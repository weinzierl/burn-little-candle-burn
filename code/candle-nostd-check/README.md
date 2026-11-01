Expected to FAIL: checks whether candle-core 0.11.0 builds for a
bare-metal Cortex-M33 (`thumbv8m.main-none-eabihf`). It does not:
its dependency tree needs `std`. Used for one slide.

    cargo build --release --target thumbv8m.main-none-eabihf
