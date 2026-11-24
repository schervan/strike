#!/usr/bin/env python3
"""Synthesize Strike's sound effects (sfxr/chiptune style). Pure stdlib, deterministic.

Usage:
  python3 -I tools/synth_sfx.py                 # all 29 ids -> audio/raw/sfx_<id>.wav
  python3 -I tools/synth_sfx.py sfx_alert shot_* # selected ids
  python3 -I tools/synth_sfx.py --out DIR
Then: python3 -I tools/process_audio.py sfx   (trim, normalize, .caf into Strike/Resources/Audio/)

Recipes (RECIPES below) are lists of layers. Layer keys:
  osc    sq | saw | tri | sin | noise
  at     start offset in seconds          dur   length in seconds
  f      Hz (or note name like "C6");  f1 = end Hz for an exponential glide
  notes  list of notes -> one sub-layer per note, spaced by `step`; `ndur` = note length (default step),
         `glide` = f1/f ratio per note
  duty   square duty (0.125..0.5)          vib = [rate Hz, depth semitones]
  env    [attack, decay, sustain, release] seconds / level (sustain 0 = percussive, quadratic decay)
  vol    layer gain                         lp / hp   one-pole cutoff Hz, or [start, end] sweep
  crush  [bits, hold samples]
Recipe options: echo = [delay s, feedback, mix].
Master chain: 7.5 kHz low-pass (no harsh highs), 30 Hz DC blocker, 3 ms fade in, 15 ms fade out,
peak normalized to -3 dBFS. Clips are clipped to the MaxLen of audio/prompts/sfx.md.
"""
import argparse, fnmatch, math, os, random, re, sys, zlib

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import audio_common as ac  # noqa: E402

R = ac.RATE
PEAK_DB = -3.0
_SEMI = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def hz(n):
    if isinstance(n, (int, float)):
        return float(n)
    m = re.fullmatch(r"([A-G])([#b]?)(\d)", n)
    semi = _SEMI[m.group(1)] + (1 if m.group(2) == "#" else -1 if m.group(2) == "b" else 0)
    return 440.0 * 2 ** ((semi + 12 * (int(m.group(3)) - 4) - 9) / 12)


# ------------------------------------------------------------ DSP toolkit
def oscillator(kind, n, freq_at, duty=0.5, vib=None, rng=None):
    out, ph = [], 0.0
    for i in range(n):
        t = i / R
        f = freq_at(i / max(1, n - 1))
        if vib:
            f *= 2 ** (vib[1] / 12 * math.sin(2 * math.pi * vib[0] * t))
        ph = (ph + f / R) % 1.0
        if kind == "sq":
            s = 1.0 if ph < duty else -1.0
        elif kind == "saw":
            s = 2 * ph - 1
        elif kind == "tri":
            s = 4 * abs(ph - 0.5) - 1
        elif kind == "sin":
            s = math.sin(2 * math.pi * ph)
        else:
            s = rng.uniform(-1, 1)
        out.append(s)
    return out


def adsr(n, a, d, s, r):
    """Envelope list. Decay is quadratic (snappy); sustain 0 makes it percussive."""
    na, nd, nr = int(a * R), int(d * R), int(r * R)
    env = []
    for i in range(n):
        if i < na:
            e = i / max(1, na)
        elif i < na + nd:
            x = (i - na) / max(1, nd)
            e = s + (1 - s) * (1 - x) ** 2
        else:
            e = s
        if nr and i >= n - nr:
            e *= (n - 1 - i) / nr
        env.append(e)
    return env


def one_pole(x, cutoff, kind="lp"):
    """Low/high-pass; cutoff is Hz or [start, end] swept linearly."""
    n, y, out = len(x), 0.0, []
    for i, v in enumerate(x):
        fc = cutoff if isinstance(cutoff, (int, float)) else cutoff[0] + (cutoff[1] - cutoff[0]) * i / max(1, n - 1)
        a = 1 - math.exp(-2 * math.pi * fc / R)
        y += a * (v - y)
        out.append(y if kind == "lp" else v - y)
    return out


def bitcrush(x, bits, hold):
    q, out, last = 2 ** (bits - 1), [], 0.0
    for i, v in enumerate(x):
        if i % max(1, hold) == 0:
            last = round(v * q) / q
        out.append(last)
    return out


