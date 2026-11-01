#!/usr/bin/env python3
"""Count the weights per storage type in a GGUF file, from its header only.

Usage: python3 tools/gguf_stats.py FILE.gguf
Q8_0 stores 32 weights in 34 bytes: 32 signed bytes and one f16 scale.
"""
import os
import struct
import sys
from collections import Counter

TYPE_NAMES = {0: "F32", 1: "F16", 8: "Q8_0"}
BYTES = {"F32": lambda n: 4 * n, "F16": lambda n: 2 * n, "Q8_0": lambda n: n // 32 * 34}
SCALAR = {0: "<B", 1: "<b", 2: "<H", 3: "<h", 4: "<I", 5: "<i", 6: "<f", 7: "<?", 10: "<Q", 11: "<q", 12: "<d"}

path = sys.argv[1]
f = open(path, "rb")


def read(fmt):
    return struct.unpack(fmt, f.read(struct.calcsize(fmt)))[0]


def string():
    return f.read(read("<Q")).decode("utf-8", "replace")


def value(kind):
    if kind == 8:
        return string()
    if kind == 9:  # array: element type, count, elements
        elem, count = read("<I"), read("<Q")
        return [value(elem) for _ in range(count)]
    return read(SCALAR[kind])


assert f.read(4) == b"GGUF", "not a GGUF file"
version, n_tensors, n_meta = read("<I"), read("<Q"), read("<Q")
for _ in range(n_meta):
    string()
    value(read("<I"))
tensors, weights = Counter(), Counter()
for _ in range(n_tensors):
    string()
    dims = [read("<Q") for _ in range(read("<I"))]
    kind = read("<I")
    read("<Q")  # offset
    n = 1
    for d in dims:
        n *= d
    name = TYPE_NAMES.get(kind, f"type {kind}")
    tensors[name] += 1
    weights[name] += n

print(f"file {os.path.basename(path)}: {os.path.getsize(path)} bytes, GGUF version {version}, {n_tensors} tensors")
for name in sorted(weights, key=lambda k: -weights[k]):
    size = f", {BYTES[name](weights[name])} bytes" if name in BYTES else ""
    print(f"{name}: {tensors[name]} tensors, {weights[name]} weights{size}")
print(f"total: {sum(weights.values())} weights")
