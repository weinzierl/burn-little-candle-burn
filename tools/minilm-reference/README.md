# MiniLM reference check

Checks the MiniLM numbers on the slides (the `similar` program in `candle-batteries/`) against a second implementation: the official ONNX export of `sentence-transformers/all-MiniLM-L6-v2` at the same revision (`1110a243fdf4706b3f48f1d95db1a4f5529b4d41`), run with ONNX Runtime one sentence at a time, then the model card's recipe (mean over the tokens, scaled to length 1).

- `src/main.rs` (`minilm-precise`): prints the vectors and scores that `similar` computes, as JSON, at full precision. Its `embed` function is copied unchanged from `candle-batteries/3-similar/src/main.rs`; same model files from the Hub cache, same batching and padding.
- `check.py`: computes the reference vectors and compares; also compares the two-decimal scores in `candle-batteries/out/similar-*.txt`, which the slides show.
- `result.txt`: the result of the run on 2026-10-31.

Python is only a verification tool here; nothing in the talk needs it.

```
pip install onnxruntime tokenizers numpy
curl -L -o model.onnx https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2/resolve/1110a243fdf4706b3f48f1d95db1a4f5529b4d41/onnx/model.onnx
echo "6fd5d72fe4589f189f8ebc006442dbb529bb7ce38f8082112682524616046452  model.onnx" | sha256sum -c -    # macOS: shasum -a 256 -c -
cargo run --release -q | python3 check.py model.onnx \
  ~/.cache/huggingface/hub/models--sentence-transformers--all-MiniLM-L6-v2/snapshots/1110a243fdf4706b3f48f1d95db1a4f5529b4d41/tokenizer.json \
  ../../candle-batteries/out
```

The tokenizer file is in the Hub cache after `similar` has run once.
