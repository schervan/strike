#!/usr/bin/env python3
"""Generate cute placeholder sprites for every Strike asset/frame.

Usage (from repo root):  python3 -I tools/make_placeholders.py [--out DIR] [--only ATLAS|GROUP_PREFIX]

Writes @2x PNGs to Strike/Resources/Atlases/<atlas>.atlas/<name>@2x.png using the
manifest in tools/asset_manifest.py. Uses Pillow only to save if installed;
otherwise a pure-python PNG writer (zlib/struct). Existing files are overwritten.
"""
import argparse, importlib.util, math, os, struct, sys, zlib

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
_spec = importlib.util.spec_from_file_location("asset_manifest", os.path.join(HERE, "asset_manifest.py"))
M = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(M)

# ---------- palette ----------
def hx(s):
    s = s.lstrip("#")
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4))

OUT = hx("2B2140"); WHITE = hx("FFFFFF"); SKIN = hx("FFD9B8"); ORANGE = hx("FF8A3D")
BLUE = hx("3D8BFF"); CYAN = hx("3DE3D0"); TEAL = hx("17A6A0"); RED = hx("FF3B5C")
MAGENTA = hx("D61F8F"); YELLOW = hx("FFD93D"); GREEN = hx("5FE08A"); PURPLE = hx("B05CFF")
PANEL = hx("2E2A55"); PANEL2 = hx("4A4585")
THEMES = {  # floorA, floorB, wall, wallTop, accent
    "l1": ("B8C4D6", "A6B3C8", "5B6B8C", "7E90B5", "FFB347"),
    "l2": ("8C8F99", "7A7D88", "4A4E5C", "6B7080", "FFC21A"),
    "l3": ("BFE3A0", "A8D488", "3C8F5A", "5FBF7A", "E36BD8"),
    "l4": ("2B3A67", "243158", "151C3A", "3A4CA0", "39F5FF"),
    "l5": ("3A1840", "2F1236", "1B0A24", "6B1E5E", "FF2E7E"),
}

# ---------- canvas ----------
def clamp(v, lo=0.0, hi=1.0):
    return lo if v < lo else hi if v > hi else v

class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.buf = bytearray(w * h * 4)

    def px(self, x, y, c, a):
        if a <= 0:
            return
        i = (y * self.w + x) * 4
        b = self.buf
        da = b[i + 3] / 255.0
        oa = a + da * (1 - a)
        for k in range(3):
            b[i + k] = int(round((c[k] * a + b[i + k] * da * (1 - a)) / oa))
        b[i + 3] = int(round(oa * 255))

    def fill(self, x0, y0, x1, y1, sdf, c, alpha=1.0):
        for y in range(max(0, int(y0)), min(self.h, int(y1) + 1)):
            for x in range(max(0, int(x0)), min(self.w, int(x1) + 1)):
                a = clamp(0.5 - sdf(x + 0.5, y + 0.5)) * alpha
                if a > 0:
                    self.px(x, y, c, a)

    def ell(self, cx, cy, rx, ry, c, ol=None, ow=0, alpha=1.0):
        rx, ry = max(rx, 0.5), max(ry, 0.5)
        def mk(rx, ry):
            m = min(rx, ry)
            return lambda x, y: (math.hypot((x - cx) / rx, (y - cy) / ry) - 1) * m
        if ol and ow:
            e = mk(rx + ow, ry + ow)
            self.fill(cx - rx - ow - 1, cy - ry - ow - 1, cx + rx + ow + 1, cy + ry + ow + 1, e, ol, alpha)
        e = mk(rx, ry)
        self.fill(cx - rx - 1, cy - ry - 1, cx + rx + 1, cy + ry + 1, e, c, alpha)

    def rr(self, cx, cy, hw, hh, rad, c, ol=None, ow=0, alpha=1.0):
        def mk(hw, hh, r):
            def f(x, y):
                qx, qy = abs(x - cx) - hw + r, abs(y - cy) - hh + r
                return math.hypot(max(qx, 0), max(qy, 0)) + min(max(qx, qy), 0) - r
            return f
        if ol and ow:
            self.fill(cx - hw - ow - 1, cy - hh - ow - 1, cx + hw + ow + 1, cy + hh + ow + 1,
                      mk(hw + ow, hh + ow, rad + ow), ol, alpha)
        self.fill(cx - hw - 1, cy - hh - 1, cx + hw + 1, cy + hh + 1, mk(hw, hh, rad), c, alpha)

    def cap(self, x0, y0, x1, y1, r, c, ol=None, ow=0):
        def mk(r):
            def f(x, y):
                dx, dy = x1 - x0, y1 - y0
                t = clamp(((x - x0) * dx + (y - y0) * dy) / (dx * dx + dy * dy or 1))
                return math.hypot(x - x0 - t * dx, y - y0 - t * dy) - r
            return f
        bb = (min(x0, x1) - r - ow - 1, min(y0, y1) - r - ow - 1, max(x0, x1) + r + ow + 1, max(y0, y1) + r + ow + 1)
        if ol and ow:
            self.fill(*bb, mk(r + ow), ol)
        self.fill(*bb, mk(r), c)

    def star(self, cx, cy, r, c, thick=0.28, alpha=1.0):
        """4-point sparkle."""
        self.ell(cx, cy, r, r * thick, c, alpha=alpha)
        self.ell(cx, cy, r * thick, r, c, alpha=alpha)
        self.ell(cx, cy, r * 0.35, r * 0.35, c, alpha=alpha)

    def tint(self, c, amt):
        b = self.buf
        for i in range(0, len(b), 4):
            if b[i + 3]:
                for k in range(3):
                    b[i + k] = int(b[i + k] + (c[k] - b[i + k]) * amt)

    def png(self):
        raw = b"".join(b"\x00" + bytes(self.buf[y * self.w * 4:(y + 1) * self.w * 4]) for y in range(self.h))
        def chunk(t, d):
            return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)
        return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", self.w, self.h, 8, 6, 0, 0, 0))
                + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))

    def save(self, path):
        try:
            from PIL import Image
            Image.frombytes("RGBA", (self.w, self.h), bytes(self.buf)).save(path)
        except ImportError:
            with open(path, "wb") as f:
                f.write(self.png())

