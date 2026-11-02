#!/usr/bin/env python3
"""Step 1: script.md, qa.md and pronunciation.md from src/*.yaml, with checks.

Durations are estimated from the words a TTS voice will actually speak (numbers
and abbreviations expanded as in pronunciation.md) at 135 words per minute, plus
marked pauses.
"""
import re
import sys
from pathlib import Path

import yaml

sys.path.insert(0, str(Path(__file__).resolve().parent))
import speech  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT  # script.md, qa.md, pronunciation.md next to src/
WPM = 135
TALK_TARGET = 35 * 60


def est(text):
    return speech.spoken_words(text) * 60 / WPM + speech.pauses(text)


def mmss(s):
    s = int(round(s))
    return f"{s // 60}:{s % 60:02d}"


def load():
    talk = yaml.safe_load(open(ROOT / "src" / "talk.yaml", encoding="utf-8"))
    qa_path = ROOT / "src" / "qa.yaml"
    qa = yaml.safe_load(open(qa_path, encoding="utf-8")) if qa_path.exists() else None
    return talk, qa


def flags_for(seg, e):
    t = seg["target"]
    out = []
    if e > t * 1.10:
        out.append(f"over by {e - t:.0f} s")
    elif e < t * 0.80 and seg.get("slide"):
        out.append(f"short by {t - e:.0f} s")
    if seg.get("flag"):
        out.append(seg["flag"])
    return "; ".join(out)


def script_md(talk):
    mod = [s for s in talk if s.get("role") == "moderator"][0]
    slides = [s for s in talk if s.get("slide")]
    lines = []
    total_t = sum(s["target"] for s in slides)
    total_e = sum(est(s["text"]) for s in slides)
    words = sum(speech.spoken_words(s["text"]) for s in slides)
    skip_t = sum(s["target"] for s in slides if s.get("skip"))
    skip_e = sum(est(s["text"]) for s in slides if s.get("skip"))
    lines += [
        "# Burn, little candle, burn! Spoken script",
        "",
        "Virtual rehearsal of the RustLab 2026 talk, step 1. Text only.",
        "",
        "Session plan, 45:00 in total: moderator 0:20, talk 35:00, Q&A 8:00 (5 questions, see qa.md), "
        "reserve 1:40. The talk clock below starts at 0:00 with slide 1; on the session clock add 0:20.",
        "",
        f"- Target: the deck's planned time per slide (notes.yaml, 40:00 in all) scaled to 35:00. Sum of targets: {mmss(total_t)}.",
        f"- Words: what the voice will say, with numbers and abbreviations spoken out as in pronunciation.md. Total: {words} words.",
        f"- Est.: words at {WPM} words per minute, plus marked pauses. Total: {mmss(total_e)}.",
        f"- Skippable slides (marked SKIP in the deck): {mmss(skip_e)} of speech ({mmss(skip_t)} of targets), your reserve if you run long.",
        "- Flags: estimate more than 10 % over or 20 % under the target, and slides whose content is hard to fit.",
        "- Markers: [pause N s] is silence, [demo N s] is time for the live demo; both count in Est.",
        "",
        "| Slide | Title | Target | Words | Est. | Starts at | Ends at | Flag |",
        "|---:|---|---:|---:|---:|---:|---:|---|",
    ]
    clock = 0.0
    for s in slides:
        e = est(s["text"])
        title = s["title"].replace("|", "\\|") + (" (SKIP)" if s.get("skip") else "")
        lines.append(f"| {s['slide']} | {title} | {s['target']} s | {speech.spoken_words(s['text'])} | "
                     f"{e:.0f} s | {mmss(clock)} | {mmss(clock + e)} | {flags_for(s, e)} |")
        clock += e
    lines += ["", f"Talk total: {mmss(clock)} (target 35:00, difference {round(clock - TALK_TARGET):+d} s).", ""]
    lines += ["## 00 · Moderator", "", f"Target {mod['target']} s · {speech.spoken_words(mod['text'])} words · "
              f"est. {est(mod['text']):.0f} s · session clock 0:00 to {mmss(est(mod['text']))}", ""]
    lines += [speech.subtitle_text(p) for p in mod["text"].strip().split("\n")] + [""]
    clock = 0.0
    for s in slides:
        e = est(s["text"])
        lines.append(f"## Slide {s['slide']} · {s['title']}" + (" (SKIP)" if s.get("skip") else ""))
        lines.append("")
        lines.append(f"Target {s['target']} s · {speech.spoken_words(s['text'])} words · est. {e:.0f} s · "
                     f"talk clock {mmss(clock)} to {mmss(clock + e)}" + (f" · **{flags_for(s, e)}**" if flags_for(s, e) else ""))
        lines.append("")
        for para in s["text"].strip().split("\n"):
            lines.append(para.strip())
            lines.append("")
        if s.get("note"):
            lines.append(f"> {s['note']}")
            lines.append("")
        clock += e
    return "\n".join(lines).rstrip() + "\n"


