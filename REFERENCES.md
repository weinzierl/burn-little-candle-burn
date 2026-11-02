# References

Primary sources behind the claims in the slides and notes. Checked on 2026-10-31 unless noted. Version numbers and dates from the crates.io API.

## The talk

- RustLab 2026 talk page, "Burn, little candle, burn!": https://rustlab.it/talks/burn-little-candle-burn (abstract, slot 2026-11-02 11:30, 45 min, level "Introductory and Overview")

## Candle (Hugging Face)

- Repository and README: https://github.com/huggingface/candle (README fetched from the `main` branch)
  - Self-description: "Candle is a minimalist ML framework for Rust with a focus on performance (including GPU support) and ease of use."
  - Goals ("Why should I use Candle?"): serverless inference, removing Python from production workloads.
  - Backends: CPU with optional MKL or Accelerate, CUDA, WASM. Metal: `metal` feature in `candle-core` 0.11.0 `Cargo.toml`, `Device::new_metal` in `src/device.rs`.
  - File formats: safetensors, npz, ggml, PyTorch. Quantization with the llama.cpp quantized types.
  - Browser demos: Whisper, LLaMA2 (llama2.c), T5 and others.
  - On dfdx: shapes in types prevent mismatches but "writing code can be a bit daunting for non rust experts".
- crates.io: `candle-core` 0.1.0 published 2023-08-02; 0.11.0 published 2026-06-26; 0.11.1 published 2026-10-31 (not used: too new to be verified).
- `candle-core` 0.11.0 source (crate tarball from static.crates.io):
  - `src/tensor.rs`: `pub struct Tensor(Arc<Tensor_>)`.
  - `src/cpu_backend/mod.rs`: CPU `set_seed` returns the error "cannot seed the CPU rng with set_seed".
  - `Cargo.toml`: features `accelerate`, `cuda`, `cudnn`, `metal`, `mkl`, `nccl`, `ug`; dependency `gemm` 0.19.0.
  - `src/lib.rs`: no `no_std` support.
- `candle-nn` 0.11.0 source:
  - `src/linear.rs`: "y = x@w.t() + b"; `linear()` creates the weight with shape `(out_dim, in_dim)`.
  - `src/optim.rs`: `ParamsAdamW` defaults lr 0.001, beta1 0.9, beta2 0.999, eps 1e-8, weight_decay 0.01. SGD without momentum.
  - `src/var_builder.rs`: `from_buffered_safetensors`, `from_slice_safetensors`, `unsafe fn from_mmaped_safetensors`.
- `candle-transformers` 0.11.0 `src/models/`: 122 model modules (excluding `mod.rs`, `with_tracing.rs`, `llama2_c_weights.rs`), 22 of them `quantized_*`, 100 others. `smol/` documents SmolLM2 via the Llama implementation and SmolLM3.

## Burn (Tracel AI)

- Repository and README: https://github.com/tracel-ai/burn (READMEs of `main` and `release/0.22` compared)
  - Self-description, as quoted on the slide (README of the `burn` 0.22.0 and 0.22.1 crates, identical in both): "Burn is both a tensor library and a deep learning framework, optimized for numerical computing, training and inference."
  - Backends (0.22 README): CubeCL GPU backends CUDA, ROCm, Metal, Vulkan, WebGPU; CPU backends "Cpu (CubeCL)" and Flex; Flex is pure Rust and supports Wasm and `no_std`. LibTorch deprecated in 0.22.0.
  - Training dashboard based on Ratatui; ONNX import through burn-onnx (generates Rust code); PyTorch and safetensors weights through burn-store.
  - Status: "Burn is currently in active development, and there will be breaking changes."
- Burn Book, `release/0.22` branch, sources under `burn-book/src/`:
  - `migrating-to-0.22.md`: backends selected at runtime through `Device`; `Tensor<B, D>` becomes `Tensor<D>`; "NdArray and LibTorch are deprecated, the Candle backend is removed"; burnpack records; `burn-store` export of old checkpoints.
  - `building-blocks/backend.md`: device constructors (`Device::flex()`, `Device::cpu()`, `Device::wgpu(..)`, ...), `autodiff()` on a device.
  - `building-blocks/tensor.md`, "Ownership and Cloning": operations take ownership; cloning only increments a reference count; in-place reuse when a tensor is used once. Rank checked by the type system; element type is a runtime property.
  - `custom-training-loop.md`: `GradientsParams::from_grads`, `optim.step(lr, model, grads)`, no `zero_grad`.
  - `saving-and-loading.md`: `SafetensorsStore`, `PyTorchToBurnAdapter`, `BurnToPyTorchAdapter`, `BurnpackStore`.
  - `advanced/no-std.md`: running a model with the Flex backend on a Raspberry Pi Pico 2, `embedded-alloc` heap.