# ---------- character drawing ----------
def eye(cv, x, y, r, pupil=OUT, look=0.0):
    cv.ell(x, y, r, r * 1.1, WHITE, OUT, max(1, r * 0.18))
    cv.ell(x + look * r * 0.3, y, r * 0.62, r * 0.75, pupil)
    cv.ell(x + look * r * 0.3 - r * 0.2, y - r * 0.3, r * 0.22, r * 0.22, WHITE)

def pose(anim, f, n, W, H):
    """returns (dx, dy, squash, whiten, flash)"""
    t = f / float(n)
    if anim == "idle":
        return 0, -math.sin(2 * math.pi * t) * 0.02 * H, math.sin(2 * math.pi * t) * 0.02, 0, 0
    if anim == "walk":
        s = math.sin(2 * math.pi * t * 1.0)
        return 0, -abs(s) * 0.05 * H, -abs(s) * 0.04 + 0.02, 0, 0
    if anim == "talk":
        return 0, -math.sin(2 * math.pi * t) * 0.03 * H, (0.05 if f % 2 == 0 else -0.03), 0, 0
    if anim in ("shoot",):
        return (-0.04 * W if f == 1 else 0), 0, 0.0, 0, (1 if f == 1 else 0)
    if anim == "charge":
        return 0, 0, -0.05 * f, 0, 0
    if anim == "hit":
        return (-0.03 * W if f == 0 else 0.02 * W), 0, 0.0, (0.85 if f == 0 else 0.4), 0
    if anim == "defeat":
        return 0, 0.02 * H * f, 0.04 * f, min(0.9, 0.15 * f), 0
    return 0, 0, 0, 0, 0

