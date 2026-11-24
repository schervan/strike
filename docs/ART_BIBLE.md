# Strike Art Bible

Owner: visual-artist. Source of truth for sprite names/sizes/frames: `tools/asset_manifest.py` (the table in section 9 is generated from it). Placeholders: `python3 -I tools/make_placeholders.py`. AI art: `art/prompts/gemini/PROMPTS.md` (lite set, Gemini web app), slicer: `tools/slice_atlas.py`. Old full-animation prompts: `art/prompts/_full_animation/` (for later).

## 1. Style rules
- **Cute anime cartoon shooter, chibi**: head about 45 percent of body height, big glossy eyes (white sclera, dark pupil, white glint), small bodies, rounded shapes, no sharp realistic detail. Friendly even when evil.
- **Kid-safe**: no blood, gore, realistic guns or scary faces. Blasters are chunky toy/light blasters. Hits flash white; defeats "power down" into stars, bolts and sparkles (code particles, see section 12) and drop loot.
- **Outline**: always #2B2140 (deep plum), never pure black. Width 3 px @2x (1.5 pt) on 32-64 pt sprites, 4 px on the boss and machine, 2 px on items under 32 pt. Uniform weight, rounded joins. Tiles: no outline on tile edges (must tile), only on inner details.
- **Shading**: soft two-tone cel shading (base + one shade 12-18 percent darker, one white highlight). Light from the **top-left**; shade bottom-right. No gradients except glows and the app icon.
- **Camera**: top-down, 3/4 view for characters (we see the head and front). **All characters are drawn facing east (right)**; code mirrors with `xScale = -1` for west and never rotates sprites. Items and puzzle objects are drawn straight top-down.
- **Silhouette**: must read at 64 px and at 50 percent scale. One strong shape and 2-3 main colors per character. Enemies are visually distinct by color: robots blue/gray/purple/silver with RED eyes, creatures green/pink.
- **Ground shadow**: baked into character sprites, a soft plum ellipse at 28 percent alpha under the feet. Not baked into items (code adds one).
- **Glow**: soft additive-looking halo baked as low-alpha circle (energy core, Pixel, projectiles).

## 2. Palette
### Global
| Role | Hex |
|---|---|
| Outline | #2B2140 |
| White / highlight | #FFFFFF |
| Skin | #FFD9B8 |
| Hero hair / dark brown | #7A4A2B |
| Hero jacket blue | #3D8BFF (shade #2D5FB8) |
| Hero accent / starter blaster orange | #FF8A3D |
| Pixel cyan | #3DE3D0 (light #BFFFF7, screen #12304A, teal dark #17A6A0) |
| OVERMIND red | #FF3B5C |
| OVERMIND magenta | #D61F8F |
| Star / rapid yellow | #FFD93D |
| Heal / good green | #5FE08A |
| Spread purple | #B05CFF |
| UI panel | #2E2A55 / light #4A4585 / inner #1E1B3D |
| Robot metal | #A9BCE0, #C9D2EA, #8FA3C8, dark #444B6B |
| Slime green | #6FE06A / #8CF07F |
| Spore pink | #E36BD8 / #FFB3F2 |
| Weapon colors | starter #FF8A3D, spread #B05CFF, rapid #FFD93D (projectile, ammo crate and HUD icon share it); enemy shots see 15.16 (pink orb, lilac puffball, cartoon rocket) |
| State colors | off/locked #FF3B5C, on/open #5FE08A |

### Per level theme (floor A / floor B / wall / wall top / accent)
| Level | Theme | Floor A | Floor B | Wall | Wall top | Accent | Mood |
|---|---|---|---|---|---|---|---|
| L1 | City Rooftop Lab | #B8C4D6 | #A6B3C8 | #5B6B8C | #7E90B5 | #FFB347 | bright daylight, sky blue #8FD3FF edges |
| L2 | Robot Factory | #8C8F99 | #7A7D88 | #4A4E5C | #6B7080 | #FFC21A | steel, hazard yellow, orange pipes #FF7A1A |
| L3 | Gene Lab Greenhouse | #BFE3A0 | #A8D488 | #3C8F5A | #5FBF7A | #E36BD8 | lush, glass #CFF5EA, spore pink |
| L4 | Server Fortress | #2B3A67 | #243158 | #151C3A | #3A4CA0 | #39F5FF | dark, neon cyan, violet #7B5CFF LEDs |
| L5 | OVERMIND Core | #3A1840 | #2F1236 | #1B0A24 | #6B1E5E | #FF2E7E | dark purple, magenta glow, boss red |

Floors are kept low contrast and mid-light (L1-L3) or dark-but-not-black (L4-L5) so characters, loot and projectiles pop. Never use a floor color that matches a pickup color at full saturation.

## 3. Lighting and effects
- Light direction top-left, shade bottom-right, highlight dot top-left on rounded objects.
- Level ambience is applied in code (SKLightNode off for MVP; use a multiply color tint per theme at 0-15 percent), not baked into sprites.
- Hit: white tint (colorBlendFactor 0.85, 0.4, 0.0 over 0.1 s) plus a **particle** sparkle at the impact point (section 12). The `fx_hitflash` frames are not used in the MVP.
- Defeat: **particle** poof (stars, chips, sparkles, ring; 0.4 s) while the sprite scales down and fades (section 12). `fx_poof`/`fx_sparkles` frames stay in the atlas as optional textures (particles may use `fx_sparkles_01`).
- Projectiles and Pixel carry their own soft glow; no other dynamic lights.

## 4. Grid, sizes and units
- **Tile = 64 pt = 128 px @2x.** Level geometry is a 64 pt grid.
- **Tile textures cover 4x4 cells** (`TILE_REPEAT = 4` in `tools/asset_manifest.py`): each `tile_lN_floor/wall` file is 256 pt = 512 px @2x (the full seamless Gemini image, which is itself a 4x4 panel grid); each 64 pt cell samples a 1/4 sub-rect (use texture sub-rects, wrap by cell coordinate mod 4). Atlas stays under 4096 px.
- Assets are authored and shipped **@2x only** (iPad Retina is 2x), files named `...@2x.png`. pixels = pt x 2. AI images are generated larger and downscaled by `slice_atlas.py`.
- Sprite anchor: characters bottom-center (feet on the tile ground line, anchor (0.5, 0.1)); everything else center.
- **Wall vs floor contrast (kids must see where they cannot walk).** Luminance = mean of the grayscale value (0-255) of the 512 px texture. Light floors (lum >= 110): wall lum must be **<= 65 % of the floor lum** (target 60 %). Dark floors (lum < 110, L4/L5): wall lum must be **>= floor lum + 35** (target +40), i.e. walls glow lighter. `slice_atlas.py` enforces this automatically for wall sheets (gain on RGB + 15 % saturation boost; floor sheets must be sliced first, default order does; `WALL_CONTRAST = False` disables). Result (floor / wall lum, before -> after): L1 184 / 126 -> 110, L2 155 / 84 (ok, unchanged), L3 188 / 142 -> 112, L4 59 / 49 -> 98, L5 48 / 51 -> 87.
- **Code-side wall treatment (spec for swift-coder).** (1) On every floor cell that touches a wall cell, draw an inner shadow strip on the floor side: 10 pt wide on the edge facing the wall, color #2B2140 at 22 % alpha (zPosition just above floor, below props). (2) Each wall cell (and each 2x2 pillar) gets a 3 pt #2B2140 outline on the sides that face floor (not between two wall cells). (3) Rim lift (revised M2 polish, replaces the old "top edge of every wall cell" strip, which drew a stray line through the middle of thick walls such as the L3 hedges): a **3 pt strip in the level "wall top" color at 45 % alpha (L3: 30 %)**, drawn **only on the side of a wall cell that directly faces a floor cell** (any of the four sides), placed **inside the cell, flush against the 3 pt outline** (strip occupies 3 to 6 pt from the cell edge). It is never drawn on a side that touches another wall cell, so it can never appear in the interior of a thick wall. Pillars use the wall texture, so they get the same treatment. Skip it entirely if it costs more than one extra node per wall edge: merge runs of the same side into one rectangle. Pillars use the wall texture, so they get the same treatment.
- Collision radius (for Swift coder): about 40 percent of sprite width, centered at the feet area. Not tied to the sprite box.

| Category | Size (pt) | Pixels @2x | Notes |
|---|---|---|---|
| hero | 64x64 | 128x128 | about 1 tile; head about 28 pt |
| pixel | 48x48 | 96x96 | floats at hero's shoulder |
| enemy: boltbot, laserdrone, slimemutant, sporeplant | 56x56 | 112x112 | |
| enemy: slimemutant_small | 40x40 | 80x80 | |
| enemy: shieldandroid | 64x64 | 128x128 | |
| boss megamech | 192x192 | 384x384 | 3x3 tiles |
| proj | 16x16 | 32x32 | |
| pickup | 32x32 | 64x64 | energycore 40x40 / 80x80 |
| puzzle button/lever/pressureplate/door | 64x64 | 128x128 | 1 tile |
| puzzle machine | 128x128 | 256x256 | 2x2 tiles |
| tile | 64x64 | 128x128 | full bleed, seamless |
| fx hitflash | 48x48 | 96x96 | |
| fx poof, sparkles | 64x64 | 128x128 | |
| ui joystick base / knob | 160 / 72 | 320 / 144 | |
| ui buttons | fire 96, inventory/reload/interact/swap 72, pause 64 | x2 | circular |
| ui quickslot | 72x72 | 144x144 | |
| ui invslot | 64x64 | 128x128 | |
| ui hpbar bg / fill | 240x28 / 232x20 | 480x56 / 464x40 | fill is scaled horizontally in code |
| ui icons | 32x32 | 64x64 | |
| app icon | 1024x1024 px | | opaque, no text |

## 5. Animation frame lists
Frame rate (full-animation set, later; MVP uses section 12): 12 fps for walk/shoot, 6-8 fps for idle (0.12-0.15 s per frame), hit 2 frames at 0.05 s each, poof/sparkles 6 frames at 0.07 s.
| Anim | Frames | Used by |
|---|---|---|
| idle | 4 | hero, pixel, all enemies, boss |
| walk | 6 | hero, boltbot, slimemutant(+small), shieldandroid, boss |
| shoot | 3 | hero, laserdrone, shieldandroid, sporeplant, boss (aim, fire/recoil, recover) |
| talk | 3 | pixel |
| hit | 2 | hero, every enemy, boss |
| charge | 4 | boss telegraph |
| defeat | 6 | boss power-down (regular enemies use the particle poof instead) |
| fx hitflash | 3 | impact |
| fx poof / sparkles | 6 | defeat, teleport |
| door opening | 4 | puzzle door |
| tile floor variants | 3 | per theme (random pick) |
| tile wall variants | 2 | per theme |
Hero and Pixel teleport (checkpoint rescue) reuse the particle poof (section 12). Hit-flash is code (color blend); `hit` frames are not used in the lite set. Lite set: every anim frame is a copy of `_01`, so PoseAnimator uses `<prefix>_idle_01` plus procedural motion (section 12); frame playback is behind an off-by-default flag.

## 6. Naming convention (exact)
```
<category>_<name>_<anim>_<NN>@2x.png
```
- `category`: `hero | pixel | enemy | boss | proj | pickup | puzzle | tile | fx | ui`
- `name`: asset id, lowercase, underscores allowed inside (`slimemutant_small`, `food_apple`, `ammo_spread`). **Omitted for `hero` and `pixel`** (`hero_idle_01@2x.png`, `pixel_talk_02@2x.png`).
- `anim`: `idle|walk|shoot|talk|hit|charge|defeat|opening` or a state/variant word (`off|on|open|closed`, tile `floor|wall`). Omitted for single-state sprites (`proj_starter@2x.png`, `pickup_keycard@2x.png`, `ui_btn_fire@2x.png`, `fx_poof_01@2x.png`).
- `NN`: 2-digit frame number **starting at 01**. Omitted when the group has only one frame.
- Tiles: `name` is the theme (`l1`..`l5`), `anim` is `floor` or `wall`: `tile_l3_floor_02@2x.png`.
- Examples: `enemy_boltbot_walk_03@2x.png`, `enemy_slimemutant_small_idle_01@2x.png`, `boss_megamech_charge_04@2x.png`, `puzzle_door_open@2x.png`, `puzzle_door_opening_02@2x.png`, `ui_icon_blaster_rapid@2x.png`.
- In SpriteKit load with the name **without** `@2x.png`: `SKTexture(imageNamed: "enemy_boltbot_walk_03")` or `SKTextureAtlas(named: "enemies")`. Atlas folder: `Strike/Resources/Atlases/<atlas>.atlas/`.
- Raw art folders in `art/raw/` are named by **group key** = the file name without frame number (`enemy_boltbot_walk`, `proj_starter`, `tile_l1_floor`).

### Atlases
`hero`, `pixel`, `enemies` (enemy_*), `boss`, `items` (proj_* + pickup_*), `puzzle`, `tiles` (all five themes), `fx`, `ui`. Total 217 PNG files for the MVP (206 + bolt, datachip, 3 blaster pickups, crate x2, checkpoint x2, exitpad x2).

## 7. HUD layout spec (iPad landscape)
Reference: iPad Pro 11 landscape, 1194 x 834 pt (also design-safe for 1024 x 768 and 1366 x 1024). Origin top-left in this table (SpriteKit camera child nodes use bottom-left; convert). Respect the **safe area** (`safeAreaInsets`, side insets about 20 pt, bottom about 20 pt for the home indicator) plus a **16 pt** inner margin. All touch targets **at least 64 x 64 pt** (kids; GDD), at least 12 pt between neighboring targets. Nothing important in the top-center 120 pt (Pixel hint bubble).