- crates.io: `burn` 0.1.0 published 2022-07-27; 0.22.0 published 2026-10-06; 0.22.1 published 2026-10-20 (used); `burn-candle` last stable 0.21.0 (2026-05-07), no 0.22 release.
- Crate sources 0.22.1:
  - `burn-nn` `src/modules/linear.rs`: weight `[d_input, d_output]` by default (`LinearLayout::Row`), "O = IW + b"; `forward` panics if the last axis is not `d_input`.
  - `burn-optim` `src/optim/adam.rs`: `AdamConfig` defaults beta_1 0.9, beta_2 0.999, epsilon 1e-5.
  - `burn-flex` `Cargo.toml`: default features `std`, `simd`, `rayon`; `gemm` dependency.
  - `burn-store` `src/burnpack.rs`: `BurnpackStore::from_static`, zero-copy from static bytes. `src/safetensors/store.rs`: `from_file` memory-maps with `memmap2`; `from_bytes` takes a `Vec<u8>`.

## Models and data used in the talk (original sources)

- ResNet-18, timm weights `timm/resnet18.gluon_in1k`, Apache-2.0: https://huggingface.co/timm/resnet18.gluon_in1k (`model.safetensors`, 46 807 446 bytes; SHA-256 checked against the Hub's LFS metadata).
- all-MiniLM-L6-v2, `sentence-transformers/all-MiniLM-L6-v2`, Apache-2.0: https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2 (`model.safetensors`, 90 868 376 bytes; checked the same way).
- SmolLM2-360M-Instruct, Hugging Face (HuggingFaceTB), Apache-2.0: https://huggingface.co/HuggingFaceTB/SmolLM2-360M-Instruct (tokenizer) and the publisher's GGUF https://huggingface.co/HuggingFaceTB/SmolLM2-360M-Instruct-GGUF (`smollm2-360m-instruct-q8_0.gguf`, 386 404 992 bytes; the only GGUF the publisher offers).
- TinyStories 260K and `tok512.bin`, Andrej Karpathy, MIT: https://huggingface.co/karpathy/tinyllamas (`stories260K/`; SHA-256 of both files equal to the Hub's LFS metadata) and https://github.com/karpathy/llama2.c (`run.c`, built in this session as the reference implementation).
- Sample images: scikit-image data, cat (Stefan van der Walt) and coffee (Rachel Michetti), CC0: https://github.com/scikit-image/scikit-image/tree/main/skimage/data
- Synthetic keyword recordings: espeak-ng, https://github.com/espeak-ng/espeak-ng (generated by `burn-nostd/3-keywords/tools/synth.py`).

## no_std details checked against crate sources

- gemm-common 0.19.0, `src/cache.rs`: without std the cache sizes cannot be queried; the defaults for targets other than x86 and PowerPC give a 512 KiB L2 cache, and `src/gemm.rs` sizes its packing buffer from it. In `gemm_basic_generic`, for m and n up to 64, `mc` is the whole L2 size divided by `kc`, and without std each call allocates an `l2_slab` of `kc × mc` elements (about 512 KiB of f32); `gevv` (k ≤ 2) and `gemv` (one side of size 1, contiguous) return before that allocation.
- burn-nostd's QEMU setup: `qemu/memory.x` gives the programs 520K of RAM, the RP2350's SRAM; `qemu/src/lib.rs` sets a 256 KiB heap and records its peak.
- burn-optim 0.22.0: declares `#![cfg_attr(not(feature = "std"), no_std)]`, but `cargo build --target thumbv8m.main-none-eabihf` with `default-features = false` fails with 6 errors (`code/burn-optim-nostd-check/`, output in `code/out/burn-optim-nostd-build.txt`).
- burn-nostd's own notes and shims: `burn-nostd/shims/README.md`.

## safetensors

- Format and Rust crate: https://github.com/huggingface/safetensors (8-byte little-endian header length, JSON header with `dtype`, `shape`, `data_offsets`, then raw data). `tiny::st` implements the read side for F32 only.

## Raspberry Pi Pico 2 / RP2350

- https://www.raspberrypi.com/products/raspberry-pi-pico-2/ : "Dual Arm Cortex-M33 or dual Hazard3 RISC-V processors @ 150MHz", "520 KB on-chip SRAM", "4 MB on-board QSPI flash".
- https://www.raspberrypi.com/products/rp2350/ : "Dual Arm Cortex-M33 cores with hardware single-precision floating point and DSP instructions @ 150MHz."