def draw_char(cv, style, anim, f, n):
    W, H = cv.w, cv.h
    dx, dy, sq, whiten, flash = pose(anim, f, n, W, H)
    ow = max(2.0, W / 40.0)          # outline width in px (~1.5-2pt feel)
    cx = W / 2 + dx
    gy = H * 0.9                      # ground line
    # soft shadow
    cv.ell(W / 2, gy, W * 0.3, H * 0.06, OUT, alpha=0.28)
    sx, sy = 1 + sq, 1 - sq
    def E(x, y, rx, ry, c, o=True):
        cv.ell(cx + (x - 0.5) * W * sx, gy - (0.9 - y) * H * sy * 0 + (y - 0.9) * H * sy + dy, rx * W * sx, ry * H * sy, c, OUT if o else None, ow)
    def R(x, y, hw, hh, rad, c, o=True):
        cv.rr(cx + (x - 0.5) * W * sx, gy + (y - 0.9) * H * sy + dy, hw * W * sx, hh * H * sy, rad * W, c, OUT if o else None, ow)
    def EYE(x, y, r):
        eye(cv, cx + (x - 0.5) * W * sx, gy + (y - 0.9) * H * sy + dy, r * W * sx, look=1)
    walk = anim == "walk" and f % 2 == 0
    if style == "hero":
        R(0.5, 0.78, 0.15, 0.10, 0.06, BLUE)                       # jacket
        R(0.40 + (0.02 if walk else 0), 0.89, 0.05, 0.035, 0.02, hx("2D5FB8"))  # feet
        R(0.60 - (0.02 if walk else 0), 0.89, 0.05, 0.035, 0.02, hx("2D5FB8"))
        R(0.72, 0.64, 0.14, 0.05, 0.03, ORANGE)                    # toy blaster
        E(0.58, 0.64, 0.045, 0.045, WHITE)                          # glove-ish
        E(0.5, 0.40, 0.26, 0.24, SKIN)                              # head
        E(0.5, 0.25, 0.27, 0.15, hx("7A4A2B"))                      # hair
        E(0.28, 0.32, 0.07, 0.07, hx("7A4A2B"))
        R(0.5, 0.21, 0.07, 0.025, 0.02, ORANGE)                     # headband
        EYE(0.62, 0.42, 0.07); EYE(0.42, 0.42, 0.065)
        if flash:
            E(0.93, 0.64, 0.07, 0.07, YELLOW)
    elif style == "pixel":
        cv.ell(cx, H * 0.5 + dy, W * 0.46, H * 0.46, CYAN, None, 0, alpha=0.25)   # glow
        E(0.5, 0.18, 0.12, 0.04, hx("BFFFF7"))                      # propeller
        E(0.5, 0.55, 0.36, 0.34, CYAN)
        R(0.5, 0.57, 0.26, 0.19, 0.12, hx("12304A"))                # screen
        if anim == "talk" and f % 2 == 0:
            E(0.5, 0.68, 0.06, 0.04, CYAN, o=False)
        else:
            cv.rr(cx, H * 0.67 + dy, W * 0.07, H * 0.012, 2, CYAN)
        E(0.40, 0.55, 0.045, 0.06, CYAN, o=False); E(0.60, 0.55, 0.045, 0.06, CYAN, o=False)
    elif style == "boltbot":
        R(0.5, 0.80, 0.22, 0.09, 0.04, hx("8FA3C8"))                # wheel base
        E(0.34, 0.88, 0.07, 0.06, hx("444B6B")); E(0.66, 0.88, 0.07, 0.06, hx("444B6B"))
        R(0.5, 0.56, 0.25, 0.22, 0.08, hx("A9BCE0"))                # body
        R(0.5, 0.52, 0.17, 0.09, 0.05, hx("2A2F4F"))                # visor
        E(0.5, 0.52, 0.06, 0.06, RED, o=False)
        R(0.5, 0.28, 0.03, 0.07, 0.01, hx("8FA3C8")); E(0.5, 0.20, 0.05, 0.05, ORANGE)   # antenna
        E(0.22, 0.58, 0.05, 0.05, ORANGE); E(0.78, 0.58, 0.05, 0.05, ORANGE)               # bolts
    elif style == "laserdrone":
        R(0.18, 0.46, 0.10, 0.04, 0.02, hx("7C5CD6")); R(0.82, 0.46, 0.10, 0.04, 0.02, hx("7C5CD6"))
        E(0.5, 0.46, 0.30, 0.28, hx("9B7BFF"))
        E(0.5, 0.46, 0.17, 0.17, WHITE)
        E(0.5, 0.46, 0.10, 0.10, RED, o=False)
        cv.ell(cx + W * 0.04, H * 0.42 + dy, W * 0.025, W * 0.025, WHITE)
        R(0.5, 0.78, 0.07, 0.04, 0.02, hx("5B3FB0"))
        if flash:
            E(0.9, 0.46, 0.06, 0.06, YELLOW)
    elif style in ("slimemutant", "slimemutant_small"):
        E(0.5, 0.72, 0.38, 0.20, hx("6FE06A"))
        E(0.5, 0.60, 0.30, 0.26, hx("8CF07F"))
        E(0.62, 0.50, 0.05, 0.03, WHITE, o=False)
        EYE(0.40, 0.60, 0.075); EYE(0.60, 0.60, 0.075)
        E(0.5, 0.74, 0.06, 0.03, hx("2F7F3A"), o=False)
        E(0.25, 0.46, 0.04, 0.05, hx("6FE06A"))
    elif style == "shieldandroid":
        R(0.5, 0.80, 0.14, 0.08, 0.04, hx("9AA4C0"))
        R(0.5, 0.52, 0.19, 0.24, 0.07, hx("C9D2EA"))
        E(0.5, 0.26, 0.17, 0.15, hx("C9D2EA"))
        R(0.5, 0.27, 0.12, 0.05, 0.03, hx("2A2F4F")); E(0.55, 0.27, 0.035, 0.035, RED, o=False)
        R(0.76, 0.56, 0.12, 0.27, 0.06, TEAL)                      # shield
        R(0.76, 0.56, 0.06, 0.20, 0.04, CYAN, o=False)
        if flash:
            E(0.95, 0.5, 0.05, 0.05, YELLOW)
    elif style == "sporeplant":
        R(0.5, 0.80, 0.07, 0.16, 0.03, hx("3C9F5A"))
        E(0.5, 0.90, 0.22, 0.05, hx("2F7F46"))
        E(0.30, 0.74, 0.14, 0.05, hx("5FBF7A")); E(0.70, 0.74, 0.14, 0.05, hx("5FBF7A"))
        E(0.5, 0.40, 0.30, 0.26, hx("E36BD8"))
        for (px_, py_) in ((0.36, 0.28), (0.66, 0.30), (0.62, 0.52)):
            E(px_, py_, 0.05, 0.05, hx("FFB3F2"), o=False)
        EYE(0.42, 0.44, 0.07); EYE(0.58, 0.44, 0.07)
        if flash:
            for k in range(3):
                E(0.85 + k * 0.04, 0.35 + k * 0.08, 0.03, 0.03, hx("FFB3F2"))
    elif style == "megamech":
        R(0.30, 0.86, 0.10, 0.07, 0.03, hx("5A5F85")); R(0.70, 0.86, 0.10, 0.07, 0.03, hx("5A5F85"))   # feet
        R(0.5, 0.62, 0.27, 0.22, 0.07, hx("7A82B8"))               # torso
        R(0.14, 0.60, 0.09, 0.17, 0.05, hx("5A5F85")); R(0.86, 0.60, 0.09, 0.17, 0.05, hx("5A5F85"))   # arms
        E(0.14, 0.80, 0.08, 0.07, ORANGE); E(0.86, 0.80, 0.08, 0.07, ORANGE)                            # fists
        R(0.5, 0.64, 0.12, 0.10, 0.04, MAGENTA)                    # core
        E(0.5, 0.64, 0.05, 0.05, hx("FFB3D9"), o=False)
        R(0.5, 0.30, 0.20, 0.15, 0.06, hx("9AA2D6"))               # head
        R(0.5, 0.30, 0.15, 0.07, 0.04, hx("2A1030"))
        E(0.5, 0.30, 0.07, 0.05, RED, o=False)
        R(0.30, 0.14, 0.02, 0.05, 0.01, MAGENTA); R(0.70, 0.14, 0.02, 0.05, 0.01, MAGENTA)  # horns
        if anim == "charge":
            E(0.5, 0.64, 0.05 + 0.04 * f, 0.05 + 0.04 * f, YELLOW, o=False)
    else:
        E(0.5, 0.5, 0.3, 0.3, hx("CCCCCC"))
    if whiten:
        cv.tint(WHITE, whiten)