def echo(x, delay, fb, mix):
    """Feedback echo; the tail extends the clip by 4 delays."""
    d = int(delay * R)
    y = list(x) + [0.0] * (d * 4)
    for i in range(d, len(y)):
        y[i] += y[i - d] * fb
    return [(x[i] if i < len(x) else 0.0) + (y[i] - (x[i] if i < len(x) else 0.0)) * mix for i in range(len(y))]


def mix_into(buf, layer, at):
    start = int(at * R)
    if len(buf) < start + len(layer):
        buf.extend([0.0] * (start + len(layer) - len(buf)))
    for i, v in enumerate(layer):
        buf[start + i] += v


def render_layer(L, rng, buf, base=0.0):
    at = base + L.get("at", 0.0)
    if "notes" in L:
        step = L["step"]
        for k, note in enumerate(L["notes"]):
            sub = {kk: vv for kk, vv in L.items() if kk not in ("notes", "step", "ndur", "glide")}
            sub.update(at=0.0, dur=L.get("ndur", step), f=hz(note))
            if "glide" in L:
                sub["f1"] = hz(note) * L["glide"]
            render_layer(sub, rng, buf, at + k * step)
        return
    n = int(L["dur"] * R)
    kind = L["osc"]
    f0 = hz(L.get("f", 440))
    f1 = hz(L["f1"]) if "f1" in L else f0
    x = oscillator(kind, n, lambda u: f0 * (f1 / f0) ** u, L.get("duty", 0.5), L.get("vib"), rng)
    if "crush" in L:
        x = bitcrush(x, *L["crush"])
    if "lp" in L:
        x = one_pole(x, L["lp"], "lp")
    if "hp" in L:
        x = one_pole(x, L["hp"], "hp")
    env = adsr(n, *L.get("env", [0.003, L["dur"], 0.0, 0.0]))
    vol = L.get("vol", 1.0)
    mix_into(buf, [v * e * vol for v, e in zip(x, env)], at)


def master(buf, maxlen):
    buf = buf[:int(maxlen * R)]
    buf = one_pole(buf, 7500, "lp")
    buf = one_pole(buf, 30, "hp")
    n = len(buf)
    for i in range(min(n, int(0.003 * R))):
        buf[i] *= i / (0.003 * R)
    nf = min(n, int(0.015 * R))
    for i in range(nf):
        buf[n - 1 - i] *= i / nf
    # trim trailing silence (-60 dB)
    pk = max(map(abs, buf)) or 1.0
    while buf and abs(buf[-1]) < pk * 1e-3:
        buf.pop()
    pk = max(map(abs, buf)) or 1.0
    g = 10 ** (PEAK_DB / 20) / pk
    return [v * g for v in buf]


# ------------------------------------------------------------ recipes
def tone(osc, at, dur, f, f1=None, vol=1.0, env=None, **kw):
    d = {"osc": osc, "at": at, "dur": dur, "f": f, "vol": vol}
    if f1 is not None:
        d["f1"] = f1
    if env:
        d["env"] = env
    d.update(kw)
    return d


def noise(at, dur, vol=1.0, env=None, **kw):
    return tone("noise", at, dur, 440, None, vol, env, **kw)