### For `tinystories-usb` (checked on 2026-11-01)

- Waveshare RP2350-Touch-LCD-3.5, https://www.waveshare.com/RP2350-Touch-LCD-3.5.htm and https://docs.waveshare.com/RP2350-Touch-LCD-3.5 : "RP2350B microcontroller chip", "16MB Flash", BOOT button: "press it when resetting to enter download mode", USB Type-C "for programming", "Drag-and-drop programming using mass storage over USB"; the -C version adds a case, an OV5640 camera and a speaker. No crystal frequency and no pin numbers in the text (the pin map is an image).
- Crate sources from crates.io: embassy-usb 0.6.0 (`CdcAcmClass`, `split_with_control`; `wait_connection` waits for the endpoint, not for DTR), embassy-executor 0.10.0 (`InterruptExecutor`; `Spawner::for_current_executor`, "absolutely required" to spawn tasks that are not `Send` on an interrupt executor), embassy-sync 0.8.0 (`Pipe::try_write` can stop at the end of the ring buffer), embassy-rp 0.10.0 (default IMAGE_DEF, `rp235xa`/`rp235xb`), rp-pac 7.0.0 (`SWI_IRQ_0` = 47, `USBCTRL_IRQ` = 14).
- UF2 family 0xe48bff59 for RP2350 Arm secure images: Trusted Firmware-M's RP2350 platform page (https://trustedfirmware-m.readthedocs.io/en/tf-mv2.1.5/platform/rpi/rp2350/readme.html, `uf2conv.py ... --base 0x10000000 ... --family 0xe48bff59`) and elf2flash-core 0.1.0 (`src/boards/rp2350.rs`, "rp2350 arm secure family id"). pico-sdk's `uf2.h` and Microsoft's `uf2families.json` on GitHub could not be fetched in this session.
- picotool README (raspberrypi/picotool): `uf2 convert` with `--family`, and an optional `--abs-block` ("Add an absolute block") under "Errata RP2350-E10 Fix". `uf2.py` adds no such block, like `picotool uf2 convert` without the option.
- elf2uf2-rs 2.2.0 (crates.io, 0BSD): used only as a cross-check of `uf2.py`; it writes the RP2040 family only.
- Waveshare's examples for the board, https://github.com/waveshareteam/RP2350-Touch-LCD-3.5 (Apache-2.0 per the repository metadata), read through the GitHub API and raw.githubusercontent.com: `examples/C/01_GUI/lib/Config/DEV_Config.h` (`SPI_PORT spi0`; `LCD_RST_PIN 23`, `LCD_DC_PIN 20`, `LCD_BL_PIN 22`, `LCD_CS_PIN 21`, `LCD_CLK_PIN 18`, `LCD_MOSI_PIN 19`; `Touch_RST_PIN 24`, `Touch_INT_PIN 25`), `DEV_Config.c` (backlight as PWM on pin 22), `lib/LCD/LCD_3in5.c` (reset 100 ms high, low, high; sleep out, 120 ms; MADCTL 0x28 for landscape, 0x48 for portrait; the register sequence from 0x3A to the second 0xF0; 120 ms; inversion on; display on) and `LCD_3in5.h` (320 x 480). Used in `pico2/src/bin/tinystories-lcd/st7796.rs`.
- Waveshare schematic, https://files.waveshare.com/wiki/RP2350-Touch-LCD-3.5/RP2350-Touch-LCD-3.5.pdf (its extracted text): U1 RP2350B, U2 PY25Q128HA flash, UP1 AXP2101, Y2 12MHz; the LCD connector's VDD and IOVCC on 3V3, LEDA/LEDK with an S8050 transistor driven from LCD_BL.

## Language model background

- Y. Bengio, R. Ducharme, P. Vincent, C. Jauvin: "A Neural Probabilistic Language Model", Journal of Machine Learning Research 3 (2003), 1137-1155. The fixed-window neural language model used in the demo follows this recipe (embeddings, one hidden layer, softmax over the vocabulary), at character level.

## Tools used

- Rust 1.97.0, cargo 1.97.0 (stable, x86_64-unknown-linux-gnu); targets thumbv8m.main-none-eabihf, wasm32-wasip1.
- Typst 0.15.1 (GitHub release), just 1.59.0 (GitHub release).
- QEMU 8.2.2 (Ubuntu 24.04 package `qemu-system-arm`), machine `mps2-an505` (Arm MPS2 with AN505 FPGA image for Cortex-M33).
- Node.js 22.23.4, built-in `node:wasi` (experimental) for wasm32-wasip1 runs.
- poppler (pdffonts, pdftoppm), qpdf.

