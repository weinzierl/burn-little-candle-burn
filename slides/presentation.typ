// Burn, little candle, burn!  RustLab 2026, Bologna.
// Build from the repository root:
//   typst compile --root . --ignore-system-fonts --font-path fonts/public \
//     --input fonts=public slides/presentation.typ presentation-public.pdf
// See README.md and the justfile for the private (Ergonomique) build.

#import "theme.typ": *

#show: deck

// Paths are relative to the repository root (--root .).
#let src = "/code"
#let out = "/code/out"

// Small readers for captured output.
#let first-line-with(path, prefix) = read(path).split("\n").find(l => l.starts-with(prefix))
#let loss-rows(path) = {
  read(path)
    .split("\n")
    .filter(l => l.starts-with("step ") and l.contains("loss"))
    .map(l => {
      let p = l.split(" ").filter(s => s != "")
      (p.at(1), p.at(3))
    })
}
#let sizes(path) = {
  let d = (:)
  for l in read(path).split("\n") {
    let p = l.split(" ").filter(s => s != "")
    if p.len() >= 2 { d.insert(p.at(0), int(p.at(1))) }
  }
  d
}
#let kib(n) = num(calc.round(n / 1024))
#let mb(n) = str(calc.round(n / 1000000, digits: 2))

#let cb = "/candle-batteries"
#let cbo = "/candle-batteries/out"
#let bn = "/burn-nostd"
#let bno = "/burn-nostd/out"

// The first capture group of `pattern` in a captured file.
#let grab(path, pattern) = {
  let m = read(path).match(regex(pattern))
  assert(m != none, message: "no match for " + pattern + " in " + path)
  m.captures.at(0)
}
// Model files as cached by hf-hub: repository, file, bytes, SHA-256.
#let models = read(cbo + "/models.txt").trim().split("\n").map(l => l.split(" "))
#let model-size-in(repo, file) = {
  let m = models.find(r => r.at(0) == repo and r.at(1) == file)
  assert(m != none, message: "no model file " + repo + " " + file)
  int(m.at(2))
}
#let model-size(file) = {
  let m = models.find(r => r.at(1) == file)
  assert(m != none, message: "no model file " + file)
  int(m.at(2))
}
#let mbr(n) = str(int(calc.round(n / 1000000)))
#let mb1(n) = str(calc.round(n / 1000000, digits: 1))

#let sine-bytes = int(grab(bno + "/sine.txt", "(\\d+) bytes of weights"))
#let sine-us = grab(bno + "/sine.txt", "(\\d+) µs per inference")
#let sine-err = grab(bno + "/sine.txt", "max error ([0-9.]+)")
#let q-sine-heap = int(grab(bno + "/qemu-sine.txt", "heap peak (\\d+) bytes"))
#let g-train-ms = grab(bno + "/gesture.txt", "epochs: (\\d+) ms")
#let g-acc = grab(bno + "/gesture.txt", "accuracy (\\d+/\\d+)")
#let q-g-heap = int(grab(bno + "/qemu-gesture.txt", "heap peak (\\d+) bytes"))
#let k-train-ms = grab(bno + "/keywords.txt", "trained in (\\d+) ms")
#let k-correct = grab(bno + "/keywords.txt", "(\\d+/\\d+) correct")
#let q-k-heap = int(grab(bno + "/qemu-keywords.txt", "heap peak (\\d+) bytes"))
#let t-bytes = int(grab(bno + "/qemu-tinystories.txt", "(\\d+) bytes of weights from flash"))
#let q-t-heap = int(grab(bno + "/qemu-tinystories.txt", "heap peak (\\d+) bytes"))
#let adam-lines = read(bn + "/adam/src/lib.rs").trim().split("\n").len()
// llama2.c header: dim, hidden, layers, heads, kv heads, vocab, seq len (7 x i32); the KV cache
// holds keys and values for every layer and position. The firmware loads the model with a
// shorter context than the header's seq len (Llama::load(..., 128) in the QEMU program).
#let t-header(k) = {
  let h = read(bn + "/4-tinystories/model/stories260K.bin", encoding: none).slice(0, 28)
  int.from-bytes(h.slice(k * 4, k * 4 + 4), endian: "little", signed: true)
}
#let t-context = int(grab(bn + "/qemu/src/bin/tinystories.rs", "Llama::load\\(stories260k::WEIGHTS, &device, (\\d+)\\)"))
#let t-seq-len = t-header(6)
#let kv-per-position = 2 * t-header(2) * calc.quo(t-header(0) * t-header(4), t-header(3)) * 4
#let kv-bytes = kv-per-position * t-context
#let heap-bytes = int(grab(bn + "/qemu/src/lib.rs", "init!\\(HEAP, (\\d+) \\* 1024\\)")) * 1024
#let story-start = read(bno + "/qemu-tinystories.txt").split("\n").at(0)
#let ask-tokens = grab(cbo + "/ask.err", "(\\d+) tokens,")
#let ask-rate = grab(cbo + "/ask.err", "([0-9.]+) tokens/s")
// SmolLM2 GGUF header (tools/gguf_stats.py) and the MiniLM reference check.
#let q8-weights = int(grab(cbo + "/gguf-stats.txt", "Q8_0: \\d+ tensors, (\\d+) weights"))
#let q8-bytes = int(grab(cbo + "/gguf-stats.txt", "Q8_0: \\d+ tensors, \\d+ weights, (\\d+) bytes"))
#let all-weights = int(grab(cbo + "/gguf-stats.txt", "total: (\\d+) weights"))
#let minilm-diff = float(grab("/tools/minilm-reference/result.txt", "in a score: +([0-9.e+-]+)"))
#assert(minilm-diff < 0.000001)
#assert(read("/tools/minilm-reference/result.txt").contains("PASS"))
#let minilm-bound = "0.000000" + str(calc.ceil(minilm-diff * 10000000))

// ------------------------------------------------------------------
// Opening
// ------------------------------------------------------------------

