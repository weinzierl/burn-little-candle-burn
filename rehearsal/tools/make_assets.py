#!/usr/bin/env python3
"""Slide images, Q&A cards, manifest.json and the ElevenLabs package.

    python3 tools/make_assets.py [--pdf DECK.pdf]     (default: ../presentation-public.pdf)

Writes the package to out/elevenlabs/ (rebuild.py, manifest.json, assets/, text/,
full_script.txt, pronunciation.pls, voices.md, README.md), with the Kokoro audio
of out/audio/ as audio_kokoro/ and timings_kokoro.json if tools/tts_kokoro.py made it.
Needs pdftoppm (poppler) for the slide images.
"""
import json
import re
import shutil
import subprocess
import sys
import textwrap
from pathlib import Path
from xml.sax.saxutils import escape

import yaml
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, str(Path(__file__).resolve().parent))
import speech  # noqa: E402
from tts_kokoro import VOICES, sentences  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
TALK = ROOT.parent  # the talk repository
PKG = ROOT / "out" / "elevenlabs"
W, H = 3840, 2160
CREAM, SAND, GOLD, BLACK = (0xEF, 0xE8, 0xD8), (0xD9, 0xCD, 0xB3), (0xE0, 0xAE, 0x4E), (0x26, 0x26, 0x26)
FONTS = TALK / "fonts" / "public"
QA_BUDGET = 96  # 8:00 for five questions
SESSION = 45 * 60
GAP = 1.5  # seconds between one segment's audio and the next: the breath at a slide change
BUILD_TIME = "about 14 minutes"  # measured on the full 4K build in this workspace
AUDIO = ROOT / "out" / "audio"


def font(name, size, wght=None):
    f = ImageFont.truetype(str(FONTS / name), size)
    if wght is not None:
        f.set_variation_by_axes([wght] if "Jost" in name else [300, wght])
    return f


def tracked(draw, xy, text, f, fill, tracking):
    x, y = xy
    for ch in text:
        draw.text((x, y), ch, font=f, fill=fill)
        x += draw.textlength(ch, font=f) + tracking


def wrap(draw, text, f, width):
    words, lines, line = text.split(), [], ""
    for w in words:
        trial = (line + " " + w).strip()
        if draw.textlength(trial, font=f) <= width:
            line = trial
        else:
            lines.append(line)
            line = w
    if line:
        lines.append(line)
    return lines


def card(path, tag, title, persona, question, pause=False):
    img = Image.new("RGB", (W, H), BLACK)
    d = ImageDraw.Draw(img)
    left, width = 224, W - 2 * 224
    tracked(d, (left, 160), tag.upper(), font("Jost[wght].ttf", 50, 500), CREAM, 9)
    d.text((left, 250), title, font=font("KumbhSans[YOPQ,wght].ttf", 150, 700), fill=CREAM)
    y = 470
    if not pause:
        f = font("Jost[wght].ttf", 62, 400)
        for line in wrap(d, persona, f, width):
            d.text((left, y), line, font=f, fill=SAND)
            y += 84
        y += 70
        fq = font("Jost[wght].ttf", 100, 500)
        for line in wrap(d, f"“{question}”", fq, width):
            d.text((left, y), line, font=fq, fill=GOLD)
            y += 130
    else:
        fq = font("Jost[wght].ttf", 70, 400)
        for line in wrap(d, f"“{question}”", fq, width):
            d.text((left, y), line, font=fq, fill=SAND)
            y += 96
    d.rectangle([0, 1872, W, 1872 + 28], fill=CREAM)  # the deck's horizon line
    img.save(path, optimize=True)


def render_slides(dest, pdf, last):
    """Pages 1 to last (the talk, without the backup slides) at 288 dpi: 3840 x 2160 for a 960 x 540 pt deck."""
    tmp = dest / "tmp"
    tmp.mkdir(parents=True, exist_ok=True)
    subprocess.run(["pdftoppm", "-r", "288", "-f", "1", "-l", str(last), "-png", str(pdf), str(tmp / "s")], check=True)
    for p in sorted(tmp.glob("s-*.png")):
        n = int(re.search(r"(\d+)\.png$", p.name).group(1))
        im = Image.open(p)
        assert im.size == (W, H), im.size
        im.save(dest / f"slide-{n:02d}.png", optimize=True)
    shutil.rmtree(tmp)


