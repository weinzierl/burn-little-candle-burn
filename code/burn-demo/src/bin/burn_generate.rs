//! Load the character LM from safetensors in Burn and write.
use burn::store::{
    ModuleSnapshot, PyTorchToBurnAdapter, SafetensorsStore,
};
use burn::tensor::{Device, Int, Tensor, TensorData};
use burn_demo::lm::CharLm;
use tiny::charlm::CTX;
use tiny::rng::{Rng, sample};
use tiny::vocab::{decode, encode};

fn main() {
    let dev = Device::flex();
    // ANCHOR: load
    let bytes = std::fs::read("data/charlm.safetensors").unwrap();
    let mut store = SafetensorsStore::from_bytes(Some(bytes))
        .with_from_adapter(PyTorchToBurnAdapter);
    let mut model = CharLm::new(&dev);
    model.load_from(&mut store).unwrap();
    // ANCHOR_END: load

    let prompt = b"    pub fn ";
    let mut ctx = vec![0i64; CTX];
    ctx.extend(prompt.iter().map(|&b| encode(b).unwrap() as i64));
    let mut text = prompt.to_vec();
    let mut rng = Rng::new(1);
    // ANCHOR: loop
    for _ in 0..400 {
        let window = ctx[ctx.len() - CTX..].to_vec();
        let data = TensorData::new(window, [1, CTX]);
        let x = Tensor::<2, Int>::from_data(data, &dev);
        let logits = model.forward(x).into_data();
        let logits = logits.try_to_vec::<f32>().unwrap();
        let next = sample(&logits, 0.8, rng.next_f32());
        ctx.push(next as i64);
        text.push(decode(next));
    }
    // ANCHOR_END: loop
    println!("{}", String::from_utf8_lossy(&text));
}