RECIPES = {
 "sfx_shot_starter": {"layers": [
    tone("sq", 0, .20, 1500, 320, .8, [.002, .18, 0, .02], duty=.25),
    tone("tri", 0, .20, 750, 160, .4, [.002, .18, 0, .02]),
    tone("sin", 0, .09, 2600, 1900, .18, [.001, .08, 0, .01])]},
 "sfx_shot_spread": {"layers": [
    *[x for k in range(3) for x in (
        tone("sin", k * .075, .10, 450 + 40 * k, 950 + 60 * k, .8, [.004, .09, 0, .01]),
        noise(k * .075, .05, .22, [.002, .05, 0, 0], lp=[3000, 800]))]]},
 "sfx_shot_rapid": {"layers": [
    tone("sq", 0, .07, 1800, 650, .55, [.001, .065, 0, .005], duty=.125, lp=4500),
    noise(0, .035, .25, [.001, .03, 0, 0], lp=3200)]},
 "sfx_shot_enemy": {"layers": [
    tone("tri", 0, .26, 320, 170, .9, [.005, .25, 0, .01], vib=[24, 1.5]),
    tone("sq", 0, .22, 230, 110, .3, [.005, .2, 0, .01], lp=1500)]},
 "sfx_alert": {"layers": [
    {"osc": "sq", "notes": ["C6", "G6"], "step": .09, "ndur": .10, "env": [.002, .1, .2, .01], "vol": .5, "duty": .5, "at": 0},
    {"osc": "sin", "notes": ["C7", "G7"], "step": .09, "ndur": .30, "env": [.002, .3, 0, .02], "vol": .3, "at": 0}],
    "echo": [.11, .3, .35]},
 "sfx_powerdown_poof": {"layers": [
    tone("sq", 0, .38, 900, 110, .5, [.003, .37, 0, .01], duty=.5, lp=3000),
    noise(.22, .28, .55, [.01, .26, 0, .01], lp=[4000, 500]),
    {"osc": "sin", "notes": ["C7", "E7", "G7", "C8", "E7", "G7", "C8", "E8"], "step": .06, "ndur": .22,
     "env": [.002, .2, 0, .01], "vol": .22, "at": .3}],
    "echo": [.13, .35, .4]},
 "sfx_hit_enemy": {"layers": [
    tone("sin", 0, .12, 520, 230, .9, [.002, .11, 0, .01]),
    tone("tri", 0, .06, 950, 300, .5, [.001, .06, 0, .005]),
    noise(0, .02, .3, [.001, .02, 0, 0], lp=2200)]},
 "sfx_hero_hurt": {"layers": [
    tone("tri", 0, .32, 330, 120, .8, [.005, .31, 0, .01], vib=[14, 1.2]),
    tone("sin", 0, .10, 85, 60, .7, [.002, .1, 0, .005]),
    noise(0, .06, .35, [.001, .06, 0, 0], lp=800)]},
 "sfx_rescue_teleport": {"layers": [
    tone("sin", 0, 1.0, 300, 2400, .22, [.1, .9, 0, .05], vib=[9, .4]),
    {"osc": "tri", "notes": ["C5", "E5", "G5", "C6", "E6", "G6", "C7"], "step": .1, "ndur": .35,
     "env": [.005, .34, 0, .01], "vol": .3, "at": 0},
    tone("sin", 1.0, .5, 2093, None, .4, [.003, .5, 0, .02])],
    "echo": [.16, .4, .4]},
 "sfx_reload": {"layers": [
    noise(0, .02, .7, [.001, .02, 0, 0], hp=1500), tone("sq", 0, .025, 1200, 900, .3, [.001, .02, 0, .003]),
    noise(.25, .04, .8, [.001, .04, 0, 0], lp=3500), tone("tri", .25, .06, 320, 180, .5, [.001, .06, 0, .003]),
    tone("sin", .48, .28, 3136, None, .4, [.002, .27, 0, .01]), tone("sin", .48, .22, 4186, None, .12, [.002, .2, 0, .01])]},
 "sfx_empty_click": {"layers": [
    noise(0, .012, .6, [.001, .012, 0, 0], hp=1200), tone("sq", 0, .02, 650, 450, .35, [.001, .02, 0, .002]),
    tone("tri", .01, .05, 420, 200, .3, [.001, .05, 0, .005])]},
 "sfx_pickup_ammo": {"layers": [
    tone("sq", 0, .07, "B5", None, .5, [.001, .06, .4, .005]),
    tone("sq", .07, .32, "E6", None, .5, [.001, .3, 0, .01]),
    noise(0, .03, .2, [.001, .03, 0, 0], hp=3000)]},
 "sfx_pickup_heal": {"layers": [
    {"osc": "sin", "notes": ["C5", "E5", "G5", "C6"], "step": .09, "ndur": .5, "env": [.005, .5, 0, .02], "vol": .4, "at": 0},
    {"osc": "tri", "notes": ["C6", "E6", "G6", "C7"], "step": .09, "ndur": .4, "env": [.005, .4, 0, .02], "vol": .12, "at": 0}],
    "echo": [.14, .4, .4]},
 "sfx_pickup_item": {"layers": [
    {"osc": "sq", "notes": ["C6", "G6", "C7"], "step": .08, "ndur": .22, "env": [.002, .2, 0, .01], "vol": .4, "duty": .25, "at": 0},
    {"osc": "sin", "notes": ["C6", "G6", "C7"], "step": .08, "ndur": .3, "env": [.002, .3, 0, .01], "vol": .3, "at": 0}]},
 "sfx_pickup_bolt": {"layers": [
    tone("sin", 0, .2, 2637, None, .6, [.001, .19, 0, .005]), tone("sin", 0, .12, 4190, None, .3, [.001, .11, 0, .005]),
    noise(0, .006, .2, [.001, .005, 0, 0], hp=5000)]},
 "sfx_button_press": {"layers": [
    tone("tri", 0, .12, 190, 90, .9, [.002, .11, 0, .005]), noise(0, .04, .4, [.001, .04, 0, 0], lp=1400),
    tone("sq", .12, .12, 880, None, .3, [.002, .12, .5, .02], lp=3000)]},
 "sfx_lever_pull": {"layers": [
    noise(0, .03, .5, [.001, .03, 0, 0], lp=2800), tone("tri", 0, .09, 230, 110, .6, [.001, .08, 0, .005]),
    noise(.25, .05, .9, [.001, .05, 0, 0], lp=1900), tone("tri", .25, .16, 150, 65, .9, [.001, .15, 0, .005]),
    tone("sin", .3, .36, 300, 620, .25, [.005, .35, 0, .01], vib=[20, 2])]},
 "sfx_plate_on": {"layers": [
    tone("tri", 0, .13, 135, 80, .9, [.002, .12, 0, .005]), noise(0, .04, .3, [.001, .04, 0, 0], lp=800),
    {"osc": "sin", "notes": ["E5", "B5"], "step": .08, "ndur": .26, "env": [.003, .25, 0, .01], "vol": .5, "at": .12}]},
 "sfx_machine_on": {"layers": [
    tone("saw", 0, 1.35, 60, 240, .35, [.3, .8, .4, .1], vib=[8, .5], lp=[500, 2500]),
    tone("sq", 0, 1.35, 120, 480, .2, [.3, .8, .4, .1], duty=.25, lp=2000),
    {"osc": "sq", "notes": ["A5", "C6", "E6"], "step": .1, "ndur": .08, "env": [.002, .08, .3, .01], "vol": .3, "at": 1.1},
    tone("sin", 1.4, .35, 120, None, .3, [.02, .33, 0, .02])]},
 "sfx_door_open": {"layers": [
    noise(0, .8, .4, [.15, .6, 0, .05], lp=[600, 4000], hp=300),
    noise(.5, .7, .3, [.05, .6, 0, .05], lp=[2500, 500]),
    {"osc": "sin", "notes": ["G5", "D6"], "step": .12, "ndur": .5, "env": [.003, .5, 0, .02], "vol": .3, "at": .9}]},
 "sfx_gate_unlocked": {"layers": [
    tone("tri", 0, .12, 200, 100, .9, [.001, .11, 0, .005]), noise(0, .03, .5, [.001, .03, 0, 0], lp=1600),
    tone("sq", .12, .012, 2000, None, .3, [.001, .01, 0, 0]),
    {"osc": "sq", "notes": ["C5", "E5", "G5", "C6", "E6", "G6"], "step": .07, "ndur": .22, "env": [.002, .2, 0, .01],
     "vol": .3, "duty": .25, "at": .2}],
    "echo": [.12, .3, .3]},
 "sfx_checkpoint": {"layers": [
    {"osc": "sin", "notes": ["G5", "C6", "E6"], "step": .14, "ndur": .6, "env": [.004, .6, 0, .03], "vol": .45, "at": 0},
    {"osc": "tri", "notes": ["G5", "C6", "E6"], "step": .14, "ndur": .4, "env": [.004, .4, 0, .02], "vol": .2, "at": 0},
    tone("sin", .4, .5, "C7", None, .12, [.004, .5, 0, .02])],
    "echo": [.15, .35, .4]},
 "sfx_crate_break": {"layers": [
    noise(0, .14, .7, [.001, .13, 0, .005], lp=[3000, 800]), tone("tri", 0, .09, 300, 120, .5, [.001, .09, 0, .005]),
    "DEBRIS"]},
 "sfx_ui_tap": {"layers": [
    tone("sin", 0, .07, 1200, 800, .8, [.001, .065, 0, .005]), tone("tri", 0, .02, 2000, None, .3, [.001, .02, 0, 0])]},
 "sfx_ui_back": {"layers": [
    {"osc": "tri", "notes": [800, 560], "step": .06, "ndur": .09, "env": [.002, .09, 0, .01], "vol": .8, "at": 0},
    {"osc": "sin", "notes": [1600, 1120], "step": .06, "ndur": .06, "env": [.002, .06, 0, .01], "vol": .2, "at": 0}]},
 "sfx_level_start": {"layers": [
    tone("saw", 0, .5, 400, 2000, .2, [.05, .4, 0, .05], lp=3500),
    {"osc": "sq", "notes": ["C5", "E5", "G5", "C6"], "step": .09, "ndur": .13, "env": [.002, .12, .3, .01], "vol": .3, "duty": .25, "at": .2},
    *[tone("sq", .6, .8, n, None, .16, [.003, .8, 0, .02], duty=.5, lp=3000) for n in ("C6", "E6", "G6")]],
    "echo": [.14, .3, .3]},
 "sfx_pixel_beep_1": {"layers": [
    {"osc": "sq", "notes": [1200, 1500, 1800, 2300], "step": .09, "ndur": .07, "glide": 1.25, "env": [.002, .07, .3, .01],
     "vol": .5, "duty": .5, "lp": 5000, "at": 0},
    {"osc": "sin", "notes": [1200, 1500, 1800, 2300], "step": .09, "ndur": .08, "glide": 1.25, "vol": .4, "vib": [30, .5],
     "env": [.002, .08, .3, .01], "at": 0}]},
 "sfx_pixel_beep_2": {"layers": [
    tone("sq", 0, .10, 1800, 1900, .5, [.002, .1, .3, .01], lp=5000), tone("sq", .12, .13, 900, 1000, .5, [.002, .13, .3, .01], lp=5000),
    tone("sq", .27, .16, 1600, 2300, .5, [.002, .16, .3, .02], lp=5000),
    tone("sin", .27, .16, 1600, 2300, .3, [.002, .16, .3, .02], vib=[25, .6])]},
 "sfx_pixel_beep_3": {"layers": [
    {"osc": "sq", "notes": [2000, 2600] * 4, "step": .035, "ndur": .03, "env": [.001, .03, .2, .003], "vol": .45, "lp": 5000, "at": 0},
    tone("sq", .3, .13, 2200, 3200, .45, [.002, .13, .3, .02], lp=5000),
    tone("sin", .3, .13, 2200, 3200, .3, [.002, .13, .3, .02], vib=[28, .5])]},
}


