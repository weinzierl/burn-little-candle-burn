# Burn, little candle, burn!

Slides, speaker notes and code for my talk at RustLab 2026 in Bologna (2 November 2026, 45 minutes): machine learning in Rust with Candle and Burn.

The talk asks one question, what does it take to do ML in Rust, and answers it three times, with real code and output captured from real runs:

1. **Use someone else's model** (`candle-batteries/`). Candle and the Hugging Face Hub: an image classifier (ResNet-18), sentence similarity (all-MiniLM-L6-v2) and a chat model (SmolLM2-360M-Instruct, 8-bit GGUF), each a short `main.rs`.
2. **Train one model in both** (`code/`). A small network learns sin(x) in Candle and in Burn from the same weights file. The printed losses match to six decimals from step 250 on.
3. **Leave std behind** (`burn-nostd/`). Burn without the standard library, in four steps: inference with weights in flash, training on the device, spoken words, and Karpathy's TinyStories 260K language model. Each step runs as a no_std desktop program, as zero-import WebAssembly in the browser, on an emulated Cortex-M33 (QEMU), and is built as Raspberry Pi Pico 2 firmware.

## Layout

```
presentation-public.pdf   slides, free fonts (built from slides/presentation.typ)
speaker-notes.pdf         notes with slide thumbnails, sized for a phone
speaker-notes.md          the same notes as Markdown
questions.md              questions to expect in the Q&A, most likely first, with answers
MAP.md                    which slide shows which file of this repository
slides/                   presentation.typ, theme.typ, code theme, QR codes, screenshots,
  media/video/            fallback videos of the four demo pages; board.mp4, the board writing
notes/                    notes.yaml (single source), speaker-notes.typ
candle-batteries/         part 1: four Candle programs (own Cargo workspace)
  out/                    captured output; the slides read these files
burn-nostd/               part 3: Burn without std (own workspaces, Rust 1.95 pinned)
  out/                    captured output; the slides read these files
code/                     part 2 and more: Cargo workspace for the comparisons
  candle-demo/, burn-demo/  hello, errors, sine in both frameworks
  candle-nostd-check/     expected to fail: Candle does not build for bare metal
  burn-optim-nostd-check/ expected to fail: burn-optim 0.22.0 does not build without std
  out/                    captured output; the slides read these files
  (also: a character LM trained by Burn and run by Candle, a framework-free no_std crate
   and Cortex-M33 firmware for it; from the first version of the talk, not on the slides)
fonts/public/             Jost, IBM Plex Mono, Kumbh Sans (SIL OFL 1.1)
fonts/private/            place for the licensed Ergonomique files (not in git)
tools/                    capture script, notes generator, deck/notes consistency check,
                          GGUF statistics, slide map
  minilm-reference/       checks the MiniLM numbers against the official ONNX export
rehearsal/                a virtual run of the talk for practice: script, five Q&A questions,
                          synthetic voices, video with a clock (its own README)
justfile                  all commands
```

## Quick start

