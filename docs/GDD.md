# Strike – Game Design Document (Season 1 MVP)

Owner: game-designer · Status: v1.2 (M2-1) · Audience: kids 7–12 · iPad landscape · offline · DE + EN

This file is the single source of truth for the design. Balance numbers live in
`Strike/Resources/Data/*.json`. If this doc and the JSON disagree, the JSON wins for numbers and
this doc wins for rules. Change log is at the bottom.

---

## 1. Pitch

The evil AI **OVERMIND** has taken over the world. It builds silly-evil robots and wobbly
gene-monsters to make everyone do boring chores forever. A young **hero** and the good drone AI
**Pixel** fly across 5 places, switch OVERMIND's machines off and finally beat its giant robot
**MEGA-MECH Unit Zero**.

Core loop (30 s): run → zap robots → grab loot → find switches.
Level loop (6–12 min): explore generated rooms → activate all required puzzle elements → exit door
opens → reach exit → stars screen.

Tone: bright anime-cartoon. Blasters shoot light, foam and bubbles. Enemies never "die": they
**power down** and poof into sparkles, bolts and loot. Villains are funny, never scary.

---

## 2. Units and conventions

| Term | Value |
|---|---|
| Distance | points (pt). 1 tile = **64 pt** (128 px @2x). iPad reference view ≈ 1194 × 834 pt |
| Speed | pt/s |
| Time | seconds (`…Sec` fields) |
| Angles | degrees (`…Deg` fields) |
| Rates | shots per second (`fireRate`) |
| Ids | lowercase snake_case, equal to asset names (see §17) |
| Text | every visible string is a key in `Localizable.xcstrings` (`nameKey`, `descKey`, …) |

Camera: follows the hero with 0.12 s smoothing (`hero.json → camera.smoothingSec`), scale 1.0,
so it shows about **18.7 × 13 tiles** (1194 / 64 × 834 / 64). Small look-ahead of 60 pt in aim
direction (`camera.lookAhead`). The camera is clamped to the room/map bounds. Room sizes
(§14.2) are in tiles and were re-checked for 64 pt in M2-1: a typical room (10–11 tiles) is about
one screen once the HUD bands are subtracted (≈ 18.7 × 11 usable tiles).

---

## 3. Controls spec (touch, twin-stick)

### 3.1 Layout (landscape)

Positions: `docs/ART_BIBLE.md` §7 wins (quick slots bottom centre). This doc owns the rules.
There is **no Fire button**: the right stick aims and auto-fires (`ui_btn_fire` stays unused).

```
+--------------------------------------------------------------+
| [HP bar]  [weapon + ammo "12 / 48"]   [minimap]    [II pause]|
|                                                              |
|                                                              |
|                                        [SWAP]                |
|                                   [RELOAD]  [INTERACT]       |
|   (move zone: left 45%)            (aim zone: right 45%)     |
|        ( L )         [Q1][Q2][Q3][Q4]         ( R )          |
+--------------------------------------------------------------+
  rough sketch only; exact positions in ART_BIBLE §7
```

### 3.2 Sticks

All values live in `hero.json → controls` (§16.6).

| Parameter | Left stick (move) | Right stick (aim + fire) |
|---|---|---|
| Zone | left 45 % of screen width, below the top 15 % HUD band | right 45 %, below HUD band, outside button hit boxes |
| Type | floating: base appears where the finger lands | floating |
| Travel radius | 70 pt (`stickRadius`) | 70 pt |
| Visual | base circle 140 pt, knob 64 pt, 70 % alpha, drawn in code | same |
| Dead zone | 0.15 of radius | 0.30 of radius (below = aim only, no fire) |
| Output | direction × magnitude (0…1). Speed = `moveSpeed × magnitude`, magnitude ≥ 0.85 counts as 1.0 | aim angle; magnitude ≥ 0.30 → **auto-fire** at the weapon's `fireRate` |
| Follow | if the finger drags > 1.4 × radius away, the base follows | same |
| Release | stick fades out in 0.15 s | stop firing; hero keeps last aim angle |

If no right-stick input: hero faces its movement direction and does not fire.
Left-handed option (Settings): mirror sticks and buttons.

### 3.3 Buttons

