//! One matrix product in Candle.
use candle_core::{Device, Result, Tensor};

fn main() -> Result<()> {
    // ANCHOR: hello
    let dev = Device::Cpu;
    let m = [[1f32, 2.], [3., 4.]];
    let a = Tensor::new(&m, &dev)?;
    let b = a.matmul(&a)?;
    println!("{b}");
    // ANCHOR_END: hello
    Ok(())
}