# ---------- other sprites ----------
def draw_tile(cv, theme, kind, v):
    fa, fb, wl, wt, ac = [hx(x) for x in THEMES[theme]]
    W = cv.w
    if kind == "floor":
        base = fa if v % 2 == 0 else fb
        cv.fill(0, 0, W, W, lambda x, y: -1, base)
        edge = tuple(int(c * 0.88) for c in base)
        cv.fill(0, 0, W, W, lambda x, y: min(x, y, W - x, W - y) - 2.0, edge, 0.0)  # (no-op keeps tiling clean)
        cv.rr(W / 2, W / 2, W / 2 - 5, W / 2 - 5, 8, tuple(min(255, int(c * 1.05)) for c in base), edge, 2)
        rnd = (v + 1) * 37
        for k in range(2 + v):
            cv.ell(14 + (rnd * (k + 3) * 11) % (W - 28), 14 + (rnd * (k + 5) * 7) % (W - 28), 3, 3, edge)
        if v == 2:
            cv.rr(W / 2, W / 2, 10, 3, 1.5, ac)
    else:
        cv.fill(0, 0, W, W, lambda x, y: -1, wl)
        cv.rr(W / 2, W / 2 - 4, W / 2 - 4, W / 2 - 12, 10, wt, tuple(int(c * 0.7) for c in wl), 3)   # lit top face
        cv.rr(W / 2, W - 14, W / 2 - 4, 7, 4, tuple(int(c * 0.8) for c in wl))                        # front face
        cv.rr(W / 2, 30, 20 + 6 * v, 3, 1.5, ac)

