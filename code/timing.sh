#!/usr/bin/env bash
# Run the sine training five times per framework; record time per step.
cd "$(dirname "$0")"
unset RUST_BACKTRACE
: > out/sine-timing.txt
for i in 1 2 3 4 5; do
  echo "candle $(target/release/candle_sine | grep '2000 steps')" >> out/sine-timing.txt
  echo "burn $(target/release/burn_sine | grep '2000 steps')" >> out/sine-timing.txt
done
cat out/sine-timing.txt