| Element | Position (from safe-area edge) | Size (pt) | Touch target | Asset |
|---|---|---|---|---|
| Move joystick (floating, appears where the left thumb lands in the left 45 percent of the screen, below the top 15 percent) | default center: left +120, bottom +120 | visual base 140, knob 64, max travel radius 70 | whole left 45% x lower 85% zone | `ui_joystick_base`, `ui_joystick_knob` |
| Aim stick with **auto-fire** (floating, right 45 percent, below the top 15 percent): drag direction = aim, holding the drag fires; no Fire button | default center: right +120, bottom +120 | visual base 140, knob 64, max travel radius 70 | whole right 45% x lower 85% zone | `ui_joystick_base`, `ui_joystick_knob` |
| Reload button | right +24, bottom +252 | 72 | 72 | `ui_btn_reload` |
| Interact button (shown only near an interactable) | right +24, bottom +164 | 72 | 72 | `ui_btn_interact` |
| Swap blaster button | right +24, bottom +340 | 72 | 72 | `ui_btn_swap` |
| HP bar (+ `ui_icon_heart` 32 at its left) | left +16, top +16 | 240 x 28 (+ fill 232 x 20 inset 4) | display only | `ui_hpbar_bg`, `ui_hpbar_fill`, `ui_icon_heart` |
| Ammo readout (blaster icon 32 + ammo icon 32 + number, system rounded font) | left +16, top +52 | about 160 x 36 | display only | `ui_icon_blaster_*`, `ui_icon_ammo` |
| Pause button | right +16, top +16 | 64 | 64 | `ui_btn_pause` |
| Inventory button | right +96, top +16 | 72 | 72 | `ui_btn_inventory` |
| Quick slots (4, horizontal row, bottom center) | centered, bottom +16, gap 12 | 72 each (row 324 wide) | 72 each | `ui_quickslot`, `ui_quickslot_sel` |
| Key / item chips (keycard, fuse, battery, energycore) | left +16, top +92, vertical stack, gap 8 | 40 | display only | pickup sprites at 0.8x |
| Pixel hint bubble | top center, top +16 | max 420 x 90, avatar `ui_icon_pixel` 32 | tap to dismiss, 64 high | `ui_icon_pixel` |

Rules:
- Joystick is floating (appears under the thumb); the drawn base is only a visual, the touch zone is the entire left zone. The aim zone on the right must not overlap the button targets: button areas (SwiftUI HUD overlay) swallow touches first; the sticks are handled in the SpriteKit scene. Values mirror `hero.json -> controls`. The reload/interact/swap column sits at the right edge (x from right +24 to +96), above the aim stick's default spot, so a resting right thumb does not hit it; `ui_btn_fire` is unused.
- Quick slots must not sit under the fire cluster: with the bottom-center row 324 wide the screen center +/-162 is reserved; the right button column stays at least 180 pt from the center.
- Inventory screen (25 slots): 5 x 5 grid of `ui_invslot` 64 pt with 8 pt gap = 352 x 352, centered; left of it the 4 quick slots drop targets, right of it item info panel (260 x 352). Close button 64 x 64 top right of the panel.
- Fonts: SF Rounded, white text with #2B2140 2 pt stroke/shadow for readability; all strings localized (de, en). No text is baked into any sprite.
- Contrast: all HUD elements sit on #2E2A55 panels at 85 percent alpha or have a plum outline.
- Opacity: joystick and buttons at 70 percent alpha idle, 100 percent while pressed (scale 0.92 on press, no separate pressed sprite).

## 8. Pipeline
1. `python3 -I tools/make_placeholders.py [--only ATLAS|GROUP_PREFIX]` regenerates placeholders (cute shapes, exact names and sizes) so code is never blocked.
2. Owner generates the 35 lite-set images with `art/prompts/gemini/PROMPTS.md` in the Gemini web app and saves each as `art/raw/<sheet>.png` (one file per prompt, no folders).
3. `python3 tools/slice_atlas.py [sheet ...]` removes the background, splits the sheet into objects, trims, scales to spec, renames and overwrites the placeholders in the atlas. `--report` lists which sheets are present or missing; `--debug` writes `<sheet>_debug.png` with the detected object boxes. Needs Pillow (`python3 -m pip install --user pillow`). Self-test: `python3 -I tools/test_slice.py`.
4. Verify against section 9, log the generator and date in `art/LICENSES.md`.

## 9. Full MVP asset list (206 files before the lite-set additions, see section 11 for the 11 new ones)
Ids: hero, pixel; enemies boltbot, laserdrone, slimemutant, slimemutant_small, shieldandroid, sporeplant; boss megamech; projectiles starter, spread, rapid, enemy; pickups healpack, food_apple, food_onigiri, food_cookie, ammo_starter, ammo_spread, ammo_rapid, fuse, battery, keycard, energycore; puzzle button, lever, pressureplate, machine, door (closed, opening, open); tiles l1-l5 floor/wall; fx hitflash, poof, sparkles; ui.

| Atlas | Group key (file prefix) | Frames | Size pt | Size px @2x | Align |
|---|---|---|---|---|---|
| hero | `hero_idle` | 4 | 64x64 | 128x128 | bottom |
| hero | `hero_walk` | 6 | 64x64 | 128x128 | bottom |
| hero | `hero_shoot` | 3 | 64x64 | 128x128 | bottom |
| hero | `hero_hit` | 2 | 64x64 | 128x128 | bottom |
| pixel | `pixel_idle` | 4 | 48x48 | 96x96 | center |
| pixel | `pixel_talk` | 3 | 48x48 | 96x96 | center |
| enemies | `enemy_boltbot_idle` | 4 | 56x56 | 112x112 | bottom |
| enemies | `enemy_boltbot_walk` | 6 | 56x56 | 112x112 | bottom |
| enemies | `enemy_boltbot_hit` | 2 | 56x56 | 112x112 | bottom |
| enemies | `enemy_laserdrone_idle` | 4 | 56x56 | 112x112 | bottom |
| enemies | `enemy_laserdrone_shoot` | 3 | 56x56 | 112x112 | bottom |
| enemies | `enemy_laserdrone_hit` | 2 | 56x56 | 112x112 | bottom |
| enemies | `enemy_slimemutant_idle` | 4 | 56x56 | 112x112 | bottom |
| enemies | `enemy_slimemutant_walk` | 6 | 56x56 | 112x112 | bottom |
| enemies | `enemy_slimemutant_hit` | 2 | 56x56 | 112x112 | bottom |
| enemies | `enemy_slimemutant_small_idle` | 4 | 40x40 | 80x80 | bottom |
| enemies | `enemy_slimemutant_small_walk` | 6 | 40x40 | 80x80 | bottom |
| enemies | `enemy_slimemutant_small_hit` | 2 | 40x40 | 80x80 | bottom |
| enemies | `enemy_shieldandroid_idle` | 4 | 64x64 | 128x128 | bottom |
| enemies | `enemy_shieldandroid_walk` | 6 | 64x64 | 128x128 | bottom |
| enemies | `enemy_shieldandroid_shoot` | 3 | 64x64 | 128x128 | bottom |
| enemies | `enemy_shieldandroid_hit` | 2 | 64x64 | 128x128 | bottom |
| enemies | `enemy_sporeplant_idle` | 4 | 56x56 | 112x112 | bottom |
| enemies | `enemy_sporeplant_shoot` | 3 | 56x56 | 112x112 | bottom |
| enemies | `enemy_sporeplant_hit` | 2 | 56x56 | 112x112 | bottom |
| boss | `boss_megamech_idle` | 4 | 192x192 | 384x384 | bottom |
| boss | `boss_megamech_walk` | 6 | 192x192 | 384x384 | bottom |
| boss | `boss_megamech_shoot` | 3 | 192x192 | 384x384 | bottom |
| boss | `boss_megamech_charge` | 4 | 192x192 | 384x384 | bottom |
| boss | `boss_megamech_hit` | 2 | 192x192 | 384x384 | bottom |
| boss | `boss_megamech_defeat` | 6 | 192x192 | 384x384 | bottom |
| items | `proj_starter` | 1 | 16x16 | 32x32 | center |
| items | `proj_spread` | 1 | 16x16 | 32x32 | center |
| items | `proj_rapid` | 1 | 16x16 | 32x32 | center |
| items | `proj_enemy` | 1 | 16x16 | 32x32 | center |
| items | `pickup_healpack` | 1 | 32x32 | 64x64 | center |
| items | `pickup_food_apple` | 1 | 32x32 | 64x64 | center |
| items | `pickup_food_onigiri` | 1 | 32x32 | 64x64 | center |
| items | `pickup_food_cookie` | 1 | 32x32 | 64x64 | center |
| items | `pickup_ammo_starter` | 1 | 32x32 | 64x64 | center |
| items | `pickup_ammo_spread` | 1 | 32x32 | 64x64 | center |
| items | `pickup_ammo_rapid` | 1 | 32x32 | 64x64 | center |
| items | `pickup_fuse` | 1 | 32x32 | 64x64 | center |
| items | `pickup_battery` | 1 | 32x32 | 64x64 | center |
| items | `pickup_keycard` | 1 | 32x32 | 64x64 | center |
| items | `pickup_energycore` | 1 | 40x40 | 80x80 | center |
| puzzle | `puzzle_button_off` | 1 | 64x64 | 128x128 | center |
| puzzle | `puzzle_button_on` | 1 | 64x64 | 128x128 | center |
| puzzle | `puzzle_lever_off` | 1 | 64x64 | 128x128 | center |
| puzzle | `puzzle_lever_on` | 1 | 64x64 | 128x128 | center |
| puzzle | `puzzle_pressureplate_off` | 1 | 64x64 | 128x128 | center |
| puzzle | `puzzle_pressureplate_on` | 1 | 64x64 | 128x128 | center |
| puzzle | `puzzle_machine_off` | 1 | 128x128 | 256x256 | center |
| puzzle | `puzzle_machine_on` | 1 | 128x128 | 256x256 | center |
| puzzle | `puzzle_door_closed` | 1 | 64x64 | 128x128 | center |
| puzzle | `puzzle_door_opening` | 4 | 64x64 | 128x128 | center |
| puzzle | `puzzle_door_open` | 1 | 64x64 | 128x128 | center |
| tiles | `tile_l1_floor` | 3 | 64x64 | 128x128 | center |
| tiles | `tile_l1_wall` | 2 | 64x64 | 128x128 | center |
| tiles | `tile_l2_floor` | 3 | 64x64 | 128x128 | center |
| tiles | `tile_l2_wall` | 2 | 64x64 | 128x128 | center |
| tiles | `tile_l3_floor` | 3 | 64x64 | 128x128 | center |
| tiles | `tile_l3_wall` | 2 | 64x64 | 128x128 | center |
| tiles | `tile_l4_floor` | 3 | 64x64 | 128x128 | center |
| tiles | `tile_l4_wall` | 2 | 64x64 | 128x128 | center |
| tiles | `tile_l5_floor` | 3 | 64x64 | 128x128 | center |
| tiles | `tile_l5_wall` | 2 | 64x64 | 128x128 | center |
| fx | `fx_hitflash` | 3 | 48x48 | 96x96 | center |
| fx | `fx_poof` | 6 | 64x64 | 128x128 | center |
| fx | `fx_sparkles` | 6 | 64x64 | 128x128 | center |
| ui | `ui_joystick_base` | 1 | 160x160 | 320x320 | center |
| ui | `ui_joystick_knob` | 1 | 72x72 | 144x144 | center |
| ui | `ui_btn_fire` | 1 | 96x96 | 192x192 | center |
| ui | `ui_btn_reload` | 1 | 72x72 | 144x144 | center |
| ui | `ui_btn_interact` | 1 | 72x72 | 144x144 | center |
| ui | `ui_btn_swap` | 1 | 72x72 | 144x144 | center |
| ui | `ui_btn_pause` | 1 | 64x64 | 128x128 | center |
| ui | `ui_btn_inventory` | 1 | 72x72 | 144x144 | center |
| ui | `ui_quickslot` | 1 | 72x72 | 144x144 | center |
| ui | `ui_quickslot_sel` | 1 | 72x72 | 144x144 | center |
| ui | `ui_invslot` | 1 | 64x64 | 128x128 | center |
| ui | `ui_invslot_sel` | 1 | 64x64 | 128x128 | center |
| ui | `ui_hpbar_bg` | 1 | 240x28 | 480x56 | center |
| ui | `ui_hpbar_fill` | 1 | 232x20 | 464x40 | center |
| ui | `ui_icon_heart` | 1 | 32x32 | 64x64 | center |
| ui | `ui_icon_ammo` | 1 | 32x32 | 64x64 | center |
| ui | `ui_icon_star` | 1 | 32x32 | 64x64 | center |
| ui | `ui_icon_blaster_starter` | 1 | 32x32 | 64x64 | center |
| ui | `ui_icon_blaster_spread` | 1 | 32x32 | 64x64 | center |
| ui | `ui_icon_blaster_rapid` | 1 | 32x32 | 64x64 | center |
| ui | `ui_icon_pixel` | 1 | 32x32 | 64x64 | center |

Outside the atlases: `Strike/Resources/Assets.xcassets` AppIcon (1024 px).

## 10. Per-asset art direction (short)
- **Hero**: kid, messy brown hair, orange headband, blue jacket, white gloves, orange toy blaster with glowing tip.
- **Pixel**: cyan ball drone, propeller, dark screen face with cyan eyes, glow.
- **Boltbot**: light blue-gray boxy robot on a wheel base, red visor eye, orange antenna bulb. Melee/rammer.
- **Laserdrone**: purple flying orb, big eyeball, wing panels. Ranged, fires red-magenta shots.
- **Slimemutant / small**: lime jelly blob, googly eyes. Small = split-off baby at 40 pt.
- **Shieldandroid**: silver humanoid with teal energy shield on the front (east) side.
- **Sporeplant**: stationary pink bulb on a green stem, shoots spore puffs.
- **Boss megamech**: 3x3 tiles, violet-blue armor, magenta core, red eye, orange fists.
- **Puzzle**: red = off, green = on, same plate/frame silhouette for both states.

## 11. Lite art set (Gemini) and background colors
Decision: art is generated with the Gemini web app, **one key pose per character** (35 images, `tools/asset_manifest.py` `SHEETS`, prompts in `art/prompts/gemini/PROMPTS.md`). Code animates the pose (`PoseAnimator`: bob, squash, tilt, recoil, flip, white hit flash). The key pose is the existing first-frame name (`hero_idle_01`, `enemy_boltbot_idle_01`, ...). The slicer copies it into every other frame and anim of that character (walk, shoot, hit, talk, charge, defeat) so any code path that loads those names still gets consistent art. Full animations stay in the manifest as "later": replace the PNGs, no renaming.

