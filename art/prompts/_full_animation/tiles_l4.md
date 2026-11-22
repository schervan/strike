# Tiles L4: Server Fortress

Preamble: copy the block from `_style_preamble.md` first.

```
Cute anime cartoon video-game sprite for a kids' top-down shooter (ages 7-12). Chibi proportions: big head, large glossy anime eyes, small body. Bold clean dark-plum outline (#2B2140), uniform medium line weight, smooth rounded shapes. Bright saturated candy colors, soft two-tone cel shading, light from the top-left, a small white specular highlight. Friendly, funny, never scary. Camera: top-down three-quarter view, character faces right (east). Single subject, centered, fully visible with a small margin, readable silhouette at 64 pixels. Flat 2D vector-like illustration, no photo-realism, no painterly texture, no background scenery, no cast shadow on the background.
```

Seamless top-down game tiles for level theme L4 (Server Fortress). Palette: 2B3A67 / 243158 floor, 151C3A / 3A4CA0 wall, 39F5FF accent. Tiles must tile seamlessly on all four edges, be flat top-down (no perspective on floors), low contrast so characters stay readable, no strong focal point. Walls get a slightly lit top face and a darker front lip (3/4 look).

Background: none - full-bleed square tile, no transparency, no margin, no outline around the tile edge (inner details may have the dark-plum outline)

Cell 512 px square (final 128x128 px). Subject-centering and margin rules from the preamble DO NOT apply to tiles: fill the whole cell edge to edge.

## tile_l4_floor

- Group key / raw folder: `art/raw/tile_l4_floor/`
- Atlas: `tiles`; final file(s): `tile_l4_floor_01@2x.png`, `tile_l4_floor_02@2x.png` ... @2x, 128x128 px each (64x64 pt)
- Frames: 3 (one row sprite sheet, left to right)
- Subject: Floor tile: dark navy circuit-board floor with thin glowing cyan trace lines; walls are black-blue server racks with blinking cyan and violet LEDs. Provide 3 variants: plain, plain with small wear marks, one with a tiny accent detail.
- Frame notes: 3 variants in one row

Prompt:
```
[PREAMBLE] Subject: Floor tile: dark navy circuit-board floor with thin glowing cyan trace lines; walls are black-blue server racks with blinking cyan and violet LEDs. Provide 3 variants: plain, plain with small wear marks, one with a tiny accent detail. Sprite sheet of 3 frames in one row, equal cells. 3 variants in one row Background: none
```

## tile_l4_wall

- Group key / raw folder: `art/raw/tile_l4_wall/`
- Atlas: `tiles`; final file(s): `tile_l4_wall_01@2x.png`, `tile_l4_wall_02@2x.png` @2x, 128x128 px each (64x64 pt)
- Frames: 2 (one row sprite sheet, left to right)
- Subject: Wall block tile: dark navy circuit-board floor with thin glowing cyan trace lines; walls are black-blue server racks with blinking cyan and violet LEDs. 2 variants: plain, and with a small accent light/detail.
- Frame notes: 2 variants in one row

Prompt:
```
[PREAMBLE] Subject: Wall block tile: dark navy circuit-board floor with thin glowing cyan trace lines; walls are black-blue server racks with blinking cyan and violet LEDs. 2 variants: plain, and with a small accent light/detail. Sprite sheet of 2 frames in one row, equal cells. 2 variants in one row Background: none
```

## Negative prompt

```
NEGATIVE: blood, gore, wounds, violence against people, realistic weapons, real guns, knives, scary faces, horror, skulls, text, letters, numbers, logo, watermark, signature, speech bubbles, UI, border, frame, 3D render, photo, realistic lighting, dithering, blurry, low contrast, extra limbs, cropped subject, multiple unrelated characters, busy background, gradient background, visible seams, vignette, perspective floor, characters, focal object in center
```
