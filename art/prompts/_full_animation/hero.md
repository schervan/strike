# Hero batch

Preamble: copy the block from `_style_preamble.md` first.

```
Cute anime cartoon video-game sprite for a kids' top-down shooter (ages 7-12). Chibi proportions: big head, large glossy anime eyes, small body. Bold clean dark-plum outline (#2B2140), uniform medium line weight, smooth rounded shapes. Bright saturated candy colors, soft two-tone cel shading, light from the top-left, a small white specular highlight. Friendly, funny, never scary. Camera: top-down three-quarter view, character faces right (east). Single subject, centered, fully visible with a small margin, readable silhouette at 64 pixels. Flat 2D vector-like illustration, no photo-realism, no painterly texture, no background scenery, no cast shadow on the background.
```

The hero: a cheerful kid adventurer (gender-neutral, brown messy hair, orange headband, blue jacket, white gloves) holding a chunky colorful toy-like light blaster (orange, rounded, with a glowing tip). No realistic gun.

Background: flat chroma green #00FF00, no shadow, no gradient - transparent PNG also fine

## hero_idle

- Group key / raw folder: `art/raw/hero_idle/`
- Atlas: `hero`; final file(s): `hero_idle_01@2x.png`, `hero_idle_02@2x.png` ... @2x, 128x128 px each (64x64 pt)
- Frames: 4 (one row sprite sheet, left to right)
- Subject: the hero standing, blaster held at the side, breathing bounce, cheerful smile
- Frame notes: 4 frames, gentle up-down bounce, blink on frame 3

Prompt:
```
[PREAMBLE] Subject: the hero standing, blaster held at the side, breathing bounce, cheerful smile Sprite sheet of 4 frames in one row, equal cells. 4 frames, gentle up-down bounce, blink on frame 3 Background: flat chroma green #00FF00, no shadow, no gradient
```

## hero_walk

- Group key / raw folder: `art/raw/hero_walk/`
- Atlas: `hero`; final file(s): `hero_walk_01@2x.png`, `hero_walk_02@2x.png` ... @2x, 128x128 px each (64x64 pt)
- Frames: 6 (one row sprite sheet, left to right)
- Subject: the hero running right, blaster in front
- Frame notes: 6 frames, full run cycle, arms and legs alternate

Prompt:
```
[PREAMBLE] Subject: the hero running right, blaster in front Sprite sheet of 6 frames in one row, equal cells. 6 frames, full run cycle, arms and legs alternate Background: flat chroma green #00FF00, no shadow, no gradient
```

## hero_shoot

- Group key / raw folder: `art/raw/hero_shoot/`
- Atlas: `hero`; final file(s): `hero_shoot_01@2x.png`, `hero_shoot_02@2x.png` ... @2x, 128x128 px each (64x64 pt)
- Frames: 3 (one row sprite sheet, left to right)
- Subject: the hero firing the toy blaster to the right with a yellow star-shaped muzzle burst
- Frame notes: 3 frames: aim, fire with burst and slight recoil, recover

Prompt:
```
[PREAMBLE] Subject: the hero firing the toy blaster to the right with a yellow star-shaped muzzle burst Sprite sheet of 3 frames in one row, equal cells. 3 frames: aim, fire with burst and slight recoil, recover Background: flat chroma green #00FF00, no shadow, no gradient
```

## hero_hit

- Group key / raw folder: `art/raw/hero_hit/`
- Atlas: `hero`; final file(s): `hero_hit_01@2x.png`, `hero_hit_02@2x.png` @2x, 128x128 px each (64x64 pt)
- Frames: 2 (one row sprite sheet, left to right)
- Subject: the hero flinching, eyes squeezed shut, tiny sweat drop, whole body slightly whitened
- Frame notes: 2 frames, no pain, comedic

Prompt:
```
[PREAMBLE] Subject: the hero flinching, eyes squeezed shut, tiny sweat drop, whole body slightly whitened Sprite sheet of 2 frames in one row, equal cells. 2 frames, no pain, comedic Background: flat chroma green #00FF00, no shadow, no gradient
```

## Negative prompt

```
NEGATIVE: blood, gore, wounds, violence against people, realistic weapons, real guns, knives, scary faces, horror, skulls, text, letters, numbers, logo, watermark, signature, speech bubbles, UI, border, frame, 3D render, photo, realistic lighting, dithering, blurry, low contrast, extra limbs, cropped subject, multiple unrelated characters, busy background, gradient background
```
