#!/usr/bin/env python3
"""Build the rehearsal video from slide images, one audio file per segment and manifest.json.

    python3 rebuild.py                    # audio from ./audio, result in ./build
    python3 rebuild.py --audio DIR --out DIR [--fps 5] [--width 1920] [--ffmpeg DIR]

Needs only Python 3 (standard library) and an ffmpeg with the subtitles and
drawtext filters (libass, freetype) and the libx264 and libmp3lame encoders; it
checks this first. For every segment in manifest.json it takes
<audio dir>/<id>.mp3 (or .wav, .m4a, .ogg, .flac), so ElevenLabs files with the
same base names replace the Kokoro ones 1:1. Slide timing follows the actual
audio length; the overlay countdowns show the planned target times from the manifest.

Subtitle timing: a file listed in the timings file (default timings_kokoro.json)
with the same SHA-1 gets its exact sentence times; any other file gets its
sentences placed by word count and snapped to the pauses in the audio.

Output in --out: rehearsal.mp4 (H.264, chapters), rehearsal.mp3 (chapters),
rehearsal.srt, and timeline.md (per part: target, actual, start time).
"""
import argparse
import hashlib
import json
import math
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
AUDIO_EXT = (".mp3", ".wav", ".m4a", ".ogg", ".flac")
SR = 48000


def run(cmd, **kw):
    r = subprocess.run(cmd, capture_output=True, text=True, **kw)
    if r.returncode:
        sys.exit(f"command failed: {' '.join(map(str, cmd))}\n{r.stderr[-3000:]}")
    return r


def check_ffmpeg(video):
    for tool in ("ffmpeg", "ffprobe"):
        if not shutil.which(tool):
            sys.exit(f"{tool} not found. Install ffmpeg, or point to it with --ffmpeg DIR.")
    filters = run(["ffmpeg", "-hide_banner", "-filters"]).stdout
    encoders = run(["ffmpeg", "-hide_banner", "-encoders"]).stdout
    need = [("encoder", "libmp3lame", encoders)]
    if video:
        need += [("filter", "subtitles", filters), ("filter", "drawtext", filters), ("encoder", "libx264", encoders)]
    missing = [f"{kind} {name}" for kind, name, text in need if not re.search(rf"\s{name}\s", text)]
    if missing:
        sys.exit(f"{shutil.which('ffmpeg')} lacks: {', '.join(missing)}.\n"
                 "macOS: brew install ffmpeg-full, then add  --ffmpeg \"$(brew --prefix ffmpeg-full)/bin\"\n"
                 "Ubuntu or Debian: sudo apt install ffmpeg")
    print(f"ffmpeg: {shutil.which('ffmpeg')}", flush=True)


def sha1(path):
    return hashlib.sha1(Path(path).read_bytes()).hexdigest()


def timing_for(seg, timings):
    """The Kokoro sentence times, only for the very file they were measured on."""
    t = timings.get(seg["id"])
    if not t:
        return None
    if "sha1" in t:
        return t if sha1(seg["audio"]) == t["sha1"] else None
    return t if abs(t["seconds"] - seg["dur"]) < 0.3 else None


def probe_duration(path):
    """Length of the decoded audio. (An MP3's container duration includes the encoder padding.)"""
    r = subprocess.run(["ffmpeg", "-v", "error", "-i", str(path), "-ac", "1", "-ar", str(SR), "-f", "s16le", "-"],
                       capture_output=True)
    if r.returncode:
        sys.exit(f"cannot decode {path}:\n{r.stderr.decode(errors='replace')[-2000:]}")
    return len(r.stdout) / 2 / SR


def mmss(s, sign=False):
    neg = s < 0
    s = int(round(abs(s)))
    out = f"{s // 60}:{s % 60:02d}"
    return ("-" if neg else ("+" if sign else "")) + out


# ---------------------------------------------------------------- subtitles

def silences(path, noise="-38dB", min_len=0.22):
    r = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-i", str(path), "-af",
                        f"silencedetect=noise={noise}:d={min_len}", "-f", "null", "-"],
                       capture_output=True, text=True)
    starts = [float(x) for x in re.findall(r"silence_start: ([\d.]+)", r.stderr)]
    ends = [float(x) for x in re.findall(r"silence_end: ([\d.]+)", r.stderr)]
    return list(zip(starts, ends))