All touch targets ≥ 64 × 64 pt (kids' fingers), 12 pt gap.

| Button | Action | Notes |
|---|---|---|
| (no Fire button) | – | firing = right stick ≥ aim dead zone |
| RELOAD | reload current blaster | auto-reload also starts when the magazine hits 0 and fire is held |
| INTERACT | press button / pull lever / insert item into machine / pick up item when bag was full / open door | glows + icon changes when an interactable is within 64 pt; greyed out otherwise |
| SWAP | next owned blaster (starter → spread → rapid → starter) | long-press (0.4 s) opens a 3-slot weapon wheel |
| Q1–Q4 | use the item assigned to the quick slot | shows icon + stack count; empty = dashed outline |
| Tap on Pixel | ask Pixel for a hint (§11) | hit box 80 pt around Pixel |
| Pause | pause menu: resume, inventory, settings, quit to map | game time stops |

Interact also triggers automatically for pressure plates (stand on them). Pick-ups are automatic
when walking over them (pickup radius 40 pt; bolts are magnet-pulled within 96 pt).

### 3.4 Aim-assist (Settings: On by default, toggle)

1. Take all enemies inside the weapon `range` and inside a cone of **±12°** around the stick angle
   (`±18°` for `blaster_spread`), with clear line of sight.
2. Pick the one with the smallest angle difference (tie: nearest).
3. Final aim = stick angle rotated toward the target by `strength = 0.6` of the difference.
4. Never snaps through walls. Ignores powered-down enemies and shields (aims at the body).
5. Off = raw stick angle.

### 3.5 Feedback

- Light haptic on hit taken, medium on enemy power-down, success haptic on puzzle element on.
- Hit sparkle on enemy (particles), white flash 0.1 s (ART_BIBLE feel constant). No damage numbers (kids read stars, not numbers).

---

## 4. Player stats (`hero`)

Numbers live in `Strike/Resources/Data/hero.json` (§16.6).

| Stat | Value |
|---|---|
| Max HP | 100 |
| Move speed | 220 pt/s |
| Collision radius | 18 pt |
| Invulnerable after hit | 0.8 s (blinks) |
| Knockback taken | 80 pt over 0.12 s |
| Pickup radius | 40 pt (bolt magnet 96 pt) |
| Interact radius | 64 pt |
| Start loadout L1 | `blaster_starter`, 12 in mag, 48 reserve, 1 × `healpack`, 2 × `food_apple` |
| Low-HP warning | ≤ 25 HP (`rules.json → lowHp.threshold`): heart pulses, Pixel line (max once per `lowHp.lineCooldownSec` 60 s) |

Slow effects (spores): move speed × 0.7 for 2 s, do not stack, refresh duration.

---

## 5. Blasters

The hero always owns `blaster_starter`. `blaster_spread` is found in L2 (guaranteed pickup in the
zone-1 treasure room), `blaster_rapid` in L3. Owned blasters carry over between levels.

| id | Fires | Damage | Pellets | Spread / jitter | Fire rate | Proj. speed | Range | Magazine | Reserve max | Reload | Ammo |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `blaster_starter` "Light Blaster" | orange light bolt | 10 | 1 | 0° / 2° | 4.0 /s | 720 | 520 | 12 | 96 | 1.0 s | `ammo_starter` |
| `blaster_spread` "Bubble Blaster" | 5 purple bubbles in a fan | 7 each (35 max) | 5 | 40° / 0° | 1.4 /s | 560 | 330 | 6 | 36 | 1.6 s | `ammo_spread` |
| `blaster_rapid` "Foam Blaster" | yellow foam pellets | 5 | 1 | 0° / 7° | 10.0 /s | 820 | 470 | 40 | 200 | 1.8 s | `ammo_rapid` |

DPS (sustained, incl. reload): starter ≈ 30, spread ≈ 40 at close range, rapid ≈ 38.
Roles: starter = precise all-rounder, spread = close crowd and slimes, rapid = shields-from-the-side
and the boss.

### 5.1 Ammo rules

- One **magazine** per blaster and one **reserve** per ammo type. Shots use the magazine.
- Reload moves `min(magazineSize − mag, reserve)` from reserve to mag. Reload is cancelled by
  swapping (no ammo lost). Swap time 0.25 s.
- Ammo pickups add to the reserve directly (even for a blaster not owned yet). Overflow above
  `reserveMax` becomes ammo-pack items in the inventory (§7) if a slot is free, else stays on the
  floor.
- Using an ammo-pack item from the inventory/quick slot adds its amount to the reserve.
- **Safety net (starter only):** if `blaster_starter` mag + reserve = 0, the reserve recharges
  +1 every 0.5 s up to 12 (`hero.json → starterSafetyNet`). The hero can never be fully stuck:
  with fire held this gives 2 shots/s (a boltbot powers down in about 1.5 s); after release the
  magazine is full again in 6 s.
- **Ammo rescue drop:** while the equipped blaster's mag + reserve is below one magazine, every
  powered-down enemy (and opened crate) drops 1 extra pack of that blaster's ammo for sure
  (`loot.json → modifiers.ammo_rescue`, §10).
- Mag + reserve carry over between levels. Each level start tops starter ammo up to at least
  12 + 48.

Projectiles stop at walls, pass through powered-down enemies and pickups, and do not hit Pixel.

---

## 6. Items

Collected by walking over them. All text via `item.<id>.name` / `item.<id>.desc` keys.

| id | Category | Effect | Stack | In inventory | Notes |
|---|---|---|---|---|---|
| `healpack` | heal | +50 HP | 5 | yes | red-cross-free design: a green heart capsule |
| `food_apple` | food | +10 HP | 10 | yes | common drop |
| `food_cookie` | food | +15 HP | 10 | yes | |
| `food_onigiri` | food | +25 HP | 10 | yes | rarer |
| `ammo_starter` | ammo | +24 reserve `ammo_starter` | 5 packs | only as overflow | orange cell (matches starter) |
| `ammo_spread` | ammo | +12 reserve `ammo_spread` | 5 packs | only as overflow | purple bubble jar (matches spread) |
| `ammo_rapid` | ammo | +60 reserve `ammo_rapid` | 5 packs | only as overflow | yellow foam can (matches rapid) |
| `fuse` | puzzle | powers a `machine` with `requiresItem: fuse` | 3 | yes | |
| `battery` | puzzle | powers a `machine` with `requiresItem: battery` | 3 | yes | |
| `keycard` | puzzle | opens a keycard `machine` (card reader) | 1 | yes | |
| `energycore` | puzzle | powers core machines (L5 + boss) | 3 | yes | glowing, bobs |
| `bolt` | collectible | +10 score | – | no | poofs from enemies; magnet pickup. **new asset** |
| `datachip` | collectible | +250 score, 3 hidden per level, unlocks a "Pixel fact" | – | no (counted per level) | **new asset** |
| `blaster_starter` / `blaster_spread` / `blaster_rapid` | weapon | adds the blaster + one full magazine | – | no (weapon wheel) | weapon pickup uses the blaster sprite |

Use rules:
- Heal items can't be used at full HP (button shakes, "Already full!"). Heal is instant, capped at
  max HP. Use cooldown 0.5 s per item type.
- Puzzle items are never used from the bag. They are consumed by INTERACT at the matching machine.
- Puzzle items are **never** dropped by enemies at random; they are placed by the generator.

---

## 7. Inventory

| Rule | Value |
|---|---|
| Slots | 25 (5 × 5 grid), opened from pause or the bag icon |
| Stacks | one item id per slot, up to `stackSize`; a second stack starts in a new slot |
| Not in slots | blasters, magazine/reserve ammo, bolts, datachips |
| Quick slots | 4 (Q1–Q4). A quick slot is a **link to an item id**, not a storage slot. It shows the total count of that id. 0 left → icon greyed, link stays |
| Auto-assign | first heal item picked up goes to Q1 if Q1 is empty, first food to Q2 |
| Assign | inventory: tap item → "Put in quick slot" → tap Q1–Q4. Or drag item onto a quick slot |
| Use | tap item → "Use" (heal/food/ammo pack). Quick slot tap = use |
| Drop | tap item → "Drop" → choose amount (1 / all). Drops at hero's feet (random offset up to `rules.json → inventory.dropScatter` 24 pt, never inside a wall), never despawns. A dropped item is not picked up again until the hero has left its pickup radius once (no instant re-pickup). Puzzle items can be dropped too (they stay until picked up again) |
| Sort | "Tidy up" button: puzzle → heal → food → ammo, then by id |
| Full | pickup stays on the floor with a bobbing "!" ; toast "Bag full!" (`ui.toast.bag_full`) |
| Persistence | inventory, quick slots and blasters carry over between levels and are saved (§16.10). Puzzle items (fuse, battery, keycard, energy core) are cleared at level start and level end: they belong to one layout |
| Rescue | inventory is kept 100 % at a checkpoint rescue |

---

## 8. Enemies

All enemies power down into sparkles + their loot. Common rules:
- **Idle → Alert** when the hero is within `detectRange` and in line of sight; alert shows a "!"
  bubble for 0.4 s before the first attack (fairness).
- **Leash:** an enemy returns to its home room if the hero is > 2 × `detectRange` away for 4 s, and
  heals to full (`rules.json → leash.rangeFactor`, `leash.returnAfterSec`, §16.8). Distance is the
  straight line in pt (boltbot: 720 pt ≈ 11 tiles).
- **Knockback:** a hit pushes the enemy by the weapon's `knockback` pt over the enemy's
  `knockbackSec` (0.1 s for all in S1).
- Contact damage triggers on touch, max once per hero invulnerability window.
- Every attack that can hurt has a telegraph ≥ 0.4 s (glow, wind-up pose, or warning line).
- Enemy projectiles are big, slow and colourful (min radius 8 pt, max speed 300 pt/s).

| id | Look | HP | Speed | Contact | Attack | Detect | Score | Loot table |
|---|---|---|---|---|---|---|---|---|
| `boltbot` | small round robot with a spring antenna | 30 | 110 | 8 | none (chaser) | 360 | 50 | `loot_boltbot` |
| `laserdrone` | hovering eye drone | 20 | 140 | 0 | laser ball 6 dmg, 1.8 s cd, 220 pt/s, telegraph 0.5 s | 420 | 75 | `loot_laserdrone` |
| `slimemutant` | wobbly green slime with goggles | 40 | 80 | 10 | none; splits on power-down | 300 | 60 | `loot_slimemutant` |
| `slimemutant_small` | mini slime | 12 | 130 | 5 | none | 300 | 20 | `loot_slimemutant_small` |
| `shieldandroid` | android with a big shiny front shield | 60 | 90 | 8 | shield bash dash 12 dmg, 3.5 s cd, telegraph 0.7 s | 380 | 120 | `loot_shieldandroid` |
| `sporeplant` | grumpy flower in a pot | 45 | 0 (static) | 6 | 3 spore puffs in 30° fan, 4 dmg + slow, 2.6 s cd, 180 pt/s, telegraph 0.6 s | 320 | 80 | `loot_sporeplant` |
| `megamech` | giant cartoon robot, OVERMIND face screen | 1200 | 60 | 12 | see §9 | 900 | 3000 | `loot_megamech` |

### 8.1 Behaviours

**boltbot – chaser.** Moves straight toward the hero with simple steering (avoid walls, separation
from other boltbots 40 pt). Every 2 s, 25 % chance of a 0.5 s "hop" pause (gives kids a breather).
Weak, comes in groups of 2–4.

**laserdrone – kiter.** Flies (ignores pressure plates, floats over low props, blocked by walls).
Keeps 220–320 pt distance; strafes sideways 1.2 s, then stops, glows red 0.5 s, fires one laser
ball. Retreats if hero closer than 160 pt.

**slimemutant – splitter.** Slow chaser. Squashes and grows when hit. On power-down spawns
2 × `slimemutant_small` at ±40 pt that pop out after 0.3 s (not damageable in that time; they
don't damage either). Smalls do not split again. Spread blaster is great here.

**shieldandroid – shielded bruiser.** Front shield covers a 120° arc and blocks 100 % of
projectiles (they bounce off as sparkles). Turns toward the hero at 120°/s, so circling works.
Attack: crouch + shield glow 0.7 s → dash 260 pt at 420 pt/s. After the dash it is **dizzy for
1.5 s** (stars over head, shield lowered, takes 1.5 × damage). Pixel hint on first meet: "Hit it
from behind!".

**sporeplant – turret.** Never moves. Opens petals (telegraph 0.6 s) and sneezes 3 spore puffs.
Spores: 4 dmg + slow (§4), pop on walls. When the hero is closer than 80 pt it closes its petals
and takes 0.5 × damage for 1 s ("shy"), so kids learn to shoot from mid range.

### 8.2 Threat cost (used by the generator)

| id | Cost |
|---|---|
| `boltbot` | 1 |
| `laserdrone` | 2 |
| `slimemutant` | 2 (smalls are free) |
| `sporeplant` | 2 |
| `shieldandroid` | 3 |

---

## 9. Boss – MEGA-MECH Unit Zero (`megamech`)

Arena: fixed 22 × 16 tile room at the end of L5 (not generated), 4 pillars for cover,
2 `machine` core sockets (`requiresItem: energycore`) at the left and right walls. Checkpoint at
the arena entrance. HP 1200, collision radius 72 pt. Contact 12. It is "OVERMIND's body":
its face screen shows OVERMIND's emoji-like expressions.

| Phase | HP range | Attacks | Notes |
|---|---|---|---|
| 1 "Stomp" | 1200 → 800 | **Stomp**: lifts foot 0.8 s (red ring telegraph 140 pt) → shockwave ring 10 dmg, expands to 220 pt; jump over not possible, step out. **Firework volley**: 6 slow star rockets in a fan, 8 dmg, 0.7 s telegraph, cd 4 s | walks slowly toward hero |
| 2 "Shield" | 800 → 400 | at 800 HP: raises a bubble shield (immune). Spawns 2 `boltbot` every 8 s (max 4 alive). The first two boltbots each carry 1 `energycore` (guaranteed drop). Laser sweep: rotating beam with 2 gaps, 10 dmg, 1.0 s telegraph line, cd 6 s | **Puzzle:** insert 1 `energycore` in each of the 2 core machines → shield pops, mech is dizzy 4 s (2 × damage). If a core is lost, the next boltbots carry new ones (always ≥ 1 core reachable) |
| 3 "Overload" | 400 → 0 | all phase 1 attacks, cd × 0.75. **Dash**: telegraph 1.0 s arrow, dash across arena 12 dmg, hits a pillar → dizzy 2.5 s | face screen glitches, funny panic expressions |

Power-down: big sparkle explosion, OVERMIND face says "This is not fair! … Okay, it is fair."
and the screen goes to a smiley. Drop: `loot_megamech` (bolts shower + datachip-like trophy).

**Kid-safety retries:** on rescue in the arena, the hero returns to the arena checkpoint; the boss
returns to the **start of its current phase** (HP = phase top) and keeps phase progress, inserted
cores stay inserted.

---

## 10. Loot tables

`loot.json` holds tables of weighted entries. On power-down:

1. Spawn `bolts` = random int in `[boltsMin, boltsMax]` (auto score pickups).
2. Add every `guaranteed` entry.
3. Do `rolls` times: with probability `dropChance` pick one entry by `weight` and spawn a random
   count in `[min, max]`.
4. **Helper modifiers** (kid-friendly pity rules) change weights before step 3:
   - hero HP ≤ 30 % → weights of category heal/food × 2
   - mag + reserve of the **equipped** blaster ≤ 25 % of (magazine + reserveMax) → weight of that
     blaster's ammo × 2.5
   - ammo for blasters the hero does not own yet → weight × 0 (except in levels ≥ unlock level)
   - **ammo rescue:** mag + reserve of the **equipped** blaster < 1.0 × its `magazineSize` →
     add 1 pack of that blaster's `ammoId` as a guaranteed drop (step 2). Self-limiting: one
     starter pack (+24) lifts the hero above the threshold.
5. Pickups pop out in a small arc (max 48 pt) and never land inside walls.

| Table | Bolts | dropChance × rolls | Main entries (weight) |
|---|---|---|---|
| `loot_boltbot` | 1–3 | 0.45 × 1 | ammo_starter 50, food_apple 30, ammo_spread 10, ammo_rapid 10 |
| `loot_laserdrone` | 2–4 | 0.45 × 1 | ammo_starter 35, ammo_rapid 25, ammo_spread 15, food_cookie 25 |
| `loot_slimemutant` | 1–2 | 0.30 × 1 | food_apple 40, food_cookie 30, ammo_spread 30 |
| `loot_slimemutant_small` | 0–1 | 0.15 × 1 | food_apple 60, ammo_spread 40 |
| `loot_shieldandroid` | 3–6 | 0.80 × 2 | ammo_rapid 30, ammo_starter 25, food_onigiri 20, healpack 10, ammo_spread 15 |
| `loot_sporeplant` | 2–3 | 0.50 × 1 | food_apple 35, food_onigiri 25, food_cookie 25, healpack 15 |
| `loot_megamech` | 40–40 | guaranteed only | healpack ×2, food_onigiri ×3 |
| `loot_crate_small` | 0–2 | 0.70 × 1 | generator-placed supply box: ammo of owned blasters 60, food 40 |

---

## 11. Puzzle elements and door rule

All puzzle elements are interactables with a state `off/on`. Only elements tagged **required**
count for the exit door. Each element shows a small light: red = off, green = on.

| id | How to activate | State behaviour | Notes |
|---|---|---|---|
| `button` | INTERACT within 64 pt | latches **on** forever | the simplest; tutorial |
| `lever` | INTERACT, 0.4 s pull animation | toggles on ↔ off | door needs **every required lever on**. No decoy levers in S1 (keep it fair for 7-year-olds) |
| `pressureplate` | stand on it (hero only; drones and Pixel don't count) for 1.0 s (filling ring) | latches **on** | enemies walking on it do nothing |
| `machine` | INTERACT while carrying `requiresItem` | consumes 1 item, latches **on** | without item: shows the item icon in a bubble + Pixel line "We need a fuse!" |
| `door` | — | opens when its requirements are met | see below |

**Door rule.**
- The level has exactly one **exit door** (`door`, role `exit`) in the exit room.
- Exit door requirement = **all** elements with `required: true` in the level are `on`.
- The door shows one light per required element (max 8) and a counter "3 / 5" on approach.
- When the last one turns on: camera pans 1.0 s to the door, door opens, Pixel cheers, hero
  control is locked during the pan (skippable by tap).
- **Gate doors** (role `gate`, L2+) split the map into zones. A gate opens when its 1–2
  assigned elements (in the earlier zone) are on. Gates are never required for the exit
  counter, they only gate progress.
- Opening the exit door does not end the level: the hero must walk into the exit pad behind it.

**M2 notes (64 pt tiles).**
- Timings live in `rules.json → puzzle` (§16.8): lever pull 0.4 s, plate hold 1.0 s, door pan
  1.0 s, max 8 door lights. INTERACT range = `hero.json → hero.interactRadius` (64 pt = 1 tile),
  measured from the hero centre to the element centre (machine: centre of its 2 × 2 cells).
- Focus: if several interactables are in range, the nearest one is focused (ring + INTERACT glow).
- The plate timer resets if the hero steps off before 1.0 s. Plate size = 1 tile; the hero
  (36 pt) counts as "on" when its centre is inside the plate cell.
- A machine without its item shows the item bubble and the toast `ui.toast.need_item`
  ("This needs: Fuse"). The same toast is not repeated within `toast.repeatCooldownSec` (3 s).
- Picking up a puzzle item shows `ui.toast.got_item`; opening a gate shows `ui.toast.gate_open`;
  the exit door shows `ui.toast.door_open` after the pan. Pixel lines replace these toasts in M3.
- Gate and exit doors fill the whole corridor width (2 cells in S1, `corridorWidth`).
- `minElementSpacing` = tile distance between element anchor cells (machine: bottom-left cell).

**Solvability (generator guarantee).** For every element: it is reachable from the start using
only the doors that open before it. For every machine: its required item is placed in the same
zone or an earlier zone and never behind the gate it opens. Verified by simulation (§14.3).

---

## 12. Checkpoints and rescue

- **Checkpoints**: the start pad, every gate door when it opens (pad just behind it), and the boss
  arena entrance. Touching a pad saves it (Pixel: "Checkpoint saved!"). Last touched wins.
- **Rescue at 0 HP** (never "game over"):
  1. Hero stops, sparkles; time slows to 0.3 × for 0.6 s.
  2. Pixel beams the hero to the last checkpoint (0.8 s teleport effect).
  3. Hero gets **100 % HP**, 2 s invulnerability.
  4. Inventory, quick slots, blasters, ammo, collected datachips: kept.
  5. Starter ammo topped to at least one full magazine.
  6. Puzzle states kept. Powered-down enemies stay down. Living enemies get full HP and return to
     their home rooms.
  7. `rescues` counter + 1 (affects 3rd star, §15).
- No lives, no restart penalty besides the star.
- M3 numbers: `rules.json → rescue` (§16.9): slow-mo `slowMoScale` 0.3 for `slowMoSec` 0.6
  (real time), beam `beamSec` 0.8, starter top-up: if starter mag + reserve < `starterMinMagazine`
  (12), the reserve gets the gap, then the magazine fills from the reserve at once (no reload
  animation). Invulnerability = `hero.json → respawnInvulnerableSec` (2.0 s). Input is locked from
  0 HP until the hero appears at the checkpoint. Enemy shots in flight are removed at the beam.
  Then Pixel says `pixel.generic.rescue`. The words "game over" never appear.

---

## 13. Pixel – the drone buddy (`pixel`)

All numbers in this section live in `rules.json → pixel / hints / lowHp` (§16.9) and
`levels.json → hintIdleSec`.

| Behaviour | Rule |
|---|---|
| Follow | floats at `followOffset` (−40, +40) pt = about 56 pt up-left of the hero, in **world** axes (does not turn with the aim: twin-stick aim changes all the time and Pixel would swing around). Bobbing 4 pt at 1.5 Hz; lerp 0.15 s; passes through walls (it's a hologram drone); never blocks shots or physics |
| Speak | lines show in the **HUD bubble at the top centre** (ART_BIBLE §7: max 420 × 90, `ui_icon_pixel` avatar, tap to dismiss), **not** above Pixel in the world (always readable, never off-screen or under walls). Max 60 chars, 2 lines max in the bubble. Shown for `bubbleBaseSec + bubblePerCharSec × chars` (3.0 + 0.04/char → 3.4–5.4 s). One line at a time, queue max 2, older dropped. While a line shows, Pixel does a small talk wiggle |
| Repeat guard | the same `pixel.*` key is not queued again within `pixel.repeatCooldownSec` (10 s). Low HP: `lowHp.lineCooldownSec` (60 s). Story beats, intro and outro are exempt (each beat fires once per level anyway) |
| Hint (tap Pixel or idle) | see "Hints" below. Fly 2 s, dotted arrow 6 s, then return. Cooldown 10 s |
| Pointer | minimap pings unactivated reachable required elements (and the exit pad once the door is open) as blinking dots after `hints.pointerAfterSec` (60 s) in the level. Ping style: ART_BIBLE §14 |
| Scan | first time an enemy type is **seen** (on screen and in line of sight, not first contact): short scan beam + tip line (`pixel.tip.<enemyId>`). The boss has no tip; its lines are the `boss.*` beats |
| Rescue | at 0 HP performs the rescue (§12), then says `pixel.generic.rescue` |
| Combat | Pixel never attacks and can't be hurt |
| Silence | Settings → "Pixel talk: lots / some / quiet" (default lots). **lots** = everything. **some** = story beats + hint lines (`hint_*`, `need_*`, `idle`, `rescue`). **quiet** = story beats, intro/outro and `rescue` only. Hints still fly and point in every mode |

**Tap on Pixel vs. stick touch.** Pixel floats inside the stick zones. A touch is a **Pixel tap**
when it starts within `pixel.tapRadius` (80 pt) of Pixel's on-screen centre, ends within
`pixel.tapMaxSec` (0.25 s) and moves less than `pixel.tapMaxMovePt` (12 pt). Such a touch starts no
stick. Implementation: a touch that starts inside the radius is held back for up to 0.25 s; if it
moves ≥ 12 pt or lasts longer, it becomes a normal stick touch from its **start** point (so a kid
who meant to move loses at most 0.25 s). Touches outside the radius start sticks at once.
While a hint is running (fly + arrow), taps on Pixel do nothing; during the cooldown a tap says
`pixel.generic.hint_wait`.

**Hints.**
1. Target = the nearest **reachable** (only through doors that are open now) required element that
   is off, by path distance. Gate elements count as required for this.
2. If that element is a machine and its item is **not** in the bag: target the nearest reachable
   floor item of that id (line `hint_item`). If no such floor item exists (should not happen,
   the generator guarantees it): no fly, line `pixel.generic.need_<item>`.
3. If that element is a machine and its item **is** in the bag: fly to the machine as normal, line
   `pixel.generic.hint_machine` ("You have it! Bring it to the machine."). Saying "We need a
   fuse!" while the kid carries one would confuse them.
4. Else, if all required elements are on and the exit door is open: target `level.exitPad`
   (line `hint_exit`).
5. Line while flying to an element: `hint_here` (tap) or `idle` (idle trigger).

**Idle hint and "progress".** The idle timer counts game time (not while paused, in the
inventory, during the door pan or the rescue sequence). It fires the hint after `hintIdleSec`
(L1 20 s, L2–L5 30 s) without progress. **Progress** = any of:
- a required element or a gate element turns on (lever pull counts when it ends on),
- an item is **stored** in the bag (PickupResolver `stored`; bolts, datachips and ammo that goes
  straight to the reserve do not count),
- a gate or the exit door opens,
- a room is revealed for the first time,
- a checkpoint is touched.
Any shown hint (tap or idle) also resets the timer. The tap hint cooldown (10 s) and the idle
timer are separate; an idle hint during the tap cooldown waits until the cooldown ends.

**Generic triggers** (keys `pixel.generic.*`). If the level has a beat for the same trigger
(`start`, `doorOpen`, `firstLowHp`), the level beat plays **instead of** the generic line.

| Key | Trigger | Filter | EN | DE |
|---|---|---|---|---|
| `pixel.generic.start` | level start, no `start` beat | lots | Let's go! Find all the switches. | Los geht's! Finde alle Schalter. |
| `pixel.generic.first_item` | first item stored in the bag this level | lots | Into the bag it goes! | Ab in die Tasche damit! |
| `pixel.generic.bag_full` | pickup `staysBagFull` | lots | Your bag is full! | Deine Tasche ist voll! |
| `pixel.generic.low_hp` | HP ≤ `lowHp.threshold`, no `firstLowHp` beat or later times | lots | Ouch! Eat something! | Autsch! Iss etwas! |
| `pixel.generic.reload` | first empty magazine | lots | Tap RELOAD for new shots! | Tipp auf NACHLADEN! |
| `pixel.generic.element_on` | a required element on (not the last) | lots | Yes! One more done! | Ja! Wieder eins geschafft! |
| `pixel.generic.all_on` | last required element on | lots | All done! The door opens! | Alles geschafft! Die Tür geht auf! |
| `pixel.generic.gate_open` | a gate opens (replaces `ui.toast.gate_open`) | lots | The gate is open. Let's go on! | Das Tor ist offen. Weiter geht's! |
| `pixel.generic.door_open` | exit door open, no `doorOpen` beat | lots | The door is open! Step on the glowing pad! | Die Tür ist offen! Lauf auf das Leuchtfeld! |
| `pixel.generic.checkpoint` | checkpoint touched (replaces `ui.toast.checkpoint`) | lots | Checkpoint saved! | Checkpoint gespeichert! |
| `pixel.generic.rescue` | after the rescue beam | all | Gotcha! I beamed you back. | Hab dich! Ich habe dich zurückgebeamt. |
| `pixel.generic.idle` | idle hint starts | some | Need help? Tap me! | Brauchst du Hilfe? Tipp mich an! |
| `pixel.generic.hint_here` | tap hint to an element | some | This way! Follow my arrow. | Hier lang! Folge meinem Pfeil. |
| `pixel.generic.hint_item` | hint to a floor puzzle item | some | Look! We need that thing over there! | Da liegt was, das wir brauchen! |
| `pixel.generic.hint_machine` | hint to a machine whose item is in the bag | some | You have it! Bring it to the machine. | Du hast es! Bring es zur Maschine. |
| `pixel.generic.hint_exit` | hint to the exit pad | some | The exit is over there! | Der Ausgang ist da drüben! |
| `pixel.generic.hint_wait` | Pixel tapped during the cooldown | some | One sec! My antenna is cooling down. | Moment! Meine Antenne kühlt ab. |
| `pixel.generic.need_fuse` | machine without item / hint with item in bag | some | We need a fuse! | Wir brauchen eine Sicherung! |
| `pixel.generic.need_battery` | same | some | We need a battery! | Wir brauchen eine Batterie! |
| `pixel.generic.need_keycard` | same | some | We need a keycard! | Wir brauchen eine Schlüsselkarte! |
| `pixel.generic.need_energycore` | same | some | We need an energy core! | Wir brauchen einen Energiekern! |
| `pixel.tip.boltbot` | first sight | lots | Boltbots run at you. Zap them! | Boltbots rennen auf dich zu. Zapp sie! |
| `pixel.tip.laserdrone` | first sight | lots | Drones glow red, then shoot. Dodge! | Drohnen leuchten rot, dann schießen sie. Ausweichen! |
| `pixel.tip.slimemutant` | first sight | lots | Slimes split in two! | Schleime teilen sich in zwei! |
| `pixel.tip.slimemutant_small` | first sight | lots | Mini slimes! They are quick. | Mini-Schleime! Die sind flott. |
| `pixel.tip.shieldandroid` | first sight | lots | Big shield! Hit it from behind! | Großer Schild! Triff ihn von hinten! |
| `pixel.tip.sporeplant` | first sight | lots | Don't get too close. It sneezes! | Nicht zu nah. Sie niest! |

Level beats (`pixel.l<n>.*`, `boss.*`) and intro/outro (`story.*`) are "story" in the filter.
"First" triggers (first item, first reload, tips) are once per **level**, so a replay teaches again.
The `need_*` line from tapping a machine replaces the M2 toast `ui.toast.need_item` only when the
talk level lets it through; otherwise the toast still shows.

---

## 14. Procedural generator

Algorithm: **BSP rooms + corridors** with a zone lock-and-key pass (GameplayKit
`GKMersenneTwisterRandomSource`, seeded per play; seed shown in debug menu).

### 14.1 Steps

1. Map = `gridWidth × gridHeight` tiles. BSP split until leaves are ≤ `maxRoomSize`, depth ≤
   `bspMaxDepth`. Place one room per leaf (size in `[minRoomSize, maxRoomSize]`, 1-tile margin).
   Keep `roomCount` rooms (discard smallest extras; regenerate if fewer than `roomCount.min`).
2. Connect sibling leaves with L-shaped corridors (`corridorWidth` tiles). Add extra loop
   corridors between neighbours with chance `loopChance`.
3. Start room = room with the smallest index on the map's left third. Exit room = room with the
   largest graph distance from start (BFS). Critical path = shortest start → exit path.
4. Split the critical path into `zones` segments; place a **gate door** on the corridor where each
   new zone begins. Rooms off the path join the zone of their attachment room.
5. Place puzzle elements from the level's `puzzle.elements` list: each into a random non-start
   room of its allowed zones, at least `minElementSpacing` tiles apart, not in corridors, not
   blocking a doorway. Machines' items go into a different room of the same or an earlier zone
   (`itemPlacement`: `sameZone` | `earlierZone`).
6. Place enemies: each room gets `threat = roomArea / 40 × enemyDensity` (rounded, min 1, max
   `maxThreatPerRoom`) points; start room and checkpoint rooms get 0. Spend points by
   `enemyMix` weights using the threat cost table (§8.2). Sporeplants only on tiles ≥ 2 from walls
   and doorways.
7. Place pickups (`pickups`): heal/food/ammo per room by chance, `crates` supply boxes,
   3 `datachip` in dead-end or off-path rooms (≥ 1 off the critical path), 1 guaranteed weapon
   pickup when `weaponPickup` is set (zone 1, off path, "treasure room").
8. Decorate with theme props (`decorDensity`), never on doorways or element tiles.

### 14.2 Parameters (per level, in `levels.json → generator`)

| Field | Type | Meaning | Range S1 |
|---|---|---|---|
| `gridWidth`, `gridHeight` | int | map size in tiles | 48–72 × 36–56 |
| `roomCount` | {min,max} | rooms kept; `max ≤ 2^bspMaxDepth` | 6–15 |
| `minRoomSize`, `maxRoomSize` | int | room side length in tiles (floor cells) | 7–14 |
| `bspMaxDepth` | int | BSP depth | 3–4 |
| `corridorWidth` | int | tiles | 2 |
| `loopChance` | 0…1 | extra corridors | 0.1–0.35 |
| `zones` | int | zones on critical path | 1–3 |
| `enemyDensity` | float | threat multiplier | 0.6–1.6 |
| `maxThreatPerRoom` | int | cap | 3–10 |
| `minElementSpacing` | int | tiles between element anchor cells | 7–8 |
| `decorDensity` | 0…1 | prop chance per free floor tile (step 8 is Later) | 0.03–0.08 |
| `maxAttempts` | int | regenerate tries | 50 |

**64 pt re-check (M2-1).** Reference numbers: view 18.7 × 13 tiles, usable ≈ 18.7 × 11 below the
HUD band; hero 36 pt wide (0.56 tile), speed 220 pt/s = 3.44 tiles/s; boltbot detect 360 pt =
5.6 tiles; starter range 520 pt = 8.1 tiles.

| Check | Rule | Result |
|---|---|---|
| Room size | typical room ≈ 1 screen | sides 7/8–12/14 tiles = 448/512–768/896 pt. Mean 9.5–11 tiles ≈ 0.55 × screen width, 0.9 × usable height → one screen. Max 14 (896 pt) scrolls a little vertically, which is fine for the big rooms of L3–L5. 15 (L4 before) was cut: 960 pt is > 1 screen high even without HUD |
| Min room | fits a 2 × 2 machine + the 3-tile enemy gap + 2–3 enemies | 8 tiles in every level with machines (L2–L5). L1 has no machines and keeps 7 (448 pt), its BSP leaves (≈ 12 × 18 tiles) are too tight for 8 + margins |
| Combat range | enemies across a room see you; you can hit them | room 10 tiles = 640 pt: boltbot (360 pt) wakes at about half a room, starter (520 pt) reaches ≈ 80 % of a room. Fair: the alert "!" fires before contact |
| Corridor | wide enough to dodge, narrow enough to read as a corridor | 2 tiles = 128 pt = 3.5 × hero width; shieldandroid (40 pt) passes the hero. L1 3 → 2: at 64 pt a 3-tile corridor (192 pt) reads like a thin room and makes 3-cell doors |
| Element spacing | elements in different spots, but zones with 4–5 elements still fit | 7–8 tiles = 448–512 pt ≈ ½ screen width, more than 1 boltbot detect range. 10 tiles (640 pt) made L4 zone 2 (fuse machine, keycard machine, 2 gate buttons, maybe the plate) hard to place in 4–5 rooms |
| BSP | `roomCount.max ≤ 2^bspMaxDepth`, leaves fit `maxRoomSize` + 1-tile margin | L1 8 ≤ 8, L2 11 ≤ 16, L3 12 ≤ 16, L4 15 ≤ 16, L5 13 ≤ 16. L4 depth 5 (32 leaves for 15 rooms) dropped to 4 |
| Fill | room floor (mean side² × mean rooms) ≈ 35–41 % of the grid, so corridors stay short | L1 37 %, L2 40 %, L3 41 %, L4 37 % → 41 % after 80 × 60 → 72 × 56, L5 36 % |

**Walking-time check** (estimate: rooms visited × centre spacing `√(grid area / rooms)` × 1.5
for backtracking, at 3.44 tiles/s). Pure walking stays at 12–15 % of par; the rest is fights,
puzzles and kids exploring. `parTimeSec` is unchanged.

| Level | Grid | Rooms (mean) | Spacing | Walk tiles | Walk s | Par s | Walk / par |
|---|---|---|---|---|---|---|---|
| L1 | 48 × 36 | 7 | 15.7 | 165 | 48 | 360 | 13 % |
| L2 | 60 × 44 | 9.5 | 16.7 | 238 | 69 | 480 | 14 % |
| L3 | 64 × 48 | 10.5 | 17.1 | 269 | 78 | 540 | 14 % |
| L4 | 72 × 56 | 13.5 | 17.3 | 350 | 102 | 660 | 15 % (80 × 60: 111 s) |
| L5 | 72 × 54 | 11.5 | 18.4 | 317 | 92 | 780 | 12 % (+ boss) |

### 14.3 Validation (must pass, else regenerate with seed + 1)

- All rooms connected; start ≠ exit; path length ≥ `zones + 1` rooms.
- Lock-and-key simulation: start with "open doors = none", flood fill, collect items + activate
  reachable elements, open satisfied gates, repeat until no change. Pass if the exit door is open.
- Element spacing and room caps respected; no element or item within 3 tiles of a spawned enemy.
- After `maxAttempts` failures: use the level's `fallbackSeed` (hand-checked) so the game never
  breaks.

---

## 15. Scoring and stars

**Score** (shown on the result screen):

| Source | Points |
|---|---|
| Enemy powered down | enemy `scoreValue` |
| Bolt | 10 each |
| Datachip | 250 each |
| Time bonus | `max(0, parTimeSec − timeSec) × 5` |
| No-rescue bonus | 500 if `rescues == 0` |

**Stars per level (each independent, best result is saved):**

| Star | Condition |
|---|---|
| ★1 | Finish the level |
| ★2 | Find all 3 datachips |
| ★3 | Finish with `rescues ≤ starRescueMax` (L1–L4: 1, L5: 2) **and** `timeSec ≤ parTimeSec × 1.5` |

15 stars max in Season 1. Stars only decorate the map; nothing is locked behind stars (levels unlock
by finishing the previous one).

---

## 16. Data schemas

All files: UTF-8 JSON, root object with `"version": 1` and one array (exceptions: `hero.json`
§16.6 and `rules.json` §16.8). Unknown fields must be
ignored by the decoder (forward compatible). Optional fields marked `?`. Ids reference each
other and are validated at load (debug assert + unit test).

### 16.1 `weapons.json`

```json
{ "version": 1, "weapons": [ Weapon ] }
```

| Field | Type | Meaning |
|---|---|---|
| `id` | string | `blaster_starter` / `blaster_spread` / `blaster_rapid` |
| `nameKey` | string | localization key |
| `ammoId` | string | item id of its ammo |
| `damage` | int | damage per projectile |
| `pellets` | int | projectiles per shot |
| `spreadDeg` | float | total fan angle across pellets (0 = single) |
| `jitterDeg` | float | random ± per shot |
| `fireRate` | float | shots per second |
| `projectileSpeed` | float | pt/s |
| `range` | float | pt before projectile fades |
| `projectileRadius` | float | pt |
| `projectileStyle` | string | `light_bolt` / `bubble` / `foam` (art + sfx hook) |
| `knockback` | float | pt pushed on enemy hit |
| `magazineSize` | int | |
| `reserveMax` | int | |
| `reloadSec` | float | |
| `aimAssistConeDeg` | float | half angle of aim-assist cone |
| `unlockLevel` | int | first level where it can appear (ammo drops gated by this) |

### 16.2 `enemies.json`

```json
{ "version": 1, "enemies": [ Enemy ] }
```

| Field | Type | Meaning |
|---|---|---|
| `id` | string | enemy id (= asset name) |
| `nameKey` | string | |
| `behavior` | string | `chaser` / `kiter` / `splitter` / `shielded` / `turret` / `boss` |
| `hp` | int | |
| `moveSpeed` | float | pt/s (0 = static) |
| `radius` | float | collision radius pt |
| `flying` | bool | ignores pressure plates and low props |
| `contactDamage` | int | |
| `detectRange` | float | pt |
| `alertSec?` | float | "!" bubble time between Idle → Alert and the first chase/attack (§8). Default 0.4, must be ≥ 0.4 (fairness) |
| `knockbackSec?` | float | duration of the push when a hero shot hits (distance = weapon `knockback`). Default 0.1; set on all 7 enemies |
| `threatCost` | int | generator budget cost (0 = never spawned by budget) |
| `scoreValue` | int | |
| `lootTableId` | string | `loot.json` table id |
| `attack?` | Attack | `{ "type": "projectile"/"dash"/"none", "damage", "cooldownSec", "telegraphSec", "range", "projectileSpeed?", "projectileCount?", "spreadDeg?", "projectileRadius?", "dashDistance?", "dashSpeed?", "slowMultiplier?", "slowSec?" }` |
| `keepDistance?` | {min,max} | kiter distance band pt |
| `splitInto?` | {enemyId,count,spawnDelaySec,spawnOffset} | splitter (offset in pt) |
| `shield?` | {arcDeg,turnRateDeg,dizzySec,dizzyDamageMultiplier} | shielded |
| `shyRange?`, `shyDamageMultiplier?`, `shySec?` | float | turret close-range defence |
| `hopChance?`, `hopEverySec?`, `hopPauseSec?` | float | chaser breather pauses (boltbot) |
| `separation?` | float | pt kept from same-type allies |
| `retreatRange?`, `strafeSec?` | float | kiter: back off below this distance; strafe time between shots |
| `rescueResetsToPhaseTop?` | bool | boss: on hero rescue, HP returns to current phase's `hpFrom` |
| `phases?` | [Phase] | boss only: `{ "id", "hpFrom", "hpTo", "immune", "cooldownMultiplier?", "attacks": [ {"type": "stomp"/"volley"/"laser_sweep"/"dash", "damage", "cooldownSec", "telegraphSec", "range", "telegraphRadius?", "projectileSpeed?", "projectileCount?", "spreadDeg?", "projectileRadius?", "gaps?", "sweepDegPerSec?", "dashSpeed?", "pillarDizzySec?"} ], "spawn?": {"enemyId","everySec","maxAlive","carryItemFirst?","carryCount?"}, "unlockBy?": {"elementType","requiresItem","count","dizzySec","dizzyDamageMultiplier"} }` |

### 16.3 `items.json`

```json
{ "version": 1, "items": [ Item ] }
```

| Field | Type | Meaning |
|---|---|---|
| `id` | string | |
| `nameKey`, `descKey` | string | |
| `category` | string | `heal` / `food` / `ammo` / `puzzle` / `collectible` / `weapon` |
| `stackSize` | int | max per slot (0 = not stored in inventory) |
| `storesInInventory` | bool | false for collectibles/weapons; ammo = true only for overflow packs |
| `usable` | bool | can be used from bag / quick slot |
| `droppable` | bool | |
| `healAmount?` | int | heal/food |
| `ammoId?`, `ammoAmount?` | string, int | ammo packs (ammoId = own id) |
| `weaponId?` | string | weapon pickup |
| `scoreValue?` | int | collectibles |
| `magnet?` | bool | auto-pulled (bolts) |

### 16.4 `loot.json`

```json
{ "version": 1, "modifiers": [ Modifier ], "tables": [ LootTable ] }
```

| Field | Type | Meaning |
|---|---|---|
| `tables[].id` | string | |
| `tables[].boltsMin`, `boltsMax` | int | bolt count |
| `tables[].dropChance` | 0…1 | chance per roll |
| `tables[].rolls` | int | |
| `tables[].entries` | [{itemId, weight, min, max}] | weighted pool |
| `tables[].guaranteed` | [{itemId, count}] | always dropped |
| `modifiers[].id` | string | `low_hp` / `low_ammo` / `unowned_weapon_ammo` / `ammo_rescue` |
| `modifiers[].condition` | string | `heroHpRatioBelow` / `equippedAmmoRatioBelow` / `weaponNotOwned` / `equippedAmmoBelowMagazines` |
| `modifiers[].threshold?` | float | ratio for the condition. For `equippedAmmoBelowMagazines`: true when equipped mag + reserve < `threshold × magazineSize` (strictly below) |
| `modifiers[].appliesTo` | string | `category:heal,food` / `equippedAmmo` / `unownedAmmo` |
| `modifiers[].weightMultiplier` | float | 1.0 = no weight change |
| `modifiers[].guaranteeCount?` | int | if set and the condition is true: add `guaranteeCount` × the `appliesTo` item (for `equippedAmmo` = equipped weapon's `ammoId`) to the guaranteed drops of step 2, count 1 each. Applies to every table roll (enemies + crates), independent of `dropChance`/`rolls`, and in addition to them. Absent = 0 |

### 16.5 `levels.json`

```json
{ "version": 1, "levels": [ Level ] }
```

| Field | Type | Meaning |
|---|---|---|
| `id` | string | `l1` … `l5` |
| `index` | int | 1…5 |
| `nameKey`, `subtitleKey` | string | |
| `theme` | string | tileset/props/music id: `rooftop_lab`, `robot_factory`, `gene_greenhouse`, `server_fortress`, `overmind_core` |
| `music` | string | track id |
| `bossMusic?` | string | track for the boss arena |
| `parTimeSec` | int | |
| `starRescueMax` | int | |
| `fallbackSeed` | int | known-good seed |
| `generator` | object | fields of §14.2 (`roomCount` = {min,max}) |
| `enemyMix` | [{enemyId, weight, zoneMin?, minPathFraction?, maxPerRoom?}] | `zoneMin`: earliest zone; `minPathFraction` 0…1: only in rooms past this fraction of the critical path; `maxPerRoom`: cap |
| `firstEncounterRoom?` | string | enemy id placed alone in the first room after start (tutorial) |
| `puzzle.elements` | [{type, count, required, zone, requiresItem?, itemPlacement?}] | `type` ∈ button/lever/pressureplate/machine; `zone` = 1-based zone or `"any"`; `itemPlacement` overrides the level default for this element |
| `puzzle.gates` | [{zone, opensWith: [{type, count, requiresItem?}]}] | gate door before `zone`; its elements are placed in `zone − 1` |
| `puzzle.itemPlacement` | string | `sameZone` / `earlierZone` |
| `pickups.perRoom` | [{itemId, chance}] | floor pickups per non-start room. Ammo for a blaster that is neither owned nor placed earlier on the path is skipped |
| `pickups.crates` | {min, max, lootTableId} | supply boxes |
| `pickups.datachips` | int | always 3 |
| `pickups.weaponPickup?` | string | weapon id guaranteed in zone 1 |
| `pickups.startGift?` | [{itemId, count}] | added on level start if not already owned (tutorial) |
| `pickups.fixed?` | [{itemId, count, respawnOnBossPhase}] | boss arena pillar pickups |
| `hintIdleSec` | int | seconds without progress before Pixel auto-hints (default 30, L1 20) |
| `bossId?` | string | `megamech` for L5 |
| `bossArena?` | {width, height, coreMachines, pillars} | fixed arena |
| `story` | {intro: [key], outro: [key], beats: [{trigger, key}]} | Pixel lines; triggers: `start`, `firstEnemy:<id>`, `firstPickup:<id>`, `firstSeen:<elementType or gate>`, `firstLowHp`, `zone:<n>`, `allElementsOn`, `doorOpen`, `bossPhase:<n>`, `bossDefeated`. `intro`/`outro` lines play on the level card before/after play |

### 16.6 `hero.json`

Exception to the "one array" rule: one hero, so the root holds three objects.

```json
{ "version": 1, "hero": Hero, "controls": Controls, "camera": Camera }
```

**`hero`**

| Field | Type | Value | Meaning |
|---|---|---|---|
| `maxHp` | int | 100 | |
| `moveSpeed` | float | 220 | pt/s at stick magnitude 1 |
| `radius` | float | 18 | collision circle pt |
| `invulnerableSec` | float | 0.8 | after a hit (blinks) |
| `respawnInvulnerableSec` | float | 2.0 | after a rescue / respawn (§12 step 3) |
| `knockbackDistance` | float | 80 | pt pushed when hit |
| `knockbackSec` | float | 0.12 | duration of the push |
| `pickupRadius` | float | 40 | pt, auto pickup |
| `magnetRadius` | float | 96 | pt, items with `magnet: true` (bolts) fly to the hero |
| `interactRadius` | float | 64 | pt, INTERACT range |
| `startLoadout` | {weaponId, magazine, reserve} | `blaster_starter`, 12, 48 | equipped blaster at a fresh L1 start (items of the start gift come from `levels.json → pickups.startGift`) |
| `starterSafetyNet` | {rechargeEverySec, rechargeTo} | 0.5, 12 | starter only: when mag + reserve = 0, reserve +1 every `rechargeEverySec` up to `rechargeTo` (§5.1) |

**`controls`** (fractions are of screen width/height or of `stickRadius`, see Meaning)

| Field | Type | Value | Meaning |
|---|---|---|---|
| `moveZoneWidth` | 0…1 | 0.45 | left share of screen width for the move stick |
| `aimZoneWidth` | 0…1 | 0.45 | right share of screen width for the aim stick |
| `hudBandHeight` | 0…1 | 0.15 | top share of screen height where no stick can start |
| `stickRadius` | float | 70 | knob travel radius pt (visual base 140, knob 64 are art constants) |
| `moveDeadZone` | 0…1 | 0.15 | × `stickRadius`; below = no movement |
| `aimDeadZone` | 0…1 | 0.30 | × `stickRadius`; below = aim only, no fire |
| `fullMagnitudeAt` | 0…1 | 0.85 | magnitude at or above this counts as 1.0 |
| `followFactor` | float | 1.4 | base follows when the finger is > `followFactor × stickRadius` from the base |
| `fadeSec` | float | 0.15 | stick fade-out after release |
| `aimAssistStrength` | 0…1 | 0.6 | share of the angle difference to rotate toward the target (§3.4) |
| `aimAssistDefaultOn` | bool | true | Settings default |

Aim-assist cone per blaster stays in `weapons.json → aimAssistConeDeg`.

**`camera`**

| Field | Type | Value | Meaning |
|---|---|---|---|
| `smoothingSec` | float | 0.12 | follow smoothing time constant |
| `lookAhead` | float | 60 | pt offset in aim direction (move direction if not aiming) |

### 16.7 Localization keys

| Pattern | Source |
|---|---|
| `weapon.<id>.name` | `weapons.json → nameKey` |
| `enemy.<id>.name` | `enemies.json → nameKey` |
| `item.<id>.name`, `item.<id>.desc` | `items.json → nameKey/descKey` |
| `level.<id>.name`, `level.<id>.subtitle` | `levels.json → nameKey/subtitleKey` |
| `hud.*` | HUD labels; format args are positional (`%1$lld`, `%2$lld`) so DE/EN can reorder |
| `ui.toast.*` | one-line HUD toasts (M2) |
| `levelComplete.*` | M2 "Level complete" card |
| `pixel.*`, `story.*`, `boss.*` | Pixel/OVERMIND lines (§13, `levels.json → story`, `docs/levels/L*.md`); max 60 chars in de + en; `pixel.*` holds **only** spoken lines |
| `inventory.*`, `pause.*`, `title.*`, `levelIntro.*`, `settings.*` | screens (M3; `settings.*` from the audio run) |

**M2 keys** (added in M2-1):

| Key | Args | EN | DE |
|---|---|---|---|
| `hud.interact` | – | Use | Benutzen |
| `hud.interact.accessibility` | – | Use the thing next to you | Benutze das Ding neben dir |
| `hud.door.accessibility` | on, total | %1$lld of %2$lld switches on | %1$lld von %2$lld Schaltern an |
| `hud.keyChips.accessibility` | – | Your things | Deine Sachen |
| `hud.minimap.accessibility` | – | Map | Karte |
| `ui.toast.need_item` | item name (`%@`) | This needs: %@ | Das braucht: %@ |
| `ui.toast.got_item` | item name (`%@`) | You got: %@ | Du hast: %@ |
| `ui.toast.checkpoint` | – | Checkpoint saved! | Checkpoint gespeichert! |
| `ui.toast.bag_full` | – | Your bag is full! | Deine Tasche ist voll! |
| `ui.toast.gate_open` | – | A gate is open! | Ein Tor ist offen! |
| `ui.toast.door_open` | – | The exit is open! | Der Ausgang ist offen! |
| `levelComplete.title` | – | Level complete! | Level geschafft! |
| `levelComplete.time` | min, sec | Time: %1$lld:%2$02lld | Zeit: %1$lld:%2$02lld |
| `levelComplete.score` | points | Score: %1$lld | Punkte: %1$lld |
| `levelComplete.datachips` | found, total | Data Chips: %1$lld / %2$lld | Datenchips: %1$lld / %2$lld |
| `levelComplete.continue` | – | Continue | Weiter |
| `levelComplete.toTitle` | – | Main menu | Hauptmenü |

**M3 keys** (added in M3-1; Pixel lines are in §13 and `docs/levels/L*.md`):

| Key | Args | EN | DE |
|---|---|---|---|
| `pause.inventory` | – | Bag | Tasche |
| `pause.quitConfirm.title` | – | Leave the level? | Level verlassen? |
| `pause.quitConfirm.message` | – | Your things stay. The level starts again next time. | Deine Sachen bleiben. Das Level startet dann neu. |
| `pause.quitConfirm.yes` / `.no` | – | Leave / Stay | Verlassen / Bleiben |
| `title.continue` | – | Continue | Weiterspielen |
| `title.newGame` | – | New game | Neues Spiel |
| `title.newGameConfirm.title` | – | Start a new game? | Neues Spiel starten? |
| `title.newGameConfirm.message` | – | Your old game will be gone. | Dein altes Spiel ist dann weg. |
| `title.newGameConfirm.yes` / `.no` | – | Start new / Keep my game | Neu starten / Mein Spiel behalten |
| `levelIntro.level` | level number | Level %lld | Level %lld |
| `levelIntro.tapToStart` | – | Tap to start | Tippen zum Starten |
| `inventory.title` | – | Bag | Tasche |
| `inventory.use` | – | Use | Benutzen |
| `inventory.drop` | – | Drop | Ablegen |
| `inventory.dropOne` / `.dropAll` | – | Drop 1 / Drop all | 1 ablegen / Alle ablegen |
| `inventory.assign` | – | Put in quick slot | In Schnellplatz |
| `inventory.assignPrompt` | – | Tap a quick slot. | Tipp auf einen Schnellplatz. |
| `inventory.cancel` | – | Cancel | Abbrechen |
| `inventory.tidy` | – | Tidy up | Aufräumen |
| `inventory.close` | – | Close | Schließen |
| `inventory.empty` | – | Your bag is empty. | Deine Tasche ist leer. |
| `inventory.pickHint` | – | Tap a thing. | Tipp auf ein Ding. |
| `inventory.count` | count | You have %lld | Du hast %lld |
| `inventory.puzzleHint` | – | Bring it to a machine. | Bring es zu einer Maschine. |
| `inventory.slot.accessibility` | name, count | %1$@, %2$lld | %1$@, %2$lld Stück |
| `inventory.emptySlot.accessibility` | – | Empty slot | Leerer Platz |
| `hud.inventory.accessibility` | – | Open your bag | Tasche öffnen |
| `hud.quickSlot.accessibility` | slot, name, count | Quick slot %1$lld: %2$@, %3$lld left | Schnellplatz %1$lld: %2$@, noch %3$lld |
| `hud.quickSlot.empty.accessibility` | slot | Quick slot %lld: empty | Schnellplatz %lld: leer |
| `hud.pixel.accessibility` | – | Pixel. Tap for help. | Pixel. Tipp für Hilfe. |
| `hud.pixelBubble.accessibility` | line | Pixel says: %@ | Pixel sagt: %@ |
| `ui.toast.already_full` | – | Already full! | Schon voll! |
| `ui.toast.dropped` | item name | Dropped: %@ | Abgelegt: %@ |
| `settings.pixelTalk` | – | Pixel talk | Pixel redet |
| `settings.pixelTalk.lots` / `.some` / `.quiet` | – | Lots / Some / Quiet | Viel / Etwas / Leise |
| `settings.aimAssist` | – | Aim help | Zielhilfe |

The pause button keeps `game.menu`; the pause menu's settings entry uses `settings.title`.
"Put in quick slot" is "In Schnellplatz" in German so it fits a 64 pt high button in one line.

`need_item` / `got_item` use "label: name" so German needs no article (eine Sicherung / einen
Energiekern). The item name comes from `item.<id>.name`. The door counter itself shows only digits
("3 / 5"). The debug overlay (`#if DEBUG`) is not localized.

### 16.8 `rules.json`

Exception to the "one array" rule: global rule numbers, grouped by system. Every block and field
is required in the file; the decoder keeps `RulesDef.fallback` (same values) if the file is missing.

```json
{ "version": 1, "puzzle": Puzzle, "leash": Leash, "minimap": Minimap, "crate": Crate, "toast": Toast,
  "inventory": Inventory, "rescue": Rescue, "pixel": Pixel, "hints": Hints, "lowHp": LowHp }
```

M2 blocks below; the M3 blocks (`inventory`, `rescue`, `pixel`, `hints`, `lowHp`) and the M3
fields of `puzzle` and `minimap` are in §16.9.

| Field | Type | Value | Meaning |
|---|---|---|---|
| `puzzle.leverPullSec` | float | 0.4 | lever pull animation; the lever toggles at the end (§11) |
| `puzzle.plateHoldSec` | float | 1.0 | continuous standing time until a plate latches on; resets when the hero steps off |
| `puzzle.doorPanSec` | float | 1.0 | camera pan to a door when its last element turns on; input locked, a tap skips |
| `puzzle.doorMaxLights` | int | 8 | max lights drawn on a door; more required elements still count in "x / y" |
| `leash.rangeFactor` | float | 2.0 | leash starts when hero distance > `rangeFactor × detectRange` (pt, straight line) |
| `leash.returnAfterSec` | float | 4.0 | time beyond that range before the enemy walks home; at home it heals to full |
| `minimap.revealOnEnter` | bool | true | a room is revealed when the hero's centre enters its rect; a corridor when it is entered |
| `minimap.updateHz` | float | 10 | max minimap pushes per second from the scene |
| `crate.hp` | int | 20 | supply crate HP: 2 starter shots, 1 spread volley (3 × 7), 4 rapid shots. On 0 it poofs and rolls `pickups.crates.lootTableId`. Crates never hurt and never move |
| `toast.showSec` | float | 2.5 | how long a `ui.toast.*` line stays (fade in/out included) |
| `toast.repeatCooldownSec` | float | 3.0 | the same toast key is not shown again inside this time |

INTERACT range is not here: it is `hero.json → hero.interactRadius` (64 pt).

### 16.9 `rules.json` M3 blocks

| Field | Type | Value | Meaning |
|---|---|---|---|
| `puzzle.plateRingFadeSec` | float | 0.1 | plate hold ring fade-in (ART_BIBLE §13.4) |
| `puzzle.doorStaggerSec` | float | 0.04 | door frame start offset per cell, outer cell first (ART_BIBLE §13.2) |
| `puzzle.doorFrameSec` | float | 0.07 | time per door opening frame (4 frames) |
| `minimap.corridorRevealRadius` | int | 3 | corridor cells within this Chebyshev distance of the hero's cell are revealed and stay revealed (ART_BIBLE §13.1) |
| `minimap.heroPulseSec` | float | 1.0 | hero dot pulse period |
| `minimap.exitPulseSec` | float | 1.2 | exit star alpha pulse period |
| `inventory.slots` | int | 25 | bag slots (5 × 5) |
| `inventory.quickSlots` | int | 4 | quick links Q1–Q4 |
| `inventory.useCooldownSec` | float | 0.5 | per item **id**: a second use inside this time is `coolingDown` (§6) |
| `inventory.dropScatter` | float | 24 | pt, max random offset from the hero centre for a dropped stack; a spot inside a wall is moved to the hero centre |
| `rescue.slowMoScale` | float | 0.3 | game speed during step 1 of §12 |
| `rescue.slowMoSec` | float | 0.6 | step 1 length in **real** seconds |
| `rescue.beamSec` | float | 0.8 | teleport beam length (step 2) |
| `rescue.starterMinMagazine` | int | 12 | starter mag + reserve is topped up to at least this (step 5; = one magazine) |
| `pixel.followOffset` | {x, y} | −40, 40 | pt from the hero centre, world axes (up-left, ≈ 56 pt) |
| `pixel.bobAmplitude` | float | 4 | pt |
| `pixel.bobHz` | float | 1.5 | bobs per second |
| `pixel.followLerpSec` | float | 0.15 | follow smoothing time constant |
| `pixel.tapRadius` | float | 80 | pt on screen around Pixel's centre that counts as a tap on Pixel (§13) |
| `pixel.tapMaxSec` | float | 0.25 | a Pixel tap must end within this time |
| `pixel.tapMaxMovePt` | float | 12 | a Pixel tap must move less than this |
| `pixel.bubbleBaseSec` | float | 3.0 | bubble time base |
| `pixel.bubblePerCharSec` | float | 0.04 | + per character of the shown line |
| `pixel.maxChars` | int | 60 | longest allowed line (debug assert, `LocalizationKeyTests`) |
| `pixel.queueMax` | int | 2 | lines waiting; a new line drops the oldest waiting one |
| `pixel.repeatCooldownSec` | float | 10 | the same `pixel.*` key is not queued again inside this time (story exempt) |
| `hints.flySec` | float | 2 | Pixel flies to the target (or until it is 64 pt from it) |
| `hints.arrowSec` | float | 6 | dotted arrow from the hero to the target, then Pixel flies back |
| `hints.cooldownSec` | float | 10 | after a hint ends (arrow gone) before the next tap hint |
| `hints.pointerAfterSec` | float | 60 | level time before minimap pings start |
| `lowHp.threshold` | int | 25 | HP (absolute, max 100): at or below = low HP (heart pulse, line, loot modifier is separate) |
| `lowHp.lineCooldownSec` | float | 60 | low-HP line at most once per this time |

The idle hint time is per level: `levels.json → hintIdleSec` (§16.5). The rescue invulnerability
is `hero.json → respawnInvulnerableSec`.

### 16.10 Save game (`save.json`)

One file in Application Support, written atomically. Saved on level complete, checkpoint touch and
app background. **No mid-level state**: Continue restarts the current level (new layout, same
seed rules) with the saved loadout and bag. Decoder rules: unknown fields are ignored; a missing
optional field takes its default; `version` ≠ 1 or a corrupt file → moved to `save.bak.json`, fresh
start, never a crash.

```json
{
  "version": 1,
  "savedAt": "2026-11-24T10:00:00Z",
  "run": {
    "currentLevelId": "l2",
    "unlockedLevelIndex": 2,
    "loadout": {
      "owned": ["blaster_starter"],
      "equipped": "blaster_starter",
      "magazines": { "blaster_starter": 12 },
      "ammo": { "reserves": { "ammo_starter": 48, "ammo_spread": 12 } }
    },
    "inventory": {
      "slots": [ { "itemId": "healpack", "count": 1 }, { "itemId": "food_apple", "count": 2 }, null ],
      "quick": [ "healpack", "food_apple", null, null ]
    },
    "bestResults": {
      "l1": { "stars": [true, false, true], "bestScore": 2350, "bestTimeSec": 301, "datachips": 2, "fewestRescues": 0 }
    },
    "settings": { "pixelTalk": "lots", "aimAssist": true }
  }
}
```

| Field | Type | Meaning |
|---|---|---|
| `version` | int | 1 |
| `savedAt` | ISO-8601 string | for debug and "last played" |
| `run.currentLevelId` | string | level that Continue starts: the level in progress, or the next one after a level complete. After L5 complete: `l5` (replay) |
| `run.unlockedLevelIndex` | int 1–5 | highest level that can be started (finish N → N + 1) |
| `run.loadout.owned` | [weaponId] | always contains `blaster_starter` |
| `run.loadout.equipped` | weaponId | must be in `owned`, else `blaster_starter` |
| `run.loadout.magazines` | {weaponId: int} | ≤ `magazineSize` |
| `run.loadout.ammo.reserves` | {ammoId: int} | ≤ `reserveMax`; also for blasters not owned yet (§5.1) |
| `run.inventory.slots` | [ItemStack or null] × 25 | `{itemId, count}`, count 1…`stackSize`; unknown item ids are dropped on load; fewer than 25 entries are padded with null (the example is shortened) |
| `run.inventory.quick` | [itemId or null] × 4 | links, not storage; a link to an id with 0 left stays |
| `run.bestResults` | {levelId: Result} | best of each field independently; `stars` = the 3 stars of §15 (OR-merged) |
| `run.settings.pixelTalk` | `lots` / `some` / `quiet` | default `lots` |
| `run.settings.aimAssist` | bool | default `hero.json → controls.aimAssistDefaultOn` (true) |

A mid-level save (checkpoint touch, app background) writes the **current** loadout and bag. A kid
who quits keeps what they found; the level itself restarts. Datachips, score, time and rescues of
an unfinished level are **not** saved. Puzzle items in the bag are removed when a level starts
or ends (they belong to one layout; a kept fuse would skip a puzzle on replay).

Start gift (`pickups.startGift`): on level start, each gift item is topped up to its `count`
(bag count below `count` → add the difference; never more). On replay of L1 with 1 healpack in
the bag, nothing is added.

Music/SFX volume and "mute all" stay in `SettingsStore` (`UserDefaults`, audio run): they are
device preferences and survive "New game". "New game" also keeps `run.settings`.

Every key referenced by a JSON file must exist in `Localizable.xcstrings` with `de` + `en`
(guarded by `LocalizationKeyTests`, M1-11). Item `desc` texts repeat JSON numbers (heal,
ammo, score); change both together.

---

## 17. Asset id list (must match art)

`hero`, `pixel`, `boltbot`, `laserdrone`, `slimemutant`, `slimemutant_small`, `shieldandroid`,
`sporeplant`, `megamech`, `blaster_starter`, `blaster_spread`, `blaster_rapid`, `ammo_starter`,
`ammo_spread`, `ammo_rapid`, `healpack`, `food_apple`, `food_onigiri`, `food_cookie`, `fuse`,
`battery`, `keycard`, `energycore`, `button`, `lever`, `pressureplate`, `machine`, `door`.

Proposed **new** asset ids (need art, see Open questions): `bolt`, `datachip`, `crate`,
`checkpoint`, `exitpad`.

---

## 18. Levels overview

| # | id | Theme | Enemies | Puzzle | New |
|---|---|---|---|---|---|
| 1 | `l1` | City Rooftop Lab (tutorial) | boltbot, laserdrone (late) | 2 buttons + 1 lever | controls, reload, heal |
| 2 | `l2` | Robot Factory | boltbot, laserdrone, shieldandroid | gate: button; exit: 2 levers + fuse machine | spread blaster, machines, gates |
| 3 | `l3` | Gene Lab Greenhouse | slimemutant, sporeplant, boltbot | gate: lever; exit: 2 plates + battery machine + lever | rapid blaster, pressure plates |
| 4 | `l4` | Server Fortress | shieldandroid, laserdrone, boltbot, slimemutant | 2 gates; exit: keycard + fuse + battery machines, 2 buttons, 1 plate | keycard, 3 zones |
| 5 | `l5` | OVERMIND Core | all 5 | gate: 2 levers; exit: 2 energycore machines + plate → boss arena | boss |

Details: `docs/levels/L1.md` … `L5.md`.

---

## 19. Open questions (owner decision needed)

1. **Game title** (working title "Strike"). Proposals:
   1. **Pixel & Me: Robo Rescue**
   2. **Spark Squad**
   3. **Blip Blaster**
   4. **Zap Heroes: Stop OVERMIND!**
   5. **Bubble Bolt**
2. **Hero name** (also needed: gender-neutral design?) – proposals: **Nova**, **Kai**, **Juno**,
   **Mika**, **Robin** (all work in DE + EN).
3. **Pixel name** – proposals: **Pixel** (keep), **Blip**, **Byte**, **Lumi**, **Sparky**.
4. **OVERMIND name** – proposals: **OVERMIND** (keep), **BOSSBYTE**, **Dr. Glitch**,
   **MAX-CONTROL**, **Kommandant Kabel** (DE-friendly pun "Captain Cable").
5. New assets needed: `bolt`, `datachip`, `crate`, `checkpoint`, `exitpad` – OK to add to the art list?
6. Should there be an "Easy" setting (enemy damage × 0.5) for 7-year-olds, or is the rescue rule
   enough?
7. Hero: one fixed character or a choice of 2–3 looks (no gameplay difference)?
8. Left-handed mirrored layout: in Settings only, or asked on first launch?
9. Levels unlock linearly; should replays of finished levels be allowed with a new seed (yes
   assumed)?
10. (M3-1) Hero gender: German lines are now written gender-neutral ("du Winzling", "Wir zwei
    sind das beste Team"). Once the hero name/look is decided, lines may use it.
11. (M3-1) `pixel.l1.button` says "tap the hand": this assumes the `ui_btn_interact` icon shows a
    hand. If it does not, the line becomes "tap the glowing button" (artist to confirm).
12. (M3-1) Datachips "unlock a Pixel fact" (§6): the fact texts are not written yet; they need a
    screen to show them (M5 stars/map screen). OK to postpone to M5?

---

## 20. Change log

| Date | Change | Before → After | Reason |
|---|---|---|---|
| 2026-11-22 | v1.0 initial GDD + data schemas | – | M0-2 |
| 2026-11-22 | §2 tile size | 48 pt → 64 pt | All tile/character art is on a 64 pt grid (DECISIONS, M0 review #1) |
| 2026-11-22 | §2 camera view | ≈ 25 × 17 tiles → ≈ 18.7 × 13 tiles (scale 1.0) | Follows from 64 pt tiles; M2 re-checks room sizes |
| 2026-11-22 | §3 Fire button | implied by HUD art → none; right stick auto-fires | M0 review #2 |
| 2026-11-22 | §3.1 HUD sketch | quick slots top → bottom centre; positions owned by ART_BIBLE §7 | M0 review #7 |
| 2026-11-22 | §3.2 stick visual | "base radius 70" → travel radius 70, visual base 140, knob 64 | M0 review #3 (numbers unchanged, wording clarified) |
| 2026-11-22 | §3.5 hit flash | 0.08 s → 0.1 s | M0 review #8 (art bible value) |
| 2026-11-22 | §5/§6 blaster + ammo colors | starter blue / spread pink / rapid green → orange / purple / yellow | M0 review #4, art is owner-approved |
| 2026-11-22 | §5 blaster display names | – → Light / Bubble / Foam Blaster (DE Licht- / Blasen- / Schaum-Blaster) | Names needed for `weapon.*.name` strings |
| 2026-11-22 | §16.6 new `hero.json` | hero, controls, camera numbers only in GDD text → JSON (values unchanged from §2–§4) | CLAUDE.md: balance never in code (M0 review #5) |
| 2026-11-22 | new fields `hero.respawnInvulnerableSec` (2.0) and `enemies[].alertSec?` (0.4, set on all 7 enemies) | rule text only (§8, §12) → JSON | Coder request: no balance in code (M1-8, M1-9) |
| 2026-11-22 | QA-004 starter safety net `rechargeEverySec` | 1.5 s → 0.5 s | Held fire at 0/0 gave 0.67 shots/s (≈ 4.5 s per boltbot), refill 18 s. Now 2 shots/s (≈ 1.5 s per boltbot), refill 6 s: running dry is a short moment, not a stuck state |
| 2026-11-22 | QA-004 new loot modifier `ammo_rescue` (`equippedAmmoBelowMagazines`, threshold 1.0, `guaranteeCount` 1) | – → 1 guaranteed equipped-ammo pack per powered-down enemy while mag + reserve < 1 magazine | Kids who miss a lot always get ammo back from the next enemy; self-limiting (+24 starter lifts them above 12) |
| 2026-11-22 | QA-004 `loot_boltbot.dropChance` | 0.35 → 0.45 | Expected starter ammo per boltbot 4.2 → 5.4 shots vs 3 hits needed; leaves room for misses |
| 2026-11-22 | §16.7 localization key patterns; xcstrings filled | 6 keys → 6 + 56 = 62 (4 hud, 3 weapon, 7 enemy, 32 item, 10 level) | M0 review #10 |
| 2026-11-22 | M2-1 L1 `corridorWidth` | 3 → 2 | At 64 pt, 3 tiles = 192 pt reads like a thin room and needs 3-cell doors; 2 tiles = 128 pt is still 3.5 × the hero width. All levels now use 2 |
| 2026-11-22 | M2-1 `minElementSpacing` | L1 8 → 7, L2 9 → 8, L3/L4/L5 10 → 8 | 10 tiles (640 pt) made L4 zone 2 (4–5 elements in 4–5 rooms) hard to place; 7–8 tiles (448–512 pt ≈ ½ screen) still keeps elements in different spots. Range 8–12 → 7–8 |
| 2026-11-22 | M2-1 L2 `minRoomSize` | 7 → 8 | Room must fit the 2 × 2 fuse machine + the 3-tile enemy gap; same as L3–L5. L1 (no machines) keeps 7 |
| 2026-11-22 | M2-1 L4 grid | 80 × 60 → 72 × 56 | Fill 37 % → 41 % like L1–L3, shorter corridors; walk ≈ 111 s → 102 s; helps the < 150 ms generation target |
| 2026-11-22 | M2-1 L4 `maxRoomSize` | 15 → 14 | 15 tiles = 960 pt is taller than the whole 834 pt view; 14 is the S1 cap |
| 2026-11-22 | M2-1 L4 `bspMaxDepth` | 5 → 4 | 32 leaves for 12–15 rooms threw away half the rooms; 16 leaves ≥ 15 rooms |
| 2026-11-22 | §14.2 ranges | grid 48–96 × 36–72, rooms 6–18, sizes 6–16, depth 3–5, corridor 2–3, spacing 8–12 → 48–72 × 36–56, 6–15, 7–14, 3–4, 2, 7–8 | Match the S1 data after the 64 pt re-check; new 64 pt check + walking-time tables |
| 2026-11-22 | new `rules.json` (§16.8) | rule text in §8/§11 → JSON: lever 0.4 s, plate 1.0 s, door pan 1.0 s, 8 lights, leash 2.0 × / 4.0 s, minimap reveal on enter / 10 Hz | DECISIONS: no balance in code. `puzzle.interactFocusRadius` from the TASKS draft is left out: `hero.interactRadius` already holds it |
| 2026-11-22 | new `rules.json → toast` | – → `showSec` 2.5, `repeatCooldownSec` 3.0 | M2 toasts need a duration, and tapping a machine without its item must not spam the toast |
| 2026-11-22 | new `rules.json → crate.hp` | – (code fallback 20) → 20 | Coder request (pass B). Breaks fast (2 starter shots) so crates feel like a treat, not a chore |
| 2026-11-22 | new `enemies[].knockbackSec?` | `EnemyNode` code constant 0.1 → JSON 0.1 on all 7 enemies | M1 review leftover 1 (balance in code) |
| 2026-11-22 | §11 M2 notes, §16.7 M2 keys | 62 keys → 79 (+5 hud incl. `hud.minimap.accessibility` on coder request, +6 ui.toast, +6 levelComplete) | M2-1; level name/subtitle keys already existed |
| 2026-11-24 | M3-1 new `rules.json` blocks (§16.9) | constants / GDD text → JSON: `inventory` (25, 4, 0.5 s, scatter 24 pt), `rescue` (0.3 × 0.6 s, beam 0.8 s, starter ≥ 12), `pixel` (offset −40/40, bob 4 pt 1.5 Hz, lerp 0.15 s, tap 80 pt / 0.25 s / 12 pt, bubble 3.0 + 0.04/char, 60 chars, queue 2, repeat 10 s), `hints` (2 / 6 / 10 / 60 s), `lowHp` (25 HP, 60 s) | CLAUDE.md: balance in JSON. Values unchanged from §4/§7/§12/§13; new: `dropScatter` 24 pt (several dropped stacks spread out and stay visible instead of piling on one point), `tapMaxSec`/`tapMaxMovePt` (DECISIONS tap rule), `repeatCooldownSec` 10 s (stops "Yes! One more done!" spam on L4 with 7+ elements) |
| 2026-11-24 | M3-1 `rules.json → minimap.corridorRevealRadius` 3, `heroPulseSec` 1.0, `exitPulseSec` 1.2; `puzzle.plateRingFadeSec` 0.1, `doorStaggerSec` 0.04, `doorFrameSec` 0.07 | code constants → JSON (same values) | M2 leftover 4, ART_BIBLE §13.9 |
| 2026-11-24 | §13 Pixel bubble | above Pixel in the world → HUD top-centre bubble (ART_BIBLE §7) | DECISIONS 2026-11-22: always readable |
| 2026-11-24 | §13 Pixel follow offset | "56 pt behind-left" (relative to facing) → (−40, +40) pt in world axes (≈ 56 pt up-left) | Twin-stick aim turns constantly; a facing-relative buddy would swing around the hero |
| 2026-11-24 | §13 hint with the machine's item already in the bag | no fly + `need_*` (TASKS draft) → fly to the machine + `hint_machine` | "We need a fuse!" while carrying one confuses 7-year-olds |
| 2026-11-24 | §13 new: tap-vs-stick rule, "progress" definition for the idle timer, talk-level filter per key, level beats replace generic lines, repeat guard | – | M3-1 |
| 2026-11-24 | §13 lines | `all_on` "The door is open!" → "The door opens!" (DE "Die Tür geht auf!"); `pixel.tip.shieldandroid` "Hit it from behind!" → "Big shield! Hit it from behind!" | the door opens after the 1 s pan; the tip now says what to look for |
| 2026-11-24 | L4/L5 DE lines | „Geh nach Hause, kleiner Held!" → „…, du Winzling!"; L5 outro 3 "Thank you, hero. You are my best friend!" / „Danke, Held. Du bist mein bester Freund!" → "Thank you! We are the best team ever!" / „Danke! Wir zwei sind das beste Team!" | Hero gender is still open (§19); German "Held/Freund" is male |
| 2026-11-24 | §7 drop + persistence | – → drop scatter 24 pt, no instant re-pickup, puzzle items cleared at level start/end | A kept fuse would skip a puzzle on replay |
| 2026-11-24 | §12 rescue | – → numbers from `rules.json → rescue`, top-up formula, input lock, enemy shots removed at the beam | M3-1 |
| 2026-11-24 | new §16.10 save game | – → `save.json` v1 schema; audio volumes stay in `SettingsStore`; start gift = top up to `count` | DECISIONS 2026-11-22 save basics |
| 2026-11-24 | §16.7 keys, xcstrings | 90 keys → 214 (+56 story/level-beat/boss keys from `levels.json`, +21 `pixel.generic.*`, +6 `pixel.tip.*`, +41 UI: 16 inventory, 5 hud, 5 pause, 6 title, 2 levelIntro, 2 ui.toast, 5 settings) | M3-1; M2 leftover 9 |
