# Strike art prompts for Gemini (lite set, 36 images)

Owner guide. Each prompt below is complete: copy the text block, attach the files named under **Attach**, send, then save the image under the **Save as** name. No editing of the prompt needed.

## Workflow

1. Open gemini.google.com and start a **new chat per prompt** (this keeps results independent). Pick the image-generation / "Create images" mode if the app offers it.
2. Do prompt **#1 (hero) first** and iterate with the follow-up lines until you love the hero. Keep the approved hero image as `art/raw/hero.png`: every later prompt attaches it as the **style reference**.
3. For prompts #2 onward: attach the files listed under **Attach** (use the paperclip / `+` button), paste the prompt, send.
4. Download the PNG, rename it to the **Save as** name and put it in `art/raw/`. One file per prompt, no sub-folders.
5. When you have a batch ready, tell Claude **"art ready"**. Claude runs `python3 tools/slice_atlas.py --report`, slices the sheets, and reports missing or odd images.

## Things to know

- **Backgrounds.** Gemini cannot make transparent PNGs and will not hit an exact color. That is fine: the slicer removes the flat background. Green is used by default. **Magenta** is used for green or pink subjects (slimes, spore-plant, green items, all on/off puzzle pairs).
- **Sparkle watermark.** Gemini may put a small sparkle in the bottom-right corner. Leave it, the slicer ignores it. (Google AI Studio images usually have none, the prompts work there too.)
- **Flat background matters, exact colors do not.** If the background has a shadow, gradient or floor, use the "If it goes wrong" line.
- **Characters face right.** Drawn in a three-quarter top-down view. The game mirrors them to face left.
- **One key pose per character.** The game animates it with code (bobbing, squash, recoil, white hit flash), so you do not need walk frames.
- **Grids and pairs.** Items must not touch each other. If they do, use the follow-up "spread the items further apart".
- **Tiles** are full-bleed seamless textures with no background; the slicer crops the middle and makes them tile.
- **Square / wide.** The last line of every prompt names the aspect ratio. Gemini sometimes ignores it: that is OK, the slicer works with any size, but keep the layout.
- **License log.** After each batch add a row to `art/LICENSES.md` (tool, model, date, plan).

## Checklist

- [ ] #1 `hero`
- [ ] #2 `pixel`
- [ ] #3 `enemy_boltbot`
- [ ] #4 `enemy_laserdrone`
- [ ] #5 `enemy_slimemutant`
- [ ] #6 `enemy_slimemutant_small`
- [ ] #7 `enemy_shieldandroid`
- [ ] #8 `enemy_sporeplant`
- [ ] #9 `boss_megamech`
- [ ] #10 `projectiles`
- [ ] #11 `pickups_heal`
- [ ] #12 `pickups_ammo`
- [ ] #13 `pickups_keys`
- [ ] #14 `pickups_blasters`
- [ ] #15 `puzzle_button`
- [ ] #16 `puzzle_lever`
- [ ] #17 `puzzle_pressureplate`
- [ ] #18 `puzzle_machine`
- [ ] #19 `puzzle_door`
- [ ] #20 `puzzle_crate`
- [ ] #21 `puzzle_checkpoint`
- [ ] #22 `puzzle_exitpad`
- [ ] #23 `tile_l1_floor`
- [ ] #24 `tile_l1_wall`
- [ ] #25 `tile_l2_floor`
- [ ] #26 `tile_l2_wall`
- [ ] #27 `tile_l3_floor`
- [ ] #28 `tile_l3_wall`
- [ ] #29 `tile_l4_floor`
- [ ] #30 `tile_l4_wall`
- [ ] #31 `tile_l5_floor`
- [ ] #32 `tile_l5_wall`
- [ ] #33 `ui_icons_a`
- [ ] #34 `ui_icons_b`
- [ ] #35 `appicon`
- [ ] #36 `ui_icon_gear`

---

## #1  Hero

**Save as:** `art/raw/hero.png`  
**Attach:** nothing (this is the style reference for everything else)  
**Image:** square, one image  
**Slicer expects:** green background, 1 item(s)

```text
Cute anime cartoon video-game art for a kids' top-down shooter (ages 7 to 12). Chibi proportions with a big head, large glossy anime eyes and a small body. Bold, clean dark plum outlines of uniform medium thickness, smooth rounded shapes, bright saturated candy colors, soft two-tone cel shading with the light coming from the top-left and one small white highlight. Friendly and funny, never scary. Flat 2D vector-like illustration, no photo-realism, no painterly texture.

Subject: the hero, a cheerful gender-neutral kid adventurer with messy brown hair, an orange headband, a bright blue jacket, white gloves, big friendly eyes and a happy smile. The hero holds a chunky, rounded, toy-like orange light blaster with a glowing cyan tip (clearly a toy, not a real gun). Neutral standing pose, full body from head to feet, three-quarter top-down view, facing right, blaster held forward at the hip.

Layout: One single character, centered, fully visible with a generous margin on every side, nothing else in the image.

Background: Plain solid bright green background (pure chroma-key green), completely flat and uniform, with no shadows, no floor, no gradient, no vignette, no scenery, and no green anywhere in the subject itself.

Do not include: text, letters, numbers, logos, watermarks, borders, frames, speech bubbles, blood, gore, wounds, scary or creepy faces, realistic weapons or real guns, knives, photo-realistic or 3D rendering, cast shadows on the background, extra characters or props.

Square image (1:1).

Output file name: hero.png (save and offer the image for download as hero.png).
```

**If it goes wrong** (send as a follow-up in the same chat):
- "Same character, but facing right and standing in a relaxed neutral pose, feet visible."
- "The blaster looks too realistic. Make it a chunky, rounded, colorful toy blaster."
- "Make the background one pure, flat, solid bright green with no shadow or gradient."

---

## #2  Pixel, the drone buddy

**Save as:** `art/raw/pixel.png`  
**Attach:** the approved hero image (art/raw/hero.png)  
**Image:** square, one image  
**Slicer expects:** green background, 1 item(s)

```text
Use the attached image only as a style reference: copy its outline thickness, color saturation and shading style, but do not copy its subject.

Cute anime cartoon video-game art for a kids' top-down shooter (ages 7 to 12). Chibi proportions with a big head, large glossy anime eyes and a small body. Bold, clean dark plum outlines of uniform medium thickness, smooth rounded shapes, bright saturated candy colors, soft two-tone cel shading with the light coming from the top-left and one small white highlight. Friendly and funny, never scary. Flat 2D vector-like illustration, no photo-realism, no painterly texture.

Subject: Pixel, the good AI drone buddy: a round, friendly, floating ball-shaped drone in glowing cyan and teal, with a small propeller on top, two tiny side fins, and a dark navy screen on the front acting as a face with two big glowing cyan eyes and a small happy smile. A soft cyan glow around the body. The face is turned slightly to the right. No legs, it floats.

Layout: One single character, centered, fully visible with a generous margin on every side, nothing else in the image.

Background: Plain solid bright green background (pure chroma-key green), completely flat and uniform, with no shadows, no floor, no gradient, no vignette, no scenery, and no green anywhere in the subject itself.

Do not include: text, letters, numbers, logos, watermarks, borders, frames, speech bubbles, blood, gore, wounds, scary or creepy faces, realistic weapons or real guns, knives, photo-realistic or 3D rendering, cast shadows on the background, extra characters or props.

Square image (1:1).

Output file name: pixel.png (save and offer the image for download as pixel.png).
```

**If it goes wrong** (send as a follow-up in the same chat):
- "Make the screen a dark navy rounded square with two big glowing cyan eyes and a smile, and turn the face slightly to the right."
- "Remove the shadow under the drone and the green reflection on the body."
- "Make the background one pure, flat, solid bright green with no shadow or gradient."

---

## #3  Enemy: boltbot

**Save as:** `art/raw/enemy_boltbot.png`  
**Attach:** the approved hero image (art/raw/hero.png)  
**Image:** square, one image  
**Slicer expects:** green background, 1 item(s)

```text
Use the attached image only as a style reference: copy its outline thickness, color saturation and shading style, but do not copy its subject.

Cute anime cartoon video-game art for a kids' top-down shooter (ages 7 to 12). Chibi proportions with a big head, large glossy anime eyes and a small body. Bold, clean dark plum outlines of uniform medium thickness, smooth rounded shapes, bright saturated candy colors, soft two-tone cel shading with the light coming from the top-left and one small white highlight. Friendly and funny, never scary. Flat 2D vector-like illustration, no photo-realism, no painterly texture.

Subject: Bolt-bot, a cute-evil minion robot of the evil AI OVERMIND: a boxy light blue-gray robot on a single round wheel base, with a big round glowing red visor eye, an orange antenna with a glowing bulb on top, stubby little arms and a grumpy-but-goofy expression. Full body, three-quarter top-down view, facing right.

Layout: One single character, centered, fully visible with a generous margin on every side, nothing else in the image.

Background: Plain solid bright green background (pure chroma-key green), completely flat and uniform, with no shadows, no floor, no gradient, no vignette, no scenery, and no green anywhere in the subject itself.

Do not include: text, letters, numbers, logos, watermarks, borders, frames, speech bubbles, blood, gore, wounds, scary or creepy faces, realistic weapons or real guns, knives, photo-realistic or 3D rendering, cast shadows on the background, extra characters or props.

Square image (1:1).

Output file name: enemy_boltbot.png (save and offer the image for download as enemy_boltbot.png).
```