#title-slide(
  title: [Burn, \ little candle, \ #text(fill: ink.gold)[burn!]],
  subtitle: [Machine learning in Rust with Candle and Burn],
  author: "Ludwig Weinzierl",
  event: "RustLab Bologna 2026 · 2 November",
)

#let slide-on = slide
#let slide = slide-on.with(bg: ink.teal)

// One side of the opening comparison: label, size, model, captured output.
#let hook-col(label, size, model, out) = {
  set block(spacing: 0pt)
  set par(spacing: 0pt)
  block(below: 22pt, label-text(label))
  block(below: 16pt, text(font: fonts.head, weight: 700, size: 44pt, size))
  block(below: 24pt, text(size: 21pt, fill: c.grey, model))
  out
}

#slide(
  id: "hook",
  title: [Two ends of one scale],
  tag: "captured output · both ran during preparation",
)[
  #grid(
    columns: (1fr, 1fr),
    column-gutter: 28pt,
    hook-col("Candle · CPU, 2 cores", [#mbr(model-size("smollm2-360m-instruct-q8_0.gguf")) MB],
      [SmolLM2-360M-Instruct, 8-bit], prose-out(read(cbo + "/ask.txt").trim(), size: 18pt)),
    hook-col("Burn · no_std · emulated Cortex-M33", [#mb1(t-bytes) MB],
      [TinyStories 260K, f32, in 520 KiB of RAM], prose-out(story-start, size: 18pt)),
  )
  #v(1fr)
  #note[Sizes of the weight files. Left: Candle 0.11 on a 2-core Linux VM. Right: Burn 0.22 without std in QEMU (mps2-an505), RAM limited to the Pico 2’s 520 KiB; not yet on a real board.]
]

#slide(id: "me", title: [Ludwig Weinzierl])[
  #grid(
    columns: (1fr, 1fr),
    column-gutter: 40pt,
    [
      - Rust since 2015
      - Co-organizer, Rust Munich Meetup
      - Embedded, LoRaWAN, retro computing
    ],
    [
      - Not an ML researcher
      - Used Candle for MiniLM sentence embeddings in a comment score predictor
    ],
  )
  #v(1fr)
  #note[github.com/weinzierl]
]

#slide(id: "question", title: [What does it take to do ML in Rust?])[
  #v(10pt)
  #grid(
    columns: (auto, 1fr),
    column-gutter: 24pt,
    row-gutter: 26pt,
    align: (left + top, left + top),
    text(font: fonts.head, weight: 700, size: 44pt, fill: c.accent)[1],
    [*Use someone else's model* \ #text(fill: c.grey)[an image, a sentence, a chat: Candle and the Hub]],
    text(font: fonts.head, weight: 700, size: 44pt, fill: c.accent)[2],
    [*Train one model in both* \ #text(fill: c.grey)[sin(x), from the same start]],
    text(font: fonts.head, weight: 700, size: 44pt, fill: c.accent)[3],
    [*Leave std behind* \ #text(fill: c.grey)[Burn on an emulated microcontroller, from sin(x) to a language model]],
  )
  #v(1fr)
  #note[Everything shown ran during preparation, on the platform each slide names.]
]

// ------------------------------------------------------------------
// 01 Two frameworks
// ------------------------------------------------------------------

#section-slide(id: "s1", num: "01", title: "Two frameworks", question: [What does each one want to be?])

#let slide = slide-on.with(bg: ink.plum)

#slide(id: "jobs", title: [What a framework does for you], tag: "concept")[
  #v(8pt)
  #grid(
    columns: (1fr, 1fr),
    column-gutter: 32pt,
    row-gutter: 44pt,
    ..(
      ("Tensors", "n-dimensional arrays, and fast kernels for them"),
      ("Autodiff", "gradients through tensor operations, for training"),
      ("Weights in and out", "files you can save, share and load"),
      ("Backends", "CPU, GPU, browser, microcontroller"),
    ).map(((k, v)) => block(
      width: 100%,
      stroke: (top: 2pt + c.ink),
      inset: (top: 14pt),
      [#text(font: fonts.head, weight: 700, size: 32pt, k) \ #text(size: 24pt, fill: c.grey, v)],
    ))
  )
]

#slide(id: "candle", title: [Candle], tag: "Hugging Face · since 2023 · 0.11")[
  #text(size: 24pt, fill: c.grey)[“Minimalist ML framework for Rust with a focus on performance (including GPU support) and ease of use.”]
  #v(12pt)
  - PyTorch-like API: runtime shapes, errors as `Result`
  - Goal: serverless inference, Python out of production
  - `candle-transformers`: 100 model implementations, plus 22 quantized (GGUF) variants
  - CPU (MKL, Accelerate), CUDA, Metal, WebAssembly
]

#slide(id: "burn", title: [Burn], tag: "Tracel AI · since 2022 · 0.22")[
  #text(size: 24pt, fill: c.grey)[“Burn is both a tensor library and a deep learning framework, optimized for numerical computing, training and inference.”]
  #v(12pt)
  - Training built in: optimizers, `Learner`, terminal dashboard
  - CubeCL backends: CUDA, ROCm, Metal, Vulkan, WebGPU, CPU, with kernel fusion
  - Flex: pure-Rust CPU backend, also for Wasm and `no_std`
  - Imports ONNX (as generated Rust code), PyTorch and safetensors weights
]

#slide(id: "burn022", title: [Burn 0.22 moved the backend], tag: "Burn · 0.22.0 released 6 October 2026")[
  #grid(
    columns: (1fr, 1fr),
    column-gutter: 24pt,
    code(
      "fn forward<B: Backend>(\n    x: Tensor<B, 2>,\n) -> Tensor<B, 2>\n\ntype B = Autodiff<NdArray>;",
      size: 20pt,
      label: "up to 0.21",
    ),
    code(
      "fn forward(\n    x: Tensor<2>,\n) -> Tensor<2>\n\nlet dev = Device::flex()\n    .autodiff();",
      size: 20pt,
      label: "0.22",
    ),
  )
  #v(10pt)
  - The backend is a runtime `Device`, no longer a type parameter
  - Burn’s Candle backend removed; NdArray and LibTorch deprecated
  #v(1fr)
  #note[Signatures only, to show the shape of the API. Many older tutorials show the old one. So does my abstract.]
]