def synth(sid, maxlen):
    rng = random.Random(zlib.crc32(sid.encode()))
    rec = RECIPES[sid]
    buf = []
    for L in rec["layers"]:
        if L == "DEBRIS":  # seeded wooden clatter: short filtered square blips at random times
            for k in range(7):
                at = .08 + .05 * k + rng.uniform(0, .03)
                f = rng.uniform(500, 1400)
                render_layer(tone("sq", at, .025, f, f * .6, .25 * (1 - k / 9), [.001, .024, 0, 0], duty=.25, lp=2500), rng, buf)
                render_layer(noise(at, .02, .18, [.001, .02, 0, 0], lp=2000), rng, buf)
        else:
            render_layer(L, rng, buf)
    if "echo" in rec:
        buf = echo(buf, *rec["echo"])
    return master(buf, maxlen)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("select", nargs="*")
    ap.add_argument("--out", default=ac.RAW)
    args = ap.parse_args()
    items = {i["id"]: i for i in ac.parse_prompts() if i["group"] == "sfx"}
    missing = set(items) - set(RECIPES)
    if missing:
        sys.exit(f"no recipe for: {sorted(missing)}")
    ids = [i for i in items if not args.select or any(
        fnmatch.fnmatch(i, p) or fnmatch.fnmatch(i, "sfx_" + p) for p in args.select)]
    os.makedirs(args.out, exist_ok=True)
    for sid in ids:
        data = synth(sid, items[sid]["maxlen"])
        ac.write_wav(os.path.join(args.out, items[sid]["file"] + ".wav"), ac.Audio([data]))
        print(f"{sid:<22} {len(data) / R:5.2f} s (max {items[sid]['maxlen']:g})")


if __name__ == "__main__":
    main()
