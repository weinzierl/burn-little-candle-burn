# Q&A: five questions

Five questions for the 8:00 Q&A, picked from questions.md for variety, in a plausible order: the board just went round, so the first hand goes up about it, and the uncomfortable question comes last. Each takes about 95 s in the rehearsal: the question (about 15 s), 20 s for your own answer, then the model answer (about 60 s).

One question is new: the list misses the most obvious question once the board goes round, "What is that board, and can I do this at home?" It takes the beginner slot instead of question 17, "Where do I start?" (its answer, the repository, is folded into the new one). The other four come from the list: 26 (expert nitpick), 4 (why not just use X), 5 (practical adoption) and 40 (slightly hostile).

The answers follow the rule from questions.md: verdict first, then one fact, then the limit. Every number is from the numbers table or VERIFICATION.md.

| # | Type | Persona | From the list | Question | Answer | Back to |
|---:|---|---|---|---:|---:|---|
| 1 | Confused beginner (new) | Maker, first RustLab | new, replaces 17 "Where do I start?" | 16 s | 63 s | slide 40 |
| 2 | Expert nitpick | Numerics engineer | 26 "Isn't the agreement trivial? Both use the same gemm crate." | 16 s | 56 s | slide 31 |
| 3 | Why not just use X | Backend dev, ships ort | 4 "Why not just use ort (ONNX Runtime), tract, or tch-rs?" | 15 s | 62 s | slide 44 |
| 4 | Practical adoption | Engineering lead | 5 "Is this production-ready? Burn just broke its whole API." | 13 s | 63 s | slide 9 |
| 5 | Slightly hostile, off-topic | Sceptical senior dev | 40 "Did you use AI to write this?" | 16 s | 60 s | slide 2 |

With the 20 s answer pause per question: 7:59 of the 8:00 Q&A.

## Q1 · Confused beginner (new)

**Persona:** A maker and Rust hobbyist at her first RustLab. She has used Arduino boards, never a Pico, and the board just reached her row. She isn't sure what was emulated and what was real. Friendly, a bit shy, speaks quickly.

**From the list:** new, replaces 17 "Where do I start?"

**Question** (36 words, est. 16 s):

> Hi, sorry, beginner question. The little board that went round: is that a Pico? And could I put the story generator on my own board at home, or do I need a special debugger for that?

**Model answer** (141 words, est. 63 s):

Not quite a Pico, and no debugger needed. It's a Waveshare board with a 3.5 inch screen and an RP2350: the chip of the Pico 2, in a package with more pins, with the same 520 KiB of RAM.

To flash it, you build a UF2 file: two commands, and they're in the burn-nostd README. Then you hold the BOOT button, press reset, and the board shows up as a USB drive. Copy the file, and it restarts and writes stories.

On a plain Pico 2, the USB version should work too: it uses no pins and prints the stories to a serial terminal. But I've only run it on this one board. The exact board name is in the README too.

**Jump back to:** slide 40, The same model on a real chip.

## Q2 · Expert nitpick

**Persona:** A numerical computing engineer who maintains a linear algebra crate and has read the gemm source. Arms crossed, precise, not unfriendly. Wants to know whether the agreement means anything.

**From the list:** 26 "Isn't the agreement trivial? Both use the same gemm crate."

**Question** (36 words, est. 16 s):

> You showed Candle and Burn agreeing to six decimals. But on the CPU, aren't both of them calling the same gemm crate for the matrix products? Then the agreement is almost trivial, isn't it?

**Model answer** (127 words, est. 56 s):

Partly fair, and thanks for looking that closely. Yes: on the CPU both end up in gemm for the matrix products, so the multiplication itself isn't tested independently.

But that's the part I trust most. The agreement checks everything around it. Both load the same start file, and Burn only gets that right with the adapter that transposes the linear layers. The forward pass. Autodiff, so the gradients. Adam, with the same epsilon and weight decay, which differ by default. And the loss. A bug in any of those shows within a few hundred steps.