def draw_item(cv, s):
    W = cv.w; c = W / 2; ow = max(2, W / 16.0)
    name = s.split("_", 1)[1]
    if s.startswith("proj_"):
        col = {"proj_starter": ORANGE, "proj_spread": PURPLE, "proj_rapid": YELLOW, "proj_enemy": RED}[s]
        cv.ell(c, c, W * 0.46, W * 0.46, col, None, 0, 0.3)
        cv.ell(c, c, W * 0.30, W * 0.30, col, OUT, 2)
        cv.ell(c - W * 0.08, c - W * 0.08, W * 0.08, W * 0.08, WHITE)
        return
    cv.ell(c, c + W * 0.42, W * 0.3, W * 0.05, OUT, alpha=0.25)
    if name == "healpack":
        cv.rr(c, c, W * .36, W * .30, W * .10, WHITE, OUT, ow)
        cv.rr(c, c, W * .20, W * .06, 2, GREEN); cv.rr(c, c, W * .06, W * .20, 2, GREEN)
    elif name == "food_apple":
        cv.ell(c, c + 3, W * .32, W * .30, RED, OUT, ow); cv.ell(c - W * .12, c - 2, W * .06, W * .08, WHITE)
        cv.rr(c, c - W * .32, 2, W * .08, 1, hx("7A4A2B")); cv.ell(c + W * .1, c - W * .3, W * .1, W * .05, GREEN, OUT, 2)
    elif name == "food_onigiri":
        cv.rr(c, c - 2, W * .32, W * .28, W * .14, WHITE, OUT, ow); cv.rr(c, c + W * .2, W * .2, W * .12, 3, hx("1F3D2E"), OUT, 2)
        cv.ell(c, c - W * .08, 2.5, 2.5, OUT); cv.ell(c - 6, c - W * .1, 2, 2, OUT); cv.ell(c + 6, c - W * .1, 2, 2, OUT)
    elif name == "food_cookie":
        cv.ell(c, c, W * .34, W * .34, hx("E0A458"), OUT, ow)
        for dx, dy in ((-8, -6), (7, -9), (2, 6), (-6, 9), (11, 3)):
            cv.ell(c + dx * W / 64 * 2, c + dy * W / 64 * 2, W * .05, W * .05, hx("5A3A22"))
    elif name.startswith("ammo_"):
        col = {"ammo_starter": ORANGE, "ammo_spread": PURPLE, "ammo_rapid": YELLOW}[name]
        cv.rr(c, c, W * .34, W * .30, W * .08, col, OUT, ow)
        cv.rr(c, c - W * .12, W * .34, W * .04, 1, WHITE, alpha=0.6)
        for k in (-1, 0, 1):
            cv.rr(c + k * W * .15, c + W * .06, W * .045, W * .13, W * .04, WHITE, OUT, 1)
    elif name == "fuse":
        cv.rr(c, c, W * .20, W * .32, W * .06, hx("FFE9A8"), OUT, ow); cv.rr(c, c - W * .28, W * .26, W * .05, 2, hx("9AA4C0"), OUT, 2)
        cv.rr(c, c + W * .28, W * .26, W * .05, 2, hx("9AA4C0"), OUT, 2); cv.rr(c, c, W * .03, W * .22, 1, ORANGE)
    elif name == "battery":
        cv.rr(c, c + 2, W * .26, W * .32, W * .08, GREEN, OUT, ow); cv.rr(c, c - W * .34, W * .09, W * .04, 1, hx("9AA4C0"), OUT, 2)
        cv.rr(c, c + 2, W * .12, W * .04, 1, WHITE); cv.rr(c, c + 2, W * .04, W * .12, 1, WHITE)
    elif name == "keycard":
        cv.rr(c, c, W * .38, W * .26, W * .06, BLUE, OUT, ow); cv.rr(c - W * .2, c - W * .04, W * .09, W * .08, 2, YELLOW, OUT, 1)
        cv.rr(c + W * .08, c + W * .14, W * .22, W * .03, 1, WHITE)
    elif name == "bolt":
        cv.ell(c, c, W * .30, W * .30, hx("C9D2EA"), OUT, ow)
        for k in range(6):
            a = k * math.pi / 3
            cv.ell(c + math.cos(a) * W * .28, c + math.sin(a) * W * .28, W * .07, W * .07, hx("C9D2EA"), OUT, 2)
        cv.ell(c, c, W * .11, W * .11, hx("12304A"), OUT, 2); cv.ell(c - W * .08, c - W * .08, W * .04, W * .04, WHITE)
    elif name == "datachip":
        cv.rr(c, c, W * .30, W * .34, W * .06, CYAN, OUT, ow)
        for k in (-1, 0, 1):
            cv.rr(c + k * W * .11, c + W * .26, W * .04, W * .07, 1, YELLOW, OUT, 1)
        cv.ell(c, c - W * .04, W * .10, W * .10, hx("12304A"), OUT, 2); cv.ell(c, c - W * .04, W * .04, W * .04, WHITE)
    elif name.startswith("blaster_"):
        col = {"blaster_starter": ORANGE, "blaster_spread": PURPLE, "blaster_rapid": YELLOW}[name]
        cv.rr(c - W * .04, c + W * .04, W * .30, W * .14, W * .06, col, OUT, ow)
        cv.rr(c - W * .16, c + W * .2, W * .08, W * .12, W * .03, col, OUT, 2)
        cv.rr(c + W * .3, c + W * .04, W * .10, W * .08, W * .03, WHITE, OUT, 2)
        cv.ell(c + W * .42, c + W * .04, W * .06, W * .06, CYAN, None, 0, 0.8)
    elif name == "energycore":
        cv.ell(c, c, W * .48, W * .48, MAGENTA, None, 0, 0.25)
        cv.ell(c, c, W * .34, W * .34, CYAN, OUT, ow); cv.ell(c, c, W * .18, W * .18, WHITE)
        cv.ell(c - W * .1, c - W * .1, W * .05, W * .05, WHITE)
    else:
        cv.ell(c, c, W * .3, W * .3, hx("CCCCCC"), OUT, ow)

