//! Host run of the framework-free LM (same code as on the MCU).
use tiny::charlm::CharLm;
use tiny::st::SafeTensors;

fn main() {
    let bytes = std::fs::read("data/charlm.safetensors").unwrap();
    let st = SafeTensors::parse(&bytes).unwrap();
    let lm = CharLm::load(&st).unwrap();
    let mut out = [0u8; 512];
    let n = lm.generate(b"    pub fn ", 1, 0.8, 400, &mut out);
    println!("{}", core::str::from_utf8(&out[..n]).unwrap());

    let sine =
        std::fs::read("data/sine-burn.safetensors").unwrap();
    let st = SafeTensors::parse(&sine).unwrap();
    let mlp = tiny::sine::Sine::load(&st).unwrap();
    for x in [-3.0f32, -1.5, 0.0, 1.5, 3.0] {
        println!(
            "x {x:>5.2}  sin {:>8.5}  mlp {:>8.5}",
            x.sin(),
            mlp.forward(x)
        );
    }
}