**New assets (added to the manifest, 64 px px = pt x 2 as usual):**
| Group key | Size pt | Notes |
|---|---|---|
| `pickup_bolt` | 32 | silver hex nut, magnet pickup, +10 score |
| `pickup_datachip` | 32 | cyan memory chip, +250 score |
| `pickup_blaster_starter/spread/rapid` | 32 | chunky toy blaster, weapon pickup (orange / purple / yellow) |
| `puzzle_crate_whole`, `puzzle_crate_broken` | 64 | supply box and its smashed state |
| `puzzle_checkpoint_off/on` | 64 | round pad, gray-blue then glowing green |
| `puzzle_exitpad_off/on` | 64 | round pad with white arrow, dim red then glowing green |

**Sheets:** characters 9 (hero, pixel, 6 enemies, boss), `projectiles`, `pickups_heal|ammo|keys|blasters`, 8 puzzle pairs (`puzzle_<name>`, off | on), 10 tiles (`tile_l1..l5_floor|wall`), `ui_icons_a|b`, `appicon`. Code-drawn (no art): joystick, quick/inventory slots, HP bar, hit flash and poof FX (particles). Their placeholders stay until M1 replaces them in code.

**Derived by the slicer:** `puzzle_door_opening_01..04` (cross-fade closed to open); tile variants (floor: 0/90/180 degree rotations, wall: mirrored); every anim frame of a character.

**Background colors for generated sheets** (Gemini cannot do transparency or exact hex): default **bright green**; **bright magenta** for green or pink subjects (slimes, spore-plant, heal/food/key items, all on/off puzzle pairs because the ON state is green). Tiles and the app icon are full-bleed (no background). The slicer samples the border, flood-fills from the edges with a tolerance, erodes the fringe, despills, and ignores a small corner watermark (Gemini sparkle). Subjects must not use the background color; keep a plum outline around everything so the edge stays clean.

**Lite-set sizes** are the table in section 4 unchanged; `ui_btn_*` are cut from `ui_icons_a` and `ui_icon_*` from `ui_icons_b` (7 icons, 4x2 grid, last cell empty). The app icon is written as `Strike/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png` (1024 px, opaque RGB) and `Contents.json` gets its `filename`.

## 12. PoseAnimator feel (M1, lite set)
Characters use the single key pose `<prefix>_idle_01` and are animated procedurally on the sprite node. All values are meant to be copied into `PoseStyle`. Sprite anchor is at the feet (anchorPoint y = 0.0 to 0.15) so squash and bob grow from the ground. `s` = current speed / max speed of that character (0...1). Angles in degrees, lengths in pt, times in seconds. Scale values are multipliers of the base scale.

### Idle (s < 0.05)
| Part | Value |
|---|---|
| Bob | vertical offset sine, amplitude 2 pt (hero, enemies), 3 pt (Pixel, floating), 4 pt (boss); period 1.2 s (hero), 1.4 s (boltbot), 1.8 s (Pixel), 2.4 s (boss) |
| Breathing | yScale 1.0 to 1.03, xScale 1.0 to 0.985, same period, in phase with the bob |
| Phase | random start phase per node so groups do not bob in sync |
| Shadow | not animated (baked) |

### Walk (s >= 0.05)
| Part | Value |
|---|---|
| Cadence | step frequency = 2.2 + 2.2 * s steps per second (hero at full speed about 4.4 steps/s, period 0.23 s); boltbot uses 3.0 steps/s flat while chasing (hop feel) |
| Hop | vertical offset abs(sin) with amplitude 3 pt * (0.4 + 0.6 s); boltbot 4 pt |
| Squash and stretch | on each step: yScale 1.0 + 0.08 at the hop apex, 1.0 - 0.08 at the landing; xScale is the inverse (1.0 - 0.06 / 1.0 + 0.06). Boss: 0.03 instead of 0.08 |
| Tilt | zRotation sways +-4 degrees (hero), +-6 (boltbot), +-2 (boss) in step with the cadence, plus a lean of 3 degrees * s toward the movement direction in x (positive x = tilt clockwise, i.e. negative zRotation). Tilt is the only allowed rotation and never exceeds 10 degrees total |
| Blend | ease in/out between idle and walk over 0.12 s |
| Slime and creatures | slow wobble instead of hop: cadence 2 steps/s, squash 0.12, no tilt |

### Facing flip
- Sprites are drawn facing east. Facing = sign of the **aim direction while aiming, else the move direction**; hold the last facing when both are zero.
- West: `xScale = -abs(xScale)`, east: `+abs(xScale)`. Never rotate the sprite to face. Put squash on a child "pose" node so the flip on the parent is not disturbed.
- Hysteresis: only flip when abs(dx) > 0.2 of the vector length (avoids flicker when aiming straight up/down). Flip is instant (no tween). Weapon muzzle offset uses the same mirrored x.

### Shoot recoil
- On each shot: the pose node is pushed 3 pt opposite to the aim direction (hero), 2 pt for enemies, 5 pt for the boss, and returns with easeOut.
- Timing: out 0.04 s, back 0.10 s. For rapid fire (shots closer than 0.14 s apart) cut to 1.5 pt and out 0.03 / back 0.06 so it does not accumulate. Never accumulate more than 4 pt of total offset.
- Plus a tiny muzzle pop: yScale 0.96 for 0.05 s. A muzzle sparkle (see particles) of 4 particles in the projectile color.

### Hit
| Part | Value |
|---|---|
| Flash | colorBlendFactor 0.85 white at once, then 0.4 at 0.05 s, then 0.0 at 0.10 s (total 0.1 s). Use white, never red |
| Shake | horizontal offset sequence +4, -4, +2, -2, 0 pt, 0.02 s each (0.1 s) on the pose node. Boss: 2 pt (heavier). Direction of the first nudge is away from the hit |
| Knockback | handled by physics (JSON); visual stretch: xScale 1.1 / yScale 0.92 for 0.08 s |
| Hero invulnerability | after a hit, alpha blinks 1.0 / 0.4 every 0.08 s for the invulnerability window (JSON), no color change |
| Rules | no screen red vignette, no damage numbers in red; use white or yellow |

### Power-down (enemy defeat)
1. t = 0.00: freeze AI, white flash 0.85 held for 0.08 s, burst particles start (see Poof).
2. t = 0.00 to 0.35: pose scale to 0.0 with easeIn (anchor at the sprite center for this step), zRotation spins +-180 degrees, alpha 1.0 to 0.0 over the last 0.15 s.
3. t = 0.35: remove node; loot pops out (arc 0.25 s, 24 pt high) as separate nodes. Total 0.4 s. Boss: 1.2 s with 3 white flashes and a bigger poof (x3 counts).
No dead bodies stay on the floor.

