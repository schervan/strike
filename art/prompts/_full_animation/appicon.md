# App icon

Preamble: copy the block from `_style_preamble.md` first, then:

```
Cute anime cartoon video-game sprite for a kids' top-down shooter (ages 7-12). Chibi proportions: big head, large glossy anime eyes, small body. Bold clean dark-plum outline (#2B2140), uniform medium line weight, smooth rounded shapes. Bright saturated candy colors, soft two-tone cel shading, light from the top-left, a small white specular highlight. Friendly, funny, never scary. Camera: top-down three-quarter view, character faces right (east). Single subject, centered, fully visible with a small margin, readable silhouette at 64 pixels. Flat 2D vector-like illustration, no photo-realism, no painterly texture, no background scenery, no cast shadow on the background.
```

- Output: 1024x1024 px PNG, opaque (no transparency, no rounded corners; iOS rounds it), no text.
- Subject: the hero's smiling face and shoulders (brown messy hair, orange headband) at the lower-left, Pixel the cyan drone floating at the upper-right, both looking at the viewer. A small toy blaster tip with a yellow star burst bottom-right. Evil red-magenta OVERMIND eye glowing faintly in the dark background behind them.
- Background: vertical gradient from deep indigo #2E2A55 (top) to bright purple #7A3FD6 (bottom) with a few sparkle stars. Keep important content inside the central 80 percent (safe zone).
- Must read at 40 px: strong shapes, high contrast, 3 main color areas (hero skin/orange, Pixel cyan, indigo-purple background).
- Frames: 1. Also generate a dark-mode/tinted-friendly variant: same but simplified, transparent background.

Prompt:
```
[PREAMBLE] App icon composition: hero face at lower-left, cyan drone Pixel upper-right, tiny toy blaster burst, faint glowing red-magenta robot eye in the background, indigo-to-purple gradient background with sparkles, square 1:1, centered, bold shapes.
```

## Negative prompt

```
NEGATIVE: blood, gore, wounds, violence against people, realistic weapons, real guns, knives, scary faces, horror, skulls, text, letters, numbers, logo, watermark, signature, speech bubbles, UI, border, frame, 3D render, photo, realistic lighting, dithering, blurry, low contrast, extra limbs, cropped subject, multiple unrelated characters, busy background, gradient background, rounded corners, mockup, device frame
```

Install: drop into `Strike/Resources/Assets.xcassets/AppIcon.appiconset/` (single 1024 universal icon).