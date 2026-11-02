# Questions to expect

Preparation for the Q&A of "Burn, little candle, burn!" (RustLab 2026, Bologna,
Monday 2 November, 11:30, RustLab Deep Space) and for the hallway afterwards.
The questions are ordered from most to least likely. Each has the question as people
tend to ask it, who asks it and why, a short answer to say, where the evidence is, and
what not to claim. Facts checked on 31 October 2026; numbers come from the captured
runs (VERIFICATION.md) unless marked otherwise.

## Who is in the room

From the RustLab 2026 programme (rustlab.it, read 31 October):

- RustLab is organized by Develer (Florence). Day 1 is workshops, days 2 and 3 are
  45-minute talks in three rooms. The talk is level "Introductory and Overview", and it
  is the only talk of the conference about ML frameworks (there is one AI workshop on
  day 1). People will treat you as "the ML in Rust person" and ask broad questions, not
  only about the slides.
- 09:30 keynote, Main Hall: Alice Ryhl, "Making the standard library less special".
  Judging by the title, std, core and alloc will be fresh in many heads: good for part
  three.
- 10:45, same room: Amos Wenger and Alexandra Østermark, "Beyond cargo build". Some of
  that audience stays: build times and binary sizes come up easily.
- 11:30, in parallel: "Making Rust working on a CHERI platform" (Deep Ocean).
- 12:15, same room after you: Guillaume Binet on Copper (robotics). Robotics people
  arrive early: latency and real-time questions.
- Day 1 workshop "Make rusty AI" (LLMs, chatbot REPLs, RAG and agents in Rust): some
  attendees think "LLM apps", and will ask about local LLMs and embeddings.
- A strong embedded thread: HID devices (12:15, Deep Ocean), Myrmic (edge runtime for
  servers and microcontrollers), nRF52 BLE firmware, a formally verified IoT protocol.
  Expect pointed microcontroller questions.
- Sponsors include Exein (security, eBPF) and TrueLayer (fintech); speakers come from
  Google, Meta, Microsoft, JetBrains, NVIDIA. Some listeners run Rust in production
  and judge maturity, supply chain and licences.
- The abstract invites people "from Python". A few ML practitioners will compare
  everything with PyTorch.

So, roughly: Rust developers who want ML in their own programs (the largest group),
embedded developers, a few Python ML people, and possibly a Burn or Candle contributor.

## How to answer

- Repeat the question, for the room and the recording.
- Verdict first, then one fact, then the limit: "I haven't measured that" is a full,
  good answer. Never improvise a number; use the table below.
- Backup slides: 48 how a model comes in, 49 quantization, 50 timing GPU code, 51 the design, a tribute to Osvaldo Cavandoli and La Linea.
- If a maintainer corrects you: thank them, note it, take it to the hallway.
- About 5 minutes are left for questions (40:00 planned). Two or three questions,
  then point to the repository and the hallway.

## Numbers at hand