**If it goes wrong** (send as a follow-up in the same chat):
- "Same robot, facing right, with one big red visor eye and an orange antenna bulb."
- "Make it cuter and goofier, less menacing: rounder shapes, bigger eye."
- "Make the background one pure, flat, solid bright green with no shadow or gradient."

---

## #4  Enemy: laserdrone

**Save as:** `art/raw/enemy_laserdrone.png`  
**Attach:** the approved hero image (art/raw/hero.png)  
**Image:** square, one image  
**Slicer expects:** green background, 1 item(s)

```text
Use the attached image only as a style reference: copy its outline thickness, color saturation and shading style, but do not copy its subject.

Cute anime cartoon video-game art for a kids' top-down shooter (ages 7 to 12). Chibi proportions with a big head, large glossy anime eyes and a small body. Bold, clean dark plum outlines of uniform medium thickness, smooth rounded shapes, bright saturated candy colors, soft two-tone cel shading with the light coming from the top-left and one small white highlight. Friendly and funny, never scary. Flat 2D vector-like illustration, no photo-realism, no painterly texture.

Subject: Laser-drone, a cute-evil flying minion robot of the evil AI OVERMIND: a round purple floating orb with one big eyeball with a red iris, two small wing panels on the sides, a tiny glowing magenta cannon under the eye, and a mischievous grin-like panel line. It hovers (no legs). Three-quarter top-down view, facing right.

Layout: One single character, centered, fully visible with a generous margin on every side, nothing else in the image.

Background: Plain solid bright green background (pure chroma-key green), completely flat and uniform, with no shadows, no floor, no gradient, no vignette, no scenery, and no green anywhere in the subject itself.

Do not include: text, letters, numbers, logos, watermarks, borders, frames, speech bubbles, blood, gore, wounds, scary or creepy faces, realistic weapons or real guns, knives, photo-realistic or 3D rendering, cast shadows on the background, extra characters or props.

Square image (1:1).

Output file name: enemy_laserdrone.png (save and offer the image for download as enemy_laserdrone.png).
```

**If it goes wrong** (send as a follow-up in the same chat):
- "Make it a round purple orb with one big red-iris eye and two small wing panels, facing right."
- "Remove the motion lines and the ground shadow."
- "Make the background one pure, flat, solid bright green with no shadow or gradient."

---

## #5  Enemy: slimemutant

**Save as:** `art/raw/enemy_slimemutant.png`  
**Attach:** the approved hero image (art/raw/hero.png)  
**Image:** square, one image  
**Slicer expects:** magenta background, 1 item(s)

```text
Use the attached image only as a style reference: copy its outline thickness, color saturation and shading style, but do not copy its subject.

Cute anime cartoon video-game art for a kids' top-down shooter (ages 7 to 12). Chibi proportions with a big head, large glossy anime eyes and a small body. Bold, clean dark plum outlines of uniform medium thickness, smooth rounded shapes, bright saturated candy colors, soft two-tone cel shading with the light coming from the top-left and one small white highlight. Friendly and funny, never scary. Flat 2D vector-like illustration, no photo-realism, no painterly texture.

Subject: Slime-mutant, a cute gene-creature: a glossy lime-green jelly blob with a flat bottom, big googly eyes, a wobbly goofy smile without teeth, a few little bubbles inside the body and a shiny white highlight on the top left. It looks funny, not gross. Three-quarter top-down view, eyes looking to the right.

Layout: One single character, centered, fully visible with a generous margin on every side, nothing else in the image.

Background: Plain solid bright magenta background (hot pink-purple, like #FF00FF), completely flat and uniform, with no shadows, no floor, no gradient, no vignette, no scenery, and no magenta or hot pink anywhere in the subject itself.

Do not include: text, letters, numbers, logos, watermarks, borders, frames, speech bubbles, blood, gore, wounds, scary or creepy faces, realistic weapons or real guns, knives, photo-realistic or 3D rendering, cast shadows on the background, extra characters or props.

Square image (1:1).

Output file name: enemy_slimemutant.png (save and offer the image for download as enemy_slimemutant.png).
```

**If it goes wrong** (send as a follow-up in the same chat):
- "Make the slime a clean lime-green jelly blob with googly eyes, no drips on the ground."
- "The slime blends into the background. Keep a dark plum outline all around it."
- "Make the background one pure, flat, solid bright magenta with no shadow or gradient."

---

## #6  Enemy: slimemutant small

**Save as:** `art/raw/enemy_slimemutant_small.png`  
**Attach:** the Slime-mutant image (art/raw/enemy_slimemutant.png)  
**Image:** square, one image  
**Slicer expects:** magenta background, 1 item(s)

```text
Use the attached image only as a style reference: copy its outline thickness, color saturation and shading style, but do not copy its subject.

Cute anime cartoon video-game art for a kids' top-down shooter (ages 7 to 12). Chibi proportions with a big head, large glossy anime eyes and a small body. Bold, clean dark plum outlines of uniform medium thickness, smooth rounded shapes, bright saturated candy colors, soft two-tone cel shading with the light coming from the top-left and one small white highlight. Friendly and funny, never scary. Flat 2D vector-like illustration, no photo-realism, no painterly texture.

Subject: a tiny baby Slime-mutant, the little split-off version of the attached slime: the same lime-green glossy jelly style and the same kind of googly eyes, but smaller and rounder, with one eye slightly bigger than the other and a cheeky smile. Three-quarter top-down view, eyes looking to the right.

Layout: One single character, centered, fully visible with a generous margin on every side, nothing else in the image.

Background: Plain solid bright magenta background (hot pink-purple, like #FF00FF), completely flat and uniform, with no shadows, no floor, no gradient, no vignette, no scenery, and no magenta or hot pink anywhere in the subject itself.

Do not include: text, letters, numbers, logos, watermarks, borders, frames, speech bubbles, blood, gore, wounds, scary or creepy faces, realistic weapons or real guns, knives, photo-realistic or 3D rendering, cast shadows on the background, extra characters or props.

Square image (1:1).

Output file name: enemy_slimemutant_small.png (save and offer the image for download as enemy_slimemutant_small.png).
```

**If it goes wrong** (send as a follow-up in the same chat):
- "Same style as the attached slime but a baby version: rounder, cuter, with one slightly bigger eye."
- "Make the background one pure, flat, solid bright magenta with no shadow or gradient."

---

## #7  Enemy: shieldandroid

**Save as:** `art/raw/enemy_shieldandroid.png`  
**Attach:** the approved hero image (art/raw/hero.png)  
**Image:** square, one image  
**Slicer expects:** green background, 1 item(s)

```text
Use the attached image only as a style reference: copy its outline thickness, color saturation and shading style, but do not copy its subject.

Cute anime cartoon video-game art for a kids' top-down shooter (ages 7 to 12). Chibi proportions with a big head, large glossy anime eyes and a small body. Bold, clean dark plum outlines of uniform medium thickness, smooth rounded shapes, bright saturated candy colors, soft two-tone cel shading with the light coming from the top-left and one small white highlight. Friendly and funny, never scary. Flat 2D vector-like illustration, no photo-realism, no painterly texture.

Subject: Shield-android, a cute-evil minion robot of the evil AI OVERMIND: a compact chibi silver humanoid android with a big round helmet head, a dark visor with two glowing red eyes, a small body, and a big glowing teal energy-shield bubble held in front of it on the right side. Full body, three-quarter top-down view, facing right.

Layout: One single character, centered, fully visible with a generous margin on every side, nothing else in the image.

Background: Plain solid bright green background (pure chroma-key green), completely flat and uniform, with no shadows, no floor, no gradient, no vignette, no scenery, and no green anywhere in the subject itself.

Do not include: text, letters, numbers, logos, watermarks, borders, frames, speech bubbles, blood, gore, wounds, scary or creepy faces, realistic weapons or real guns, knives, photo-realistic or 3D rendering, cast shadows on the background, extra characters or props.

Square image (1:1).

Output file name: enemy_shieldandroid.png (save and offer the image for download as enemy_shieldandroid.png).
```

**If it goes wrong** (send as a follow-up in the same chat):
- "Put the teal energy shield on the right side, in front of the android, and make the android silver with red eyes."
- "Make the proportions chibi: big head, small body."
- "Make the background one pure, flat, solid bright green with no shadow or gradient."

---

## #8  Enemy: sporeplant

**Save as:** `art/raw/enemy_sporeplant.png`  
**Attach:** the approved hero image (art/raw/hero.png)  
**Image:** square, one image  
**Slicer expects:** magenta background, 1 item(s)

