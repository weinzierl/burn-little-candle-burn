use candle_core::{Device, Tensor};

fn main() -> candle_core::Result<()> {
    // CPU, unless built with `--features metal` or `--features cuda`.
    let device =
        Device::new_metal(0).or_else(|_| Device::cuda_if_available(0))?;

    let a = Tensor::arange(0f32, 6., &device)?.reshape((2, 3))?;
    let b = a.t()?; // a view, no copy
    println!("{}", a.matmul(&b)?);

    // Shapes are runtime values: a mismatch is an Err, not a compile error.
    println!("{}", a.matmul(&a).unwrap_err());
    Ok(())
}
