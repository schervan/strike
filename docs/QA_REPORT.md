# QA Report

## M0 - Project skeleton and data (2026-11-22)

### Commands
```
~/.local/opt/xcodegen-dl/xcodegen/bin/xcodegen generate
xcodebuild -project Strike.xcodeproj -scheme Strike \
  -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M5),OS=latest' \
  -derivedDataPath build/DerivedData test
```

### Results: TEST SUCCEEDED
- Swift Testing (StrikeTests): 8 tests in 2 suites, 8 passed, 0 failed (the 6-case texture test counts as one test).
  - StrikeSmokeTests (3): model switching, placeholder scene, de/en localizations.
  - DataIntegrityTests (5, new, `StrikeTests/DataIntegrityTests.swift`): all 5 JSON files parse (JSONSerialization) and carry `version`; cross-references resolve (weapon `ammoId` -> items, enemy `lootTableId` -> loot tables, loot `itemId` -> items, levels `itemId` / `enemyId` / `lootTableId`, 5 levels present); 6 sample textures load with non-zero size; all 9 atlases non-empty; bundle localizations contain de and en.
- XCUITest (StrikeUITests): 1 test, 0 failures.

### Kid-safety grep over Strike/
- Network/analytics/ads/IAP/web (`URLSession`, `import Network`, `NWConnection`, Firebase, Analytics, AdSupport, StoreKit, WKWebView, openURL, SafariServices) in Swift sources: 0 occurrences.
- Whole words blood, kill, die, dead, death, gore, gun in Localizable.xcstrings and Data/*.json: 0 occurrences. ("weapon" appears only as item category and nameKey prefix; blaster naming is fine.)
- Not yet covered: art content review, touch-target sizes, parental gate (no UI exists yet).

### Findings (non-blocking)
- QA-001 (low, info): Atlases ship only `@2x` PNGs. `SKTextureAtlas.textureNames` reports names with the `@2x.png` suffix, while `textureNamed("hero_idle_01")` still resolves with non-zero size. Code should look textures up by the plain name; tests accept both forms. Suspected: art pipeline in `Strike/Resources/Atlases/`.
- QA-002 (info): Localization test only checks bundle localizations (de, en). A per-key de/en completeness test is deferred until the string catalog has real UI keys (M1+).

### Open bugs
None.

## M1 - Core loop (2026-11-22, branch m1-core-loop @ 6ba8d42 + uncommitted QA tests)

### Commands
```
~/.local/opt/xcodegen-dl/xcodegen/bin/xcodegen generate
xcodebuild -project Strike.xcodeproj -scheme Strike \
  -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M5),OS=latest' \
  -derivedDataPath build/DerivedData test
```

### Results: TEST SUCCEEDED
- Baseline before QA additions: 54 Swift Testing tests + 2 XCUITests, all green.
- After M1-11: 64 Swift Testing tests in 12 suites, all passed; 3 XCUITests, 0 failures (174 s, mostly the play pass).
- New in StrikeTests: `LocalizationKeyTests.swift` (every `*Key` in all 6 JSON files plus all hud/level/title/game keys exist and are non-empty in compiled de and en tables; de and en key sets identical; no violent wording in either language), `RobustnessTests.swift` (unknown/nested unknown fields decode, each missing required field throws a DecodingError, garbage input throws, missing bundle file gives `GameDataError`, duplicate ids reported, ProjectilePool stress: 20,000 random spawn/recycle ops incl. double recycle, capacity never exceeded, scene graph empty afterwards).
- New in StrikeUITests: `StrikePlayPassUITests.swift` (uses `-StrikeAutoStart`, drags on both halves, reads HUD values, saves screenshots).

### Play pass on iPad Pro 11-inch (M5) simulator
Real output from the run (hero starts 12 / 48, HP 100):
- Firing: aim drag in right zone, ammo 12 -> 4 (6 / 48 mid-hold in the probe). Shots, muzzle flash and the floating aim stick are visible (qa screenshots).
- Hero faces the aim direction (sprite turned right when aiming right).
- Manual reload: 4 / 48 -> 12 / 40. The reload button turns blue while reloading. Auto reload on empty magazine also happens (12 / 28 after 0).
- Enemies: boltbots stand idle until near, then chase; HP fell 100 -> 68 -> 36 -> 4 from contact damage (8 per touch, x4 per tick pairs as seen).
- Boltbots take hits and power down: 3 at start, 2 then 1 on screen later; ammo rose from 0/0 to 1/1, 1/2 (loot pickups collected).
- Respawn: HP 4 -> 100 observed twice (checkpoint rescue works) with the hero back at full HP.
- Node count stable: nodes 309 at start, 320 during firing, 305 after about 3 minutes of play. FPS 51-60 on the simulator (showsFPS).
- Screenshots (raw device orientation is portrait, rotate 270 to read): `/private/tmp/claude-503/-Users-flyingbull-Developer-Strike/8a9e170c-024e-4dbc-b225-45e9eb286ba8/scratchpad/qa_r_1_start.png`, `qa_probe_r_aimhold.png`, `qa_r_4_fight.png`, `qa_r_6_idle.png`.
- Not observed visually (fast, no mid-gesture screenshots): the alert exclamation and the sparkles of a power-down. Hit/poof particles exist in code; confirm by eye on device.

### Kid-safety pass
- No networking/analytics/ads/IAP/web symbols anywhere in Strike/ Swift code: 0 hits.
- No blood, kill, die, dead, death, gore, gun, splat, destroy, explode wording in Swift code, JSON or Localizable (hits are only "dead zone" identifiers). Particles code states no red tints. Weapon names: Light/Bubble/Foam Blaster (de: Licht-/Blasen-/Schaum-Blaster), nothing realistic.
- Touch targets: reload 72 pt, pause 64 pt (both >= 60). No external links, so no parental gate needed yet.

### Open bugs / findings
- QA-003 (medium, harness note, not a game bug): with the simulator in its default orientation, XCUITest touches are injected rotated 90 degrees from the landscape-only app (a rightward drag moved the hero up; aim drag did nothing). Fix is `XCUIDevice.shared.orientation = .landscapeLeft` before launch, now used in the play-pass test. The existing `StrikeCoreLoopUITests` does not set it, so its drag step is a no-op; swift-coder or QA should add the line there (QA will do it). Worth checking on a real iPad that touches are correct (expected, as this is a simulator quirk).
- QA-004 (medium, balance/design): ammo starvation. Steady firing drove ammo to 0 / 0 within about 25 s with enemies still alive; recovery depends on random boltbot ammo drops (dropChance 0.35, entries weighted) so the hero can be unable to damage anything. Expected: some guaranteed way to get ammo (or a never-empty fallback) in the test room. Actual: 0 / 0 for several rounds in the run. Suspected: `Strike/Resources/Data/loot.json` (loot_boltbot dropChance, ammo weights), `Strike/Game/Systems/LootRoller.swift`. Owner: game-designer/swift-coder.
- QA-005 (low): gameplay is rendered under the HUD; in the shots the hero and a boltbot sit behind the heart/ammo capsule at the top-left, and the room edge is tight against the HUD. Expected: camera clamps so the hero never hides under HUD. Suspected: `Strike/Game/Systems/CameraController.swift` (camera bounds vs HUD band).
- QA-006 (info): the localization test reads compiled `Localizable.strings` from the app bundle, so it validates the catalog after build, not the xcstrings source.
- Earlier QA-001 / QA-002 still apply (QA-002 is now covered by `LocalizationKeyTests`).

### M1-11 verdict
Automated suite green (64 + 3). Manual pass of the M1 goal sentence completed (move, aim, fire, ammo, reload, chase, hits, power down, loot, contact damage, respawn). No blocker; QA-004 and QA-005 filed for review.

## M2 - Levels (2026-11-22, branch m2-levels, pass B committed; QA tests uncommitted)

### Commands
```
~/.local/opt/xcodegen-dl/xcodegen/bin/xcodegen generate
xcodebuild -project Strike.xcodeproj -scheme Strike \
  -destination 'platform=iOS Simulator,id=<dedicated QA iPad Pro 11-inch (M5), iOS 26.5>' \
  -derivedDataPath build/DerivedDataQA test
```
Note: another agent was running `xcodebuild test` on the shared simulator and derived data at the same time, which killed my runs ("Test crashed with signal kill before establishing connection"). A dedicated simulator device and derived-data folder fixed it. Recommend every agent runs tests in its own derived-data path and simulator.

### Results: TEST SUCCEEDED
- Baseline before QA additions: 130 Swift Testing tests, all passed (StrikeTests only).
- After M2-7, full run (unit + UI): 138 Swift Testing tests in 25 suites passed; 9 XCTest cases, 0 failures (UI play passes included).
- New tests:
  - `StrikeTests/GeneratorFuzzTests.swift`: 2,000 seeds x 5 levels = 10,000 generated levels, checked with QA's own model (it does not call `SolvabilityChecker`). Per seed it checks: hero start, pad, elements, items, enemies, pickups, crates, checkpoints, door cells all on floor; no two placements share a cell, none in a door cell; flood-fill from the hero with all doors closed, then a fixpoint of "interact with everything reachable (machines consume their item), open doors whose elements are all on"; every required element activates, every gate and the exit open, in order; every machine item is fetchable before its machine needs it; exit pad sealed while the exit is closed and reachable afterwards; every enemy, pickup and checkpoint reachable at the end; the whole floor is one connected component. A mutant self-test (`checkerCatchesBrokenLevels`: pad on wall, element in wall, item sealed in the exit niche, exit waiting for a missing element, enemy on element) proves the checker fails when it should.
  - `StrikeTests/ScenePlaythroughTests.swift`: a scripted player walks a real `GameScene` for each of the 5 levels on 3 seeds (15 runs): BFS over the scene's live solid grid (closed doors block), picks up puzzle items, INTERACT on buttons/levers/machines, stands on plates, waits out door pans, touches checkpoints, takes real boltbot contact damage at 1 HP and is rescued at the last checkpoint, then reaches the exit pad; asserts gates open in zone order, `GameModel.screen == .levelComplete`. No debug commands.
  - `StrikeTests/VisualCheckTests.swift`: renders the alert "!", the chase, power-down, a gate before/after and button focus from a real scene into PNGs.
  - `StrikeUITests/StrikeM2PassUITests.swift`: launch args `-StrikeLevel/-StrikeSeed`, L1 and L3 flow, L4 FPS.

### Fuzz results (real output, iPad simulator, Debug build)
| Level | Seeds | Failing seeds | Fallbacks used | Max attempts | Time per seed |
|---|---|---|---|---|---|
| l1 | 2000 | 0 | 0 | 4 | 8.6 ms |
| l2 | 2000 | 0 | 0 | 3 | 15.0 ms |
| l3 | 2000 | 0 | 0 | 3 | 17.5 ms |
| l4 | 2000 | 0 | 0 | 5 | 28.2 ms |
| l5 | 2000 | 0 | 0 | 3 | 21.9 ms |
Fuzz seed count: `GeneratorFuzzTests` is `.serialized` and defaults to 400 seeds per level (36 s). The full 2,000 seeds per level (the table above, 203 s) run with `TEST_RUNNER_FUZZ_SEEDS=2000` on a dedicated simulator and derived-data path. A 2,000-seed run on the shared simulator was killed by the test host (cause unconfirmed).

Generation including retries stays under 30 ms per level on the simulator, so no loading hitch.

### Scripted playthrough (15 runs, all completed)
Rooms 8-15, 0-2 gates; the script found and used every element, picked up fuse, battery, keycard and energycore as needed, crossed every gate, touched the gate checkpoints (L4 ended on `checkpoint_gate_3`), was rescued at that checkpoint after contact damage (rescue counter and position verified), reached the pad and got the Level complete result. Minimap rooms revealed at the end ranged from 5/8 to 14/14 depending on the route (rooms off the path stay hidden, as designed). Time 18 s (L1) to 106 s (L4) of simulated play.

### Manual simulator pass (screenshots in scratchpad, rotate 270 to read the raw ones)
- L1 seed 11 and L3 seed 3333 via launch args: real drag moved the hero; INTERACT button on screen; MAP shows the minimap with rooms, hero dot, checkpoint diamond, element dots and exit star; ALL ON then EXIT shows the Level complete card (L3: "Gene Lab Greenhouse", Time, Score, Data Chips 0 / 3); Continue leads to L2 resp. L4 (debug label confirms). Files: `qa_m2r_l1_*.png`, `qa_m2r_l3_*.png`.
- Honest scope note: in the simulator pass, the puzzle shortcut used the debug buttons (ALL ON / EXIT); the "find and use each element, cross gate, die and respawn" path was verified by the scripted scene playthrough above, not by finger drags (a blind finger walk cannot read the hero position). The leash (boltbot returning home) was not exercised in either pass; it is covered only by `LeashTests`/`PathfinderTests`.
- Door visuals from a real scene render: closed gate with red lights, button focus ring, button turns green, counter "1 / 1", gate lights turn green and the panels slide open (`qa_m2_gate_closed.png`, `qa_m2_button_on.png`, `qa_m2_gate_open.png`). The door pan itself (camera) is exercised by the playthrough (3.5 s settle per activation) but not captured as a screenshot.
- M1 leftovers checked by eye: the alert "!" is shown above a boltbot in range (yellow with dark outline, readable) and the boltbot then chases (`qa_m2_alert.png`, `qa_m2_chase.png`). Power-down: a white ring and a few sparkles, then the robot is gone within about 0.4 s (`qa_m2_powerdown_a.png`, `_b.png`). Works, but see QA-009.
- L4 node count and FPS (seed 77, start room and firing): 194 nodes, 59 fps; L1 map view 81 nodes, 57 fps (`qa_m2r_l4_fight.png`). Simulator numbers, an empty room; a crowded L4 room on real hardware is still to be measured.

### Kid-safety pass (new strings and code)
- 0 hits for network/analytics/ads/IAP/web symbols in Swift sources. 0 violent words in either language across all strings (`LocalizationKeyTests`, now 138 tests overall). New strings read: "Use", "Checkpoint saved!", "A gate is open!", "The exit is open!", "This needs: %@", "Your bag is full!", "Level complete!"; de equivalents are natural and complete (en and de key sets identical, all `*Key` in JSON resolve).
- Touch targets: INTERACT (>= 60 pt, checked), Continue (>= 60 pt, checked), reload 72, pause 64. The DEBUG overlay buttons (44 pt, gray) are compiled out of release.

### Open bugs / findings
- QA-007 (low, feel): for the 2 x 2 machine no tile-centre position is inside INTERACT range (hero centre must be within 96 pt of the machine centre while the solid machine edge keeps it at least ~84 pt away), so the player has to press right against the machine and be roughly centred. Steps: L4 or L2, walk beside a machine from a diagonal. Expected: focus from anywhere along its edge. Actual: no focus at the corner side (distance 101 pt minus pad 32 = 69 > 64). Suspected: `GameScene.updateFocus` / `hero.json interactRadius` (64); suggest measuring to the machine rectangle instead of its centre.
- QA-008 (info): the drawn exit pad (`LevelBuilder.exitPadCenter`, centre of the niche's far row) is 32 pt away from the logical `GeneratedLevel.exitPad` cell in every generated level. Nothing breaks (the scene uses the node), but anything that later uses `level.exitPad` (hints, Pixel, tests) will be half a tile off. Suspected: `LevelGenerator` niche pad vs `LevelBuilder.exitPadCenter`.
- QA-009 (low, visual): the power-down effect is subtle on the busy L1 floor (thin white ring plus a few small dots, gone in about 0.4 s). Readable but not very "rewarding" for ages 7-12. Suspected: `Strike/Game/Components/Particles.swift` (`poof`).
- QA-010 (info, debug only): the DEBUG overlay sits at the bottom centre of the playfield and covers floor; it is compiled out of release.
- QA-005 (camera under HUD) was not reproduced in the M2 screenshots; the hero stayed clear of the HUD capsule (hudBand clamp). Considered fixed.
- QA-004 (ammo starvation) not re-tested in M2.
- QA-003 still applies: UI tests need `XCUIDevice.shared.orientation = .landscapeLeft`; a real-iPad touch check is still pending.

### M2-7 verdict
Green: fuzz 10,000/10,000 seeds clean, 15/15 scripted playthroughs complete, full suite green. No blockers; QA-007 and QA-009 are suggestions for M2-8.

### M2-7 re-verification after coder fixes (2026-11-22, dedicated simulator, `build/DerivedDataQA`)
- Full suite, default fuzz (400 seeds per level): 140 Swift Testing tests in 26 suites passed; 9 XCTest cases, 0 failures; `StrikeM2PassUITests` both cases passed (L1/L3 flow to Level complete and Continue, L4 run). TEST SUCCEEDED.
- New `StrikeTests/FixVerificationTests.swift` (2 tests, 20 cases total counting arguments):
  - QA-007 FIXED: in L2, L4 and L5 the hero stands on every walkable cell orthogonally beside each 2 x 2 machine (cell centres, no nudging); the machine is focused every time (8, 24 and 16 side cells). Before, no tile-centre position was in range.
  - QA-008 trigger FIXED: with all elements on, standing on the logical `exitPad` cell or on the drawn pad completes the level in all 5 levels x 3 seeds. The 32 pt offset between the logical cell and the drawn pad still exists in every level (visible in the scripted playthrough log), but it no longer breaks anything; it stays as an info note for Pixel/hint code that might use `level.exitPad`.
- QA-009 (subtle power-down) stays open for M3 (QA-009 in this report is the power-down effect; the machine-focus item was filed as QA-007 and is the one coder-m2 called QA-009).
- Fuzz default: `GeneratorFuzzTests` is `.serialized`, 400 seeds per level (about 36 s); full 2,000 per level with `TEST_RUNNER_FUZZ_SEEDS=2000` (203 s on the dedicated setup).


## M3 - Systems (2026-11-24, branch m3-systems, pass B committed; QA tests uncommitted)

### Commands
Dedicated simulator "QA iPad" (iPad Pro 11-inch M5, iOS 26.5) and `-derivedDataPath build/DerivedDataQA`, as CLAUDE.md now requires for parallel agents:
```
xcodebuild -project Strike.xcodeproj -scheme Strike -destination 'platform=iOS Simulator,id=<QA iPad>' -derivedDataPath build/DerivedDataQA test
```

### Results: TEST SUCCEEDED
- Unit suite (StrikeTests): 235 Swift Testing tests passed at the start of M3-7; after QA additions 243 tests in 43 suites passed, 0 failed, no warnings in the test targets.
- Full suite including UI: 16 XCTest cases (UI tests), 0 failures (about 7 minutes; the old play pass alone is 146 s). One run was red for a moment: my `withKnownIssue` for QA-010 failed with "Known issue was not recorded" because coder-m3 fixed QA-010 in the meantime; I turned it into a normal assertion and re-ran green.
- New or changed tests:
  - `InventoryFuzzTests.swift`: 10,000 seeded random sequences x 60 actions (600,000 actions) + 200 long sequences x 400 actions against `Inventory` + `ItemUse`. Actions: add (incl. 130-item overflow, bolts/blasters/unknown ids), addAll, remove, drop (bad slots), assignQuick (bad index, nil), tidy, use via quick slot and slot (cooldown, full HP, ammo packs), hurt, and JSON round trip + `bind`. Invariants after every action: 25 slots, never more than 25 used, every stack within 1...stackSize, only bag-storable known ids, quick links valid and unique, item totals equal a ledger (added - used - dropped, so nothing duplicated or lost), HP and ammo reserve inside bounds, tidy conserves totals and leaves no gaps and at most one partial stack per id, round trip keeps the exact layout. Result: 0 violations.
  - `LocalizationKeyTests.swift` extended (7 tests now): every key in `levels.json -> story` (intro, outro, beats), generic Pixel lines (derived from items and enemies), boss keys exist in de and en; all pixel/story/boss lines fit `rules.pixel.maxChars` (60) in both languages (longest: 53 en, 52 de); every key-looking string literal in the Swift sources exists in the catalog (scans the source tree; ignores UserDefaults keys, SF Symbols and `id:` identifiers); banned-word list stays split per language.
  - `M3ScenarioTests.swift`: leash and rescue on a real `GameScene` (details below).
  - `StrikeUITests/StrikeM3PassUITests.swift`: save/relaunch/Continue with quick slots and Pixel hint, German screens, L4 crowd.
  - Main-actor warnings: fixed in `StrikePlayPassUITests` and `StrikeM2PassUITests` (helpers are `@MainActor`, the second-thread screenshot is gone), and in `StrikeInventoryUITests`, `StrikeSettingsUITests`, `StrikeLevelScreenshotUITests`. A full test-target build shows no warnings. The remaining build notice is a project-level warning about `UIRequiresFullScreen` and orientations ("will soon be ignored / all orientations required"), see QA-013.

### Manual checks (real output)
- Leash (leftover 5): L1 seed 11 and L3 seed 222; a boltbot is lured with the hero 200 pt away, hurt to half HP, then the hero is placed 45+ path steps away (outside the 2 x detectRange leash). It walks home after the 4 s out-of-range timer (6.8 s and 6.3 s total including the walk), arrives 27 pt from its spawn, HP back to 30/30 (was 15), state Idle. Enemy movement was integrated by hand, because SpriteKit physics only runs in a live render loop; no finger run was done.
- Rescue: L1, L2 and L4 (L2 and L4 touched the gate checkpoint first, the bag was filled from floor pickups). `damageHero(1000)` starts the sequence, the beam node appears, it takes 1.40 s, the hero lands on `checkpoint_start`, `checkpoint_gate_2` or `checkpoint_gate_3` (192 to 1950 pt away), HP 100/100, rescues + 1, last checkpoint unchanged, bag identical (stacks and quick links), blasters and other ammo kept, hero alpha and scale back to 1, every living enemy back at full HP and either walking home or idle. In the simulator the DMG button path (4 x DMG to 0 HP) was already covered by coder's `StrikeInventoryUITests` (passes).
- Save (simulator, real app kill): L1 seed 5, New game; Q1 heal pack 1, Q2 apples 2; DMG, apple heals (70 to 80 HP), Q2 shows 1, heal pack used (Q1 0); Level complete via ALL ON and EXIT; app terminated on the card; relaunch (no `-StrikeFreshSave`): Continue exists, resumes at "l2 · seed ..." with Q1 0 and Q2 1 (items kept). Screens: `qa_m3_en_complete.png`, `qa_m3_en_title_continue.png`, `qa_m3_en_l2_resumed.png`.
- Quick slots: all four slots are at least 60 pt wide; empty slots show a dashed "+" frame, the used heal pack is greyed (`qa_m3r_en_quick_used.png`).
- Pixel tap hint: tapping Pixel shows "This way! Follow my arrow." in the top bubble, draws the dotted arrow toward the target and pings the minimap (`qa_m3r_en_pixel_tap_hint.png`). Pixel idles up-left of the hero as designed; the low-HP line "Ouch! Eat something!" appears in the crowd fight.
- German screens (`qa_m3r_de_intro.png`, `de_hud_pixel`, `de_inventory`, `de_pause`, `de_complete`): intro card text, "Tasche", "Heilpaket / Du hast 1 / Gibt dir 50 Leben.", "Benutzen / In Schnellplatz / Ablegen" and the pause menu fit without clipping. The "In Schnellplatz" label is set smaller than its neighbours (see QA-014).
- Crowd (L4 seed 7, 12 boltbots + crates via CROWD, 8 s of fire; simulator): 271 nodes, 60 fps in the fight, 139 nodes at 60 fps in the idle hint shot, 88 nodes at start. Real device number is still an owner question.

### Kid-safety pass (all new text)
- No violent or scary wording in 214+ strings (per-language banned lists, test green). I read all 48 story/boss/Pixel lines in English: tone is playful ("Eww, it is so sticky", "OVERMIND is very angry now", "Slimes split in two", "The monsters are just sleepy now"), the outro ends on a gentle cliffhanger beep. No network, analytics, ads or web code in the new files (the sources scan and the earlier greps stay clean).
- Touch targets: quick slots 60 pt or more, inventory Drop 64 pt or more (coder's UI test), inventory/Pause/Continue buttons large.

### Open bugs / findings (IDs continue from QA-009)
- QA-010 FIXED (low): `Inventory.bind` re-packed the bag after save/load, closing gaps and merging partial stacks. Found by the first fuzz run (6,472 of 10,000 sequences changed layout); coder-m3 fixed it (each stack keeps its slot); the fuzz now checks the exact layout and passes 10,000/10,000.
- QA-011 (low, latent for M4): `StoryDirector` asks for `pixel.tip.<enemyId>` on the first sight of any enemy, but there is no `pixel.tip.megamech`. When the boss is seen, the raw key could appear in Pixel's bubble. Suspected: `Strike/Game/Pixel/StoryDirector.swift:124`; add the string or skip the tip for the boss. The new test excludes megamech on purpose.
- QA-012 (info, M4 content): L2 beats `pixel.l2.spread` / `pixel.l2.swap` ("Tap SWAP to change blasters") and `pixel.l3.rapid` fire on `firstPickup:blaster_*`. The SWAP button does not exist before M4; if a blaster pickup appears earlier the line points at a missing button. Suspected: `levels.json` beats.
- QA-013 (low, project): the UI test runs print "Update the Info.plist: UIRequiresFullScreen will soon be ignored; support for all orientations will soon be required" (`project.yml` landscape-only with `UIRequiresFullScreen`). Needs an owner decision before submission to the App Store.
- QA-014 (low, polish): in German, the inventory button "In Schnellplatz" is set noticeably smaller than "Benutzen" and "Ablegen" to fit one line. Suggest a shorter label ("Schnellplatz") or two lines. Suspected: `Strike/UI/ItemInfoPanel.swift`.
- QA-015 (info, visual): on L4 the world-space arcade machine can sit under the reload and interact buttons (`qa_m3r_crowd_fight.png`), which is just map position under a HUD button, no function lost.
- Ignored as instructed: duplicate bag count badge on the quick slot (visible at the bottom of the intro screens), rescue beam look, one Pixel line.
- QA-004 (ammo starvation) not re-tested in M3. QA-009 (power-down effect subtle) and QA-003 (real-iPad touch check) remain open.

### M3-7 verdict
Green: 243/243 unit tests, 16/16 UI cases, inventory fuzz 10,000/10,000 clean, leash, rescue, save/Continue, quick slots and Pixel hint verified, de and en lines fit. No blockers; QA-011 and QA-012 should be handled before M4 content lands.
