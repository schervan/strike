# Strike – Game Design Document (Season 1 MVP)

Owner: game-designer · Status: v1.1 (M1-1) · Audience: kids 7–12 · iPad landscape · offline · DE + EN

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
direction (`camera.lookAhead`). The camera is clamped to the room/map bounds. M2 room sizes
(§14.2) are in tiles, so rooms read about 1.33 × larger than in v1.0; the generator ranges are
re-checked in M2.

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
| Low-HP warning | ≤ 25 HP: heart pulses, Pixel line (max once per 60 s) |

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
  +1 every 1.5 s up to 12. The hero can never be fully stuck.
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
| Drop | tap item → "Drop" → choose amount (1 / all). Drops at hero's feet, never despawns. Puzzle items can be dropped too (they stay until picked up again) |
| Sort | "Tidy up" button: puzzle → heal → food → ammo, then by id |
| Full | pickup stays on the floor with a bobbing "!" ; toast "Bag full!" (`ui.toast.bag_full`) |
| Persistence | inventory, quick slots and blasters carry over between levels and are saved |
| Rescue | inventory is kept 100 % at a checkpoint rescue |

---

## 8. Enemies

All enemies power down into sparkles + their loot. Common rules:
- **Idle → Alert** when the hero is within `detectRange` and in line of sight; alert shows a "!"
  bubble for 0.4 s before the first attack (fairness).
- **Leash:** an enemy returns to its home room if the hero is > 2 × `detectRange` away for 4 s, and
  heals to full.
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
5. Pickups pop out in a small arc (max 48 pt) and never land inside walls.

| Table | Bolts | dropChance × rolls | Main entries (weight) |
|---|---|---|---|
| `loot_boltbot` | 1–3 | 0.35 × 1 | ammo_starter 50, food_apple 30, ammo_spread 10, ammo_rapid 10 |
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

**Solvability (generator guarantee).** For every element: it is reachable from the start using
only the doors that open before it. For every machine: its required item is placed in the same
zone or an earlier zone and never behind the gate it opens. Verified by simulation (§13.3).

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

---

## 13. Pixel – the drone buddy (`pixel`)

| Behaviour | Rule |
|---|---|
| Follow | floats 56 pt behind-left of the hero, bobbing 4 pt at 1.5 Hz; lerp 0.15 s; passes through walls (it's a hologram drone); never blocks shots or touch |
| Speak | speech bubble above Pixel, 1 line, max 60 chars, 3.0 s (+0.04 s/char). One line at a time, queue max 2, older dropped. Lines come from `pixel.*` keys |
| Hint (tap Pixel or 30 s no progress) | Pixel flies 2 s toward the nearest reachable unactivated required element (or the needed item if a machine is blocked), shows a dotted arrow for 6 s, then returns. Cooldown 10 s |
| Pointer | minimap pings unactivated reachable required elements as blinking dots after 60 s in the level |
| Scan | first time an enemy type is seen: short "scan" beam + tip line (`pixel.tip.<enemyId>`) |
| Rescue | at 0 HP performs the rescue (§12) |
| Combat | Pixel never attacks and can't be hurt |
| Silence | Settings → "Pixel talk: lots / some / quiet". "some" = story + hints only, "quiet" = story only |

Generic triggers (keys in `pixel.generic.*`): level start, first item, bag full, low HP,
first reload, element on, all elements on, door open, checkpoint, rescue, idle 30 s.

| Key | EN | DE |
|---|---|---|
| `pixel.generic.bag_full` | Your bag is full! | Deine Tasche ist voll! |
| `pixel.generic.low_hp` | Ouch! Eat something! | Autsch! Iss etwas! |
| `pixel.generic.reload` | Tap RELOAD for new shots! | Tipp auf NACHLADEN! |
| `pixel.generic.element_on` | Yes! One more done! | Ja! Wieder eins geschafft! |
| `pixel.generic.all_on` | All done! The door is open! | Alles geschafft! Die Tür ist offen! |
| `pixel.generic.checkpoint` | Checkpoint saved! | Checkpoint gespeichert! |
| `pixel.generic.rescue` | Gotcha! I beamed you back. | Hab dich! Ich habe dich zurückgebeamt. |
| `pixel.generic.idle` | Need help? Tap me! | Brauchst du Hilfe? Tipp mich an! |
| `pixel.generic.need_fuse` | We need a fuse! | Wir brauchen eine Sicherung! |
| `pixel.generic.need_battery` | We need a battery! | Wir brauchen eine Batterie! |
| `pixel.generic.need_keycard` | We need a keycard! | Wir brauchen eine Schlüsselkarte! |
| `pixel.generic.need_energycore` | We need an energy core! | Wir brauchen einen Energiekern! |
| `pixel.tip.boltbot` | Boltbots run at you. Zap them! | Boltbots rennen auf dich zu. Zapp sie! |
| `pixel.tip.laserdrone` | Drones glow red, then shoot. Dodge! | Drohnen leuchten rot, dann schießen sie. Ausweichen! |
| `pixel.tip.slimemutant` | Slimes split in two! | Schleime teilen sich in zwei! |
| `pixel.tip.shieldandroid` | Hit it from behind! | Triff ihn von hinten! |
| `pixel.tip.sporeplant` | Don't get too close. It sneezes! | Nicht zu nah. Sie niest! |

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
| `gridWidth`, `gridHeight` | int | map size in tiles | 48–96 × 36–72 |
| `roomCount` | {min,max} | rooms kept | 6–18 |
| `minRoomSize`, `maxRoomSize` | int | room side length in tiles | 6–16 |
| `bspMaxDepth` | int | BSP depth | 3–5 |
| `corridorWidth` | int | tiles | 2–3 |
| `loopChance` | 0…1 | extra corridors | 0.1–0.35 |
| `zones` | int | zones on critical path | 1–3 |
| `enemyDensity` | float | threat multiplier | 0.6–1.6 |
| `maxThreatPerRoom` | int | cap | 3–10 |
| `minElementSpacing` | int | tiles | 8–12 |
| `decorDensity` | 0…1 | prop chance per free floor tile | 0.03–0.08 |
| `maxAttempts` | int | regenerate tries | 50 |

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

All files: UTF-8 JSON, root object with `"version": 1` and one array (exception: `hero.json`,
§16.6). Unknown fields must be
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
| `modifiers[].id` | string | `low_hp` / `low_ammo` / `unowned_weapon_ammo` |
| `modifiers[].condition` | string | `heroHpRatioBelow` / `equippedAmmoRatioBelow` / `weaponNotOwned` |
| `modifiers[].threshold?` | float | ratio for the condition |
| `modifiers[].appliesTo` | string | `category:heal,food` / `equippedAmmo` / `unownedAmmo` |
| `modifiers[].weightMultiplier` | float | |

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
| `starterSafetyNet` | {rechargeEverySec, rechargeTo} | 1.5, 12 | starter only: when mag + reserve = 0, reserve +1 every `rechargeEverySec` up to `rechargeTo` (§5.1) |

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
| `pixel.*`, `story.*`, `ui.*` | added when their milestone needs them (M2+) |

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
| 2026-11-22 | §16.7 localization key patterns; xcstrings filled | 6 keys → 6 + 56 = 62 (4 hud, 3 weapon, 7 enemy, 32 item, 10 level) | M0 review #10 |
