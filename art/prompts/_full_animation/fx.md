# FX batch

Preamble: copy the block from `_style_preamble.md` first.

```
Cute anime cartoon video-game sprite for a kids' top-down shooter (ages 7-12). Chibi proportions: big head, large glossy anime eyes, small body. Bold clean dark-plum outline (#2B2140), uniform medium line weight, smooth rounded shapes. Bright saturated candy colors, soft two-tone cel shading, light from the top-left, a small white specular highlight. Friendly, funny, never scary. Camera: top-down three-quarter view, character faces right (east). Single subject, centered, fully visible with a small margin, readable silhouette at 64 pixels. Flat 2D vector-like illustration, no photo-realism, no painterly texture, no background scenery, no cast shadow on the background.
```

Visual effects. Bright, cute, no fire, no smoke realism, no blood. Defeat = enemies 'power down' into stars, bolts and sparkles.

Background: flat chroma green #00FF00 - transparent PNG strongly preferred for soft glows

Cell 512 px. On chroma background soft glow edges may fringe; prefer a generator that outputs transparency.

## fx_hitflash

- Group key / raw folder: `art/raw/fx_hitflash/`
- Atlas: `fx`; final file(s): `fx_hitflash_01@2x.png`, `fx_hitflash_02@2x.png` ... @2x, 96x96 px each (48x48 pt)
- Frames: 3 (one row sprite sheet, left to right)
- Subject: White impact starburst with a soft white core, growing and fading
- Frame notes: 3 frames, small to big, fading

Prompt:
```
[PREAMBLE] Subject: White impact starburst with a soft white core, growing and fading Sprite sheet of 3 frames in one row, equal cells. 3 frames, small to big, fading Background: flat chroma green #00FF00
```

## fx_poof

- Group key / raw folder: `art/raw/fx_poof/`
- Atlas: `fx`; final file(s): `fx_poof_01@2x.png`, `fx_poof_02@2x.png` ... @2x, 128x128 px each (64x64 pt)
- Frames: 6 (one row sprite sheet, left to right)
- Subject: Round cartoon puff cloud ring, soft lavender-white with plum outline, expanding and fading, with two tiny bolt shapes
- Frame notes: 6 frames

Prompt:
```
[PREAMBLE] Subject: Round cartoon puff cloud ring, soft lavender-white with plum outline, expanding and fading, with two tiny bolt shapes Sprite sheet of 6 frames in one row, equal cells. 6 frames Background: flat chroma green #00FF00
```

## fx_sparkles

- Group key / raw folder: `art/raw/fx_sparkles/`
- Atlas: `fx`; final file(s): `fx_sparkles_01@2x.png`, `fx_sparkles_02@2x.png` ... @2x, 128x128 px each (64x64 pt)
- Frames: 6 (one row sprite sheet, left to right)
- Subject: Burst of 4-point sparkle stars in yellow, white, cyan and pink flying outward, tiny star confetti
- Frame notes: 6 frames

Prompt:
```
[PREAMBLE] Subject: Burst of 4-point sparkle stars in yellow, white, cyan and pink flying outward, tiny star confetti Sprite sheet of 6 frames in one row, equal cells. 6 frames Background: flat chroma green #00FF00
```

## Negative prompt

```
NEGATIVE: blood, gore, wounds, violence against people, realistic weapons, real guns, knives, scary faces, horror, skulls, text, letters, numbers, logo, watermark, signature, speech bubbles, UI, border, frame, 3D render, photo, realistic lighting, dithering, blurry, low contrast, extra limbs, cropped subject, multiple unrelated characters, busy background, gradient background
```