```text
Use the attached image only as a style reference: copy its outline thickness, color saturation and shading style, but do not copy its subject.

Cute anime cartoon video-game art for a kids' top-down shooter (ages 7 to 12). Chibi proportions with a big head, large glossy anime eyes and a small body. Bold, clean dark plum outlines of uniform medium thickness, smooth rounded shapes, bright saturated candy colors, soft two-tone cel shading with the light coming from the top-left and one small white highlight. Friendly and funny, never scary. Flat 2D vector-like illustration, no photo-realism, no painterly texture.

Subject: Spore-plant, a cute gene-creature that stays in one place: a round light pastel-pink bulb on a short green stem with two leaves, big googly eyes, and a wide round open mouth on the right side from which a few little spore puffs float out. The bulb is a light, soft pastel pink with a dark plum outline, lighter than hot pink. Three-quarter top-down view, facing right.

Layout: One single character, centered, fully visible with a generous margin on every side, nothing else in the image.

Background: Plain solid bright magenta background (hot pink-purple, like #FF00FF), completely flat and uniform, with no shadows, no floor, no gradient, no vignette, no scenery, and no magenta or hot pink anywhere in the subject itself.

Do not include: text, letters, numbers, logos, watermarks, borders, frames, speech bubbles, blood, gore, wounds, scary or creepy faces, realistic weapons or real guns, knives, photo-realistic or 3D rendering, cast shadows on the background, extra characters or props.

Square image (1:1).

Output file name: enemy_sporeplant.png (save and offer the image for download as enemy_sporeplant.png).
```

**If it goes wrong** (send as a follow-up in the same chat):
- "Make the bulb a light pastel pink (not hot pink) with a clear dark plum outline so it stands out from the background."
- "Remove the pot and the ground; only the plant with its stem."
- "Make the background one pure, flat, solid bright magenta with no shadow or gradient."

---

## #9  Boss: megamech

**Save as:** `art/raw/boss_megamech.png`  
**Attach:** the approved hero image (art/raw/hero.png) and the Bolt-bot image (art/raw/enemy_boltbot.png)  
**Image:** square, one image  
**Slicer expects:** green background, 1 item(s)

```text
Use the attached image only as a style reference: copy its outline thickness, color saturation and shading style, but do not copy its subject.

Cute anime cartoon video-game art for a kids' top-down shooter (ages 7 to 12). Chibi proportions with a big head, large glossy anime eyes and a small body. Bold, clean dark plum outlines of uniform medium thickness, smooth rounded shapes, bright saturated candy colors, soft two-tone cel shading with the light coming from the top-left and one small white highlight. Friendly and funny, never scary. Flat 2D vector-like illustration, no photo-realism, no painterly texture.

Subject: MEGA-MECH Unit Zero, the big boss robot of the evil AI OVERMIND: a huge chibi mech with violet-blue armor, a big glowing magenta energy core in the chest, one large glowing red eye visor on a small head, broad shoulders, oversized orange fists, short stubby legs in a wide stance, and a goofy-evil look (funny, not scary). Full body, three-quarter top-down view, facing right.

Layout: One single character, centered, fully visible with a generous margin on every side, nothing else in the image.

Background: Plain solid bright green background (pure chroma-key green), completely flat and uniform, with no shadows, no floor, no gradient, no vignette, no scenery, and no green anywhere in the subject itself.

Do not include: text, letters, numbers, logos, watermarks, borders, frames, speech bubbles, blood, gore, wounds, scary or creepy faces, realistic weapons or real guns, knives, photo-realistic or 3D rendering, cast shadows on the background, extra characters or props.

Square image (1:1).

Output file name: boss_megamech.png (save and offer the image for download as boss_megamech.png).
```

**If it goes wrong** (send as a follow-up in the same chat):
- "Make the boss look goofy-evil and chibi: bigger head and fists, shorter legs, rounder armor."
- "Remove the smoke, sparks and the background; only the mech."
- "Make the background one pure, flat, solid bright green with no shadow or gradient."

---

## #10  Projectiles

**Save as:** `art/raw/projectiles.png`  
**Attach:** the approved hero image (art/raw/hero.png)  
**Image:** square, one image  
**Slicer expects:** green background, 4 item(s) in grid2x2

```text
Use the attached image only as a style reference: copy its outline thickness, color saturation and shading style, but do not copy its subject.

Cute anime cartoon video-game art for a kids' top-down shooter (ages 7 to 12). Chibi proportions with a big head, large glossy anime eyes and a small body. Bold, clean dark plum outlines of uniform medium thickness, smooth rounded shapes, bright saturated candy colors, soft two-tone cel shading with the light coming from the top-left and one small white highlight. Friendly and funny, never scary. Flat 2D vector-like illustration, no photo-realism, no painterly texture.

Subject: four small glowing energy shots for toy blasters, drawn as simple round shapes seen from above, each with a dark plum outline, a bright core and only a thin soft halo (keep the edges crisp). Top-left: the starter shot, a warm orange orb with a white center. Top-right: the spread shot, a purple bubble with a white highlight. Bottom-left: the rapid shot, a yellow glowing spark orb. Bottom-right: the enemy shot, a red-magenta orb with a darker red core.

Layout: A 2 by 2 grid of exactly four separate projectile icons, each one centered in its own quarter of the image, same visual size, with generous empty background between and around them so that nothing touches or overlaps.

Background: Plain solid bright green background (pure chroma-key green), completely flat and uniform, with no shadows, no floor, no gradient, no vignette, no scenery, and no green anywhere in the subject itself.

Do not include: text, letters, numbers, logos, watermarks, borders, frames, speech bubbles, blood, gore, wounds, scary or creepy faces, realistic weapons or real guns, knives, photo-realistic or 3D rendering, cast shadows on the background, extra items beyond the ones listed.

Square image (1:1).

Output file name: projectiles.png (save and offer the image for download as projectiles.png).
```

**If it goes wrong** (send as a follow-up in the same chat):
- "Make each shot a simple round orb with a crisp dark plum outline and only a very thin glow."
- "Spread the four shots further apart so that none of them touch."
- "Make the background one pure, flat, solid bright green with no shadow or gradient."

---

## #11  Pickups: heal

**Save as:** `art/raw/pickups_heal.png`  
**Attach:** the approved hero image (art/raw/hero.png)  
**Image:** square, one image  
**Slicer expects:** magenta background, 4 item(s) in grid2x2

```text
Use the attached image only as a style reference: copy its outline thickness, color saturation and shading style, but do not copy its subject.

Cute anime cartoon video-game art for a kids' top-down shooter (ages 7 to 12). Chibi proportions with a big head, large glossy anime eyes and a small body. Bold, clean dark plum outlines of uniform medium thickness, smooth rounded shapes, bright saturated candy colors, soft two-tone cel shading with the light coming from the top-left and one small white highlight. Friendly and funny, never scary. Flat 2D vector-like illustration, no photo-realism, no painterly texture.

Subject: four small collectible items for a video game, drawn straight from above in chunky icon style, each with a dark plum outline. Top-left: a heal pack, a white first-aid box with a green cross. Top-right: a shiny red apple with a green leaf. Bottom-left: a round onigiri rice ball with a dark green seaweed strip. Bottom-right: a round chocolate-chip cookie.

Layout: A 2 by 2 grid of exactly four separate items, each one centered in its own quarter of the image, same visual size, with generous empty background between and around them so that nothing touches or overlaps.

Background: Plain solid bright magenta background (hot pink-purple, like #FF00FF), completely flat and uniform, with no shadows, no floor, no gradient, no vignette, no scenery, and no magenta or hot pink anywhere in the subject itself.

Do not include: text, letters, numbers, logos, watermarks, borders, frames, speech bubbles, blood, gore, wounds, scary or creepy faces, realistic weapons or real guns, knives, photo-realistic or 3D rendering, cast shadows on the background, extra items beyond the ones listed.

Square image (1:1).

Output file name: pickups_heal.png (save and offer the image for download as pickups_heal.png).
```

**If it goes wrong** (send as a follow-up in the same chat):
- "Make all four items the same size, drawn straight from above, with a dark plum outline."
- "Make the background one pure, flat, solid bright magenta with no shadow or gradient."

---

## #12  Pickups: ammo

**Save as:** `art/raw/pickups_ammo.png`  
**Attach:** the approved hero image (art/raw/hero.png)  
**Image:** square, one image  
**Slicer expects:** green background, 4 item(s) in grid2x2

```text
Use the attached image only as a style reference: copy its outline thickness, color saturation and shading style, but do not copy its subject.

Cute anime cartoon video-game art for a kids' top-down shooter (ages 7 to 12). Chibi proportions with a big head, large glossy anime eyes and a small body. Bold, clean dark plum outlines of uniform medium thickness, smooth rounded shapes, bright saturated candy colors, soft two-tone cel shading with the light coming from the top-left and one small white highlight. Friendly and funny, never scary. Flat 2D vector-like illustration, no photo-realism, no painterly texture.

Subject: four small collectible items for a video game, drawn straight from above in chunky icon style, each with a dark plum outline. Top-left: a small toy ammo box in orange with three white foam-dart tips. Top-right: the same style of ammo box in purple. Bottom-left: the same style of ammo box in yellow. Bottom-right: an energy core, a glowing cyan sphere with a white center and a soft magenta glow ring.

Layout: A 2 by 2 grid of exactly four separate items, each one centered in its own quarter of the image, same visual size, with generous empty background between and around them so that nothing touches or overlaps.

Background: Plain solid bright green background (pure chroma-key green), completely flat and uniform, with no shadows, no floor, no gradient, no vignette, no scenery, and no green anywhere in the subject itself.

Do not include: text, letters, numbers, logos, watermarks, borders, frames, speech bubbles, blood, gore, wounds, scary or creepy faces, realistic weapons or real guns, knives, photo-realistic or 3D rendering, cast shadows on the background, extra items beyond the ones listed.

Square image (1:1).

Output file name: pickups_ammo.png (save and offer the image for download as pickups_ammo.png).
```

