#!/usr/bin/env python3
"""Step 2: one WAV per segment with Kokoro-82M v1.0 (kokoro-onnx), misaki G2P.

Usage: python3 tools/tts_kokoro.py [--speed-narrator S] [--only ID ...]
Writes out/audio/<id>.wav (24 kHz mono) and out/audio/durations.json.
"""
import argparse
import json
import re
import sys
import time
from pathlib import Path

import numpy as np
import soundfile as sf
import yaml

sys.path.insert(0, str(Path(__file__).resolve().parent))
import speech  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "out" / "audio"
SR = 24000
PARA_GAP = 0.75  # seconds between paragraphs inside a segment
SENT_GAP = 0.4  # seconds between sentences

VOICES = {  # role: (Kokoro voice, speed relative to the role's base)
    "narrator": ("am_michael", 1.0),
    "moderator": ("af_heart", 0.95),
    "q1": ("af_bella", 0.9),
    "q2": ("bm_george", 0.85),
    "q3": ("am_fenrir", 0.88),
    "q4": ("bf_emma", 0.74),
    "q5": ("am_puck", 0.75),
}


def segments():
    import segments as plan
    return [{"id": s["id"], "role": s["role"], "text": s["text"]} for s in plan.build() if s.get("text")]


def engine():
    import espeakng_loader
    from phonemizer.backend.espeak.wrapper import EspeakWrapper
    EspeakWrapper.set_library(espeakng_loader.get_library_path())
    EspeakWrapper.set_data_path(espeakng_loader.get_data_path())
    from kokoro_onnx import Kokoro
    from misaki import en, espeak
    g2p = en.G2P(trf=False, british=False, fallback=espeak.EspeakFallback(british=False))
    kokoro = Kokoro(str(ROOT / "models" / "kokoro-v1.0.onnx"), str(ROOT / "models" / "voices-v1.0.bin"))
    return g2p, kokoro


def sentences(paragraph):
    """Split after . ! ? (with a closing quote) where the next sentence starts."""
    out, start = [], 0
    for m in re.finditer(r'[.!?]["\u201d]?(?=\s+["\u201c(]?[A-Z0-9])', paragraph):
        out.append(paragraph[start:m.end()].strip())
        start = m.end()
    out.append(paragraph[start:].strip())
    return [p for p in out if p]


def trim(audio, threshold=0.004):
    """Cut leading and trailing near-silence, keep 40 ms on each side."""
    loud = np.flatnonzero(np.abs(audio) > threshold)
    if not len(loud):
        return audio
    pad = int(0.04 * SR)
    return audio[max(0, loud[0] - pad): min(len(audio), loud[-1] + pad)]


def synth(g2p, kokoro, seg, narrator_speed):
    """Audio of a segment, and the timing of every sentence: [(start, end, text), ...]."""
    voice, rel = VOICES[seg["role"]]
    speed = rel * (narrator_speed if seg["role"] == "narrator" else 1.0)
    lang = "en-gb" if voice.startswith("b") else "en-us"
    parts, timing, t = [], [], 0.0

    def add(samples):
        nonlocal t
        parts.append(samples)
        t += len(samples) / SR

    for para in [p.strip() for p in seg["text"].strip().split("\n") if p.strip()]:
        m = speech.MARKER.fullmatch(para)
        if m:
            add(np.zeros(int(float(m.group(2)) * SR), dtype=np.float32))
            continue
        for si, sentence in enumerate(sentences(para)):
            if parts:
                add(np.zeros(int((SENT_GAP if si else PARA_GAP) * SR), dtype=np.float32))
            phonemes, _ = g2p(speech.kokoro_text(sentence))
            audio, sr = kokoro.create(phonemes, voice=voice, speed=speed, lang=lang, is_phonemes=True)
            assert sr == SR
            audio = trim(audio.astype(np.float32))
            start = t
            add(audio)
            timing.append([round(start, 3), round(t, 3), sentence])
    return np.concatenate(parts), voice, speed, timing


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--speed-narrator", type=float, default=0.85, help="0.85: about 140 words per minute while speaking")
    ap.add_argument("--only", nargs="*")
    args = ap.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    g2p, kokoro = engine()
    meta_path = OUT / "durations.json"
    meta = json.loads(meta_path.read_text()) if meta_path.exists() else {}
    for seg in segments():
        if args.only and seg["id"] not in args.only:
            continue
        t0 = time.time()
        audio, voice, speed, timing = synth(g2p, kokoro, seg, args.speed_narrator)
        sf.write(OUT / f"{seg['id']}.wav", audio, SR, subtype="PCM_16")
        words = speech.spoken_words(seg["text"])
        dur = len(audio) / SR
        speech_s = dur - speech.pauses(seg["text"])
        meta[seg["id"]] = {"role": seg["role"], "voice": voice, "speed": round(speed, 3), "seconds": round(dur, 2),
                           "words": words, "wpm": round(words / speech_s * 60, 1) if speech_s > 0 else None,
                           "sentences": timing}
        meta_path.write_text(json.dumps(meta, indent=1))
        print(f"{seg['id']:<14} {voice:<11} {dur:6.1f} s  {meta[seg['id']]['wpm']} wpm  ({time.time() - t0:.1f} s)", flush=True)


if __name__ == "__main__":
    main()