// ------------------------------------------------------------------
// 02 Tensors
// ------------------------------------------------------------------

#section-slide(id: "s2", num: "02", title: "Tensors", question: [Where does the information live?])

#let slide = slide-on.with(bg: ink.olive)

#slide(id: "hello-candle", title: [One matrix product: Candle], tag: "Candle · ran on Linux x86-64")[
  #code(snippet(src + "/candle-demo/src/bin/candle_hello.rs", "hello"), size: 22pt)
  #v(6pt)
  #term(out-lines(out + "/candle-hello.txt"), size: 21pt, label: "output")
  #v(1fr)
  #note[Operations that can fail return `Result<Tensor>`. The tensor knows its shape and element type at run time.]
]

#slide(id: "hello-burn", title: [One matrix product: Burn], tag: "Burn · ran on Linux x86-64")[
  #grid(
    columns: (1.6fr, 1fr),
    column-gutter: 18pt,
    code(snippet(src + "/burn-demo/src/bin/burn_hello.rs", "hello"), size: 18pt),
    term(out-lines(out + "/burn-hello.txt"), size: 15pt, label: "output"),
  )
  #v(1fr)
  #note[No `?`. The rank is in the type: `Tensor::<2>`. `matmul` takes `self`, so `a` is cloned to use it twice; the clone only bumps a reference count.]
]

#slide(id: "shapes-candle", title: [Wrong shapes: Candle returns an error], tag: "Candle · ran on Linux x86-64")[
  #code(snippet(src + "/candle-demo/src/bin/candle_errors.rs", "mismatch"), size: 22pt)
  #v(6pt)
  #term(out-lines(out + "/candle-errors.txt", from: 0, to: 1), size: 21pt, label: "output")
  #v(1fr)
  #note[A shape error is a value. The program decides what happens next.]
]

#slide(id: "shapes-burn", title: [Wrong shapes: Burn panics], tag: "Burn · ran on Linux x86-64")[
  #code(snippet(src + "/burn-demo/src/bin/burn_errors.rs", "mismatch"), size: 22pt)
  #v(6pt)
  #let panic-lines = read(out + "/burn-errors.txt").split("\n")
  #let p0 = panic-lines.position(l => l.starts-with("=== Tensor Operation Error"))
  #term-wrap(panic-lines.slice(p0, p0 + 4).join("\n"), size: 18pt, max: 72, label: "output (panic message)")
  #v(1fr)
  #note[Burn treats it like a slice index out of bounds: a bug, so it panics. Check shapes from outside before the call.]
]

#slide(id: "rank", title: [Wrong rank: Burn does not compile], tag: "Burn · compile error, captured")[
  #code(snippet(src + "/burn-demo/src/bin/burn_rank_error.rs", "rank"), size: 21pt)
  #v(4pt)
  #term(out-lines(out + "/burn-rank-error.txt", from: 0, to: 10), size: 17pt, label: "cargo build")
  #v(1fr)
  #note[`matmul` wants equal ranks: a `[3, 1]` matrix works. Candle catches this at run time.]
]

#slide(id: "where", title: [Where the information lives], tag: "Candle 0.11 · Burn 0.22")[
  #set text(size: 23pt)
  #table(
    columns: (1.25fr, 1.6fr, 1.9fr),
    stroke: (x, y) => (top: if y == 0 { none } else if y == 1 { 1.6pt + c.ink } else { 0.6pt + c.rule }),
    inset: (x: 6pt, y: 10pt),
    table.header(
      [], text(font: fonts.head, weight: 700)[Candle], text(font: fonts.head, weight: 700)[Burn],
    ),
    [rank], [value], [type: `Tensor<2>`],
    [shape], [value], [value],
    [element type], [value: `DType::F32`], [kind in the type (`Int`), width a value],
    [device], [value: `Device::Cpu`], [value: `Device::flex()`],
    [shape error], [`Err(…)`], [panic],
    [operations], [borrow: `&self`], [move: `self`, cheap clone],
  )
]

// ------------------------------------------------------------------
// 03 Candle, batteries included
// ------------------------------------------------------------------

#section-slide(id: "s3", num: "03", title: [Candle, batteries included], question: [How far do a few lines get you?])

#let slide = slide-on.with(bg: ink.brick)

#slide(id: "hub", title: [A model is a download away], tag: "hf-hub 1.0 · original repositories")[
  #code(cut(cb + "/2-classify/src/main.rs", "let weights = HFClientSync", ".send()?;"), size: 21pt)
  #v(6pt)
  #set text(size: 22pt)
  #table(
    columns: (auto, 1fr, auto),
    stroke: (x, y) => (top: if y == 0 { none } else if y == 1 { 1.6pt + c.ink } else { 0.6pt + c.rule }),
    inset: (x: 6pt, y: 7pt),
    table.header(text(font: fonts.head, weight: 700)[Program], text(font: fonts.head, weight: 700)[Model, from the Hub], text(font: fonts.head, weight: 700)[Size]),
    [`classify`], [ResNet-18 · `timm/resnet18.gluon_in1k`], [#mbr(model-size-in("timm/resnet18.gluon_in1k", "model.safetensors")) MB],
    [`similar`], [MiniLM · `sentence-transformers/all-MiniLM-L6-v2`], [#mbr(model-size-in("sentence-transformers/all-MiniLM-L6-v2", "model.safetensors")) MB],
    [`ask`], [SmolLM2-360M-Instruct · `HuggingFaceTB`, 8-bit GGUF], [#mbr(model-size("smollm2-360m-instruct-q8_0.gguf")) MB],
  )
  #v(1fr)
  #note[Downloaded once into `~/.cache/huggingface`, then read from there: with the network cut, all three programs still ran.]
]

#slide(id: "classify", title: [An image: ResNet-18], tag: "Candle 0.11 · CPU · ran on Linux x86-64")[
  #code(cut(cb + "/2-classify/src/main.rs", "let bytes = fs::read(weights)", "let probs = softmax_last_dim"), size: 17pt)
  #v(10pt)
  #grid(
    columns: (auto, 1fr),
    column-gutter: 20pt,
    align: (left + top, left + top),
    image(cb + "/2-classify/images/cat.jpg", height: 150pt),
    term(read(cbo + "/classify-cat.txt").trim(), size: 19pt, label: "cargo classify 2-classify/images/cat.jpg"),
  )
  #v(1fr)
  #note[The architecture comes from `candle-transformers`, the weights from the Hub. Scaling the image like the training images is your job.]
]