| What | Number | Measured where |
|---|---|---|
| SmolLM2-360M-Instruct, Q8_0 GGUF | 386 MB file; 31 tokens at 4.2 tokens/s | Candle 0.11, 2 vCPU Linux VM |
| SmolLM2 weights | 361.8 million in Q8_0: 384 MB; as f32 1.45 GB | GGUF header |
| MiniLM against ONNX Runtime | scores within 0.0000003; all 20 slide values identical | official ONNX export, same revision |
| ResNet-18 | 81.7 % Egyptian cat; weights 47 MB | Candle, CPU |
| sin(x), 1 153 parameters, 2 000 steps | Candle 526 to 685 µs/step, Burn 540 to 683 µs/step (5 runs each) | 2 vCPU VM, informal |
| sin(x) agreement | losses equal to 6 decimals from step 250; max error 0.0075 | 256 training points |
| Step 1, sine, 321 parameters | 2 564-byte Burnpack file; 4 µs per inference; heap peak 7 888 bytes | desktop; QEMU |
| Step 2, gestures, 1 316 parameters | 15 epochs in 13 ms; 100/100; heap peak 42 468 bytes (41 KiB) | desktop; QEMU |
| Step 3, keywords, 5 448 parameters | trained in 167 ms; 11/12; heap peak 217 340 bytes (212 KiB) | desktop; QEMU |
| Step 4, TinyStories 260K | 1 056 540 bytes of weights; heap peak 184 036 bytes (180 KiB), KV cache 160 KiB at 128 positions, 640 KiB at 512 | QEMU |
| TinyStories speed | 6 909 tokens/s desktop; 214 tokens/s in the browser | x86-64; headless Chromium |
| QEMU memory | RAM limited to 520 KiB (memory.x), heap 256 KiB | mps2-an505, Cortex-M33 |
| Pico 2 firmware size | 1.3 to 1.8 MB code per program; TinyStories adds 1.1 MB weights (board: 4 MB flash) | built; only the TinyStories programs ran on a board |
| TinyStories on an RP2350 board | 4.3 tokens/s (124 tokens in 28.5 s), same four stories as QEMU | Waveshare RP2350-Touch-LCD-3.5 (RP2350B, 150 MHz), 1 November |
| WebAssembly modules | 1.6 to 2.3 MB each, 0.35 to 1.25 MB gzipped | release, opt-level "s" |
| Candle programs, x86-64, stripped | classify 17.5 MB, similar 18.6 MB, ask 19.3 MB; tensors demo 1.4 MB | release |
| Clean release builds, 2 vCPU | candle-batteries 8 min, burn-nostd 4 min | Linux VM |
| Versions (crates.io, 31 Oct) | Candle 0.11.1 released 31 Oct; Burn 0.22.1 (20 Oct), 0.23.0-pre.1 (29 Oct) | |

## The questions, most likely first

### Very likely

**1. "So which one should I use?"**
- *Variants:* "...for embeddings in my web service?", "...to run an LLM locally?", "...to train my own model?"
- *Who:* almost everyone; the abstract promises "enough context to pick the right tool".
- **Answer:** To run a model that already exists, especially from the Hugging Face Hub: Candle. The model zoo, tokenizers and GGUF are there. To train in Rust, to train on the device, for microcontrollers, or for GPUs beyond CUDA and Metal: Burn. If you only need to run an ONNX model in a service, ort, the ONNX Runtime bindings, is the pragmatic choice; it is C++ underneath, so no no_std. And you can use both: weights travel as safetensors.
- *Evidence:* slide 44.
- *Careful:* "my reading, November 2026"; GPUs not tested.

**2. "Did you run it on a real Pico 2? How fast is it on the chip?"**
- *Who:* embedded developers; the slides say "emulated", and they will notice.
- **Answer:** Not on a Pico 2, but on its chip: step 4, TinyStories, ran on a Waveshare RP2350-Touch-LCD-3.5, an RP2350B at 150 MHz with the same 520 KiB of RAM. 4.3 tokens per second, the same four stories as in QEMU, over USB and on the board's screen. That is slow, and I have not profiled it: every token reads all 1.1 MB of weights from flash through a 16 KiB cache, and every operation goes through Burn's generic tensor layer. Steps 1 to 3 ran in QEMU only; their firmware builds.
- *Evidence:* slides 2, 34 and 40 (photo of the board); `burn-nostd/out/board-tinystories-usb.txt` and `board-tinystories-lcd.txt`; VERIFICATION.md part 3.
- *Careful:* "an RP2350 board", not "a Pico 2". No speed claims for steps 1 to 3, and no comparison with C on the chip: none was run.

**3. "How fast is it? Candle against Burn, against PyTorch, against llama.cpp?"**
- *Who:* everyone who has read a framework benchmark.
- **Answer:** I did not benchmark, on purpose. All my times are CPU times on a shared two-core VM. For sin(x) both land in the same range, 526 to 685 microseconds per step for Candle and 540 to 683 for Burn, five runs each: that measures framework overhead on a tiny model, not arithmetic. SmolLM2 at 8 bits: 4.2 tokens per second on two cores. No GPU, no PyTorch, no llama.cpp comparison. How to time it properly: backup slide 50.
- *Evidence:* slides 23 and 31, backup 50.
- *Careful:* never "X is faster".

