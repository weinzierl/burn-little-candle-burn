//! Does not compile, on purpose: the rank is part of the type.
use burn::tensor::{Device, Tensor};

fn main() {
    let dev = Device::flex();
    // ANCHOR: rank
    let a = Tensor::<2>::zeros([2, 3], &dev);
    let v = Tensor::<1>::zeros([3], &dev);
    let c = a.matmul(v);
    // ANCHOR_END: rank
    println!("{c}");
}
