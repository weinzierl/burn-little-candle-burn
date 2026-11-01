//! The character language model, framework-free.
//!
//! next char = f(previous CTX chars):
//! embed each char (EMB floats), concatenate,
//! one hidden layer (HID, tanh), project to VOCAB logits.
//! Weights use the PyTorch layout: Linear is [out, in].

use crate::rng::tanh;
use crate::st::{Error, F32s, SafeTensors};
pub use crate::vocab::VOCAB;

pub const CTX: usize = 32;
pub const EMB: usize = 16;
pub const HID: usize = 512;

pub struct CharLm<'a> {
    emb: F32s<'a>, // [VOCAB, EMB]
    w1: F32s<'a>,  // [HID, CTX * EMB]
    b1: F32s<'a>,  // [HID]
    w2: F32s<'a>,  // [VOCAB, HID]
    b2: F32s<'a>,  // [VOCAB]
}

impl<'a> CharLm<'a> {
    pub fn load(st: &SafeTensors<'a>) -> Result<Self, Error> {
        Ok(CharLm {
            emb: st.f32s("emb.weight", VOCAB * EMB)?,
            w1: st.f32s("hidden.weight", HID * CTX * EMB)?,
            b1: st.f32s("hidden.bias", HID)?,
            w2: st.f32s("out.weight", VOCAB * HID)?,
            b2: st.f32s("out.bias", VOCAB)?,
        })
    }

    // ANCHOR: forward
    /// Logits for the character after `ctx`.
    pub fn forward(
        &self,
        ctx: &[u8; CTX],
        logits: &mut [f32; VOCAB],
    ) {
        let mut x = [0f32; CTX * EMB];
        for (t, &c) in ctx.iter().enumerate() {
            let row = c as usize * EMB;
            for e in 0..EMB {
                x[t * EMB + e] = self.emb.get(row + e);
            }
        }
        let mut h = [0f32; HID];
        dense(&self.w1, &self.b1, &x, &mut h);
        h.iter_mut().for_each(|v| *v = tanh(*v));
        dense(&self.w2, &self.b2, &h, logits);
    }
    // ANCHOR_END: forward
}

// ANCHOR: dense
/// out = W x + b, with W stored as [out, in].
fn dense(w: &F32s, b: &F32s, x: &[f32], out: &mut [f32]) {
    for (o, y) in out.iter_mut().enumerate() {
        let row = o * x.len();
        let mut s = b.get(o);
        for (i, v) in x.iter().enumerate() {
            s += w.get(row + i) * v;
        }
        *y = s;
    }
}
// ANCHOR_END: dense

impl CharLm<'_> {
    // ANCHOR: generate
    /// Sample `n` characters after `prompt` into `out`.
    /// Returns the number of bytes written.
    pub fn generate(
        &self,
        prompt: &[u8],
        seed: u64,
        temperature: f32,
        n: usize,
        out: &mut [u8],
    ) -> usize {
        let mut rng = crate::rng::Rng::new(seed);
        let mut ctx = [0u8; CTX]; // 0 is '\n'
        let mut len = 0;
        for &b in prompt {
            if let Some(c) = crate::vocab::encode(b) {
                ctx.rotate_left(1);
                ctx[CTX - 1] = c;
                out[len] = b;
                len += 1;
            }
        }
        let mut logits = [0f32; VOCAB];
        for _ in 0..n {
            if len == out.len() {
                break;
            }
            self.forward(&ctx, &mut logits);
            let u = rng.next_f32();
            let c = crate::rng::sample(&logits, temperature, u);
            ctx.rotate_left(1);
            ctx[CTX - 1] = c as u8;
            out[len] = crate::vocab::decode(c);
            len += 1;
        }
        len
    }
    // ANCHOR_END: generate
}
