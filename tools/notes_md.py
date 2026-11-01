#!/usr/bin/env python3
"""Generate speaker-notes.md from notes/notes.yaml (needs PyYAML)."""
import sys
import yaml

notes = yaml.safe_load(open("notes/notes.yaml", encoding="utf-8"))


def mmss(s):
    return f"{s // 60}:{s % 60:02d}"


# Backup slides come after the end, for questions only: not in the plan.
talk = [n for n in notes if not n.get("backup")]
total = sum(n["time"] for n in talk)
skippable = sum(n["time"] for n in talk if n.get("skip"))
backups = len(notes) - len(talk)
out = []
out.append("# Speaker notes: Burn, little candle, burn!\n")
out.append("RustLab 2026, Bologna. 2 November 2026, 11:30, 45 minute slot.\n")
out.append(
    f"Planned: {mmss(total)} over {len(talk)} slides. "
    f"Skippable: {mmss(skippable)} (marked SKIP). "
    f"Backup slides after the end, for questions only: {backups} (marked BACKUP).\n"
)
out.append("## Running order\n")
out.append("| # | Slide | Time | At | |")
out.append("|---:|---|---:|---:|---|")
acc = 0
for i, n in enumerate(notes, 1):
    if n.get("backup"):
        out.append(f"| {i} | {n['title']} | | | BACKUP |")
        continue
    acc += n["time"]
    skip = "SKIP" if n.get("skip") else ""
    out.append(f"| {i} | {n['title']} | {mmss(n['time'])} | {mmss(acc)} | {skip} |")
out.append("")
acc = 0
for i, n in enumerate(notes, 1):
    out.append(f"## {i}. {n['title']}\n")
    if n.get("backup"):
        out.append("*BACKUP · for questions*\n")
    else:
        acc += n["time"]
        skip = " · SKIP" if n.get("skip") else ""
        out.append(f"*{mmss(n['time'])} · at {mmss(acc)}{skip}*\n")
    out.append("**Cues**\n")
    for c in n["cue"]:
        out.append(f"- {c}")
    out.append("\n**Notes**\n")
    out.append(n["notes"].strip() + "\n")
    for qa in n.get("qa", []):
        out.append(f"> **Q:** {qa['q']}  ")
        out.append(f"> **A:** {qa['a']}\n")
text = "\n".join(out).rstrip() + "\n"
for bad in ("–", "—"):
    if bad in text:
        sys.exit("dash character found in notes")
open("speaker-notes.md", "w", encoding="utf-8").write(text)
print(f"speaker-notes.md: {len(talk)} slides + {backups} backup, {mmss(total)} planned")
