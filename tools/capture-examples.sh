#!/usr/bin/env bash
# Runs the two example repositories and writes the output the slides show:
#   burn-nostd/out/*.txt        desktop programs (no_std) and QEMU runs
#   candle-batteries/out/*.txt  the four Candle programs (models from the Hugging Face Hub)
# Run from the repository root. Needs Rust (burn-nostd pins 1.95 itself),
# qemu-system-arm for the QEMU runs, network access to the Hub on the first Candle run,
# and Python 3 for the GGUF statistics.
set -uo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)

# Time a command, keep stdout and stderr apart, and log the exit code.
run() {
  local out=$1 name=$2; shift 2
  local t0 t1 rc
  t0=$(date +%s%N)
  "$@" > "$out/$name.txt" 2> "$out/$name.err"
  rc=$?
  t1=$(date +%s%N)
  [ -s "$out/$name.err" ] || rm -f "$out/$name.err"
  printf '%-22s exit %d  %6.2f s\n' "$name" "$rc" "$(echo "($t1 - $t0) / 1000000000" | bc -l)" | tee -a "$out/runs.log"
}

# ---- burn-nostd: desktop programs, without std ----
bn="$root/burn-nostd"
out="$bn/out"; mkdir -p "$out"; : > "$out/runs.log"
cd "$bn"
cargo build --release --locked -q || exit 1
run "$out" sine        cargo -q sine
run "$out" gesture     cargo -q gesture
run "$out" keywords    cargo -q keywords
run "$out" tinystories cargo -q tinystories -- "Once upon a time" 0 80

# ---- burn-nostd: the firmware code paths on an emulated Cortex-M33 ----
if command -v qemu-system-arm > /dev/null; then
  cd "$bn/qemu"
  for b in sine gesture keywords tinystories; do
    run "$out" "qemu-$b" cargo run --release --locked -q --bin "$b"
  done
fi

# Last, because rewriting the weights file (even with the same bytes) makes cargo rebuild the firmware.
cd "$bn"
out="$bn/out"
# sine-train must reproduce the committed weights byte for byte.
before=$(sha256sum 1-sine/weights/sine.bpk | cut -d' ' -f1)
run "$out" sine-train  cargo -q sine-train
after=$(sha256sum 1-sine/weights/sine.bpk | cut -d' ' -f1)
echo "sine.bpk before $before after $after" >> "$out/sine-train.txt"

# ---- candle-batteries: weights from the Hub (cached after the first run) ----
cb="$root/candle-batteries"
out="$cb/out"; mkdir -p "$out"; : > "$out/runs.log"
cd "$cb"
unset RUST_BACKTRACE
cargo build --release --locked -q || exit 1
run "$out" tensors         ./target/release/tensors
run "$out" classify-cat    ./target/release/classify 2-classify/images/cat.jpg
run "$out" classify-coffee ./target/release/classify 2-classify/images/coffee.jpg
run "$out" similar-eat     ./target/release/similar "Where can I eat tonight?"
run "$out" similar-rain    ./target/release/similar "It is raining."
run "$out" similar-old     ./target/release/similar "How old is the city?"
run "$out" similar-router  ./target/release/similar "How do I reset my router?"
run "$out" ask             ./target/release/ask

# The model files the Candle programs read, as cached by hf-hub: repository, file, bytes, SHA-256.
hub="${HF_HOME:-$HOME/.cache/huggingface}/hub"
{
  for f in "$hub"/models--*/snapshots/*/*; do
    repo=$(echo "$f" | sed -E 's#.*/models--([^/]*)/snapshots/.*#\1#; s#--#/#')
    printf '%s %s %s %s\n' "$repo" "$(basename "$f")" "$(stat -L -c %s "$f")" "$(sha256sum "$(readlink -f "$f")" | cut -d' ' -f1)"
  done
} > "$out/models.txt"

# Weights per storage type in the SmolLM2 GGUF file (backup slide on quantization).
python3 "$root/tools/gguf_stats.py" "$hub"/models--HuggingFaceTB--SmolLM2-360M-Instruct-GGUF/snapshots/*/smollm2-360m-instruct-q8_0.gguf > "$out/gguf-stats.txt"
