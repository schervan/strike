#!/usr/bin/env python3
"""Process raw generated audio into bundled game assets (pure stdlib + macOS afconvert/afinfo).

Usage:
  python3 -I tools/process_audio.py music_title sfx_shot_starter   # process ids (raw -> Strike/Resources/Audio)
  python3 -I tools/process_audio.py all                            # everything that has a raw file
  python3 -I tools/process_audio.py music_title --variant 2        # process _candidates/<file>_v2.wav
  python3 -I tools/process_audio.py --report                       # present/missing, duration, peak, RMS, seam
Options: --raw DIR, --out DIR, --music-rms-db (default -20 dBFS RMS, about -18 LUFS), --sfx-peak-db (-3).

Music loops: skip leading silence, cut N whole bars (from BPM and the id's Length), start/end nudged to
zero crossings, last 50 ms of overlap crossfaded (equal power) into the head so the loop wraps without a
click, normalized by RMS (peak limited to -1 dBFS), exported .m4a (AAC 128 kbps, 48 kHz).
Jingles: trim silence, 20 ms fade in/out, same loudness, .m4a.
SFX: strongest sound (first transient) of at most MaxLen s, trim silence (-50 dB), 5 ms fade in,
10 ms fade out, peak normalized to -3 dBFS, exported .caf (16-bit PCM, 48 kHz).
"""
import argparse, fnmatch, math, os, sys, tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))  # needed under python -I
import audio_common as ac  # noqa: E402

SILENCE_DB = -50.0
XFADE_SEC = 0.05
BEATS_PER_BAR = 4


# ---------------------------------------------------------------- primitives
def gain(au, g):
    au.ch = [[s * g for s in c] for c in au.ch]
    return au


def slice_audio(au, a, b):
    return ac.Audio([c[a:b] for c in au.ch], au.rate)


def trim_silence(au, thresh_db=SILENCE_DB):
    """Returns (start, end) sample indices of non-silent region (5 ms frames)."""
    env, f = ac.frame_env(au)
    th = 10 ** (thresh_db / 20)
    idx = [i for i, e in enumerate(env) if e > th]
    if not idx:
        return 0, 0
    return idx[0] * f, min(au.n, (idx[-1] + 1) * f)


def nearest_zero_crossing(au, pos, max_ms=10):
    """Nearest index (within +-max_ms) where the first channel changes sign; else pos."""
    c = au.ch[0]
    r = int(au.rate * max_ms / 1000)
    best = None
    for d in range(0, r + 1):
        for p in (pos - d, pos + d):
            if 1 <= p < len(c) and (c[p - 1] <= 0 < c[p] or c[p - 1] >= 0 > c[p]):
                return p
    return best if best is not None else pos


def fade(au, in_sec, out_sec):
    for c in au.ch:
        ni, no = min(len(c), int(in_sec * au.rate)), min(len(c), int(out_sec * au.rate))
        for i in range(ni):
            c[i] *= i / ni
        for i in range(no):
            c[len(c) - 1 - i] *= i / no
    return au


def loop_crossfade(au, start, length, xfade_sec=XFADE_SEC):
    """Loop of `length` samples starting at `start`. Needs au.n >= start+length+xfade.
    The audio following the loop end is blended into the loop start (equal power), so the
    jump end -> start is continuous."""
    x = int(xfade_sec * au.rate)
    if start + length + x > au.n:
        raise ValueError("not enough audio after loop end for the crossfade")
    out = []
    for c in au.ch:
        seg = c[start:start + length]
        tail = c[start + length:start + length + x]
        for i in range(x):
            t = (i + 0.5) / x
            seg[i] = seg[i] * math.sin(t * math.pi / 2) + tail[i] * math.cos(t * math.pi / 2)
        out.append(seg)
    return ac.Audio(out, au.rate)


def normalize_rms(au, target_db, peak_limit_db=-1.0):
    r = ac.rms(au)
    if r <= 1e-9:
        return au
    g = 10 ** (target_db / 20) / r
    p = ac.peak(au) * g
    lim = 10 ** (peak_limit_db / 20)
    if p > lim:
        g *= lim / p
    return gain(au, g)


