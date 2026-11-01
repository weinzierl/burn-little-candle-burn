# Burn, little candle, burn!  RustLab 2026, Bologna.
# `just` lists the recipes. Run them from the repository root.

set shell := ["bash", "-euo", "pipefail", "-c"]

typst := env("TYPST", "typst")
typst_base := "--root . --ignore-system-fonts --font-path fonts/public"

default:
    @just --list --unsorted

# Slides with the free headline font (Kumbh Sans): presentation-public.pdf
public:
    {{typst}} compile {{typst_base}} --input fonts=public slides/presentation.typ presentation-public.pdf
    @echo "presentation-public.pdf"

# Slides with Ergonomique (licensed files in fonts/private/): presentation-private.pdf
private:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! ls fonts/private/*.[ot]tf >/dev/null 2>&1; then
      echo "No Ergonomique font files in fonts/private/ (see fonts/private/README.md)." >&2
      exit 1
    fi
    {{typst}} compile {{typst_base}} --font-path fonts/private --input fonts=private \
      slides/presentation.typ presentation-private.pdf 2> typst-private.log || { cat typst-private.log; exit 1; }
    if grep -q "unknown font family" typst-private.log; then
      cat typst-private.log; echo "Ergonomique was not found by Typst." >&2; exit 1
    fi
    if [ -s typst-private.log ]; then cat typst-private.log >&2; fi
    rm -f typst-private.log
    pdffonts presentation-private.pdf 2>/dev/null | grep -i ergonomique || echo "(pdffonts not installed: check font embedding yourself)"
    echo "presentation-private.pdf"

# Speaker notes: speaker-notes.pdf (public thumbnails) and speaker-notes.md
notes: public check-notes
    {{typst}} compile {{typst_base}} --input deck=/presentation-public.pdf notes/speaker-notes.typ speaker-notes.pdf
    python3 tools/notes_md.py

# Speaker notes with thumbnails of the private deck (do not publish)
notes-private: private check-notes
    {{typst}} compile {{typst_base}} --font-path fonts/private --input deck=/presentation-private.pdf notes/speaker-notes.typ speaker-notes-private.pdf
    @echo "speaker-notes-private.pdf"

# Check that notes/notes.yaml matches the slide order
check-notes:
    {{typst}} query {{typst_base}} --input fonts=public slides/presentation.typ "<slide-id>" --field value 2>/dev/null | python3 tools/check_notes.py

# Download every crate once, so later builds work offline
fetch:
    cd code && cargo fetch
    cd code/firmware && cargo fetch
    cd code/firmware/pico2 && cargo fetch
    cd candle-batteries && cargo fetch
    cd burn-nostd && cargo fetch
    cd burn-nostd/web && cargo fetch
    cd burn-nostd/qemu && cargo fetch
    cd burn-nostd/pico2 && cargo fetch

# Part 1: the four Candle programs (models download from the Hub on the first run)
candle:
    cd candle-batteries && cargo tensors
    cd candle-batteries && cargo classify 2-classify/images/cat.jpg
    cd candle-batteries && cargo similar "Where can I eat tonight?"
    cd candle-batteries && cargo ask

# Part 3: the four no_std steps as desktop programs (Rust 1.95 via rust-toolchain.toml)
nostd:
    cd burn-nostd && cargo sine
    cd burn-nostd && cargo gesture
    cd burn-nostd && cargo keywords
    cd burn-nostd && cargo tinystories -- "Once upon a time" 0 80

# Part 3: build the four WebAssembly modules and serve the demo pages on http://localhost:8000
nostd-web:
    cd burn-nostd && cargo web

# Part 3: the firmware code paths on an emulated Cortex-M33 (needs qemu-system-arm)
nostd-qemu:
    cd burn-nostd/qemu && for b in sine gesture keywords tinystories; do cargo run --release -q --bin "$b"; done

# Refresh candle-batteries/out and burn-nostd/out, which the slides read
capture-examples:
    tools/capture-examples.sh

# Build all host examples (release)
examples:
    cd code && cargo build --release

# Unit tests of the no_std crate, then check that all generated texts agree
test:
    cd code && cargo test --release -p tiny
    cd code && ./compare.sh

# Part 2: sin(x) in Candle, then in Burn, from the same start
sine:
    cd code && cargo run --release -q --bin candle_sine
    cd code && cargo run --release -q --bin burn_sine

# Extra, not on the slides: train the character LM with Burn (overwrites data/charlm.*; `git checkout code/data` restores)
train-lm steps="20000":
    cd code && cargo run --release -q --bin make_corpus
    cd code && cargo run --release -q --bin burn_train_lm -- {{steps}}

# Extra, not on the slides: the character LM in Burn, Candle and the framework-free crate
generate:
    cd code && cargo run --release -q --bin burn_generate
    cd code && cargo run --release -q --bin candle_generate
    cd code && cargo run --release -q --bin tiny_generate

# Shape and rank errors (the Burn ones panic or fail to compile on purpose)
errors:
    cd code && cargo run --release -q --bin candle_errors
    -cd code && cargo run --release -q --bin burn_errors
    -cd code && cargo build --release -q --bin burn_rank_error --features show-compile-error

# Extra, not on the slides: the character LM on an emulated Cortex-M33 (needs qemu-system-arm)
qemu:
    cd code/firmware && cargo run --release -q -p qemu-m33
    cd code/firmware && cargo run --release -q -p burn-m33

# Extra, not on the slides: build the character-LM firmware and print section sizes
firmware:
    cd code/firmware && cargo build --release
    cd code/firmware && "$(ls "$(rustc --print sysroot)"/lib/rustlib/*/bin/llvm-size | head -1)" -A target/thumbv8m.main-none-eabihf/release/qemu-m33 target/thumbv8m.main-none-eabihf/release/burn-m33

# Extra, not on the slides: the character-LM generators as wasm32-wasip1, run in Node (>= 22)
wasm:
    cd code && cargo build --release --target wasm32-wasip1 --bin candle_generate --bin burn_generate
    cd code && node --no-warnings wasi-run.mjs target/wasm32-wasip1/release/candle_generate.wasm
    cd code && node --no-warnings wasi-run.mjs target/wasm32-wasip1/release/burn_generate.wasm

# Re-run everything and refresh code/out/, which the slides read
capture:
    cd code && ./capture.sh

# Remove build output and generated PDFs
clean:
    rm -f presentation-public.pdf presentation-private.pdf speaker-notes.pdf speaker-notes-private.pdf
    cd code && cargo clean
    cd code/firmware && cargo clean
    cd code/firmware/pico2 && cargo clean
    cd code/candle-nostd-check && cargo clean
    cd candle-batteries && cargo clean
    cd burn-nostd && cargo clean
    cd burn-nostd/web && cargo clean
    cd burn-nostd/qemu && cargo clean
    cd burn-nostd/pico2 && cargo clean

# Extra, not on the slides: character-LM firmware for the Pico 2 (UART0 on GPIO0/1, 115200 baud). Built, not tested on hardware.
# Flash: picotool load -u -v -x -t elf code/firmware/pico2/target/thumbv8m.main-none-eabihf/release/pico2
pico2:
    cd code/firmware/pico2 && cargo build --release
    @echo "code/firmware/pico2/target/thumbv8m.main-none-eabihf/release/pico2"
