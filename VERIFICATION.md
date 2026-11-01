# Verification

What was built, run and checked for "Burn, little candle, burn!" (RustLab 2026), and what was not. All runs on 2026-10-31 in a Linux x86-64 cloud VM (2 vCPU, 7.8 GiB RAM, no GPU), unless stated. Version 3 of the talk: the content of version 2 (rebuilt around Ludwig's own examples, `candle-batteries` and `burn-nostd`, which came from earlier chats and were verified again here), set in Ludwig's `seventies` slide style. The restyle changed no code, captured output or number (word by word comparison of the two public decks with pdftotext); wording changed in the footers, the tags, the intro of the steps slide and on the end slide. Version 3.1 adds, after a comparison with another draft of the talk: a fourth, off-topic query on the Bologna slide, one sentence on padding on the MiniLM slide, three backup slides, and an independent check of the MiniLM numbers (below). Version 3.2 follows outside feedback on the slides: more precise wording (hardware status, what was compared, what is synthetic), heap numbers in QEMU that are now true peaks (below), a QR code on the end slide, and "Grazie mille". `questions.md` (31 October) prepares the Q&A: 55 questions, most likely first; its facts come from the files here, the sizes below, and the sources listed in REFERENCES.md. On 1 November: `tinystories-usb`, step 4 for an RP2350 board without a debug probe, with the stories on the board's own USB port, and `tinystories-lcd`, the same with the stories also on the screen of the Waveshare RP2350-Touch-LCD-3.5 (below). Ludwig reported that `tinystories-usb` ran on his Waveshare board; its log is not yet captured here. Later on 1 November, after feedback: 40pt between the two columns of "What it took" (slide 40, the only page that changed), and recipes and scripts to flash and read the board (`just uf2`, `just board-log`, `just board-check`); the private build can take the Ergonomique files from any folder (`ERGONOMIQUE_DIR`), so they need not be copied into the repository.

## The talk

| | |
|---|---|
| Slides | 47 (6 of them section dividers), plus 4 backup slides for questions; 16:9, 960 x 540 pt |
| Planned speaking time | 39:50 of a 45 minute slot |
| Skippable | 4:50 over 5 slides (marked SKIP in the notes) |
| Topics | what a framework does; Candle and Burn in one slide each; the Burn 0.22 API change; tensors, shapes, ranks and errors; Candle with models from the Hub (ResNet-18, MiniLM, SmolLM2-360M); sin(x) trained in both frameworks from one start file; Burn without std in four steps (inference from flash, training on the device, keyword spotting, TinyStories 260K); what no_std needed; when to use which |
| Main demos | `candle-batteries` (pretrained models, Candle's strength) and `burn-nostd` (no_std down to a Cortex-M33, Burn's), joined by the sin(x) comparison |
| Why | they are Ludwig's own examples; together they cover the abstract (real code in both, a comparable model in each, backends, server, edge, training, WASM); every number on the slides is reproducible from the captured files |

## Build and run results

The slides read the captured files directly: `candle-batteries/out/`, `burn-nostd/out/`, `code/out/`. `tools/capture-examples.sh` regenerates the first two; the last capture ran on an otherwise idle VM.

### Part 1: `candle-batteries` (Candle 0.11.0, hf-hub 1.0.0, Rust 1.97.0, CPU)

| Program | Result | Output |
|---|---|---|
| build | `cargo build --release --locked`, 7 min 59 s, no warnings | |
| `tensors` | ran; matmul result and the shape error as a value | `tensors.txt` |
| `classify` cat.jpg | 81.7 % Egyptian cat, 9.7 % tiger cat, 8.3 % tabby | `classify-cat.txt` |
| `classify` coffee.jpg | 95.5 % espresso | `classify-coffee.txt` |
| `similar`, four queries | eat: tortellini 0.36; rain: porticoes 0.30; how old: university 0.34; off-topic "How do I reset my router?": university 0.05 (run later the same day, only this query). Rerun on 1 November with "Fast trains run to Florence." instead of "Trains leave for Florence hourly." (a reviewer: fast trains run several times an hour; 37 minutes, English Wikipedia): the same top sentence for all four queries; the ONNX Runtime check again PASS, largest score difference 2.71e-07 | `similar-*.txt` |
| MiniLM reference | official ONNX export of all-MiniLM-L6-v2, same revision, SHA-256 equal to the Hub's metadata, run with ONNX Runtime 1.29.0 one sentence at a time without padding; against `similar`'s batched, padded and masked vectors (`tools/minilm-reference`, same `embed` code): largest difference 1.7e-7 in a vector coordinate, 2.7e-7 in a score; all 20 scores on the slide identical | `tools/minilm-reference/result.txt` |
| SmolLM2 GGUF | header read by `tools/gguf_stats.py`: 361 758 720 weights in Q8_0 (384 368 640 bytes), 62 400 in F32 | `gguf-stats.txt` |
| `ask` | one-sentence answer, 31 tokens, 4.2 tokens/s; same text in two runs (seed 42) | `ask.txt`, `ask.err` |
| models | downloaded from the original repositories with hf-hub; SHA-256 of each LFS file equal to the Hub's metadata | `models.txt` |
| offline | with a warm cache, `similar`, `classify` and `ask` ran with the endpoint unreachable, with the proxy dead, and with `HF_HUB_OFFLINE=1` | |

Change against the chat version: `ask` used `bartowski/SmolLM2-360M-Instruct-GGUF` (4-bit, a third-party conversion). It now uses the publisher's `HuggingFaceTB/SmolLM2-360M-Instruct-GGUF` (`smollm2-360m-instruct-q8_0.gguf`, 8-bit), the only GGUF the publisher offers. The chat's stand-in Hub server and npm-converted weights were not used.

### Part 2: sin(x) in both frameworks (`code/`, Candle 0.11.0, Burn 0.22.1)

| Program | Result | Output |
|---|---|---|
| `candle_hello`, `burn_hello` | ran | `candle-hello.txt`, `burn-hello.txt` |
| `candle_errors` | ran, `Err` printed, exit 0 | `candle-errors.txt` |
| `burn_errors` | panicked as intended, exit 101 | `burn-errors.txt` |
| `burn_rank_error` | compile error E0308 as intended | `burn-rank-error.txt` |
| `candle_sine`, `burn_sine` | loss printed before the update at steps 0, 250, ..., 1750 and once after the loop (row 2000): equal to 6 decimals except the first row (6.588534 vs 6.588533; most likely a different summation order in Burn's SIMD code, not isolated); largest error of the Burn model over the 256 training points 0.0075 (`sine-burn.csv`) | `candle-sine.txt`, `burn-sine.txt`, `sine-*.csv` |
| sine timing, five runs each | Candle 526 to 685 µs/step, Burn 540 to 683 µs/step | `sine-timing.txt` |
| `candle-nostd-check` | build for thumbv8m.main-none-eabihf fails as expected (E0463, getrandom needs `std`) | `candle-nostd-build.txt` |
| `burn-optim-nostd-check` | burn-optim 0.22.0 with `default-features = false` for thumbv8m.main-none-eabihf: fails, 6 errors (an std-only module used unconditionally, missing `vec!` and `String` imports) | `burn-optim-nostd-build.txt` |

The first version's character language model (trained by Burn, run by Candle, tiny, WebAssembly and two Cortex-M33 firmwares, eight byte-identical texts) is still in `code/` with its captured output, but no longer on the slides.

### Part 3: `burn-nostd` (Burn 0.22.0, Rust 1.95.0 from its `rust-toolchain.toml`)

| Item | Platform | Result | Output |
|---|---|---|---|
| build | x86-64 | `cargo build --release --locked`, 4 min 16 s | |
| `cargo test --release --locked` | x86-64 | 4 tests pass, among them TinyStories against llama2.c's text | |
| `sine` | x86-64, no_std | 1-16-16-1 ReLU network on [0, 2π], 321 parameters, separate from the sin(x) comparison; the program prints "2564 bytes of weights": the size of the whole Burnpack file (the 321 f32 values are 1 284 bytes of it); max error 0.0199 at 25 points, 4 µs per inference | `sine.txt` |
| `sine-train` | x86-64, no_std | reproduces `1-sine/weights/sine.bpk` byte for byte (SHA-256 a0826dac…cdcb2 before and after) | `sine-train.txt` |
| `gesture` | x86-64, no_std | 20 examples, 15 epochs in 13 ms, 100/100 new windows; training and test windows come from the same synthetic generator | `gesture.txt` |
| `keywords` | x86-64, no_std | 20 synthetic recordings, trained in 167 ms, 11/12 words; training and test clips from one espeak-ng voice (en-us) with random speed, pitch, gain, offset and noise | `keywords.txt` |
| `tinystories` | x86-64, no_std | same story as llama2.c, 76 tokens, 6 909 tokens/s | `tinystories.txt` |
| reference | x86-64 | llama2.c `run.c` (karpathy/llama2.c master, built with gcc -O3), same files, `-t 0 -n 80`: identical text | |
| model files | | `stories260K.bin` and `tok512.bin`: SHA-256 equal to the Hub's metadata for karpathy/tinyllamas | |
| QEMU `sine` | thumbv8m.main-none-eabihf, mps2-an505, RAM limited to 520 KiB in `memory.x`, heap 256 KiB | max error 0.0176 at 101 points; heap in use at the end 3 580 bytes, **peak 7 888 bytes** | `qemu-sine.txt` |
| QEMU `gesture` | same | 100/100; heap in use after training 26 304 bytes, **peak 42 468 bytes** | `qemu-gesture.txt` |
| QEMU `keywords` | same | 11/12, **heap peak 217 340 bytes** | `qemu-keywords.txt` |
| QEMU `tinystories-usb` | same | the USB firmware's first four stories, same prompts, temperatures and seeds: the text a board should print; the first, greedy story begins with llama2.c's text (exit 0); **stack peak 7 968 bytes** (stack painted with a pattern at the start, the lowest overwritten word found at the end), heap peak 184 804 bytes | `qemu-tinystories-usb.txt` |
| QEMU `tinystories` | same | same text as llama2.c (compared as text), **heap peak 184 036 bytes**; context 128 positions, KV cache 163 840 bytes (1 280 bytes per position from the model header: 5 layers, 4 KV heads of 8 dimensions, keys and values, f32); at the header's 512 positions it would be 655 360 bytes | `qemu-tinystories.txt` |
| WebAssembly modules | wasm32-unknown-unknown | built by `cargo web --out` (2 min 8 s) | |
| demo pages | headless Chromium (Playwright) | sine: trained in the page, 2 000 epochs; gesture: 20 simulated examples, all 4 simulated gestures recognized; keywords: sample voice, 11/12 (first "yes" heard as "left"); tinystories: same story start, 214 tokens/s. 1 November, night: six defects from an external functional test of the deployed pages (ChatGPT, report and evidence from Ludwig) fixed in the page scripts, the WebAssembly unchanged: Start over during training (gesture, keywords) no longer traps the module (every reset bumps a generation; training loops, recordings, sample loading and playback stop when it changed), a Rust panic now shows an error and stops further calls; prompts with characters outside the vocabulary (`Grüße 😊`) decode as one UTF-8 stream; a new sample voice clears the old results; word labels with quotes survive Start over; Start over stops the sample sentence and keeps playback off. Each sequence from the report replayed in headless Chromium (Playwright): all fail or abort with the published pages and pass with the fixed ones; `é` and the default prompt unchanged; sine and index load without errors. The step 4 page now says 4.3 tokens/s on a real RP2350 board instead of "not yet on a board" | screenshots in `slides/media/` |
| Pico 2 firmware | thumbv8m.main-none-eabihf, Embassy | all four programs build (`cargo build --release --locked -j 1`; with parallel jobs, while other builds ran, the linker was killed by signal 9, most likely out of memory); built again after the version 3.2 comment change in `pico2/src/lib.rs` (exit 0, 5 min 31 s, no warnings); on 1 November all five programs, with `tinystories-usb` (exit 0, 2 min 36 s with `-j 2` on an idle VM, no warnings; the four older programs grew by 32 to 40 bytes, most likely because panic locations hold the absolute build path: the `sine` firmware's `.rodata` contains the path of `1-sine/src/lib.rs`, now in the repository instead of a work copy); again with `tinystories-lcd` and embedded-graphics 0.8.2 (all six programs, exit 0, 4 min 03 s, no warnings); **a Pico 2 itself has not run any of them**; `tinystories-usb` and `tinystories-lcd` ran on an RP2350B board (next rows) | `pico2-size.txt` |
| `tinystories-usb` firmware | thumbv8m.main-none-eabihf, Embassy, embassy-usb 0.6.0 | step 4 with the stories on the board's USB port (CDC-ACM serial); USB in an interrupt executor (SWI_IRQ_0) above the model in thread mode; no GPIO used; built for the RP2350A (embassy-rp 0.10's `rp235xa` and `rp235xb` features differ only in pins: GPIO count, pin types, ADC channels; checked in its source). Checked in the ELF: initial stack pointer 0x20080000, reset vector 0x1000013d; the `USBCTRL_IRQ` and `SWI_IRQ_0` (IRQ 47) vectors point to their handlers; IMAGE_DEF block at 0x10000114 (markers 0xffffded3 and 0xab123579, image type 0x1021: secure Arm executable for the RP2350); flash image 2 467 992 bytes in the UF2 built here before embedded-graphics was added to `pico2/Cargo.toml` (the same sources now give a `.text` 2 296 bytes larger, no dependency changed its features, checked with `cargo tree -e features`); **ran on Ludwig's Waveshare RP2350-Touch-LCD-3.5 (RP2350B, 150 MHz)**: first on 1 November afternoon, in a UF2 he built himself (his report); then on 1 November evening from a fresh build of the published sources (burn-little-candle-burn 6b21555), flashed with `just flash usb`, log taken with `just log`: the four stories have the same text as QEMU's (`check_log.py`), 124 tokens in 28 509, 28 581 and 28 580 ms and 120 in 28 577 ms, 4.3 tokens/s; heap 179 228 bytes after loading (the firmware prints the allocator's `used()`, not a peak). Ludwig's terminal transcript of the session shows the commands and the same output | `pico2-size.txt`, `board-tinystories-usb.txt` |
| board scripts | Linux x86-64 (this VM) | `pico2/board_log.py` (`just board-log`): opens the port, raw mode, shows and saves the text, stops after 4 stories; tested on a pseudo terminal with written test text (stopped by itself after the requested 2 stories, exit 0). `pico2/check_log.py` (`just board-check`): stories after the last header against `out/qemu-tinystories-usb.txt`, with tokens per second; tested on logs made from the QEMU transcript in both firmware formats (all match, exit 0) and with one changed word (reported with a diff, exit 1). Run by Ludwig on both board logs (all complete stories match). `board_log.py` counted the end of the story the screen version was writing when the port opened, so it stopped after 3 complete stories of the session; it now counts from the session's header (tested on a pseudo terminal with the board's own log replayed: 4 stories, all matching) | |
| `tinystories-lcd` firmware | same, plus embedded-graphics 0.8.2 | the stories on the board's screen from power-up (480 x 320, landscape; prompt gold, model text cream; footer: while writing, "writing" left and "weinzierlweb.com" right (1 November, night, for the board handed round in the talk; host preview checked, built without warnings); after each story, tokens per second of the model, time spent drawing and on USB subtracted), and over USB as `tinystories-usb`; ST7796 driver of our own: pins (SPI0 clock 18, data 19; DC 20, CS 21, backlight 22, reset 23), reset timing and register values from Waveshare's example (`examples/C/01_GUI`, `DEV_Config.h`, `LCD_3in5.c`), SPI at 37.5 MHz; vector table and IMAGE_DEF checked as above; UF2 9 700 blocks, decoded equal to `llvm-objcopy -O binary`. Layout checked on the host: `screen.rs` unchanged on a framebuffer, the four QEMU stories fed byte by byte and in one piece give the same pixels; 6 to 8 of 10 lines per story, scrolling tested with all four in a row. **Ran on Ludwig's Waveshare board (1 November, evening)**, from a fresh build of the published sources: the stories appear on the screen and keep coming (the four prompts in turn; opening the USB port starts again at story 1); photos and a video by Ludwig. Over USB at the same time: 3 complete stories after the header, the same text as QEMU's, 124 tokens each in 28 990 to 29 058 ms, 28 817 to 28 893 ms of it in the model (4.3 tokens/s) | `pico2-size.txt`, `board-tinystories-lcd.txt` |
| UF2 file | `pico2/uf2.py` | 9 641 blocks of 256 bytes, 0x10000000 to 0x1025a900, family 0xe48bff59 (RP2350 Arm secure; the value in Trusted Firmware-M's RP2350 documentation and in elf2flash-core 0.1.0; pico-sdk's `uf2.h` on GitHub could not be fetched here); decoded, equal byte for byte to `llvm-objcopy -O binary` of the ELF, zeros after it; the same blocks as elf2uf2-rs 2.2.0 makes, except the family field (elf2uf2-rs writes only the RP2040 family); `uf2.py` reproduces elf2uf2-rs's two test UF2 files byte for byte (RP2040 family) | |
| shims | x86-64 | without the `[patch.crates-io]` shims the desktop build fails: E0152 duplicate lang item `panic_impl`, std pulled in through `web_time` | `no-shims-build.txt` |
| gemm buffer | source | gemm-common 0.19.0 `src/cache.rs`: without std, on non-x86, non-PowerPC targets the default L2 cache is 512 KiB; `src/gemm.rs`, `gemm_basic_generic`: for m and n up to 64, `mc` comes from the whole L2 size, and without std every call allocates an `l2_slab` of `kc × mc` elements, about 512 KiB of f32; products with k ≤ 2 (`gevv`) or with one side of size 1 and contiguous strides (`gemv`) return before that allocation | |

Heap peaks: the QEMU programs' global allocator now wraps embedded-alloc's `LlffHeap` and keeps the largest `used()` seen after any allocation (`AtomicUsize::fetch_max`), and every program prints that peak. Version 3.1 sampled `used()` instead: `sine` and `gesture` once at the end (3 580 and 26 304 bytes), `keywords` after every 20 ms chunk while listening, which left out training (172 772 bytes), and `tinystories` after every generated token (181 660 bytes). All four QEMU programs were rebuilt and run again with this change (exit 0, same results otherwise; `out/runs.log`).

Never run anywhere: a real Raspberry Pi Pico 2, a real microphone or IMU, macOS, a phone's motion sensor. On another RP2350 board, Ludwig's Waveshare RP2350-Touch-LCD-3.5, `tinystories-usb` and `tinystories-lcd` have run (logs in `burn-nostd/out/board-*.txt`); steps 1 to 3 have not run on any board.

### Sizes (measured on 31 October for `questions.md`)

| What | Size | How |
|---|---|---|
| Candle programs, x86-64 release | tensors 1 856 472 bytes (stripped 1 381 288), classify 23 242 024 (17 510 840), similar 24 635 528 (18 636 880), ask 25 510 056 (19 343 056) | `stat` on `candle-batteries/target/release/*`, `strip -o` copies |
| burn-nostd WebAssembly modules (`cargo web --out`, opt-level "s", LTO) | sine 1 867 725 bytes (gzip -9: 411 572), gesture 1 611 899 (348 668), keywords 1 641 193 (354 337), tinystories 2 316 502 (1 252 431) | the build of 31 October 14:25 |
| Pico 2 firmware (fat LTO, release; build of 1 November) | `.text` 1 334 264 to 1 791 572 bytes; tinystories `.rodata` 1 106 120; `.bss` 265 576 to 285 848 (includes the 256 KiB heap); tinystories-usb `.text` 1 360 792, `.rodata` 1 108 968, `.bss` 271 736; tinystories-lcd `.text` 1 370 560 (with the footer link, 1 November night), `.rodata` 1 111 960, `.bss` 272 696 | `burn-nostd/out/pico2-size.txt` |
| Next llama2.c checkpoint | `stories15M.bin` 60 816 028 bytes | Hugging Face API, `karpathy/tinyllamas` file listing |

## PDF checks

`qpdf --check` on both decks and both notes files: no syntax or stream encoding errors. `pdfinfo`: decks 51 pages (47 and 4 backup; 49 before the board slide and the La Linea backup), 960 x 540 pt, not encrypted; notes 50 pages.

Review by other LLMs (1 November, night; Ludwig passed on two reports): fixed: slide 21's train sentence (now "Fast trains run to Florence.", rerun and rechecked, see `similar`); slide 45 ("the same `Module` trains on a laptop" was wrong: the same no_std crates train on a desktop and an emulated M33, the language model ran on a real RP2350); slide 49 says 384 MB of weights and the 386 MB file; slide 31 "the first loss differs" and step numbers as 2 000; slide 34 "limited to the Pico 2's 520 KiB of RAM, 256 KiB of it heap" (the emulated board itself has more); slide 7 says 0.11.0, the version that ran (candle-core and candle-transformers 0.11.1 came out on 31 October, crates.io), and drops the model count, which stays on slide 24 as "0.11.0 ships 100 ... and 22"; slide 44 "Learner built in; Candle trains too"; slide 26's last sentence; slide 23's note on two lines; slide 41's first row shortened; slide 35 "bytes of Burnpack, 1 284 of them weights" (decoded the file: header 471 bytes padded to 512, six tensors each starting on a 256-byte boundary, 1 284 bytes of f32 data); part 3 tags all "Burn no_std", slide 20's tag names the model; command labels (`$ cargo classify ...`, `$ cargo ask`, `$ cargo build`) as code, not letter-spaced capitals; curly apostrophe on slide 37; MiniLM scores with a real minus sign, "0.00" for "-0.00" and right-aligned. Checked and left: the Burn quote on slide 8 is verbatim from the current README (one review said otherwise; fetched again); slide 36 already says "built, not yet run". Backup slide 51, new on 1 November (night): "Grazie, Cava", one sentence: the design of the slides is a tribute to Osvaldo Cavandoli and La Linea. The still from La Linea (`slides/media/la-linea.jpg`, 624 x 458, credited "La Linea © Osvaldo Cavandoli") was supplied by Ludwig, who decided to use it. Slide 40, new on 1 November (late): "The same model on a real chip", Ludwig's photo of `tinystories-lcd` on his Waveshare board (story 11, temperature 0.8; cropped and scaled to 1 400 x 1 050, saved without metadata as `slides/media/board-tinystories.jpg`). Ludwig's 8.8 s video of the same evening (terminal with `just board-log`, then the screen starting story 3 token by token): `slides/media/video/board.mp4` (sound and metadata removed, H.264, 0.9 MB) and, cropped to the board from 4.5 s on, `burn-nostd/media/board.gif` (0.7 MB) in the burn-nostd README, with the rate and token count read from `burn-nostd/out/board-tinystories-usb.txt`. Every later page moved by one; compared with the previous delivery, those pages differ only in the page number (pixel comparison of everything above the footer, both editions). Slide 41 ("What it took", 1 November, then slide 40): the table's columns are now 1.32 to 1, with 20pt inner padding on each side, so the two columns' text is 40pt apart (it was 12pt); the code `[patch.crates-io]` moves to its own line instead of breaking. Every left-column line stays as it was, the table is as tall as before. Checked: both decks rebuilt, 49 pages; rendered at 40 dpi, only page 40 differs from the version Ludwig checked (`rustlab-source-2.zip`); pdfminer sizes: no word smaller (1 823 words compared with that version, 1 443 with version 2); nothing on the line or in the margins (lowest text 458.4 pt, both editions); notes match the deck (49 slides); both notes files rebuilt (50 pages), `speaker-notes.md` byte-identical; public PDFs embed all fonts and no Ergonomique.

`pdffonts presentation-public.pdf`:

```
name                                 type              encoding         emb sub uni object ID
------------------------------------ ----------------- ---------------- --- --- --- ---------
TPENFQ+Jost-Regular                  CID TrueType      Identity-H       yes yes yes   1095  0
UXIVPW+KumbhSans-Regular             CID TrueType      Identity-H       yes yes yes   1098  0
RPDWTR+Jost-Regular                  CID TrueType      Identity-H       yes yes yes   1101  0
AGHILK+Jost-Regular                  CID TrueType      Identity-H       yes yes yes   1104  0
GQXAFE+IBMPlexMono-Regular           CID TrueType      Identity-H       yes yes yes   1107  0
OQYYDY+Jost-Regular                  CID TrueType      Identity-H       yes yes yes   1110  0
WXVEQS+KumbhSans-Regular             CID TrueType      Identity-H       yes yes yes   1113  0
YLFUDI+IBMPlexMono-Bold              CID TrueType      Identity-H       yes yes yes   1116  0
VMVLLJ+IBMPlexMono-Italic            CID TrueType      Identity-H       yes yes yes   1119  0
```

`pdffonts presentation-private.pdf`:

```
name                                 type              encoding         emb sub uni object ID
------------------------------------ ----------------- ---------------- --- --- --- ---------
TPENFQ+Jost-Regular                  CID TrueType      Identity-H       yes yes yes   1095  0
JRSYVE+Ergonomique-Bold-Identity-H   CID Type 0C       Identity-H       yes yes yes   1098  0
RPDWTR+Jost-Regular                  CID TrueType      Identity-H       yes yes yes   1101  0
AGHILK+Jost-Regular                  CID TrueType      Identity-H       yes yes yes   1104  0
GQXAFE+IBMPlexMono-Regular           CID TrueType      Identity-H       yes yes yes   1107  0
OQYYDY+Jost-Regular                  CID TrueType      Identity-H       yes yes yes   1110  0
BUIAUJ+Ergonomique-Black-Identity-H  CID Type 0C       Identity-H       yes yes yes   1113  0
YLFUDI+IBMPlexMono-Bold              CID TrueType      Identity-H       yes yes yes   1116  0
VMVLLJ+IBMPlexMono-Italic            CID TrueType      Identity-H       yes yes yes   1119  0
```

All fonts embedded as subsets. Jost and Kumbh Sans are variable fonts; pdffonts lists every used weight under the default instance's name. Ergonomique: Bold (titles) and Black (section numbers), the weights the style uses. Neither build printed a warning.

Visual check: every slide of both editions rendered to PNG with pdftoppm and inspected, again after the switch to the `seventies` style (full-bleed colour, the line on a fixed horizon at 468 pt, content kept above it) and again for version 3.2. No text is smaller than in version 2: every word that appears on the same slide in a version 3.2 deck and the version 2 public deck was compared with pdfminer (1 443 words in each edition, none smaller), and the text sizes below 17 pt are the same as in version 2 (tags, labels and footer at 13 and 14 pt, code inside notes at 13.6 pt, dense terminal output at 15 and 16 pt; inline code on the backup slides at 16.8 pt). Where the horizon left less room, spacing and layout changed instead (the opening comparison, the four steps as one staircase with wider treads, the inference step). A word position check (pdftotext -bbox) finds no text in the band of the line or outside the side margins (lowest text above the line at 458.4 pt, the line starts at 464.5 pt). Contrast (WCAG formula): cream text on teal 5.1, plum 6.9, slate 9.8, brick 4.3, olive 4.1; black text on ochre 5.9; the code colours on their slate or black panels 4.1 or more. Code is cut from the source files; lines too long for the slide are wrapped for display with a visible `↪`. Screenshots of the demo pages are images; all slide text is text.

QR codes: as large as in version 2 (170 and 220 pt), on cream fields that give each code a quiet zone of at least 4 modules. Both decode to their URLs with OpenCV 5.0 (`https://github.com/weinzierl/burn-little-candle-burn`, `https://weinzierl.github.io/burn-nostd/`), as SVG and on the rendered slides of both editions (150 dpi; each code on its own with the classic detector, both together with the Aruco detector). The end slide repeats the repository code at 150 pt on its own cream field with the same quiet zone; on the rendered end slide of both editions the Aruco detector decodes it from the full slide and the classic detector from the code cropped out. Neither target exists yet (see the checklist).

`pdfinfo` (poppler 24.02.0) prints "Syntax Error: Suspects object is wrong type (boolean)" for every Typst PDF here; the file has `/MarkInfo << /Marked true /Suspects false >>`, which the PDF specification allows; qpdf reports no errors.

Text checks: no en dash or em dash in slides, notes, README or docs (scripted check); thousands separators are spaces; decimals use a dot.

## Source package (`rustlab-source.zip`)

292 files in one top folder, `burn-little-candle-burn/`. The packaging script leaves out build output (all `target/` folders), private PDFs, a downloaded `tools/minilm-reference/model.onnx` and everything in `fonts/private/` except its README and `.gitignore`.

Ergonomique is not in the package. Checked on the final zip:

- `unzip -Z1 rustlab-source.zip | grep -i '\.otf$'`: no match.
- `unzip -Z1 rustlab-source.zip | grep -i ergonomique`: no match.
- `pdffonts` on the two PDFs in the zip (`presentation-public.pdf`, `speaker-notes.pdf`): no Ergonomique font; the byte string "Ergonomique" does not occur in either file.
- Every extracted file checked for a font signature (OpenType, TrueType, WOFF, WOFF2, collection): only the eight `.ttf` files below.
- Unzipped into an empty folder: `unzip -t` finds no errors; `just public` and `just check-notes` run there; the rebuilt deck has 49 pages and the same text (pdftotext) as the delivered `presentation-public.pdf`; `just private` stops with the message that the font files are missing.
- All font files in the zip:

```
fonts/private/.gitignore
fonts/private/README.md
fonts/public/IBMPlexMono-Bold.ttf
fonts/public/IBMPlexMono-Italic.ttf
fonts/public/IBMPlexMono-Medium.ttf
fonts/public/IBMPlexMono-Regular.ttf
fonts/public/IBMPlexMono-SemiBold.ttf
fonts/public/Jost-Italic[wght].ttf
fonts/public/Jost[wght].ttf
fonts/public/KumbhSans[YOPQ,wght].ttf
fonts/public/OFL-IBMPlexMono.txt
fonts/public/OFL-Jost.txt
fonts/public/OFL-KumbhSans.txt
```

<details><summary>Complete file list</summary>

```
.gitignore
FONTS.md
LICENSE-APACHE
LICENSE-MIT
README.md
REFERENCES.md
VERIFICATION.md
burn-nostd/.cargo/config.toml
burn-nostd/.github/workflows/ci.yml
burn-nostd/.github/workflows/pages.yml
burn-nostd/.gitignore
burn-nostd/1-sine/Cargo.toml
burn-nostd/1-sine/src/lib.rs
burn-nostd/1-sine/weights/sine.bpk
burn-nostd/2-gesture/Cargo.toml
burn-nostd/2-gesture/src/lib.rs
burn-nostd/2-gesture/src/synth.rs
burn-nostd/3-keywords/Cargo.toml
burn-nostd/3-keywords/src/frontend.rs
burn-nostd/3-keywords/src/lib.rs
burn-nostd/3-keywords/src/segmenter.rs
burn-nostd/3-keywords/testdata/README.md
burn-nostd/3-keywords/testdata/enroll.i16
burn-nostd/3-keywords/testdata/stream.i16
burn-nostd/3-keywords/tools/synth.py
burn-nostd/4-tinystories/Cargo.toml
burn-nostd/4-tinystories/model/README.md
burn-nostd/4-tinystories/model/stories260K.bin
burn-nostd/4-tinystories/model/tok512.bin
burn-nostd/4-tinystories/src/lib.rs
burn-nostd/4-tinystories/src/tokenizer.rs
burn-nostd/Cargo.lock
burn-nostd/Cargo.toml
burn-nostd/LICENSE-APACHE
burn-nostd/LICENSE-MIT
burn-nostd/README.md
burn-nostd/adam/Cargo.toml
burn-nostd/adam/src/lib.rs
burn-nostd/desktop/Cargo.toml
burn-nostd/desktop/src/bin/gesture.rs
burn-nostd/desktop/src/bin/keywords.rs
burn-nostd/desktop/src/bin/sine-train.rs
burn-nostd/desktop/src/bin/sine.rs
burn-nostd/desktop/src/bin/tinystories.rs
burn-nostd/desktop/src/lib.rs
burn-nostd/media/board.gif
burn-nostd/media/gesture.gif
burn-nostd/media/keywords.gif
burn-nostd/media/sine.gif
burn-nostd/media/tinystories.gif
burn-nostd/out/board-tinystories-lcd.txt
burn-nostd/out/board-tinystories-usb.txt
burn-nostd/out/gesture.txt
burn-nostd/out/keywords.txt
burn-nostd/out/no-shims-build.txt
burn-nostd/out/pico2-size.txt
burn-nostd/out/qemu-gesture.txt
burn-nostd/out/qemu-keywords.txt
burn-nostd/out/qemu-sine.txt
burn-nostd/out/qemu-tinystories-usb.txt
burn-nostd/out/qemu-tinystories.txt
burn-nostd/out/runs.log
burn-nostd/out/sine-train.txt
burn-nostd/out/sine.txt
burn-nostd/out/tinystories.txt
burn-nostd/pico2/.cargo/config.toml
burn-nostd/pico2/Cargo.lock
burn-nostd/pico2/Cargo.toml
burn-nostd/pico2/board_log.py
burn-nostd/pico2/build.rs
burn-nostd/pico2/check_log.py
burn-nostd/pico2/memory.x
burn-nostd/pico2/src/bin/gesture.rs
burn-nostd/pico2/src/bin/keywords.rs
burn-nostd/pico2/src/bin/sine.rs
burn-nostd/pico2/src/bin/tinystories-lcd/main.rs
burn-nostd/pico2/src/bin/tinystories-lcd/screen.rs
burn-nostd/pico2/src/bin/tinystories-lcd/st7796.rs
burn-nostd/pico2/src/bin/tinystories-usb.rs
burn-nostd/pico2/src/bin/tinystories.rs
burn-nostd/pico2/src/lib.rs
burn-nostd/pico2/uf2.py
burn-nostd/qemu/.cargo/config.toml
burn-nostd/qemu/Cargo.lock
burn-nostd/qemu/Cargo.toml
burn-nostd/qemu/build.rs
burn-nostd/qemu/memory.x
burn-nostd/qemu/src/bin/gesture.rs
burn-nostd/qemu/src/bin/keywords.rs
burn-nostd/qemu/src/bin/sine.rs
burn-nostd/qemu/src/bin/tinystories-usb.rs
burn-nostd/qemu/src/bin/tinystories.rs
burn-nostd/qemu/src/lib.rs
burn-nostd/rust-toolchain.toml
burn-nostd/serve/Cargo.toml
burn-nostd/serve/src/main.rs
burn-nostd/shims/README.md
burn-nostd/shims/wasm-bindgen-futures/Cargo.toml
burn-nostd/shims/wasm-bindgen-futures/src/lib.rs
burn-nostd/shims/web-time/Cargo.toml
burn-nostd/shims/web-time/src/lib.rs
burn-nostd/web/.cargo/config.toml
burn-nostd/web/Cargo.lock
burn-nostd/web/Cargo.toml
burn-nostd/web/gesture/Cargo.toml
burn-nostd/web/gesture/src/lib.rs
burn-nostd/web/keywords/Cargo.toml
burn-nostd/web/keywords/src/lib.rs
burn-nostd/web/rt/Cargo.toml
burn-nostd/web/rt/src/lib.rs
burn-nostd/web/sine/Cargo.toml
burn-nostd/web/sine/src/lib.rs
burn-nostd/web/site/app.js
burn-nostd/web/site/gesture.html
burn-nostd/web/site/img/gesture.png
burn-nostd/web/site/img/keywords.png
burn-nostd/web/site/img/sine.png
burn-nostd/web/site/img/tinystories.png
burn-nostd/web/site/index.html
burn-nostd/web/site/keywords.html
burn-nostd/web/site/sine.html
burn-nostd/web/site/style.css
burn-nostd/web/site/tinystories.html
burn-nostd/web/tinystories/Cargo.toml
burn-nostd/web/tinystories/src/lib.rs
candle-batteries/.cargo/config.toml
candle-batteries/.gitignore
candle-batteries/1-tensors/Cargo.toml
candle-batteries/1-tensors/src/main.rs
candle-batteries/2-classify/Cargo.toml
candle-batteries/2-classify/images/cat.jpg
candle-batteries/2-classify/images/coffee.jpg
candle-batteries/2-classify/src/imagenet-classes.txt
candle-batteries/2-classify/src/main.rs
candle-batteries/3-similar/Cargo.toml
candle-batteries/3-similar/src/main.rs
candle-batteries/4-ask/Cargo.toml
candle-batteries/4-ask/src/main.rs
candle-batteries/Cargo.lock
candle-batteries/Cargo.toml
candle-batteries/LICENSE
candle-batteries/README.md
candle-batteries/out/ask.err
candle-batteries/out/ask.txt
candle-batteries/out/classify-cat.txt
candle-batteries/out/classify-coffee.txt
candle-batteries/out/gguf-stats.txt
candle-batteries/out/models.txt
candle-batteries/out/runs.log
candle-batteries/out/similar-eat.txt
candle-batteries/out/similar-old.txt
candle-batteries/out/similar-rain.txt
candle-batteries/out/similar-router.txt
candle-batteries/out/tensors.txt
candle-batteries/rustfmt.toml
code/Cargo.lock
code/Cargo.toml
code/burn-demo/Cargo.toml
code/burn-demo/src/bin/burn_errors.rs
code/burn-demo/src/bin/burn_generate.rs
code/burn-demo/src/bin/burn_hello.rs
code/burn-demo/src/bin/burn_rank_error.rs
code/burn-demo/src/bin/burn_sine.rs
code/burn-demo/src/bin/burn_train_lm.rs
code/burn-demo/src/bin/make_corpus.rs
code/burn-demo/src/lib.rs
code/burn-demo/src/lm.rs
code/burn-optim-nostd-check/Cargo.lock
code/burn-optim-nostd-check/Cargo.toml
code/burn-optim-nostd-check/rust-toolchain.toml
code/burn-optim-nostd-check/src/lib.rs
code/candle-demo/Cargo.toml
code/candle-demo/src/bin/candle_errors.rs
code/candle-demo/src/bin/candle_generate.rs
code/candle-demo/src/bin/candle_hello.rs
code/candle-demo/src/bin/candle_sine.rs
code/candle-nostd-check/Cargo.lock
code/candle-nostd-check/Cargo.toml
code/candle-nostd-check/README.md
code/candle-nostd-check/src/lib.rs
code/capture.sh
code/compare.sh
code/data/charlm.bpk
code/data/charlm.safetensors
code/data/corpus.txt
code/data/sine-burn.safetensors
code/data/sine-candle.safetensors
code/data/sine-init.safetensors
code/data/third-party/candle/LICENSE-APACHE
code/data/third-party/candle/LICENSE-MIT
code/firmware/.cargo/config.toml
code/firmware/Cargo.lock
code/firmware/Cargo.toml
code/firmware/burn-m33/Cargo.toml
code/firmware/burn-m33/build.rs
code/firmware/burn-m33/memory.x
code/firmware/burn-m33/src/main.rs
code/firmware/pico2/Cargo.lock
code/firmware/pico2/Cargo.toml
code/firmware/pico2/build.rs
code/firmware/pico2/memory.x
code/firmware/pico2/src/main.rs
code/firmware/qemu-m33/Cargo.toml
code/firmware/qemu-m33/build.rs
code/firmware/qemu-m33/memory.x
code/firmware/qemu-m33/src/main.rs
code/firmware/rustfmt.toml
code/out/burn-errors.txt
code/out/burn-generate.txt
code/out/burn-hello.txt
code/out/burn-m33-size.txt
code/out/burn-m33.txt
code/out/burn-optim-nostd-build.txt
code/out/burn-rank-error.txt
code/out/burn-sine.txt
code/out/burn-train-lm.txt
code/out/burn-wasm.err
code/out/burn-wasm.txt
code/out/candle-errors.txt
code/out/candle-generate.txt
code/out/candle-hello.txt
code/out/candle-nostd-build.txt
code/out/candle-sine.txt
code/out/candle-wasm.err
code/out/candle-wasm.txt
code/out/pico2-size.txt
code/out/qemu-m33-size.txt
code/out/qemu-m33.txt
code/out/sine-burn.csv
code/out/sine-candle.csv
code/out/sine-timing.txt
code/out/tiny-generate.txt
code/out/wasm-sizes.txt
code/rustfmt.toml
code/timing.sh
code/tiny/Cargo.toml
code/tiny/src/bin/tiny_generate.rs
code/tiny/src/charlm.rs
code/tiny/src/lib.rs
code/tiny/src/rng.rs
code/tiny/src/sine.rs
code/tiny/src/st.rs
code/tiny/src/vocab.rs
code/wasi-run.mjs
fonts/private/.gitignore
fonts/private/README.md
fonts/public/IBMPlexMono-Bold.ttf
fonts/public/IBMPlexMono-Italic.ttf
fonts/public/IBMPlexMono-Medium.ttf
fonts/public/IBMPlexMono-Regular.ttf
fonts/public/IBMPlexMono-SemiBold.ttf
fonts/public/Jost-Italic[wght].ttf
fonts/public/Jost[wght].ttf
fonts/public/KumbhSans[YOPQ,wght].ttf
fonts/public/OFL-IBMPlexMono.txt
fonts/public/OFL-Jost.txt
fonts/public/OFL-KumbhSans.txt
justfile
notes/notes.yaml
notes/speaker-notes.typ
presentation-public.pdf
questions.md
slides/code.tmTheme
slides/media/board-tinystories.jpg
slides/media/gesture-shake.png
slides/media/keywords-heard.png
slides/media/keywords-spec.png
slides/media/la-linea.jpg
slides/media/qr-demos.svg
slides/media/sine-plot.png
slides/media/tinystories-top.png
slides/media/video/board.mp4
slides/media/video/gesture.mp4
slides/media/video/keywords.mp4
slides/media/video/sine.mp4
slides/media/video/tinystories.mp4
slides/presentation.typ
slides/qr-repo.svg
slides/theme.typ
speaker-notes.md
speaker-notes.pdf
tools/capture-examples.sh
tools/check_notes.py
tools/gguf_stats.py
tools/minilm-reference/Cargo.lock
tools/minilm-reference/Cargo.toml
tools/minilm-reference/README.md
tools/minilm-reference/check.py
tools/minilm-reference/result.txt
tools/minilm-reference/rustfmt.toml
tools/minilm-reference/src/main.rs
tools/notes_md.py
```

</details>

## Offline status

| Level | Status |
|---|---|
| 1. Presenting the PDF offline | **verified**: all fonts embedded, no external resources, QR codes are vector art |
| 2. Running the examples offline | Candle: **verified on Linux** with a warm Hugging Face cache (network cut, `HF_HUB_OFFLINE=1`). burn-nostd: needs no network at run time; the demo pages run offline from `cargo web`. **Not verified on macOS.** |
| 3. Rebuilding from source offline | `just fetch` downloads every crate; afterwards `cargo --offline` works (tested for `code/` in version 1 with vendored crates). Typst needs no packages. |

## Limitations

- Timings come from a shared 2-vCPU VM; a run during parallel builds gave 1.3 tokens/s for `ask` instead of 4.2 and was discarded. Expect a laptop to be faster.
- QEMU emulates a Cortex-M33 and the memory limit, not the RP2350's timing. The one speed number for the microcontroller, 4.3 tokens/s, comes from one board (RP2350B at its default 150 MHz), two runs of the same evening; it was not profiled.
- `tinystories-usb` and `tinystories-lcd` are meant for the Waveshare RP2350-Touch-LCD-3.5-C (USB-C only, no probe needed). From Waveshare's product page and documentation: RP2350B, 16 MB flash, a BOOT button pressed during reset for download mode, drag-and-drop programming over USB. From the schematic (text of the PDF): a 12 MHz crystal (Y2), the panel's VDD and IOVCC on the 3V3 rail, the backlight switched by a transistor from LCD_BL. From the example code: the display pins and register values above; GPIO 25 is the touch interrupt (the Pico 2's LED pin, so neither program drives it). Both programs are built for the RP2350A (see above).
- The keyword recordings are synthetic: one espeak-ng voice for training and test. The gesture windows are synthetic too, from one generator for training and test. Both checks show that training works, not how well it works on real signals.
- QEMU's mps2-an505 has more RAM than a Pico 2; `memory.x` limits the programs to 520 KiB, and the heap is 256 KiB of it.
- The GitHub repositories and the demo site exist since 1 November; the CI and Pages runs were not seen from here.

## Provenance summary

1. **Performed by Ludwig earlier** (his notes): MiniLM sentence embeddings via Candle with XGBoost to predict Hacker News comment scores. Mentioned on the "about me" slide and in the MiniLM notes.
2. **Created in Ludwig's earlier chats, never run by him on his hardware** (as far as the material says): `candle-batteries` (written 19 October 2026; run there only against a stand-in Hub with converted weights) and `burn-nostd` with its slides and notes (tested there in a sandbox with Rust 1.91). Both were run again here, against the real Hub and with Rust 1.95, with the results above. Not reused: the stand-in Hub and its converted weights.
3. **Verified external facts**: see `REFERENCES.md` (READMEs, Burn Book 0.22, crate sources, crates.io dates, the Hub's file metadata, llama2.c).
4. **Created and run in this session**: the comparison code in `code/`, all captured output in the three `out/` folders, the capture script, the screenshots, the slides and the notes; and the checks of burn-optim, the shims and gemm.

## MacBook checklist (in priority order, under 30 minutes)

1. **Open `presentation-private.pdf` in the app you will present with** (2 min). Page through once. Keep `presentation-public.pdf` as a fallback.
2. **Create `weinzierl/burn-nostd` on GitHub, push `burn-nostd/`, and set Pages to "GitHub Actions"** (5 min). The demo QR code and the live slide point to `weinzierl.github.io/burn-nostd`. Open the four pages on your phone once.
3. **Create `weinzierl/burn-little-candle-burn` and push this package** (3 min). The other QR code (try slide and end slide) points there. Scan the end slide from across a room once.
4. **Warm the Hugging Face cache and test offline** (10 min, mostly download): `just candle`, then the same with Wi-Fi off. All four programs must print what the slides show.
5. **Rehearse with `speaker-notes-private.pdf`** (rest of the time). Drop SKIP slides when behind. For the live demo use the keywords page (sample voice, train, play); fallback videos are in `slides/media/video/`.
6. Optional, with a Pico 2 and a debug probe: `cd burn-nostd/pico2 && cargo run --release --bin tinystories`. Without a probe, on any RP2350 board with USB: `tinystories-usb` as a UF2 file (burn-nostd README); the first four stories should equal `burn-nostd/out/qemu-tinystories-usb.txt`. On the Waveshare board, `tinystories-lcd` shows them on its screen. Done on 1 November: 4.3 tokens/s, now on slides 2, 34 and 39 and in `questions.md`.
