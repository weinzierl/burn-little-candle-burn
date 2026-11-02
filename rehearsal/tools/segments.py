"""The rehearsal as an ordered list of segments, shared by the TTS, the video and the ElevenLabs package.

A slide whose text has a [demo N s] marker in the middle becomes two audio segments
around a silent one (42_slide42, 42_slide42_demo, 42_slide42b); a marker at the end
becomes silence after the audio (tail_silence). Every audio segment's text is free
of markers, so an ElevenLabs file can replace a Kokoro file 1:1.
"""
from pathlib import Path

import yaml

import speech

ROOT = Path(__file__).resolve().parent.parent
QA_BUDGET = 96  # 8:00 for five questions


def _parts(text):
    """[('text', str) | ('silence', seconds)] in order."""
    out, buf = [], []
    for para in [p.strip() for p in text.strip().split("\n") if p.strip()]:
        m = speech.MARKER.fullmatch(para)
        if m:
            if buf:
                out.append(("text", "\n".join(buf)))
                buf = []
            out.append(("silence", float(m.group(2))))
        else:
            buf.append(para)
    if buf:
        out.append(("text", "\n".join(buf)))
    return out


def build():
    talk = yaml.safe_load(open(ROOT / "src" / "talk.yaml", encoding="utf-8"))
    qa = yaml.safe_load(open(ROOT / "src" / "qa.yaml", encoding="utf-8"))
    segs = []
    for s in talk:
        if s.get("role") == "moderator":
            segs.append({"id": s["id"], "role": "moderator", "group": "moderator", "label": "Intro",
                         "target": s["target"], "image": "assets/slides/slide-01.png", "chapter": "Moderator",
                         "text": s["text"].strip()})
            continue
        base = {"role": "narrator", "group": s["id"], "label": f"Slide {s['slide']}", "target": s["target"],
                "image": f"assets/slides/slide-{s['slide']:02d}.png"}
        parts = _parts(s["text"])
        out, suffix = [], ""
        for kind, val in parts:
            if kind == "text":
                out.append(dict(base, id=s["id"] + suffix, text=val))
                suffix = "b" if not suffix else chr(ord(suffix) + 1)
            elif out and kind == "silence" and (kind, val) == parts[-1]:
                out[-1]["tail_silence"] = val
            else:
                out.append(dict(base, id=s["id"] + "_demo", role="pause", silence=val))
        out[0]["chapter"] = f"Slide {s['slide']} · {s['title']}"
        if s.get("skip"):
            out[0]["skip"] = True
        segs += out
    for i, q in enumerate(qa["questions"], 1):
        g = f"qa{i}"
        segs.append({"id": f"qa{i}_question", "role": f"q{i}", "group": g, "label": f"Q{i}", "target": QA_BUDGET,
                     "image": f"assets/cards/qa{i}_question.png",
                     "chapter": f"Q{i} · {q['type']}: {q['persona_short']}", "text": q["question"].strip(),
                     "burn": False})
        segs.append({"id": f"qa{i}_pause", "role": "pause", "group": g, "label": f"Q{i}", "target": QA_BUDGET,
                     "image": f"assets/cards/qa{i}_pause.png", "silence": 20, "countdown": 20})
        segs.append({"id": f"qa{i}_answer", "role": "narrator", "group": g, "label": f"Q{i}", "target": QA_BUDGET,
                     "image": f"assets/slides/slide-{q['slide']:02d}.png", "text": q["answer"].strip(),
                     "jump_back": f"slide {q['slide']}, {q['slide_title']}"})
    return segs
