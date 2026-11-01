#!/usr/bin/env python3
"""Check that notes/notes.yaml lists exactly the slide ids of the deck, in order.
Reads the ids from `typst query` JSON on stdin."""
import json
import sys
import yaml

deck = json.load(sys.stdin)
notes = [n["id"] for n in yaml.safe_load(open("notes/notes.yaml", encoding="utf-8"))]
if deck == notes:
    print(f"notes match the deck: {len(deck)} slides")
else:
    for i, (a, b) in enumerate(zip(deck, notes), 1):
        if a != b:
            print(f"first mismatch at slide {i}: deck {a!r}, notes {b!r}")
            break
    print(f"deck {len(deck)} slides, notes {len(notes)} entries")
    sys.exit(1)