def draw_puzzle(cv, s, idx=0, n=1):
    W, H = cv.w, cv.h; c = W / 2
    _, name, st = s.split("_", 2)
    on = st in ("on", "open")
    if name == "button":
        cv.rr(c, c, W * .34, W * .34, W * .10, hx("8FA3C8"), OUT, 3)
        cv.ell(c, c + (3 if on else 0), W * .22, W * .22, GREEN if on else RED, OUT, 3)
        cv.ell(c - 6, c - 6, 4, 4, WHITE, alpha=0.7)
    elif name == "lever":
        cv.rr(c, c + W * .22, W * .30, W * .12, W * .05, hx("8FA3C8"), OUT, 3)
        tx = c + (W * .22 if on else -W * .22)
        cv.cap(c, c + W * .2, tx, c - W * .22, 4, hx("C9D2EA"), OUT, 3)
        cv.ell(tx, c - W * .24, W * .09, W * .09, GREEN if on else RED, OUT, 3)
    elif name == "pressureplate":
        cv.rr(c, c, W * .36, W * .36, W * .08, hx("6F7690"), OUT, 3)
        inner = W * .27 if not on else W * .25
        cv.rr(c, c, inner, inner, W * .06, GREEN if on else hx("FFD93D"), OUT, 2)
        cv.rr(c, c, W * .1, W * .03, 1, WHITE, alpha=0.8)
    elif name == "machine":
        cv.rr(c, c + 6, W * .42, W * .40, W * .08, hx("7A82B8"), OUT, 4)
        cv.rr(c, c - W * .12, W * .30, W * .17, W * .05, hx("12304A"), OUT, 3)
        col = GREEN if on else RED
        for k in (-1, 0, 1):
            cv.ell(c + k * W * .13, c + W * .2, W * .04, W * .04, col, OUT, 2)
        cv.ell(c, c - W * .12, W * .07, W * .07, CYAN if on else hx("2A5A6A"))
        cv.rr(c, c - W * .45, W * .12, W * .04, 2, hx("9AA4C0"), OUT, 3)
    elif name == "crate":
        if st == "whole":
            cv.rr(c, c, W * .34, W * .34, W * .05, hx("D9A15B"), OUT, 3)
            cv.rr(c, c, W * .24, W * .24, W * .03, hx("E8B878"), OUT, 2)
            cv.rr(c, c, W * .30, W * .04, 1, hx("B07A3C")); cv.rr(c, c, W * .04, W * .30, 1, hx("B07A3C"))
        else:
            for dx, dy, r in ((-.16, -.1, .12), (.14, -.12, .1), (-.08, .16, .11), (.18, .14, .09)):
                cv.rr(c + W * dx, c + W * dy, W * r, W * r * .8, 3, hx("D9A15B"), OUT, 2)
    elif name == "checkpoint" or name == "exitpad":
        col = GREEN if on else (RED if name == "exitpad" else hx("8FA3C8"))
        cv.ell(c, c, W * .40, W * .40, hx("3A3F66"), OUT, 3)
        cv.ell(c, c, W * .30, W * .30, col, OUT, 2)
        if name == "exitpad":
            cv.rr(c, c, W * .16, W * .05, 2, WHITE); cv.rr(c + W * .08, c, W * .06, W * .06, 2, WHITE)
        else:
            cv.ell(c, c, W * .12, W * .12, WHITE if on else hx("C9D2EA"), OUT, 2)
    elif name == "door":
        if st == "closed" or st == "opening":
            pass
        cv.rr(c, c, W * .48, W * .48, W * .06, hx("3A3F66"), OUT, 3)           # frame
        gap = {"closed": 0.0, "open": 1.0}.get(st, 0.0)
        if st == "opening":
            gap = (idx + 1) / float(n + 1)
        half = W * .22 * (1 - gap)
        cv.rr(c, c, W * .36, W * .36, W * .04, hx("12102A"))                   # opening
        if half > 1:
            cv.rr(c - W * .18 * (1 - gap) - W * .0, c, max(half / 1.0, 1) * .5 + W * .0, W * .34, 3, hx("9AA4C0"), OUT, 2)
            cv.rr(c + W * .18 * (1 - gap), c, max(half / 1.0, 1) * .5, W * .34, 3, hx("9AA4C0"), OUT, 2)
        if st != "open":
            cv.ell(c, c, W * .06, W * .06, RED, OUT, 2)

