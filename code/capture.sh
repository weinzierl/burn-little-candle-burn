#!/usr/bin/env bash
# Re-run every example and capture its output into out/.
# The slides read these files, so slides and runs cannot drift apart.
# Usage (from code/):  ./capture.sh          everything except training
#                      ./capture.sh train    also retrain the LM (~3 min)
set -u
cd "$(dirname "$0")"
export -n RUST_BACKTRACE 2>/dev/null || true
unset RUST_BACKTRACE
mkdir -p out data
R=target/release

echo "== build (release)"
cargo build --release --quiet || exit 1

run() { # name, command...   ($HOME is shown as ~ in captured paths)
  local name=$1; shift
  local rc=0
  "$@" > "out/$name.txt" 2>&1 || rc=$?
  sed -i.bak "s#$HOME#~#g" "out/$name.txt" && rm -f "out/$name.txt.bak"
  echo "   $name: exit $rc"
}

echo "== tensors and errors"
run candle-hello $R/candle_hello
run burn-hello $R/burn_hello
run candle-errors $R/candle_errors
run burn-errors $R/burn_errors
cargo build --release --bin burn_rank_error --features show-compile-error 2>&1 \
  | grep -v '^ *Compiling' | sed "s#$HOME#~#g" > out/burn-rank-error.txt
echo "   burn-rank-error: captured (expected to fail)"

echo "== sine"
run candle-sine $R/candle_sine
run burn-sine $R/burn_sine

if [ "${1:-}" = "train" ]; then
  echo "== training the character LM with Burn (about 3 minutes)"
  run burn-train-lm $R/burn_train_lm 20000
fi

echo "== generate"
run candle-generate $R/candle_generate
run burn-generate $R/burn_generate
run tiny-generate $R/tiny_generate

echo "== wasm32-wasip1 (needs: rustup target add wasm32-wasip1; node >= 22)"
if cargo build --release --quiet --target wasm32-wasip1 \
     --bin candle_generate --bin burn_generate 2>/dev/null; then
  W=target/wasm32-wasip1/release
  node --no-warnings wasi-run.mjs $W/candle_generate.wasm > out/candle-wasm.txt 2>&1
  node --no-warnings wasi-run.mjs $W/burn_generate.wasm > out/burn-wasm.txt 2>&1
  wc -c < $W/candle_generate.wasm | tr -d ' ' > out/wasm-sizes.txt
  wc -c < $W/burn_generate.wasm | tr -d ' ' >> out/wasm-sizes.txt
  echo "   wasm: done"
else
  echo "   wasm: SKIPPED (target or toolchain missing)"
fi

echo "== Cortex-M33 (needs: rustup target add thumbv8m.main-none-eabihf; qemu-system-arm)"
if (cd firmware && cargo build --release --quiet 2>/dev/null); then
  F=firmware/target/thumbv8m.main-none-eabihf/release
  SIZE=$(ls "$(rustc --print sysroot)"/lib/rustlib/*/bin/llvm-size 2>/dev/null | head -1)
  if [ -n "$SIZE" ]; then
    "$SIZE" -A $F/qemu-m33 | sed -n '3,9p' > out/qemu-m33-size.txt
    "$SIZE" -A $F/burn-m33 | sed -n '3,9p' > out/burn-m33-size.txt
    if (cd firmware/pico2 && cargo build --release --quiet 2>/dev/null); then
      "$SIZE" -A firmware/pico2/target/thumbv8m.main-none-eabihf/release/pico2 | sed -n '3,12p' > out/pico2-size.txt
    fi
  fi
  if command -v qemu-system-arm >/dev/null; then
    Q="qemu-system-arm -machine mps2-an505 -cpu cortex-m33 -nographic -semihosting-config enable=on,target=native -kernel"
    $Q $F/qemu-m33 > out/qemu-m33.txt 2>&1
    $Q $F/burn-m33 > out/burn-m33.txt 2>&1
    echo "   qemu: done"
  else
    echo "   qemu: SKIPPED (qemu-system-arm not installed)"
  fi
else
  echo "   firmware: SKIPPED (build failed; is the thumbv8m.main-none-eabihf target installed?)"
fi

echo "== candle on bare metal (expected to fail)"
if (cd candle-nostd-check && cargo build --release --target thumbv8m.main-none-eabihf > build.log 2>&1); then
  echo "   unexpected: candle-core built for thumbv8m"
else
  grep -m1 -A1 '^error\[E0463\]' candle-nostd-check/build.log \
    | sed 's#/[^ ]*/registry/src/[^/]*/#~/.cargo/registry/src/…/#' > out/candle-nostd-build.txt
  grep -m1 'may not support the standard library' candle-nostd-check/build.log >> out/candle-nostd-build.txt
  echo "   candle-nostd-build: captured (failed as expected)"
fi

echo "== compare generated text"
./compare.sh