**If it goes wrong** (send as a follow-up in the same chat):
- "The three ammo boxes must look like the same box in orange, purple and yellow."
- "Keep the glow of the energy core thin so its outline stays crisp."
- "Make the background one pure, flat, solid bright green with no shadow or gradient."

---

## #13  Pickups: keys

**Save as:** `art/raw/pickups_keys.png`  
**Attach:** the approved hero image (art/raw/hero.png)  
**Image:** square, one image  
**Slicer expects:** magenta background, 4 item(s) in grid2x2

```text
Use the attached image only as a style reference: copy its outline thickness, color saturation and shading style, but do not copy its subject.

Cute anime cartoon video-game art for a kids' top-down shooter (ages 7 to 12). Chibi proportions with a big head, large glossy anime eyes and a small body. Bold, clean dark plum outlines of uniform medium thickness, smooth rounded shapes, bright saturated candy colors, soft two-tone cel shading with the light coming from the top-left and one small white highlight. Friendly and funny, never scary. Flat 2D vector-like illustration, no photo-realism, no painterly texture.

Subject: four small collectible puzzle items for a video game, drawn straight from above in chunky icon style, each with a dark plum outline. Top-left: a fuse, a cream-colored glass tube with metal caps on both ends and an orange filament. Top-right: a battery in bright green with a white plus sign shape and a silver tip. Bottom-left: a blue keycard with a yellow chip and a white stripe. Bottom-right: a datachip, a cyan square memory chip with gold contacts and a tiny dark screen.

Layout: A 2 by 2 grid of exactly four separate items, each one centered in its own quarter of the image, same visual size, with generous empty background between and around them so that nothing touches or overlaps.

Background: Plain solid bright magenta background (hot pink-purple, like #FF00FF), completely flat and uniform, with no shadows, no floor, no gradient, no vignette, no scenery, and no magenta or hot pink anywhere in the subject itself.

Do not include: text, letters, numbers, logos, watermarks, borders, frames, speech bubbles, blood, gore, wounds, scary or creepy faces, realistic weapons or real guns, knives, photo-realistic or 3D rendering, cast shadows on the background, extra items beyond the ones listed.

Square image (1:1).

Output file name: pickups_keys.png (save and offer the image for download as pickups_keys.png).
```

**If it goes wrong** (send as a follow-up in the same chat):
- "Make all four items the same size, drawn straight from above, with a dark plum outline."
- "Make the background one pure, flat, solid bright magenta with no shadow or gradient."

---

## #14  Pickups: blasters

**Save as:** `art/raw/pickups_blasters.png`  
**Attach:** the Projectiles image (art/raw/projectiles.png)  
**Image:** square, one image  
**Slicer expects:** green background, 4 item(s) in grid2x2

```text
Use the attached image only as a style reference: copy its outline thickness, color saturation and shading style, but do not copy its subject.

Cute anime cartoon video-game art for a kids' top-down shooter (ages 7 to 12). Chibi proportions with a big head, large glossy anime eyes and a small body. Bold, clean dark plum outlines of uniform medium thickness, smooth rounded shapes, bright saturated candy colors, soft two-tone cel shading with the light coming from the top-left and one small white highlight. Friendly and funny, never scary. Flat 2D vector-like illustration, no photo-realism, no painterly texture.

Subject: four small collectible items for a video game, drawn in chunky icon style from above, each with a dark plum outline. Top-left: a bolt, a shiny silver hex nut with a round dark hole in the middle. Top-right: a toy light blaster in orange, chunky and rounded, pointing right, with a glowing tip. Bottom-left: a toy light blaster in purple with a wide double barrel, pointing right. Bottom-right: a toy light blaster in yellow, long and slim with a drum on top, pointing right. All blasters are clearly toys.

Layout: A 2 by 2 grid of exactly four separate items, each one centered in its own quarter of the image, same visual size, with generous empty background between and around them so that nothing touches or overlaps.

Background: Plain solid bright green background (pure chroma-key green), completely flat and uniform, with no shadows, no floor, no gradient, no vignette, no scenery, and no green anywhere in the subject itself.

Do not include: text, letters, numbers, logos, watermarks, borders, frames, speech bubbles, blood, gore, wounds, scary or creepy faces, realistic weapons or real guns, knives, photo-realistic or 3D rendering, cast shadows on the background, extra items beyond the ones listed.

Square image (1:1).

Output file name: pickups_blasters.png (save and offer the image for download as pickups_blasters.png).
```

**If it goes wrong** (send as a follow-up in the same chat):
- "The blasters are too realistic. Make them chunky, rounded, colorful toys."
- "All three blasters point right and have the same size."
- "Make the background one pure, flat, solid bright green with no shadow or gradient."

---

## #15  Puzzle: button

**Save as:** `art/raw/puzzle_button.png`  
**Attach:** the approved hero image (art/raw/hero.png)  
**Image:** wide 16:9, one image  
**Slicer expects:** magenta background, 2 item(s) in row2

```text
Use the attached image only as a style reference: copy its outline thickness, color saturation and shading style, but do not copy its subject.

Cute anime cartoon video-game art for a kids' top-down shooter (ages 7 to 12). Chibi proportions with a big head, large glossy anime eyes and a small body. Bold, clean dark plum outlines of uniform medium thickness, smooth rounded shapes, bright saturated candy colors, soft two-tone cel shading with the light coming from the top-left and one small white highlight. Friendly and funny, never scary. Flat 2D vector-like illustration, no photo-realism, no painterly texture.

Subject: a floor button for a game puzzle, drawn straight from above. Left: the OFF state, a round red button standing out of a square steel plate with bolts in the corners. Right: the ON state, the same plate and button, but the button is pressed down and glows green.

Layout: Exactly two objects side by side in one row, same size, same position in their half, with generous empty background between them and around them. Left: the first state. Right: the second state.

Background: Plain solid bright magenta background (hot pink-purple, like #FF00FF), completely flat and uniform, with no shadows, no floor, no gradient, no vignette, no scenery, and no magenta or hot pink anywhere in the subject itself.

Do not include: text, letters, numbers, logos, watermarks, borders, frames, speech bubbles, blood, gore, wounds, scary or creepy faces, realistic weapons or real guns, knives, photo-realistic or 3D rendering, cast shadows on the background, extra items beyond the ones listed.

Wide 16:9 image.

Output file name: puzzle_button.png (save and offer the image for download as puzzle_button.png).
```

**If it goes wrong** (send as a follow-up in the same chat):
- "Make both objects identical in size, shape and position; only the state (colors and lights) changes."
- "Make the background one pure, flat, solid bright magenta with no shadow or gradient."

---

## #16  Puzzle: lever

**Save as:** `art/raw/puzzle_lever.png`  
**Attach:** the Button image (art/raw/puzzle_button.png)  
**Image:** wide 16:9, one image  
**Slicer expects:** magenta background, 2 item(s) in row2

```text
Use the attached image only as a style reference: copy its outline thickness, color saturation and shading style, but do not copy its subject.

Cute anime cartoon video-game art for a kids' top-down shooter (ages 7 to 12). Chibi proportions with a big head, large glossy anime eyes and a small body. Bold, clean dark plum outlines of uniform medium thickness, smooth rounded shapes, bright saturated candy colors, soft two-tone cel shading with the light coming from the top-left and one small white highlight. Friendly and funny, never scary. Flat 2D vector-like illustration, no photo-realism, no painterly texture.

Subject: a wall-style lever switch for a game puzzle, drawn from above. Left: the OFF state, a steel base plate with a lever handle tilted to the left, ending in a red knob. Right: the ON state, the same base plate with the handle tilted to the right, ending in a green glowing knob.

Layout: Exactly two objects side by side in one row, same size, same position in their half, with generous empty background between them and around them. Left: the first state. Right: the second state.

Background: Plain solid bright magenta background (hot pink-purple, like #FF00FF), completely flat and uniform, with no shadows, no floor, no gradient, no vignette, no scenery, and no magenta or hot pink anywhere in the subject itself.

Do not include: text, letters, numbers, logos, watermarks, borders, frames, speech bubbles, blood, gore, wounds, scary or creepy faces, realistic weapons or real guns, knives, photo-realistic or 3D rendering, cast shadows on the background, extra items beyond the ones listed.

Wide 16:9 image.

Output file name: puzzle_lever.png (save and offer the image for download as puzzle_lever.png).
```

