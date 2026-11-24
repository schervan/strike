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
| Weapon colors | starter #FF8A3D, spread #B05CFF, rapid #FFD93D (projectile, ammo crate and HUD icon share it); enemy shot #FF3B5C |
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
