#!/usr/bin/env bash
# All implementations must write exactly the same text.
cd "$(dirname "$0")"
ref=$(head -n 12 out/candle-generate.txt)
ok=1
check() {
  if [ -f "$1" ]; then
    got=$(grep -v -e '^loaded, heap' -e '^heap peak' "$1" | head -n 12)
    if [ "$got" = "$ref" ]; then echo "   same text: $1"; else echo "   DIFFERENT: $1"; ok=0; fi
  else
    echo "   missing:   $1"
  fi
}
for f in out/burn-generate.txt out/tiny-generate.txt out/candle-wasm.txt \
         out/burn-wasm.txt out/qemu-m33.txt out/burn-m33.txt; do
  check "$f"
done
if [ -f out/burn-train-lm.txt ]; then
  got=$(sed -n '/--- sample after training ---/,/^---$/p' out/burn-train-lm.txt | sed '1d;$d')
  if [ "$got" = "$ref" ]; then echo "   same text: out/burn-train-lm.txt"; else echo "   DIFFERENT: out/burn-train-lm.txt"; ok=0; fi
fi
[ $ok = 1 ] && echo "   all identical" || { echo "   MISMATCH"; exit 1; }
