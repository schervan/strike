#!/usr/bin/env python3
"""Turn Gemini sheets in art/raw/<sheet>.png into SpriteKit atlas PNGs (needs Pillow).

Each sheet is defined in tools/asset_manifest.py (SHEETS): ordered group keys,
background type (green / magenta / none), layout hint. Per sheet:
  1. background: sample the border -> flood-fill from the edges with a tolerance
     (Gemini never hits an exact colour) -> erode 1 px + despill the fringe -> alpha
  2. blobs: connected objects (nearby parts merged), corner watermark / specks dropped,
     extra blobs merged into their nearest neighbour, reading order -> group keys.
     If the blob count does not match, a fixed grid from the layout hint is used
     (with a warning).
  3. per object: trim, scale to the manifest size (shared factor for state pairs),
     align (bottom for characters, centre otherwise), write @2x PNGs into
     Strike/Resources/Atlases/<atlas>.atlas/. A multi-frame group gets the key pose
     in all frames; characters fill every anim (walk, hit, ...) with it
     (PoseAnimator animates in code). Real animation frames can replace them later.
  4. tiles: centre crop, made seamless (offset + cross-blend), resized to 128 px,
     floor/wall variants derived by rotating/flipping. App icon: 1024 px opaque PNG
     into Assets.xcassets/AppIcon.appiconset + Contents.json.

Tiles: each tile texture is the full seamless image at 512 px (TILE_REPEAT = 4 cells per side;
the game samples a 1/4 sub-rect per 64 pt cell). Every write touches the .atlas folder mtime
(os.utime) so Xcode recompiles the atlas.

Usage:
  python3 tools/slice_atlas.py                 # every sheet found in art/raw
  python3 tools/slice_atlas.py hero pixel      # selected sheets
  python3 tools/slice_atlas.py --report        # present / missing sheets + warnings
Options: --raw DIR, --out DIR, --icon-dir DIR, --tol N (bg tolerance, default 70), --debug
Raw file: art/raw/<sheet>.png (.jpg/.jpeg/.webp also accepted).
"""
import argparse, importlib.util, json, os, site, sys

try:
    from PIL import Image, ImageChops, ImageDraw, ImageFilter
except ImportError:
    # `python3 -I` ignores the user site-packages where `pip install --user` puts Pillow.
    sys.path.append(site.getusersitepackages())
    try:
        from PIL import Image, ImageChops, ImageDraw, ImageFilter
    except ImportError:
        sys.exit("Pillow is required: python3 -m pip install --user pillow")

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
_spec = importlib.util.spec_from_file_location("asset_manifest", os.path.join(HERE, "asset_manifest.py"))
M = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(M)

EXT = (".png", ".webp", ".jpg", ".jpeg")
MAX_WORK = 1280          # longest side used for keying / blob detection
BLOB_MAX = 480           # longest side of the label map
ICON_DIR = os.path.join(ROOT, "Strike", "Resources", "Assets.xcassets", "AppIcon.appiconset")


def find_raw(raw_dir, sheet):
    for e in EXT:
        p = os.path.join(raw_dir, sheet + e)
        if os.path.isfile(p):
            return p
    return None


