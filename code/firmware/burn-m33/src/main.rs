//! The same character LM, run by Burn itself (Flex backend,
//! no_std) on a bare-metal Cortex-M33 under QEMU.
#![no_std]
#![no_main]
extern crate alloc;

use alloc::vec::Vec;
use burn::store::{BurnpackStore, ModuleSnapshot};
use burn::tensor::{Device, Int, Tensor, TensorData};
use cortex_m_rt::entry;
use cortex_m_semihosting::{debug, hprintln};
use embedded_alloc::LlffHeap as Heap;
use tiny::charlm::CTX;
use tiny::rng::{Rng, sample};
use tiny::vocab::{decode, encode};

// The model definition used for training, unchanged.
#[path = "../../../burn-demo/src/lm.rs"]
mod lm;

#[global_allocator]
static HEAP: Heap = Heap::empty();
const HEAP_SIZE: usize = 32 * 1024;

// ANCHOR: weights
static MODEL: &[u8] = include_bytes!("../../../data/charlm.bpk");
// ANCHOR_END: weights

#[entry]
fn main() -> ! {
    {
        use core::mem::MaybeUninit;
        static mut MEM: [MaybeUninit<u8>; HEAP_SIZE] =
            [MaybeUninit::uninit(); HEAP_SIZE];
        unsafe { HEAP.init(&raw mut MEM as usize, HEAP_SIZE) }
    }
    // ANCHOR: load
    let dev = Device::flex();
    let mut model = lm::CharLm::new(&dev);
    let mut store = BurnpackStore::from_static(MODEL);
    model.load_from(&mut store).unwrap();
    // ANCHOR_END: load
    hprintln!("loaded, heap used {} bytes", HEAP.used());

    let mut ctx: Vec<i64> = alloc::vec![0; CTX];
    let mut text: Vec<u8> = Vec::new();
    for &b in b"    pub fn " {
        ctx.push(encode(b).unwrap() as i64);
        text.push(b);
    }
    let mut rng = Rng::new(1);
    let mut peak = 0;
    for _ in 0..400 {
        let w = ctx[ctx.len() - CTX..].to_vec();
        let x = Tensor::<2, Int>::from_data(
            TensorData::new(w, [1, CTX]),
            &dev,
        );
        let logits: Vec<f32> = model
            .forward(x)
            .into_data()
            .try_to_vec::<f32>()
            .unwrap();
        let next = sample(&logits, 0.8, rng.next_f32());
        ctx.push(next as i64);
        text.push(decode(next));
        peak = peak.max(HEAP.used());
    }
    hprintln!("{}", core::str::from_utf8(&text).unwrap());
    hprintln!("heap peak during generation {} bytes", peak);
    debug::exit(debug::EXIT_SUCCESS);
    loop {}
}

#[panic_handler]
fn panic(info: &core::panic::PanicInfo) -> ! {
    hprintln!("PANIC: {}", info);
    debug::exit(debug::EXIT_FAILURE);
    loop {}
}
