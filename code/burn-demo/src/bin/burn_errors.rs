//! What happens when shapes do not match? (Burn)
use burn::tensor::{Device, Tensor};

fn main() {
    let dev = Device::flex();
    // ANCHOR: mismatch
    let a = Tensor::<2>::zeros([2, 3], &dev);
    let b = Tensor::<2>::zeros([4, 5], &dev);
    let c = a.matmul(b); // panics
    println!("{c}");
    // ANCHOR_END: mismatch
}