#slide(id: "similar", title: [A sentence: MiniLM], tag: "Candle 0.11 · candle-batteries step 3")[
  #code(cut(cb + "/3-similar/src/main.rs", "let hidden = model.forward", "Ok(mean.broadcast_div"), size: 20pt, label: "one vector per sentence")
  #v(8pt)
  #code(cut(cb + "/3-similar/src/main.rs", "// Unit vectors", "let scores ="), size: 20pt, label: "compare")
  #v(1fr)
  #note[The model returns one vector per token. Averaging them into one vector per sentence, and making it length 1, is the part you write. Count the padding and it still compiles and runs: correct Rust, wrong embeddings.]
]

#slide(id: "similar-out", title: [Five sentences about Bologna], tag: "Candle 0.11 · CPU · ran on Linux x86-64")[
  #grid(
    columns: (1fr, 1fr),
    column-gutter: 12pt,
    term(read(cbo + "/similar-eat.txt").trim(), size: 16pt, label: "“Where can I eat tonight?”"),
    term(read(cbo + "/similar-rain.txt").trim(), size: 16pt, label: "“It is raining.”"),
  )
  #v(10pt)
  #grid(
    columns: (1fr, 1fr),
    column-gutter: 12pt,
    term(read(cbo + "/similar-old.txt").trim(), size: 16pt, label: "“How old is the city?”"),
    term(read(cbo + "/similar-router.txt").trim(), size: 16pt, label: "“How do I reset my router?”"),
  )
  #v(1fr)
  #note[Cosine similarity: 1 means the same direction. The tortellini sentence shares no word with its question. The router question still gets a top sentence: nearest is not relevant.]
]

#slide(id: "ask", title: [A chat: SmolLM2, one token at a time], tag: "Candle 0.11 · quantized LLaMA · GGUF")[
  #code(cut-n(cb + "/4-ask/src/main.rs", "for _ in 0..256", 14), size: 18pt)
  #v(1fr)
  #note[`pos` tells the model how much it has already seen: the KV cache inside `ModelWeights` keeps the rest. The prompt goes in once, then one token per step.]
]

#slide(id: "ask-out", title: [What it answers], tag: "Candle 0.11 · CPU, 2 cores · ran on Linux x86-64")[
  #code(cut(cb + "/4-ask/src/main.rs", "let prompt = format!(", ");"), size: 19pt, label: "the chat template is plain text")
  #v(8pt)
  #prose-out(read(cbo + "/ask.txt").trim(), size: 21pt, label: "cargo ask")
  #v(6pt)
  #text(size: 22pt)[#ask-tokens tokens, #ask-rate tokens/s on 2 CPU cores, 8-bit weights.]
  #v(1fr)
  #note[Sampling: top-p 0.9, temperature 0.5, seed 42. Same seed, same answer on this machine; Metal and CUDA are cargo features.]
]

#slide(id: "you-write", title: [What Candle gives you, what you write], tag: "concept")[
  #set text(size: 23pt)
  #table(
    columns: (1fr, 1fr),
    stroke: (x, y) => (top: if y == 0 { none } else if y == 1 { 1.6pt + c.ink } else { 0.6pt + c.rule }),
    inset: (x: 6pt, y: 10pt),
    table.header(text(font: fonts.head, weight: 700)[Candle and friends], text(font: fonts.head, weight: 700)[You]),
    [model code: ResNet, BERT, LLaMA], [scale and normalize the image],
    [weights from the Hub, cached], [average the token vectors],
    [tokenizers, the Rust library Python uses], [the chat template],
    [GGUF reader, sampler, KV cache], [the loop that asks for the next token],
  )
  #v(1fr)
  #note[`candle-transformers` 0.11 ships 100 model implementations and 22 quantized variants.]
]

// ------------------------------------------------------------------
// 04 Learning sin(x)
// ------------------------------------------------------------------

#section-slide(id: "s4", num: "04", title: [Learning sin(x)], question: [Do they agree?])

#let slide = slide-on.with(bg: ink.teal)

#slide(id: "loop", title: [Learning, in four lines], tag: "concept")[
  #let rows = (
    ([predict], [`ŷ = model(x, w)`], [forward pass]),
    ([measure], [`loss = mean((ŷ − y)²)`], [one number]),
    ([blame], [`g = ∂loss / ∂w`], [autodiff]),
    ([adjust], [`w = w − lr · g`], [optimizer]),
  )
  #v(6pt)
  #grid(
    columns: (180pt, 1fr, auto),
    row-gutter: 42pt,
    align: (left + horizon, left + horizon, left + horizon),
    ..rows.map(r => (
      text(font: fonts.head, weight: 700, size: 30pt, fill: c.accent, r.at(0)),
      text(size: 27pt, r.at(1)),
      text(size: 22pt, fill: c.grey, r.at(2)),
    )).flatten()
  )
  #v(1fr)
  #note[`w`: all weights, `lr`: learning rate. The simplest form: squared error and plain gradient descent. Every training run in this talk follows this loop, with Adam, and the classifiers with cross-entropy.]
]