# ---------------------------------------------------------------- background
def sample_border(im):
    px = im.load()
    w, h = im.size
    pts = []
    for i in range(0, w, 4):
        pts += [px[i, 0], px[i, 1], px[i, h - 1], px[i, h - 2]]
    for j in range(0, h, 4):
        pts += [px[0, j], px[1, j], px[w - 1, j], px[w - 2, j]]
    return tuple(sorted(p[c] for p in pts)[len(pts) // 2] for c in range(3))


def bg_candidates(rgb, color, tol):
    solid = Image.new("RGB", rgb.size, color)
    d = ImageChops.difference(rgb, solid)
    r, g, b = d.split()
    m = ImageChops.lighter(ImageChops.lighter(r, g), b)
    return m.point(lambda v: 255 if v <= tol else 0)


def flood_edges(cand):
    """Mark (value 128) the bg-like regions connected to the image border."""
    w, h = cand.size
    px = cand.load()
    step = max(2, min(w, h) // 200)
    seeds = [(x, y) for x in range(0, w, step) for y in (0, h - 1)] + \
            [(x, y) for y in range(0, h, step) for x in (0, w - 1)]
    for (x, y) in seeds:
        if px[x, y] == 255:
            ImageDraw.floodfill(cand, (x, y), 128)
    return cand.point(lambda v: 255 if v == 128 else 0)


def despill(rgb, bgmask, kind):
    r, g, b = rgb.split()
    if kind == "green":
        avg = ImageChops.add(r, b, scale=2)
        g2 = ImageChops.darker(g, avg)
        fixed = Image.merge("RGB", (r, g2, b))
    else:  # magenta: pull red/blue down towards green where they spill
        spill = ImageChops.subtract(ImageChops.darker(r, b), g)
        fixed = Image.merge("RGB", (ImageChops.subtract(r, spill), g, ImageChops.subtract(b, spill)))
    band = bgmask.filter(ImageFilter.MaxFilter(7))
    return Image.composite(fixed, rgb, band)


def key_background(im, kind, tol, warn):
    """-> RGBA image with the background removed."""
    rgb = im.convert("RGB")
    color = sample_border(rgb)
    r, g, b = color
    ok = (g > r + 30 and g > b + 30) if kind == "green" else (r > g + 60 and b > g + 60)
    if not ok:
        warn("background colour %s does not look %s (is the background flat %s?)" % (color, kind, kind))
    bgmask = flood_edges(bg_candidates(rgb, color, tol))
    fg = ImageChops.invert(bgmask).filter(ImageFilter.MinFilter(3))       # cut the fringe
    alpha = fg.filter(ImageFilter.GaussianBlur(0.7)).point(lambda v: 0 if v < 40 else (255 if v > 215 else v))
    out = despill(rgb, bgmask, kind).convert("RGBA")
    out.putalpha(alpha)
    return out


# ---------------------------------------------------------------- blobs
def label(mask):
    """4-connected labelling of a binary 'L' image -> list of pixel lists."""
    w, h = mask.size
    data = mask.load()
    seen = bytearray(w * h)
    comps = []
    for y0 in range(h):
        for x0 in range(w):
            if data[x0, y0] and not seen[y0 * w + x0]:
                stack = [(x0, y0)]
                seen[y0 * w + x0] = 1
                pts = []
                while stack:
                    x, y = stack.pop()
                    pts.append((x, y))
                    for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                        if 0 <= nx < w and 0 <= ny < h and data[nx, ny] and not seen[ny * w + nx]:
                            seen[ny * w + nx] = 1
                            stack.append((nx, ny))
                comps.append(pts)
    return comps


def bbox_dist(a, b):
    dx = max(a[0] - b[2], b[0] - a[2], 0)
    dy = max(a[1] - b[3], b[1] - a[3], 0)
    return (dx * dx + dy * dy) ** 0.5


def find_blobs(alpha, n, warn):
    """-> list of bboxes (full-res coords) in reading order, or None if count != n."""
    W, H = alpha.size
    s = min(1.0, BLOB_MAX / float(max(W, H)))
    sw, sh = max(1, int(W * s)), max(1, int(H * s))
    small = alpha.resize((sw, sh), Image.BOX).point(lambda v: 255 if v > 24 else 0)
    gap = max(3, int(max(sw, sh) * 0.012)) | 1
    comps = label(small.filter(ImageFilter.MaxFilter(2 * gap + 1)))
    solid = small.load()
    blobs = []
    for pts in comps:
        real = [(x, y) for x, y in pts if solid[x, y]]
        if not real:
            continue
        xs = [p[0] for p in real]
        ys = [p[1] for p in real]
        blobs.append({"box": [min(xs), min(ys), max(xs) + 1, max(ys) + 1], "area": len(real)})
    if not blobs:
        return None
    total = sw * sh
    blobs = [b for b in blobs if b["area"] > total * 0.0004]                      # specks
    big = sorted(b["area"] for b in blobs)
    med = big[len(big) // 2] if big else 0
    keep = []
    for b in blobs:                                                               # corner watermark
        cx, cy = (b["box"][0] + b["box"][2]) / 2.0, (b["box"][1] + b["box"][3]) / 2.0
        if cx > sw * 0.86 and cy > sh * 0.86 and b["area"] < med * 0.35:
            continue
        keep.append(b)
    blobs = keep
    while len(blobs) > n:                                                         # merge strays
        blobs.sort(key=lambda b: b["area"])
        small_b = blobs.pop(0)
        near = min(blobs, key=lambda o: bbox_dist(small_b["box"], o["box"]))
        near["box"] = [min(near["box"][0], small_b["box"][0]), min(near["box"][1], small_b["box"][1]),
                       max(near["box"][2], small_b["box"][2]), max(near["box"][3], small_b["box"][3])]
        near["area"] += small_b["area"]
    if len(blobs) != n:
        return None
    return [(int(b["box"][0] / s), int(b["box"][1] / s), int(b["box"][2] / s), int(b["box"][3] / s))
            for b in blobs]


def reading_order(boxes, cols, rows):
    """Chunk by rows (sorted by centre y), each row left to right."""
    boxes = sorted(boxes, key=lambda b: (b[1] + b[3]))
    per_row = [cols] * rows
    out, i = [], 0
    for k, c in enumerate(per_row):
        chunk = boxes[i:i + c] if k < rows - 1 else boxes[i:]
        i += c
        out += sorted(chunk, key=lambda b: b[0] + b[2])
    return out


def grid_boxes(alpha, cols, rows, n):
    W, H = alpha.size
    cw, ch = W / float(cols), H / float(rows)
    out = []
    for i in range(n):
        c, r = i % cols, i // cols
        cell = alpha.crop((int(c * cw), int(r * ch), int((c + 1) * cw), int((r + 1) * ch))).point(
            lambda v: 255 if v > 24 else 0)
        bb = cell.getbbox()
        out.append(None if not bb else (int(c * cw) + bb[0], int(r * ch) + bb[1],
                                        int(c * cw) + bb[2], int(r * ch) + bb[3]))
    return out


# ---------------------------------------------------------------- output
def fit(crop, W, H, pad, scale=None):
    bw, bh = crop.size
    s = scale if scale else min((W - 2 * pad) / float(bw), (H - 2 * pad) / float(bh))
    return crop.resize((max(1, round(bw * s)), max(1, round(bh * s))), Image.LANCZOS), s


def place(crop, W, H, align, pad):
    res = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    x = (W - crop.width) // 2
    y = H - pad - crop.height if align == "bottom" else (H - crop.height) // 2
    res.paste(crop, (x, y), crop)
    return res


def make_seamless(im, size=512):
    """Centre-crop square (drops a 6 % border: watermark/frame), offset + cross-blend."""
    w, h = im.size
    side = int(min(w, h) * 0.88)
    x0, y0 = (w - side) // 2, (h - side) // 2
    a = im.convert("RGB").crop((x0, y0, x0 + side, y0 + side)).resize((size, size), Image.LANCZOS)
    b = ImageChops.offset(a, size // 2, size // 2)
    ramp = Image.new("L", (size, 1))
    ramp.putdata([int(255 * max(0.0, 1 - abs(2.0 * x / (size - 1) - 1)) ** 0.6) for x in range(size)])
    mx = ramp.resize((size, size))
    my = mx.transpose(Image.TRANSPOSE)
    mask = ImageChops.darker(mx, my)
    return Image.composite(a, b, mask)


def write(out_dir, atlas, name, im):
    d = os.path.join(out_dir, atlas + ".atlas")
    os.makedirs(d, exist_ok=True)
    im.save(os.path.join(d, name + "@2x.png"))
    # Xcode recompiles a .atlas only when the folder mtime changes; replacing files inside does not.
    os.utime(d, None)


def write_group(out_dir, gr, pose, derive=None):
    """Write `pose` into every frame of group gr (derive(i,n) may replace per frame)."""
    names = gr.files()
    for i, name in enumerate(names):
        write(out_dir, gr.atlas, name, derive(i, len(names)) if derive else pose)
    return len(names)


def tile_variants(gr, base):
    vs = []
    for i in range(gr.frames):
        if gr.anim == "floor":
            vs.append(base.rotate(90 * i, expand=False) if i else base)
        else:
            vs.append(base.transpose(Image.FLIP_LEFT_RIGHT) if i % 2 else base)
    return vs


BLASTER_ICONS = ("starter", "spread", "rapid")


def derive_blaster_icons(out_dir):
    """ui_icon_blaster_* come from items.atlas pickup_blaster_* (64x64 px, fit to 90 %, centred),
    never from the ui_icons_b sheet (its blaster drawings looked like real guns)."""
    n = 0
    for k in BLASTER_ICONS:
        src = os.path.join(out_dir, "items.atlas", "pickup_blaster_%s@2x.png" % k)
        if not os.path.isfile(src):
            continue
        im = Image.open(src).convert("RGBA")
        bb = im.getchannel("A").getbbox()
        if not bb:
            continue
        crop = im.crop(bb)
        S = 64
        sc = (S * 0.9) / float(max(crop.size))
        crop = crop.resize((max(1, round(crop.width * sc)), max(1, round(crop.height * sc))), Image.LANCZOS)
        icon = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        icon.paste(crop, ((S - crop.width) // 2, (S - crop.height) // 2), crop)
        write(out_dir, "ui", "ui_icon_blaster_" + k, icon)
        n += 1
    return n


def process_sheet(name, path, out_dir, icon_dir=ICON_DIR, tol=70, debug=False):
    """Slice one sheet. Returns (files_written, warnings)."""
    sh = M.SHEETS[name]
    warnings = []
    warn = warnings.append
    im = Image.open(path).convert("RGBA")
    written = 0

    if sh["items"] == ["@appicon"]:
        side = min(im.size)
        x0, y0 = (im.width - side) // 2, (im.height - side) // 2
        icon = im.convert("RGB").crop((x0, y0, x0 + side, y0 + side)).resize((1024, 1024), Image.LANCZOS)
        os.makedirs(icon_dir, exist_ok=True)
        icon.save(os.path.join(icon_dir, "AppIcon.png"))
        cj = os.path.join(icon_dir, "Contents.json")
        data = json.load(open(cj)) if os.path.isfile(cj) else {"images": [{"idiom": "universal", "platform": "ios", "size": "1024x1024"}],
                                                                "info": {"author": "xcode", "version": 1}}
        for e in data["images"]:
            if e.get("size") == "1024x1024":
                e["filename"] = "AppIcon.png"
        json.dump(data, open(cj, "w"), indent=2)
        return 1, warnings

    if sh["bg"] == "none":  # tiles
        gr = M.group(sh["items"][0])
        base = make_seamless(im, gr.px[0]).resize(gr.px, Image.LANCZOS).convert("RGBA")
        for i, v in enumerate(tile_variants(gr, base)):
            write(out_dir, gr.atlas, gr.files()[i], v)
            written += 1
        return written, warnings

    if max(im.size) > MAX_WORK:
        s = MAX_WORK / float(max(im.size))
        im = im.resize((int(im.width * s), int(im.height * s)), Image.LANCZOS)
    im = key_background(im, sh["bg"], tol, warn)
    alpha = im.getchannel("A")
    items = sh["items"]
    cols, rows = M.LAYOUT_GRID[sh["layout"]]
    boxes = find_blobs(alpha, len(items), warn)
    if boxes is None:
        warn("blob count != %d expected; fell back to a %dx%d grid cut" % (len(items), cols, rows))
        boxes = grid_boxes(alpha, cols, rows, len(items))
    else:
        boxes = reading_order(boxes, cols, rows)
    if debug:
        dbg = im.convert("RGB").copy()
        dd = ImageDraw.Draw(dbg)
        for i, b in enumerate(boxes):
            if b:
                dd.rectangle(b, outline=(255, 0, 0), width=3)
                dd.text((b[0] + 4, b[1] + 4), str(i + 1), fill=(255, 0, 0))
        dbg.save(os.path.splitext(path)[0] + "_debug.png")

    crops = []
    pad_ratio = 0.03
    for key, b in zip(items, boxes):
        if b is None:
            warn("nothing found for %s" % key)
            crops.append(None)
            continue
        m = 4
        c = im.crop((max(0, b[0] - m), max(0, b[1] - m), min(im.width, b[2] + m), min(im.height, b[3] + m)))
        bb = c.getchannel("A").getbbox()
        crops.append(c.crop(bb) if bb else None)

    shared = None
    if sh["shared"]:
        scales = []
        for key, c in zip(items, crops):
            if c is None:
                continue
            gr = M.group(key)
            W, H = gr.px
            pad = max(2, int(min(W, H) * pad_ratio))
            scales.append(min((W - 2 * pad) / float(c.width), (H - 2 * pad) / float(c.height)))
        shared = min(scales) if scales else None

    posed = {}
    for key, c in zip(items, crops):
        if c is None:
            continue
        gr = M.group(key)
        W, H = gr.px
        pad = max(2, int(min(W, H) * pad_ratio))
        scaled, _ = fit(c, W, H, pad, shared)
        pose = place(scaled, W, H, gr.align, pad)
        posed[key] = pose
        if key.startswith("ui_icon_blaster_"):
            continue  # derived from pickup_blaster_* below
        targets = M.siblings(gr) if sh["fill"] == "siblings" else [gr]
        for t in targets:
            written += write_group(out_dir, t, pose)
    if name in ("ui_icons_b", "pickups_blasters"):
        written += derive_blaster_icons(out_dir)
    if name == "puzzle_door" and "puzzle_door_closed" in posed and "puzzle_door_open" in posed:
        a, b = posed["puzzle_door_closed"], posed["puzzle_door_open"]
        opening = M.group("puzzle_door_opening")
        written += write_group(out_dir, opening, None,
                               lambda i, n: Image.blend(a, b, (i + 1) / float(n + 1)))
    return written, warnings


# ---------------------------------------------------------------- cli
def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("sheets", nargs="*")
    ap.add_argument("--raw", default=os.path.join(ROOT, "art", "raw"))
    ap.add_argument("--out", default=os.path.join(ROOT, "Strike", "Resources", "Atlases"))
    ap.add_argument("--icon-dir", default=ICON_DIR)
    ap.add_argument("--tol", type=int, default=70)
    ap.add_argument("--report", action="store_true")
    ap.add_argument("--debug", action="store_true", help="write <sheet>_debug.png with blob boxes")
    a = ap.parse_args()
    for k in a.sheets:
        if k not in M.SHEETS:
            sys.exit("unknown sheet: %s (see SHEETS in tools/asset_manifest.py)" % k)
    names = a.sheets or list(M.SHEETS)
    present = missing = nwarn = 0
    if a.report:
        print("%-3s %-26s %-8s %s" % ("#", "sheet", "status", "items"))
    for name in names:
        sh = M.SHEETS[name]
        path = find_raw(a.raw, name)
        if not path:
            missing += 1
            if a.report or a.sheets:
                print("%-3d %-26s %-8s %d item(s), bg=%s, %s" % (sh["no"], name, "MISSING", len(sh["items"]), sh["bg"], sh["shape"]))
            continue
        present += 1
        if a.report:
            print("%-3d %-26s %-8s %d item(s)" % (sh["no"], name, "present", len(sh["items"])))
            continue
        n, warns = process_sheet(name, path, a.out, a.icon_dir, a.tol, a.debug)
        print("ok %-26s %d file(s)" % (name, n))
        for w in warns:
            nwarn += 1
            print("   ! %s: %s" % (name, w))
    print("%d sheet(s) present, %d missing (placeholders stay), %d warning(s)" % (present, missing, nwarn))
    if a.report:
        later = M.later()
        print("not part of the lite set (placeholders / code-drawn): %d group(s)" % len(later))


if __name__ == "__main__":
    main()