**4. "Why not just use ort (ONNX Runtime), tract, or tch-rs?"**
- *Who:* Rust developers who already ship models with ort.
- **Answer:** Good options with a different trade-off. ort wraps Microsoft's ONNX Runtime: mature kernels and hardware providers, but a large native C++ dependency, and its 2.0 is still a release candidate (rc.15 on 19 October). tract is a self-contained Rust engine for ONNX and TensorFlow models. tch-rs binds libtorch; Candle's own README says it brings the whole torch library into your runtime, and that its main author is also involved in Candle. Candle and Burn are for when the model should be Rust code you can change, train, and take to WebAssembly or, with Burn, to a microcontroller.
- *Evidence:* crates.io, Candle README "Other ML frameworks".
- *Careful:* none of them was benchmarked or tested for this talk.

**5. "Is this production-ready? Burn just broke its whole API."**
- *Who:* people who run Rust in production; slide 9 invites it.
- **Answer:** Both are below 1.0 and move fast. Candle 0.11.1 came out on 31 October, Burn 0.22.0 on 6 October, 0.22.1 on 20 October, and a 0.23 pre-release on 29 October. Burn's README says there will be breaking changes. Candle runs underneath real projects: Hugging Face's own text-embeddings-inference server has a Candle backend, and mistral.rs is built on Candle. Pin exact versions, read the migration guides, budget time for upgrades.
- *Evidence:* crates.io; TEI and mistral.rs dependencies.
- *Careful:* you cannot name production users of Burn; do not guess.

**6. "Does it use my Mac's GPU? CUDA? Did you test GPUs?"**
- *Who:* the many MacBook users; GPU people.
- **Answer:** Not tested; everything in the talk ran on CPUs. Candle: Metal and CUDA are cargo features, Accelerate and MKL speed up the CPU, and the README mentions multi-GPU through NCCL. Burn: CubeCL backends for CUDA, ROCm, Metal, Vulkan and WebGPU, chosen at run time since 0.22. If you time GPU code: warm up, then synchronize before you stop the clock.
- *Evidence:* slides 7 and 8, backup 50, REFERENCES.md.

**7. "How do I get my PyTorch model into Rust?"**
- *Who:* the Python people the abstract invited.
- **Answer:** Two routes, backup slide 48. Weights only: save safetensors from PyTorch and write or reuse the architecture in Rust. In Candle, candle-transformers has 100 models; in Burn you write the module and load with burn-store, whose adapters fix PyTorch's Linear layout. Whole graph: export ONNX. Burn's burn-onnx turns it into Rust code at build time; Candle's candle-onnx evaluates it at run time. Then compare the outputs on the same inputs with PyTorch, as I did for MiniLM against ONNX Runtime.
- *Evidence:* backup 48, slide 32.
- *Careful:* ONNX operator coverage varies; check the list.

### Likely

**8. "Can I fine-tune or train an LLM in Rust?"**
- *Who:* workshop attendees from day 1, Python people.
- **Answer:** Both have autodiff and optimizers; Burn has the fuller training story, with a learner, checkpoints and a dashboard. For LLM fine-tuning, Candle's README lists candle-lora, a third-party LoRA implementation. I trained only small models, 321 to 5 448 parameters, so I cannot vouch for large-scale training. The realistic split today: train big models in Python, run them in Rust; train small ones in Rust where the data is.
- *Careful:* no claims about mixed precision, multi-GPU or LoRA quality.

**9. "Why do ML in Rust at all? Python has everything."**
- *Who:* the friendly skeptic.
- **Answer:** For research and big training runs, Python wins. Rust wins when the model has to live inside a program: one binary, no Python runtime, predictable memory, WebAssembly, a microcontroller, and Rust's checks for the code around the model, which is where my bugs were. Candle's README states it plainly: serverless inference, and Python out of production.