And where I wanted a truly independent reference, I used one: MiniLM against ONNX Runtime, and TinyStories against Karpathy's plain C program. Both agree.

**Jump back to:** slide 31, Same start, same data, same curve.

## Q3 · Why not just use X

**Persona:** A backend developer at a fintech who runs an ONNX model in production with ort. Pragmatic, slightly impatient, happy with what works and suspicious of switching for its own sake.

**From the list:** 4 "Why not just use ort (ONNX Runtime), tract, or tch-rs?"

**Question** (34 words, est. 15 s):

> We already run our models in production with ort, the ONNX Runtime bindings. It's fast, and it works. Why would I switch to Candle or Burn? Or to tract, for that matter?

**Model answer** (139 words, est. 62 s):

If ort works for you, keep it. It's a good choice, with a different trade-off. ort wraps Microsoft's ONNX Runtime: mature kernels and lots of hardware support, but a large native C++ dependency underneath, and the crate's 2.0 is still a release candidate. tract is a self-contained Rust engine for ONNX models.

Candle and Burn are for when the model should be Rust code that you can change, train, and take places: to WebAssembly, or, with Burn, to a microcontroller without the standard library.

So: a fixed ONNX model in a service, ort is the pragmatic choice. Training, changing the model, or tiny targets: that's where Candle and Burn come in. And I didn't benchmark them against each other, so I won't tell you which is faster.

**Jump back to:** slide 44, Which one?.

## Q4 · Practical adoption

**Persona:** An engineering lead at a mid-size company who has been burned by breaking changes before and has to decide whether a team may adopt Burn. Calm, serious, wants a straight answer.

**From the list:** 5 "Is this production-ready? Burn just broke its whole API."

**Question** (30 words, est. 13 s):

> Is any of this production-ready? You just showed us that Burn changed its whole API last month. How am I supposed to build a product on that?

**Model answer** (141 words, est. 63 s):

Fair question. Both are below 1.0, and both move fast. Candle 0.11.1 came out on the 31st of October. Burn 0.22 came out on the 6th of October, then 0.22.1 on the 20th, and there's already a 0.23 pre-release. Burn's README says plainly that there will be breaking changes.

On the other side, Candle already runs underneath real projects: Hugging Face's own text-embeddings-inference server has a Candle backend, and mistral.rs is built on Candle. For Burn, I can't name production users, so I won't guess.

My advice: pin exact versions, read the migration guides, and budget time for upgrades. And keep the model code in one corner of your program, so an upgrade touches few files.

**Jump back to:** slide 9, Burn 0.22 moved the backend.

## Q5 · Slightly hostile, off-topic

**Persona:** A senior developer, sceptical of AI hype, asks with a smile but means it. Slightly provocative, speaks loudly so the room hears it.

**From the list:** 40 "Did you use AI to write this?"

**Question** (35 words, est. 16 s):

> Honest question, since this is a talk about ML: did you use AI to write this talk and the code? And if so, how do we know any of it is actually correct?

**Model answer** (134 words, est. 60 s):

Yes, I did, and I'd rather say it than have you guess. An AI assistant wrote a good part of the example code, the slides and my notes, together with me.

So why should you trust it? Not because of me, and not because of the AI. Because nothing on the slides is typed: every output is captured from a real run, and the slides read their numbers from those files. And because, where possible, results are checked against something independent: MiniLM against ONNX Runtime, TinyStories against Karpathy's C program, Candle against Burn, and the board against QEMU.

The repository has a file, VERIFICATION, that says what ran where, and what did not. If you find a mistake, please open an issue. That's what it's for.

**Jump back to:** slide 2, Two ends of one scale (captured output).

*Note:* Put this one in your own words: it is your account of how you worked. The facts in it are the ones from questions.md and VERIFICATION.md.
