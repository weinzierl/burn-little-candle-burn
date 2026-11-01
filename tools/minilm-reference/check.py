"""Reference check for the MiniLM numbers on the slides.

Runs the official ONNX export of sentence-transformers/all-MiniLM-L6-v2
(same revision as the safetensors file Candle loads) with ONNX Runtime,
one sentence at a time and without padding, then applies the model card's
recipe: mean over the tokens, then scale to length 1. Compares with

  1. the full-precision vectors and scores printed by `minilm-precise`
     (stdin, JSON): the same code and batching as the `similar` program;
  2. the two-decimal scores in candle-batteries/out/similar-*.txt,
     which the slides show.

Usage, from this folder:
  cargo run --release -q | python3 check.py MODEL.onnx TOKENIZER.json ../../candle-batteries/out
"""

import json
import pathlib
import sys

import numpy as np
import onnxruntime as ort
import tokenizers

TOLERANCE = 1e-5
CAPTURES = ["similar-eat", "similar-rain", "similar-old", "similar-router"]

onnx_path, tokenizer_path, out_dir = sys.argv[1:4]
runs = json.load(sys.stdin)

session = ort.InferenceSession(onnx_path, providers=["CPUExecutionProvider"])
tokenizer = tokenizers.Tokenizer.from_file(tokenizer_path)
tokenizer.no_padding()  # one sentence per call: nothing to pad


def reference(text):
    enc = tokenizer.encode(text)
    ids = np.array([enc.ids], dtype=np.int64)
    mask = np.array([enc.attention_mask], dtype=np.int64)
    feed = {"input_ids": ids, "attention_mask": mask, "token_type_ids": np.zeros_like(ids)}
    hidden = session.run(["last_hidden_state"], feed)[0][0]  # [tokens, 384]
    mean = hidden.mean(axis=0)
    return mean / np.linalg.norm(mean)


print(f"ONNX Runtime {ort.__version__}, tokenizers {tokenizers.__version__}, numpy {np.__version__}")
print(f"reference model: {pathlib.Path(onnx_path).name}, one sentence per call, no padding")

max_vec = max_score = 0.0
slide_values = slide_mismatch = 0
for run, capture in zip(runs, CAPTURES, strict=True):
    texts = run["texts"]
    candle = np.array(run["vectors"], dtype=np.float64)
    ref = np.array([reference(t) for t in texts], dtype=np.float64)
    max_vec = max(max_vec, float(np.abs(candle - ref).max()))
    ref_scores = ref[1:] @ ref[0]
    max_score = max(max_score, float(np.abs(np.array(run["scores"]) - ref_scores).max()))

    # The slide: "0.36  Tortellini are served till late." per line.
    shown = {}
    for line in (pathlib.Path(out_dir) / f"{capture}.txt").read_text().splitlines():
        score, doc = line.split("  ", 1)
        shown[doc] = score
    for doc, rs, cs in zip(texts[1:], ref_scores, run["scores"]):
        slide_values += 1
        if shown[doc] != f"{rs:.2f}" or shown[doc] != f"{cs:.2f}":
            slide_mismatch += 1
            print(f"  {capture}: {doc!r} slide {shown[doc]}, reference {rs:.4f}, candle {cs:.4f}")
    print(f"{capture:15} {texts[0]!r}: top {texts[1 + int(np.argmax(ref_scores))]!r}")

print(f"largest difference in a vector coordinate: {max_vec:.2e}")
print(f"largest difference in a score:             {max_score:.2e}")
print(f"slide values checked: {slide_values}, different from the reference: {slide_mismatch}")
ok = max_vec < TOLERANCE and max_score < TOLERANCE and slide_mismatch == 0
print(f"tolerance {TOLERANCE:g}: {'PASS' if ok else 'FAIL'}")
sys.exit(0 if ok else 1)
