# Which slide shows which code

Made by `tools/slide_map.py` from `slides/presentation.typ`: the slides read code and captured output
from these files when the deck is built, so what a slide shows is what the file holds.
Slides without files are text, tables or diagrams. Numbers in the text (sizes, rates, parameter counts)
are read from the same `out/` files at the top of `slides/presentation.typ`. Output files were captured
from real runs; VERIFICATION.md says where each ran.

| Slide | Title | Files |
|---:|---|---|
| 1 | Burn, little candle, burn! |  |
| 2 | Two ends of this talk | `candle-batteries/out/ask.txt` |
| 3 | Ludwig Weinzierl |  |
| 4 | What does it take to do ML in Rust? |  |
| 5 | 01 Two frameworks |  |
| 6 | What a framework does for you |  |
| 7 | Candle |  |
| 8 | Burn |  |
| 9 | Burn 0.22 moved the backend |  |
| 10 | 02 Tensors |  |
| 11 | One matrix product: Candle | `code/candle-demo/src/bin/candle_hello.rs`<br>`code/out/candle-hello.txt` |
| 12 | One matrix product: Burn | `code/burn-demo/src/bin/burn_hello.rs`<br>`code/out/burn-hello.txt` |
| 13 | Wrong shapes: Candle returns an error | `code/candle-demo/src/bin/candle_errors.rs`<br>`code/out/candle-errors.txt` |
| 14 | Wrong shapes: Burn panics | `code/burn-demo/src/bin/burn_errors.rs`<br>`code/out/burn-errors.txt` |
| 15 | Wrong rank: Burn does not compile | `code/burn-demo/src/bin/burn_rank_error.rs`<br>`code/out/burn-rank-error.txt` |
| 16 | Where the information lives |  |
| 17 | 03 Candle, batteries included |  |
| 18 | A model is a download away | `candle-batteries/2-classify/src/main.rs` |
| 19 | An image: ResNet-18 | `candle-batteries/2-classify/src/main.rs`<br>`candle-batteries/2-classify/images/cat.jpg`<br>`candle-batteries/out/classify-cat.txt` |
| 20 | A sentence: MiniLM | `candle-batteries/3-similar/src/main.rs` |
| 21 | Five sentences about Bologna | `candle-batteries/out/similar-eat.txt`<br>`candle-batteries/out/similar-rain.txt`<br>`candle-batteries/out/similar-old.txt`<br>`candle-batteries/out/similar-router.txt` |
| 22 | A chat: SmolLM2, one token at a time | `candle-batteries/4-ask/src/main.rs` |
| 23 | What it answers | `candle-batteries/4-ask/src/main.rs`<br>`candle-batteries/out/ask.txt`<br>`candle-batteries/out/ask.err` |
| 24 | What Candle gives you, what you write |  |
| 25 | 04 Learning sin(x) |  |
| 26 | Learning, in four lines |  |
| 27 | Experiment 1: learn sin(x) |  |
| 28 | The model, twice | `code/candle-demo/src/bin/candle_sine.rs`<br>`code/burn-demo/src/bin/burn_sine.rs` |
| 29 | Training loop: Candle | `code/candle-demo/src/bin/candle_sine.rs` |
| 30 | Training loop: Burn | `code/burn-demo/src/bin/burn_sine.rs` |
| 31 | Same start, same data, same curve | `code/out/candle-sine.txt`<br>`code/out/burn-sine.txt`<br>`code/out/sine-burn.csv`<br>`code/out/sine-timing.txt` |
| 32 | The detail that made it work | `code/burn-demo/src/bin/burn_sine.rs` |
| 33 | 05 Burn without std |  |
| 34 | Four steps, one no_std crate each |  |
| 35 | 1 · Inference: the weights stay in flash | `burn-nostd/1-sine/src/lib.rs`<br>`slides/media/sine-plot.png`<br>`burn-nostd/out/sine.txt` |
| 36 | 2 · Training on the device | `burn-nostd/desktop/src/bin/gesture.rs`<br>`burn-nostd/out/gesture.txt` |
| 37 | Without std: our own Adam, batch size 1 | `burn-nostd/2-gesture/src/lib.rs` |
| 38 | 3 · Audio: teach it words | `slides/media/keywords-spec.png`<br>`slides/media/keywords-heard.png`<br>`burn-nostd/out/keywords.txt` |
| 39 | 4 · Someone else's model, straight from flash | `burn-nostd/4-tinystories/src/lib.rs`<br>`burn-nostd/qemu/src/bin/tinystories.rs` |
| 40 | The same model on a real chip | `slides/media/board-tinystories.jpg`<br>`burn-nostd/out/board-tinystories-usb.txt` |
| 41 | What it took |  |
| 42 | Try it now, on your phone |  |
| 43 | 06 Choosing |  |
| 44 | Which one? |  |
| 45 | Three things I take home |  |
| 46 | Try it |  |
| 47 | Grazie mille |  |
| 48 | Backup: three ways a model comes in |  |
| 49 | Backup: quantization |  |
| 50 | Backup: timing GPU code |  |
| 51 | Backup: Osvaldo Cavandoli | `slides/media/la-linea.jpg` |

24 of 51 slides show or read files of this repository.
