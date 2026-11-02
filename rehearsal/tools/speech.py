"""Text for the ear: pronunciation respellings and numbers as words.

The script text (also the subtitles) stays as written; tts_text() returns what a
TTS engine gets. Used for the word counts of step 1 and the TTS input of steps 2
and 4, so both always agree.
"""
import re
from pathlib import Path

import yaml
from num2words import num2words

SRC = Path(__file__).resolve().parent.parent / "src"
MARKER = re.compile(r"\[(pause|demo) (\d+(?:\.\d+)?) s\]")


def load_pron(path=SRC / "pron.yaml"):
    data = yaml.safe_load(open(path, encoding="utf-8"))
    entries = [e for group in data.values() for e in group]
    return entries


def _term_regex(term):
    # A term is matched as a whole: not preceded or followed by a word character,
    # and not glued to a hyphen-joined or dotted neighbour (llama2.c, burn-nostd).
    return re.compile(r"(?<![\w\-.])" + re.escape(term) + r"(?![\w\-]|\.\w)")


_ENTRIES = None


def entries():
    global _ENTRIES
    if _ENTRIES is None:
        _ENTRIES = sorted(load_pron(), key=lambda e: -len(e["term"]))
        for e in _ENTRIES:
            e["re"] = _term_regex(e["term"])
    return _ENTRIES


def _cardinal(n):
    words = num2words(n, lang="en")
    return words.replace(",", "").replace(" and ", " ")


def _decimal(text):
    whole, frac = text.split(".")
    return _cardinal(int(whole)) + " point " + " ".join(_cardinal(int(d)) for d in frac)


def numbers_to_words(text):
    # 1 056 540 (space-grouped thousands), then decimals, then plain integers.
    # A number may end a sentence ("... 128."), but not run into a word or a version ("0.22.1").
    end = r"(?![\w]|\.\w)"
    text = re.sub(r"(?<![\w.])(\d{1,3}(?: \d{3})+)" + end,
                  lambda m: _cardinal(int(m.group(1).replace(" ", ""))), text)
    text = re.sub(r"(?<![\w.])(\d+\.\d+)" + end, lambda m: _decimal(m.group(1)), text)
    text = re.sub(r"(?<![\w.])(\d+)" + end, lambda m: _cardinal(int(m.group(1))), text)
    return text


def respell(text):
    for e in entries():
        text = e["re"].sub(e["tts"], text)
    return text


def tts_text(text):
    """The words a TTS engine should speak; markers removed."""
    text = MARKER.sub(" ", text)
    text = respell(text)
    text = numbers_to_words(text)
    text = text.replace("%", " percent")
    return re.sub(r"[ \t]+", " ", text).strip()


def pauses(text):
    """Seconds of silence or demo marked in the text."""
    return sum(float(m.group(2)) for m in MARKER.finditer(text))


def subtitle_text(text):
    return re.sub(r"[ \t]+", " ", MARKER.sub(" ", text)).strip()


def spoken_words(text):
    return len([w for w in re.split(r"[\s\-]+", tts_text(text)) if re.search(r"\w", w)])


def display_words(text):
    return len([w for w in subtitle_text(text).split() if re.search(r"\w", w)])


def kokoro_text(text):
    """Like tts_text, but terms with Kokoro phonemes become misaki overrides: [term](/phonemes/)."""
    text = MARKER.sub(" ", text)
    for e in entries():
        if e.get("ipa"):
            text = e["re"].sub(lambda m, e=e: f"[{e['term']}](/{e['ipa']}/)", text)
        else:
            text = e["re"].sub(e["tts"], text)
    text = numbers_to_words(text)
    text = text.replace("%", " percent")
    return re.sub(r"[ \t]+", " ", text).strip()