**10. "Why does Burn panic on a shape mismatch? Isn't that un-Rusty?"**
- *Who:* Rust people; slides 13 to 15 invite the debate.
- **Answer:** Burn treats a wrong shape like an index out of bounds: a bug, not an expected condition. Candle treats it as an error value, as PyTorch does with exceptions. Both are defensible. With Burn, check shapes that come from outside, from files, users or the network, before the call; with Candle, you write `?` after every operation. Burn checks the rank at compile time; the sizes are run-time values in both.
- *Evidence:* slides 13 to 16.

**11. "Can I run Llama, Qwen or Mistral locally with Candle? How does it compare with llama.cpp or Ollama?"**
- *Who:* the LLM-app crowd.
- **Answer:** Yes. candle-transformers 0.11.0 has 100 model implementations plus 22 quantized GGUF variants, and Candle reads GGUF files from 2-bit to 8-bit. Built on Candle are mistral.rs, an LLM inference engine, and candle-vllm, an OpenAI-compatible server. I measured only SmolLM2 with 360 million parameters on two CPU cores. If you just want a local chatbot, llama.cpp and Ollama are the established choice; Candle is for when the model should run inside your own Rust program.
- *Careful:* no speed comparison with llama.cpp.

**12. "How big are the binaries? How long do builds take?"**
- *Who:* the "Beyond cargo build" audience, serverless people.
- **Answer:** On the build VM, release and stripped: the Candle programs are 17.5 to 19.3 MB; the tokenizer, TLS for the Hub download and the model code are in there. The plain tensor demo is 1.4 MB. The burn-nostd WebAssembly modules are 1.6 to 2.3 MB, 0.35 to 1.25 MB gzipped, TinyStories with its 1 MB of weights. Clean release builds on two cores took 8 minutes for the Candle examples and 4 for burn-nostd. I did not optimize for size.
- *Evidence:* VERIFICATION.md (sizes and build times).

**13. "How much flash and RAM does it really need on the microcontroller?"**
- *Who:* embedded developers.
- **Answer:** RAM: a 256 KiB heap, and the peaks I measured in QEMU are 7.7 KiB for the sine model, 41 KiB for training the gesture model, 212 KiB for the keyword spotter, and 180 KiB for TinyStories, of which 160 KiB is the KV cache. Flash: 1.3 to 1.8 MB of code per firmware, built with fat LTO; probably most of it is Burn's generic tensor code and kernels, but I have not analysed or tried to shrink it. The weights stay in flash and are never copied.
- *Evidence:* slides 35 to 39, `burn-nostd/out/pico2-size.txt`.
- *Careful:* "fits", not "small".

**14. "How hard was it to get Burn working without std?"**
- *Who:* embedded developers, keynote listeners.
- **Answer:** Burn's core crates build without std: tensor, autodiff, nn, store and the Flex backend. A whole program needed five fixes, all in my code, no fork: two shims for web-time and wasm-bindgen-futures in the no_std desktop and WebAssembly builds, a 78-line Adam because burn-optim 0.22.0 does not compile without std, batch size 1 because gemm would allocate a 512 KiB buffer per small matrix-matrix product, a 256-byte aligned wrapper for Burnpack weights, and two empty unwinder symbols for the Linux binary. Burn's own book has a Pico 2 chapter too.
- *Evidence:* slides 37 and 41.

**15. "Why f32 on a microcontroller? Why not int8, CMSIS-NN or TensorFlow Lite Micro?"**
- *Who:* embedded ML people.
- **Answer:** The RP2350's Cortex-M33 has a single-precision FPU, and my goal was Burn's normal code path without std, not the smallest model. For int8 on microcontrollers, TensorFlow Lite Micro with CMSIS-NN is the established route; in Rust, MicroFlow from the University of Padova compiles quantized TFLite models into no_std code and was tested on ESP32, nRF52840 and others. Burn's quantization today is post-training and dequantizes before it computes, so it saves storage, not arithmetic.
- *Evidence:* backup 49.
- *Careful:* you have not used MicroFlow or TFLite Micro.

**16. "Does it work on ESP32, nRF52, STM32, or the RP2350's RISC-V cores?"**
- **Answer:** I only built for the Cortex-M33 with FPU. The crates are plain no_std plus alloc, so another 32-bit chip with enough RAM should need a HAL and a heap, but I have not tried. RAM decides: keywords peak at 212 KiB, TinyStories at 180 KiB. Without an FPU, f32 will be slow.
- *Careful:* untested.

