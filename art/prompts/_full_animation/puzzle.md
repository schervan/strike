# Puzzle objects batch

Preamble: copy the block from `_style_preamble.md` first.

```
Cute anime cartoon video-game sprite for a kids' top-down shooter (ages 7-12). Chibi proportions: big head, large glossy anime eyes, small body. Bold clean dark-plum outline (#2B2140), uniform medium line weight, smooth rounded shapes. Bright saturated candy colors, soft two-tone cel shading, light from the top-left, a small white specular highlight. Friendly, funny, never scary. Camera: top-down three-quarter view, character faces right (east). Single subject, centered, fully visible with a small margin, readable silhouette at 64 pixels. Flat 2D vector-like illustration, no photo-realism, no painterly texture, no background scenery, no cast shadow on the background.
```

Top-down interactive objects that open the exit door. Same outline and palette. State changes must be obvious: red = off, green = on.

Background: flat chroma green #00FF00, no shadow, no gradient - transparent PNG also fine

Machine at 1024 px cells; the rest 512 px.

## puzzle_button_off

- Group key / raw folder: `art/raw/puzzle_button_off/`
- Atlas: `puzzle`; final file(s): `puzzle_button_off@2x.png` @2x, 128x128 px each (64x64 pt)
- Frames: 1 (one row sprite sheet, left to right)
- Subject: Floor button: gray-blue rounded base with a raised red round button
- Frame notes: single

Prompt:
```
[PREAMBLE] Subject: Floor button: gray-blue rounded base with a raised red round button Sprite sheet of 1 frame in one row, equal cells. single Background: flat chroma green #00FF00, no shadow, no gradient
```

## puzzle_button_on

- Group key / raw folder: `art/raw/puzzle_button_on/`
- Atlas: `puzzle`; final file(s): `puzzle_button_on@2x.png` @2x, 128x128 px each (64x64 pt)
- Frames: 1 (one row sprite sheet, left to right)
- Subject: Same button pressed down, now green
- Frame notes: single

Prompt:
```
[PREAMBLE] Subject: Same button pressed down, now green Sprite sheet of 1 frame in one row, equal cells. single Background: flat chroma green #00FF00, no shadow, no gradient
```

## puzzle_lever_off

- Group key / raw folder: `art/raw/puzzle_lever_off/`
- Atlas: `puzzle`; final file(s): `puzzle_lever_off@2x.png` @2x, 128x128 px each (64x64 pt)
- Frames: 1 (one row sprite sheet, left to right)
- Subject: Lever on a plate, stick tilted left, red knob
- Frame notes: single

Prompt:
```
[PREAMBLE] Subject: Lever on a plate, stick tilted left, red knob Sprite sheet of 1 frame in one row, equal cells. single Background: flat chroma green #00FF00, no shadow, no gradient
```

## puzzle_lever_on

- Group key / raw folder: `art/raw/puzzle_lever_on/`
- Atlas: `puzzle`; final file(s): `puzzle_lever_on@2x.png` @2x, 128x128 px each (64x64 pt)
- Frames: 1 (one row sprite sheet, left to right)
- Subject: Same lever tilted right, green knob
- Frame notes: single

Prompt:
```
[PREAMBLE] Subject: Same lever tilted right, green knob Sprite sheet of 1 frame in one row, equal cells. single Background: flat chroma green #00FF00, no shadow, no gradient
```

## puzzle_pressureplate_off

- Group key / raw folder: `art/raw/puzzle_pressureplate_off/`
- Atlas: `puzzle`; final file(s): `puzzle_pressureplate_off@2x.png` @2x, 128x128 px each (64x64 pt)
- Frames: 1 (one row sprite sheet, left to right)
- Subject: Square pressure plate, yellow center with arrow marks, raised
- Frame notes: single

Prompt:
```
[PREAMBLE] Subject: Square pressure plate, yellow center with arrow marks, raised Sprite sheet of 1 frame in one row, equal cells. single Background: flat chroma green #00FF00, no shadow, no gradient
```

## puzzle_pressureplate_on

