# Tiles L1: City Rooftop Lab

Preamble: copy the block from `_style_preamble.md` first.

```
Cute anime cartoon video-game sprite for a kids' top-down shooter (ages 7-12). Chibi proportions: big head, large glossy anime eyes, small body. Bold clean dark-plum outline (#2B2140), uniform medium line weight, smooth rounded shapes. Bright saturated candy colors, soft two-tone cel shading, light from the top-left, a small white specular highlight. Friendly, funny, never scary. Camera: top-down three-quarter view, character faces right (east). Single subject, centered, fully visible with a small margin, readable silhouette at 64 pixels. Flat 2D vector-like illustration, no photo-realism, no painterly texture, no background scenery, no cast shadow on the background.
```

Seamless top-down game tiles for level theme L1 (City Rooftop Lab). Palette: B8C4D6 / A6B3C8 floor, 5B6B8C / 7E90B5 wall, FFB347 accent. Tiles must tile seamlessly on all four edges, be flat top-down (no perspective on floors), low contrast so characters stay readable, no strong focal point. Walls get a slightly lit top face and a darker front lip (3/4 look).

Background: none - full-bleed square tile, no transparency, no margin, no outline around the tile edge (inner details may have the dark-plum outline)

Cell 512 px square (final 128x128 px). Subject-centering and margin rules from the preamble DO NOT apply to tiles: fill the whole cell edge to edge.

## tile_l1_floor

- Group key / raw folder: `art/raw/tile_l1_floor/`
- Atlas: `tiles`; final file(s): `tile_l1_floor_01@2x.png`, `tile_l1_floor_02@2x.png` ... @2x, 128x128 px each (64x64 pt)
- Frames: 3 (one row sprite sheet, left to right)
- Subject: Floor tile: light gray-blue concrete rooftop floor with subtle panel seams and tiny orange hazard dashes; walls are blue-gray lab walls and rooftop parapets with a lighter lit top face. Provide 3 variants: plain, plain with small wear marks, one with a tiny accent detail.
- Frame notes: 3 variants in one row

Prompt:
```
[PREAMBLE] Subject: Floor tile: light gray-blue concrete rooftop floor with subtle panel seams and tiny orange hazard dashes; walls are blue-gray lab walls and rooftop parapets with a lighter lit top face. Provide 3 variants: plain, plain with small wear marks, one with a tiny accent detail. Sprite sheet of 3 frames in one row, equal cells. 3 variants in one row Background: none
```

## tile_l1_wall

- Group key / raw folder: `art/raw/tile_l1_wall/`
- Atlas: `tiles`; final file(s): `tile_l1_wall_01@2x.png`, `tile_l1_wall_02@2x.png` @2x, 128x128 px each (64x64 pt)
- Frames: 2 (one row sprite sheet, left to right)
- Subject: Wall block tile: light gray-blue concrete rooftop floor with subtle panel seams and tiny orange hazard dashes; walls are blue-gray lab walls and rooftop parapets with a lighter lit top face. 2 variants: plain, and with a small accent light/detail.
- Frame notes: 2 variants in one row

Prompt:
```
[PREAMBLE] Subject: Wall block tile: light gray-blue concrete rooftop floor with subtle panel seams and tiny orange hazard dashes; walls are blue-gray lab walls and rooftop parapets with a lighter lit top face. 2 variants: plain, and with a small accent light/detail. Sprite sheet of 2 frames in one row, equal cells. 2 variants in one row Background: none
```

## Negative prompt

```
NEGATIVE: blood, gore, wounds, violence against people, realistic weapons, real guns, knives, scary faces, horror, skulls, text, letters, numbers, logo, watermark, signature, speech bubbles, UI, border, frame, 3D render, photo, realistic lighting, dithering, blurry, low contrast, extra limbs, cropped subject, multiple unrelated characters, busy background, gradient background, visible seams, vignette, perspective floor, characters, focal object in center
```
