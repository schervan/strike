"""Single source of truth for Strike sprite assets (names, sizes, frames).

Sizes are in points (pt); files are written @2x, so pixels = pt * 2.
File name: <category>_<name>_<anim>_<NN>@2x.png  (see docs/ART_BIBLE.md).
Parts that do not apply are omitted: hero/pixel have no <name>; static
sprites have no <NN>; single-state sprites have no <anim>.
"""

SCALE = 2


class Group:
    """One animation (or one static sprite): `frames` files sharing a prefix."""

    def __init__(self, atlas, cat, name, anim, frames, w, h, style, align="center"):
        self.atlas, self.cat, self.name, self.anim = atlas, cat, name, anim
        self.frames, self.w, self.h, self.style, self.align = frames, w, h, style, align

    @property
    def key(self):
        return "_".join(p for p in (self.cat, self.name, self.anim) if p)

    @property
    def px(self):
        return self.w * SCALE, self.h * SCALE

    def files(self):
        if self.frames <= 1:
            return [self.key]
        return ["%s_%02d" % (self.key, i + 1) for i in range(self.frames)]


def _build():
    g = []
    A = g.append
    # --- hero (64pt, faces EAST; code mirrors for west) ---
    for anim, n in (("idle", 4), ("walk", 6), ("shoot", 3), ("hit", 2)):
        A(Group("hero", "hero", None, anim, n, 64, 64, "hero", "bottom"))
    # --- pixel (drone buddy, 48pt) ---
    for anim, n in (("idle", 4), ("talk", 3)):
        A(Group("pixel", "pixel", None, anim, n, 48, 48, "pixel"))
    # --- enemies ---
    en = [
        ("boltbot", 56, (("idle", 4), ("walk", 6), ("hit", 2))),
        ("laserdrone", 56, (("idle", 4), ("shoot", 3), ("hit", 2))),
        ("slimemutant", 56, (("idle", 4), ("walk", 6), ("hit", 2))),
        ("slimemutant_small", 40, (("idle", 4), ("walk", 6), ("hit", 2))),
        ("shieldandroid", 64, (("idle", 4), ("walk", 6), ("shoot", 3), ("hit", 2))),
        ("sporeplant", 56, (("idle", 4), ("shoot", 3), ("hit", 2))),
    ]
    for name, s, anims in en:
        for anim, n in anims:
            A(Group("enemies", "enemy", name, anim, n, s, s, name, "bottom"))
    # --- boss (192pt = 3x3 tiles) ---
    for anim, n in (("idle", 4), ("walk", 6), ("shoot", 3), ("charge", 4), ("hit", 2), ("defeat", 6)):
        A(Group("boss", "boss", "megamech", anim, n, 192, 192, "megamech", "bottom"))
    # --- items atlas: projectiles + pickups ---
    for name in ("starter", "spread", "rapid", "enemy"):
        A(Group("items", "proj", name, None, 1, 16, 16, "proj_" + name))
    for name in ("healpack", "food_apple", "food_onigiri", "food_cookie",
                 "ammo_starter", "ammo_spread", "ammo_rapid", "fuse", "battery", "keycard"):
        A(Group("items", "pickup", name, None, 1, 32, 32, "pickup_" + name))
    A(Group("items", "pickup", "energycore", None, 1, 40, 40, "pickup_energycore"))
    # lite-set additions (GDD "new assets" + weapon pickups)
    for name in ("bolt", "datachip", "blaster_starter", "blaster_spread", "blaster_rapid"):
        A(Group("items", "pickup", name, None, 1, 32, 32, "pickup_" + name))
    # --- puzzle ---
    for name in ("button", "lever", "pressureplate"):
        for st in ("off", "on"):
            A(Group("puzzle", "puzzle", name, st, 1, 64, 64, "puzzle_" + name + "_" + st))
    for st in ("off", "on"):
        A(Group("puzzle", "puzzle", "machine", st, 1, 128, 128, "puzzle_machine_" + st))
    A(Group("puzzle", "puzzle", "door", "closed", 1, 64, 64, "puzzle_door_closed"))
    A(Group("puzzle", "puzzle", "door", "opening", 4, 64, 64, "puzzle_door_opening"))
    A(Group("puzzle", "puzzle", "door", "open", 1, 64, 64, "puzzle_door_open"))
    for name, states in (("crate", ("whole", "broken")), ("checkpoint", ("off", "on")),
                         ("exitpad", ("off", "on"))):
        for st in states:
            A(Group("puzzle", "puzzle", name, st, 1, 64, 64, "puzzle_" + name + "_" + st))
    # --- tiles (64pt) ---
    for t in ("l1", "l2", "l3", "l4", "l5"):
        A(Group("tiles", "tile", t, "floor", 3, 64, 64, "tile_" + t + "_floor"))
        A(Group("tiles", "tile", t, "wall", 2, 64, 64, "tile_" + t + "_wall"))
    # --- fx ---
    A(Group("fx", "fx", "hitflash", None, 3, 48, 48, "fx_hitflash"))
    A(Group("fx", "fx", "poof", None, 6, 64, 64, "fx_poof"))
    A(Group("fx", "fx", "sparkles", None, 6, 64, 64, "fx_sparkles"))
    # --- ui ---
    ui = [
        ("joystick_base", 160, 160), ("joystick_knob", 72, 72),
        ("btn_fire", 96, 96), ("btn_reload", 72, 72), ("btn_interact", 72, 72),
        ("btn_swap", 72, 72), ("btn_pause", 64, 64), ("btn_inventory", 72, 72),
        ("quickslot", 72, 72), ("quickslot_sel", 72, 72),
        ("invslot", 64, 64), ("invslot_sel", 64, 64),
        ("hpbar_bg", 240, 28), ("hpbar_fill", 232, 20),
        ("icon_heart", 32, 32), ("icon_ammo", 32, 32), ("icon_star", 32, 32),
        ("icon_blaster_starter", 32, 32), ("icon_blaster_spread", 32, 32),
        ("icon_blaster_rapid", 32, 32), ("icon_pixel", 32, 32),
    ]
    for name, w, h in ui:
        A(Group("ui", "ui", name, None, 1, w, h, "ui_" + name))
    return g


