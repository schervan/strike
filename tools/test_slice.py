#!/usr/bin/env python3
"""Self-test for slice_atlas.py with synthetic "Gemini-like" sheets.  Run: python3 -I tools/test_slice.py"""
import importlib.util, os, random, site, sys, tempfile, json

try:
    from PIL import Image, ImageDraw
except ImportError:  # -I drops the user site-packages
    sys.path.append(site.getusersitepackages())
    from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))


def load(name):
    spec = importlib.util.spec_from_file_location(name, os.path.join(HERE, name + ".py"))
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


S = load("slice_atlas")
M = S.M
fails = []


def check(cond, msg):
    print(("PASS  " if cond else "FAIL  ") + msg)
    if not cond:
        fails.append(msg)


def noisy_bg(size, base, seed=1):
    rnd = random.Random(seed)
    im = Image.new("RGB", size, base)
    px = im.load()
    for _ in range(size[0] * size[1] // 20):          # sprinkle noise: Gemini is never flat
        x, y = rnd.randrange(size[0]), rnd.randrange(size[1])
        px[x, y] = tuple(max(0, min(255, c + rnd.randint(-12, 12))) for c in base)
    return im


def sheet(size, base, cells, cols, rows, sparkle=True, extra_part=False):
    im = noisy_bg(size, base)
    d = ImageDraw.Draw(im)
    cw, ch = size[0] / cols, size[1] / rows
    for i, col in enumerate(cells):
        cx, cy = (i % cols + 0.5) * cw, (i // cols + 0.5) * ch
        r = min(cw, ch) * 0.28
        d.ellipse((cx - r, cy - r * 0.9, cx + r, cy + r * 0.9), fill=col, outline=(43, 33, 64), width=6)
        if extra_part and i == 0:   # detached floating star near blob 1
            d.ellipse((cx + r * 1.2, cy - r * 1.3, cx + r * 1.4, cy - r * 1.1), fill=col)
    if sparkle:  # Gemini watermark in the bottom-right corner
        w, h = size
        d.polygon([(w - 40, h - 70), (w - 30, h - 40), (w - 5, h - 35), (w - 30, h - 28), (w - 40, h - 5),
                   (w - 50, h - 28), (w - 75, h - 35), (w - 50, h - 40)], fill=(255, 255, 255))
    return im


tmp = tempfile.mkdtemp(prefix="slice_test_")
out = os.path.join(tmp, "Atlases")
icon = os.path.join(tmp, "AppIcon.appiconset")
os.makedirs(icon)
json.dump({"images": [{"idiom": "universal", "platform": "ios", "size": "1024x1024"}],
           "info": {"author": "xcode", "version": 1}}, open(os.path.join(icon, "Contents.json"), "w"))


def outfile(atlas, base):
    return os.path.join(out, atlas + ".atlas", base + "@2x.png")


# 1. green 2x2 grid with sparkle: 4 correct outputs
p = os.path.join(tmp, "projectiles.png")
sheet((1024, 1024), (24, 225, 45), [(255, 138, 61), (176, 92, 255), (255, 217, 61), (255, 59, 92)], 2, 2).save(p)
n, w = S.process_sheet("projectiles", p, out, icon)
check(n == 4 and not w, "projectiles: 4 files, no warnings (got %d, %s)" % (n, w))
for key in ("proj_starter", "proj_spread", "proj_rapid", "proj_enemy"):
    f = outfile("items", key)
    ok = os.path.isfile(f)
    if ok:
        im = Image.open(f)
        ok = im.size == (32, 32) and im.getpixel((0, 0))[3] == 0 and im.getpixel((16, 16))[3] == 255
    check(ok, "%s is 32x32, transparent corner, opaque centre" % key)
# order: starter orange (top-left), enemy red (bottom-right)
c = Image.open(outfile("items", "proj_starter")).getpixel((16, 16))
check(c[0] > 200 and 100 < c[1] < 170 and c[2] < 100, "proj_starter is the orange blob (reading order) %s" % (c,))
c = Image.open(outfile("items", "proj_enemy")).getpixel((16, 16))
check(c[0] > 200 and c[1] < 100, "proj_enemy is the red blob %s" % (c,))

# 2. magenta bg, 4 pickups, detached part must merge, fringe must not be magenta/green
p = os.path.join(tmp, "pickups_heal.png")
sheet((1024, 1024), (255, 20, 235), [(255, 255, 255), (255, 59, 92), (240, 240, 230), (224, 164, 88)], 2, 2,
      extra_part=True).save(p)
n, w = S.process_sheet("pickups_heal", p, out, icon)
check(n == 4 and not w, "pickups_heal (magenta, detached part): 4 files, no warnings (got %d, %s)" % (n, w))
im = Image.open(outfile("items", "pickup_healpack"))
check(im.getpixel((0, 0))[3] == 0 and im.size == (64, 64), "pickup_healpack 64x64 with transparent corner")

# 3. one character: all sibling anims filled, bottom aligned, 128 px
p = os.path.join(tmp, "hero.png")
sheet((1024, 1024), (24, 225, 45), [(61, 139, 255)], 1, 1).save(p)
n, w = S.process_sheet("hero", p, out, icon)
check(n == 15 and not w, "hero: 15 frames (idle4 walk6 shoot3 hit2), no warnings (got %d, %s)" % (n, w))
im = Image.open(outfile("hero", "hero_walk_06"))
bb = im.getchannel("A").getbbox()
check(im.size == (128, 128) and bb and bb[3] >= 120, "hero_walk_06 128x128, bottom aligned (bbox %s)" % (bb,))

# 4. wide 2-up puzzle pair shares a scale; door writes opening frames
p = os.path.join(tmp, "puzzle_door.png")
sheet((1344, 768), (255, 20, 235), [(255, 59, 92), (95, 224, 138)], 2, 1).save(p)
n, w = S.process_sheet("puzzle_door", p, out, icon)
check(n == 6 and not w, "puzzle_door: closed + open + 4 opening (got %d, %s)" % (n, w))
check(all(os.path.isfile(outfile("puzzle", k)) for k in
          ("puzzle_door_closed", "puzzle_door_open", "puzzle_door_opening_01", "puzzle_door_opening_04")),
      "door files exist")

# 5. blob count mismatch falls back to grid with a warning
p = os.path.join(tmp, "pickups_keys.png")
sheet((1024, 1024), (255, 20, 235), [(0, 0, 0)] * 3 + [(200, 200, 40)], 2, 2).save(p)
im = Image.open(p)
ImageDraw.Draw(im).rectangle((0, 0, 1023, 1023), outline=None)
# erase blob 3 so only 3 remain
ImageDraw.Draw(im).rectangle((0, 512, 512, 1023), fill=(255, 20, 235))
im.save(p)
n, w = S.process_sheet("pickups_keys", p, out, icon)
check(any("fell back" in x for x in w) or any("nothing found" in x for x in w),
      "wrong blob count warns (%s)" % w)

# 6. tile: 512 px, seamless-ish (opposite edges close), 3 floor variants
p = os.path.join(tmp, "tile_l1_floor.png")
t = Image.new("RGB", (1024, 1024), (184, 196, 214))
dt = ImageDraw.Draw(t)
for i in range(0, 1024, 128):
    dt.line((i, 0, i, 1024), fill=(150, 160, 190), width=6)       # grid lines: left != right edge
    dt.line((0, i + 40, 1024, i + 40), fill=(150, 160, 190), width=6)
t.putpixel((10, 10), (0, 0, 0))
t.save(p)
n, w = S.process_sheet("tile_l1_floor", p, out, icon)
check(n == 3, "tile_l1_floor writes 3 variants (got %d)" % n)
im = Image.open(outfile("tiles", "tile_l1_floor_01")).convert("RGB")
check(im.size == (512, 512), "tile is 512x512 (TILE_REPEAT 4)")
diff = sum(sum(abs(a - b) for a, b in zip(im.getpixel((0, y)), im.getpixel((511, y)))) for y in range(512)) / 512.0
check(diff < 40, "tile left/right edges match (avg diff %.1f)" % diff)

# 7. app icon: 1024 opaque, Contents.json updated
p = os.path.join(tmp, "appicon.png")
Image.new("RGB", (1408, 1408), (61, 139, 255)).save(p)
n, w = S.process_sheet("appicon", p, out, icon)
ic = Image.open(os.path.join(icon, "AppIcon.png"))
cj = json.load(open(os.path.join(icon, "Contents.json")))
check(ic.size == (1024, 1024) and ic.mode == "RGB", "AppIcon.png is 1024x1024 opaque RGB")
check(cj["images"][0].get("filename") == "AppIcon.png", "Contents.json filename set")

# 8. manifest sanity
check(len(M.SHEETS) == 36, "36 sheets in manifest (got %d)" % len(M.SHEETS))
allk = {g.key for g in M.GROUPS}
check(all(k in allk for k in M.LITE), "every SHEETS item is a manifest group")

print("\n%s" % ("ALL PASSED" if not fails else "%d FAILED" % len(fails)))
sys.exit(1 if fails else 0)
