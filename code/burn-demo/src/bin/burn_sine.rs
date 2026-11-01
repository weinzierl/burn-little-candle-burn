//! Learn sin(x) with a tiny MLP in Burn (Flex CPU backend).
use std::time::Instant;

use burn::module::Module;
use burn::nn::loss::{MseLoss, Reduction::Mean};
use burn::nn::{Linear, LinearConfig};
use burn::optim::{AdamConfig, GradientsParams};
use burn::store::{
    BurnToPyTorchAdapter, ModuleSnapshot, PyTorchToBurnAdapter,
    SafetensorsStore,
};
use burn::tensor::{Device, Tensor, TensorData};

const INIT: &str = "data/sine-init.safetensors";
const OUT: &str = "data/sine-burn.safetensors";

// ANCHOR: model
#[derive(Module, Debug)]
struct Mlp {
    l1: Linear,
    l2: Linear,
    l3: Linear,
}

impl Mlp {
    fn new(dev: &Device) -> Self {
        Self {
            // ANCHOR: names
            l1: LinearConfig::new(1, 32).init(dev),
            l2: LinearConfig::new(32, 32).init(dev),
            l3: LinearConfig::new(32, 1).init(dev),
            // ANCHOR_END: names
        }
    }

    // ANCHOR: forward
    fn forward(&self, x: Tensor<2>) -> Tensor<2> {
        let x = self.l1.forward(x).tanh();
        let x = self.l2.forward(x).tanh();
        self.l3.forward(x)
    }
    // ANCHOR_END: forward
}
// ANCHOR_END: model

fn report(step: usize, loss: Tensor<1>) {
    if step % 250 == 0 {
        let l = loss.into_scalar::<f32>();
        println!("step {step:>4}  loss {l:.6}");
    }
}

fn main() {
    let dev = Device::flex().autodiff();
    let mut model = Mlp::new(&dev);

    // Same start as Candle: weights stored PyTorch-style.
    // ANCHOR: init
    let mut init = SafetensorsStore::from_file(INIT)
        .with_from_adapter(PyTorchToBurnAdapter);
    model.load_from(&mut init).expect("load init");
    // ANCHOR_END: init

    let xs: Vec<f32> = (0..256)
        .map(|i| -3.14159265 + 6.2831853 * i as f32 / 255.0)
        .collect();

    let t0 = Instant::now();
    // ANCHOR: train
    let data = TensorData::new(xs, [256, 1]);
    let x = Tensor::<2>::from_data(data, &dev);
    let y = x.clone().sin();
    let mut opt = AdamConfig::new().with_epsilon(1e-8).init();
    for step in 0..2000 {
        let pred = model.forward(x.clone());
        let loss = MseLoss::new().forward(pred, y.clone(), Mean);
        let grads = loss.backward();
        let grads = GradientsParams::from_grads(grads, &model);
        model = opt.step(0.01, model, grads);
        report(step, loss);
    }
    // ANCHOR_END: train
    let secs = t0.elapsed().as_secs_f64();
    let model = model.valid();
    let xv = x.clone().without_autodiff();
    let pred = model.forward(xv.clone());
    let fin = MseLoss::new()
        .forward(pred.clone(), xv.clone().sin(), Mean)
        .into_scalar::<f32>();
    println!("step 2000  loss {fin:.6}");
    println!(
        "2000 steps: {secs:.2} s ({:.0} us/step)",
        secs * 1e6 / 2000.0
    );
    let mut out = SafetensorsStore::from_file(OUT)
        .with_to_adapter(BurnToPyTorchAdapter)
        .overwrite(true);
    model.save_into(&mut out).expect("save");
    println!("saved {OUT}");

    let px: Vec<f32> =
        xv.into_data().try_to_vec::<f32>().unwrap();
    let py: Vec<f32> =
        pred.into_data().try_to_vec::<f32>().unwrap();
    let mut csv = String::from("x,sin,pred\n");
    for (a, b) in px.iter().zip(py.iter()) {
        csv += &format!("{a:.5},{:.5},{b:.5}\n", a.sin());
    }
    std::fs::write("out/sine-burn.csv", csv).unwrap();
}
