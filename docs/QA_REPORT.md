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