def segment_sentences(text):
    items = []
    for para in [p.strip() for p in text.strip().split("\n") if p.strip()]:
        m = speech.MARKER.fullmatch(para)
        if m:
            items.append({"pause": float(m.group(2))})
            continue
        for s in sentences(para):
            items.append({"text": s, "words": speech.spoken_words(s)})
    return items


VOICE_NOTES = {
    "narrator": ("Ludwig, the speaker", "male", "around 50", "German, speaking fluent English: a light German accent is right",
                 "warm, precise, dry humour, never salesy", "calm, about 135 words per minute, short pauses between sentences"),
    "moderator": ("Moderator", "female", "30 to 45", "Italian, fluent English (RustLab is run by Develer, Florence)",
                  "friendly, crisp, welcoming", "normal pace, slightly faster than the speaker"),
    "q1": ("Q1, maker at her first RustLab", "female", "20s", "any European accent, light",
           "friendly, a bit shy, curious", "quick, slightly rushed"),
    "q2": ("Q2, numerics engineer", "male", "40s to 50s", "British",
           "dry, precise, sceptical but polite", "measured, deliberate"),
    "q3": ("Q3, backend developer who ships ort", "male", "30s", "American",
           "pragmatic, a little impatient", "brisk"),
    "q4": ("Q4, engineering lead", "female", "40s", "Dutch or Scandinavian, light",
           "calm, serious, wants a straight answer", "steady"),
    "q5": ("Q5, sceptical senior developer", "male", "50s", "Italian, clearly audible",
           "provocative with a smile, loud enough for the room", "medium, emphatic"),
}


def pls(path):
    data = yaml.safe_load(open(ROOT / "src" / "pron.yaml", encoding="utf-8"))
    rows = ['<?xml version="1.0" encoding="UTF-8"?>',
            '<lexicon version="1.0" xmlns="http://www.w3.org/2005/01/pronunciation-lexicon"',
            '         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"',
            '         xsi:schemaLocation="http://www.w3.org/2005/01/pronunciation-lexicon',
            '           http://www.w3.org/TR/2007/CR-pronunciation-lexicon-20071212/pls.xsd"',
            '         alphabet="ipa" xml:lang="en-US">']
    for group in data.values():
        for e in group:
            if e["tts"] == e["term"]:
                continue
            rows += ["  <lexeme>", f"    <grapheme>{escape(e['term'])}</grapheme>", f"    <alias>{escape(e['tts'])}</alias>", "  </lexeme>"]
    rows.append("</lexicon>")
    Path(path).write_text("\n".join(rows) + "\n", encoding="utf-8")


def write_voices(path, segs):
    rows = ["# Voice casting", "",
            "One voice per role. The Kokoro voice is what the rehearsal video uses now; the rest is the brief for "
            "ElevenLabs (voice library search or voice design).", ""]
    for role, (name, gender, age, accent, tone, pace) in VOICE_NOTES.items():
        files = [s["id"] for s in segs if s["role"] == role and s.get("file")]
        rows += [f"## {name}", "",
                 f"- Gender: {gender}", f"- Age: {age}", f"- Accent: {accent}", f"- Tone: {tone}", f"- Pace: {pace}",
                 f"- Kokoro voice used: `{VOICES[role][0]}`",
                 f"- Segments: {len(files)} ({', '.join(files[:3])}{', ...' if len(files) > 3 else ''})", ""]
    rows += ["## ElevenLabs settings that suit a talk", "",
             "- Model: a multilingual model, so the accents above are possible.",
             "- Stability around 50 %, similarity around 75 %, style low (0 to 20 %): a talk, not a performance.",
             "- Keep one voice per role for all its segments, so the speaker sounds the same from slide 1 to the last answer.",
             "- The text files already contain the respellings from pronunciation.md. Upload pronunciation.pls only if "
             "you paste the original script text instead.", ""]
    Path(path).write_text("\n".join(rows), encoding="utf-8")


