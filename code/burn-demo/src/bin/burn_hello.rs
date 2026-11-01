//! One matrix product in Burn.
use burn::tensor::{Device, Tensor};

fn main() {
    // ANCHOR: hello
    let dev = Device::flex();
    let m = [[1., 2.], [3., 4.]];
    let a = Tensor::<2>::from_floats(m, &dev);
    let b = a.clone().matmul(a);
    println!("{b}");
    // ANCHOR_END: hello
}