**If it goes wrong** (send as a follow-up in the same chat):
- "Make both objects identical in size, shape and position; only the state (colors and lights) changes."
- "Make the background one pure, flat, solid bright magenta with no shadow or gradient."

---

## #17  Puzzle: pressureplate

**Save as:** `art/raw/puzzle_pressureplate.png`  
**Attach:** the Button image (art/raw/puzzle_button.png)  
**Image:** wide 16:9, one image  
**Slicer expects:** magenta background, 2 item(s) in row2

```text
Use the attached image only as a style reference: copy its outline thickness, color saturation and shading style, but do not copy its subject.

Cute anime cartoon video-game art for a kids' top-down shooter (ages 7 to 12). Chibi proportions with a big head, large glossy anime eyes and a small body. Bold, clean dark plum outlines of uniform medium thickness, smooth rounded shapes, bright saturated candy colors, soft two-tone cel shading with the light coming from the top-left and one small white highlight. Friendly and funny, never scary. Flat 2D vector-like illustration, no photo-realism, no painterly texture.

Subject: a floor pressure plate for a game puzzle, drawn straight from above. Left: the OFF state, a square steel frame with a raised yellow plate. Right: the ON state, the same frame with the plate pressed down and glowing green.

Layout: Exactly two objects side by side in one row, same size, same position in their half, with generous empty background between them and around them. Left: the first state. Right: the second state.

Background: Plain solid bright magenta background (hot pink-purple, like #FF00FF), completely flat and uniform, with no shadows, no floor, no gradient, no vignette, no scenery, and no magenta or hot pink anywhere in the subject itself.

Do not include: text, letters, numbers, logos, watermarks, borders, frames, speech bubbles, blood, gore, wounds, scary or creepy faces, realistic weapons or real guns, knives, photo-realistic or 3D rendering, cast shadows on the background, extra items beyond the ones listed.

Wide 16:9 image.

Output file name: puzzle_pressureplate.png (save and offer the image for download as puzzle_pressureplate.png).
```

**If it goes wrong** (send as a follow-up in the same chat):
- "Make both objects identical in size, shape and position; only the state (colors and lights) changes."
- "Make the background one pure, flat, solid bright magenta with no shadow or gradient."

---

## #18  Puzzle: machine

**Save as:** `art/raw/puzzle_machine.png`  
**Attach:** the Button image (art/raw/puzzle_button.png)  
**Image:** wide 16:9, one image  
**Slicer expects:** magenta background, 2 item(s) in row2

```text
Use the attached image only as a style reference: copy its outline thickness, color saturation and shading style, but do not copy its subject.

Cute anime cartoon video-game art for a kids' top-down shooter (ages 7 to 12). Chibi proportions with a big head, large glossy anime eyes and a small body. Bold, clean dark plum outlines of uniform medium thickness, smooth rounded shapes, bright saturated candy colors, soft two-tone cel shading with the light coming from the top-left and one small white highlight. Friendly and funny, never scary. Flat 2D vector-like illustration, no photo-realism, no painterly texture.

Subject: a large friendly puzzle machine (a control console with a dark screen, a socket and three round indicator lights), drawn from above in a three-quarter view, in violet-gray metal with red and orange accents and no pink. Left: the OFF state, dark screen and red lights. Right: the ON state, the same machine with a glowing cyan screen and green lights.

Layout: Exactly two objects side by side in one row, same size, same position in their half, with generous empty background between them and around them. Left: the first state. Right: the second state.

Background: Plain solid bright magenta background (hot pink-purple, like #FF00FF), completely flat and uniform, with no shadows, no floor, no gradient, no vignette, no scenery, and no magenta or hot pink anywhere in the subject itself.

Do not include: text, letters, numbers, logos, watermarks, borders, frames, speech bubbles, blood, gore, wounds, scary or creepy faces, realistic weapons or real guns, knives, photo-realistic or 3D rendering, cast shadows on the background, extra items beyond the ones listed.

Wide 16:9 image.

Output file name: puzzle_machine.png (save and offer the image for download as puzzle_machine.png).
```

**If it goes wrong** (send as a follow-up in the same chat):
- "Make both objects identical in size, shape and position; only the state (colors and lights) changes."
- "Make the background one pure, flat, solid bright magenta with no shadow or gradient."

---

## #19  Puzzle: door

**Save as:** `art/raw/puzzle_door.png`  
**Attach:** the Button image (art/raw/puzzle_button.png)  
**Image:** wide 16:9, one image  
**Slicer expects:** magenta background, 2 item(s) in row2

```text
Use the attached image only as a style reference: copy its outline thickness, color saturation and shading style, but do not copy its subject.

Cute anime cartoon video-game art for a kids' top-down shooter (ages 7 to 12). Chibi proportions with a big head, large glossy anime eyes and a small body. Bold, clean dark plum outlines of uniform medium thickness, smooth rounded shapes, bright saturated candy colors, soft two-tone cel shading with the light coming from the top-left and one small white highlight. Friendly and funny, never scary. Flat 2D vector-like illustration, no photo-realism, no painterly texture.

Subject: a sliding door for a game puzzle, drawn straight from above inside a dark steel frame. Left: the CLOSED state, two silver door panels meeting in the middle with a red light. Right: the OPEN state, the same frame and panels, but the panels slid apart into the frame, showing a dark opening, with a green light.

Layout: Exactly two objects side by side in one row, same size, same position in their half, with generous empty background between them and around them. Left: the first state. Right: the second state.

Background: Plain solid bright magenta background (hot pink-purple, like #FF00FF), completely flat and uniform, with no shadows, no floor, no gradient, no vignette, no scenery, and no magenta or hot pink anywhere in the subject itself.

Do not include: text, letters, numbers, logos, watermarks, borders, frames, speech bubbles, blood, gore, wounds, scary or creepy faces, realistic weapons or real guns, knives, photo-realistic or 3D rendering, cast shadows on the background, extra items beyond the ones listed.

Wide 16:9 image.

Output file name: puzzle_door.png (save and offer the image for download as puzzle_door.png).
```

**If it goes wrong** (send as a follow-up in the same chat):
- "Make both objects identical in size, shape and position; only the state (colors and lights) changes."
- "Make the background one pure, flat, solid bright magenta with no shadow or gradient."

---

## #20  Puzzle: crate

**Save as:** `art/raw/puzzle_crate.png`  
**Attach:** the Button image (art/raw/puzzle_button.png)  
**Image:** wide 16:9, one image  
**Slicer expects:** magenta background, 2 item(s) in row2

```text
Use the attached image only as a style reference: copy its outline thickness, color saturation and shading style, but do not copy its subject.

Cute anime cartoon video-game art for a kids' top-down shooter (ages 7 to 12). Chibi proportions with a big head, large glossy anime eyes and a small body. Bold, clean dark plum outlines of uniform medium thickness, smooth rounded shapes, bright saturated candy colors, soft two-tone cel shading with the light coming from the top-left and one small white highlight. Friendly and funny, never scary. Flat 2D vector-like illustration, no photo-realism, no painterly texture.

Subject: a supply crate for a game, drawn straight from above. Left: the WHOLE crate, a square wooden box with a lighter lid, cross-shaped metal straps and rounded corners. Right: the BROKEN crate, the same crate smashed into four chunky wooden pieces lying close together, nothing coming out of it.

Layout: Exactly two objects side by side in one row, same size, same position in their half, with generous empty background between them and around them. Left: the first state. Right: the second state.

Background: Plain solid bright magenta background (hot pink-purple, like #FF00FF), completely flat and uniform, with no shadows, no floor, no gradient, no vignette, no scenery, and no magenta or hot pink anywhere in the subject itself.

Do not include: text, letters, numbers, logos, watermarks, borders, frames, speech bubbles, blood, gore, wounds, scary or creepy faces, realistic weapons or real guns, knives, photo-realistic or 3D rendering, cast shadows on the background, extra items beyond the ones listed.

Wide 16:9 image.

Output file name: puzzle_crate.png (save and offer the image for download as puzzle_crate.png).
```

**If it goes wrong** (send as a follow-up in the same chat):
- "Make the broken crate four clean cartoon wood pieces, with no splinters flying and no dust."
- "Make the background one pure, flat, solid bright magenta with no shadow or gradient."

---

## #21  Puzzle: checkpoint

**Save as:** `art/raw/puzzle_checkpoint.png`  
**Attach:** the Button image (art/raw/puzzle_button.png)  
**Image:** wide 16:9, one image  
**Slicer expects:** magenta background, 2 item(s) in row2