#slide(id: "sine-task", title: [Experiment 1: learn sin(x)], tag: "concept")[
  #grid(
    columns: (1fr, 1.05fr),
    column-gutter: 24pt,
    [
      - 256 points on [−π,~π]
      - Layers 1 #ar 32 #ar 32 #ar 1, tanh
      - 1~153 parameters
      - Adam, learning rate 0.01, 2~000 steps
      - One shared start: #box[`sine-init.safetensors`]
    ],
    block(height: 320pt, width: 100%)[
      #let mid = 150pt
      #let gap = 34pt
      #let ys = range(8).map(i => mid - 3.5 * gap + i * gap)
      #for a in ys { for b in ys { place(line(start: (150pt, a), end: (260pt, b), stroke: 0.4pt + c.rule)) } }
      #for a in ys {
        place(line(start: (40pt, mid), end: (150pt, a), stroke: 0.6pt + c.rule))
        place(line(start: (260pt, a), end: (370pt, mid), stroke: 0.6pt + c.rule))
      }
      #let dot(x, y) = place(dx: x - 7pt, dy: y - 7pt, circle(radius: 7pt, stroke: 1.4pt + c.ink, fill: c.paper))
      #dot(40pt, mid)
      #for y in ys { dot(150pt, y); dot(260pt, y) }
      #dot(370pt, mid)
      #place(dx: 20pt, dy: mid + 16pt, text(size: 21pt)[x])
      #place(dx: 360pt, dy: mid + 16pt, text(size: 21pt)[ŷ])
      #place(dx: 116pt, dy: 282pt, text(size: 17pt, fill: c.grey)[32, tanh])
      #place(dx: 226pt, dy: 282pt, text(size: 17pt, fill: c.grey)[32, tanh])
      #place(dx: 196pt, dy: 6pt, text(size: 15pt, fill: c.grey)[(8 of 32 drawn)])
    ],
  )
]

#slide(id: "sine-model", title: [The model, twice], tag: "Candle · Burn")[
  #code(snippet(src + "/candle-demo/src/bin/candle_sine.rs", "forward"), size: 21pt, label: "Candle")
  #v(8pt)
  #code(snippet(src + "/burn-demo/src/bin/burn_sine.rs", "forward"), size: 21pt, label: "Burn")
  #v(1fr)
  #note[Same structure. Candle: borrow and `?`. Burn: move, no `Result`.]
]

#slide(id: "sine-train-candle", title: [Training loop: Candle], tag: "Candle · ran on Linux x86-64")[
  #code(snippet(src + "/candle-demo/src/bin/candle_sine.rs", "train"), size: 21pt)
  #v(1fr)
  #note[`backward_step` runs the backward pass and the optimizer step. AdamW with weight decay 0 is plain Adam.]
]

#slide(id: "sine-train-burn", title: [Training loop: Burn], tag: "Burn · ran on Linux x86-64")[
  #code(snippet(src + "/burn-demo/src/bin/burn_sine.rs", "train"), size: 21pt)
  #v(1fr)
  #note[The optimizer takes the model by value and returns the updated one. No `zero_grad`: gradients are consumed. Model and data live on `Device::flex().autodiff()`.]
]

#slide(id: "sine-result", title: [Same start, same data, same curve], tag: "Candle · Burn · ran on Linux x86-64")[
  #let cl = loss-rows(out + "/candle-sine.txt")
  #let bl = loss-rows(out + "/burn-sine.txt")
  #grid(
    columns: (1fr, 1.05fr),
    column-gutter: 30pt,
    [
      #set text(font: fonts.mono, size: 18pt)
      #table(
        columns: (auto, 1fr, 1fr),
        align: (right, right, right),
        stroke: (x, y) => (top: if y == 1 { 1.2pt + c.ink } else { none }),
        inset: (x: 8pt, y: 4.4pt),
        table.header(
          text(font: fonts.body, size: 16pt, fill: c.grey)[step],
          text(font: fonts.body, size: 16pt, fill: c.grey)[Candle],
          text(font: fonts.body, size: 16pt, fill: c.grey)[Burn],
        ),
        ..cl.zip(bl).map(((a, b)) => (a.at(0), a.at(1), b.at(1))).flatten(),
      )
    ],
    [
      #let rows = csv(out + "/sine-burn.csv").slice(1)
      #let px(x) = (float(x) + 3.2) / 6.4 * 400pt
      #let py(y) = 120pt - float(y) * 105pt
      #block(width: 400pt, height: 260pt)[
        #place(line(start: (0pt, 120pt), end: (400pt, 120pt), stroke: 0.6pt + c.rule))
        #place(curve(
          stroke: 2.2pt + c.ink,
          curve.move((px(rows.at(0).at(0)), py(rows.at(0).at(1)))),
          ..rows.slice(1).map(r => curve.line((px(r.at(0)), py(r.at(1))))),
        ))
        #for (i, r) in rows.enumerate() {
          if calc.rem(i, 12) == 0 {
            place(dx: px(r.at(0)) - 4.5pt, dy: py(r.at(2)) - 4.5pt, circle(radius: 4.5pt, fill: c.accent, stroke: none))
          }
        }
        #let max-err = calc.max(..rows.map(r => calc.abs(float(r.at(2)) - float(r.at(1)))))
        #place(dx: 0pt, dy: 238pt, text(size: 16pt, fill: c.grey)[line: sin(x) on \[−π, π\] · dots: Burn model · max error #calc.round(max-err, digits: 4) at the 256 training points])
      ]
    ],
  )
  #v(1fr)
  #let us(fw) = read(out + "/sine-timing.txt").split("\n").filter(l => l.starts-with(fw + " ")).map(l => int(l.split("(").at(1).split(" ").at(0)))
  #note[Loss (mean squared error) after every 250 updates; the 2000 row is a check after the loop. The first losses differ in the last digit: floating point, likely Burn’s SIMD adding in another order. Informal timing, five runs each on 2 vCPUs: Candle #calc.min(..us("candle")) to #calc.max(..us("candle"))~µs per step, Burn #calc.min(..us("burn")) to #calc.max(..us("burn"))~µs.]
]

