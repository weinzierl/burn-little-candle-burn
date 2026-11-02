# Rehearsal

A virtual run of the talk, for practice: the script read by synthetic voices over
the slides, with a clock, subtitles, and five audience questions with a pause for
your own answer. Not part of the talk itself.

The session is 45:00: the moderator's introduction (0:20), the talk (35:00), the
Q&A (8:00: five questions of 1:36 each, that is the question, 20 s for your answer
and a model answer), and 1:40 in reserve.

## Files

| Path | What |
|---|---|
| `src/talk.yaml` | The spoken script, one entry per slide, with its target time: the planned times of `notes/notes.yaml` scaled from 40:00 to 35:00 |
| `src/qa.yaml` | Five questions: who asks, the question, a model answer, the slide to go back to |
| `src/pron.yaml` | How names, code and numbers are spoken (the voices get the respellings, the subtitles the script) |
| `script.md`, `qa.md`, `pronunciation.md` | The three as documents, made by `tools/build_step1.py` |
| `notes.md` | Problems in the slides noticed while writing the script |
| `tools/` | The scripts of the steps below |
| `requirements.txt` | Python packages |
| `out/`, `models/`, `.venv/` | Made or downloaded here; git ignores them |

## Steps

All commands in this folder. Each step writes only into `out/` (step 1: next to `src/`).

0. Once: a Python environment in `.venv/` and the Kokoro-82M model (Apache 2.0, 354 MB) in `models/`:

       python3 -m venv .venv
       .venv/bin/pip install -r requirements.txt
       mkdir -p models
       curl -L -o models/kokoro-v1.0.onnx https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/kokoro-v1.0.onnx
       curl -L -o models/voices-v1.0.bin https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/voices-v1.0.bin
       shasum -a 256 models/*

   The checksums of the files used here: `7d5df8ecf7d4b1878015a32686053fd0eebe2bc377234608764cc0ef3636a6c5`
   (`kokoro-v1.0.onnx`) and `bca610b8308e8d99f32e6fe4197e7ec01679264efed0cac9140fe9c29f1fbf7d` (`voices-v1.0.bin`).

1. Documents from `src/`, with word counts and the time at 135 words per minute:

       .venv/bin/python tools/build_step1.py

2. Audio, one WAV per segment, in `out/audio/`, with the time of every sentence in
   `out/audio/durations.json` (about 25 minutes on two CPU cores; one segment:
   `--only 07_slide07`):

       .venv/bin/python tools/tts_kokoro.py

3. Slide images (3840 x 2160, needs `pdftoppm` from poppler), Q&A cards and the
   package for ElevenLabs in `out/elevenlabs/`:

       .venv/bin/python tools/make_assets.py

   The slides come from `../presentation-public.pdf`. `--pdf FILE` takes another
   edition, for example the private one; `out/` stays out of git either way.

4. The video, the MP3 and the subtitles in `out/build/`:

       python3 out/elevenlabs/rebuild.py --audio out/audio --timings out/audio/durations.json --out out/build

   `rebuild.py` needs an ffmpeg with the `subtitles` and `drawtext` filters; how
   to get one, and how to rebuild with other voices (ElevenLabs), is in
   `out/elevenlabs/README.md`.

Optional: `tools/asr_check.py` transcribes the audio with Whisper (`.venv/bin/pip install faster-whisper==1.2.1`)
and lists the words it heard differently from the script, a check of the pronunciations.

## Voices

Kokoro voices: the speaker `am_michael` at speed 0.85 (134 words per minute over the talk, slide changes included),
the moderator `af_heart`, the five questioners `af_bella`, `bm_george`, `am_fenrir`,
`bf_emma` and `am_puck`. The descriptions for ElevenLabs are in
`out/elevenlabs/voices.md`.