**17. "Where do I start?"**
- *Who:* the intro-level majority.
- **Answer:** The talk repository: candle-batteries steps 1 to 4 for pretrained models, the sin(x) pair in `code/`, burn-nostd steps 1 to 4 and its demo page. Then the Burn Book and Candle's examples; the Candle README links a tutorial on porting a PyTorch model.

**18. "Can I use the MiniLM part for semantic search or RAG? How do I pick a threshold?"**
- *Who:* the LLM-app crowd.
- **Answer:** Yes, that is what sentence embeddings are for, and how I used MiniLM for Hacker News comments. Store the unit vectors, compare with a dot product. The router question shows there is always a nearest sentence, here at 0.05, so set the threshold from your own data: label some pairs and look at the scores. For serving embeddings at scale, Hugging Face's text-embeddings-inference has a Candle backend.
- *Evidence:* slides 20 and 21.

**19. "How do you know the outputs are right?"**
- **Answer:** Each against an independent reference. MiniLM against the official ONNX export in ONNX Runtime: within 0.0000003, all 20 values on the slide identical. TinyStories against Karpathy's run.c: same text for 80 steps. sin(x): Candle and Burn agree to six decimals. Model files: hashes equal to the Hub's metadata. Loaded is not checked.
- *Evidence:* backup 48, VERIFICATION.md.

**20. "Why QEMU? How realistic is it?"**
- **Answer:** It runs the same Cortex-M33 instruction set and enforces the memory limit I set, 520 KiB of RAM and a 256 KiB heap, so memory use and correctness carry over. It does not model the RP2350's timing, its flash cache or its peripherals, so QEMU gives no speed numbers. The real board gave the same text as QEMU, at 4.3 tokens per second (question 2). The emulated board has more RAM; the linker script cuts it to the Pico 2's size.

**21. "Burn's matmul takes self. Aren't all those clones expensive?"**
- **Answer:** A clone only bumps a reference count; the data is not copied. Taking ownership lets Burn reuse a buffer in place when it holds the only reference, so moves can make it faster, not slower.
- *Evidence:* slide 12, Burn Book "Ownership and Cloning".

### Possible

**22. "Burn 0.22 picks the backend at run time. Doesn't dynamic dispatch cost performance?"**
- **Answer:** I did not measure the dispatch cost. What you gain: model code without generics, and one program that can choose CPU or GPU at run time. On my tiny CPU model both frameworks land in the same range per step.
- *Careful:* no claim about GPU overhead.

**23. "Can I use Candle and Burn together?"**
- **Answer:** Yes, through files: safetensors with the same tensor names, and Burn's PyTorch-to-Burn adapter for linear layers. Since 0.22 Burn no longer runs on top of Candle, so the file is the interface. My sin(x) start file is exactly that.
- *Evidence:* slide 32.

**24. "Candle runs in the browser. Why can't it run on a microcontroller?"**
- *Who:* keynote listeners.
- **Answer:** The browser target, wasm32-unknown-unknown, has a standard library, partly stubbed, so Candle builds there. A microcontroller target has no std at all. Candle's build for the Pico's target stops at getrandom, which needs std; I kept the build log.
- *Evidence:* slide 34, `code/out/candle-nostd-build.txt`.

**25. "Training on a microcontroller: why would anyone do that?"**
- **Answer:** Personalization without sending data off the device: your gestures, your voice, your machine's vibration. And devices without a network. In my demo the training ran in QEMU with Burn's autodiff and a heap peak of 41 KiB; the data was synthetic.

**26. "Isn't the agreement trivial? Both use the same gemm crate."**
- *Who:* a sharp listener. Tricky.
- **Answer:** Partly fair: on the CPU both call gemm for matrix products. The agreement checks everything around it: loading the same start with the layout adapter, the forward pass, autodiff, Adam with matched settings, epsilon and weight decay, and the loss. A bug in any of those shows within a few hundred steps.