def qa_md(qa):
    lines = ["# Q&A: five questions", "", qa["intro"].strip(), ""]
    lines += ["| # | Type | Persona | From the list | Question | Answer | Back to |",
              "|---:|---|---|---|---:|---:|---|"]
    total = 0
    for i, q in enumerate(qa["questions"], 1):
        qe, ae = est(q["question"]), est(q["answer"])
        total += qe + 20 + ae
        lines.append(f"| {i} | {q['type']} | {q['persona_short']} | {q['source']} | {qe:.0f} s | {ae:.0f} s | slide {q['slide']} |")
    lines += ["", f"With the 20 s answer pause per question: {mmss(total)} of the 8:00 Q&A.", ""]
    for i, q in enumerate(qa["questions"], 1):
        qe, ae = est(q["question"]), est(q["answer"])
        lines += [f"## Q{i} · {q['type']}", "",
                  f"**Persona:** {q['persona'].strip()}", "",
                  f"**From the list:** {q['source']}", "",
                  f"**Question** ({speech.spoken_words(q['question'])} words, est. {qe:.0f} s):", "",
                  "> " + speech.subtitle_text(q["question"].strip()), "",
                  f"**Model answer** ({speech.spoken_words(q['answer'])} words, est. {ae:.0f} s):", ""]
        for para in q["answer"].strip().split("\n"):
            lines += [para.strip(), ""]
        lines += [f"**Jump back to:** slide {q['slide']}, {q['slide_title']}.", ""]
        if q.get("note"):
            lines += [f"*Note:* {q['note'].strip()}", ""]
    return "\n".join(lines).rstrip() + "\n"


def used_terms(texts):
    used = {}
    for e in speech.entries():
        n = sum(len(e["re"].findall(speech.MARKER.sub(" ", t))) for t in texts.values())
        if n:
            used[e["term"]] = sorted(k for k, t in texts.items() if e["re"].search(t))
    return used