#slide(id: "layout", title: [The detail that made it work], tag: "Candle · Burn")[
  #grid(
    columns: (1fr, 1fr),
    column-gutter: 30pt,
    [
      #text(font: fonts.head, weight: 700, size: 28pt)[Candle, PyTorch]
      #v(2pt)
      weight stored `[out, in]` \
      forward: `x · transpose(W) + b`
    ],
    [
      #text(font: fonts.head, weight: 700, size: 28pt)[Burn]
      #v(2pt)
      weight stored `[in, out]` \
      forward: `x · W + b`
    ],
  )
  #v(18pt)
  #code(snippet(src + "/burn-demo/src/bin/burn_sine.rs", "init"), size: 21pt, label: "Burn, loading the shared start")
  #v(1fr)
  #note[Same `Linear` layer, transposed storage. `burn-store` adapters transpose on load (`PyTorchToBurnAdapter`) and on save (`BurnToPyTorchAdapter`).]
]

// ------------------------------------------------------------------
// 05 Burn without std
// ------------------------------------------------------------------

#section-slide(id: "s5", num: "05", title: [Burn without std], question: [How small can it go?])

#let slide = slide-on.with(bg: ink.slate)

#let stair = ((56, 268, 280), (268, 480, 254), (480, 692, 228), (692, 904, 202))
#let stair-line = polyline(
  ((-10, base), (56, base), ..stair.map(((x0, x1, t)) => ((x0, t), (x1, t))).flatten().chunks(2), (904, base), (970, base)),
  (0,) + (10,) * 8 + (0,),
)
#slide(
  id: "steps",
  title: [Four steps, one `#![no_std]` crate each],
  tag: "burn-nostd · Burn 0.22.0 · Flex backend",
  line: stair-line,
)[
  #text(size: 21pt)[Each runs without std: on the desktop, as zero-import WebAssembly, and on an emulated Cortex-M33 with the Pico 2’s 520 KiB of RAM. Pico 2 firmware builds; not yet run on a board.]
  #v(2pt)
  #note[Candle is not in this part: it needs std. Its build for `thumbv8m.main-none-eabihf` stops at `getrandom`.]
  #let steps = (
    ("1", [Inference], [weights stay in flash], [321 parameters]),
    ("2", [Training], [autodiff on the device], [#num(1316) parameters]),
    ("3", [Audio], [sound, FFT, words], [#num(5448) parameters]),
    ("4", [Pretrained LLM], [someone else's weights], [TinyStories 260K]),
  )
  #for ((x0, x1, t), (n, name, what, size)) in stair.zip(steps) {
    place(top + left, dx: (x0 + 14) * 1pt - margin.left, dy: (t + 12) * 1pt - margin.top, block(width: (x1 - x0 - 28) * 1pt)[
      #text(font: fonts.head, weight: 700, size: 44pt, fill: c.accent, n) \
      #text(font: fonts.head, weight: 700, size: 24pt, name) \
      #v(2pt)
      #text(size: 19pt, what) \
      #v(2pt)
      #text(size: 19pt, size)
    ])
  }
]

#slide(id: "step1", title: [1 · Inference: the weights stay in flash], tag: "Burn no_std · a smaller sine model of its own · desktop, QEMU · plot: browser page")[
  #set block(spacing: 14pt)
  #code(cut(bn + "/1-sine/src/lib.rs", "#[repr(C, align(256))]", "pub static WEIGHTS"), size: 18pt, wrap: 74)
  #grid(
    columns: (auto, 1fr),
    column-gutter: 20pt,
    align: (left + top, left + top),
    box(stroke: 0.6pt + c.rule, image("media/sine-plot.png", width: 434pt)),
    grid(
      columns: (1fr, 1fr),
      row-gutter: 14pt,
      column-gutter: 14pt,
      fact[#num(sine-bytes)][bytes in flash, one Burnpack file],
      fact[#sine-us µs][per inference, desktop],
      fact[#sine-err][largest error, 25 points],
      fact[#num(q-sine-heap)][bytes heap peak, emulated M33],
    ),
  )
]

#slide(id: "step2", title: [2 · Training on the device], tag: "Burn no_std · autodiff · desktop and QEMU")[
  #code(cut(bn + "/desktop/src/bin/gesture.rs", "let mut learner = Learner::new", "let loss = learner.train(15);"), size: 19pt)
  #v(1fr)
  #facts(
    fact[#g-train-ms ms][15 epochs, 20 examples, desktop],
    fact[#g-acc][new synthetic windows right],
    fact[#kib(q-g-heap) KiB][heap peak, training, emulated M33],
  )
  #v(4pt)
  #note[`Learner` is the demo’s own helper. Training and test windows come from one synthetic generator, as on the browser page. On the Pico 2 an IMU and a button would supply them: built, not yet run.]
]

#slide(id: "step2-adam", title: [Two things std would have given], tag: "burn-nostd · checked against the crates' sources")[
  #code(cut(bn + "/2-gesture/src/lib.rs", "let loss = loss_fn.forward", "self.net = self.adam.step"), size: 18pt, wrap: 74, label: "inside train(): one example at a time")
  #v(8pt)
  - `burn-optim` 0.22.0 does not compile without std (6 errors, thumbv8m). Our `adam` is #num(adam-lines) lines: a `ModuleMapper` that updates each parameter.
  - Without std on Arm, gemm assumes a 512 KiB L2 cache, and each small matrix-matrix product allocates a packing buffer that size. One example at a time keeps them matrix-vector products, which pack nothing.
  #v(1fr)
  #note[Batch size 1 is the design, not laziness: a 512 KiB buffer cannot come out of a #calc.quo(heap-bytes, 1024) KiB heap.]
]

#slide(id: "step3", title: [3 · Audio: teach it words], tag: "Burn no_std · synthetic espeak-ng voice · desktop and QEMU")[
  #let boxes = (
    ([Audio], [16 kHz, mic or file]),
    ([Log-mel], [FFT, 16 bands]),
    ([Words], [loudness over the noise floor]),
    ([Features], [10 slices × 16 bands, plus length]),
    ([MLP], [#num(5448) parameters, trained here]),
  )
  #grid(
    columns: (1fr,) * 5,
    column-gutter: 12pt,
    ..boxes.enumerate().map(((i, (k, v))) => block(
      width: 100%,
      stroke: (top: 2pt + if i == 4 { c.accent } else { c.ink }),
      inset: (top: 8pt),
      [#text(font: fonts.head, weight: 700, size: 22pt, k) \ #text(size: 17pt, fill: c.grey, v)],
    ))
  )
  #v(10pt)
  #grid(
    columns: (1fr, 1fr),
    column-gutter: 20pt,
    align: (left + top, left + top),
    box(stroke: 0.6pt + c.rule, image("media/keywords-spec.png", width: 100%)),
    box(stroke: 0.6pt + c.rule, image("media/keywords-heard.png", width: 100%)),
  )
  #v(8pt)
  #facts(
    fact[#k-train-ms ms][training, 20 clips, desktop],
    fact[#k-correct][new synthetic words right],
    fact[#kib(q-k-heap) KiB][heap peak, emulated M33],
  )
  #v(1fr)
  #note[Only the last box learns. The voice is synthetic (espeak-ng), not a person: real microphones are untested.]
]

#slide(id: "step4", title: [4 · Someone else's model, straight from flash], tag: "Burn no_std · TinyStories 260K · own Llama code on Burn tensors")[
  #code(cut(bn + "/4-tinystories/src/lib.rs", "let bytes = bytes::Bytes::from_static", "Tensor::<2>::from_data"), size: 18pt, wrap: 74, label: "every weight tensor borrows the checkpoint")
  #v(1fr)
  #facts(
    fact[#mb1(t-bytes) MB][of f32 weights, never copied],
    fact[#kib(q-t-heap) KiB][heap peak, #kib(kv-bytes) KiB of it KV cache],
    fact[same text][as llama2.c's `run.c`],
  )
  #v(4pt)
  #note[Karpathy’s `stories260K.bin`, unchanged. Context cut to #t-context of its #t-seq-len positions: at #t-seq-len the KV cache alone would take #kib(kv-per-position * t-seq-len) KiB. At temperature 0 the text equals `run.c`’s for this prompt, 80 steps.]
]

#slide(id: "took", title: [What it took], tag: "burn-nostd · Burn 0.22.0")[
  #set text(size: 22pt)
  #table(
    // 40pt between the columns' text (the rules still run across); the left
    // column keeps every line it had, the right one moves the code below.
    columns: (1.32fr, 1fr),
    stroke: (x, y) => (top: if y == 0 { none } else if y == 1 { 1.6pt + c.ink } else { 0.6pt + c.rule }),
    inset: (x, y) => (left: if x == 0 { 6pt } else { 20pt }, right: if x == 0 { 20pt } else { 6pt }, y: 8pt),
    table.header(text(font: fonts.head, weight: 700)[Problem], text(font: fonts.head, weight: 700)[Fix]),
    [`web-time` and `wasm-bindgen-futures` pull std into no_std desktop and Wasm binaries], [two small shims via #box[`[patch.crates-io]`]],
    [`burn-optim` 0.22.0 does not compile without std], [Adam in #num(adam-lines) lines],
    [gemm's 512 KiB packing buffer per small product, no std, Arm], [batch size 1, one token at a time],
    [Burnpack wants 256-byte alignment], [`#[repr(align(256))]` wrapper],
    [no unwinder on a no_std Linux binary], [two empty symbols],
  )
  #v(1fr)
  #note[Burn’s tensor, autodiff, nn, store and Flex crates build without std; burn-optim 0.22.0 does not. A whole no_std program needed these five fixes, all in user code.]
]

#slide(id: "live", title: [Try it now, on your phone], tag: "no_std WebAssembly · zero imports · runs in your browser")[
  #grid(
    columns: (auto, 1fr),
    column-gutter: 40pt,
    align: (left + top, left + top),
    qr("media/qr-demos.svg", width: 220pt),
    [
      #text(size: 26pt)[weinzierl.github.io/burn-nostd]
      #v(10pt)
      - *Gesture:* record each gesture five times, train, then move the phone
      - *Keywords:* use the sample voice, train, play
      - *TinyStories:* writes a story when it opens
      #v(8pt)
      #note[The same Rust crates as the Pico 2 firmware. Nothing leaves the page.]
    ],
  )
]

// ------------------------------------------------------------------
// 06 Choosing
// ------------------------------------------------------------------

#section-slide(id: "s6", num: "06", title: "Choosing", question: [Which one, for what?])

#let slide = slide-on.with(bg: ink.plum)

#let tbl-top = 112
#let row-h = 40
#slide(
  id: "choose",
  title: [Which one?],
  tag: "my reading, November 2026 · GPUs not tested",
  line: (curve.move(P(-10, base)), ..arch(36, 924, tbl-top + row-h, r: 0), curve.line(P(970, base))),
)[
  #place(top + left, dy: (tbl-top * 1pt) - margin.top, {
    set text(size: 22pt)
    table(
      columns: (1.5fr, 0.85fr, 1.75fr),
      rows: row-h * 1pt,
      inset: (x: 6pt, y: 0pt),
      align: left + horizon,
      stroke: (x, y) => (top: if y < 2 { none } else { 0.6pt + c.rule }),
      table.header([], text(font: fonts.head, weight: 700)[Reach for], text(font: fonts.head, weight: 700)[Because]),
      [Run a model from the Hub], [Candle], [model zoo, tokenizers, GGUF],
      [Train in Rust], [Burn], [autodiff, optimizers, `Learner`],
      [Train on the device], [Burn], [autodiff works without std],
      [Microcontroller], [Burn], [Flex is `no_std`; Candle needs std],
      [GPUs beyond CUDA, Metal], [Burn], [CubeCL: Vulkan, WebGPU],
      [Import an ONNX model], [Burn], [`burn-onnx` writes Rust],
      [Move weights between them], [both], [safetensors, same names; adapters],
    )
  })
]

#slide(id: "takeaways", title: [Three things I take home])[
  #v(6pt)
  #grid(
    columns: (auto, 1fr),
    column-gutter: 24pt,
    row-gutter: 28pt,
    align: (left + top, left + top),
    text(font: fonts.head, weight: 700, size: 44pt, fill: c.accent)[1],
    [*Candle: batteries included.* A model from the Hub is a download and a few lines. What you write is the part around it.],
    text(font: fonts.head, weight: 700, size: 44pt, fill: c.accent)[2],
    [*Burn goes all the way down.* The same `Module` trains on a laptop and on an emulated Cortex-M33 with 520 KiB of RAM.],
    text(font: fonts.head, weight: 700, size: 44pt, fill: c.accent)[3],
    [*They agree.* Same start, same data: the printed losses match to six decimals from step 250 on.],
  )
]

#slide(id: "try", title: [Try it])[
  #set par(spacing: 12pt)
  #set block(spacing: 12pt)
  #grid(
    columns: (1fr, 1fr),
    column-gutter: 40pt,
    align: (left + top, left + top),
    [
      #qr("qr-repo.svg", width: 170pt, pad: 24pt)
      #v(8pt)
      #text(size: 21pt)[github.com/weinzierl/ \ burn-little-candle-burn]
      #v(4pt)
      #note[Slides, notes, the Candle programs, both sin(x) runs]
    ],
    [
      #qr("media/qr-demos.svg", width: 170pt, pad: 24pt)
      #v(8pt)
      #text(size: 21pt)[weinzierl.github.io/ \ burn-nostd]
      #v(4pt)
      #note[Burn without std: the four demos, code at github.com/weinzierl/burn-nostd]
    ],
  )
]

