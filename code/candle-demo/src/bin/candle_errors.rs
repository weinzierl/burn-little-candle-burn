//! What happens when shapes do not match? (Candle)
use candle_core::{DType, Device, Tensor};

fn main() -> candle_core::Result<()> {
    let dev = Device::Cpu;
    // ANCHOR: mismatch
    let a = Tensor::zeros((2, 3), DType::F32, &dev)?;
    let b = Tensor::zeros((4, 5), DType::F32, &dev)?;
    match a.matmul(&b) {
        Ok(c) => println!("{c}"),
        Err(e) => println!("Err: {e}"),
    }
    // ANCHOR_END: mismatch
    // ANCHOR: rank
    let v = Tensor::zeros(3, DType::F32, &dev)?;
    if let Err(e) = a.matmul(&v) {
        println!("Err: {e}");
    }
    // ANCHOR_END: rank
    Ok(())
}