Requirements: Rust (rustup), [just](https://github.com/casey/just), [Typst](https://github.com/typst/typst) 0.15 for the slides. `burn-nostd` installs Rust 1.95 itself through its `rust-toolchain.toml`; the rest needs 1.95 or newer (tested with 1.97.0). Optional: `qemu-system-arm` for the Cortex-M33 runs, Python 3 with PyYAML for the Markdown notes. `just qemu` and `just firmware` build `code/firmware` with your default toolchain, which needs the target once: `rustup target add thumbv8m.main-none-eabihf`.

```sh
just candle      # part 1: tensors, classify, similar, ask (downloads 527 MB of models once)
just sine        # part 2: sin(x) in Candle, then Burn, from one start file
just nostd       # part 3: the four no_std steps on the desktop
just nostd-web   # part 3: the four demo pages on http://localhost:8000
just nostd-qemu  # part 3: the firmware code paths on an emulated Cortex-M33
just public      # slides
just notes       # speaker notes (PDF and Markdown)
```

## Slides

Style: 1970s Swiss, after my `seventies` Typst kit. Full-bleed flat colour, one cream line on the same horizon on every slide, after Osvaldo Cavandoli's La Linea; it rises into the candle on the first and last slide, a plinth for each section number, a staircase for the four no_std steps and a frame for the comparison table. Text is cream on the dark fields and black on ochre (contrast 4.1:1 or more). Three backup slides after the last one, for questions only: how a model comes in, quantization, timing GPU code.

One source, two font profiles:

```sh
just public    # Kumbh Sans headlines, everything redistributable
just private   # Ergonomique headlines; needs the font files in fonts/private/
```

Both run Typst with `--ignore-system-fonts` and explicit `--font-path`, so no system font can sneak in, and with `text(fallback: false)`, so a missing glyph shows up instead of being silently replaced. Code on the slides is cut from the real source files, either by `// ANCHOR:` markers or by first and last line, and every output block and number is read from the captured files in `*/out/`. `just capture-examples` (parts 1 and 3) and `just capture` (part 2) refresh them; recompiling the slides then shows the new output. Long code lines are wrapped for display with a visible `↪`.

## The examples

| Recipe | What it runs | Notes |
|---|---|---|
| `just candle` | `candle-batteries`: `tensors`, `classify`, `similar`, `ask` | models from the Hub on the first run, cached in `~/.cache/huggingface` |
| `just sine` | sin(x) in Candle, then Burn, from `code/data/sine-init.safetensors` | seconds |
| `just errors` | shape errors: Candle `Err`, Burn panic, Burn rank compile error | the Burn ones fail on purpose |
| `just nostd` | `burn-nostd` desktop programs: sine, gesture, keywords, tinystories | no_std, libc instead of std |
| `just nostd-web` | builds the four WebAssembly modules and serves the demo site | no wasm-bindgen, zero imports |
| `just nostd-qemu` | the four firmware programs in QEMU `mps2-an505` | 520 KiB of RAM, like the RP2350 |
| `just uf2` | builds `tinystories-usb` (or `just uf2 tinystories-lcd`) and its UF2 file for an RP2350 board without a debug probe | copy the file to the board's drive |
| `just board-log`, `just board-check` | save the stories the board sends over USB serial, compare them with QEMU's, print tokens per second | Linux `/dev/ttyACM0` by default |
| `just capture-examples` | all of `candle-batteries` and `burn-nostd`, output into their `out/` | a few minutes |

Inside `candle-batteries/` and `burn-nostd/` the cargo aliases from their READMEs work too (`cargo similar "It is raining."`, `cargo tinystories -- "Once upon a time" 0.8`, `cargo web`).

The Pico 2 firmware is in `burn-nostd/pico2/` (`cargo build --release` there; flashing needs probe-rs or picotool). It builds; a Pico 2 itself has not run it. `tinystories-usb` needs no probe: it writes the stories to the board's own USB port. It and `tinystories-lcd`, which also shows them on the screen, ran on a Waveshare RP2350-Touch-LCD-3.5 (RP2350B): 4.3 tokens/s, the same stories as in QEMU (`burn-nostd/out/board-*.txt`).

## Offline preparation (before travelling)

1. With network, once: `just fetch` (all crates), then `just candle` (downloads the three models, 527 MB, into `~/.cache/huggingface`), `just nostd`, `just nostd-web`.
2. Test with the network off: `HF_HUB_OFFLINE=1 just candle` must still print the same results. With a warm cache the Candle programs ran with the network cut.
3. The burn-nostd weights (sine, TinyStories 260K) and test recordings are in the repository; nothing is downloaded at run time.

## Versions

| Component | Version |
|---|---|
| candle-core, candle-nn, candle-transformers | 0.11.0 (`Cargo.lock`), hf-hub 1.0.0, tokenizers 0.22.2 |
| burn in `burn-nostd` | 0.22.0 (pinned with `=`), Flex backend, `default-features = false` |
| burn in `code/` | 0.22.1 (pinned with `=`) |
| Rust | 1.95.0 for `burn-nostd` (pinned), 1.97.0 for the rest |
| Typst | 0.15.1 |
| QEMU | 8.2.2, machine `mps2-an505` |

## What was tested where

Everything below ran on a Linux x86-64 cloud VM with 2 vCPUs and no GPU, on 2026-10-31. Details and the captured evidence are in `VERIFICATION.md`.

| Item | Status |
|---|---|
| `candle-batteries`, all four programs, CPU | built and run against the Hub; models checked against the Hub's SHA-256 |
| `candle-batteries` with the network cut (warm cache) | run |
| sin(x) in Candle 0.11.0 and Burn 0.22.1 | built and run |
| `burn-nostd`: tests, desktop programs | built and run with Rust 1.95.0 |
| `burn-nostd`: WebAssembly pages | built, run in headless Chromium |
| `burn-nostd`: firmware code paths in QEMU | built and run |
| `burn-nostd/pico2` for the Raspberry Pi Pico 2 | built only, **not run on a Pico 2** |
| `tinystories-usb` and `tinystories-lcd` on a Waveshare RP2350-Touch-LCD-3.5 (RP2350B) | run (1 November): 4.3 tokens/s, same text as QEMU; logs in `burn-nostd/out/` |
| macOS, Metal, CUDA, real microphones and motion sensors | **not tested** |

## Limitations

- Timings come from a shared 2-vCPU cloud VM. They show orders of magnitude, not benchmarks.
- QEMU does not model timing: no speed numbers for the microcontroller.
- The keyword recordings are synthetic voices (espeak-ng), not people.
- `ask` uses the publisher's 8-bit GGUF (`HuggingFaceTB/SmolLM2-360M-Instruct-GGUF`); a 4-bit file from a third party was used in an earlier draft and replaced.
- Burn's API changed substantially in 0.22 (released 6 October 2026). Older tutorials use `Tensor<B, D>` and do not compile with it.

## License

- Code in `code/` and `burn-nostd/`: MIT OR Apache-2.0, at your option (`LICENSE-MIT`, `LICENSE-APACHE`). `candle-batteries/`: MIT (`candle-batteries/LICENSE`).
- Slides and speaker notes: CC BY 4.0.
- TinyStories 260K and its tokenizer (`burn-nostd/4-tinystories/model/`): Andrej Karpathy, MIT. The Hub models used by `candle-batteries` are downloaded at run time, not included (all Apache-2.0).
- `candle-batteries/2-classify/images/`: scikit-image sample data, CC0.
- `code/data/corpus.txt` is derived from the source of candle-core and candle-nn 0.11.0 (MIT OR Apache-2.0, license texts in `code/data/third-party/candle/`).
- Fonts: see `FONTS.md`. Ergonomique is not included and must not be committed.

See `REFERENCES.md` for sources and `VERIFICATION.md` for the checks behind every claim.