def write_readme(path, segs):
    n_audio = sum(1 for s in segs if s.get("file"))
    rows = ["# Rehearsal video: rebuild with new audio", "",
            "Everything to turn one audio file per segment into the rehearsal video: slide images, Q&A cards, "
            "the text of every segment, and the rebuild script.", "",
            "## What is here", "",
            "| Path | What |", "|---|---|",
            f"| `text/*.txt` | The {n_audio} segments to speak, one file each, exactly as to be spoken (respellings applied, numbers written out) |",
            "| `full_script.txt` | The same, in order, with a heading per segment: for one ElevenLabs Studio project |",
            "| `pronunciation.pls` | The respellings as a PLS dictionary (aliases), for ElevenLabs |",
            "| `voices.md` | Voice casting per role |",
            "| `manifest.json` | Segment order, file names, role, target time, image per segment |",
            "| `rebuild.py` | Builds the video from the audio files |",
            "| `audio/` | Put your audio files here |",
            "| `audio_kokoro/`, `timings_kokoro.json` | The Kokoro audio of the current video, and its sentence timings |",
            "| `assets/` | Slide images (3840 x 2160), Q&A cards, fonts (OFL) |", "",
            "## What you need", "",
            "Python 3 (standard library only) and an ffmpeg with the `subtitles` and `drawtext` filters and the `libx264` "
            "and `libmp3lame` encoders. rebuild.py checks this first and says what is missing.", "",
            "- macOS: `brew install ffmpeg-full`. It installs beside a plain `ffmpeg` without replacing it (keg-only), so "
            "add `--ffmpeg \"$(brew --prefix ffmpeg-full)/bin\"` to each rebuild command below. Homebrew's plain `ffmpeg` "
            "may lack the two filters; rebuild.py tells you if it does.",
            "- Ubuntu or Debian: `sudo apt install ffmpeg` has everything.", "",
            "## Rebuild with ElevenLabs audio", "",
            "1. Make one MP3 per text file in ElevenLabs, named like the text file: `text/07_slide07.txt` becomes "
            "`07_slide07.mp3`. Use one voice per role (voices.md).",
            "2. Put them into `audio/`. Then fill the segments you have not made with the Kokoro files "
            "(`-n` never overwrites yours):",
            "", "       cp -n audio_kokoro/*.mp3 audio/", "",
            "3. Build:", "", "       python3 rebuild.py", "",
            "   The result is in `build/`: `rehearsal.mp4` (H.264 with chapters), `rehearsal.mp3` (with chapters), "
            "`rehearsal.srt`, and `timeline.md` (target and actual time per slide and per question).",
            "", "   `python3 rebuild.py --width 1920` builds a 1080p video, about four times faster. "
            "`python3 rebuild.py --only-audio` makes only the MP3, the SRT and the timeline, in seconds: "
            "the quick way to see whether new audio still fits.", "",
            "To rebuild the current video from the Kokoro files: `python3 rebuild.py --audio audio_kokoro`.", "",
            f"A 4K build of the whole session took {BUILD_TIME} on two cloud CPU cores; a recent Mac is faster.", "",
            "## How the timing works", "",
            f"- Every slide stays on screen as long as its audio, plus {GAP} s for the slide change, plus any marked pause "
            "(the QR codes on slide 46). Longer audio makes the slide longer; nothing is cut.",
            "- Slide 42 has the live demo: `42_slide42` is spoken before it, `42_slide42b` after, and 20 s of silence in between.",
            "- The overlay: top line of the band, left, the elapsed time against 45:00; right, the countdown of the current "
            "slide's target time from `manifest.json`, red with a plus sign once it runs over. For each question the countdown "
            "covers question, your 20 s and the answer together: 1:36, so five questions fit 8:00. A thin bar at the bottom edge "
            "shows the progress through 45:00.",
            "- Subtitles: the script text, not the respellings. For a Kokoro file each sentence starts exactly where it is "
            "spoken (timings_kokoro.json, matched by the file's SHA-1, so it never applies to a file you replaced); for "
            "your files the sentences are placed by word count and snapped to the pauses in the audio. The questions are "
            "not burned in, because the card already shows them; they are in the SRT.",
            "- Q&A: the question plays over a card with the persona and the question; then 20 s for your answer with a countdown; "
            "then the model answer over the slide it refers to.", ""]
    Path(path).write_text("\n".join(rows), encoding="utf-8")


def export_kokoro(segs):
    """The Kokoro audio as MP3 (audio_kokoro/) and its sentence timings, keyed by the MP3's SHA-1.

    rebuild.py uses a timing entry only for the very file it was made for, so an
    ElevenLabs file under the same name never gets the Kokoro timings."""
    import hashlib
    dest = PKG / "audio_kokoro"
    dest.mkdir(parents=True, exist_ok=True)
    durations = json.loads((AUDIO / "durations.json").read_text())
    timings = {}
    for s in segs:
        if not s.get("file") or s["id"] not in durations or not (AUDIO / f"{s['id']}.wav").exists():
            continue
        mp3 = dest / f"{s['id']}.mp3"
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(AUDIO / f"{s['id']}.wav"), "-ac", "1",
                        "-c:a", "libmp3lame", "-b:a", "64k", str(mp3)], check=True)
        d = durations[s["id"]]
        timings[s["id"]] = {"sha1": hashlib.sha1(mp3.read_bytes()).hexdigest(), "seconds": d["seconds"],
                            "voice": d["voice"], "sentences": d["sentences"]}
    (PKG / "timings_kokoro.json").write_text(json.dumps(timings, indent=1, ensure_ascii=False), encoding="utf-8")
    print(f"Kokoro audio: {len(timings)} of {sum(1 for s in segs if s.get('file'))} segments in audio_kokoro/")


