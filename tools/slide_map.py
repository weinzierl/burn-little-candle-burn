#!/usr/bin/env python3
"""Write MAP.md: for every slide, the files of this repository it shows or reads.

    python3 tools/slide_map.py      (from the repository root)

The deck reads code and captured output at build time (`cut`, `cut-n`, `read`,
`grab`, `image` with a path), so this list comes from slides/presentation.typ
itself; page numbers and titles come from notes/notes.yaml, which `just check-notes`
keeps in step with the deck.
"""
import re
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
typ = (ROOT / "slides" / "presentation.typ").read_text(encoding="utf-8")
notes = yaml.safe_load((ROOT / "notes" / "notes.yaml").read_text(encoding="utf-8"))
VARS = dict(re.findall(r'^#let ([a-z0-9-]+) = "(/[^"]*)"', typ, re.M))

# Each slide's block: from its id to the next slide's id.
starts = [(m.start(), m.group(1)) for m in re.finditer(r'#(?:title-slide|section-slide|slide)\((?:\s*)id: "([^"]+)"', typ)]
blocks = {sid: typ[a:(starts[i + 1][0] if i + 1 < len(starts) else len(typ))] for i, (a, sid) in enumerate(starts)}
# The value lines at the top of the file (#let x = int(grab(bno + "/..."))) feed numbers into slides.
lets = {}
for m in re.finditer(r'^#let ([a-z0-9-]+) = .*?\b([a-z]+)\s*\+\s*"(/[^"]+)"', typ, re.M):
    if m.group(2) in VARS:
        lets[m.group(1)] = VARS[m.group(2)] + m.group(3)

# A path is a known folder variable plus a string ("src + \"/candle-demo/...\""), whatever
# helper takes it (cut, snippet, out-lines, scores, read, ...), or an image next to the deck.
JOINED = re.compile(r'\b([a-z]+)\s*\+\s*"(/[^"]+)"')
IMAGE = re.compile(r'image\(\s*"([^"]+)"')


def files(block):
    found = []
    for var, path in JOINED.findall(block):
        if var in VARS:
            found.append((VARS[var] + path).lstrip("/"))
    for path in IMAGE.findall(block):
        found.append(path.lstrip("/") if path.startswith("/") else "slides/" + path)
    for name, p in lets.items():
        if re.search(r"#" + re.escape(name) + r"\b", block):
            found.append(p.lstrip("/"))
    out = []
    for f in found:
        if f not in out:
            out.append(f)
    return out


rows = ["# Which slide shows which code", "",
        "Made by `tools/slide_map.py` from `slides/presentation.typ`: the slides read code and captured output",
        "from these files when the deck is built, so what a slide shows is what the file holds.",
        "Slides without files are text, tables or diagrams. Numbers in the text (sizes, rates, parameter counts)",
        "are read from the same `out/` files at the top of `slides/presentation.typ`. Output files were captured",
        "from real runs; VERIFICATION.md says where each ran.", "",
        "| Slide | Title | Files |", "|---:|---|---|"]
code_slides = 0
for n, note in enumerate(notes, 1):
    sid = note["id"]
    fs = files(blocks.get(sid, ""))
    if fs:
        code_slides += 1
    title = str(note["title"]).replace("|", "\\|")
    cell = "<br>".join(f"`{f}`" for f in fs) if fs else ""
    rows.append(f"| {n} | {title} | {cell} |")
rows += ["", f"{code_slides} of {len(notes)} slides show or read files of this repository.", ""]
(ROOT / "MAP.md").write_text("\n".join(rows), encoding="utf-8")
print(f"MAP.md: {len(notes)} slides, {code_slides} with files")
