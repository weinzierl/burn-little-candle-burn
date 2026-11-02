#!/usr/bin/env python3
"""Listen to the narration with Whisper and compare it with the script: a pronunciation check.

    python3 tools/asr_check.py [ID ...]     (default: every segment)

Prints the word error rate per segment and the words Whisper heard differently.
"""
import difflib
import json
import re
import subprocess
import sys

import numpy as np
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import segments as plan  # noqa: E402
import speech  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
AUDIO = ROOT / "out" / "audio"


def norm(text):
    text = text.lower().replace("-", " ")
    text = re.sub(r"[^a-z0-9' ]+", " ", text)
    return text.split()


def main():
    from faster_whisper import WhisperModel
    model = WhisperModel("base.en", device="cpu", compute_type="int8")
    want = set(sys.argv[1:])
    report, total_err, total_n = {}, 0, 0
    for seg in plan.build():
        if not seg.get("text") or (want and seg["id"] not in want):
            continue
        wav = AUDIO / f"{seg['id']}.wav"
        if not wav.exists():
            continue
        pcm = subprocess.run(["ffmpeg", "-v", "error", "-i", str(wav), "-f", "f32le", "-ac", "1", "-ar", "16000", "-"],
                             capture_output=True, check=True).stdout
        parts, _ = model.transcribe(np.frombuffer(pcm, dtype=np.float32), language="en", beam_size=1, vad_filter=False)
        heard = norm(" ".join(p.text for p in parts))
        said = norm(speech.tts_text(seg["text"]))
        sm = difflib.SequenceMatcher(a=said, b=heard, autojunk=False)
        diffs = [(" ".join(said[i1:i2]), " ".join(heard[j1:j2])) for op, i1, i2, j1, j2 in sm.get_opcodes() if op != "equal"]
        err = sum(max(i2 - i1, j2 - j1) for op, i1, i2, j1, j2 in sm.get_opcodes() if op != "equal")
        total_err += err
        total_n += len(said)
        report[seg["id"]] = {"wer": round(err / max(1, len(said)), 3), "diffs": diffs}
        print(f"{seg['id']:<14} WER {err / max(1, len(said)):.1%}  " + "; ".join(f"{a!r}->{b!r}" for a, b in diffs[:8]), flush=True)
    (ROOT / "out" / "asr_check.json").write_text(json.dumps(report, indent=1))
    print(f"overall WER {total_err / max(1, total_n):.1%} over {total_n} words")


if __name__ == "__main__":
    main()
