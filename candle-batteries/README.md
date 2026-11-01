# Candle, batteries included

From a tensor to a chat model in four small Rust programs, with
[Candle](https://github.com/huggingface/candle), Hugging Face's minimalist ML framework.
Each step is one `main.rs` and adds one idea.

Code for the Candle half of the talk *Burn, Little Candle, Burn!* at RustLab 2026.
The Burn half: [weinzierl/burn-nostd](https://github.com/weinzierl/burn-nostd).

| Step | Run | Adds |
|---|---|---|
| 1 | `cargo tensors` | Tensors, devices, shapes checked at run time |
| 2 | `cargo classify 2-classify/images/cat.jpg` | Pretrained weights from the Hub, ResNet-18 from the model zoo |
| 3 | `cargo similar "Where can I eat tonight?"` | Tokenizer, batching, sentence embeddings (all-MiniLM-L6-v2) |
| 4 | `cargo ask "What is a tensor?"` | 8-bit GGUF (Q8_0), KV cache, sampling, streaming (SmolLM2-360M-Instruct) |

## Running

Tested with Rust 1.97.0 on Linux x86-64. On their first run, steps 2 to 4 download
weights from the Hugging Face Hub (47 MB, 91 MB and 386 MB) into
`~/.cache/huggingface`; after that they run offline. The tokenizers crate builds the
Oniguruma C library, so a C compiler is needed (on macOS: `xcode-select --install`).

Everything runs on the CPU by default. Metal (Apple silicon) and CUDA are features:

```sh
cargo run --release -p ask --features metal -- "What is a tensor?"
```

## Credits

Models, all Apache-2.0:
[timm/resnet18.gluon_in1k](https://huggingface.co/timm/resnet18.gluon_in1k),
[sentence-transformers/all-MiniLM-L6-v2](https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2),
[HuggingFaceTB/SmolLM2-360M-Instruct](https://huggingface.co/HuggingFaceTB/SmolLM2-360M-Instruct)
(tokenizer) and the publisher's
[GGUF](https://huggingface.co/HuggingFaceTB/SmolLM2-360M-Instruct-GGUF)
(`smollm2-360m-instruct-q8_0.gguf`).
Images from scikit-image's sample data: cat (Stefan van der Walt) and coffee
(Rachel Michetti), CC0.
ImageNet class names from Candle's examples.

Code: MIT.