GROUPS = _build()
ATLASES = ["hero", "pixel", "enemies", "boss", "items", "puzzle", "tiles", "fx", "ui"]


# ---------------------------------------------------------------------------
# Gemini "lite" sheets: one generated image (art/raw/<sheet>.png) -> several groups.
#   items   : group keys in reading order (left-to-right, top-to-bottom). A
#             multi-frame group gets the single key pose in every frame; with
#             fill="siblings" every other anim of the same character (walk, hit,
#             shoot, ...) is filled with the same pose too (PoseAnimator moves it).
#             Tile groups get all variants derived from the one texture.
#             "@appicon" = the 1024 px App Store icon (written to Assets.xcassets).
#   bg      : "green" | "magenta" | "none" (tiles, icon: full-bleed)
#   layout  : single | row2 | grid2x2 | grid3x2 | grid4x2 (fallback grid + row split)
#   shape   : "square" | "wide" (what to ask Gemini for)
#   shared  : True = all items of the sheet are scaled by one common factor (state pairs)
#   no      : prompt number in art/prompts/gemini/PROMPTS.md
# ---------------------------------------------------------------------------
def _sheets():
    S = {}
    n = [0]

    def add(name, items, bg="green", layout="single", shape="square", fill=None, shared=False):
        n[0] += 1
        S[name] = dict(items=items, bg=bg, layout=layout, shape=shape, fill=fill,
                       shared=shared, no=n[0])

    add("hero", ["hero_idle"], fill="siblings")
    add("pixel", ["pixel_idle"], fill="siblings")
    add("enemy_boltbot", ["enemy_boltbot_idle"], fill="siblings")
    add("enemy_laserdrone", ["enemy_laserdrone_idle"], fill="siblings")
    add("enemy_slimemutant", ["enemy_slimemutant_idle"], bg="magenta", fill="siblings")
    add("enemy_slimemutant_small", ["enemy_slimemutant_small_idle"], bg="magenta", fill="siblings")
    add("enemy_shieldandroid", ["enemy_shieldandroid_idle"], fill="siblings")
    add("enemy_sporeplant", ["enemy_sporeplant_idle"], bg="magenta", fill="siblings")
    add("boss_megamech", ["boss_megamech_idle"], fill="siblings")
    add("projectiles", ["proj_starter", "proj_spread", "proj_rapid", "proj_enemy"], layout="grid2x2")
    add("pickups_heal", ["pickup_healpack", "pickup_food_apple", "pickup_food_onigiri",
                         "pickup_food_cookie"], bg="magenta", layout="grid2x2")
    add("pickups_ammo", ["pickup_ammo_starter", "pickup_ammo_spread", "pickup_ammo_rapid",
                         "pickup_energycore"], layout="grid2x2")
    add("pickups_keys", ["pickup_fuse", "pickup_battery", "pickup_keycard", "pickup_datachip"],
        bg="magenta", layout="grid2x2")
    add("pickups_blasters", ["pickup_bolt", "pickup_blaster_starter", "pickup_blaster_spread",
                             "pickup_blaster_rapid"], layout="grid2x2")
    for name, a, b in (("button", "off", "on"), ("lever", "off", "on"), ("pressureplate", "off", "on"),
                       ("machine", "off", "on"), ("door", "closed", "open"),
                       ("crate", "whole", "broken"), ("checkpoint", "off", "on"),
                       ("exitpad", "off", "on")):
        add("puzzle_" + name, ["puzzle_%s_%s" % (name, a), "puzzle_%s_%s" % (name, b)],
            bg="magenta", layout="row2", shape="wide", shared=True)
    for t in ("l1", "l2", "l3", "l4", "l5"):
        for k in ("floor", "wall"):
            add("tile_%s_%s" % (t, k), ["tile_%s_%s" % (t, k)], bg="none")
    add("ui_icons_a", ["ui_btn_fire", "ui_btn_reload", "ui_btn_interact", "ui_btn_swap",
                       "ui_btn_pause", "ui_btn_inventory"], layout="grid3x2", shape="wide")
    add("ui_icons_b", ["ui_icon_heart", "ui_icon_ammo", "ui_icon_star", "ui_icon_blaster_starter",
                       "ui_icon_blaster_spread", "ui_icon_blaster_rapid", "ui_icon_pixel"],
        layout="grid4x2", shape="wide")
    add("appicon", ["@appicon"], bg="none")
    return S


SHEETS = _sheets()
LAYOUT_GRID = {"single": (1, 1), "row2": (2, 1), "grid2x2": (2, 2), "grid3x2": (3, 2), "grid4x2": (4, 2)}
LITE = [k for sh in SHEETS.values() for k in sh["items"] if not k.startswith("@")]
_BY_KEY = {g.key: g for g in GROUPS}


def group(key):
    return _BY_KEY[key]


def siblings(gr):
    """Groups of the same character (same atlas/cat/name), including gr itself."""
    return [g for g in GROUPS if (g.atlas, g.cat, g.name) == (gr.atlas, gr.cat, gr.name)]


def later():
    """Groups not produced by Gemini in the lite set (full animations, fx, code-drawn UI)."""
    covered = set()
    for sh in SHEETS.values():
        for k in sh["items"]:
            if k.startswith("@"):
                continue
            covered.update(g.key for g in (siblings(group(k)) if sh["fill"] else [group(k)]))
    covered.add("puzzle_door_opening")  # derived: cross-fade closed -> open
    return [g.key for g in GROUPS if g.key not in covered]


def all_files():
    """Yield (group, file_base) for every PNG (without @2x.png)."""
    for gr in GROUPS:
        for f in gr.files():
            yield gr, f