```text
Use the attached image only as a style reference: copy its outline thickness, color saturation and shading style, but do not copy its subject.

Cute anime cartoon video-game art for a kids' top-down shooter (ages 7 to 12). Chibi proportions with a big head, large glossy anime eyes and a small body. Bold, clean dark plum outlines of uniform medium thickness, smooth rounded shapes, bright saturated candy colors, soft two-tone cel shading with the light coming from the top-left and one small white highlight. Friendly and funny, never scary. Flat 2D vector-like illustration, no photo-realism, no painterly texture.

Subject: a checkpoint pad for a game, drawn straight from above. Left: the OFF state, a round gray-blue metal pad with a dark ring and a dim white center dot. Right: the ON state, the same pad glowing green with a bright white center dot and a soft light ring.

Layout: Exactly two objects side by side in one row, same size, same position in their half, with generous empty background between them and around them. Left: the first state. Right: the second state.

Background: Plain solid bright magenta background (hot pink-purple, like #FF00FF), completely flat and uniform, with no shadows, no floor, no gradient, no vignette, no scenery, and no magenta or hot pink anywhere in the subject itself.

Do not include: text, letters, numbers, logos, watermarks, borders, frames, speech bubbles, blood, gore, wounds, scary or creepy faces, realistic weapons or real guns, knives, photo-realistic or 3D rendering, cast shadows on the background, extra items beyond the ones listed.

Wide 16:9 image.

Output file name: puzzle_checkpoint.png (save and offer the image for download as puzzle_checkpoint.png).
```

**If it goes wrong** (send as a follow-up in the same chat):
- "Make both objects identical in size, shape and position; only the state (colors and lights) changes."
- "Make the background one pure, flat, solid bright magenta with no shadow or gradient."

---

## #22  Puzzle: exitpad

**Save as:** `art/raw/puzzle_exitpad.png`  
**Attach:** the Checkpoint image (art/raw/puzzle_checkpoint.png)  
**Image:** wide 16:9, one image  
**Slicer expects:** magenta background, 2 item(s) in row2

```text
Use the attached image only as a style reference: copy its outline thickness, color saturation and shading style, but do not copy its subject.

Cute anime cartoon video-game art for a kids' top-down shooter (ages 7 to 12). Chibi proportions with a big head, large glossy anime eyes and a small body. Bold, clean dark plum outlines of uniform medium thickness, smooth rounded shapes, bright saturated candy colors, soft two-tone cel shading with the light coming from the top-left and one small white highlight. Friendly and funny, never scary. Flat 2D vector-like illustration, no photo-realism, no painterly texture.

Subject: a level exit pad for a game, drawn straight from above. Left: the OFF state, a round metal pad with a dim red glow and a white arrow shape pointing right in the middle. Right: the ON state, the same pad glowing bright green with the same white arrow and a soft green light ring. The arrow is a plain shape, not text.

Layout: Exactly two objects side by side in one row, same size, same position in their half, with generous empty background between them and around them. Left: the first state. Right: the second state.

Background: Plain solid bright magenta background (hot pink-purple, like #FF00FF), completely flat and uniform, with no shadows, no floor, no gradient, no vignette, no scenery, and no magenta or hot pink anywhere in the subject itself.

Do not include: text, letters, numbers, logos, watermarks, borders, frames, speech bubbles, blood, gore, wounds, scary or creepy faces, realistic weapons or real guns, knives, photo-realistic or 3D rendering, cast shadows on the background, extra items beyond the ones listed.

Wide 16:9 image.

Output file name: puzzle_exitpad.png (save and offer the image for download as puzzle_exitpad.png).
```

**If it goes wrong** (send as a follow-up in the same chat):
- "Make both objects identical in size, shape and position; only the state (colors and lights) changes."
- "Make the background one pure, flat, solid bright magenta with no shadow or gradient."

---

## #23  L1: City Rooftop Lab floor tile

**Save as:** `art/raw/tile_l1_floor.png`  
**Attach:** the approved hero image (art/raw/hero.png)  
**Image:** square, one image  
**Slicer expects:** full-bleed texture, 1 item(s)

```text
Use the attached image only as a style reference: copy its outline thickness, color saturation and shading style, but do not copy its subject.

Cute anime cartoon video-game art for a kids' top-down shooter (ages 7 to 12). Flat 2D vector-like illustration with bold clean dark plum outlines only on inner details, bright but soft candy colors, soft two-tone cel shading with the light from the top-left. Friendly, never scary.

Subject: a single seamless tileable top-down texture for Level 1 City Rooftop Lab: a light blue-gray metal floor of a city rooftop laboratory: large square panels in two slightly different pale blue-gray tones (#B8C4D6 and #A6B3C8), thin darker seams, a few small rivets and one or two tiny orange warning scuffs. Very low contrast and calm, so characters stand out.

Layout: the texture fills the entire image edge to edge, with no border, no margin and no background, so it can repeat without visible seams (the pattern continues across all four edges). Straight top-down view, no perspective.

Do not include: any characters, objects, props, items, shadows of objects, text, letters, numbers, logos, watermarks, borders, frames, vignettes, perspective, a horizon, strong light gradients, and photo-realistic rendering.

Square image (1:1).

Output file name: tile_l1_floor.png (save and offer the image for download as tile_l1_floor.png).
```

**If it goes wrong** (send as a follow-up in the same chat):
- "Make the texture fill the whole image edge to edge, with no frame, no border and no objects on it."
- "Make it flatter and lower in contrast, with a repeating pattern that looks the same on all four edges."

---

## #24  L1: City Rooftop Lab wall tile

**Save as:** `art/raw/tile_l1_wall.png`  
**Attach:** the matching floor tile (art/raw/tile_l1_floor.png)  
**Image:** square, one image  
**Slicer expects:** full-bleed texture, 1 item(s)

```text
Use the attached image only as a style reference: copy its outline thickness, color saturation and shading style, but do not copy its subject.

Cute anime cartoon video-game art for a kids' top-down shooter (ages 7 to 12). Flat 2D vector-like illustration with bold clean dark plum outlines only on inner details, bright but soft candy colors, soft two-tone cel shading with the light from the top-left. Friendly, never scary.

Subject: a single seamless tileable top-down texture for Level 1 City Rooftop Lab: the top of a wall block of a city rooftop laboratory: steel-blue panels (#5B6B8C) with a lighter bevelled top edge (#7E90B5), rivets, and a thin orange stripe. Same simple style as a floor tile, no perspective.

Layout: the texture fills the entire image edge to edge, with no border, no margin and no background, so it can repeat without visible seams (the pattern continues across all four edges). Straight top-down view, no perspective.

Do not include: any characters, objects, props, items, shadows of objects, text, letters, numbers, logos, watermarks, borders, frames, vignettes, perspective, a horizon, strong light gradients, and photo-realistic rendering.

Square image (1:1).

Output file name: tile_l1_wall.png (save and offer the image for download as tile_l1_wall.png).
```

**If it goes wrong** (send as a follow-up in the same chat):
- "Make the texture fill the whole image edge to edge, with no frame, no border and no objects on it."
- "Make the lighter top edge thinner and the pattern repeat evenly along the sides."

---

## #25  L2: Robot Factory floor tile

**Save as:** `art/raw/tile_l2_floor.png`  
**Attach:** the previous level's floor tile (art/raw/tile_l1_floor.png)  
**Image:** square, one image  
**Slicer expects:** full-bleed texture, 1 item(s)

```text
Use the attached image only as a style reference: copy its outline thickness, color saturation and shading style, but do not copy its subject.

Cute anime cartoon video-game art for a kids' top-down shooter (ages 7 to 12). Flat 2D vector-like illustration with bold clean dark plum outlines only on inner details, bright but soft candy colors, soft two-tone cel shading with the light from the top-left. Friendly, never scary.

Subject: a single seamless tileable top-down texture for Level 2 Robot Factory: a gray steel factory floor (#8C8F99 and #7A7D88) with a subtle diamond-plate pattern, and a few faded hazard-yellow stripe fragments. Low contrast and calm.

Layout: the texture fills the entire image edge to edge, with no border, no margin and no background, so it can repeat without visible seams (the pattern continues across all four edges). Straight top-down view, no perspective.

Do not include: any characters, objects, props, items, shadows of objects, text, letters, numbers, logos, watermarks, borders, frames, vignettes, perspective, a horizon, strong light gradients, and photo-realistic rendering.

Square image (1:1).

Output file name: tile_l2_floor.png (save and offer the image for download as tile_l2_floor.png).
```

**If it goes wrong** (send as a follow-up in the same chat):
- "Make the texture fill the whole image edge to edge, with no frame, no border and no objects on it."
- "Make it flatter and lower in contrast, with a repeating pattern that looks the same on all four edges."

---

## #26  L2: Robot Factory wall tile

**Save as:** `art/raw/tile_l2_wall.png`  
**Attach:** the matching floor tile (art/raw/tile_l2_floor.png)  
**Image:** square, one image  
**Slicer expects:** full-bleed texture, 1 item(s)

```text
Use the attached image only as a style reference: copy its outline thickness, color saturation and shading style, but do not copy its subject.

Cute anime cartoon video-game art for a kids' top-down shooter (ages 7 to 12). Flat 2D vector-like illustration with bold clean dark plum outlines only on inner details, bright but soft candy colors, soft two-tone cel shading with the light from the top-left. Friendly, never scary.

Subject: a single seamless tileable top-down texture for Level 2 Robot Factory: the top of a wall block in a robot factory: dark steel panels (#4A4E5C) with a lighter top edge (#6B7080), big bolts, and an orange pipe (#FF7A1A) running along the middle.

Layout: the texture fills the entire image edge to edge, with no border, no margin and no background, so it can repeat without visible seams (the pattern continues across all four edges). Straight top-down view, no perspective.

Do not include: any characters, objects, props, items, shadows of objects, text, letters, numbers, logos, watermarks, borders, frames, vignettes, perspective, a horizon, strong light gradients, and photo-realistic rendering.

Square image (1:1).

Output file name: tile_l2_wall.png (save and offer the image for download as tile_l2_wall.png).
```