## Fonts

- Jost, Owen Earl (indestructible type*), SIL Open Font License 1.1: https://github.com/indestructible-type/Jost (files from google/fonts `ofl/jost`).
- IBM Plex Mono, IBM, SIL Open Font License 1.1, Reserved Font Name "Plex": https://github.com/IBM/plex (files from google/fonts `ofl/ibmplexmono`).
- Kumbh Sans, Saurabh Sharma (The KumbhSans Project Authors, 2020), SIL Open Font License 1.1: https://github.com/xconsau/KumbhSans (files from google/fonts `ofl/kumbhsans`). Public substitute for the headline face.
- Ergonomique, Paulo Goode (2019): https://paulogoode.com/ergonomique . Licensed under the Fontspring Desktop Font EULA 1.7.0 (text shipped with the licensed font files, not in this repository). Used only in the private build; never distributed.

## Backup slides and the MiniLM check

- Burn Book, `release/0.22` branch, `burn-book/src/performance/quantization.md`: "Burn does not currently support QAT. Only post-training quantization (PTQ) is implemented"; per-tensor and per-block quantization to 8, 4 and 2 bits "on some backends"; "No integer operations are currently supported, which means tensors are dequantized to perform the operations in floating point precision."
- Burn Book, `release/0.22`, `burn-book/src/onnx-import.md`: `burn-onnx` generates Rust code and a `.bpk` weights file during the build (`ModelGen` in `build.rs`); opset 1 to 24; "Opset coverage does not mean every configuration of an operator is supported." crates.io: `burn-onnx` 0.22.0 published 2026-10-06.
- `candle-onnx` 0.11.0 source (crate tarball): `read_file`, and `simple_eval` in `src/eval.rs`, described there as "a direct evaluation of the proto".
- `candle-core` 0.11.0 source: `src/quantized/k_quants.rs`, `QK8_0 = 32` and `BlockQ8_0 { d: f16, qs: [i8; 32] }`; the Q8_0 dot product multiplies `i8` by `i8` into `i32` sums per block, then scales; `matmul` quantizes the left-hand side with `VecDotType::from_float`. `src/device.rs`: `Device::synchronize` (nothing to do on the CPU; CUDA and Metal wait).
- `burn-tensor` 0.22.1 source, `src/device.rs`: `Device::sync` ("waiting for all pending operations to complete"), `Device::flush`, `Device::profile` (device time; the fusion backend holds a closure's last operations back, so a closure should end with a read). `burn-wgpu` and `burn-cuda` 0.22.1 `Cargo.toml`: default features include `autotune` and `fusion`. `cubecl-runtime` 0.11.3, `src/tune/mod.rs`: "Autotuning runs several candidate kernels on reference inputs and caches the fastest one per key."
- SmolLM2 GGUF statistics: read from the file header by `tools/gguf_stats.py` (`candle-batteries/out/gguf-stats.txt`).
- MiniLM reference: `onnx/model.onnx` from https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2 at revision `1110a243fdf4706b3f48f1d95db1a4f5529b4d41` (90 405 214 bytes, SHA-256 `6fd5d72fe4589f189f8ebc006442dbb529bb7ce38f8082112682524616046452`, equal to the Hub's LFS metadata); ONNX Runtime 1.29.0, tokenizers 0.23.3 and numpy 2.5.3 from PyPI. Recipe (mean over the tokens, then length 1) from the model card.

## Q&A preparation (`questions.md`)

Checked on 2026-10-31.

- RustLab 2026 (rustlab.it: home, schedule, about-us, sponsors, tickets26, job-board, the talk page and the speaker page): 1 to 3 November 2026, Savoia Regency Hotel, Bologna; day 1 workshops, days 2 and 3 talks in Main Hall, RustLab Deep Space and RustLab Deep Ocean; organized by Develer; the 2 November programme around the talk (keynote "Making the standard library less special", "Beyond cargo build" before it in the same room, Copper after it, the CHERI talk in parallel) and the day 1 workshop "Make rusty AI".
- crates.io API (version, date, licence, description, downloads): `ort` 2.0.0-rc.15 (2026-10-19, "A safe Rust wrapper for ONNX Runtime 1.31"), no stable 2.0; `tract-onnx` 0.23.9 ("Tiny, no-nonsense, self contained, TensorFlow and ONNX inference"); `tch` 0.26.0 ("Rust wrappers for the PyTorch C++ api (libtorch)"); `mistralrs` 0.8.1, whose `mistralrs-core` 0.8.1 depends on `candle-core` ^0.10.2; `llama-cpp-2` 0.1.160; `dfdx` 0.13.0 (2023-07-27, the last release); `linfa` 0.8.1; `microflow` 0.1.3 (2024-05-31); `burn-lm` 0.0.1 (2025-08-04); `cubecl` ("Multi-platform high-performance compute language extension for Rust."); `burn-dataset`, `burn-train`, `candle-datasets`; `candle-core` 0.11.1 (2026-10-31, 10 961 266 downloads), `burn` 0.22.1 and 0.23.0-pre.1 (2026-10-29, 2 054 267 downloads). Candle and Burn: MIT OR Apache-2.0.
- Hugging Face text-embeddings-inference, `Cargo.toml` and `backends/candle/Cargo.toml` (main branch): backends `candle`, `ort` and `python`; the Candle backend uses candle, candle-nn and candle-transformers, with optional flash attention and a `metal` feature.
- Candle README (main branch): "Useful External Resources" lists `candle-lora` (LoRA), `candle-vllm` (OpenAI compatible API server), `candle-tutorial` (converting a PyTorch model) and others; features: multiple GPU distribution via NCCL, flash-attention v2 as a user-defined op; "Other ML frameworks": dfdx ("writing code can be a bit daunting for non rust experts"), tch-rs ("bring in the entire torch library into the runtime. The main contributor of `tch-rs` is also involved in the development of `candle`").
- `candle-core` 0.11.0 source, `src/quantized/mod.rs`: `GgmlDType` F32, F16, BF16, Q4_0, Q4_1, Q5_0, Q5_1, Q8_0, Q8_1, Q2K to Q8K.
- MicroFlow README (matteocarnelos/microflow-rs) and arXiv 2409.19432 (University of Padova): compiler-based TinyML engine, `no_std` runtime, TensorFlow Lite models only, quantized operators; tested on ESP32, ATSAMV71, nRF52840, LM3S6965 and ATmega328.
- tracel-ai/models README: official Burn ports (ALBERT, MiniLM, MobileNetV2, SqueezeNet, ResNet, RoBERTa, YOLOX) and community ports (Llama 2, Whisper, Stable Diffusion and more). tracel-ai/burn-lm README: "Burn-LM has been archived and is no longer maintained", a new Burn powered engine announced.
- `karpathy/tinyllamas` on Hugging Face: `stories15M.bin` 60 816 028 bytes.

## Slide style

- `seventies`: Ludwig Weinzierl's Typst slide kit (1970s Swiss, full-bleed flat colour, one continuous line), used for colours, the line, the candle and the code colours (`slides/code.tmTheme` is the kit's `seventies.tmTheme`).
- The line after Osvaldo Cavandoli's *La Linea* (1971), as an homage; no drawing from the series is reproduced.
- English Wikipedia, "Osvaldo Cavandoli" (read 2026-11-01), for backup slide 51: 1 January 1920 to 3 March 2007, pen name Cava. The still from La Linea on that slide comes from Ludwig.

## Checked on 2 November 2026 (second round of review)

- Burn README, `main` branch (raw.githubusercontent.com/tracel-ai/burn/main/README.md): the tagline "A tensor library and deep learning framework for numerical computing, training and inference." The `v0.22.0` README: "Burn is both a tensor library and a deep learning framework, optimized for numerical computing, training and inference".
- SmolLM2-360M-Instruct `tokenizer_config.json` (huggingface.co/HuggingFaceTB/SmolLM2-360M-Instruct): the chat template adds `<|im_start|>system\nYou are a helpful AI assistant named SmolLM, trained by Hugging Face<|im_end|>` when the first message is not a system message.
- Burn Book, `migrating-to-0.22.md` at `v0.22.0`: "NdArray and LibTorch are deprecated, the Candle backend is removed"; the Cargo features `candle`, `candle-cuda`, `candle-metal`: removed. Tracel's release post (tracel.ai/blog/release-0.22.0, 6 October 2026): "Candle has been removed, while NdArray and LibTorch are deprecated." Neither gives a reason.
- `burn-candle` on lib.rs: "It is still in alpha stage, not all operations are supported."
- Rust project goals update, April 2026 (blog.rust-lang.org, 18 May 2026): `std::autodiff` "is now partly in CI"; users "can now download libEnzyme artifacts, place them locally in the right spot for their toolchain, and then use autodiff on their nightly compiler"; a rustup component is planned once macOS is supported.
- `burn-nostd/pico2/src/bin/tinystories-lcd/main.rs`: the status line computes tenths as `tokens * 10_000 / model_ms` (integer division) and seeds story `round` with `round + 1`.
