# UI batch

Preamble: copy the block from `_style_preamble.md` first.

```
Cute anime cartoon video-game sprite for a kids' top-down shooter (ages 7-12). Chibi proportions: big head, large glossy anime eyes, small body. Bold clean dark-plum outline (#2B2140), uniform medium line weight, smooth rounded shapes. Bright saturated candy colors, soft two-tone cel shading, light from the top-left, a small white specular highlight. Friendly, funny, never scary. Camera: top-down three-quarter view, character faces right (east). Single subject, centered, fully visible with a small margin, readable silhouette at 64 pixels. Flat 2D vector-like illustration, no photo-realism, no painterly texture, no background scenery, no cast shadow on the background.
```

Touch UI for an iPad HUD: chunky, glossy, rounded buttons in the same outline style. Dark indigo panels (#2E2A55 / #4A4585) with white or color rim. Icons are symbols only, absolutely no text or numbers.

Background: flat chroma green #00FF00, no shadow, no gradient - transparent PNG also fine

Joystick base: 640 px cell; fire button 384 px; others 256-512 px. Panels/bars may use transparent PNG instead of chroma. Health bar fill will be cropped/scaled by code, so keep it a plain horizontal strip.

## ui_joystick_base

- Group key / raw folder: `art/raw/ui_joystick_base/`
- Atlas: `ui`; final file(s): `ui_joystick_base@2x.png` @2x, 320x320 px each (160x160 pt)
- Frames: 1 (one row sprite sheet, left to right)
- Subject: Virtual joystick base: large translucent dark indigo circle with a white rim and faint arrow ticks
- Frame notes: single

Prompt:
```
[PREAMBLE] Subject: Virtual joystick base: large translucent dark indigo circle with a white rim and faint arrow ticks Sprite sheet of 1 frame in one row, equal cells. single Background: flat chroma green #00FF00, no shadow, no gradient
```

## ui_joystick_knob

- Group key / raw folder: `art/raw/ui_joystick_knob/`
- Atlas: `ui`; final file(s): `ui_joystick_knob@2x.png` @2x, 144x144 px each (72x72 pt)
- Frames: 1 (one row sprite sheet, left to right)
- Subject: Joystick knob: light cyan-white glossy ball
- Frame notes: single

Prompt:
```
[PREAMBLE] Subject: Joystick knob: light cyan-white glossy ball Sprite sheet of 1 frame in one row, equal cells. single Background: flat chroma green #00FF00, no shadow, no gradient
```

## ui_btn_fire

- Group key / raw folder: `art/raw/ui_btn_fire/`
- Atlas: `ui`; final file(s): `ui_btn_fire@2x.png` @2x, 192x192 px each (96x96 pt)
- Frames: 1 (one row sprite sheet, left to right)
- Subject: Round fire button, orange, white burst-star symbol
- Frame notes: single

Prompt:
```
[PREAMBLE] Subject: Round fire button, orange, white burst-star symbol Sprite sheet of 1 frame in one row, equal cells. single Background: flat chroma green #00FF00, no shadow, no gradient
```

## ui_btn_reload

- Group key / raw folder: `art/raw/ui_btn_reload/`
- Atlas: `ui`; final file(s): `ui_btn_reload@2x.png` @2x, 144x144 px each (72x72 pt)
- Frames: 1 (one row sprite sheet, left to right)
- Subject: Round blue button, white circular arrow symbol
- Frame notes: single

Prompt:
```
[PREAMBLE] Subject: Round blue button, white circular arrow symbol Sprite sheet of 1 frame in one row, equal cells. single Background: flat chroma green #00FF00, no shadow, no gradient
```

## ui_btn_interact

- Group key / raw folder: `art/raw/ui_btn_interact/`
- Atlas: `ui`; final file(s): `ui_btn_interact@2x.png` @2x, 144x144 px each (72x72 pt)
- Frames: 1 (one row sprite sheet, left to right)
- Subject: Round green button, white sparkle/hand symbol
- Frame notes: single

Prompt:
```
[PREAMBLE] Subject: Round green button, white sparkle/hand symbol Sprite sheet of 1 frame in one row, equal cells. single Background: flat chroma green #00FF00, no shadow, no gradient
```

## ui_btn_swap

- Group key / raw folder: `art/raw/ui_btn_swap/`
- Atlas: `ui`; final file(s): `ui_btn_swap@2x.png` @2x, 144x144 px each (72x72 pt)
- Frames: 1 (one row sprite sheet, left to right)
- Subject: Round purple button, two white opposing arrows
- Frame notes: single

Prompt:
```
[PREAMBLE] Subject: Round purple button, two white opposing arrows Sprite sheet of 1 frame in one row, equal cells. single Background: flat chroma green #00FF00, no shadow, no gradient
```

## ui_btn_pause

- Group key / raw folder: `art/raw/ui_btn_pause/`
- Atlas: `ui`; final file(s): `ui_btn_pause@2x.png` @2x, 128x128 px each (64x64 pt)
- Frames: 1 (one row sprite sheet, left to right)
- Subject: Round indigo button, two white vertical bars
- Frame notes: single

Prompt:
```
[PREAMBLE] Subject: Round indigo button, two white vertical bars Sprite sheet of 1 frame in one row, equal cells. single Background: flat chroma green #00FF00, no shadow, no gradient
```

## ui_btn_inventory

- Group key / raw folder: `art/raw/ui_btn_inventory/`
- Atlas: `ui`; final file(s): `ui_btn_inventory@2x.png` @2x, 144x144 px each (72x72 pt)
- Frames: 1 (one row sprite sheet, left to right)
- Subject: Round yellow button, white backpack symbol
- Frame notes: single

Prompt:
```
[PREAMBLE] Subject: Round yellow button, white backpack symbol Sprite sheet of 1 frame in one row, equal cells. single Background: flat chroma green #00FF00, no shadow, no gradient
```

## ui_quickslot

- Group key / raw folder: `art/raw/ui_quickslot/`
- Atlas: `ui`; final file(s): `ui_quickslot@2x.png` @2x, 144x144 px each (72x72 pt)
- Frames: 1 (one row sprite sheet, left to right)
- Subject: Quick slot frame: rounded square, dark indigo, light rim, empty inside
- Frame notes: single

Prompt:
```
[PREAMBLE] Subject: Quick slot frame: rounded square, dark indigo, light rim, empty inside Sprite sheet of 1 frame in one row, equal cells. single Background: flat chroma green #00FF00, no shadow, no gradient
```

## ui_quickslot_sel

- Group key / raw folder: `art/raw/ui_quickslot_sel/`
- Atlas: `ui`; final file(s): `ui_quickslot_sel@2x.png` @2x, 144x144 px each (72x72 pt)
- Frames: 1 (one row sprite sheet, left to right)
- Subject: Same, selected: glowing yellow rim
- Frame notes: single

Prompt:
```
[PREAMBLE] Subject: Same, selected: glowing yellow rim Sprite sheet of 1 frame in one row, equal cells. single Background: flat chroma green #00FF00, no shadow, no gradient
```

## ui_invslot

- Group key / raw folder: `art/raw/ui_invslot/`
- Atlas: `ui`; final file(s): `ui_invslot@2x.png` @2x, 128x128 px each (64x64 pt)
- Frames: 1 (one row sprite sheet, left to right)
- Subject: Inventory slot: smaller rounded square, dark indigo, empty
- Frame notes: single

Prompt:
```
[PREAMBLE] Subject: Inventory slot: smaller rounded square, dark indigo, empty Sprite sheet of 1 frame in one row, equal cells. single Background: flat chroma green #00FF00, no shadow, no gradient
```

## ui_invslot_sel

- Group key / raw folder: `art/raw/ui_invslot_sel/`
- Atlas: `ui`; final file(s): `ui_invslot_sel@2x.png` @2x, 128x128 px each (64x64 pt)
- Frames: 1 (one row sprite sheet, left to right)
- Subject: Same, selected: yellow rim
- Frame notes: single

Prompt:
```
[PREAMBLE] Subject: Same, selected: yellow rim Sprite sheet of 1 frame in one row, equal cells. single Background: flat chroma green #00FF00, no shadow, no gradient
```

## ui_hpbar_bg

- Group key / raw folder: `art/raw/ui_hpbar_bg/`
- Atlas: `ui`; final file(s): `ui_hpbar_bg@2x.png` @2x, 480x56 px each (240x28 pt)
- Frames: 1 (one row sprite sheet, left to right)
- Subject: Health bar background: long thin rounded capsule, dark inside, white rim
- Frame notes: single, aspect 240:28

Prompt:
```
[PREAMBLE] Subject: Health bar background: long thin rounded capsule, dark inside, white rim Sprite sheet of 1 frame in one row, equal cells. single, aspect 240:28 Background: flat chroma green #00FF00, no shadow, no gradient
```

## ui_hpbar_fill

- Group key / raw folder: `art/raw/ui_hpbar_fill/`
- Atlas: `ui`; final file(s): `ui_hpbar_fill@2x.png` @2x, 464x40 px each (232x20 pt)
- Frames: 1 (one row sprite sheet, left to right)
- Subject: Health bar fill: long rounded green capsule with a lighter top shine, no outline
- Frame notes: single, aspect 232:20

Prompt:
```
[PREAMBLE] Subject: Health bar fill: long rounded green capsule with a lighter top shine, no outline Sprite sheet of 1 frame in one row, equal cells. single, aspect 232:20 Background: flat chroma green #00FF00, no shadow, no gradient
```

## ui_icon_heart

- Group key / raw folder: `art/raw/ui_icon_heart/`
- Atlas: `ui`; final file(s): `ui_icon_heart@2x.png` @2x, 64x64 px each (32x32 pt)
- Frames: 1 (one row sprite sheet, left to right)
- Subject: Heart icon, red, outline, shine
- Frame notes: single

Prompt:
```
[PREAMBLE] Subject: Heart icon, red, outline, shine Sprite sheet of 1 frame in one row, equal cells. single Background: flat chroma green #00FF00, no shadow, no gradient
```

## ui_icon_ammo

- Group key / raw folder: `art/raw/ui_icon_ammo/`
- Atlas: `ui`; final file(s): `ui_icon_ammo@2x.png` @2x, 64x64 px each (32x32 pt)
- Frames: 1 (one row sprite sheet, left to right)
- Subject: Ammo icon: orange cartridge
- Frame notes: single

Prompt:
```
[PREAMBLE] Subject: Ammo icon: orange cartridge Sprite sheet of 1 frame in one row, equal cells. single Background: flat chroma green #00FF00, no shadow, no gradient
```

## ui_icon_star

- Group key / raw folder: `art/raw/ui_icon_star/`
- Atlas: `ui`; final file(s): `ui_icon_star@2x.png` @2x, 64x64 px each (32x32 pt)
- Frames: 1 (one row sprite sheet, left to right)
- Subject: Gold star icon
- Frame notes: single

Prompt:
```
[PREAMBLE] Subject: Gold star icon Sprite sheet of 1 frame in one row, equal cells. single Background: flat chroma green #00FF00, no shadow, no gradient
```

## ui_icon_blaster_starter

- Group key / raw folder: `art/raw/ui_icon_blaster_starter/`
- Atlas: `ui`; final file(s): `ui_icon_blaster_starter@2x.png` @2x, 64x64 px each (32x32 pt)
- Frames: 1 (one row sprite sheet, left to right)
- Subject: Orange toy blaster side view icon
- Frame notes: single

Prompt:
```
[PREAMBLE] Subject: Orange toy blaster side view icon Sprite sheet of 1 frame in one row, equal cells. single Background: flat chroma green #00FF00, no shadow, no gradient
```

## ui_icon_blaster_spread

- Group key / raw folder: `art/raw/ui_icon_blaster_spread/`
- Atlas: `ui`; final file(s): `ui_icon_blaster_spread@2x.png` @2x, 64x64 px each (32x32 pt)
- Frames: 1 (one row sprite sheet, left to right)
- Subject: Purple wide-nozzle toy blaster side view icon
- Frame notes: single

Prompt:
```
[PREAMBLE] Subject: Purple wide-nozzle toy blaster side view icon Sprite sheet of 1 frame in one row, equal cells. single Background: flat chroma green #00FF00, no shadow, no gradient
```

## ui_icon_blaster_rapid

- Group key / raw folder: `art/raw/ui_icon_blaster_rapid/`
- Atlas: `ui`; final file(s): `ui_icon_blaster_rapid@2x.png` @2x, 64x64 px each (32x32 pt)
- Frames: 1 (one row sprite sheet, left to right)
- Subject: Yellow sleek toy blaster side view icon
- Frame notes: single

Prompt:
```
[PREAMBLE] Subject: Yellow sleek toy blaster side view icon Sprite sheet of 1 frame in one row, equal cells. single Background: flat chroma green #00FF00, no shadow, no gradient
```

## ui_icon_pixel

- Group key / raw folder: `art/raw/ui_icon_pixel/`
- Atlas: `ui`; final file(s): `ui_icon_pixel@2x.png` @2x, 64x64 px each (32x32 pt)
- Frames: 1 (one row sprite sheet, left to right)
- Subject: Pixel drone face icon: cyan circle with dark screen face
- Frame notes: single

Prompt:
```
[PREAMBLE] Subject: Pixel drone face icon: cyan circle with dark screen face Sprite sheet of 1 frame in one row, equal cells. single Background: flat chroma green #00FF00, no shadow, no gradient
```

## Negative prompt

```
NEGATIVE: blood, gore, wounds, violence against people, realistic weapons, real guns, knives, scary faces, horror, skulls, text, letters, numbers, logo, watermark, signature, speech bubbles, UI, border, frame, 3D render, photo, realistic lighting, dithering, blurry, low contrast, extra limbs, cropped subject, multiple unrelated characters, busy background, gradient background
```