**27. "Why is the first loss different in the last digit?"**
- **Answer:** Floating point: adding in a different order rounds differently. Most likely Burn's SIMD code sums in another order; I did not isolate it. From step 250 on the printed values agree.

**28. "Did you report the burn-optim and gemm problems upstream?"**
- *Who:* a contributor in the room.
- **Answer:** Not yet; both are worth an issue. burn-optim 0.22.0 without default features fails for thumbv8m with 6 errors; gemm without std on non-x86 targets assumes a 512 KiB L2 cache and allocates that much per small matrix-matrix product.
- *Careful:* promise only what you will do.

**29. "Would the keyword spotter work with real voices and noise?"**
- **Answer:** Not measured. All recordings, training and test, come from one synthetic espeak-ng voice with random speed, pitch, loudness and noise. The desktop program reads WAV files, so your own recordings can go in; Google's Speech Commands has real voices.

**30. "What is the point of a 260 000-parameter language model?"**
- *Who:* the skeptic.
- **Answer:** The mechanism: someone else's pretrained weights in an unchanged file, a real Llama architecture, and tensors that borrow the file from flash. The desktop program takes other llama2.c files too, but I only ran this one. The next size up, stories15M, has about 60 MB of f32 weights: far beyond a Pico 2, even with PSRAM. Useful on-device models are more likely classifiers like the keyword spotter.

**31. "Can I run inference in a real-time control loop?"**
- *Who:* the robotics people waiting for Copper.
- **Answer:** Burn allocates for activations, so a forward pass is not allocation-free; in my inference demos only the weights avoid the heap. I measured heap peaks, not timing jitter. For hard real time you would want pre-allocated buffers, or an engine that turns the model into Rust code ahead of time, like MicroFlow.
- *Careful:* no latency numbers.

**32. "Doesn't Burn have pretrained models too?"**
- **Answer:** Yes: Tracel's models repository has Burn ports of MiniLM, ResNet, RoBERTa, YOLOX, MobileNetV2 and more, plus community ports like Whisper and Llama 2. I did not run them. Candle's advantage is that 100 implementations ship inside candle-transformers and read Hub files directly. For Burn I showed someone else's model differently: an unchanged llama2.c checkpoint with my own Llama code.

**33. "Does Burn have an LLM engine like mistral.rs?"**
- **Answer:** Tracel published Burn-LM as an alpha in 2025; that repository is archived now, and Tracel says a new Burn-powered engine, embeddable or as a server, is coming. The Rust LLM engines I know today build on Candle (mistral.rs, candle-vllm) or bind llama.cpp (llama-cpp-2).

**34. "Did the browser demos use WebGPU or threads?"**
- **Answer:** No. They run Burn's Flex backend on the CPU, compiled to WebAssembly with zero imports, so no WebGPU and no threads. Burn has a WebGPU backend; I did not test it.

**35. "Why zero imports and no wasm-bindgen?"**
- **Answer:** The module needs nothing from JavaScript: the page writes inputs into wasm memory and reads the results. That keeps it portable, and shows the crates need nothing from a host. The cost was two small shims, because Burn's dependency cubecl-environment would pull in std or wasm-bindgen; Burn only reaches them from profiling and async code paths.

**36. "Can I call these models from Python, or keep training in PyTorch?"**
- **Answer:** The common split: train in PyTorch, export safetensors or ONNX, run in Rust. For calling Rust from Python, PyO3 works with any Rust code; I have not used Python bindings for Candle or Burn.
- *Careful:* do not claim official Python packages.

**37. "What about data loading and preprocessing?"**
- **Answer:** That is the part you write: slide 24. Candle has candle-datasets, Burn has burn-dataset. In the demos I wrote preprocessing by hand: image scaling with ImageNet's mean and standard deviation, and an FFT with log-mel bands for audio.

**38. "Can I make it deterministic? Seeds?"**
- **Answer:** Candle's CPU random generator cannot be seeded; set_seed returns an error. That is why my sin(x) start comes from a file. Sampling in the chat demo is seeded (42): same answer twice on the same machine. GPU determinism: not tested.