def align(sentences, duration, sil):
    """Sentence (start, end) times from word counts, snapped to detected silences."""
    items = sentences  # [{"text", "words"} or {"pause": seconds}]
    pause_total = sum(i.get("pause", 0) for i in items)
    words_total = sum(i.get("words", 0) for i in items) or 1
    speech = max(0.1, duration - pause_total)
    mids = [((a + b) / 2, b - a) for a, b in sil]
    out, t = [], 0.0
    for k, it in enumerate(items):
        if "pause" in it:
            # The marked pause is the longest silence near the expected place.
            near = [m for m in sil if m[1] - m[0] >= it["pause"] * 0.6 and abs(m[0] - t) < 8]
            if near:
                t = near[0][1]
            else:
                t += it["pause"]
            continue
        start = t
        end = start + speech * it["words"] / words_total
        if k < len(items) - 1:
            cands = [m for m, ln in mids if abs(m - end) < max(1.0, 0.25 * (end - start))]
            if cands:
                end = min(cands, key=lambda m: abs(m - end))
        else:
            end = duration
        out.append((start, max(end, start + 0.4), it["text"]))
        t = end
    # Trim each cue to the speech: start after a silence that begins it, end at the silence after it.
    fixed = []
    for s, e, txt in out:
        for a, b in sil:
            if a <= s + 0.05 < b:
                s = b
            if s < a < e < b + 0.3:
                e = a
        fixed.append((s, max(e, s + 0.4), txt))
    return fixed


def split_cue(start, end, text, max_chars):
    """Long sentences become several cues, split at a comma, colon or semicolon near the middle."""
    if len(text) <= max_chars:
        return [(start, end, text)]
    best, mid = None, len(text) / 2
    for m in re.finditer(r"[,;:] ", text):
        if best is None or abs(m.end() - mid) < abs(best - mid):
            best = m.end()
    if best is None:
        sp = [m.start() for m in re.finditer(" ", text)]
        best = min(sp, key=lambda i: abs(i - mid)) + 1 if sp else len(text) // 2
    a, b = text[:best].strip(), text[best:].strip()
    t = start + (end - start) * len(a) / max(1, len(a) + len(b))
    return split_cue(start, t, a, max_chars) + split_cue(t, end, b, max_chars)


def ass_time(t):
    t = max(0, t)
    h, rem = divmod(t, 3600)
    m, s = divmod(rem, 60)
    return f"{int(h)}:{int(m):02d}:{s:05.2f}"


def srt_time(t):
    t = max(0, t)
    ms = int(round(t * 1000))
    h, ms = divmod(ms, 3600000)
    m, ms = divmod(ms, 60000)
    s, ms = divmod(ms, 1000)
    return f"{h:02d}:{m:02d}:{s:02d},{ms:03d}"


def ass_file(path, cues, W, H, style):
    esc = lambda s: s.replace("\\", "\\\\").replace("{", "(").replace("}", ")").replace("\n", " ")
    lines = ["[Script Info]", "ScriptType: v4.00+", f"PlayResX: {W}", f"PlayResY: {H}", "WrapStyle: 0",
             "ScaledBorderAndShadow: yes", "", "[V4+ Styles]",
             "Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, "
             "Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, "
             "MarginR, MarginV, Encoding",
             f"Style: Sub,{style['font']},{style['size']},&H00D8E8EF,&H00D8E8EF,&H00000000,&H00000000,0,0,0,0,100,100,0,0,"
             f"1,{style['pad']},0,2,{style['margin_lr']},{style['margin_lr']},{style['margin_v']},1",
             "", "[Events]", "Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text"]
    for s, e, txt in cues:
        lines.append(f"Dialogue: 0,{ass_time(s)},{ass_time(e)},Sub,,0,0,0,,{esc(txt)}")
    Path(path).write_text("\n".join(lines) + "\n", encoding="utf-8")


# ---------------------------------------------------------------- video

def ff_escape_text(s):
    # drawtext text inside a filter script: escape \ ' : and %
    return s.replace("\\", "\\\\").replace("'", "\\'").replace(":", "\\:").replace("%", "\\%")


