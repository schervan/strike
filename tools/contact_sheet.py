#!/usr/bin/env python3
"""Labeled contact sheet (needs Pillow). Checkerboard behind transparency, max 1600 px wide.

Usage:
  python3 tools/contact_sheet.py art/raw --out sheet.png        # a dir (png/jpg/webp, non-recursive)
  python3 tools/contact_sheet.py a.png b.png --out sheet.png    # explicit files
  python3 tools/contact_sheet.py --atlases --out atlases.png    # Strike/Resources/Atlases/*.atlas/*.png
Options: --cols N (default auto), --cell PX (cell image size, default 200), --max-width PX (1600)
"""
import argparse, glob, os, site, sys

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    sys.path.append(site.getusersitepackages())
    try:
        from PIL import Image, ImageDraw, ImageFont
    except ImportError:
        sys.exit("Pillow is required: python3 -m pip install --user pillow")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EXT = (".png", ".jpg", ".jpeg", ".webp")


def checker(w, h, s=10):
    im = Image.new("RGB", (w, h), (225, 225, 225))
    d = ImageDraw.Draw(im)
    for y in range(0, h, s):
        for x in range(0, w, s):
            if (x // s + y // s) % 2:
                d.rectangle([x, y, x + s - 1, y + s - 1], fill=(170, 170, 170))
    return im


def collect(paths, atlases):
    out = []
    if atlases:
        for d in sorted(glob.glob(os.path.join(ROOT, "Strike", "Resources", "Atlases", "*.atlas"))):
            for f in sorted(os.listdir(d)):
                if f.lower().endswith(".png"):
                    out.append((os.path.join(d, f), f"{os.path.basename(d)[:-6]}/{f}"))
    for p in paths:
        if os.path.isdir(p):
            for f in sorted(os.listdir(p)):
                if f.lower().endswith(EXT):
                    out.append((os.path.join(p, f), f))
        elif os.path.isfile(p):
            out.append((p, os.path.basename(p)))
        else:
            print(f"warning: not found: {p}")
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("paths", nargs="*")
    ap.add_argument("--out", required=True)
    ap.add_argument("--atlases", action="store_true")
    ap.add_argument("--cols", type=int, default=0)
    ap.add_argument("--cell", type=int, default=200)
    ap.add_argument("--max-width", type=int, default=1600)
    a = ap.parse_args()
    files = collect(a.paths, a.atlases)
    if not files:
        sys.exit("No images found.")
    pad, lab = 8, 16
    cols = a.cols or max(1, min(len(files), (a.max_width - pad) // (a.cell + pad)))
    cw = (a.max_width - pad) // cols - pad if cols * (a.cell + pad) + pad > a.max_width else a.cell
    rows = -(-len(files) // cols)
    W, H = cols * (cw + pad) + pad, rows * (cw + lab + pad) + pad
    sheet = Image.new("RGB", (W, H), (60, 60, 70))
    d = ImageDraw.Draw(sheet)
    font = ImageFont.load_default()
    for i, (p, label) in enumerate(files):
        x, y = pad + (i % cols) * (cw + pad), pad + (i // cols) * (cw + lab + pad)
        try:
            im = Image.open(p).convert("RGBA")
        except Exception as e:
            d.text((x, y), f"unreadable {label}", fill=(255, 120, 120), font=font)
            continue
        sz = f"{im.width}x{im.height}"
        s = min(cw / im.width, cw / im.height)
        im = im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.LANCZOS if s < 1 else Image.NEAREST)
        bg = checker(cw, cw)
        bg.paste(im, ((cw - im.width) // 2, (cw - im.height) // 2), im)
        sheet.paste(bg, (x, y))
        text = f"{label} {sz}"
        d.text((x, y + cw + 2), text if len(text) * 6 <= cw else label[-(cw // 6):], fill=(255, 255, 255), font=font)
    sheet.save(a.out)
    print(f"wrote {a.out}: {len(files)} images, {W}x{H}")


if __name__ == "__main__":
    main()