**39. "How does the KV cache work, and why only 128 positions?"**
- **Answer:** Keys and values for every layer and position: 1 280 bytes per position for this model, 5 layers, 4 KV heads of 8 dimensions, f32. 128 positions are 160 KiB; the model's 512 would need 640 KiB, more than the whole chip. The browser version uses 512.
- *Evidence:* slide 39.

**40. "Did you use AI to write this?"**
- *Who:* likely in 2026, at a talk about ML.
- **Answer, in your own words:** parts of the example code and of the slides were written with an AI assistant; every output on the slides comes from a real run; the code is public, and VERIFICATION.md says what ran where and what did not.

### Less likely, but have a sentence ready

**41. "Flex or the CubeCL CPU backend?"**
- **Answer:** Flex is Burn's pure-Rust CPU backend, built on gemm, with SIMD and rayon when std is there, and the one that builds without std and for WebAssembly. The CubeCL CPU backend compiles kernels through CubeCL. I used only Flex.

**42. "What is CubeCL? Can I write my own GPU kernels in Rust?"**
- **Answer:** Tracel calls it a "multi-platform high-performance compute language extension for Rust": kernels written in Rust, run on CUDA, ROCm, Metal, Vulkan or WebGPU. Burn's GPU backends sit on it, with automatic kernel fusion. Candle supports custom kernels too; flash-attention v2 is one. I wrote no kernels.

**43. "How does autodiff differ between them?"**
- **Answer:** Candle: call backward on the loss, get a gradient store, step an optimizer from candle-nn. Burn: autodiff is a device property since 0.22; backward returns the gradients as a value, and the optimizer consumes the model and returns a new one, so there is no zero_grad. Higher-order gradients: not tested.

**44. "Will my old Burn checkpoints load in 0.22?"**
- **Answer:** Not directly. 0.22 uses the Burnpack format; the migration guide says to export old records to safetensors with burn-store in the old version, then import them.

**45. "Is Candle pure Rust? What about the supply chain?"**
- *Who:* security-minded listeners.
- **Answer:** Its CPU kernels are Rust. But candle-core 0.11 pulls in the tokenizers crate with the Oniguruma C library on non-wasm targets, so you need a C compiler; hf-hub brings TLS for downloads. The memory-mapped weight loader is an unsafe function; I used the buffered one. Burn's Flex backend is pure Rust.

**46. "Licences?"**
- **Answer:** Candle and Burn are MIT or Apache-2.0. My code: candle-batteries is MIT, the rest MIT or Apache-2.0. The models: ResNet-18 weights from timm, MiniLM and SmolLM2 under Apache-2.0, TinyStories under MIT.

**47. "Who is behind them? Will they still be around?"**
- **Answer:** Candle comes from Hugging Face, Burn from Tracel AI, which also makes CubeCL. Both release often. Downloads of the main crate on crates.io: candle-core about 11 million, burn about 2 million; CI counts too, so take that as a rough signal.

**48. "Mixed precision, f16 or bf16?"**
- **Answer:** Candle has F16 and BF16 types, and the quantized GGUF types. In Burn the float width is a run-time value. All my demos use f32, plus SmolLM2's 8-bit weights. Not tested.

**49. "Multi-GPU or distributed training?"**
- **Answer:** Candle's README mentions multi-GPU through NCCL. For Burn I do not know. Out of scope for this talk.

**50. "What about classical ML, random forests, k-means?"**
- **Answer:** Different tools: linfa is the Rust crate for that. In my Hacker News project I put XGBoost on top of MiniLM embeddings.

**51. "Why not dfdx, with shapes in the types?"**
- **Answer:** dfdx puts full shapes into types; Candle's README calls that "a bit daunting for non rust experts". Its last release was 0.13.0, in July 2023. Burn sits in between: the rank is in the type, the sizes are values.

**52. "Can Burn read GGUF files?"**
- **Answer:** I used GGUF only with Candle. Burn loads safetensors, PyTorch files and its own Burnpack; for the llama2.c file I wrote the reader myself. I have not checked GGUF in Burn.