- Group key / raw folder: `art/raw/puzzle_pressureplate_on/`
- Atlas: `puzzle`; final file(s): `puzzle_pressureplate_on@2x.png` @2x, 128x128 px each (64x64 pt)
- Frames: 1 (one row sprite sheet, left to right)
- Subject: Same plate pressed in, green
- Frame notes: single

Prompt:
```
[PREAMBLE] Subject: Same plate pressed in, green Sprite sheet of 1 frame in one row, equal cells. single Background: flat chroma green #00FF00, no shadow, no gradient
```

## puzzle_machine_off

- Group key / raw folder: `art/raw/puzzle_machine_off/`
- Atlas: `puzzle`; final file(s): `puzzle_machine_off@2x.png` @2x, 256x256 px each (128x128 pt)
- Frames: 1 (one row sprite sheet, left to right)
- Subject: Machine: big friendly console, 2x2 tiles, dark screen, three red lights, antenna
- Frame notes: single, 128x128 pt

Prompt:
```
[PREAMBLE] Subject: Machine: big friendly console, 2x2 tiles, dark screen, three red lights, antenna Sprite sheet of 1 frame in one row, equal cells. single, 128x128 pt Background: flat chroma green #00FF00, no shadow, no gradient
```

## puzzle_machine_on

- Group key / raw folder: `art/raw/puzzle_machine_on/`
- Atlas: `puzzle`; final file(s): `puzzle_machine_on@2x.png` @2x, 256x256 px each (128x128 pt)
- Frames: 1 (one row sprite sheet, left to right)
- Subject: Same machine on: cyan screen glow, three green lights
- Frame notes: single

Prompt:
```
[PREAMBLE] Subject: Same machine on: cyan screen glow, three green lights Sprite sheet of 1 frame in one row, equal cells. single Background: flat chroma green #00FF00, no shadow, no gradient
```

## puzzle_door_closed

- Group key / raw folder: `art/raw/puzzle_door_closed/`
- Atlas: `puzzle`; final file(s): `puzzle_door_closed@2x.png` @2x, 128x128 px each (64x64 pt)
- Frames: 1 (one row sprite sheet, left to right)
- Subject: Exit door seen from above: sturdy frame, two metal sliding halves closed, red lock light in the middle
- Frame notes: single

Prompt:
```
[PREAMBLE] Subject: Exit door seen from above: sturdy frame, two metal sliding halves closed, red lock light in the middle Sprite sheet of 1 frame in one row, equal cells. single Background: flat chroma green #00FF00, no shadow, no gradient
```

## puzzle_door_opening

- Group key / raw folder: `art/raw/puzzle_door_opening/`
- Atlas: `puzzle`; final file(s): `puzzle_door_opening_01@2x.png`, `puzzle_door_opening_02@2x.png` ... @2x, 128x128 px each (64x64 pt)
- Frames: 4 (one row sprite sheet, left to right)
- Subject: Same door with halves sliding apart gradually, lock light turning green
- Frame notes: 4 frames

Prompt:
```
[PREAMBLE] Subject: Same door with halves sliding apart gradually, lock light turning green Sprite sheet of 4 frames in one row, equal cells. 4 frames Background: flat chroma green #00FF00, no shadow, no gradient
```

## puzzle_door_open

- Group key / raw folder: `art/raw/puzzle_door_open/`
- Atlas: `puzzle`; final file(s): `puzzle_door_open@2x.png` @2x, 128x128 px each (64x64 pt)
- Frames: 1 (one row sprite sheet, left to right)
- Subject: Same door fully open, dark passage visible, green light
- Frame notes: single

Prompt:
```
[PREAMBLE] Subject: Same door fully open, dark passage visible, green light Sprite sheet of 1 frame in one row, equal cells. single Background: flat chroma green #00FF00, no shadow, no gradient
```

## Negative prompt

```
NEGATIVE: blood, gore, wounds, violence against people, realistic weapons, real guns, knives, scary faces, horror, skulls, text, letters, numbers, logo, watermark, signature, speech bubbles, UI, border, frame, 3D render, photo, realistic lighting, dithering, blurry, low contrast, extra limbs, cropped subject, multiple unrelated characters, busy background, gradient background
```