def main():
    import argparse
    import segments as plan
    ap = argparse.ArgumentParser(description="Slide images, Q&A cards, texts and manifest in out/elevenlabs/.")
    ap.add_argument("--pdf", type=Path, default=TALK / "presentation-public.pdf",
                    help="the deck to take the slide images from (default: the public edition)")
    args = ap.parse_args()
    if not args.pdf.exists():
        sys.exit(f"no {args.pdf}")
    shutil.rmtree(PKG, ignore_errors=True)
    for d in ("assets/slides", "assets/cards", "assets/fonts", "text", "audio"):
        (PKG / d).mkdir(parents=True)
    talk = yaml.safe_load(open(ROOT / "src" / "talk.yaml", encoding="utf-8"))
    render_slides(PKG / "assets" / "slides", args.pdf, max(s["slide"] for s in talk if s.get("slide")))
    for f in ["Jost[wght].ttf", "OFL-Jost.txt", "IBMPlexMono-Regular.ttf", "OFL-IBMPlexMono.txt"]:
        shutil.copy(FONTS / f, PKG / "assets" / "fonts" / f)
    qa = yaml.safe_load(open(ROOT / "src" / "qa.yaml", encoding="utf-8"))
    for i, q in enumerate(qa["questions"], 1):
        card(PKG / "assets" / "cards" / f"qa{i}_question.png", f"Q&A \u00b7 question {i} of 5 \u00b7 {q['type']}",
             q["persona_short"], q["persona"].strip(), q["question"].strip())
        card(PKG / "assets" / "cards" / f"qa{i}_pause.png", f"Q&A \u00b7 question {i} of 5", "Your answer", "",
             q["question"].strip(), pause=True)
    segs = plan.build()
    full = ["Burn, little candle, burn! Virtual rehearsal, complete text for ElevenLabs Studio.",
            "One section per audio file, in order. The heading is not to be spoken; the text below it is.", ""]
    for s in segs:
        if s.get("text"):
            spoken = "\n\n".join(speech.tts_text(p) for p in s["text"].split("\n"))
            (PKG / "text" / f"{s['id']}.txt").write_text(spoken + "\n", encoding="utf-8")
            full += [f"=== {s['id']} ({VOICE_NOTES[s['role']][0]}) ===", "", spoken, ""]
            s["sentences"] = segment_sentences(s["text"])
            s["file"] = f"text/{s['id']}.txt"
            s["audio"] = f"audio/{s['id']}.mp3"
            s["voice_kokoro"] = VOICES[s["role"]][0]
            s.pop("text")
    (PKG / "full_script.txt").write_text("\n".join(full), encoding="utf-8")
    pls(PKG / "pronunciation.pls")
    manifest = {
        "title": "Burn, little candle, burn! Virtual rehearsal",
        "session_total": SESSION, "gap": GAP, "max_cue_chars": 80, "countdown_y": 0.52,
        "band": {"top": 0.8796, "timer_y": 0.905, "x_left": 0.0583, "x_right": 0.9417, "sub_margin_lr": 0.19,
                 "sub_margin_v": 0.012},
        "fonts": {"dir": "assets/fonts", "mono": "IBMPlexMono-Regular.ttf", "subtitle_family": "Jost"},
        "segments": segs,
    }
    (PKG / "manifest.json").write_text(json.dumps(manifest, indent=1, ensure_ascii=False), encoding="utf-8")
    shutil.copy(ROOT / "tools" / "rebuild.py", PKG / "rebuild.py")
    if (AUDIO / "durations.json").exists():
        export_kokoro(segs)
    else:
        print(f"no Kokoro audio in {AUDIO} (tools/tts_kokoro.py makes it): package without audio_kokoro/")
    write_voices(PKG / "voices.md", segs)
    write_readme(PKG / "README.md", segs)
    print(f"{len(segs)} segments, {sum(1 for s in segs if s.get('file'))} with audio; package in {PKG}")


if __name__ == "__main__":
    main()
