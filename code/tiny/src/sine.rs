//! The sine MLP (1 -> 32 -> 32 -> 1, tanh), PyTorch layout.

use crate::rng::tanh;
use crate::st::{Error, F32s, SafeTensors};

pub struct Sine<'a> {
    w1: F32s<'a>,
    b1: F32s<'a>,
    w2: F32s<'a>,
    b2: F32s<'a>,
    w3: F32s<'a>,
    b3: F32s<'a>,
}

impl<'a> Sine<'a> {
    pub fn load(st: &SafeTensors<'a>) -> Result<Self, Error> {
        Ok(Sine {
            w1: st.f32s("l1.weight", 32)?,
            b1: st.f32s("l1.bias", 32)?,
            w2: st.f32s("l2.weight", 32 * 32)?,
            b2: st.f32s("l2.bias", 32)?,
            w3: st.f32s("l3.weight", 32)?,
            b3: st.f32s("l3.bias", 1)?,
        })
    }

    pub fn forward(&self, x: f32) -> f32 {
        let mut h1 = [0f32; 32];
        for (o, h) in h1.iter_mut().enumerate() {
            *h = tanh(self.w1.get(o) * x + self.b1.get(o));
        }
        let mut h2 = [0f32; 32];
        for (o, h) in h2.iter_mut().enumerate() {
            let mut s = self.b2.get(o);
            for (i, v) in h1.iter().enumerate() {
                s += self.w2.get(o * 32 + i) * v;
            }
            *h = tanh(s);
        }
        let mut y = self.b3.get(0);
        for (i, v) in h2.iter().enumerate() {
            y += self.w3.get(i) * v;
        }
        y
    }
}