def normalize_peak(au, target_db):
    p = ac.peak(au)
    return gain(au, 10 ** (target_db / 20) / p) if p > 1e-9 else au


def seam_ratio(au):
    """Max |jump| across the loop seam divided by the 99th-percentile sample-to-sample step. ~1 = clean."""
    c = au.ch[0]
    if len(c) < 100:
        return 0.0
    steps = sorted(abs(c[i + 1] - c[i]) for i in range(0, len(c) - 1, max(1, len(c) // 20000)))
    ref = max(steps[int(len(steps) * 0.99)], 1e-4)
    return abs(c[0] - c[-1]) / ref


# ---------------------------------------------------------------- per-kind processing
def process_loop(au, bpm, target_len, rms_db):
    s, e = trim_silence(au)
    au = slice_audio(au, s, e)
    bar = ac.RATE * 60.0 / bpm * BEATS_PER_BAR
    x = int(XFADE_SEC * au.rate)
    avail = au.n - x
    bars = int(min(target_len * au.rate, avail) // bar)
    if bars < 1:
        raise ValueError(f"only {au.seconds:.1f} s of audio, less than one bar")
    start = nearest_zero_crossing(au, 0, 20)
    avail = au.n - start - x
    bars = max(1, int(min(target_len * au.rate, avail) // bar))
    length = int(round(bars * bar))
    length = nearest_zero_crossing(au, start + length) - start
    length = min(length, au.n - start - x)
    out = loop_crossfade(au, start, length)
    return normalize_rms(out, rms_db), bars


def process_jingle(au, target_len, rms_db):
    s, e = trim_silence(au)
    au = slice_audio(au, s, min(e, s + int((target_len + 1.5) * au.rate)))
    return normalize_rms(fade(au, 0.02, 0.15), rms_db)


def process_sfx(au, maxlen, peak_db):
    env, f = ac.frame_env(au, 5)
    th = 10 ** (SILENCE_DB / 20)
    pk = max(env) if env else 0.0
    if pk <= th:
        raise ValueError("clip is silent")
    win = max(1, int(maxlen * au.rate / f))
    onset_th = max(th, pk * 10 ** (-30 / 20))
    cands = []
    for i, e in enumerate(env):
        prev = sum(env[max(0, i - 4):i]) / max(1, min(4, i)) if i else 0.0
        if e >= onset_th and (i == 0 or e > 3 * prev + th):
            cands.append(i)
    first = next(i for i, e in enumerate(env) if e > th)
    if first not in cands:
        cands.insert(0, first)  # slow-attack sounds have no sharp onset: the first audible frame counts too
    ens = [(i, sum(v * v for v in env[i:i + win])) for i in cands]
    top = max(e for _, e in ens)
    best = next(i for i, e in ens if e >= 0.6 * top)  # earliest onset that is nearly as strong as the best
    a = max(0, (best - 2) * f)  # ~10 ms pre-roll
    b = min(au.n, a + int(maxlen * au.rate))
    seg = slice_audio(au, a, b)
    s, e = trim_silence(seg)
    seg = slice_audio(seg, s, e)
    fade(seg, 0.005, 0.010)
    return normalize_peak(seg, peak_db)


# ---------------------------------------------------------------- driver
def export(au, path, kind):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with tempfile.TemporaryDirectory() as td:
        tmp = os.path.join(td, "x.wav")
        ac.write_wav(tmp, au)
        if path.endswith(".m4a"):
            ac.run(["afconvert", "-f", "m4af", "-d", f"aac@{ac.RATE}", "-b", "128000", "-s", "3", tmp, path])
        elif path.endswith(".caf"):
            ac.afconvert(tmp, path, "caff", f"LEI16@{ac.RATE}")
        else:
            raise ValueError("unknown output extension " + path)


def out_name(item):
    return item["file"] + (".caf" if item["group"] == "sfx" else ".m4a")


def process_item(item, src_wav, out_dir, args):
    au = ac.read_wav(src_wav)
    if au.rate != ac.RATE:
        raise ValueError(f"{src_wav}: sample rate {au.rate}, expected {ac.RATE}")
    info = ""
    if item["kind"] == "loop":
        au, bars = process_loop(au, item["bpm"], item["length"], args.music_rms_db)
        info = f"{bars} bars"
    elif item["kind"] == "jingle":
        au = process_jingle(au, item["length"], args.music_rms_db)
    else:
        au = process_sfx(au, item["maxlen"], args.sfx_peak_db)
    dst = os.path.join(out_dir, out_name(item))
    export(au, dst, item["kind"])
    print(f"  {item['id']}: {au.seconds:.2f} s, peak {ac.db(ac.peak(au)):.1f} dBFS, "
          f"rms {ac.db(ac.rms(au)):.1f} dBFS {info} -> {os.path.relpath(dst, ac.ROOT)}")
    return dst


def report(items, out_dir, raw_dir):
    print(f"{'id':<26} {'raw':<5} {'out':<8} {'dur s':>6} {'peak':>7} {'rms':>7}  notes")
    ok = 0
    for it in items:
        raw = os.path.isfile(os.path.join(raw_dir, it["file"] + ".wav"))
        path = os.path.join(out_dir, out_name(it))
        have = os.path.isfile(path)
        if not have:
            print(f"{it['id']:<26} {'yes' if raw else 'no':<5} {'MISSING':<8}")
            continue
        ok += 1
        with tempfile.TemporaryDirectory() as td:
            tmp = os.path.join(td, "d.wav")
            ac.to_wav48(path, tmp)
            au = ac.read_wav(tmp)
        notes = []
        if it["kind"] == "loop":
            sr = seam_ratio(au)
            notes.append(f"seam {sr:.1f}x" + (" CLICK?" if sr > 8 else ""))
        if it["kind"] == "sfx" and au.seconds > it["maxlen"] + 0.1:
            notes.append("longer than MaxLen")
        if ac.db(ac.peak(au)) > -0.5:
            notes.append("peak hot")
        env, f = ac.frame_env(au, 50)
        sil = sum(1 for e in env if e < 10 ** (SILENCE_DB / 20)) / max(1, len(env))
        if sil > 0.3:
            notes.append(f"silence {sil:.0%}")
        print(f"{it['id']:<26} {'yes' if raw else 'no':<5} {'ok':<8} {au.seconds:6.2f} "
              f"{ac.db(ac.peak(au)):7.1f} {ac.db(ac.rms(au)):7.1f}  {'; '.join(notes)}")
    print(f"{ok}/{len(items)} present in {os.path.relpath(out_dir, ac.ROOT)}")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("select", nargs="*", help="ids, globs, music, sfx, all")
    ap.add_argument("--report", action="store_true")
    ap.add_argument("--variant", type=int, default=0, help="use _candidates/<file>_vN.wav as source")
    ap.add_argument("--raw", default=ac.RAW)
    ap.add_argument("--out", default=ac.OUT)
    ap.add_argument("--music-rms-db", type=float, default=-20.0)
    ap.add_argument("--sfx-peak-db", type=float, default=-3.0)
    args = ap.parse_args()
    items = ac.parse_prompts()
    if args.report:
        report(items, args.out, args.raw)
        return
    if not args.select:
        ap.error("give ids or --report")
    chosen = []
    for tok in ",".join(args.select).split(","):
        hits = items if tok == "all" else [i for i in items if tok in ("music", "sfx") and i["group"] == tok or
                                           any(fnmatch.fnmatch(i["id"], p) for p in (tok, "sfx_" + tok, "music_" + tok))]
        if not hits:
            sys.exit(f"No id matches {tok!r}")
        chosen += [h for h in hits if h not in chosen]
    fails = 0
    for it in chosen:
        src = (os.path.join(args.raw, "_candidates", f"{it['file']}_v{args.variant}.wav") if args.variant
               else os.path.join(args.raw, it["file"] + ".wav"))
        if not os.path.isfile(src):
            if args.select != ["all"]:
                print(f"  {it['id']}: no raw file {os.path.relpath(src, ac.ROOT)}")
                fails += 1
            continue
        try:
            process_item(it, src, args.out, args)
        except Exception as e:
            print(f"  {it['id']}: FAILED {e}")
            fails += 1
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
