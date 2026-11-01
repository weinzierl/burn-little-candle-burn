//! The character LM on a bare-metal Cortex-M33 (QEMU).
#![no_std]
#![no_main]

use cortex_m_rt::entry;
use cortex_m_semihosting::{debug, hprintln};
use panic_halt as _;
use tiny::charlm::CharLm;
use tiny::st::SafeTensors;

// ANCHOR: weights
// 1.2 MB of weights, linked into flash. Never copied to RAM.
static MODEL: &[u8] =
    include_bytes!("../../../data/charlm.safetensors");
// ANCHOR_END: weights

#[entry]
fn main() -> ! {
    let st = SafeTensors::parse(MODEL).unwrap();
    let lm = CharLm::load(&st).unwrap();
    let mut out = [0u8; 512];
    let n = lm.generate(b"    pub fn ", 1, 0.8, 400, &mut out);
    let text = core::str::from_utf8(&out[..n]).unwrap();
    hprintln!("{}", text);
    debug::exit(debug::EXIT_SUCCESS);
    loop {}
}
