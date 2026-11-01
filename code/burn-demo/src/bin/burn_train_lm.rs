//! Train the character LM with Burn on Candle's source code.
use std::time::Instant;

use burn::module::Module;
use burn::nn::loss::CrossEntropyLossConfig;
use burn::optim::{AdamConfig, GradientsParams};
use burn::store::{
    BurnToPyTorchAdapter, BurnpackStore, ModuleSnapshot,
    SafetensorsStore,
};
use burn::tensor::{Device, Int, Tensor, TensorData};
use burn_demo::lm::CharLm;
use tiny::charlm::{CTX, VOCAB};
use tiny::rng::{Rng, sample};
use tiny::vocab::{decode, encode};

const BATCH: usize = 128;

fn batch(
    ids: &[u8],
    rng: &mut Rng,
    dev: &Device,
) -> (Tensor<2, Int>, Tensor<1, Int>) {
    let mut ctx = Vec::with_capacity(BATCH * CTX);
    let mut next = Vec::with_capacity(BATCH);
    for _ in 0..BATCH {
        let p = rng.below(ids.len() - CTX - 1);
        ctx.extend(ids[p..p + CTX].iter().map(|&c| c as i64));
        next.push(ids[p + CTX] as i64);
    }
    let ctx = TensorData::new(ctx, [BATCH, CTX]);
    let next = TensorData::new(next, [BATCH]);
    (Tensor::from_data(ctx, dev), Tensor::from_data(next, dev))
}

fn generate(
    model: &CharLm,
    dev: &Device,
    n: usize,
    seed: u64,
) -> String {
    let mut rng = Rng::new(seed);
    let mut ctx: Vec<u8> = b"    pub fn "
        .iter()
        .map(|&b| encode(b).unwrap())
        .collect();
    while ctx.len() < CTX {
        ctx.insert(0, 0);
    }
    let mut out: Vec<u8> = b"    pub fn ".to_vec();
    for _ in 0..n {
        let window: Vec<i64> = ctx[ctx.len() - CTX..]
            .iter()
            .map(|&c| c as i64)
            .collect();
        let x = Tensor::<2, Int>::from_data(
            TensorData::new(window, [1, CTX]),
            dev,
        );
        let logits: Vec<f32> = model
            .forward(x)
            .into_data()
            .try_to_vec::<f32>()
            .unwrap();
        let next = sample(&logits, 0.8, rng.next_f32());
        ctx.push(next as u8);
        out.push(decode(next));
    }
    String::from_utf8(out).unwrap()
}

fn main() {
    let steps: usize = std::env::args()
        .nth(1)
        .map(|s| s.parse().unwrap())
        .unwrap_or(6000);
    let text = std::fs::read("data/corpus.txt")
        .expect("run make_corpus first");
    let ids: Vec<u8> =
        text.iter().filter_map(|&b| encode(b)).collect();
    // every 20th block of 4096 chars is held out for validation
    let (mut train, mut valid) = (Vec::new(), Vec::new());
    for (i, block) in ids.chunks(4096).enumerate() {
        if i % 20 == 19 {
            valid.extend_from_slice(block)
        } else {
            train.extend_from_slice(block)
        }
    }
    let (train, valid) = (&train[..], &valid[..]);
    println!(
        "corpus {} chars, train {}, valid {}",
        ids.len(),
        train.len(),
        valid.len()
    );

    let dev = Device::flex().autodiff();
    dev.seed(42);
    let mut model = CharLm::new(&dev);
    let mut opt = AdamConfig::new().with_epsilon(1e-8).init();
    let ce = CrossEntropyLossConfig::new().init(&dev);
    let mut rng = Rng::new(7);
    let n_params = model.num_params();
    println!("parameters: {n_params}");
    let checkpoints = [0usize, 300, 1000, 3000];
    let show = |model: &CharLm, step: usize| {
        let s = generate(
            &model.clone().valid(),
            &dev.clone().without_autodiff(),
            100,
            1,
        );
        println!("--- sample at step {step} ---\n{s}\n---");
    };
    show(&model, 0);

    let t0 = Instant::now();
    let mut acc = 0.0;
    for step in 1..=steps {
        // linear decay from 3e-3 to 3e-4
        let lr = 3e-3 - 2.7e-3 * (step as f64 / steps as f64);
        let (x, y) = batch(train, &mut rng, &dev);
        let loss = ce.forward(model.forward(x), y);
        acc += loss.clone().into_scalar::<f32>();
        let grads =
            GradientsParams::from_grads(loss.backward(), &model);
        model = opt.step(lr, model, grads);
        if checkpoints.contains(&step) {
            show(&model, step);
        }
        if step % 1000 == 0 {
            let m = model.valid();
            let vdev = dev.clone().without_autodiff();
            // same validation batches every time
            let mut vrng = Rng::new(99);
            let mut vl = 0.0;
            for _ in 0..8 {
                let (x, y) = batch(valid, &mut vrng, &vdev);
                vl += ce
                    .forward(m.forward(x), y)
                    .into_scalar::<f32>();
            }
            println!(
                "step {step:>5}  train {:.3}  valid {:.3}  {:.0} s",
                acc / 1000.0,
                vl / 8.0,
                t0.elapsed().as_secs_f64()
            );
            acc = 0.0;
        }
    }
    let secs = t0.elapsed().as_secs_f64();
    println!(
        "trained {steps} steps in {secs:.1} s ({:.1} ms/step)",
        secs * 1e3 / steps as f64
    );
    let model = model.valid();
    let vdev = dev.without_autodiff();
    println!(
        "--- sample after training ---\n{}\n---",
        generate(&model, &vdev, 400, 1)
    );
    let mut store =
        SafetensorsStore::from_file("data/charlm.safetensors")
            .with_to_adapter(BurnToPyTorchAdapter)
            .overwrite(true);
    model.save_into(&mut store).expect("save");
    println!("saved data/charlm.safetensors");
    let mut bpk = BurnpackStore::from_file("data/charlm.bpk")
        .overwrite(true);
    model.save_into(&mut bpk).expect("save bpk");
    println!("saved data/charlm.bpk");
    let _ = VOCAB;
}