def draw_fx(cv, name, f, n):
    W = cv.w; c = W / 2; t = (f + 1) / float(n)
    if name == "hitflash":
        r = W * (0.18 + 0.28 * t)
        cv.star(c, c, r * 1.4, WHITE, 0.3, 1 - 0.3 * f)
        cv.ell(c, c, r * 0.55, r * 0.55, WHITE, alpha=0.9 - 0.25 * f)
    elif name == "poof":
        a = 1 - t * 0.85
        for k in range(6):
            ang = k * math.pi / 3 + 0.3
            d = W * 0.34 * t
            cv.ell(c + math.cos(ang) * d, c + math.sin(ang) * d, W * (0.14 - 0.06 * t) + 2, W * (0.14 - 0.06 * t) + 2, hx("F2F0FF"), hx("B9B3E6"), 2, a)
        cv.ell(c, c, W * 0.18 * (1.1 - t), W * 0.18 * (1.1 - t), WHITE, alpha=a)
    elif name == "sparkles":
        cols = [YELLOW, WHITE, CYAN, hx("FF9BD5")]
        for k in range(5):
            ang = k * 2 * math.pi / 5 + f * 0.4
            d = W * (0.12 + 0.28 * t)
            sz = W * (0.14 - 0.05 * ((f + k) % 3) * 0.5) * (1.0 - 0.4 * t)
            cv.star(c + math.cos(ang) * d, c + math.sin(ang) * d, sz, cols[k % 4], 0.3, 1 - 0.6 * t)