#end-slide[
  #set par(spacing: 0pt)
  #set block(spacing: 0pt)
  #place(top + left, dx: 394pt, dy: 92pt, qr("qr-repo.svg", width: 150pt))
  #v(24pt)
  #text(font: fonts.head, weight: 700, size: 104pt, tracking: -0.02em)[#set par(leading: 0.18em); Grazie \ mille.]
  #v(36pt)
  #text(size: 30pt)[Questions?]
  #v(1fr)
  #label-text[Slides and code]
  #v(10pt)
  #text(font: fonts.mono, size: 20pt)[github.com/weinzierl/burn-little-candle-burn]
  #v(10pt)
]

// ------------------------------------------------------------------
// Backup slides, for questions only (not in the timed talk)
// ------------------------------------------------------------------

#let slide = slide-on.with(bg: ink.black, tag: "backup · for questions")

#slide(id: "b-import", title: [Three ways a model comes in])[
  #set text(size: 21pt)
  #grid(
    columns: (1fr, 1fr, 1fr),
    column-gutter: 28pt,
    [#label-text("Weights") \ Safetensors or GGUF: named tensors, no code. You bring the architecture: Candle’s model zoo, or your own Burn module with burn-store, whose adapters convert PyTorch layouts.],
    [#label-text("Graph") \ ONNX. Burn: burn-onnx writes Rust source and a `.bpk` file at build time. Candle: candle-onnx walks the graph at run time. Check the operator lists first.],
    [#label-text("Application") \ Tokenizer, image scaling, pooling, chat template, sampling: your code, in both.],
  )
  #v(1fr)
  #text(size: 23pt)[Loaded is not checked. Compare with a reference: TinyStories with llama2.c gives identical text, MiniLM with ONNX Runtime agrees within #minilm-bound.]
  #v(8pt)
]

#slide(id: "b-quant", title: [Quantization: a format and a kernel])[
  #set text(size: 21pt)
  #grid(
    columns: (1fr, 1fr),
    column-gutter: 36pt,
    [
      #label-text("Candle · GGUF Q8_0 · our SmolLM2")
      - 32 weights share one f16 scale: 34~bytes, 8.5~bits a weight.
      - #str(calc.round(q8-weights / 1000000, digits: 1)) million weights: #mbr(q8-bytes)~MB, not #str(calc.round(all-weights * 4 / 1000000000, digits: 2))~GB as f32.
      - On the CPU the activations are quantized to the same blocks and multiplied as 8-bit integers.
    ],
    [
      #label-text("Burn 0.22 · Burn Book")
      - Post-training quantization only, no quantization-aware training.
      - Per tensor or per block, 8, 4 or 2~bits, on some backends.
      - No integer operations yet: tensors are dequantized and computed in floating point.
    ],
  )
  #v(1fr)
  #text(size: 23pt)[A smaller file is not automatically faster: the kernel decides.]
  #v(8pt)
]

#slide(id: "b-timing", title: [Timing GPU code])[
  #set text(size: 21pt)
  - GPU work runs in the background: the call returns before the GPU is done.
  - Warm up: Burn’s GPU backends autotune by default, the first calls try several kernels and keep the fastest.
  - Wait before you stop the clock: `device.synchronize()?` in Candle, `device.sync()?` in Burn. Reading a result back waits too.
  - Burn’s `device.profile(...)` measures device time; fusion holds work back, so end the closure with a read.
  - Load once, time inference alone, repeat, take the median.
  #v(1fr)
  #note[All times in this talk are CPU times from a shared VM: none is a benchmark.]
]
