//! Load the Burn-trained character LM in Candle and write.
use candle_core::DType::F32;
use candle_core::{D, Device, Result, Tensor};
use candle_nn::{
    Embedding, Linear, Module, VarBuilder, embedding, linear, ops,
};
use tiny::charlm::{CTX, EMB, HID, VOCAB};
use tiny::rng::{Rng, sample};
use tiny::vocab::{decode, encode};

// ANCHOR: model
struct CharLm {
    emb: Embedding,
    hidden: Linear,
    out: Linear,
}

impl CharLm {
    fn new(vb: VarBuilder) -> Result<Self> {
        Ok(Self {
            emb: embedding(VOCAB, EMB, vb.pp("emb"))?,
            hidden: linear(CTX * EMB, HID, vb.pp("hidden"))?,
            out: linear(HID, VOCAB, vb.pp("out"))?,
        })
    }

    fn forward(&self, ctx: &Tensor) -> Result<Tensor> {
        let (batch, _) = ctx.dims2()?;
        let x = self.emb.forward(ctx)?; // [batch, CTX, EMB]
        let x = x.reshape((batch, CTX * EMB))?;
        let x = self.hidden.forward(&x)?.tanh()?;
        self.out.forward(&x)
    }
}
// ANCHOR_END: model

/// Prompt bytes as char ids, left-padded with '\n' (id 0).
fn context(prompt: &[u8]) -> Vec<u32> {
    let mut ctx = vec![0u32; CTX];
    ctx.extend(prompt.iter().map(|&b| encode(b).unwrap() as u32));
    ctx
}

fn main() -> Result<()> {
    let dev = Device::Cpu;
    // ANCHOR: load
    let bytes = std::fs::read("data/charlm.safetensors")?;
    let vb =
        VarBuilder::from_buffered_safetensors(bytes, F32, &dev)?;
    let model = CharLm::new(vb)?;
    // ANCHOR_END: load

    let mut ctx = context(b"    pub fn ");
    let mut text = b"    pub fn ".to_vec();
    let mut rng = Rng::new(1);
    // ANCHOR: loop
    for _ in 0..400 {
        let x = Tensor::new(&ctx[ctx.len() - CTX..], &dev)?;
        let logits = model.forward(&x.unsqueeze(0)?)?;
        let logits = logits.squeeze(0)?.to_vec1::<f32>()?;
        let next = sample(&logits, 0.8, rng.next_f32());
        ctx.push(next as u32);
        text.push(decode(next));
    }
    // ANCHOR_END: loop
    println!("{}", String::from_utf8_lossy(&text));

    // The three most likely next characters for two prompts.
    for probe in ["let x = self.forwar", "let x = self.forward("]
    {
        let c = context(probe.as_bytes());
        let x = Tensor::new(&c[c.len() - CTX..], &dev)?
            .unsqueeze(0)?;
        let p = ops::softmax(&model.forward(&x)?, D::Minus1)?;
        let p = p.squeeze(0)?.to_vec1::<f32>()?;
        let mut idx: Vec<usize> = (0..VOCAB).collect();
        idx.sort_by(|&a, &b| p[b].total_cmp(&p[a]));
        print!("after {probe:?} ->");
        for &i in &idx[..3] {
            print!("  {:?} {:.2}", decode(i) as char, p[i]);
        }
        println!();
    }
    Ok(())
}
