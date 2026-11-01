//! Learn sin(x) with a tiny MLP in Candle (CPU).
use std::path::Path;
use std::time::Instant;

use candle_core::{DType, Device, Result, Tensor};
use candle_nn::{
    AdamW, Linear, Module, Optimizer, ParamsAdamW, VarBuilder,
    VarMap, linear, loss,
};

const INIT: &str = "data/sine-init.safetensors";
const OUT: &str = "data/sine-candle.safetensors";

// ANCHOR: model
struct Mlp {
    l1: Linear,
    l2: Linear,
    l3: Linear,
}

impl Mlp {
    fn new(vb: VarBuilder) -> Result<Self> {
        Ok(Self {
            // ANCHOR: names
            l1: linear(1, 32, vb.pp("l1"))?,
            l2: linear(32, 32, vb.pp("l2"))?,
            l3: linear(32, 1, vb.pp("l3"))?,
            // ANCHOR_END: names
        })
    }

    // ANCHOR: forward
    fn forward(&self, x: &Tensor) -> Result<Tensor> {
        let x = self.l1.forward(x)?.tanh()?;
        let x = self.l2.forward(&x)?.tanh()?;
        self.l3.forward(&x)
    }
    // ANCHOR_END: forward
}
// ANCHOR_END: model

fn report(step: usize, loss: &Tensor) -> Result<()> {
    if step % 250 == 0 {
        let l = loss.to_scalar::<f32>()?;
        println!("step {step:>4}  loss {l:.6}");
    }
    Ok(())
}

fn main() -> Result<()> {
    let dev = Device::Cpu;
    let mut varmap = VarMap::new();
    let vb = VarBuilder::from_varmap(&varmap, DType::F32, &dev);
    let model = Mlp::new(vb)?;

    // Both frameworks start from the same weights.
    if !Path::new(INIT).exists() {
        varmap.save(INIT)?;
        println!("created {INIT}");
    }
    varmap.load(INIT)?;

    // 256 points on [-pi, pi]
    let xs: Vec<f32> = (0..256)
        .map(|i| -3.14159265 + 6.2831853 * i as f32 / 255.0)
        .collect();

    let t0 = Instant::now();
    // ANCHOR: train
    let x = Tensor::from_vec(xs, (256, 1), &dev)?;
    let y = x.sin()?;
    let params = ParamsAdamW {
        lr: 0.01,
        weight_decay: 0.0,
        ..Default::default()
    };
    let mut opt = AdamW::new(varmap.all_vars(), params)?;
    for step in 0..2000 {
        let loss = loss::mse(&model.forward(&x)?, &y)?;
        opt.backward_step(&loss)?;
        report(step, &loss)?;
    }
    // ANCHOR_END: train
    let secs = t0.elapsed().as_secs_f64();
    let pred = model.forward(&x)?;
    let fin = loss::mse(&pred, &y)?.to_scalar::<f32>()?;
    println!("step 2000  loss {fin:.6}");
    println!(
        "2000 steps: {secs:.2} s ({:.0} us/step)",
        secs * 1e6 / 2000.0
    );
    varmap.save(OUT)?;
    println!("saved {OUT}");

    // CSV for the plot: x, sin(x), prediction
    let px = x.flatten_all()?.to_vec1::<f32>()?;
    let py = pred.flatten_all()?.to_vec1::<f32>()?;
    let mut csv = String::from("x,sin,pred\n");
    for (a, b) in px.iter().zip(py.iter()) {
        csv += &format!("{a:.5},{:.5},{b:.5}\n", a.sin());
    }
    std::fs::write("out/sine-candle.csv", csv).unwrap();
    Ok(())
}