**53. "Does it work offline or air-gapped?"**
- **Answer:** Yes. hf-hub caches the files in ~/.cache/huggingface, or HF_HOME; after the first download all three Candle programs ran with the network cut. Copy the cache to another machine and they run there.

**54. "How did you get include_bytes aligned?"**
- **Answer:** A `#[repr(C, align(256))]` wrapper struct around the included bytes. Burnpack aligns tensor data to 256 bytes from the start of the file, and include_bytes only guarantees 1.
- *Evidence:* slide 35.

**55. "What about power consumption?"**
- **Answer:** Not measured; there was no hardware run.

### Asked by Ludwig on the morning of the talk

**56. "What is ONNX?"**
- **Answer:** Open Neural Network Exchange: an open file format for trained models, started in 2017 by Facebook and Microsoft, now a Linux Foundation project. A file holds the computation graph, made of standard operators with versioned operator sets, and the weights. Any runtime that implements those operators can run it. ONNX Runtime is Microsoft's; `ort` is its Rust binding. Burn's `burn-onnx` turns the graph into Rust source at build time; Candle's `candle-onnx` walks the graph at run time and supports a subset of operators. In this talk: slide 44 ("Import an ONNX model"), backup slide 48, and the MiniLM check against the official ONNX export.

**57. "How does autodiff work in each? Do they use std::autodiff?"**
- **Answer:** Neither uses the compiler. Both do reverse-mode autodiff in library code at run time. In Candle, every tensor remembers the operation and inputs that made it; trainable weights are `Var`s, and `loss.backward()` walks that graph backwards and returns a store of gradients. In Burn, autodiff is a backend decorator: in 0.22 you ask the device for it (`Device::flex().autodiff()`), it records the operations of the forward pass on a graph, and `loss.backward()` returns the gradients, which `GradientsParams` maps to the module's parameters for the optimizer.
- **std::autodiff** is different: an experimental nightly feature that differentiates ordinary Rust functions inside the compiler, with Enzyme working on the optimized LLVM IR. It is attractive because it differentiates plain Rust (loops, scalars, structs), not just tensor operations, without recording a graph at run time, and the gradient code is optimized like any other code. It is not used here because it is nightly only (as of the April 2026 Rust project goals update, partly in CI, with Enzyme artifacts placed by hand and no rustup component yet, macOS still missing), and because a framework's work happens in kernels and at run time: GPU kernels through CubeCL, gemm, graphs whose shapes are known only when they run. Burn and Candle target stable Rust.
- **Don't claim:** that it will never be used; Burn or Candle could adopt it for parts once it is stable.

**58. "Why did Burn 0.22 remove the Candle backend and deprecate NdArray and LibTorch?"**
- **Answer:** Tracel does not say why. The release post and the migration guide only state it: "Candle has been removed, while NdArray and LibTorch are deprecated." My reading, not theirs: in 0.22 the backend became a runtime device, and their own backends now cover every target. Flex is a pure-Rust CPU backend that also runs in WebAssembly and without std (where NdArray was the usual choice), the CubeCL CPU backend compiles kernels, and the CubeCL GPU backends cover CUDA, ROCm, Metal, Vulkan and WebGPU, so LibTorch, with its big C++ dependency, is no longer needed for GPUs. The Candle backend had been "in alpha stage, not all operations are supported" (its README).
- **Don't claim:** a reason from Tracel; there is none in writing.

**59. "What is Adam?"**
- **Answer:** The most common optimizer, from Kingma and Ba (2014): gradient descent with a step size per parameter. It keeps two running averages per weight, of the gradient (momentum) and of the squared gradient, corrects both for their start at zero, and divides the first by the square root of the second: big steps where gradients are small and steady, small steps where they jump. Defaults: β1 0.9, β2 0.999, ε 1e-8. AdamW decouples the weight decay; with weight decay 0 it is Adam, which is why Candle's AdamW and Burn's Adam give the same updates in the sine experiment (slides 29 to 32). Without std, burn-optim did not compile, so `burn-nostd` has its own Adam in 78 lines (slide 37).