**If it goes wrong** (send as a follow-up in the same chat):
- "Make the texture fill the whole image edge to edge, with no frame, no border and no objects on it."
- "Make the lighter top edge thinner and the pattern repeat evenly along the sides."

---

## #27  L3: Gene Lab Greenhouse floor tile

**Save as:** `art/raw/tile_l3_floor.png`  
**Attach:** the previous level's floor tile (art/raw/tile_l2_floor.png)  
**Image:** square, one image  
**Slicer expects:** full-bleed texture, 1 item(s)

```text
Use the attached image only as a style reference: copy its outline thickness, color saturation and shading style, but do not copy its subject.

Cute anime cartoon video-game art for a kids' top-down shooter (ages 7 to 12). Flat 2D vector-like illustration with bold clean dark plum outlines only on inner details, bright but soft candy colors, soft two-tone cel shading with the light from the top-left. Friendly, never scary.

Subject: a single seamless tileable top-down texture for Level 3 Gene Lab Greenhouse: a pale green greenhouse floor (#BFE3A0 and #A8D488): square stone tiles with tiny moss and clover leaves growing in the seams and one or two small pink flowers. Soft and low contrast.

Layout: the texture fills the entire image edge to edge, with no border, no margin and no background, so it can repeat without visible seams (the pattern continues across all four edges). Straight top-down view, no perspective.

Do not include: any characters, objects, props, items, shadows of objects, text, letters, numbers, logos, watermarks, borders, frames, vignettes, perspective, a horizon, strong light gradients, and photo-realistic rendering.

Square image (1:1).

Output file name: tile_l3_floor.png (save and offer the image for download as tile_l3_floor.png).
```

**If it goes wrong** (send as a follow-up in the same chat):
- "Make the texture fill the whole image edge to edge, with no frame, no border and no objects on it."
- "Make it flatter and lower in contrast, with a repeating pattern that looks the same on all four edges."

---

## #28  L3: Gene Lab Greenhouse wall tile

**Save as:** `art/raw/tile_l3_wall.png`  
**Attach:** the matching floor tile (art/raw/tile_l3_floor.png)  
**Image:** square, one image  
**Slicer expects:** full-bleed texture, 1 item(s)

```text
Use the attached image only as a style reference: copy its outline thickness, color saturation and shading style, but do not copy its subject.

Cute anime cartoon video-game art for a kids' top-down shooter (ages 7 to 12). Flat 2D vector-like illustration with bold clean dark plum outlines only on inner details, bright but soft candy colors, soft two-tone cel shading with the light from the top-left. Friendly, never scary.

Subject: a single seamless tileable top-down texture for Level 3 Gene Lab Greenhouse: the top of a wall block in a greenhouse: green leafy hedge panels (#3C8F5A, lighter top #5FBF7A) set in pale glass-and-metal frames (#CFF5EA), with a few leaves.

Layout: the texture fills the entire image edge to edge, with no border, no margin and no background, so it can repeat without visible seams (the pattern continues across all four edges). Straight top-down view, no perspective.

Do not include: any characters, objects, props, items, shadows of objects, text, letters, numbers, logos, watermarks, borders, frames, vignettes, perspective, a horizon, strong light gradients, and photo-realistic rendering.

Square image (1:1).

Output file name: tile_l3_wall.png (save and offer the image for download as tile_l3_wall.png).
```

**If it goes wrong** (send as a follow-up in the same chat):
- "Make the texture fill the whole image edge to edge, with no frame, no border and no objects on it."
- "Make the lighter top edge thinner and the pattern repeat evenly along the sides."

---

## #29  L4: Server Fortress floor tile

**Save as:** `art/raw/tile_l4_floor.png`  
**Attach:** the previous level's floor tile (art/raw/tile_l3_floor.png)  
**Image:** square, one image  
**Slicer expects:** full-bleed texture, 1 item(s)

```text
Use the attached image only as a style reference: copy its outline thickness, color saturation and shading style, but do not copy its subject.

Cute anime cartoon video-game art for a kids' top-down shooter (ages 7 to 12). Flat 2D vector-like illustration with bold clean dark plum outlines only on inner details, bright but soft candy colors, soft two-tone cel shading with the light from the top-left. Friendly, never scary.

Subject: a single seamless tileable top-down texture for Level 4 Server Fortress: a dark navy server-room floor (#2B3A67 and #243158) made of square panels with faint cyan circuit traces and a few tiny violet LED dots. Dark but not black, low contrast.

Layout: the texture fills the entire image edge to edge, with no border, no margin and no background, so it can repeat without visible seams (the pattern continues across all four edges). Straight top-down view, no perspective.

Do not include: any characters, objects, props, items, shadows of objects, text, letters, numbers, logos, watermarks, borders, frames, vignettes, perspective, a horizon, strong light gradients, and photo-realistic rendering.

Square image (1:1).

Output file name: tile_l4_floor.png (save and offer the image for download as tile_l4_floor.png).
```

**If it goes wrong** (send as a follow-up in the same chat):
- "Make the texture fill the whole image edge to edge, with no frame, no border and no objects on it."
- "Make it flatter and lower in contrast, with a repeating pattern that looks the same on all four edges."

---

## #30  L4: Server Fortress wall tile

**Save as:** `art/raw/tile_l4_wall.png`  
**Attach:** the matching floor tile (art/raw/tile_l4_floor.png)  
**Image:** square, one image  
**Slicer expects:** full-bleed texture, 1 item(s)

```text
Use the attached image only as a style reference: copy its outline thickness, color saturation and shading style, but do not copy its subject.

Cute anime cartoon video-game art for a kids' top-down shooter (ages 7 to 12). Flat 2D vector-like illustration with bold clean dark plum outlines only on inner details, bright but soft candy colors, soft two-tone cel shading with the light from the top-left. Friendly, never scary.

Subject: a single seamless tileable top-down texture for Level 4 Server Fortress: the top of a wall block in a server fortress: very dark blue server-rack panels (#151C3A) with a lighter top edge (#3A4CA0) and small glowing neon cyan lights in a row.

Layout: the texture fills the entire image edge to edge, with no border, no margin and no background, so it can repeat without visible seams (the pattern continues across all four edges). Straight top-down view, no perspective.

Do not include: any characters, objects, props, items, shadows of objects, text, letters, numbers, logos, watermarks, borders, frames, vignettes, perspective, a horizon, strong light gradients, and photo-realistic rendering.

Square image (1:1).

Output file name: tile_l4_wall.png (save and offer the image for download as tile_l4_wall.png).
```

**If it goes wrong** (send as a follow-up in the same chat):
- "Make the texture fill the whole image edge to edge, with no frame, no border and no objects on it."
- "Make the lighter top edge thinner and the pattern repeat evenly along the sides."

---

## #31  L5: OVERMIND Core floor tile

**Save as:** `art/raw/tile_l5_floor.png`  
**Attach:** the previous level's floor tile (art/raw/tile_l4_floor.png)  
**Image:** square, one image  
**Slicer expects:** full-bleed texture, 1 item(s)

```text
Use the attached image only as a style reference: copy its outline thickness, color saturation and shading style, but do not copy its subject.

Cute anime cartoon video-game art for a kids' top-down shooter (ages 7 to 12). Flat 2D vector-like illustration with bold clean dark plum outlines only on inner details, bright but soft candy colors, soft two-tone cel shading with the light from the top-left. Friendly, never scary.

Subject: a single seamless tileable top-down texture for Level 5 OVERMIND Core: a dark purple glossy floor (#3A1840 and #2F1236) with faint glowing magenta circuit lines and small hexagon patterns. Dark but not black, low contrast.

Layout: the texture fills the entire image edge to edge, with no border, no margin and no background, so it can repeat without visible seams (the pattern continues across all four edges). Straight top-down view, no perspective.

Do not include: any characters, objects, props, items, shadows of objects, text, letters, numbers, logos, watermarks, borders, frames, vignettes, perspective, a horizon, strong light gradients, and photo-realistic rendering.

Square image (1:1).

Output file name: tile_l5_floor.png (save and offer the image for download as tile_l5_floor.png).
```

**If it goes wrong** (send as a follow-up in the same chat):
- "Make the texture fill the whole image edge to edge, with no frame, no border and no objects on it."
- "Make it flatter and lower in contrast, with a repeating pattern that looks the same on all four edges."

---

## #32  L5: OVERMIND Core wall tile

**Save as:** `art/raw/tile_l5_wall.png`  
**Attach:** the matching floor tile (art/raw/tile_l5_floor.png)  
**Image:** square, one image  
**Slicer expects:** full-bleed texture, 1 item(s)