def pronunciation_md(texts):
    data = yaml.safe_load(open(ROOT / "src" / "pron.yaml", encoding="utf-8"))
    used = used_terms(texts)
    names = {"people_places": "People and places", "products_projects": "Products, projects, crates",
             "code_identifiers": "Code identifiers", "acronyms_units": "Acronyms and units",
             "numbers_versions": "Numbers, versions, years"}
    lines = ["# Pronunciation", "",
             "For the TTS input only: the subtitles keep the script's spelling. \"Say\" is the intended "
             "pronunciation, \"TTS input\" is the respelling the voice gets. Matching is case-sensitive and on "
             "whole terms; longer terms win (\"ONNX Runtime\" before \"ONNX\").", ""]
    for key, title in names.items():
        rows = [e for e in data[key] if e["term"] in used]
        if not rows:
            continue
        lines += [f"## {title}", "", "| Term | Say | TTS input | Used in |", "|---|---|---|---|"]
        for e in rows:
            where = ", ".join(used[e["term"]][:4]) + (", ..." if len(used[e["term"]]) > 4 else "")
            say = e["say"] + (f" (Kokoro phonemes: /{e['ipa']}/)" if e.get("ipa") else "")
            lines.append(f"| `{e['term']}` | {say} | {e['tts']} | {where} |")
        lines.append("")
    lines += ["## Numbers in general", "",
              "- Numbers grouped with spaces are one number: \"2 564\" is \"two thousand five hundred sixty-four\", "
              "\"1 056 540\" is \"one million fifty-six thousand five hundred forty\".",
              "- Decimals digit by digit after the point: \"0.0075\" is \"zero point zero zero seven five\", \"4.3\" is "
              "\"four point three\", \"81.7 percent\" is \"eighty-one point seven percent\".",
              "- Versions are not decimals: \"0.22\" is \"zero point twenty-two\", not \"zero point two two\" (see the table).",
              "- Years as years: 2015 \"twenty fifteen\", 1088 \"ten eighty-eight\".",
              "- KiB is said \"kilobytes\" (the slides keep KiB). The script already writes megabytes, milliseconds, "
              "megahertz and kilohertz as words.",
              ""]
    lines += ["## Left to the voice, check on the first listen", "",
              "- \"Llama\" (LAH-ma), \"Candle\", \"Burn\", \"Flex\", \"Metal\", \"Vulkan\", \"Adam\", \"Learner\": plain English.",
              "- Single letters as variables: \"x\", \"w\", \"B\". If the voice reads \"x\" as \"times\", respell it \"ex\".",
              "- \"Result\" and \"Results\" are the Rust type; ordinary English pronunciation is right.",
              ""]
    return "\n".join(lines).rstrip() + "\n"


RISKY = re.compile(r"\b(?:[A-Z]{2,}\w*|\w*_\w+|\w*\d\w*[A-Za-z]\w*|[a-z]+[A-Z]\w*)\b")
OK_CAPS = {"I", "OK", "C", "P", "U", "G", "M", "L", "V", "A", "K", "F", "T", "D", "N", "S", "R", "H", "B", "Q",
           "E", "X", "Y", "Z", "PDF"}


def checks(texts):
    problems = []
    for k, t in texts.items():
        if re.search("[\u2013\u2014]", t):
            problems.append(f"{k}: en or em dash")
        if re.search(r"\d,\d{3}", t):
            problems.append(f"{k}: comma as thousands separator")
        spoken = speech.tts_text(t)
        left = sorted(set(w for w in RISKY.findall(spoken) if w not in OK_CAPS))
        if left:
            problems.append(f"{k}: possibly risky in TTS input: {', '.join(left)}")
    return problems


def main():
    talk, qa = load()
    OUT.mkdir(parents=True, exist_ok=True)
    texts = {s["id"]: s["text"] for s in talk}
    (OUT / "script.md").write_text(script_md(talk), encoding="utf-8")
    if qa:
        for i, q in enumerate(qa["questions"], 1):
            texts[f"qa{i}_question"] = q["question"]
            texts[f"qa{i}_answer"] = q["answer"]
        (OUT / "qa.md").write_text(qa_md(qa), encoding="utf-8")
    (OUT / "pronunciation.md").write_text(pronunciation_md(texts), encoding="utf-8")
    for f in ("script.md", "qa.md", "pronunciation.md"):
        p = OUT / f
        if p.exists() and re.search("[\u2013\u2014]", p.read_text(encoding="utf-8")):
            print(f"DASH in {f}")
    for p in checks(texts):
        print("CHECK", p)
    slides = [s for s in talk if s.get("slide")]
    tot = sum(est(s["text"]) for s in slides)
    print(f"talk: {sum(speech.spoken_words(s['text']) for s in slides)} spoken words, est {mmss(tot)}")


if __name__ == "__main__":
    main()