def mmss_expr(x):
    # m:ss of a non-negative expression x, for drawtext's %{eif}
    return (f"%{{eif\\:floor(({x})/60)\\:d}}\\:%{{eif\\:mod(floor({x})\\,60)\\:d\\:2}}")


def clip(seg, slot, offset, group_start, args, man, work, fonts):
    W, H, fps = args.width, args.height, args.fps
    k = W / 3840
    mono = fonts / man["fonts"]["mono"]
    total = man["session_total"]
    budget = seg["target"]
    g0 = offset - group_start  # time already spent in this budget group when the clip starts
    label = ff_escape_text(seg["label"])
    size = int(54 * k)
    y = int(man["band"]["timer_y"] * H)
    x_l, x_r = int(man["band"]["x_left"] * W), int(man["band"]["x_right"] * W)
    box = f"box=1:boxcolor=black@0.45:boxborderw={int(14 * k)}"
    elapsed = mmss_expr(f"{offset:.3f}+t")
    remaining = f"{budget:.3f}-{g0:.3f}-t"
    over = f"{g0:.3f}+t-{budget:.3f}"
    band_y = int(man["band"]["top"] * H)
    filters = [f"[0:v]scale={W}:{H}:flags=lanczos,setsar=1,"
               f"drawbox=x=0:y={band_y}:w=iw:h=ih-{band_y}:color=black@0.86:t=fill[b]"]
    src = "[b]"
    if seg.get("ass"):
        ass = str(work / f"{seg['id']}.ass").replace("\\", "/").replace(":", "\\:")
        filters.append(f"{src}subtitles=filename='{ass}':fontsdir='{str(fonts)}'[s]")
        src = "[s]"
    filters.append(
        f"{src}drawtext=fontfile='{mono}':fontsize={size}:fontcolor=0xEFE8D8:{box}:x={x_l}:y={y}:"
        f"text='{elapsed} / {ff_escape_text(mmss(total))}',"
        f"drawtext=fontfile='{mono}':fontsize={size}:fontcolor=0xEFE8D8:{box}:x={x_r}-text_w:y={y}:"
        f"text='{label}  {mmss_expr(f'max(0,{remaining})')}':enable='gte({remaining},0)',"
        f"drawtext=fontfile='{mono}':fontsize={size}:fontcolor=0xF08A6E:{box}:x={x_r}-text_w:y={y}:"
        f"text='{label}  +{mmss_expr(f'max(0,{over})')}':enable='lt({remaining},0)'[t]")
    if seg.get("countdown"):
        big = int(300 * k)
        cd = f"max(0,{seg['countdown']}-t)"
        filters.append(f"[t]drawtext=fontfile='{mono}':fontsize={big}:fontcolor=0xE0AE4E:x=(w-text_w)/2:"
                       f"y={int(man['countdown_y'] * H)}:text='{mmss_expr(f'ceil({cd})')}'[t2]")
        last = "[t2]"
    else:
        last = "[t]"
    bar_h = max(4, int(10 * k))
    filters.append(f"color=c=0xE0AE4E:s={W}x{bar_h}:r={fps}[bar]")
    filters.append(f"{last}[bar]overlay=x='-W+W*({offset:.3f}+t)/{total}':y=H-{bar_h}:eval=frame:shortest=1[v]")
    script = work / f"{seg['id']}.filter"
    script.write_text(";\n".join(filters), encoding="utf-8")
    out = work / f"{seg['id']}.mp4"
    run(["ffmpeg", "-hide_banner", "-y", "-loop", "1", "-framerate", str(fps), "-i", str(seg["image_path"]),
         "-filter_complex_script", str(script), "-map", "[v]", "-t", f"{slot:.3f}", "-r", str(fps),
         "-c:v", "libx264", "-preset", args.preset, "-tune", "stillimage", "-crf", str(args.crf),
         "-pix_fmt", "yuv420p", "-profile:v", "high", "-an", str(out)])
    return out


# ---------------------------------------------------------------- main

