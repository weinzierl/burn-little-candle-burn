//! The character LM on a Raspberry Pi Pico 2 (RP2350, Cortex-M33).
//!
//! BUILT FOR THE BOARD, NOT TESTED ON HARDWARE.
//! Writes the generated text to UART0 (GPIO0 = TX, GPIO1 = RX),
//! 115200 baud, 8N1, then blinks the LED on GPIO25.
#![no_std]
#![no_main]

use embedded_hal::delay::DelayNs;
use embedded_hal::digital::OutputPin;
use hal::clocks::Clock;
use hal::fugit::RateExtU32;
use hal::uart::{DataBits, StopBits, UartConfig};
use panic_halt as _;
use rp235x_hal as hal;
use tiny::charlm::CharLm;
use tiny::st::SafeTensors;

/// Tell the Boot ROM about our application.
#[unsafe(link_section = ".start_block")]
#[used]
pub static IMAGE_DEF: hal::block::ImageDef =
    hal::block::ImageDef::secure_exe();

/// The Pico 2 has a 12 MHz crystal.
const XTAL_FREQ_HZ: u32 = 12_000_000;

// 1.25 MB of weights in flash, read in place.
static MODEL: &[u8] =
    include_bytes!("../../../data/charlm.safetensors");

#[hal::entry]
fn main() -> ! {
    let mut pac = hal::pac::Peripherals::take().unwrap();
    let mut watchdog = hal::Watchdog::new(pac.WATCHDOG);
    let clocks = hal::clocks::init_clocks_and_plls(
        XTAL_FREQ_HZ,
        pac.XOSC,
        pac.CLOCKS,
        pac.PLL_SYS,
        pac.PLL_USB,
        &mut pac.RESETS,
        &mut watchdog,
    )
    .unwrap();
    let mut timer =
        hal::Timer::new_timer0(pac.TIMER0, &mut pac.RESETS, &clocks);
    let sio = hal::Sio::new(pac.SIO);
    let pins = hal::gpio::Pins::new(
        pac.IO_BANK0,
        pac.PADS_BANK0,
        sio.gpio_bank0,
        &mut pac.RESETS,
    );
    let uart_pins =
        (pins.gpio0.into_function(), pins.gpio1.into_function());
    let uart =
        hal::uart::UartPeripheral::new(pac.UART0, uart_pins, &mut pac.RESETS)
            .enable(
                UartConfig::new(
                    115_200.Hz(),
                    DataBits::Eight,
                    None,
                    StopBits::One,
                ),
                clocks.peripheral_clock.freq(),
            )
            .unwrap();
    let mut led = pins.gpio25.into_push_pull_output();

    let st = SafeTensors::parse(MODEL).unwrap();
    let lm = CharLm::load(&st).unwrap();
    let mut out = [0u8; 512];
    let t0 = timer.get_counter();
    let n = lm.generate(b"    pub fn ", 1, 0.8, 400, &mut out);
    let us = (timer.get_counter() - t0).to_micros();

    for line in out[..n].split(|&b| b == b'\n') {
        uart.write_full_blocking(line);
        uart.write_full_blocking(b"\r\n");
    }
    let mut buf = [0u8; 20];
    uart.write_full_blocking(b"microseconds for 400 characters: ");
    uart.write_full_blocking(decimal(us, &mut buf));
    uart.write_full_blocking(b"\r\n");

    loop {
        led.set_high().unwrap();
        timer.delay_ms(500);
        led.set_low().unwrap();
        timer.delay_ms(500);
    }
}

/// Format an unsigned integer without `core::fmt`.
fn decimal(mut v: u64, buf: &mut [u8; 20]) -> &[u8] {
    let mut i = buf.len();
    loop {
        i -= 1;
        buf[i] = b'0' + (v % 10) as u8;
        v /= 10;
        if v == 0 {
            break;
        }
    }
    &buf[i..]
}

/// Program metadata for `picotool info`.
#[unsafe(link_section = ".bi_entries")]
#[used]
pub static PICOTOOL_ENTRIES: [hal::binary_info::EntryAddr; 2] = [
    hal::binary_info::rp_program_name!(c"burn-little-candle-burn LM"),
    hal::binary_info::rp_program_description!(
        c"Character LM from RustLab 2026, output on UART0"
    ),
];