```text
Use the attached image only as a style reference: copy its outline thickness, color saturation and shading style, but do not copy its subject.

Cute anime cartoon video-game art for a kids' top-down shooter (ages 7 to 12). Flat 2D vector-like illustration with bold clean dark plum outlines only on inner details, bright but soft candy colors, soft two-tone cel shading with the light from the top-left. Friendly, never scary.

Subject: a single seamless tileable top-down texture for Level 5 OVERMIND Core: the top of a wall block in the core of the evil AI: dark violet armored panels (#1B0A24) with a lighter top edge (#6B1E5E) and glowing magenta-pink seams (#FF2E7E).

Layout: the texture fills the entire image edge to edge, with no border, no margin and no background, so it can repeat without visible seams (the pattern continues across all four edges). Straight top-down view, no perspective.

Do not include: any characters, objects, props, items, shadows of objects, text, letters, numbers, logos, watermarks, borders, frames, vignettes, perspective, a horizon, strong light gradients, and photo-realistic rendering.

Square image (1:1).

Output file name: tile_l5_wall.png (save and offer the image for download as tile_l5_wall.png).
```

**If it goes wrong** (send as a follow-up in the same chat):
- "Make the texture fill the whole image edge to edge, with no frame, no border and no objects on it."
- "Make the lighter top edge thinner and the pattern repeat evenly along the sides."

---

## #33  UI icons A (round buttons)

**Save as:** `art/raw/ui_icons_a.png`  
**Attach:** the approved hero image (art/raw/hero.png)  
**Image:** wide 16:9, one image  
**Slicer expects:** green background, 6 item(s) in grid3x2

```text
Use the attached image only as a style reference: copy its outline thickness, color saturation and shading style, but do not copy its subject.

Cute anime cartoon game UI icons for a kids' shooter (ages 7 to 12). Round glossy buttons with a thick dark plum outline, a dark indigo (#2E2A55) rim and a bright simple pictogram inside, bright saturated candy colors, soft two-tone cel shading with light from the top-left, one small white highlight. Friendly and clear, flat 2D vector-like.

Subject: six round game buttons, each a glossy circle with a bright pictogram and no text. Row 1 from left to right: FIRE, an orange button with a white star-burst; RELOAD, a blue button with two white circular arrows; INTERACT, a green-teal button with a white tapping hand. Row 2 from left to right: SWAP, a purple button with two white arrows swapping places; PAUSE, a yellow button with two white vertical bars; INVENTORY, a blue-violet button with a white backpack.

Layout: A grid of 3 columns by 2 rows: exactly six separate round button icons, each centered in its own cell, same size, with generous empty background between them so that nothing touches or overlaps.

Background: Plain solid bright green background (pure chroma-key green), completely flat and uniform, with no shadows, no floor, no gradient, no vignette, no scenery, and no green anywhere in the subject itself.

Do not include: text, letters, numbers, logos, watermarks, borders, frames, speech bubbles, blood, gore, wounds, scary or creepy faces, realistic weapons or real guns, knives, photo-realistic or 3D rendering, cast shadows on the background, extra items beyond the ones listed.

Wide 16:9 image.

Output file name: ui_icons_a.png (save and offer the image for download as ui_icons_a.png).
```

**If it goes wrong** (send as a follow-up in the same chat):
- "Make all six buttons the same size circles with a dark plum outline and no text."
- "Use only simple white pictograms inside; remove every letter."
- "Make the background one pure, flat, solid bright green with no shadow or gradient."

---

## #34  UI icons B (HUD icons)

**Save as:** `art/raw/ui_icons_b.png`  
**Attach:** the Round buttons image (art/raw/ui_icons_a.png)  
**Image:** wide 16:9, one image  
**Slicer expects:** green background, 7 item(s) in grid4x2

```text
Use the attached image only as a style reference: copy its outline thickness, color saturation and shading style, but do not copy its subject.

Cute anime cartoon game UI icons for a kids' shooter (ages 7 to 12). Round glossy buttons with a thick dark plum outline, a dark indigo (#2E2A55) rim and a bright simple pictogram inside, bright saturated candy colors, soft two-tone cel shading with light from the top-left, one small white highlight. Friendly and clear, flat 2D vector-like.

Subject: seven small HUD icons, each a simple chunky pictogram with a dark plum outline on its own (no circle behind them). Row 1 from left to right: a glossy red heart; a small toy ammo capsule in gold; a yellow star; a chunky orange toy blaster pointing right. Row 2 from left to right: a chunky purple toy blaster with a wide double barrel pointing right; a long slim yellow toy blaster pointing right; the round cyan face of Pixel, the friendly drone, with a dark navy screen face and two glowing cyan eyes.

Layout: A grid of 4 columns by 2 rows with 7 separate small icons filled in reading order (top row first, left to right); the eighth cell stays completely empty. Each icon is centered in its cell, same size, with generous empty background between them so that nothing touches or overlaps.

Background: Plain solid bright green background (pure chroma-key green), completely flat and uniform, with no shadows, no floor, no gradient, no vignette, no scenery, and no green anywhere in the subject itself.

Do not include: text, letters, numbers, logos, watermarks, borders, frames, speech bubbles, blood, gore, wounds, scary or creepy faces, realistic weapons or real guns, knives, photo-realistic or 3D rendering, cast shadows on the background, extra items beyond the ones listed.

Wide 16:9 image.

Output file name: ui_icons_b.png (save and offer the image for download as ui_icons_b.png).
```

**If it goes wrong** (send as a follow-up in the same chat):
- "Place exactly seven icons in two rows (four on top, three below), the last cell empty, with space between them."
- "Make the background one pure, flat, solid bright green with no shadow or gradient."

---

## #35  App icon

**Save as:** `art/raw/appicon.png`  
**Attach:** the approved hero image (art/raw/hero.png) and the Pixel image (art/raw/pixel.png)  
**Image:** square, one image  
**Slicer expects:** full-bleed icon, 1 item(s)

```text
Use the attached image only as a style reference: copy its outline thickness, color saturation and shading style, but do not copy its subject.

Cute anime cartoon video-game art for a kids' top-down shooter (ages 7 to 12). Chibi proportions with a big head, large glossy anime eyes and a small body. Bold, clean dark plum outlines of uniform medium thickness, smooth rounded shapes, bright saturated candy colors, soft two-tone cel shading with the light coming from the top-left and one small white highlight. Friendly and funny, never scary. Flat 2D vector-like illustration, no photo-realism, no painterly texture.

Subject: an app icon for a kids' shooter game. The hero (as in the first attached image) stands in the front-center, big and friendly, aiming the toy blaster up and to the right with a happy open-mouth grin, and Pixel the cyan drone (as in the second attached image) floats at the hero's shoulder. Behind them a bright sky-blue background with a golden-yellow sunburst, a few white stars, and a tiny cute red robot eye peeking from a bottom corner. Cheerful and eye-catching, very readable when small.

Layout: the artwork fills the whole square edge to edge, the characters well inside the middle 70 percent, no rounded corners, no border, no frame.

Do not include: text, letters, numbers, logos, watermarks, borders, frames, blood, gore, scary faces, realistic weapons or real guns, and photo-realistic rendering.

Square image (1:1).

Output file name: appicon.png (save and offer the image for download as appicon.png).
```

**If it goes wrong** (send as a follow-up in the same chat):
- "Make the artwork fill the entire square with no border or rounded corners."
- "Make the hero and Pixel larger and more centered, with a simpler background."

---

## #36  Settings gear button

**Save as:** `art/raw/ui_icon_gear.png`  
**Attach:** the Round buttons image (art/raw/ui_icons_a.png)  
**Image:** square, one image  
**Slicer expects:** green background, 1 item(s)

```text
Use the attached image only as a style reference: copy its outline thickness, color saturation and shading style, but do not copy its subject.

Cute anime cartoon game UI icon for a kids' shooter (ages 7 to 12). A round glossy button with a thick dark plum outline, a dark indigo (#2E2A55) rim and a bright simple pictogram inside, bright saturated candy colors, soft two-tone cel shading with light from the top-left, one small white highlight. Friendly and clear, flat 2D vector-like.

Subject: one round SETTINGS button, a glossy teal-blue circle with a chunky white gear (cog with six rounded teeth) in the middle and a small round hole in the gear center. No text.

Layout: exactly one round button icon, centered, filling about 70 percent of the image, with empty background all around.

Background: Plain solid bright green background (pure chroma-key green), completely flat and uniform, with no shadows, no floor, no gradient, no vignette, no scenery, and no green anywhere in the subject itself.

Do not include: text, letters, numbers, logos, watermarks, borders, frames, speech bubbles, blood, gore, wounds, scary or creepy faces, realistic weapons or real guns, knives, photo-realistic or 3D rendering, cast shadows on the background, extra items beyond the one listed.

Square image (1:1).

Output file name: ui_icon_gear.png (save and offer the image for download as ui_icon_gear.png).
```

**If it goes wrong** (send as a follow-up in the same chat):
- "Make it one single round button with a white gear, no text, centered."
- "Make the background one pure, flat, solid bright green with no shadow or gradient."