def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--manifest", default=str(HERE / "manifest.json"))
    ap.add_argument("--audio", default=str(HERE / "audio"))
    ap.add_argument("--timings", default=None,
                    help="sentence timings of the Kokoro files (default: timings_kokoro.json next to the manifest)")
    ap.add_argument("--out", default=str(HERE / "build"))
    ap.add_argument("--fps", type=int, default=5)
    ap.add_argument("--width", type=int, default=3840, help="3840 (4K) or 1920 (faster)")
    ap.add_argument("--preset", default="veryfast")
    ap.add_argument("--crf", type=int, default=20)
    ap.add_argument("--only-audio", action="store_true", help="MP3, SRT and timeline only, no video")
    ap.add_argument("--ffmpeg", default=None, help="directory with the ffmpeg and ffprobe to use (default: from PATH)")
    args = ap.parse_args()
    if args.ffmpeg:
        os.environ["PATH"] = str(Path(args.ffmpeg).expanduser()) + os.pathsep + os.environ.get("PATH", "")
    check_ffmpeg(video=not args.only_audio)
    args.height = args.width * 9 // 16
    man = json.loads(Path(args.manifest).read_text(encoding="utf-8"))
    root = Path(args.manifest).resolve().parent
    fonts = (root / man["fonts"]["dir"]).resolve()
    out = Path(args.out)
    work = out / "work"
    shutil.rmtree(work, ignore_errors=True)
    work.mkdir(parents=True)
    tpath = Path(args.timings) if args.timings else root / "timings_kokoro.json"
    timings = json.loads(tpath.read_text(encoding="utf-8")) if tpath.exists() else {}
    audio_dir = Path(args.audio)
    fps, gap = args.fps, man["gap"]

    # 1. Audio files, durations, slots on the frame grid.
    plan, offset = [], 0.0
    group, group_start = None, 0.0
    for seg in man["segments"]:
        seg = dict(seg)
        seg["image_path"] = root / seg["image"]
        if seg.get("silence"):
            dur, path = float(seg["silence"]), None
        else:
            path = next((audio_dir / f"{seg['id']}{e}" for e in AUDIO_EXT if (audio_dir / f"{seg['id']}{e}").exists()), None)
            if path is None:
                sys.exit(f"missing audio: {audio_dir}/{seg['id']}.mp3 (or .wav)")
            dur = probe_duration(path)
        pad = 0 if seg.get("silence") else gap + float(seg.get("tail_silence", 0))
        slot = math.ceil((dur + pad) * fps - 1e-6) / fps
        if seg["group"] != group:
            group, group_start = seg["group"], offset
        seg.update(audio=path, dur=dur, slot=slot, start=offset, group_start=group_start)
        plan.append(seg)
        offset += slot
    total = offset

    # 2. Subtitles: sentence timings from the Kokoro run when they fit, else aligned to silences.
    srt, n, exact, aligned = [], 0, 0, 0
    W, H = args.width, args.height
    k = W / 3840
    style = {"font": man["fonts"]["subtitle_family"], "size": int(80 * k), "pad": max(1, int(2 * k)),
             "margin_lr": int(man["band"]["sub_margin_lr"] * W), "margin_v": int(man["band"]["sub_margin_v"] * H)}
    for seg in plan:
        if not seg.get("sentences"):
            continue
        t = timing_for(seg, timings)
        if t:
            cues = [(a, b, txt) for a, b, txt in t["sentences"]]
            exact += 1
        else:
            cues = align(seg["sentences"], seg["dur"], silences(seg["audio"]))
            aligned += 1
        cues = [c for s, e, txt in cues for c in split_cue(s, e, txt, man["max_cue_chars"])]
        for s, e, txt in cues:
            n += 1
            srt.append(f"{n}\n{srt_time(seg['start'] + s)} --> {srt_time(seg['start'] + e)}\n{txt}\n")
        if seg.get("burn", True):
            ass_file(work / f"{seg['id']}.ass", cues, W, H, style)
            seg["ass"] = True
    out.mkdir(parents=True, exist_ok=True)
    (out / "rehearsal.srt").write_text("\n".join(srt), encoding="utf-8")
    print(f"subtitles: {exact} segments with exact sentence times, {aligned} placed by word count", flush=True)

    # 3. One audio track: every segment padded to its slot.
    parts = []
    for i, seg in enumerate(plan):
        p = work / f"a{i:03d}.wav"
        if seg["audio"] is None:
            run(["ffmpeg", "-hide_banner", "-y", "-f", "lavfi", "-i", f"anullsrc=r={SR}:cl=mono", "-t", f"{seg['slot']:.3f}", str(p)])
        else:
            run(["ffmpeg", "-hide_banner", "-y", "-i", str(seg["audio"]), "-ac", "1", "-ar", str(SR),
                 "-af", f"apad=whole_dur={seg['slot']:.3f}", "-t", f"{seg['slot']:.3f}", str(p)])
        parts.append(p)
    lst = work / "audio.txt"
    lst.write_text("".join(f"file '{p.name}'\n" for p in parts))
    full = work / "full.wav"
    run(["ffmpeg", "-hide_banner", "-y", "-f", "concat", "-safe", "0", "-i", str(lst), "-c", "copy", str(full)])

    # 4. Chapters.
    meta = [";FFMETADATA1", "title=Burn, little candle, burn! (rehearsal)", "artist=Ludwig Weinzierl"]
    for seg in plan:
        if seg.get("chapter"):
            meta.append("[CHAPTER]")
            meta.append("TIMEBASE=1/1000")
            meta.append(f"START={int(seg['start'] * 1000)}")
            end = next((s["start"] for s in plan[plan.index(seg) + 1:] if s.get("chapter")), total)
            meta.append(f"END={int(end * 1000)}")
            meta.append("title=" + seg["chapter"].replace("=", "\\=").replace(";", "\\;").replace("#", "\\#"))
    chapters = work / "chapters.txt"
    chapters.write_text("\n".join(meta) + "\n", encoding="utf-8")
    run(["ffmpeg", "-hide_banner", "-y", "-i", str(full), "-i", str(chapters), "-map", "0:a", "-map_metadata", "1",
         "-map_chapters", "1", "-c:a", "libmp3lame", "-b:a", "128k", "-id3v2_version", "3", str(out / "rehearsal.mp3")])

    # 5. Timeline.
    groups = {}
    for seg in plan:
        g = groups.setdefault(seg["group"], {"label": seg["label"], "target": seg["target"], "start": seg["start"], "actual": 0.0})
        g["actual"] += seg["slot"]
    rows = ["| Part | Target | Actual | Starts at | Difference |", "|---|---:|---:|---:|---:|"]
    for g in groups.values():
        d = g["actual"] - g["target"]
        rows.append(f"| {g['label']} | {mmss(g['target'])} | {mmss(g['actual'])} | {mmss(g['start'])} | {d:+.0f} s |")
    (out / "timeline.md").write_text(f"Total {mmss(total)} of {mmss(man['session_total'])}.\n\n" + "\n".join(rows) + "\n")
    (out / "timeline.json").write_text(json.dumps([{k: seg[k] for k in ("id", "group", "label", "target", "start", "slot", "dur")}
                                                   for seg in plan], indent=1))
    if args.only_audio:
        print(f"audio only: {mmss(total)}")
        return

    # 6. Video: one clip per segment, joined without re-encoding, then audio and chapters.
    clips = []
    for i, seg in enumerate(plan):
        clips.append(clip(seg, seg["slot"], seg["start"], seg["group_start"], args, man, work, fonts))
        print(f"[{i + 1}/{len(plan)}] {seg['id']} {seg['slot']:.1f} s", flush=True)
    vl = work / "video.txt"
    vl.write_text("".join(f"file '{c.name}'\n" for c in clips))
    video = work / "video.mp4"
    run(["ffmpeg", "-hide_banner", "-y", "-f", "concat", "-safe", "0", "-i", str(vl), "-c", "copy", str(video)])
    run(["ffmpeg", "-hide_banner", "-y", "-i", str(video), "-i", str(full), "-i", str(chapters),
         "-map", "0:v", "-map", "1:a", "-map_metadata", "2", "-map_chapters", "2", "-c:v", "copy",
         "-c:a", "aac", "-b:a", "160k", "-ar", str(SR), "-movflags", "+faststart", str(out / "rehearsal.mp4")])
    print(f"done: {out / 'rehearsal.mp4'}, {mmss(total)}")


if __name__ == "__main__":
    main()
