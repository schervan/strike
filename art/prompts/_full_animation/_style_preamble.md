# Style preamble (paste verbatim at the start of EVERY prompt)

```
Cute anime cartoon video-game sprite for a kids' top-down shooter (ages 7-12). Chibi proportions: big head, large glossy anime eyes, small body. Bold clean dark-plum outline (#2B2140), uniform medium line weight, smooth rounded shapes. Bright saturated candy colors, soft two-tone cel shading, light from the top-left, a small white specular highlight. Friendly, funny, never scary. Camera: top-down three-quarter view, character faces right (east). Single subject, centered, fully visible with a small margin, readable silhouette at 64 pixels. Flat 2D vector-like illustration, no photo-realism, no painterly texture, no background scenery, no cast shadow on the background.
```

```
NEGATIVE: blood, gore, wounds, violence against people, realistic weapons, real guns, knives, scary faces, horror, skulls, text, letters, numbers, logo, watermark, signature, speech bubbles, UI, border, frame, 3D render, photo, realistic lighting, dithering, blurry, low contrast, extra limbs, cropped subject, multiple unrelated characters, busy background, gradient background
```

## Global rules
- Palette: see `docs/ART_BIBLE.md` section 2. Outline color is always #2B2140.
- Background: ONE flat chroma color covering the whole image with no gradient or shadow, specified per prompt (default #00FF00 green; #0033FF blue for green/pink subjects). Tiles are the exception (full-bleed, no background).
- Output: PNG, square cells. Sprite sheets: one animation per image, frames in one row left-to-right, equal cell size, subject centered in each cell and the same size and ground line in every frame.
- Cell size to generate: 512 px for sprites up to 64 pt, 1024 px for the boss and 128 pt+ machine; 4x the final @2x size is ideal. The slicer downsizes.
- Drop results into `art/raw/<group_key>/` (the group key is named in each prompt), then run `python3 tools/slice_atlas.py --chroma 00FF00` (or 0033FF).
- Record tool, model and date in `art/LICENSES.md` for every batch.
