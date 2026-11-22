# Pixel batch

Preamble: copy the block from `_style_preamble.md` first.

```
Cute anime cartoon video-game sprite for a kids' top-down shooter (ages 7-12). Chibi proportions: big head, large glossy anime eyes, small body. Bold clean dark-plum outline (#2B2140), uniform medium line weight, smooth rounded shapes. Bright saturated candy colors, soft two-tone cel shading, light from the top-left, a small white specular highlight. Friendly, funny, never scary. Camera: top-down three-quarter view, character faces right (east). Single subject, centered, fully visible with a small margin, readable silhouette at 64 pixels. Flat 2D vector-like illustration, no photo-realism, no painterly texture, no background scenery, no cast shadow on the background.
```

Pixel: the good AI drone buddy. Round cyan/teal ball body, small propeller on top, a dark rounded screen-face showing two glowing cyan eyes and a tiny mouth line, soft glow halo.

Background: flat chroma green #00FF00, no shadow, no gradient - transparent PNG also fine

## pixel_idle

- Group key / raw folder: `art/raw/pixel_idle/`
- Atlas: `pixel`; final file(s): `pixel_idle_01@2x.png`, `pixel_idle_02@2x.png` ... @2x, 96x96 px each (48x48 pt)
- Frames: 4 (one row sprite sheet, left to right)
- Subject: Pixel hovering, propeller blurred, screen blinking
- Frame notes: 4 frames, hover bob, blink on frame 3

Prompt:
```
[PREAMBLE] Subject: Pixel hovering, propeller blurred, screen blinking Sprite sheet of 4 frames in one row, equal cells. 4 frames, hover bob, blink on frame 3 Background: flat chroma green #00FF00, no shadow, no gradient
```

## pixel_talk

- Group key / raw folder: `art/raw/pixel_talk/`
- Atlas: `pixel`; final file(s): `pixel_talk_01@2x.png`, `pixel_talk_02@2x.png` ... @2x, 96x96 px each (48x48 pt)
- Frames: 3 (one row sprite sheet, left to right)
- Subject: Pixel talking, mouth opens and closes on its screen, eyes happy arcs on frame 2
- Frame notes: 3 frames

Prompt:
```
[PREAMBLE] Subject: Pixel talking, mouth opens and closes on its screen, eyes happy arcs on frame 2 Sprite sheet of 3 frames in one row, equal cells. 3 frames Background: flat chroma green #00FF00, no shadow, no gradient
```

## Negative prompt

```
NEGATIVE: blood, gore, wounds, violence against people, realistic weapons, real guns, knives, scary faces, horror, skulls, text, letters, numbers, logo, watermark, signature, speech bubbles, UI, border, frame, 3D render, photo, realistic lighting, dithering, blurry, low contrast, extra limbs, cropped subject, multiple unrelated characters, busy background, gradient background
```