### Particles (SKEmitterNode or manual SKSpriteNodes, texture `fx_sparkles_01` or a generated 8 x 8 white star/circle; colorBlendFactor 1.0 to tint)
Common rules: no red or dark-red tints on enemy hits except OVERMIND enemy shots (#FF3B5C is allowed for **enemy projectile** impact only, as a bright spark, never on the hero). Use `blendMode = .add` for sparkles. zPosition above characters. Pool and cap at 120 live particles.

| Effect | Colors (palette) | Count | Lifetime | Speed (pt/s) | Size (pt, start to end) | Notes |
|---|---|---|---|---|---|---|
| Hit sparkle (blaster impact) | white #FFFFFF + projectile color: starter #FF8A3D, spread #B05CFF, rapid #FFD93D | 6 (rapid 4) | 0.25 s (0.20 rapid) | 120 to 200, random angle in a 140 degree cone away from the shot, gravity 0 | 8 to 0 | alpha 1 to 0, spawn at the impact point |
| Hit on hero (enemy contact or shot) | white + #FFD93D | 5 | 0.25 s | 100 to 160, full circle | 8 to 0 | no red |
| Muzzle sparkle | projectile color + white | 4 | 0.15 s | 80 to 140, 60 degree cone along aim | 6 to 0 | at the blaster tip |
| Poof (power-down, regular enemy) | stars #FFD93D and #FFFFFF; bolts #A9BCE0 / #C9D2EA (robots) or slime #6FE06A / #8CF07F, spore #E36BD8 / #FFB3F2 (creatures); sparkles #BFFFF7 | 14 total: 6 stars, 4 body-colored chips, 4 sparkles | 0.5 s | 90 to 220, full circle, small gravity of -60 on chips (they fall slightly), rotation speed +-6 rad/s | 12 to 0 (stars), 8 to 0 (chips), 6 to 0 (sparkles) | plus one expanding ring: white circle alpha 0.6, scale 0.3 to 1.4 over 0.3 s |
| Boss power-down | same as poof, 3 bursts 0.25 s apart | 14 each, size x1.5 | 0.7 s | up to 300 | | camera shake 3 pt for 0.3 s |
| Pickup collect | #FFD93D + white | 6 | 0.3 s | 60 to 120, upward bias | 6 to 0 | item flies 20 pt up while scaling to 0 in 0.15 s |
| Heal | #5FE08A + white | 8 | 0.5 s | 40 to 80, rising | 8 to 0 | hearts or plus shapes are allowed |
| Teleport/spawn (Pixel, hero) | #3DE3D0 + #BFFFF7 | 12 | 0.5 s | 100 to 200 inward-then-out | 8 to 0 | |

### Misc timings
- Alert "!" above an enemy: pop scale 0.0 to 1.2 to 1.0 in 0.15 s, held to 0.4 s total, color #FFD93D with #2B2140 outline.
- Projectile: no animation, spawn scale 0.6 to 1.0 in 0.05 s; trail optional (2 faded copies at 0.04 s spacing, alpha 0.4 and 0.2).
- All motion uses SKAction timing modes (easeOut for impulses, easeInEaseOut for sways); nothing may exceed 4 simultaneous tweens per node.

## 13. Level presentation (M2)
All values are pt unless noted, zPosition numbers are relative (world layers: floor 0, wall shadow strip 1, floor props / pads / plates 2, loot 3, doors / buttons / levers / machines 4, characters 5+, projectiles 8, FX 9). Colors from section 2. Every value belongs in `rules.json` or a Swift constant named after the row, never inline magic numbers.

### 13.1 Minimap
**Placement (HUD camera child, origin top-right).** Panel 160 x 120, right inset +16 from the safe-area edge, top +96 (below the pause button 64 at top +16, gap 16). Reasons: top-center 120 pt stays free for Pixel's bubble (max 420 wide; on 1194 wide the bubble spans x 387-807, the panel starts at about x 998; on 1024 wide 302-722 vs 828); the key chips (left +16, top +92) and the interact/reload/swap column (right +24, bottom +164 to +412) do not collide (panel bottom is at top +216; on 768 high the column top is at y 356 from top, the panel ends at 216). GDD §3.1 "top-centre" is superseded by this (DECISIONS). The panel is display-only (`isUserInteractionEnabled = false`), so the right aim zone below it keeps working under it.
| Part | Value |
|---|---|
| Panel | 160 x 120, corner radius 12, fill #1E1B3D at 80 % alpha, 2 pt stroke #4A4585 (light UI panel), z above world HUD |
| Inner map area | panel inset 6 on all sides = 148 x 108 |
| Map scale | `cellPt = floor(min(148 / gridW, 108 / gridH) * 2) / 2`, minimum 2.0, centered in the inner area; one cell = `cellPt` square. 48 x 32 grid gives 3.0 pt |
| Render | one `SKSpriteNode` with a texture redrawn (CoreGraphics, 2x) only when a room / corridor is revealed or a door / element changes; marker nodes (hero, pulse) update at 10 Hz. No per-frame redraw |
| Fog of war | unrevealed cells draw nothing (panel color shows through). Revealed room: all its cells, on first entry. Revealed corridor: cells within 3 cells of the hero's cell (Chebyshev), stays revealed. Walls are not drawn; the revealed floor area is the map. Revealed state persists in `LevelSession.revealedRoomIds` (+ corridor cell set) |
| Room floor | #C9D2EA at 90 % alpha |
| Corridor floor | #8FA3C8 at 90 % alpha |
| Room edge | 1 pt #4A4585 around the outer boundary of revealed cells (cheap: draw wall-adjacent edges only) |
| Hero | circle 7 pt diameter, #3D8BFF fill, 1.5 pt white outline; pulse scale 1.0 to 1.3 to 1.0 over 1.0 s, easeInEaseOut, forever; always above everything else, clamped to the inner area |
| Door closed | bar across the corridor width: `cellPt * corridorWidth` long, 3 pt thick (thick side across the corridor), #FF3B5C |
| Door open | same bar, #5FE08A at 70 % alpha |
| Element off (button, lever, plate, machine) | 4 pt circle #FF3B5C with 1 pt #2B2140 outline, only if its room is revealed |
| Element on | 4 pt circle #5FE08A with 1 pt #2B2140 outline |
| Checkpoint | 5 pt diamond (square rotated 45 degrees) #3DE3D0, 1 pt #2B2140 outline; hollow (fill alpha 0.25) until touched |
| Exit pad | 8 pt five-point star #FFD93D, 1 pt #2B2140 outline, shown once its room is revealed; gentle alpha pulse 0.7 to 1.0 over 1.2 s |
| Crates, loot, enemies | not shown (keeps it calm; pings are M3) |
| Draw order | floors, door bars, elements, checkpoints, exit, hero |
| Colour-blind safety | on/off are never color only: off = filled circle with no center mark, on = the same circle with a 1.5 pt white check-dot (2 pt white center). Door closed = solid bar, open = bar at 70 % with a 1 cell gap in the middle |

### 13.2 Doors across 2-3 tile corridors
- A gate or exit door covers `GatesDef.cells` (a line of `corridorWidth` cells, 2 or 3). **One `DoorNode` per gate**, containing **one 64 x 64 sprite per cell**, each placed at its cell center. Never stretch a sprite (the outline would get fat).
- Texture: `puzzle_door_closed / opening_01..04 / open`. All cells of a door use the same texture at the same time, but the frame is played with a **stagger of 0.04 s from the outer cell to the cell next to the other wall** (cell i starts at i * 0.04 s), so a 3-wide door ripples open. Opening total 4 frames x 0.07 s = 0.28 s (plus stagger up to 0.08 s); closing plays the frames in reverse.
- Orientation: the art is drawn for a corridor running **west-east** (the door blocks east-west travel, the panel seam is vertical). For a **north-south** corridor (door blocks vertical travel) set `zRotation = pi / 2` on each sprite (allowed, doors are objects, section 1). Rotation is on the sprite, not on the DoorNode, so lights and counter stay upright.
- Sprites touch exactly at cell borders (no gap, no overlap). The outer outline between two door cells is intentional and reads as one wide door of several panels. Cells at the corridor sides sit against wall cells, so no extra frame is needed.
- Seam hiding: none needed. Optional: 4 pt #2B2140 strip, 100 % alpha, along both ends of the door (the sides touching walls) is **not** used (walls already have outlines per section 4).
- Open door: the sprite shows `puzzle_door_open` (retracted panels). It stays 64 x 64 per cell, z 2 (floor prop) so characters walk over it. Closed door z 4. Physics body: one rectangle spanning all cells, removed when open.
- **Lights and counter** (code nodes, one set per DoorNode, centered on the door's middle cell or, for 2-wide, on the shared edge of the two cells, 40 pt above the door's long axis center, outside the corridor line so it is never hidden by the hero):
  - Lights: one circle per required element, 10 pt diameter, 4 pt gap, row centered. Off #FF3B5C, on #5FE08A, 1.5 pt #2B2140 outline, on-state gets a 3 pt soft halo (circle 16 pt, same color, alpha 0.35, additive). Maximum 6 lights; above 6 show only the counter.
  - Counter: "3 / 5" (on / total) in SF Rounded bold 16 pt, white, 2 pt #2B2140 stroke, centered 14 pt above the lights, on a plum pill 56 x 22 (#2E2A55 at 85 %). Upright for both orientations (rotate nothing). Numbers are not localized text; no word is drawn.
  - Counter hidden while the hero is farther than 6 tiles from the door and the door is closed, alpha 0 to 1 over 0.2 s; always shown (alpha 0.5) once open for 1.0 s then fades out.
  - The counter pops (scale 1.0 to 1.25 to 1.0 in 0.2 s) when an element turns on; on the last one a white flash on all door cell sprites (colorBlendFactor 0.6 to 0 in 0.15 s) before the opening animation.

### 13.3 Interact focus
Exactly one interactable is the **focused** one (nearest within `interactRadius`, ties by smallest angle to the aim). Everything fades with 0.12 s alpha tweens.
| Part | Value |
|---|---|
| Focus ring on the object | circle stroke, diameter = sprite size + 12 (76 for 1-tile, 140 for the machine), line width 3, color #FFD93D with a 1.5 pt #2B2140 underlay stroke (draw the dark 6 pt ring first), z 3.5 (above floor props, below the sprite) |
| Ring animation | scale 0.95 to 1.05 and alpha 0.7 to 1.0 together, period 0.9 s, easeInEaseOut |
| Soft glow | additive circle (texture generated radial, no new art), diameter sprite size + 28, #FFD93D at 30 % alpha, same pulse |
| Arrow | none |
| Interact button (HUD, section 7) | appears with scale 0.6 to 1.0 in 0.15 s (easeOut), alpha 0 to 1; while shown, a glow ring behind it: circle 88 pt (72 + 16), #FFD93D alpha 0.5, pulse 1.0 to 1.12 over 0.8 s. Disappears with alpha 0 over 0.1 s. Icon stays `ui_btn_interact`; no text |
| Not usable (machine without item, plate already on, nothing to do) | ring color #FFFFFF at 50 % alpha instead of yellow, no pulse, interact button shown at 45 % alpha but still tappable (so the bubble in 13.5 appears) |
| Hero feedback | none beyond the above (no hero rotation) |

### 13.4 Pressure plate
Sprite `puzzle_pressureplate_off/on` (64). Plates are held down while the hero (or a box, none in M2) stands on them; hold timer from `rules.json`.
| Part | Value |
|---|---|
| Fill ring (hold timer) | arc centered on the plate, radius 26 (ring middle), line width 6, round caps, #FFD93D, starts at 12 o'clock, clockwise; track behind it: full circle radius 26 width 6 #2B2140 at 35 % alpha. Visible only while the hero stands on it or the timer runs; fades in over 0.1 s |
| Timer drain | when the hero leaves, the arc drains back to 0 over the same remaining time (it is the remaining hold time), color switches to #FF3B5C below 25 % |
| Complete | arc fills, color turns #5FE08A, sprite swaps to `_on`, pulse scale 1.0 to 1.15 to 1.0 in 0.2 s plus 6 particles (#5FE08A + white, 0.3 s) |
| Idle (off, nobody on it) | faint dashed ring radius 26, 2 pt, #FFFFFF at 30 % alpha, no animation |
| Held plate that needs hold time and counts down for a door | the door counter flashes yellow (text color #FFD93D) while the plate is held |

### 13.5 Machine "needs item" bubble
Machine sprite is 128 x 128 (2 x 2 cells). Bubble shown when the hero interacts without the item (`ActivationResult.needsItem`) and also, softly, when the focus is on a machine and the item is not in the bag.
| Part | Value |
|---|---|
| Bubble | rounded rect 56 x 44, corner radius 12, fill #FFFFFF, 3 pt #2B2140 stroke, with a 10 x 8 pt tail pointing down; centered over the machine, bottom of the tail 8 pt above the sprite's top edge (so about 72 pt above the machine's center) |
| Content | the required item sprite (`pickup_fuse`, `pickup_battery`, `pickup_energycore`, `pickup_keycard`) at 32 x 32 centered; no text. Above it nothing; if the hero already carries the item the bubble is not shown |
| Silhouette hint | the item is drawn at 100 % when the hero does not own it; if the item exists in the level but the hero lacks it, same. (No dimming rules: kids need a clear picture.) |
| Animation | pop scale 0.0 to 1.15 to 1.0 in 0.2 s (easeOut), hold 2.0 s (or while the hero stays in range, max 3.0 s), then fade out in 0.2 s. A small shake x +/- 3 pt (0.04 s each, 4 steps) on the machine sprite and a soft low "no" blip are allowed (sound is M6) |
| Bubble size scale | on a 1024 x 768 screen identical (pt based) |
| When the item is used | the item sprite flies from the hero to the machine slot in 0.25 s (easeIn, scale 1.0 to 0.6), then `puzzle_machine_on`, 8 particles (#5FE08A + white), and the machine plays a pulse 1.0 to 1.06 to 1.0 in 0.2 s |

### 13.6 Checkpoint and exit pad states
Sprites are 64 x 64, drawn top-down on the floor (z 2). All glows are code nodes using a generated radial gradient texture (white, alpha falling to 0), tinted by `color`, additive blend.
| State | Visual |
|---|---|
| Checkpoint off (not touched) | `puzzle_checkpoint_off`; static, no glow; alpha 1.0 |
| Checkpoint idle glow (off) | cyan hint: radial glow 88 pt diameter #3DE3D0 at 18 % alpha, pulse alpha 0.10 to 0.22 over 1.6 s, so kids spot it from afar. Visible even when the checkpoint is off |
| Checkpoint touched | swap to `_on`; ring burst: white circle stroke 3 pt scale 0.5 to 2.0, alpha 0.8 to 0 over 0.4 s; 10 particles (#3DE3D0 + #BFFFF7, 0.5 s); glow becomes #5FE08A at 30 %, steady pulse 0.2 to 0.35 over 1.6 s; a small "saved" star (`fx_sparkles_01` 24 pt) pops above for 0.6 s; no text |
| Exit pad off (exit door closed) | `puzzle_exitpad_off`; glow none; static. Counter style like doors is not used (the door shows it) |
| Exit pad on (exit door open) | `_on` with glow 120 pt diameter #FFD93D at 35 %, pulse alpha 0.25 to 0.45 over 1.2 s; plus 3 rising sparkles (#FFD93D + white, 6 pt, 0.8 s life, one every 0.4 s, rise 24 pt) |
| Reaching the exit pad | hero stands inside radius 28 for 0.3 s: white flash ring scale 0.5 to 2.2 alpha 0.9 to 0 over 0.4 s, then the Level complete card |
| Trigger radius (checkpoint / exit) | 28 pt from the pad center (visual radius is 32) |

### 13.7 Wall edge treatment l2 to l5 (confirmed)
Section 4 rules apply to every theme: inner shadow strip 10 pt #2B2140 at 22 %, 3 pt #2B2140 outline on wall sides that face floor, and the revised rim lift (3 pt, 45 %, only on floor-facing sides, flush inside the outline; L3 30 %). With the M1 contrast fix the wall / floor luminance is L1 110 / 184, L2 84 / 155, L3 112 / 188, L4 98 / 58, L5 87 / 47 (checked on the sliced atlas, 2026-11-22). Visually confirmed for l2 to l5 with the strip and outline: walls separate clearly from floors; L4/L5 walls read as lighter than the floor, which is intended ("glowing walls"). Polish (slice_atlas.py `WALL_CALM`): L4 and L5 walls are calmed so they do not pull the eye: detail blends toward the wall mean by k (L4 0.68, L5 0.50), saturation x0.60 / x0.75, and the luminance rule then lifts the mean (no saturation boost). Wall lum unchanged (L4 98 vs floor 58 = +40; L5 87 vs 47 = +40); detail std-dev 52.0 -> 20.2 (L4), 32.3 -> 17.5 (L5); brightest 1 % 254 -> 169 (L4), 187 -> 151 (L5); mean saturation 175 -> 121 (L4), 160 -> 118 (L5).

### 13.8 Readability test (floors L1 to L5) and results
Test: composite of 8 loot sprites (bolt, datachip, healpack, three ammo crates, keycard, fuse), the starter and the enemy shot, and the puzzle sprites (button off/on, lever, plate off/on, door, checkpoint, exit pad on) over each `tile_lN_floor_01` at 1:1 (2x). Script: scratch composite (the `tools/contact_sheet.py` is label-only; no floor compositing there).
Results before calming: every pickup (outlined 3 px, saturated) read on all floors; puzzle sprites are opaque plates (own panel, red/green lights are inside the plate) and read everywhere. Weak spots: L1 and L2 floors were busy (panel grid, rivets, L2 diamond-plate hatching, orange marks), and small 16 pt projectiles / the bolt's green dot lost contrast on L2 (hatching) and L5 (magenta glows). The enemy shot (#FF3B5C) on L5 (#3A1840) is the lowest contrast pair.
Fix (applied in `tools/slice_atlas.py`, `FLOOR_CALM`): floor textures blend toward their own mean color by k = L1 0.40, L2 0.45, L3 0.25, L4 0.30, L5 0.30. Mean luminance is unchanged (wall contrast numbers hold), seams unaffected. Luminance std-dev of the 512 px floor, before -> after: L1 30.1 -> 18.1, L2 27.8 -> 15.3, L3 29.1 -> 21.9, L4 13.1 -> 9.2, L5 17.5 -> 12.3. After: loot pops on all five floors; L2 hatching is quiet. Atlas folder mtime bumped (Xcode recompiles).
Code-side loot rules (readability, all themes):
| Item | Value |
|---|---|
| Loot halo | additive radial glow under every pickup: diameter 44 (energycore 52), #FFFFFF at 28 % alpha on L1-L3, 38 % on L4-L5, z just below the loot; pulse alpha +/- 0.06 over 1.4 s |
| Loot shadow | soft plum ellipse 22 x 8 at 25 % alpha, 12 pt below the item center (section 1: code adds item shadows) |
| Loot bob | 3 pt vertical, period 1.2 s, random phase |
| Enemy shot on dark floors (L4, L5) | add a white-pink under-glow circle 28 pt, #FFB3F2 at 40 % alpha, additive, behind the 16 pt projectile; keep the sprite as is |
| Player shots | no change (orange, purple and yellow read on all floors) |
| State lights | the red / green lights live inside the plate sprites and read everywhere; the extra door lights (13.2) have the 1.5 pt plum outline so they read on dark floors too |

### 13.9 Open questions for the coder
- Reveal radius (3 cells), hold-time ring, and stagger timings above should go to `rules.json -> minimap / puzzle / door` next to the designer's numbers; if the designer's values differ, JSON wins.
- Generated radial glow texture: 128 px, white center to transparent edge, `pow(1 - r, 2)` falloff; create once at launch and share (no art file needed).

## 14. Systems UI and Pixel (M3)
All values are for swift-coder (M3-5/M3-6). Reference screen 1194 x 834 pt. Fonts SF Rounded, white with the 2 pt #2B2140 stroke (section 7). Colors are from section 2. Everything is code-drawn from `ui_quickslot`, `ui_quickslot_sel`, `ui_invslot`, `ui_invslot_sel` plus item sprites from `items.atlas`, so no new art is needed except the optional gear (14.10). Nothing here uses red except the existing off-state lights.

### 14.1 Quick-slot bar (4 slots, bottom centre, section 7: 72 pt, gap 12)
Each slot = `ui_quickslot` 72 pt with the item sprite 48 pt centred (touch only, no hotkeys).
| State | Look |
|---|---|
| Empty | `ui_quickslot` at 45 % alpha, plus a dashed rounded-square outline (corner 14, 2 pt, #8FA3C8, dash 6 on / 5 off) drawn 6 pt inside the edge; a 20 pt faint "+" (#8FA3C8, 60 %) in the centre. Tapping an empty slot opens the inventory |
| Filled | `ui_quickslot` at 100 %, item sprite 48 pt centred, 2 pt above centre; alpha of the whole bar is 85 % idle (section 7 uses 70 % for buttons; slots read as content so 85 %) and 100 % while pressed (scale 0.92, 0.06 s) |
| Count badge | circle 24 pt at the slot's bottom-right corner offset (+4, -4 outside the corner), fill #2E2A55, 2 pt #2B2140 outline, 1 pt #FFFFFF inner hairline at 40 %; number SF Rounded Bold 15 pt white; hidden at count 1; "99" max. Badge pops 1.0 to 1.25 to 1.0 in 0.15 s when the count changes |
| Selected / pressed feedback | `ui_quickslot_sel` overlay at 100 %, pulse alpha 0.7 to 1.0 over 0.8 s while the finger is down or for 0.25 s after a use. There is no persistent selected slot in M3 (quick slots are use-on-tap), so `_sel` only flashes |
| Cooldown (0.5 s per item type, `ItemUse`) | dark sweep: #1E1B3D at 60 % pie that shrinks clockwise from 12 o'clock (full at t=0, gone at t=0.5), clipped to the slot's rounded square; item sprite at 60 % alpha meanwhile; taps are ignored and do not shake |
| Used successfully | item sprite pops 1.0 to 1.2 to 1.0 in 0.15 s, heal sparkle (section 12 "Heal" particles) at the hero, count badge ticks down |
| Zero count (link kept, item gone) | slot stays linked: item sprite as a silhouette (colorBlendFactor 1.0 with #8FA3C8, alpha 35 %), no badge, slot at 70 % alpha |
| Disabled (cannot use now: heal at full HP, `alreadyFull`) | sprite at 60 % alpha and desaturated (blend #8FA3C8 at 0.5); on tap, "no" shake: x offsets +6, -6, +4, -4, 0 pt at 0.04 s each, and a Pixel line `pixel.generic.full_hp` (if the talk level allows). No red flash |
| "Full" shake | same shake, used when ammo is already at `reserveMax` or HP is full |
Hit test: 72 x 72 each, 12 gap, as section 7; row is 324 wide at bottom +16. The hit area never shrinks during animations.

### 14.2 Inventory screen (modal over a dim world, pauses the game)
Full-screen dim #1E1B3D at 70 %, fade 0.15 s. Everything sits on one panel centred on the screen (safe-area aware), fill #2E2A55 at 95 %, corner 20, 3 pt stroke #4A4585, soft shadow plum 30 %. Panel 900 x 500 at 1194 wide; on 1024 wide it scales to 0.9.
| Zone | Position inside the panel (panel origin top-left) | Size | Content |
|---|---|---|---|
| Title bar | x 24, y 16 | 600 x 40 | localized "Bag" (SF Rounded Bold 28, left aligned) |
| Quick-slot column | x 24, y 76 | 72 wide, 4 slots, gap 12 = 72 x 336 | 4 drop targets (`ui_quickslot`, vertical); a 14 pt number 1 to 4 (#8FA3C8) in each slot's top-left corner |
| Grid | x 120, y 76 | 5 x 5 `ui_invslot` 64, gap 8 = 352 x 352 | 25 slots, row-major |
| Info panel | x 496, y 76 | 260 x 352 | see below |
| Button column | x 776, y 76 | 100 x 352 | Close (top), Tidy (below) |
| Footer | x 24, y 440 | 852 x 44 | capacity text "12 / 25" (SF Rounded Bold 20, #FFFFFF; turns #FFD93D at 24 or 25) |
Slot states:
| State | Look |
|---|---|
| Empty | `ui_invslot` at 100 %, nothing else |
| Filled | item sprite 44 pt centred, count badge 20 pt (same style as 14.1, number 13 pt) at bottom-right inside the slot (offset -2, +2), hidden at 1 |
| Selected | `ui_invslot_sel` overlay + item scale 1.1; stays until another slot or empty space is tapped; info panel shows it |
| Drag | after a 0.15 s hold (or 8 pt move) the item lifts: a copy at 56 pt, alpha 90 %, scale 1.15, shadow ellipse 30 x 10, follows the finger with 12 pt vertical offset above it; the origin slot shows the item at 30 %. Valid quick slot targets under the finger get `ui_quickslot_sel` and scale 1.08. Dropping on a valid slot: copy flies in 0.12 s, badge pops. Dropping elsewhere: flies back in 0.15 s (easeOut). Dropping on another grid slot swaps or merges stacks |
| Quick link marker | an item linked to a quick slot shows a 18 pt circle badge at the top-left of its grid slot (#3DE3D0 fill, 2 pt plum outline, white number 1 to 4 in 11 pt bold) |
| Non-usable item (puzzle) | normal look; its "Use" button is hidden |
Info panel (fill #1E1B3D at 85 %, corner 14, 2 pt #4A4585, inner padding 14):
| Row | Layout |
|---|---|
| Icon | 72 pt item sprite centred top, y +14, on a 88 pt round plate #2E2A55 with a 2 pt #4A4585 stroke |
| Name | y +112, SF Rounded Bold 22, centred, 1 line, minimumScaleFactor 0.7 |
| Count | y +142, "x 5" SF Rounded 16, #BFFFF7 |
| Description | y +166, 14 pt SF Rounded regular, #C9D2EA, 4 lines max, 232 wide, line height 18 |
| Effect chip (heal, ammo) | y +244, 232 x 28 rounded 14, fill #5FE08A at 25 %, 1.5 pt #5FE08A stroke, 14 pt white text such as "+25 HP" |
| Buttons | Use at y +284 and Drop at y +284 (see below), side by side |
| Nothing selected | the panel shows Pixel `pixel_idle_01` 72 pt and the localized hint "Tap an item" |
Buttons (all at least 64 pt high; width 112 each in the info panel, gap 12 => 236):
| Button | Look |
|---|---|
| Use | 112 x 64 rounded 20, fill #5FE08A, 2 pt #2B2140 outline, label white 20 pt bold; hidden for puzzle items; dimmed 40 % and not tappable for `alreadyFull` (HP full) |
| Drop | 112 x 64 rounded 20, fill #FFB347 (UI accent, not red), 2 pt outline, label white; for stacks > 1 a tap drops one, a long press (0.5 s) drops the whole stack. Item appears at the hero's feet after closing |
| Close | 64 x 64 round, `ui_btn_pause` style: fill #FFD93D with a plum "x" 4 pt strokes, outline 2 pt #2B2140; top right of the button column. Also tap on the dim area or swipe down |
| Tidy | 64 x 64 round, fill #3D8BFF, white four-line "sort" icon; sits 12 pt below Close |
Press feedback is the section 7 rule (scale 0.92, alpha 100 %).
Open/close animation: panel scales 0.92 to 1.0 and fades in over 0.18 s (easeOut); close reverses in 0.12 s.

### 14.3 Bag full
| Part | Value |
|---|---|
| Footer in the inventory | "25 / 25" turns #FFD93D and a small yellow "!" badge (below) sits left of it |
| HUD inventory button (`ui_btn_inventory`) | when the bag is full, a "!" badge 24 pt at its top-right corner: circle #FFD93D, 2 pt #2B2140 outline, plum "!" SF Rounded Heavy 16; bounce scale 1.0 to 1.2 to 1.0 every 1.4 s, no sound loop |
| Pickup refused | the item stays on the floor; the hero and the item both play a "no" wiggle (item +-3 pt, 3 shakes, 0.12 s) and the inventory button badge pops once. One Pixel line (`pixel.generic.bag_full`), cooldown 20 s |
| Floor "!" marker on a pickup that cannot be taken | a 22 pt "!" badge (same style as above) floats 22 pt above the item, bob 3 pt over 1.0 s, only while the hero is within 3 tiles (192 pt), fade in/out 0.15 s; z above the loot halo; the halo is dimmed to 12 % alpha so the item reads as "not takeable" |
| Overflow ammo packs | if no slot is free, the ammo stays on the floor with the same "!" marker |

### 14.4 Pixel follow and hover (PixelNode)
Sprite `pixel_idle_01` at its M1 node scale, glow baked.
| Part | Value |
|---|---|
| Rest position | 56 pt behind-left of the hero (module map), 30 pt above the hero's feet: facing east the offset is (-48, +30), facing west (+48, +30); the side switches with the facing hysteresis of section 12 |
| Follow | critically damped lerp: `pos += (target - pos) * (1 - exp(-dt / 0.15))`, so about 0.15 s lag. Teleports (rescue, new level) snap with the teleport particles |
| Max speed | 520 pt/s (hero 220 pt/s) so it never lags behind off-screen; leash: if farther than 240 pt from the hero it snaps to 120 pt |
| Hover bob | on top of section 12 idle bob: amplitude 3 pt, period 1.8 s (as section 12), plus a slow side drift +-2 pt over 3.1 s so it feels alive; faces the hero's facing (xScale flip) with the 0.12 s ease |
| Move lean | tilt 5 degrees toward the follow direction while it is catching up (speed > 60), max 8 degrees |
| Talk wiggle | while a bubble is shown: zRotation +-6 degrees at 5 Hz, scale pulse 1.0 to 1.06 at 4 Hz; swap texture `pixel_talk_01..03` at 8 fps (loop) if present, else the key pose |
| Shadow | none (it floats); a soft plum ellipse 20 x 7 at 18 % alpha 30 pt below the sprite, to anchor it on the floor |
| Glow | additive cyan #3DE3D0 circle 56 pt at 25 % alpha, pulse 0.2 to 0.3 over 1.8 s |
| z | above the hero, below the HUD, above floor loot |
| Ignores | walls, physics, hits. Never blocks shots |
| Scan beam (hint start and "scan" comments) | cone from Pixel toward the target for 0.8 s: triangle 20 pt wide at Pixel to 80 pt at 90 pt length, #BFFFF7 at 30 % alpha, additive, sweeps +-12 degrees once; 6 sparkles #3DE3D0 along it |

### 14.5 Speech bubble (HUD top centre, per DECISIONS)
| Part | Value |
|---|---|
| Position | centred horizontally, top +16 inside the safe area; never moves |
| Size | width fits the text, min 200, max 420; height 64 for 1 line, 90 for 2 lines (max 2 lines, 60 characters, per `SpeechQueue`) |
| Panel | corner 20, fill #FFFFFF at 95 %, 3 pt #2B2140 outline, 3 pt offset plum shadow (#2B2140 at 25 %); no tail (the avatar replaces it) |
| Avatar | `ui_icon_pixel` at 40 pt (hi-res, 2x asset is 64 px), inside a 48 pt circle #3DE3D0 with a 2 pt plum outline, overlapping the left edge of the bubble by 16 pt (so the bubble is 416 total at max); bobs 2 pt over 0.6 s while talking |
| Text | SF Rounded Semibold 18 pt, #2B2140, left aligned, padding 14, 2 lines max with line height 22, `minimumScaleFactor` 0.8; DE strings may be about 20 percent longer: the 60 character rule still holds |
| Appear | 0.18 s: scale 0.85 to 1.05 to 1.0 (easeOut) and alpha 0 to 1, slides 12 pt down from top +4; a short blip is audio's job |
| Hold | `base + perChar x length` from `rules.json` (section M3 SpeechQueue) |
| Dismiss | tap anywhere on the bubble (hit area 64 pt high, full width), or timeout: fade and scale 1.0 to 0.92 in 0.15 s. When a next line is queued the swap is a 0.1 s cross-fade, no pop |
| Story lines | same panel, but outline #FFD93D and the avatar plate #FFD93D so a story beat feels special; held 1.3x longer |
| Hint lines | same panel with a small 16 pt arrow icon (white arrow on #5FE08A circle) at the right edge to say "I am pointing at something" |
| Layout safety | on 1194 wide the bubble spans x 389-805; the minimap panel starts at about x 998, key chips end at x 56. No overlap |

### 14.6 Hint arrow, flight and minimap ping
Hint flight (`flyTo`): Pixel leaves the follow position and flies in an arc toward the target (0.6 to 0.9 s, easeInEaseOut, max speed 480 pt/s), stops 40 pt from the target (never on top, so the target stays visible), hovers 1.2 s with the scan beam at the target, then returns to follow with a 0.5 s ease (or sooner if the hero moves farther than 320 pt away from Pixel).
| Part | Value |
|---|---|
| Dotted arrow (world, from the hero toward the target) | starts 48 pt from the hero, ends 64 pt before the target; round dots 8 pt diameter, spacing 18 pt, #FFD93D with 1.5 pt #2B2140 outline; arrowhead = chevron 22 pt wide, 5 pt strokes, same colors, at the tip |
| Flow animation | dots travel along the line at 90 pt/s (dash phase), alpha 0.9; individual dot scale ramps 0.6 to 1.0 along the path so it reads as direction |
| Lifetime | 6 s total: fade in 0.3 s, fade out 0.5 s; cancelled at once when the target element turns on or the hero gets within 128 pt of the target |
| Off-screen target | the arrow is clamped to the screen edge: a 40 pt chevron plate #FFD93D with plum outline, inset 24 pt from the safe area, pointing toward the target, bobbing 4 pt over 0.8 s. Never covers the joystick zones: when the clamp would fall in the bottom 160 pt corners it slides along the edge upward |
| Target highlight | ring 48 pt on the target element, 3 pt #FFD93D, pulse scale 1.0 to 1.2 over 0.8 s, 6 s |
| World arrow vs bag hint | when the item is already in the bag there is no arrow, only a bubble (HintPlanner) and the quick-slot / inventory button gets a 2 pt #FFD93D glow ring pulse (alpha 0.4 to 1.0 over 0.7 s) for 4 s |
Minimap ping (extends 13.1, display-only):
| Part | Value |
|---|---|
| Marker | ring around the target element dot: starts 4 pt, grows to 14 pt diameter over 0.9 s while alpha 1.0 to 0, #FFD93D 2 pt stroke, repeating |
| Rate | 2 Hz blink: every 0.5 s one ring (a second ring offset 0.25 s for the first 2 s so it is easy to find) |
| Dot | the target dot itself blinks scale 1.0 to 1.5 to 1.0 per ping, fill stays its state color so on/off remains readable |
| Duration | 6 s (same as the arrow), or until the target is solved |
| Hero line | when the target is out of the revealed area, the ping is a 9 pt #FFD93D triangle on the panel edge toward it, blinking at 2 Hz |
| Z | above elements, below the hero marker |

### 14.7 Rescue beam sequence (at 0 HP, GDD §12; 0.3x slow-mo for 0.6 s then 0.8 s beam)
Times are real seconds from the moment HP reaches 0. Slow-mo scales the game clock, not the UI.
| t (s) | What happens |
|---|---|
| 0.00 | hero control off, hit flash white, `Hero` kneels: pose scale 1.0 to 0.9 (0.15 s), "dizzy" stars: 3 yellow stars #FFD93D (14 pt, outline) orbit the head, radius 18 pt, 1.2 rev/s. Slow-mo 0.3x starts. World tint: full-screen overlay #BFFFF7 at 0 to 18 % over 0.3 s, and saturation down is NOT used (no grey, no red). Enemy shots in flight keep flying |
| 0.00 to 0.60 | Pixel (in real time, ignores slow-mo) dashes to the hero in 0.35 s (easeIn) and stops 36 pt above it; Pixel talk wiggle on. Bubble `pixel.rescue.*` appears at 0.2 s |
| 0.60 | slow-mo ends (0.1 s ease back to 1.0x). Beam starts |
| 0.60 to 0.80 | beam in: a vertical column centred on the hero, width 0 to 72 pt in 0.2 s, height from 220 pt above to 20 pt below the hero's feet; core #FFFFFF at 90 %, inner #BFFFF7 at 70 % (width 72 x 0.7), outer #3DE3D0 at 40 % (width 96), additive. Soft ground ring ellipse 88 x 32 pt #3DE3D0 at 60 % at the feet, scaling 0.6 to 1.0 |
| 0.80 to 1.20 | hero lifts: y +0 to +40 pt, scale 1.0 to 0.2, alpha 1.0 to 0.0 (easeIn, 0.4 s) while 14 sparkles #BFFFF7 / #3DE3D0 / white rise along the beam (speed 120 to 220 up, size 8 to 0, life 0.5 s) and 4 tiny stars #FFD93D. Camera does not shake |
| 1.20 | beam out (width to 0 in 0.15 s). Camera cuts (not pans) to the checkpoint: 0.15 s white-cyan fade (#FFFFFF 0 to 60 to 0 %) hides the jump. Pixel snaps next to the checkpoint with the teleport particles |
| 1.35 to 1.55 | at the checkpoint pad the same beam appears, width 72 pt, 0.2 s, hero fades in from the top: scale 0.2 to 1.0, alpha 0 to 1, y +40 to 0 (easeOut, 0.4 s), 12 sparkles falling inward |
| 1.55 to 1.95 | beam out (0.15 s), landing squash: yScale 0.9 to 1.0 in 0.12 s, ring burst (checkpoint touched style, 13.6) |
| 1.95 | control back, full HP, invulnerability 2 s (alpha blink 1.0 / 0.4 every 0.08 s as in section 12), HP bar refills from 0 to 100 % in 0.4 s with the heart pulse (14.8) and the heal sparkle |
| 2.0 | Pixel line `pixel.rescue.back`. The overlay tint is gone by now |
Total control-off time about 1.95 s (rules.json owns the real timings; the slow-mo 0.6 s and beam 0.8 s match GDD §12 so beam out+in = 0.8 s plus fades). No text on screen besides Pixel's bubble. Never shows a "game over" word, red, or a death pose.

### 14.8 Low-HP heart pulse
Trigger: HP below `rules.json -> lowHp` threshold (design default 30 %). Never red-vignette (section 12 rule).
| Part | Value |
|---|---|
| Heart icon (`ui_icon_heart`, 32 pt at the HP bar's left) | scale 1.0 to 1.25 to 1.0 in a "lub-dub": 0.12 s up, 0.10 s down, 0.10 s up to 1.15, 0.18 s down, then rest to 0.9 s period (about 1.1 Hz). Faster below 15 %: period 0.7 s. Stops at once when HP is back above threshold, easing back in 0.15 s |
| Heart color | stays the asset color; add a white additive glow circle 44 pt behind it at 0 to 40 % alpha in step with the beat |
| HP bar | fill colour is unchanged (the green to yellow mapping from the HUD stays); a soft #FFD93D 3 pt outline glow around `ui_hpbar_bg` pulses alpha 0.0 to 0.8 in step with the heart. Fill at the end of the bar blinks alpha 1.0 to 0.65 per beat |
| Edge hint | optional soft screen-edge glow #FFD93D at 0 to 12 % alpha, 120 pt wide gradient on the 4 edges, in step with the beat. Max 12 % so it never reads as "danger red" |
| Pixel | one comment, per-key cooldown 60 s (SpeechQueue); Pixel also gives a small cyan heart-shaped sparkle (6 particles, #3DE3D0) toward the hero once |
| Reduce Motion | if the system setting is on, no scale pulse: the heart holds at 1.1 with the glow at 30 % fixed |

### 14.9 Poof v2 (QA-009 fix: power-down on busy floors)
Problem: the old poof (14 particles, ring alpha 0.6, 0.5 s) vanished on L1/L2 floors. v2 keeps the 0.4 s sprite scale-down (section 12) but makes the burst larger, more colorful and longer. All particles `blendMode = .add` only for sparkles; stars and chips use `.alpha` with a 1.5 pt plum outline texture (generate a star and a chip with plum rim so they separate from the floor, additive alone washes out on light floors L1/L3). Cap stays 120 live particles; one poof = 34 particles, so at most 3 poofs at once at full count; with 4 or more simultaneous poofs scale counts by 0.6.
| Layer | Value |
|---|---|
| 0. Pre-flash | 0.08 s white flash on the sprite (as section 12) |
| 1. Dark pop ring (floor contrast) | filled circle #2B2140 at 35 % alpha (an anti-glow, so the burst reads on light floors), diameter 24 to 92 pt in 0.25 s (easeOut), alpha to 0; on dark floors L4 and L5 use a white circle #FFFFFF at 30 % instead. The theme flag comes from the level |
| 2. Shock ring | stroke circle 4 pt, #FFFFFF with 1.5 pt plum outside it, diameter 20 to 110 pt over 0.35 s, alpha 1 to 0, easeOut |
| 3. Stars | 10 stars, 14 to 22 pt random, 1.5 pt plum outline; colors cycle #FFD93D, #FF8A3D, #FFFFFF, #B05CFF (not red). Speed 140 to 300 pt/s with drag 2.2 (decelerate), rotation +-8 rad/s, life 0.7 s, alpha 1 until 0.5 s then to 0, size scale 1.0 to 0.2 |
| 4. Bolts / chips | 8 chips 10 to 14 pt: robots = bolt, nut and gear shapes #A9BCE0 / #C9D2EA with plum outline; slimes #6FE06A / #8CF07F blobs; spore #E36BD8 / #FFB3F2 petals. Speed 100 to 240, gravity -90 so they arc and drop, life 0.8 s, a small bounce 6 pt at 0.5 s, rotation +-10 rad/s |
| 5. Sparkles | 12 sparkles `fx_sparkles_01`, 10 to 16 pt, #BFFFF7 / #FFFFFF / #FFD93D, additive, speed 60 to 200, life 0.6 s, twinkle (alpha 1 to 0.3 to 1) at 12 Hz |
| 6. Center twinkle | a 4-point star 40 pt white, scale 0.4 to 1.3 to 0 in 0.3 s, additive, above the sprite; one-frame hold at the start |
| 7. Loot reveal | loot pops out at t = 0.35 s (section 12) with a 0.2 s cyan ring so the player sees where it fell; the rest of the burst keeps playing to 0.8 s |
| Duration | 0.8 s total (was 0.4 s sprite plus 0.5 s particles), sprite gone at 0.35 s |
| Color family | robot: gold + silver + cyan; slime: gold + green + white; spore: gold + pink + white. Always some #FFD93D so it is recognised as "power down, good" |
| Size | burst radius about 70 pt (about 1.1 tiles) vs about 45 pt before. Boss: counts x2, radius x1.8, 3 bursts as in section 12 |
| Safety | no red, no dark splats, no particles that persist on the floor; the dark pop ring is a soft, round, short-lived shadow-like disc, not a stain |
| Test | pass when, on each of L1 to L5 floors, the burst is visible in a screenshot at 50 % scale (compare `qa_m2_powerdown_a/_b.png`): the stars separate from the floor by outline alone. Coder checks L1 and L2 first (the weakest floors) |

### 14.10 Gear icon for Settings and Pause menu
Until art exists, use the SF Symbol `gearshape.fill` (white, 28 pt, on a 64 pt round #3D8BFF button with 2 pt plum outline, same style as 14.2 buttons). If the owner generates prompt #36 (Gemini sheet `ui_icon_gear`, one icon, 72 x 72 pt, slicer name `ui_btn_settings`), swap the sprite in at the same size and remove the SF Symbol; the touch target is 64 pt either way (button 72 pt in the pause menu).

### 14.11 Notes for the coder
- Every number here that is a gameplay timing (slow-mo, beam, lowHp threshold, hint durations, speech durations) is a default: `rules.json` wins if the designer set it differently.
- All generated textures (star, chip, bolt, nut, gear, dashed outline, radial glow 13.9) are created once at launch and cached.
- Reduce Motion (14.8) also disables the scan beam sweep, the lean and the side drift.

## 15. Enemies, blasters, boss (M4)
For swift-coder (M4-5/M4-6). Reference 1194 x 834 pt, colors from section 2, outline #2B2140, fonts and HUD rules from sections 7 and 14. Times are seconds. Every telegraph lasts at least the JSON `telegraphSec` (the effect may start earlier, never end earlier). Telegraph colors use the OVERMIND warning red #FF3B5C only as a soft glow or line, never as a splat, fire or burst. Shared rules: telegraphs are drawn under the sprite on z = enemy - 1 with a 1.5 pt #2B2140 outline so they read on all 5 floors; on L4/L5 (dark floors) add a white 1 pt inner line, on L1-L3 (light floors) keep the plum outline. Reduce Motion: pulses become a steady glow at the end alpha, shakes are removed. No sound or text is baked in.

### 15.1 Telegraphs (wind-up before damage)
| Enemy / attack | JSON | Visual (all values from start of wind-up) |
|---|---|---|
| Laserdrone shot | `telegraphSec` 0.5 | additive glow disc #FF3B5C, 28 pt, alpha 0.2 to 0.9 over 0.5, scale 0.6 to 1.1 at the barrel (sprite front, 14 pt from centre toward the hero); drone stops strafing and hovers still; thin aim dots (4 pt, 3 dots, 10 pt apart, #FF3B5C 60 %) toward the hero, fade at fire. Fires on t = 0.5, glow pops to 40 pt and fades in 0.1 |
| Shield android dash | 0.7 | crouch: yScale 1.0 to 0.82, xScale 1.0 to 1.08 in 0.25, hold; shield arc glows #FFD93D alpha 0.5 to 1.0 pulsing 6 Hz; a dash lane preview: rounded strip 28 pt wide x 260 pt long from the android toward the hero, fill #FFD93D at 18 %, 2 pt dashed edge, drawn at t = 0.2 and locked at t = 0.45 (direction frozen) so the player can dodge. Two small dust puffs (#FFFFFF 50 %, 8 pt) at the feet |
| Spore plant volley | 0.6 | petals open: the 4 petal parts (a code-drawn #E36BD8 / #FFB3F2 ellipse 16 x 26 pt, outline 1.5 pt) rotate outward 0 to 35 degrees in 0.4, a pink glow disc #FFB3F2 24 pt at the centre pulses 0.3 to 0.9; three tiny fan ticks (white 4 pt dots 40 pt out at -15, 0, +15 degrees) show the 30 degree fan; shot at t = 0.6, petals close in 0.2 |
| Boss stomp ring | 0.8 | ground ring, 2 pt #FF3B5C stroke plus 5 pt #FF3B5C at 20 % fill disc, radius `telegraphRadius` 140 pt; an inner filled disc grows from 0 to 140 over 0.8 (easeIn) so the player sees when it lands; boss lifts 6 pt and squashes at the end; wave (15.6) then expands 140 to 220 pt |
| Boss volley | 0.7 | 6 short warning lines from the boss toward the 6 rocket angles (length 90 pt, 3 pt, #FF3B5C 70 %, dashed 8/6), fade in over 0.3; star-shaped glow 36 pt #FFD93D on the mech's launchers |
| Boss laser warning line | 1.0 | the beam's whole sweep sector as a pie of 5 % white fill; each gap is shown as a clearly green wedge (#5FE08A at 25 %), the beam positions as 4 pt #FF3B5C dashed lines that brighten 0.2 to 0.9 alpha over 1.0 s; beam then rotates at 45 degrees/s. Beam body: width 18 pt, core #FFFFFF, mid #FF8AA0, outer #FF3B5C at 40 % additive, rounded caps, soft not razor |
| Boss dash arrow | 1.0 | a big arrow on the floor from the boss to the end of the dash line: shaft 36 pt wide, head 72 pt, fill #FFD93D at 30 %, 3 pt #FF3B5C outline, 3 chevrons marching along it at 2 Hz; pillars on the line get a ring 3 pt #FFD93D (the player can see where it will crash). Boss rears: yScale 1.0 to 1.1, eyes flash |
| Alert exclamation (all, see 13) | `alertSec` 0.4 | unchanged |

### 15.2 Shield (shield android)
| Part | Value |
|---|---|
| Arc | `arcDeg` 120: a curved plate, centred on the facing, radius = enemy radius + 8 (28 pt), thickness 8 pt, fill #3DE3D0 at 55 % with a 1.5 pt #BFFFF7 inner edge and a 2 pt #2B2140 outer outline, additive shimmer stripe sweeping along the arc every 1.6 s. Drawn above the sprite. Rotates toward the hero at `turnRateDeg` 120 |
| Raised idle | alpha 0.75 |
| Block bounce | shot disc reflects on the shield normal at 60 % speed for 36 pt and turns into 6 sparkles (#BFFFF7 / #FFFFFF / #FFD93D, 8 to 12 pt, life 0.35, additive) with a 4-point star flash 24 pt at the contact point (0.12 s); arc flashes white alpha 1.0 for 0.08; a tiny "clink" ring (2 pt white stroke, radius 6 to 22 pt, 0.2 s). No damage number, enemy does not flinch, hero shots do not pass |
| Dash | shield stays glowing #FFD93D (see 15.1) |
| Dizzy (after the dash miss, `dizzySec` 1.5) | shield arc falls: alpha 0.75 to 0 and scales 0.8 over 0.2, cracks nothing; android sprite tints toward #FFD93D 25 %; dizzy stars (15.3); a small "x1.5" is NOT shown; hits get an extra bright white flash and a 20 pt star pop so the bonus is felt |
| Recover | shield pops back 0 to 0.75, scale 1.15 to 1.0 in 0.2 |

### 15.3 Dizzy stars (shield android, boss)
3 stars (code-drawn five-point, #FFD93D, 1.5 pt plum outline), 12 pt for enemies and 22 pt for the boss, orbit on an ellipse (rx = radius x 0.9, ry = rx x 0.4) centred 6 pt above the head (boss 20 pt above the face), speed 1.4 rev/s, z above the sprite, each star also scales 0.85 to 1.1 with its depth (front stars are bigger, back stars are drawn under the head). They fade in/out in 0.12 s. Same look as the hero's rescue stars (14.7).

### 15.4 Spore slow on the hero
| Part | Value |
|---|---|
| Hit | spore shot (4 dmg) pops into 8 pink puffs (#E36BD8 / #FFB3F2, 6 to 12 pt, drift 40 pt/s up, life 0.5, alpha) |
| Tint | hero sprite `colorBlend` #E36BD8 at 0.30 for `slowSec` 2.0 (the last 0.4 s fades out); refreshing on re-hit restarts the timer without stacking |
| Aura | a soft pink ring on the ground under the hero: ellipse 56 x 20 pt, #E36BD8 at 35 %, 1.5 pt #FFB3F2 stroke, slowly pulsing 0.25 to 0.45 |
| Particles | every 0.2 s a spore puff (4 pt) sinks from above the head, 5 at a time max; plus a tiny "snail" read through the walk: the hero's PoseAnimator step cadence x0.7 (matches the 0.7 multiplier) |
| Icon | a 24 pt round badge #E36BD8 with a plum outline and a white down-arrow to the right of the HP bar for 2 s with a small ring timer sweeping off (clockwise, #FFFFFF 60 %) |
| Pixel | optional line `pixel.generic.slow`, cooldown 30 s |
| Rescue | cleared; no leftover tint |

### 15.5 Slime split (slimemutant, `splitInto`)
| Part | Value |
|---|---|
| On hit | squash: yScale 0.82, xScale 1.15 in 0.06, spring back with overshoot to 1.05 in 0.14; 3 green droplets (#8CF07F, 5 pt, 1 pt plum outline, 0.4 s) |
| On power-down | 0.0: white flash 0.08, body shrinks and wobbles (xScale +-0.12 at 18 Hz) for 0.25; 0.25: plop ring (2 pt #8CF07F stroke, 20 to 60 pt, 0.25 s); poof reduced to 60 % particles (green, gold, white) |
| Pop-out (t = 0.3, `spawnDelaySec`) | 2 smalls spawn at the body centre (scale 0.2) and arc out to `spawnOffset` 40 pt in opposite directions (`+-40` along a random axis) in 0.25 s with a 10 pt hop (easeOut), landing with a squash (yScale 0.8 to 1.0 in 0.1), scale 0.2 to 1.0 with a little overshoot to 1.15. A small "bloop" sparkle (#FFFFFF, 6 pt) at the origin. While popping, 0.4 s total: alpha blink 1.0 / 0.6 every 0.08 (harmless, not damageable, same as the hero invulnerability look) |
| Small slime | same sprite at 0.55 scale (radius 11), a lighter green #8CF07F tint 15 %; never splits; plain poof |
| Walls | spawn positions are chosen not inside walls (coder), the hop arc never crosses a wall corner |

### 15.6 Blasters (feel per weapon)
Weapon colors (section 2): starter #FF8A3D, spread #B05CFF, rapid #FFD93D. Muzzle flash is a 20 pt additive 4-point star in the weapon color at the muzzle, 0.06 s, scale 0.6 to 1.2. Projectile pool textures are code-drawn or from `projectiles` sheet; all projectiles have a 1.5 pt #2B2140 outline except trails.
| Blaster | Projectile | Trail | Hit | Hero feel |
|---|---|---|---|---|
| Starter (`light_bolt`, r 6, 720 pt/s) | rounded capsule 20 x 10 pt, #FFB36B core with #FF8A3D rim, white 4 pt highlight | 3 fading afterimages at 14 pt spacing, alpha 0.5 / 0.3 / 0.15, additive | white flash + 4 orange sparkles (8 pt, 0.25) | recoil 2 pt backward 0.05 s, no shake |
| Spread / Bubble (`bubble`, r 8, 560 pt/s, 5 pellets over 40 degrees) | round soap bubble 24 pt: fill #D9B8FF at 35 %, 2 pt #B05CFF rim, white crescent highlight top-left, a small rainbow tint stripe (#3DE3D0) on the lower right | wobble: scale oscillates 0.92 to 1.08 at 7 Hz (opposite phases per bubble) and the path sways +-3 pt sinusoid at 4 Hz perpendicular to travel; no trail | bubble pops: ring 1.5 pt white expanding 24 to 44 pt (0.18 s) + 6 purple droplets (#B05CFF / #E8D4FF, 6 pt); on a miss it pops at max range with a smaller ring (0.12 s) | muzzle: 5 small bubbles puff out 12 to 24 pt (0.25 s); recoil 4 pt, camera nudge 1 pt over 0.08 s; reload: three bubbles blown from the muzzle |
| Rapid / Foam (`foam`, r 5, 820 pt/s) | foam blob 16 pt, lumpy outline of 3 overlapping circles, fill #FFF3A0, rim #FFD93D, 1.5 pt plum outline, 2 white speckles | continuous foam crumbs: a puff 6 pt every 22 pt of travel, #FFFFFF 70 %, life 0.25, shrinking; 3 pt random lateral offset so the stream looks bubbly | splat star: 6 yellow/white foam flecks (6 pt, 0.3 s) and a squash flash on the target | muzzle: small yellow puff 14 pt, 0.08; no recoil beyond 1 pt jitter, 10 shots per second so no camera effects |
Spent shell/mag feedback: none (kid-safe, no casings). Empty magazine click: the HUD ammo number does a 1.0 to 1.15 to 1.0 pulse in #FFD93D; reload bar under the hero as 14 (unchanged).

### 15.7 SWAP button and weapon wheel
**SWAP button** (`ui_btn_swap`, 72 pt, right +24 / bottom +340 per section 7, visible once 2 or more blasters are owned):
| State | Look |
|---|---|
| Hidden | with only the starter: not drawn and no touch area |
| First appear | pops 0.0 to 1.2 to 1.0 in 0.25 and a ring pulse (2 pt #FFD93D, 72 to 104 pt, 0.4 s) once; Pixel hint only once (`pixel.l2.swap`) |
| Idle | alpha 0.7; the next blaster's icon (22 pt, `ui_icon_blaster_*`) sits as a small badge at the top-right corner (radius 14 plate #2E2A55, 2 pt plum outline), so a kid sees what a tap gives |
| Pressed | scale 0.92 and alpha 1.0 as section 7; short 0.25 s swap sequence: the current blaster icon in the ammo readout slides out left 16 pt, the new one slides in from the right (0.12 s each); hero blaster pose crossfade 0.1 s; a small star burst in the new weapon colour (4 sparkles) at the hero's hands |
| Swapping (0.25 s) | the button shows a ring sweep (#FFFFFF 60 %, clockwise, 0.25 s) and taps are ignored without shaking |
| Reloading | the button stays active (swap cancels reload); a slim 2 pt #FFD93D arc remains |
| Long-press | hold 0.4 s: scale 1.0 to 1.15 as it fills a radial progress ring (3 pt #FFD93D) over 0.4, then the wheel opens with a 0.05 s haptic style tick (audio's job). Release before 0.4 s = a normal tap swap |
| Disabled (swapping no-op: only 1 owned) | hidden, see above |
**Weapon wheel** (`WeaponWheelView`, pauses nothing but slows time to 0.3x while open, 14.7 rule: UI is real time):
| Part | Value |
|---|---|
| Layout | 3 slots in a quarter-arc up and to the left of the SWAP button (it sits on the right edge, so the fan must never go right of it). Centre = button centre (about x 1114, 376 pt above the bottom on 1194 wide); radius **140 pt**; angles measured counter-clockwise from +x: starter **180** (straight left), spread **135** (up-left), rapid **90** (straight up). Plates are **80 pt** and the chord between neighbours is 2 x 140 x sin(22.5) = 107 pt, so the gap between plates is 27 pt (at least 24) and hit areas (80 + 12 slop) do not overlap. The right-most plate edge is x 1154 (inside the 1158 safe limit); the top slot reaches 556 pt above the bottom, clear of pause/inventory. On other widths keep the same offsets from the button and clamp inside the safe area plus 16 pt. Ammo pills sit under each plate and clear the SWAP button |
| Slot plate | circle #2E2A55 at 95 %, 3 pt #4A4585, inner icon `ui_icon_blaster_*` 48 pt, a coloured 4 pt arc of the weapon colour on the rim |
| Ammo under the icon | magazine/reserve "12 / 96", SF Rounded Bold 14 pt, white with plum 2 pt stroke, in a 56 x 20 pill #1E1B3D at 85 % under the plate (y +52 from centre); reserve 0 shows the numbers in #FFD93D |
| Equipped | plate scaled 1.1, rim glow 3 pt #FFD93D, tiny "tick" badge (#5FE08A circle 22 pt, plum outline, white check) at the top-right |
| Locked / unowned | plate at 55 % alpha, icon as a silhouette (#8FA3C8, colorBlendFactor 1.0, alpha 50 %), a 22 pt padlock badge instead of the ammo pill, no response on tap except the "no" shake of 14.1 |
| Selection | finger drag over a slot: scale 1.2, highlight ring 3 pt #FFFFFF; release on a slot = swap to it; release on the centre or the dim = close with no change; tap on a slot while the wheel is pinned also picks it |
| Open / close | scale 0.6 to 1.0 with overshoot 1.08 in 0.15, the slots fan out from the button staggered 0.03 s; close 0.1 |
| Dim | #1E1B3D at 35 % behind (just enough to focus, world remains visible) |
| Rule | a pick plays the swap sequence of the SWAP button; swap takes `swapSec` 0.25 |

### 15.8 Boss bar (HUD)
| Part | Value |
|---|---|
| Position | top centre, top +64 (just under the Pixel bubble zone, below it in z; the bubble is at y 16 to about 106 when shown, so while a bubble is visible the bar slides down 36 pt to avoid it), width 420 pt, height 28 pt (display only) |
| Frame | pill 28 pt tall: fill #1E1B3D at 90 %, 3 pt #2B2140 outline, a 2 pt #4A4585 inner line; icon plate on the left: circle 44 pt #D61F8F with a plum outline and the megamech head (the key pose cropped, or a white stylised round robot head) |
| Fill | width 400 x HP fraction, colour gradient left #FF8AB8 to right #FF3B5C (a pink/red, not blood, with a top-left white 25 % gloss stripe 6 pt); no numbers, no percent text |
| Phase notches | 2 notches at 1/3 and 2/3 (HP 800 and 400): a 4 pt wide white rounded tick with a plum outline, rising 6 pt above and below the bar; passed notches turn #FFD93D |
| Immune (phase 2 shield) | fill is replaced by a bright #3DE3D0 hatch pattern (diagonal stripes 8 pt, scrolling 20 pt/s) at 80 %, the frame glows cyan 3 pt, and a small bubble-shield icon (24 pt) sits at the left; it returns to the pink fill when the shield breaks |
| Damage feedback | on hit: a lighter "lag" band (#FFFFFF at 70 %) shows the lost HP and shrinks over 0.5 s after 0.2 s; the frame shakes 1 pt on hits >= 20 dmg |
| Phase change | bar flashes white 0.15 s, notch bursts a star, the bar pops 1.0 to 1.06 to 1.0 in 0.3 |
| Rescue reset | the fill refills to the phase top in 0.4 s (the heal feel), never an instant jump |
| Appear / defeat | slides down from -40 pt in 0.3 s with a small overshoot when the boss wakes; on defeat the bar drains to 0, flashes #FFD93D, then fades in 0.4 s |
| Accessibility | id `hud.bossBar`, VoiceOver label from Localizable ("Boss health", phase name), no numeric value |
| Sits clear of | HP bar (left +16), minimap (right), inventory/pause (right), key chips (left) |

### 15.9 Bubble shield (boss phase 2, `immune`)
| Part | Value |
|---|---|
| Body | circle 2 x radius + 36 = about 180 pt around the mech (centre at the torso), fill radial from #BFFFF7 at 10 % (centre) to #3DE3D0 at 45 % (rim), 3 pt #BFFFF7 rim, 1.5 pt #2B2140 outer outline, additive shimmer: 3 white arc streaks of 40 degrees circling at 0.3 rev/s, and a hex pattern at 8 % alpha |
| Idle | breathes: scale 1.0 to 1.04 over 1.6 s, alpha 0.9 to 1.0 |
| Shot hits it | shots stop at the rim and pop with a cyan ring ripple (2 pt, expands 12 to 36 pt in 0.2 s) and 4 sparkles; no damage; a ripple travels across the bubble's surface (a bright arc spot at the contact angle, 0.25 s); Pixel hint `pixel.boss.shield` once |
| Core socket links | thin beams (3 pt, #3DE3D0 at 60 %, dashed, flowing 80 pt/s) link each core machine to the bubble; a socket filled by an energycore turns its beam on and the bubble's rim gets a notch glow (#FFD93D) per filled socket (0 to 2) |
| Break (all cores in) | bubble flickers 3 times (alpha 1.0 / 0.3 at 0.08 s), then bursts in 0.2 s: 12 cyan/white shards (rounded, 14 pt) fly out 160 pt and fade in 0.5, ring shock 4 pt #FFFFFF from 90 to 200 pt in 0.35; mech dizzy 4 s with stars (15.3) and a yellow "weak" glow ring #FFD93D 3 pt at the torso, pulsing 2 Hz; damage x2 flashes the star pop on every hit |
| Back up (after dizzy if phase 2 still continues vulnerable) | does not come back: phase 2 continues vulnerable until 400 (designer rule); the bar shows pink fill |

### 15.10 Core machine sockets (boss arena, 2 machines)
Uses the `puzzle_machine` sprite. The socket is a code-drawn overlay 40 x 40 pt at the machine's front, z above the sprite.
| State | Look |
|---|---|
| Empty / off | rounded-square hole #1E1B3D, 3 pt #4A4585 rim, a faint outline of the energycore (circle 22 pt dashed #8FA3C8, 2 pt) and a slowly blinking "off" dot #FF3B5C (alpha 0.4 to 1.0 at 1 Hz) top-right, as section 13 off-state |
| Hero is near with a core in the bag | the dashed core pulses #FFD93D (0.4 to 1.0 at 1.2 Hz), the INTERACT button shows (existing rule), a 3 pt #FFD93D ring around the socket, plus the world arrow of 14.6 via Pixel |
| Filling (0.4 s) | the energycore sprite (item icon) flies from the hero to the socket in an arc, scale 1.0 to 0.7, clicks in with 4 sparkles; the dot turns #5FE08A |
| Filled / on | socket glows #3DE3D0, the core sits inside with a spin of its inner light (rotation 1 rev/2 s), the machine's state light #5FE08A, a beam to the boss bubble (15.9); the machine hums with a 6 pt tall light bar in front |
| Counter | on the minimap and above the machine: 1/2 and 2/2 shown as 2 small circle pips (14 pt each, filled #5FE08A or hollow #8FA3C8) next to the boss bar; no text |
| Refuse (no core) | machine shakes 3 pt, a quick hollow "no" ring; Pixel line `pixel.boss.core_needed` (cooldown 20 s) |
| Core carriers | boltbots carrying an energycore wear a 20 pt core icon on their back (spinning 0.5 rev/s) with a #3DE3D0 additive glow 36 pt, so the player knows which one to hit; dropped core hops 10 pt and bobs with a halo |

### 15.11 Phase-change flash
0.0 boss pauses (no attack), white flash overlay on the sprite alpha 0 to 1 to 0 over 0.3; 0.0 to 0.5 a screen-wide soft ring (#FFFFFF 4 pt, radius 60 to 700 pt, alpha 0.7 to 0, additive) and 8 stars/bolts burst up and fall (power-down colours, #FFD93D, #3DE3D0, #D61F8F); face (15.13) switches mood on t = 0.2; camera 3 pt nudge 0.15 s (not in Reduce Motion); the stomp wave of the arena is cleared for 0.8 s; boss is invulnerable and enemy shots are removed for 0.8 s; boss bar notch burst (15.8). No red tint of the screen, no shake > 3 pt.

### 15.12 Boss defeat: sparkle burst (no explosion look)
Never: orange or red fireballs, smoke, shockwave debris, flashing full-screen white more than once. The mech powers down and goes out in stars.
| t (s) | What happens |
|---|---|
| 0.00 | hit flash white, boss stops, face to `smiley`-style "dizzy" X eyes (@ code face "panic" then "smiley"), all enemy shots and spores popped into sparkles, boltbots poof |
| 0.00 to 1.4 | 3 mini bursts at random torso points 0.45 s apart (poof v2 scaled 1.0, the section 14.9 stars/chips, colour mix #FFD93D, #3DE3D0, #FFFFFF, #D61F8F), the mech shakes +-3 pt at 14 Hz and its alpha stays 1.0; spark chips fall (bolts, gears, nuts only; no fire) |
| 1.4 to 1.8 | the boss shrinks to scale 0.85 and the colour desaturates 30 %; stars spiral up from the body (16 stars 14 to 22 pt, 1.2 s, rising 160 pt then fading); Pixel flies to the boss |
| 1.8 | single big burst: 40 stars/chips/sparkles radiating up to 260 pt (poof v2 x2 counts, x1.8 radius, 3 s limit on live particles 120 cap), ring 4 pt #FFFFFF from 80 to 300 pt in 0.5 s, 4-point twinkle 160 pt white at the centre (scale 0.4 to 1.3 to 0 in 0.4 s). Full-screen white overlay peaks at 35 % for 0.1 s, once (no strobe) |
| 1.8 to 2.4 | the mech sprite scales 0.85 to 0 and fades; leaves a soft glow disc #BFFFF7 40 pt that fades in 0.6 s, no floor stain; loot (`loot_megamech`) bounces out with a cyan ring each (poof loot reveal 14.9) |
| 2.4 to 3.4 | confetti: 40 ribbons/stars (#FFD93D, #3DE3D0, #D61F8F, #5FE08A, #B05CFF) fall from the top of the screen for 1.2 s; Pixel cheers (wiggle), the hero gets a victory hop; camera zooms 1.0 to 1.08 over 1.0 |
| 3.4 | the Season complete card (15.14) slides in |
Reduce Motion: no shake, no camera zoom, one burst only, confetti reduced to 12.

### 15.13 Boss face overlay (code-drawn, no new art)
Decision: code-drawn, so no Gemini prompt is added. The key pose `boss_megamech_idle_01` keeps its own printed screen; the overlay is a rounded screen patch on top that covers the printed face. Coder reads the face rectangle from `PoseAnimator` data once at build; if it needs an exact rect for the 192 pt key pose, use the screen area measured from the sprite (about 40 % width, 22 % height of the sprite, centred on the head). The 4 moods are Core Graphics shapes (SKShapeNode / pre-rendered `SKTexture` cache, the same approach as the section 14.9 stars):
| Mood | When | Screen | Eyes | Mouth / extra |
|---|---|---|---|---|
| smug (default) | phase 1 idle, between attacks | #12304A with a 3 pt #D61F8F rim and 1.5 pt plum outline | two half-lidded ovals #FF3B5C 22 x 12 pt, a white 4 pt highlight each, lids flat on top, slightly narrowed | a lopsided grin: arc 36 pt, 3 pt #FF3B5C, one corner up 6 pt |
| angry | stomp / volley / dash wind-up, phase 3 overload | same screen with the rim pulsing #FF3B5C at 1 Hz | eyes 24 x 14 pt slanted 18 degrees inward (V shape), pupils #FFFFFF 5 pt | small flat mouth 28 pt with 2 zig-zag teeth (still goofy, not scary); eyebrow bars 22 x 4 pt, #FF3B5C. Never more than that |
| panic | phase change, hit while dizzy, shield break | screen rim #FFD93D | eyes round 22 pt white, pupils 6 pt dark, jittering +-1.5 pt at 12 Hz, a sweat drop (#8FD3FF 8 pt) | wobbly mouth, a wavy 3 pt line #FFFFFF; stars when dizzy |
| smiley | defeat / intro / "friendly" end | rim #5FE08A | happy arcs `^ ^` 3 pt #5FE08A | open smile arc 30 pt #5FE08A with a tiny tongue #FF8AB8 ; this one shows during defeat and the Season card |
Rules: the overlay blinks every 3.5 s (eyes squash to 2 pt for 0.12 s); the mood cross-fades in 0.12 s; eyes look toward the hero (pupils shift up to 4 pt); the overlay is scaled and bobbed with the boss pose (child node of the sprite, so it follows `PoseAnimator`); face is not damaged by hit flash: use the same white flash colour blend on the sprite and set the overlay to blend 1.0 white for 0.08 s too. Eye colour #FF3B5C reads as the OVERMIND red-eye motif but is flat and cartoonish; no glow rays.

### 15.14 Season complete card
| Part | Value |
|---|---|
| Style | full-screen dim #1E1B3D at 70 % fading in 0.3 s, one centred card 760 x 520 pt (on 1024 wide it scales to 0.85), fill #2E2A55 at 97 %, corner 28, 4 pt #FFD93D stroke, 3 pt offset plum shadow; a little confetti keeps falling behind (continuing from 15.12, 8 pieces at a time) |
| Header | a gold ribbon banner 560 x 80 pt, fill #FFD93D, 3 pt plum outline, centred at the top overlapping the card by 40 pt; localized "Season complete!" SF Rounded Heavy 36 pt #2B2140; two 36 pt `ui_icon_star` at the sides rotating gently +-8 degrees |
| Hero and Pixel | hero key pose 120 pt left of centre (victory hop every 2.4 s, 0.3 s), Pixel 72 pt hovering at the right of the hero with the talk wiggle, a #3DE3D0 additive halo; MEGA-MECH `smiley` face shown as a small 56 pt round icon in the corner (the friendly "thank you") optional |
| Body | L5 outro line (2 lines, SF Rounded Semibold 20 pt, #FFFFFF, centred, max width 560); below it 3 stat chips in a row 160 x 72 pt (fill #1E1B3D, 2 pt #4A4585, icon 28 pt + number SF Rounded Bold 26 pt): total score (star icon), datachips (chip icon from `items`), time (clock, optional) |
| Stars | optional later (M5): 3 big stars 56 pt pop one by one 0.25 s apart (scale 0.0 to 1.3 to 1.0, sparkle on each); in M4 show a row of 3 gold stars as decoration |
| Button | one 220 x 72 pt pill "Title" (`seasonComplete.toTitle`): fill #5FE08A, 3 pt plum outline, label white 24 pt bold, press scale 0.92; appears 0.8 s after the card so a kid does not tap through it; the card cannot be dismissed by tapping outside |
| Motion | card scales 0.8 to 1.05 to 1.0 in 0.35 (easeOut), content staggered 0.1 s; stats count up over 0.8 s; no flashing; Reduce Motion: no confetti, no scale overshoot |
| Safe | no red, no "game over" or death words; text only through Localizable; ids `seasonComplete.view`, `seasonComplete.toTitle` |

### 15.15 Prompts and assets in this section
- New Gemini prompts: **none** (all of the above is code-drawn; the boss face is code-drawn per 15.13, so no face sprites are generated).
- Open leftover from M3: prompt **#36** (`ui_icon_gear`, slicer name `ui_btn_settings`) is already in `art/prompts/gemini/PROMPTS.md` and the asset manifest and is still ungenerated. Main runs it; then `python3 tools/slice_atlas.py` and swap the SF Symbol out (14.10). I did not call Gemini.
- Everything here must be created once and cached (star, ring, petal, arc, hex, ribbon textures), as in 14.11.

### 15.16 Enemy projectile looks (QA-018 fix, supersedes "enemy shot #FF3B5C" in section 2)
Owner decision: no glossy red discs. Red survives only as soft telegraph glows, warning lines and rings (15.1). All three enemy shots are flat, outlined, candy-coloured, and none is a plain round red. Outline for all: 2 pt #2B2140 (1.5 pt for the rocket parts). Verified by compositing at 2 pt/px on `tile_l1..l5_floor_01`: all three read on all five floors by their plum outline plus light fills (checked at 1:1 and 50 %). Tail stars and bubble bumps must not go below the sizes below.
| Shot | Source | Size (pt) | Look |
|---|---|---|---|
| Spore (sporeplant, radius 12) | `proj_enemy_spore` | 28 incl. fuzz (body 22) | pastel puffball: 12 fuzz bumps (7 pt dots on the rim, alternating #D9C2FF lilac and #B8F5DC mint) around a body #D9C2FF; inner disc #B8F5DC (45 % of the radius); a white 6 x 6 pt highlight top-left; plum rim #4A3A70 under the bumps, then the 2 pt outline #2B2140. Matte, no gloss streak. Motion: scale 0.94 to 1.06 at 5 Hz and spin 1.0 rev/s so it feels fluffy; a faint trail of 3 mint puffs (#B8F5DC 50 %, 8 pt, life 0.3). Pop on walls/hero: 8 lilac/mint puffs (see 15.4, pink hero tint stays) |
| Boss firework rocket (volley, radius 12) | `proj_boss_rocket` | 52 long x 24 high, points along travel | cartoon rocket: body capsule #3DE3D0 (outline 1.5 pt), nose cone #FFD93D, porthole #BFFFF7 6.4 pt with outline, fins #FFD93D, white 5 x 4 pt highlight; tail of 2 stars (outline 1.2 pt): near star #FFF3A0 12 pt, far star #FFD93D 10 pt, behind the fins at 8 and 20 pt; add a 3rd star #FFFFFF 8 pt at 32 pt (alpha 0.6) while flying. Tail stars twinkle (scale 0.8 to 1.1 at 10 Hz). Optional soft additive glow #FFD93D 30 pt at 20 %. Pop: 6 stars (#FFD93D / #3DE3D0 / #FFFFFF, 10 pt, 0.4 s). Aim telegraph keeps its red dashed line (15.1) |
| Laserdrone ball (radius 10) | `proj_enemy` | 20 body (+ outline = 24) | candy-pink energy orb: ring #FF7AD9 (2 pt plum outline), inner #FFC2EF (60 % radius), white core #FFFFFF (28 %); no highlight streak; additive glow #FF7AD9 at 25 %, 36 pt, pulse 0.2 to 0.35 at 3 Hz. Trail: 3 pink sparkles (6 pt) each 12 pt. L4/L5 underglow (13.8) uses #FFC2EF at 35 %, not red |
Palette change: **enemy shot colours are #FF7AD9 / #D9C2FF / #B8F5DC / #FFD93D / #3DE3D0**. #FF3B5C remains for states (off/locked lights, doors), telegraph glows, rings, lines and the boss face (section 15.13). The red hit spark on enemy shots (section 12 common rules) becomes a pink or white spark. Hero projectiles stay orange, purple and yellow: the drone orb (pink) is the only pink shot, the spore puffball (lilac/mint) is the only lilac/mint shot, and neither shares a hue with a hero shot.
Delivery: code-drawn textures cached once (14.11); no new Gemini prompts. Hit radii are unchanged (JSON `projectileRadius`), the visuals may be larger than the radius but never smaller.