def draw_ui(cv, name):
    W, H = cv.w, cv.h; c = W / 2; ch = H / 2
    if name == "joystick_base":
        cv.ell(c, ch, W * .48, W * .48, WHITE, None, 0, 0.18)
        cv.ell(c, ch, W * .48, W * .48, PANEL, WHITE, 3, 0.35)
    elif name == "joystick_knob":
        cv.ell(c, ch, W * .46, W * .46, hx("DDF7FF"), OUT, 3); cv.ell(c - 8, ch - 8, W * .12, W * .12, WHITE, alpha=0.8)
    elif name.startswith("btn_"):
        col = {"fire": ORANGE, "reload": BLUE, "interact": GREEN, "swap": PURPLE, "pause": PANEL2, "inventory": YELLOW}[name[4:]]
        cv.ell(c, ch, W * .47, W * .47, col, OUT, 3); cv.ell(c - W * .12, ch - W * .14, W * .16, W * .08, WHITE, alpha=0.45)
        k = name[4:]
        if k == "fire":
            cv.star(c, ch, W * .30, WHITE, 0.35)
        elif k == "reload":
            cv.ell(c, ch, W * .24, W * .24, WHITE); cv.ell(c, ch, W * .15, W * .15, col); cv.rr(c + W * .2, ch - W * .1, W * .1, W * .05, 2, WHITE)
        elif k == "interact":
            cv.rr(c, ch, W * .06, W * .22, 3, WHITE); cv.ell(c, ch + W * .2, W * .06, W * .06, WHITE)
        elif k == "swap":
            cv.rr(c, ch - W * .1, W * .22, W * .05, 2, WHITE); cv.rr(c, ch + W * .1, W * .22, W * .05, 2, WHITE)
            cv.ell(c + W * .22, ch - W * .1, W * .06, W * .06, WHITE); cv.ell(c - W * .22, ch + W * .1, W * .06, W * .06, WHITE)
        elif k == "pause":
            cv.rr(c - W * .1, ch, W * .06, W * .2, 2, WHITE); cv.rr(c + W * .1, ch, W * .06, W * .2, 2, WHITE)
        elif k == "inventory":
            cv.rr(c, ch + 2, W * .2, W * .22, W * .08, WHITE, OUT, 2); cv.rr(c, ch + W * .1, W * .12, W * .08, 3, col, OUT, 2)
            cv.rr(c, ch - W * .24, W * .09, W * .04, 2, WHITE, OUT, 2)
    elif name in ("quickslot", "quickslot_sel", "invslot", "invslot_sel"):
        sel = name.endswith("_sel")
        cv.rr(c, ch, W * .48, H * .48, W * .12, PANEL, YELLOW if sel else PANEL2, 4 if sel else 3, 0.85)
        cv.rr(c, ch, W * .40, H * .40, W * .09, hx("1E1B3D"), None, 0, 0.6)
    elif name == "hpbar_bg":
        cv.rr(c, ch, W * .49, H * .46, H * .46, hx("1E1B3D"), WHITE, 3)
    elif name == "hpbar_fill":
        cv.rr(c, ch, W * .5, H * .5, H * .5, GREEN)
        cv.rr(c, ch - H * .18, W * .46, H * .12, H * .12, WHITE, alpha=0.4)
    elif name == "icon_heart":
        cv.ell(c - W * .17, ch - W * .1, W * .2, W * .2, RED, OUT, 2); cv.ell(c + W * .17, ch - W * .1, W * .2, W * .2, RED, OUT, 2)
        cv.rr(c, ch + W * .08, W * .26, W * .24, W * .06, RED, None); cv.ell(c - W * .2, ch - W * .15, W * .06, W * .06, WHITE)
    elif name == "icon_ammo":
        cv.rr(c, ch, W * .26, W * .3, W * .06, ORANGE, OUT, 2); cv.rr(c, ch, W * .08, W * .18, 2, WHITE)
    elif name == "icon_star":
        cv.star(c, ch, W * .45, YELLOW, 0.4); cv.ell(c, ch, W * .12, W * .12, WHITE)
    elif name.startswith("icon_blaster_"):
        col = {"starter": ORANGE, "spread": PURPLE, "rapid": YELLOW}[name.split("_")[2]]
        cv.rr(c, ch, W * .38, W * .14, W * .06, col, OUT, 2); cv.rr(c - W * .18, ch + W * .16, W * .08, W * .12, 2, col, OUT, 2)
        cv.ell(c + W * .36, ch, W * .06, W * .06, WHITE)
    elif name == "icon_pixel":
        cv.ell(c, ch, W * .42, W * .42, CYAN, OUT, 2); cv.rr(c, ch + 1, W * .28, W * .2, W * .1, hx("12304A")); cv.ell(c - 4, ch + 1, 2.5, 3, CYAN); cv.ell(c + 4, ch + 1, 2.5, 3, CYAN)

# ---------- main ----------
def render(gr, idx):
    w, h = gr.px
    cv = Canvas(w, h)
    s = gr.style
    if gr.cat in ("hero", "pixel", "enemy", "boss"):
        draw_char(cv, s, gr.anim, idx, gr.frames)
    elif gr.cat == "tile":
        draw_tile(cv, gr.name, gr.anim, idx)
    elif gr.cat in ("proj", "pickup"):
        draw_item(cv, s)
    elif gr.cat == "puzzle":
        draw_puzzle(cv, s, idx, gr.frames)
    elif gr.cat == "fx":
        draw_fx(cv, gr.name, idx, gr.frames)
    elif gr.cat == "ui":
        draw_ui(cv, gr.name)
    return cv

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(ROOT, "Strike", "Resources", "Atlases"))
    ap.add_argument("--only")
    a = ap.parse_args()
    count = 0
    for gr in M.GROUPS:
        if a.only and a.only not in (gr.atlas, gr.key) and not gr.key.startswith(a.only):
            continue
        d = os.path.join(a.out, gr.atlas + ".atlas")
        os.makedirs(d, exist_ok=True)
        for i, base in enumerate(gr.files()):
            cv = render(gr, i)
            cv.save(os.path.join(d, base + "@2x.png"))
            count += 1
    print("wrote %d PNGs to %s" % (count, a.out))

if __name__ == "__main__":
    main()
