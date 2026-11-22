# Tasks

## M0 Setup
- [x] M0-1 Create agents, CLAUDE.md, git, docs skeleton (main session)
- [x] M0-2 game-designer: write `docs/GDD.md` incl. data schemas + `docs/levels/L1–L5.md`
- [x] M0-3 visual-artist: write `docs/ART_BIBLE.md` + placeholder generator
- [x] M0-4 swift-coder: `project.yml`, empty SwiftUI+SpriteView app, landscape, builds on simulator
- [x] M0-5 qa-tester: test targets run (smoke test green), logged in `docs/QA_REPORT.md` (M0: 8 + 1 green)
- [x] M0-6 game-manager: review M0, plan M1 tasks (2026-11-22)

### M0 review (2026-11-22)
Resolved inconsistencies (decisions in `DECISIONS.md`, owners update their docs in M1-1 / M1-2):
1. **Tile size**: GDD §2 says 48 pt, ART_BIBLE §4 and all tile art say 64 pt. → **64 pt** wins.
2. **Fire control**: GDD §3 = right aim stick with auto-fire; ART_BIBLE §7 has a 96 pt Fire button. → **auto-fire stick, no Fire button** (`ui_btn_fire` stays in the atlas, unused).
3. **Stick geometry**: GDD 45 % zones / radius 70 / targets ≥ 64; ART_BIBLE 40 % / base 160 / travel 56 / targets ≥ 60. → **GDD numbers** (zones 45 %, below top 15 %, travel radius 70, visual base 140, knob 64, targets ≥ 64), stored in `hero.json → controls`.
4. **Blaster colors**: GDD says starter blue / spread pink / rapid green; art is starter orange / spread purple / rapid yellow. → **art wins**, GDD §5 text updated.
5. **Hero stats + control tuning are not in any JSON** (CLAUDE.md: balance never in code). → new `Strike/Resources/Data/hero.json` (M1-1).
6. **Lite set**: every anim frame in the atlases is a byte-identical copy of `_01` (verified by md5). → PoseAnimator uses the `<prefix>_idle_01` key pose + procedural motion; frame playback stays behind a flag that is off in MVP.
7. **HUD layout**: GDD §3.1 sketch (quick slots top) vs ART_BIBLE §7 (quick slots bottom center). → ART_BIBLE wins for **positions**, GDD wins for **rules** (relevant in M3).
8. **Hit flash**: GDD 0.08 s vs ART_BIBLE 0.1 s → 0.1 s (art bible), it is a feel constant, may live in code (`PoseStyle`).
9. Boltbot collision radius: JSON 16 pt vs ART_BIBLE "≈40 % of width" (22 pt) → **JSON wins** (as GDD header says).
10. `Localizable.xcstrings` has only 6 keys; the `nameKey`/`descKey` values used in JSON are missing → added in M1-1, guarded by a test in M1-11.
11. `StrikeSmokeTests.gameSceneShowsPlaceholderLabel` will break once the scene has a real room → updated in M1-10.
12. ART_BIBLE §1/§3 still mention `fx_poof`/`fx_sparkles` frame FX; DECISIONS says hit/poof FX are particles → particles win; artist cleans the text in M1-2 (particles may use a `fx_sparkles_01` texture).

## Art (Gemini lite set)
- [x] ART-1 visual-artist: manifest LITE + SHEETS, 5 new assets (bolt, datachip, crate, checkpoint, exitpad) with placeholders
- [x] ART-2 visual-artist: `art/prompts/gemini/PROMPTS.md` (~35 copy-paste prompts) + Artifact page with copy buttons
- [x] ART-3 visual-artist: Gemini-proof slicer (auto background, despill, watermark removal, blob split, seamless tiles, app icon) + `tools/test_slice.py`
- [x] ART-4 Claude: generate images via Gemini API (`tools/gen_art.py`); owner picked hero v1 (43 calls)
- [x] ART-5 sliced all 35 sheets; regenerated #14, #35
- [ ] ART-6 visual-artist: make slicer derive `ui_icon_blaster_*` from `pickup_blaster_*` (currently copied by hand; re-slicing `ui_icons_b` would bring back gun-like icons). Optional: polish `proj_starter` green fringe, Pixel glow tint

## M1 Core loop

Goal: on the simulator, tap Start → a single walled test room (L1 tiles) → hero moves with the left stick, aims + auto-fires with the right stick, reloads, 3 boltbots chase, take damage, power down in sparkles and drop loot; HUD shows HP and ammo. All numbers from JSON.

Order: M1-1 and M1-2 run in parallel (short, doc/data only). M1-3 … M1-10 are **one swift-coder pass**, in this order. Then M1-11 (QA), then M1-12 (review).

### M1 module map (binding for M1-3 … M1-10)
Existing folders are used; one main type per file. Pure logic (no SpriteKit) is `struct`/`enum`, `Sendable`, nonisolated, and unit-tested. SpriteKit types are `@MainActor`.

| File | Type(s) | Role |
|---|---|---|
| `Strike/Data/WeaponDef.swift` | `WeaponDef`, `WeaponsFile` | Codable, all §16.1 fields |
| `Strike/Data/EnemyDef.swift` | `EnemyDef`, `EnemyAttackDef`, `EnemiesFile` | common §16.2 fields + `attack?` + `hop*?` + `separation?`. Other behaviour blocks (`phases`, `shield`, `splitInto`, `keepDistance`, …) are **not** modelled in M1 (ignored by Codable; M4) |
| `Strike/Data/ItemDef.swift` | `ItemDef`, `ItemCategory`, `ItemsFile` | all §16.3 fields |
| `Strike/Data/LootDef.swift` | `LootTable`, `LootEntry`, `LootGuaranteed`, `LootModifier`, `LootFile` | all §16.4 fields |
| `Strike/Data/HeroDef.swift` | `HeroDef`, `ControlsDef`, `CameraDef`, `HeroFile` | `hero.json` (M1-1) |
| `Strike/Data/GameData.swift` | `struct GameData: Sendable` with `weapons/enemies/items/lootTables: [String: …]`, `hero: HeroDef`; `static func load(bundle: Bundle = .main) throws -> GameData`; `func validate() -> [String]` (unresolved id refs); `enum GameDataError: Error` | loads `<bundle>/Data/*.json` (folder reference). `levels.json` is not decoded in M1 (M2) |
| `Strike/Game/Systems/WeaponState.swift` | `struct WeaponState` | mag, reserve, fire cooldown, reload timer, auto-reload, starter safety net. API: `init(def:magazine:reserve:)`, `mutating tick(dt:)`, `mutating tryFire(triggerHeld:) -> Bool`, `mutating startReload() -> Bool`, `mutating cancelReload()`, `mutating addReserve(_:) -> Int` (returns overflow), `isReloading`, `reloadProgress` (0…1) |
| `Strike/Game/Systems/Health.swift` | `struct Health`, `enum DamageResult { ignored, hit, depleted }` | `applyDamage(_:)` honours invulnerability window, `heal(_:)` caps at max, `tick(dt:)`, `isInvulnerable` |
| `Strike/Game/Systems/AimAssist.swift` | `enum AimAssist` | `static func adjust(stickAngle:origin:targets:[CGPoint] coneDeg:range:strength:hasLineOfSight:(CGPoint)->Bool) -> CGFloat` (§3.4; caller passes only alive targets) |
| `Strike/Game/Systems/LootRoller.swift` | `enum LootRoller`, `struct LootContext`, `struct LootDrop { itemId, count }` | §10 steps 1–4 incl. the 3 JSON modifiers; takes `GKRandom` so tests are seeded |
| `Strike/Game/Systems/ProjectilePool.swift` | `@MainActor final class ProjectilePool` | preallocates `capacity` `ProjectileNode`s, `spawn(...) -> ProjectileNode?`, `recycle(_:)`, `activeCount`; never allocates after init |
| `Strike/Game/Systems/CameraController.swift` | `@MainActor final class CameraController` | `SKCameraNode` follow with smoothing + aim look-ahead (from `hero.json → camera`), clamped to room bounds |
| `Strike/Game/Input/StickInput.swift` | `struct StickInput` | pure: `init(origin:touch:radius:deadZone:fullAt:)` → `direction`, `magnitude` (0…1, ≥ fullAt → 1), `isActive`; base-follow when drag > 1.4 × radius |
| `Strike/Game/Input/TwinStickController.swift` | `@MainActor final class TwinStickController` | tracks two `UITouch`es by zone, produces `move: StickInput?`, `aim: StickInput?`, `fireHeld: Bool`; draws floating `StickNode`s (code-drawn `SKShapeNode`, 70 % alpha, fade 0.15 s) on the camera |
| `Strike/Game/Components/PoseAnimator.swift` | `@MainActor final class PoseAnimator`, `struct PoseStyle` | owns one `SKSpriteNode` (key pose `<prefix>_idle_01`). `setMotion(speed01:)` (idle bob ↔ walk squash/tilt), `face(east:)` (xScale ±1, never rotate), `playHit()` (white colorBlend 0.85→0.4→0 over 0.1 s + 3 pt shake), `playRecoil(angle:)` (3 pt kick back, 0.08 s), `playPowerDown(completion:)` (scale to 0 + fade 0.3 s). `useFrameAnimations = false` flag for later full art |
| `Strike/Game/Components/Particles.swift` | `enum Particles` | code-built `SKEmitterNode`s: `hitSparkle(color:)`, `poof()` (stars/sparkles, colorful, no red splats), auto-removed |
| `Strike/Game/Entities/PhysicsCategory.swift` | `enum PhysicsCategory` (`UInt32` masks) | `hero, enemy, heroShot, wall, pickup` |
| `Strike/Game/Entities/HeroNode.swift` | `@MainActor final class HeroNode: SKNode` | container at collision centre (circle `hero.radius`), sprite child anchor (0.5, 0.1) at y = −radius, owns `PoseAnimator`, `Health`, `WeaponState`, knockback |
| `Strike/Game/Entities/ProjectileNode.swift` | `@MainActor final class ProjectileNode: SKSpriteNode` | texture `proj_<style>` from `items` atlas, velocity, remaining range, damage |
| `Strike/Game/Entities/EnemyNode.swift` | `@MainActor final class EnemyNode: SKNode` | generic enemy from `EnemyDef`: sprite `enemy_<id>_idle_01`, `PoseAnimator`, `Health`, `brain: GKStateMachine` |
| `Strike/Game/Entities/BoltbotStates.swift` | `IdleState, AlertState, ChaseState, HopState, PoweredDownState: GKState` | §8 / §8.1 boltbot: alert "!" 0.4 s before chasing, wall-avoid steering, separation, hop pause from JSON. Leash is M2 (needs rooms) |
| `Strike/Game/Entities/PickupNode.swift` | `@MainActor final class PickupNode: SKSpriteNode` | `pickup_<itemId>`, pop-out arc ≤ 48 pt, bob, collected within `hero.pickupRadius` (bolts magnet within `hero.magnetRadius`) |
| `Strike/Game/Level/TestRoom.swift` | `@MainActor enum TestRoom` | builds a fixed 20 × 14 tile room (64 pt tiles, `tile_l1_floor_0x` / `tile_l1_wall_0x`), border walls + 2 pillar blocks, static physics edges; returns hero spawn + 3 boltbot spawns + bounds. Layout constants in code are OK (geometry, not balance; replaced by the M2 generator) |
| `Strike/Game/Scenes/GameScene.swift` | `GameScene` (rewritten) | composes all of the above; `SKPhysicsContactDelegate`; `update(_:)` drives systems; pushes `HUDState` to the model only when it changed |
| `Strike/App/GameModel.swift` | `GameModel` (extended), `struct HUDState: Equatable` | `hud: HUDState` (hp, maxHp, magazine, reserve, isReloading, reloadProgress, score, weaponId); `requestReload()` forwards to `var commandHandler: ((GameCommand) -> Void)?`; `enum GameCommand { reload }` |
| `Strike/UI/HUDView.swift` | `HUDView`, `AtlasImage` | SwiftUI overlay: HP bar (code-drawn, heart icon), ammo readout "12 / 48" + `ui_icon_blaster_starter`, RELOAD button (`ui_btn_reload`, 72 pt, bottom-right cluster per ART_BIBLE §7 minus Fire). `AtlasImage` = `Image(uiImage:)` from `SKTextureAtlas(...).textureNamed(...).cgImage()` |

Accessibility ids (used by UI tests): `gameView`, `menuButton` (existing), `hud.hpBar`, `hud.ammoLabel`, `hud.reloadButton`.
Touch split: sticks live in the SpriteKit scene (`touchesBegan/Moved/Ended` in `GameScene`); buttons live in the SwiftUI overlay and swallow their touches first.

### Tasks
- [x] **M1-1 game-designer — hero.json, M1 strings, GDD fixes**
  - Inputs: `docs/GDD.md` §2–§5, §16, `docs/TASKS.md` (M0 review), `Strike/Resources/Data/*.json`, `Strike/Resources/Localizable.xcstrings`
  - Outputs: `Strike/Resources/Data/hero.json`; `Localizable.xcstrings`; `docs/GDD.md` (§2 tile 64 pt + camera tiles, §3 no fire button, §5 blaster colors, new §16.6 `hero.json` schema, change log)
  - `hero.json` = `{ "version": 1, "hero": { maxHp, moveSpeed, radius, invulnerableSec, knockbackDistance, knockbackSec, pickupRadius, magnetRadius, interactRadius, startLoadout: { weaponId, magazine, reserve }, starterSafetyNet: { rechargeEverySec, rechargeTo } }, "controls": { moveZoneWidth, aimZoneWidth, hudBandHeight, stickRadius, moveDeadZone, aimDeadZone, fullMagnitudeAt, followFactor, fadeSec, aimAssistStrength, aimAssistDefaultOn }, "camera": { smoothingSec, lookAhead } }`
  - Strings (de + en): `hud.reload`, `hud.reloading`, `hud.hp.accessibility` ("Health %lld of %lld"), `hud.ammo.accessibility` ("%lld shots, %lld in reserve"), plus every `nameKey`/`descKey` referenced in weapons/items/enemies JSON
  - Done when: JSON is valid and matches GDD §4/§3/§2 numbers; every JSON text key exists in the catalog with de + en; GDD change log updated; no other code touched

- [x] **M1-2 visual-artist — ART_BIBLE alignment + pose spec** (parallel to M1-1, not blocking the coder)
  - Inputs: `docs/ART_BIBLE.md`, `docs/DECISIONS.md` (2026-11-22 M1 rows)
  - Outputs: `docs/ART_BIBLE.md` §1/§3 (particles, not frame FX), §7 (no Fire button; reload/swap/interact cluster re-flowed; stick visual 140 base / 64 knob / zones 45 %; touch targets ≥ 64), new §12 "PoseAnimator feel" (bob amplitude/Hz, walk squash %, tilt deg, recoil pt, hit-flash timing, power-down timing, particle colors per projectile style); ART-6 may be done in the same pass
  - Done when: no contradiction left with GDD §3 and DECISIONS; §12 values are concrete numbers the coder can copy into `PoseStyle`

- [x] **M1-3 swift-coder — Data layer** (needs `hero.json` from M1-1; if not there yet, coder creates it from GDD §4 numbers and the designer reviews)
  - Inputs: GDD §16, `Strike/Resources/Data/*.json`
  - Outputs: `Strike/Data/*.swift` per module map
  - Done when: `GameData.load()` decodes weapons/enemies/items/loot/hero from the bundle; `validate()` returns `[]`; unknown fields ignored; optional fields optional

- [x] **M1-4 swift-coder — Pure gameplay systems + unit tests**
  - Outputs: `WeaponState`, `Health`, `AimAssist`, `LootRoller`, `StickInput`; tests `StrikeTests/DataDecodingTests.swift`, `WeaponStateTests.swift`, `HealthTests.swift`, `AimAssistTests.swift`, `LootRollerTests.swift`, `StickInputTests.swift`
  - Done when (each is a test):
    - decoding: starter = mag 12 / reserveMax 96 / reload 1.0 / fireRate 4; boltbot hp 30 speed 110; `validate()` empty
    - ammo: fire uses mag only; no fire faster than `1/fireRate`; empty mag cannot fire; reload moves `min(magazineSize − mag, reserve)` after `reloadSec`; reload refused when mag full or reserve 0; swap/cancel loses no ammo; auto-reload starts at mag 0 with trigger held; starter safety net +1 per `rechargeEverySec` (hero.json) up to the cap only when mag + reserve = 0; `addReserve` returns overflow above `reserveMax`
    - health: damage reduces HP, second hit inside 0.8 s is `ignored`, HP clamps at 0 → `depleted`, heal caps at max
    - aim assist: target inside ±cone pulled by 0.6 of the difference; outside cone / out of range / no LOS → raw angle; nearest wins ties
    - stick: below dead zone inactive (move) / aim-only no fire (aim); ≥ 0.85 → magnitude 1
    - loot: seeded `GKMersenneTwisterRandomSource` gives identical drops; bolts within `[boltsMin, boltsMax]`; in level 1 with only the starter owned `ammo_spread`/`ammo_rapid` never drop (unowned modifier); low-HP modifier doubles heal/food weight

- [x] **M1-5 swift-coder — Test room, hero, camera**
  - Outputs: `TestRoom`, `PhysicsCategory`, `HeroNode`, `CameraController`, `GameScene` rewrite
  - Done when: room renders with L1 tiles at 64 pt, hero spawns with `hero_idle_01`, walls block the hero, camera follows with smoothing and stays inside room bounds; 60 fps on iPad Pro 11 simulator with `showsFPS`

- [x] **M1-6 swift-coder — Twin-stick input, firing, projectile pool, aim-assist**
  - Outputs: `TwinStickController`, `StickInput` wiring, `ProjectileNode`, `ProjectilePool` (capacity 64), aim-assist hook (toggle read from `controls.aimAssistDefaultOn`)
  - Done when: left stick floats where the thumb lands in the left zone and moves at `moveSpeed × magnitude`; right stick aims, auto-fires at `fireRate` above the aim dead zone, stops on release and keeps the last aim; no right input → hero faces move direction; shots stop at walls and fade at `range`; `ProjectilePoolTests` proves 200 shots never exceed capacity and nodes are reused

- [x] **M1-7 swift-coder — PoseAnimator + particles** (replaces the old "M1-x" line)
  - Outputs: `PoseAnimator`, `PoseStyle` (values from ART_BIBLE §12 if M1-2 landed, else sensible defaults marked `// TODO ART_BIBLE §12`), `Particles`
  - Done when: hero and boltbot bob when idle, squash/tilt when moving, flip with `xScale` (never rotate), flash white + shake on hit, recoil on each shot; power-down = poof sparkles + shrink/fade; no red/blood-like particles

- [x] **M1-8 swift-coder — Boltbot enemy, damage, power-down, loot**
  - Outputs: `EnemyNode`, `BoltbotStates`, `PickupNode`; contact handling in `GameScene`
  - Done when: 3 boltbots idle until the hero is within `detectRange` with LOS, show "!" 0.4 s, then chase with separation and hop pauses; hero shots deal `damage` and knockback; at 0 HP the boltbot powers down (no "die/kill" wording anywhere), score += `scoreValue`, `LootRoller` drops spawn as `PickupNode`s. M1 pickup effects: `bolt` → score + 10, `ammo_starter` → `addReserve(ammoAmount)`, everything else is collected and counted only (inventory is M3). Contact damage hurts the hero once per invulnerability window with knockback, light haptic; medium haptic on power-down

- [x] **M1-9 swift-coder — GameModel HUD + SwiftUI HUD + M1 rescue**
  - Outputs: `GameModel` (`HUDState`, `GameCommand`), `HUDView`, `AtlasImage`, `GameContainerView` overlay
  - Done when: HP bar and "mag / reserve" update live; RELOAD button (≥ 64 pt) starts reload and shows progress, greyed while reloading or nothing to reload; all text via `Localizable.xcstrings`; at 0 HP the hero sparkles and reappears at the room spawn with full HP + 2 s invulnerability (placeholder for the full M3 rescue; no "game over")

- [x] **M1-10 swift-coder — Smoke/UI tests**
  - Outputs: updated `StrikeTests/StrikeSmokeTests.swift` (scene builds a room + hero instead of the placeholder label), `StrikeUITests/StrikeCoreLoopUITests.swift`
  - Done when: UI test taps Start, finds `gameView`, `hud.hpBar`, `hud.ammoLabel` (value "12 / 48") and taps `hud.reloadButton` without crash; `xcodegen generate` + full `xcodebuild … test` green

- [x] **M1-11 qa-tester — M1 verification**
  - Inputs: everything above
  - Outputs: `docs/QA_REPORT.md` (M1 section), extra tests: `StrikeTests/LocalizationKeyTests.swift` (every JSON `nameKey`/`descKey` + `hud.*` key exists with de + en), JSON fuzz (missing optional fields / unknown fields still decode), `ProjectilePool` stress
  - Done when: full test run green (or bugs filed in QA_REPORT with repro), manual sim pass of the M1 goal sentence, kid-safety check (no red splats, no death wording in code strings or UI), node count stable after 2 min of firing

- [x] **M1-12 game-manager — M1 review**: check deliverables against GDD/ART_BIBLE, update ROADMAP/TASKS, plan M2 (2026-11-22, see below)

### M1 review (2026-11-22, branch `m1-core-loop` @ 0c35868)
**Accepted.** 68 Swift tests + 3 UI tests green (team-lead run after the QA fixes); the QA play pass covered every part of the M1 goal sentence.
- Module map followed 1:1. Extras: `Palette`, `Textures`, `RoomGeometry` (pure geometry for LOS/steering), `CameraControllerTests`, `StrikePlayPassUITests`.
- Data rules kept: hero, controls and camera come from `hero.json`; `alertSec` and `respawnInvulnerableSec` were moved into JSON when the coder asked. The GDD change log and ART_BIBLE §7/§12 were updated.
- QA-004 (running out of ammo) was fixed with data only: safety-net recharge 0.5 s, `ammo_rescue` loot modifier, boltbot `dropChance` 0.45. QA-005 (hero hidden under the HUD) was fixed by keeping the camera's view of the hero below the HUD band. Walls now have contrast plus an edge outline and top strip (screenshot reviewed: walls and pillars read clearly against the floor, the HP bar sits on its own band, and 60 fps at 313 nodes).
- Leftovers, carried into M2:
  1. `EnemyNode.knockbackSec = 0.1` is a balance number in code → move it to `enemies.json` (M2-1 / M2-4).
  2. Boltbots catch on pillar corners (steering only, no pathfinding) → M2-4 `Pathfinder`.
  3. The L1 floor tile is busy (high-contrast grid and orange marks). Pickups and projectiles still read in the screenshot; re-check readability with real loot on L1–L5 in M2-2.
  4. QA-003 touch orientation is a simulator quirk; it still needs a check on a real iPad (owner question).
  5. The alert "!" and the power-down sparkles were not caught on screenshots; QA checks them by eye in M2-7.

## M2 Levels

Goal: Start → level L1 (or any level via a debug launch argument), generated from `levels.json` with a seed. The player walks through BSP rooms and corridors with walls in the level's theme, opens gates and the exit door with buttons, levers, pressure plates and machines (with carried puzzle items), sees a minimap, touches checkpoints, reaches the exit pad and sees a simple "Level complete" card that leads to the next level. Boltbots find their way around obstacles and return home when the player leaves them behind (leash). All 5 levels generate and are solvable for every tested seed.

Out of scope for M2 (decided, see DECISIONS):
- inventory UI (M3)
- Pixel, hints and minimap pings (M3)
- the full rescue beam (M3)
- non-chaser behaviours and working weapon pickups (M4)
- boss arena (M4)
- decor props (no prop art exists → Later)
- stars screen and level map (M5)

Order:
- **M2-1** (designer) and **M2-2** (artist) run in parallel.
- **Coder pass A** = **M2-3 + M2-4**. It is pure logic and tests, starts immediately and only needs the existing `levels.json`; M2-1 only changes numbers.
- **Coder pass B** = **M2-5 … M2-6**, the scene integration. It needs M2-1 (`rules.json`, strings). It uses M2-2 visuals if they have landed, otherwise placeholders marked `// TODO ART_BIBLE §13`.
- Then **M2-7** (QA) and **M2-8** (review).

### M2 module map (binding for M2-3 … M2-6)
Same conventions as M1: pure logic is `nonisolated struct/enum`, `Sendable`, and is unit-tested; SpriteKit/UI types are `@MainActor`. Randomness only comes through a seeded `GKMersenneTwisterRandomSource` that is passed in; no global RNG.

| File | Type(s) | Role |
|---|---|---|
| `Strike/Data/LevelDef.swift` | `LevelDef`, `GeneratorParams`, `IntRange`, `EnemyMixEntry`, `PuzzleDef`, `PuzzleElementDef`, `GateDef`, `PickupsDef`, `LevelsFile` | §16.5 fields used by M2; `zone` decodes `Int` or `"any"` (`enum ZoneSpec { index(Int), any }`). `story`, `bossArena` and `pickups.fixed` are left out (M3/M4) |
| `Strike/Data/RulesDef.swift` | `RulesDef`, `RulesFile` | new `rules.json` from M2-1 (puzzle timings, leash, door pan, minimap). `GameData` gains `levels: [String: LevelDef]` (ordered by `index`) and `rules` |
| `Strike/Game/Level/TileGrid.swift` | `struct TileGrid`, `enum Tile { wall, floor }`, `struct GridPoint` | width × height cells, `tileSize = 64`, `world(_:)` / `cell(at:)`, `isWalkable`, `hasLineOfSight(from:to:)` (grid DDA), `isBlocked(_:radius:)`. Replaces `RoomGeometry` for generated levels; `TestRoom` builds a `TileGrid` too, so one geometry API remains |
| `Strike/Game/Level/BSPLayout.swift` | `enum BSPLayout`, `struct RoomRect`, `struct Corridor` | §14.1 steps 1–2: BSP split, rooms, L-shaped corridors of `corridorWidth`, loop corridors |
| `Strike/Game/Level/LevelGraph.swift` | `struct LevelGraph` | room adjacency through corridors, BFS distances, start/exit choice, critical path, zone assignment (steps 3–4) |
| `Strike/Game/Level/PuzzlePlacer.swift` | `enum PuzzlePlacer` | step 5: elements, gate elements, machine items (`sameZone`/`earlierZone`), spacing, no doorway blocking; machine takes 2 × 2 cells |
| `Strike/Game/Level/SpawnPlacer.swift` | `enum SpawnPlacer` | steps 6–7: threat budget per room, `enemyMix` (zoneMin, minPathFraction, maxPerRoom), `firstEncounterRoom`, per-room pickups, crates, 3 datachips (≥ 1 off-path), weapon pickup room, checkpoints (start pad + one behind each gate), exit pad behind the exit door |
| `Strike/Game/Level/LevelGenerator.swift` | `enum LevelGenerator`, `struct GeneratedLevel` | `generate(_ level: LevelDef, seed: UInt64) -> GeneratedLevel`; retries seed + 1 up to `maxAttempts`, then `fallbackSeed`; `GeneratedLevel` = grid, rooms (id, rect, zone, isOnPath), corridors, startRoom, exitRoom, criticalPath, gates (id, zone, cells, elementIds), exitDoor (cells, elementIds), elements (id, type, cell, roomId, zone, required, requiresItem?), itemPlacements, enemySpawns (enemyId, position, roomId), pickups, crates, checkpoints, exitPad, `seedUsed`, `attempts` |
| `Strike/Game/Level/SolvabilityChecker.swift` | `enum SolvabilityChecker` | §14.3 lock-and-key flood fill; also checks spacing, room caps and "no element/item within 3 tiles of an enemy" |
| `Strike/Game/Systems/PuzzleState.swift` | `struct PuzzleState`, `enum ActivationResult { activated, toggled, needsItem(String), alreadyOn, notReady }` | element on/off, button latch, lever toggle, plate hold timer, machine consumes item from an `ItemCarrier`; `isGateOpen(_:)`, `isExitOpen`, `requiredProgress -> (on, total)` |
| `Strike/Game/Systems/ItemCarrier.swift` | `protocol ItemCarrier`, `struct PuzzleBag` | `count(of:)`, `add(_:count:) -> Int` (overflow), `remove(_:count:) -> Bool`. `PuzzleBag` holds the puzzle items for M2; the M3 `Inventory` will conform to the same protocol and replace it |
| `Strike/Game/Systems/Pathfinder.swift` | `@MainActor final class Pathfinder` | `GKGridGraph` built from `TileGrid` (walkable cells only, diagonals off), `path(from:to:) -> [CGPoint]`, string-pulled with grid LOS, cached per target cell; rebuilt when doors open or close |
| `Strike/Game/Systems/LevelSession.swift` | `struct LevelSession` | levelId, seed, elapsed time, score, bolts, datachips found, rescues, last checkpoint, revealed room ids. M5 persists it |
| `Strike/Game/Level/LevelBuilder.swift` | `@MainActor enum LevelBuilder` | `GeneratedLevel` + theme → nodes. Floor/walls as `SKTileMapNode`s (themed `tile_lN_*` with the M1 4 × 4 sub-cells and the M1 wall edge treatment); wall physics as merged rectangles (greedy rows); spawns all entities |
| `Strike/Game/Entities/Puzzle/InteractableNode.swift` | `@MainActor class InteractableNode: SKNode` | element id, state light (red/green), `interactRadius`, highlight when it is the focused interactable |
| `Strike/Game/Entities/Puzzle/ButtonNode.swift`, `LeverNode.swift`, `PressurePlateNode.swift`, `MachineNode.swift`, `DoorNode.swift`, `CheckpointNode.swift`, `ExitPadNode.swift`, `CrateNode.swift` | one type each | sprites `puzzle_<id>_off/on`, door `closed → opening_01..04 → open` across all corridor cells (ART_BIBLE §13), lights + "3 / 5" counter on the door, plate fill ring, machine item bubble, crate takes hits and drops `loot_crate_small` |
| `Strike/Game/Entities/BoltbotStates.swift` | + `ReturnHomeState` | chasers follow `Pathfinder` waypoints when there is no direct LOS; leash per `rules.json`: return to the home room and heal to full |
| `Strike/Game/Entities/EnemyNode.swift` | (extended) | `homeRoomId`; reads `knockbackSec` from JSON; any enemy whose `behavior` is not implemented yet uses the chaser states with its own sprite and stats (temporary until M4) |
| `Strike/Game/Scenes/GameScene.swift` | (extended) | `init(level:seed:)`; focused-interactable search, INTERACT handling, door pan (1.0 s, input locked, skippable by tap), checkpoint save, M1 respawn now goes to the last checkpoint, exit pad → `GameCommand`/model `levelComplete` |
| `Strike/App/GameModel.swift` | (extended) | `Screen.levelComplete(LevelResult)`, `startLevel(id:seed:)`, `nextLevel()`; `HUDState` + `interact: InteractPrompt?` (icon id), `carried: [String: Int]` (key chips), `minimap: MinimapSnapshot`; `GameCommand.interact` |
| `Strike/UI/MinimapView.swift` | `MinimapView`, `struct MinimapSnapshot` | SwiftUI `Canvas`: layout image built once per level (a `CGImage` of the grid), revealed rooms only, hero dot, door states, seen elements as red/green dots. The scene pushes updates at ≤ 10 Hz. Position/size from ART_BIBLE §13 |
| `Strike/UI/HUDView.swift` | (extended) | INTERACT button (`ui_btn_interact`, ≥ 64 pt; glows when a target is focused, greyed out otherwise), key chips, toast line (`ui.toast.*`) |
| `Strike/UI/LevelCompleteView.swift` | `LevelCompleteView` | level name, time, score, datachips x / 3, Continue (→ next level; after L5 → title), Title button |
| `Strike/UI/DebugOverlay.swift` | `DebugOverlay` (`#if DEBUG` only) | seed + level id, "turn all on", "go to exit", "reveal map". Launch args: `-StrikeLevel l3`, `-StrikeSeed 1234`, `-StrikeTestRoom` (keeps the M1 room for tests) |

Accessibility ids (new): `hud.interactButton`, `hud.minimap`, `hud.keyChips`, `levelComplete.view`, `levelComplete.continue`, `debug.solveAll`, `debug.gotoExit`.

### Tasks
- [x] **M2-1 game-designer — 64 pt room sizes, rules.json, M2 strings**
  - Inputs: `docs/GDD.md` §11–§14, `docs/levels/L1–L5.md`, `Strike/Resources/Data/levels.json`, `enemies.json`, this task list
  - Outputs: `levels.json` (generator numbers), new `Strike/Resources/Data/rules.json`, `enemies.json` (`knockbackSec` per enemy), `Localizable.xcstrings`, `docs/GDD.md` (§14.2 table, new §16.8 `rules.json` schema, §11 notes, change log), `docs/levels/L*.md` where numbers change
  - **Re-check §14.2 for 64 pt tiles** (open item from M1-1). The view is now about 18.7 × 13 tiles instead of 25 × 17. Check room min/max size, grid size, corridor width (2 tiles = 128 pt; the hero is 36 pt wide), and `minElementSpacing` against the M1 combat feel: boltbot detect range 360 pt ≈ 5.6 tiles, starter range 520 pt ≈ 8 tiles. Target: a typical room is about one screen; L1 total walking time stays near `parTimeSec`.
  - `rules.json`: `{ version, puzzle: { leverPullSec, plateHoldSec, doorPanSec, doorMaxLights, interactFocusRadius? }, leash: { rangeFactor, returnAfterSec }, minimap: { revealOnEnter, updateHz } }`, with numbers from GDD §8/§11
  - Strings (de + en):
    - `hud.interact` and its accessibility label
    - door counter accessibility ("%lld of %lld switches on")
    - `ui.toast.need_item` (with item name), `ui.toast.checkpoint`, `ui.toast.bag_full`
    - `levelComplete.title`, `.time`, `.score`, `.datachips`, `.continue`, `.toTitle`
    - every `level.*.name` / `subtitle` key that is not there yet
  - Done when: JSON valid, `LocalizationKeyTests` green, the GDD change log explains every changed number, and no code is touched

- [x] **M2-2 visual-artist — Level visuals spec (ART_BIBLE §13)** (parallel; pass B uses placeholders until this lands)
  - Inputs: `docs/ART_BIBLE.md` §4/§7, puzzle + tile atlases, M1 screenshot
  - Outputs: `docs/ART_BIBLE.md` new §13 "Level presentation". Optional slicer/atlas tweaks under `tools/` and `Strike/Resources/Atlases/` (no Swift).
  - §13 must cover:
    - **Minimap position and size.** GDD §3.1 puts it top-centre, but ART_BIBLE §7 keeps the top-centre 120 pt free for Pixel's bubble. Pick a place that does not collide (e.g. top-right next to pause), with size, colours (room / corridor / unrevealed / hero / door open / door closed / element on / element off) and alpha.
    - Doors across 2–3-tile corridors: repeat the 64 pt door sprite per cell; rotate it 90° for vertical corridors (allowed: doors are objects, not characters). Lights + "3 / 5" counter style.
    - INTERACT button focus glow; ring on the focused interactable; pressure plate fill ring; machine "needs item" bubble; checkpoint/exit pad idle glow.
    - Floor readability: check L1–L5 floors with pickups, projectiles and the green/red state lights on top. The L1 floor is busy, so propose a fix if loot does not pop (e.g. lower the floor detail alpha in the slicer).
    - Wall edge treatment confirmed for l2–l5 (the M1 contrast fix changed l1/l3/l4/l5).
  - Done when: every value in §13 is a concrete number or hex and nothing contradicts §7 or the GDD

- [x] **M2-3 swift-coder (pass A) — Level data + generator + solvability**
  - Outputs: `LevelDef`, `RulesDef` (decoding is tolerant if `rules.json` is still missing: use the GDD defaults in a single `RulesDef.fallback` and log once), `TileGrid`, `BSPLayout`, `LevelGraph`, `PuzzlePlacer`, `SpawnPlacer`, `LevelGenerator`, `SolvabilityChecker`. Tests in `StrikeTests/LevelDecodingTests.swift`, `TileGridTests.swift`, `LevelGeneratorTests.swift`, `SolvabilityTests.swift`.
  - Done when (each is a test):
    - all 5 levels decode; `validate()` also resolves level enemy/item/loot ids
    - the same level + seed gives an identical `GeneratedLevel` (compare a stable hash of grid + placements)
    - for each level, seeds 0…199 all validate (no fallback needed in ≥ 95 % of them; the fallback seed always validates)
    - room count within `roomCount`; room sizes within min/max; every floor cell reachable when all doors are open; start ≠ exit; critical path ≥ `zones + 1` rooms
    - every gate sits on the corridor where its zone begins; gate elements are in zone − 1; machine items are never behind the gate they open
    - element spacing ≥ `minElementSpacing`; nothing blocks a doorway; no element or item within 3 tiles of an enemy spawn; start and checkpoint rooms have no enemies
    - 3 datachips with ≥ 1 off the critical path; the L2 `weaponPickup` is in zone 1 off the path
    - generating L4 (the largest) takes < 150 ms in a Debug test on the simulator

- [x] **M2-4 swift-coder (pass A) — PuzzleState, ItemCarrier, Pathfinder, leash logic**
  - Outputs: `PuzzleState`, `ItemCarrier`/`PuzzleBag`, `Pathfinder`, `LevelSession`; `ReturnHomeState` logic and the JSON `knockbackSec`. Tests in `PuzzleStateTests.swift`, `PathfinderTests.swift`, `LeashTests.swift`.
  - Done when (each is a test):
    - button latches; lever toggles and the exit needs every required lever on
    - plate turns on only after `plateHoldSec` of continuous standing
    - machine without the item → `needsItem(id)` and nothing consumed; with the item → consumes 1 and latches
    - gate opens with its elements; exit opens only with all required elements; `requiredProgress` counts correctly
    - path around a 2 × 2 pillar exists and never enters a wall cell; no path through a closed door; a path appears after the door opens
    - leash triggers after `returnAfterSec` beyond `rangeFactor × detectRange` and restores full HP at home

- [x] **M2-5 swift-coder (pass B) — Level in the scene**
  - Outputs: `LevelBuilder`, `Entities/Puzzle/*`, `EnemyNode`/`BoltbotStates` updates, `GameScene` changes, `DebugOverlay`, launch args
  - Done when:
    - L1–L5 render in their themes with M1-style walls
    - the hero collides with walls and closed doors
    - interactables highlight within `interactRadius`, and INTERACT activates button / lever (0.4 s pull) / machine
    - plates fill while the hero stands on them
    - doors show lights + counter, and the last element triggers the 1.0 s camera pan (input locked, tap skips)
    - boltbots path around pillars and through corridors with no corner sticking, and leash home
    - crates break and drop loot
    - checkpoints save on touch, and 0 HP respawns at the last checkpoint
    - the exit pad ends the level
    - 60 fps and < 1500 nodes on L4 on the iPad Pro 11 simulator (`showsFPS`)

- [x] **M2-6 swift-coder (pass B) — HUD, minimap, level flow, tests**
  - Outputs: `GameModel` extensions, `HUDView` (interact button, key chips, toast), `MinimapView`, `LevelCompleteView`; updated smoke tests; `StrikeUITests/StrikeLevelFlowUITests.swift`
  - Done when:
    - the minimap reveals rooms on entry and shows hero, doors and seen elements
    - key chips show carried puzzle items
    - the toast shows "need item"
    - Level complete → Continue loads the next level with a new seed, and after L5 it returns to the title
    - all text goes through the catalog
    - UI test (landscape set, see QA-003): launch with `-StrikeLevel l1 -StrikeSeed 42`, find `hud.minimap` and `hud.interactButton`, tap `debug.solveAll` then `debug.gotoExit`, and `levelComplete.view` appears; then Continue starts L2
    - full `xcodegen generate` + `xcodebuild … test` green

- [x] **M2-7 qa-tester — M2 verification**
  - Outputs: `docs/QA_REPORT.md` M2 section; `StrikeTests/GeneratorFuzzTests.swift`
  - Fuzz: 2,000 seeds per level with an **independent** reachability check written by QA, not a call to `SolvabilityChecker`. It covers: all required elements reachable, machine items never behind their own gate, exit pad reachable once everything is on.
  - Done when:
    - fuzz green and timings logged
    - manual sim pass of L1 and L3 without debug buttons (find all elements, use a machine, cross a gate, leash a boltbot, die and respawn at a checkpoint, finish)
    - minimap checked against the map
    - eyeball check of the alert "!" and the power-down sparkles (M1 leftover)
    - kid-safety pass on the new strings
    - node count and FPS on L4 logged

- [x] **M2-8 game-manager — M2 review**: check deliverables against GDD/ART_BIBLE, update ROADMAP/TASKS/DECISIONS, plan M3 (2026-11-22, see below)

### M2 review (2026-11-22, branch `m2-levels` @ 369bef8)
**Accepted.** 138 Swift tests and 9 XCTest cases are green.
- 10,000 fuzz seeds (2,000 per level) are valid under QA's independent checker, with no fallbacks used and at most 28 ms per level.
- A scripted player finishes L1–L5 on 3 seeds each in a real `GameScene` without debug commands, including a rescue at a gate checkpoint.
- L4 runs at about 194–250 nodes and 59–60 fps on the simulator, against the targets of under 1500 nodes and 150 ms generation.
- The module map was followed. Extras: `LevelRandom`, `Leash`, `VisualCheckTests` (renders of the alert, chase, power-down and gate).
- Data rules kept: `rules.json` exists, `knockbackSec` is now in JSON, and every changed number has a reason in the GDD change log (room-size re-check for 64 pt done: corridors 2, spacing 7–8, L4 grid 72 × 56).
- ART_BIBLE §13 is implemented: minimap top-right 160 × 120 under pause, floors calmed (`FLOOR_CALM`), L4/L5 walls calmed.
- QA-007 (machine focus) is fixed by measuring to the machine footprint. QA-003 is closed: the owner played on an iPad 10th gen (DECISIONS).

Leftovers, all carried into M3 (task id in brackets):
1. **QA-008**: the drawn exit pad is 32 pt off `GeneratedLevel.exitPad`. Pixel hints will use `level.exitPad`, so make the two agree. [M3-5]
2. **QA-009**: power-down is subtle on the L1 floor (thin ring, a few dots, 0.4 s). Artist specifies a bigger "poof v2", coder implements it. [M3-2, M3-5]
3. **Pickup halos, shadows and the enemy-shot under-glow** from ART_BIBLE §13.8 are not implemented. [M3-5]
4. Minimap corridor reveal radius and timings from ART_BIBLE §13.9 are still constants and belong in `rules.json`. [M3-1]
5. **Leash** is covered by unit tests only and has never been triggered by hand. [M3-7]
6. **Crowded L4 room** performance has not been measured on a real iPad. A debug "spawn crowd" button plus an owner device run. [M3-5, owner question]
7. **Main-actor warnings** in `StrikePlayPassUITests`. [M3-7]
8. **QA id mix-up**: code comments in `InteractableNode.swift:86` and `ScenePlaythroughTests.swift:94` say "QA-009" for machine focus. The report calls that QA-007 (QA-009 is the power-down effect). Fix the comments. [M3-5]
9. **56 story/Pixel keys** referenced by `levels.json → story` (`story.l1.intro.1`, `pixel.l1.move`, …) are missing from `Localizable.xcstrings`. `LocalizationKeyTests` only checks `*Key` fields, so they slipped through. [M3-1, M3-7]

## M3 Systems

Goal:
- **Arrival:** the level starts with Pixel's intro card, then Pixel floats beside the hero.
- **Bag:** the hero picks up food, heal packs, ammo and puzzle items into a 25-slot bag, uses them from 4 quick slots or the inventory screen, and drops items at their feet.
- **Ammo and machines:** ammo fills per-type reserves, with overflow becoming ammo packs. Machines take items from the bag.
- **Rescue:** at 0 HP, Pixel beams the hero to the last checkpoint (§12) with nothing lost.
- **Hints and talk:** Pixel gives hints (tap or idle), pings the minimap, comments on firsts and plays the story beats.
- **Save:** the loadout and level progress are saved and restored after relaunching the app.

Out of scope for M3:
- spread/rapid blasters, the SWAP button and weapon wheel, real weapon pickups (M4)
- boss and boss story triggers (M4)
- Settings screen (M5; M3 stores the settings in the save with defaults)
- stars screen and level map (M5)
- audio (M5)

Order:
- **M3-1** (designer) and **M3-2** (artist) run in parallel.
- **Coder pass A** = **M3-3 + M3-4**. Pure logic and tests; starts now, with GDD defaults in `RulesDef.fallback` until M3-1 lands, as in M2.
- **Coder pass B** = **M3-5 + M3-6**, scene and UI. It needs M3-1 strings/JSON and uses M3-2 visuals (placeholders marked `// TODO ART_BIBLE §14` otherwise).
- Then **M3-7** (QA) and **M3-8** (review).

### M3 module map (binding for M3-3 … M3-6)
Same conventions as M1/M2: pure logic is `nonisolated struct/enum`, `Sendable`, `Codable` where it is saved, and unit-tested; SpriteKit/UI types are `@MainActor`. GameModel stays the only bridge: the scene pushes snapshots, and the UI sends `GameCommand`s.

| File | Type(s) | Role |
|---|---|---|
| `Strike/Data/RulesDef.swift` | (extended) | new blocks from M3-1: `inventory`, `rescue`, `pixel`, `hints`, `lowHp`; `minimap.corridorRevealRadius` |
| `Strike/Data/LevelDef.swift` | (extended) | `story` (`intro`, `outro`, `beats[{trigger, key}]`), `hintIdleSec`, `pickups.startGift` |
| `Strike/Game/Inventory/ItemStack.swift` | `struct ItemStack: Codable` | `itemId`, `count` |
| `Strike/Game/Inventory/Inventory.swift` | `struct Inventory: ItemCarrier, Codable` | 25 slots of `ItemStack?`, 4 quick links (`String?`, item id, not a slot). `add(_:count:) -> Int` (fills existing stacks up to `stackSize`, then the first empty slot; returns what did not fit), `remove`, `count(of:)`. Also `drop(slot:count:) -> ItemStack`, `assignQuick(itemId:to:)`, `tidy()` (puzzle → heal → food → ammo, then id). Auto-assign: first heal → Q1 if empty, first food → Q2 if empty. `storesInInventory == false` items are rejected. **Replaces `PuzzleBag`** (deleted) |
| `Strike/Game/Inventory/ItemUse.swift` | `enum ItemUse`, `enum UseResult { used(heal: Int, ammo: (String, Int)?), alreadyFull, coolingDown, notUsable, none }`, `struct UseCooldowns` | GDD §6 use rules: no heal at full HP, 0.5 s cooldown per item type, heal capped; ammo packs add to reserve; puzzle items are never used from the bag |
| `Strike/Game/Systems/AmmoBank.swift` | `struct AmmoBank: Codable` | one reserve per ammo id with `reserveMax` from `weapons.json`; `add(_:amount:) -> Int` overflow; ammo for blasters not owned yet still counts (§5.1) |
| `Strike/Game/Systems/Loadout.swift` | `struct Loadout: Codable` | `owned` weapon ids, `equipped`, `magazines[weaponId]`, `ammo: AmmoBank`. `WeaponState` is refactored to keep only timers and fire/reload logic and to read and write magazine and reserve through `Loadout`. The starter safety net and `ammo_rescue` keep working (existing tests stay green) |
| `Strike/Game/Systems/PickupResolver.swift` | `enum PickupResolver`, `enum PickupOutcome { stored, reserve(overflowPacks: Int), score(Int), datachip, staysBagFull, weaponPlaceholder }` | pure decision for every item category (GDD §6/§7): bolt → score; datachip → session count + score; ammo → reserve, overflow → ammo-pack item if a slot is free, else it stays on the floor; heal/food/puzzle → inventory or `staysBagFull`; blaster → placeholder until M4 |
| `Strike/Game/Systems/RunState.swift` | `struct RunState: Codable` | everything that carries over between levels: `loadout`, `inventory`, `unlockedLevelIndex`, `bestResults[levelId]`, `settings` (`pixelTalk: lots/some/quiet`, `aimAssist`). Lives in `GameModel.run` |
| `Strike/Game/Systems/RescueRules.swift` | `enum RescueRules` | pure §12 steps 3–7: full HP, invulnerability, starter topped up to ≥ 1 magazine, `rescues += 1`, which enemies reset. Timings (slow-mo 0.3 × 0.6 s, beam 0.8 s) come from `rules.json → rescue` |
| `Strike/Game/Pixel/SpeechQueue.swift` | `struct SpeechQueue` | one line at a time, queue max 2 (older dropped), duration `base + perChar × length`, max 60 chars, talk-level filter (`lots` all; `some` story + hints; `quiet` story only), per-key cooldowns (low HP once per 60 s) |
| `Strike/Game/Pixel/StoryDirector.swift` | `struct StoryDirector` | maps triggers `start`, `firstEnemy:<id>`, `firstPickup:<id>`, `firstSeen:<elementType or gate>`, `firstLowHp`, `zone:<n>`, `allElementsOn`, `doorOpen` to the level's `beats` (each once per level) plus the GDD §13 generic lines and `pixel.tip.<enemyId>` on first sight. `bossPhase`/`bossDefeated` are ignored until M4 |
| `Strike/Game/Pixel/HintPlanner.swift` | `enum HintPlanner` | target = nearest **reachable** (current doors) required element that is off. If its machine lacks the item, target the item (in the bag → no fly, line `pixel.generic.need_*` instead; on the floor → its position). Else the next gate's element, else the exit pad (uses the QA-008-fixed `level.exitPad`). Also `pings(afterSec:)` for the minimap |
| `Strike/Game/Pixel/PixelNode.swift` | `@MainActor final class PixelNode: SKNode` | sprite `pixel_idle_01` + `PoseAnimator` (float bob, talk wiggle), follows 56 pt behind-left with a 0.15 s lerp, ignores walls and physics; `flyTo(_:then:)` for hints, dotted hint arrow (6 s), scan beam, rescue beam |
| `Strike/Game/Pixel/PixelController.swift` | `@MainActor final class PixelController` | owns `SpeechQueue`, `StoryDirector`, idle timer (`hintIdleSec`, reset on progress = element on, item picked, gate/door open, new room revealed), hint cooldown 10 s; pushes `bubble: PixelLine?` to the HUD |
| `Strike/Persistence/SaveGame.swift` | `struct SaveGame: Codable` | `version: 1`, `run: RunState`, `savedAt`. No mid-level state (decision) |
| `Strike/Persistence/SaveStore.swift` | `final class SaveStore` | `load() -> SaveGame?` / `save(_:)`: atomic write to Application Support `save.json` (directory injectable for tests); unknown version or corrupt file → move to `save.bak.json`, start fresh, never crash. Saves on level complete, checkpoint touch and app background |
| `Strike/Game/Scenes/GameScene.swift` | (extended) | pickups through `PickupResolver` (floor "!" marker when the bag is full), item drops at the hero's feet (never despawn), Pixel, rescue sequence (slow-mo → beam → checkpoint), low-HP trigger, minimap pings, crowd debug spawn, QA-008/009 and §13.8 fixes |
| `Strike/App/GameModel.swift` | (extended) | `run: RunState`, `Screen.levelIntro(levelId)`, `continueGame()`/`newGame()`, `HUDState` + `quickSlots: [QuickSlotState]`, `bubble: PixelLine?`, `lowHp: Bool`, `isPaused`; `GameCommand` + `useQuick(Int)`, `useItem(slot)`, `dropItem(slot, count)`, `assignQuick(itemId, slot)`, `tidy`, `openInventory`, `pause`, `resume`, `tapPixel` |
| `Strike/UI/QuickSlotBar.swift` | `QuickSlotBar` | 4 × 72 pt bottom-centre (ART_BIBLE §7): icon + total count, dashed when empty, greyed at 0, cooldown sweep, shake + toast "Already full!" |
| `Strike/UI/InventoryView.swift`, `ItemInfoPanel.swift` | | 5 × 5 grid of 64 pt slots (§7), info panel with Use / Drop (1 / all) / Put in quick slot / Tidy up; quick slots as drop targets (drag is nice-to-have, the tap flow is required); game time stops while open |
| `Strike/UI/PauseMenuView.swift` | `PauseMenuView` | Resume, Inventory, Quit to title. Settings comes in M5 |
| `Strike/UI/PixelBubbleView.swift` | `PixelBubbleView` | top-centre bubble (ART_BIBLE §7: max 420 × 90, `ui_icon_pixel` avatar, tap to dismiss) |
| `Strike/UI/LevelIntroView.swift` | `LevelIntroView` | level name + subtitle + the `story.intro` lines with Pixel's avatar, tap to continue; `LevelCompleteView` shows the `outro` lines |
| `Strike/UI/RootView.swift` | (extended) | title: "Continue" (if a save exists) + "New game" (asks for confirmation if a save exists) |

Accessibility ids (new): `hud.quickSlot.0…3`, `hud.inventoryButton`, `hud.pauseButton`, `pixel.bubble`, `inventory.view`, `inventory.slot.0…24`, `inventory.use`, `inventory.drop`, `inventory.assign`, `inventory.tidy`, `inventory.close`, `pause.view`, `pause.resume`, `levelIntro.view`, `title.continue`, `title.newGame`, `debug.spawnCrowd`, `debug.damageHero`.

### Tasks
- [ ] **M3-1 game-designer — M3 rules, Pixel and story text, save schema**
  - Inputs: GDD §4, §6, §7, §10, §12, §13, §15; `docs/levels/L1–L5.md`; `levels.json`; `rules.json`; ART_BIBLE §7 / §13.9
  - Outputs: `rules.json`, `hero.json`, `Localizable.xcstrings`, `docs/GDD.md`, `docs/levels/L*.md` if lines change
  - `rules.json` additions:
    - `inventory { slots 25, quickSlots 4, useCooldownSec 0.5, dropScatter }`
    - `rescue { slowMoScale 0.3, slowMoSec 0.6, beamSec 0.8, starterMinMagazine 12 }` (the invulnerability number stays `hero.respawnInvulnerableSec`)
    - `pixel { followOffset, bobAmplitude, bobHz, followLerpSec, tapRadius 80, bubbleBaseSec 3.0, bubblePerCharSec 0.04, maxChars 60, queueMax 2 }`
    - `hints { flySec 2, arrowSec 6, cooldownSec 10, pointerAfterSec 60 }`
    - `lowHp { threshold 25, lineCooldownSec 60 }`
    - `minimap.corridorRevealRadius 3` plus the §13.9 timings
  - Strings (de + en; kid tone, ≤ 60 chars for Pixel):
    - all 56 missing `story.*` / `pixel.l*.*` keys referenced by `levels.json`
    - every GDD §13 `pixel.generic.*` and `pixel.tip.*` line
    - inventory (`inventory.*`: use, drop, drop one, drop all, quick slot, tidy, close, empty)
    - `ui.toast.already_full`, pause (`pause.*`)
    - title Continue / New game / confirm text
    - level intro "Tap to start"
  - GDD:
    - §13: the bubble is the HUD top-centre bubble (ART_BIBLE §7), not above Pixel
    - define "progress" for the idle hint timer
    - the tap-on-Pixel vs stick-touch rule (a touch inside `tapRadius` that ends within 0.25 s and moves < 12 pt is a Pixel tap and starts no stick)
    - new §16.9 `rules.json` M3 blocks and §16.10 save-game contents
    - change log
  - Done when: JSON valid; every key in `levels.json → story` exists in de + en; Pixel lines ≤ 60 chars in both languages; no violent wording; no code touched

- [ ] **M3-2 visual-artist — ART_BIBLE §14 "Systems UI and Pixel"** (parallel)
  - Inputs: ART_BIBLE §7, §12, §13; `ui`/`pixel`/`fx` atlases; QA-009 screenshots `qa_m2_powerdown_a.png` / `_b.png` in the scratchpad
  - Outputs: `docs/ART_BIBLE.md` §14. Optional atlas/slicer tweaks (no Swift).
  - §14 covers:
    - quick-slot states: empty dashed, count badge, greyed at 0, cooldown sweep, "full" shake
    - inventory screen details beyond §7: selection, info panel layout, buttons ≥ 64 pt
    - Pixel bubble style (font size, max 2 lines, avatar, appear/dismiss timing)
    - Pixel feel: float bob, talk wiggle, scan beam
    - hint fly + dotted arrow style
    - minimap ping (blink rate, colour)
    - rescue beam (cyan column + sparkles, slow-mo tint) and hero fade-in at the checkpoint
    - low-HP heart pulse
    - bag-full "!" marker on floor pickups
    - **poof v2 (QA-009)**: bigger, colourful, ≥ 0.6 s, a burst of stars + bolts, readable on all 5 floors and still kid-safe (no red splats)
  - Done when: every value is a concrete number or hex; nothing contradicts §7 / §13 or the GDD

- [ ] **M3-3 swift-coder (pass A) — Inventory, ammo, pickups, run state, save**
  - Outputs: `ItemStack`, `Inventory` (`PuzzleBag` removed, its callers moved over), `ItemUse`, `AmmoBank`, `Loadout`, `WeaponState` refactor, `PickupResolver`, `RunState`, `SaveGame`, `SaveStore`. Tests in `InventoryTests.swift`, `ItemUseTests.swift`, `AmmoBankTests.swift`, `PickupResolverTests.swift`, `SaveStoreTests.swift`; existing `WeaponStateTests` and `LootRollerTests` stay green.
  - Done when (each is a test):
    - **Inventory storage:**
      - stacks fill up to `stackSize`, then a new slot
      - the 26th distinct stack is rejected and the overflow is returned
      - non-inventory items (bolt, datachip, blasters) are rejected
    - **Inventory actions:**
      - a quick slot shows the total count across stacks, stays linked at 0, and using it consumes from the first stack
      - auto-assign puts the first heal in Q1 and the first food in Q2, only into empty slots
      - drop returns the stack
      - tidy order is correct
      - the M2 machine tests pass with `Inventory` as the `ItemCarrier`
    - **Item use:**
      - heal is refused at full HP (`alreadyFull`) and capped at max
      - a second use of the same item type within 0.5 s is `coolingDown`
      - an ammo pack adds its amount to the matching reserve
    - **Ammo:**
      - ammo above `reserveMax` becomes ammo packs when a slot is free, otherwise `staysBagFull`
      - ammo for a blaster not owned yet still fills its reserve
    - **Save:**
      - a `RunState` round-trips through `SaveStore` in a temp directory
      - a corrupt file or a version mismatch gives `nil` plus a `.bak` file and does not crash
    - **Start gift:** the L1 `startGift` is applied once on a new game (not again on replay if already owned)

- [ ] **M3-4 swift-coder (pass A) — Rescue rules, Pixel brain, hints, story**
  - Outputs: `RescueRules`, `SpeechQueue`, `StoryDirector`, `HintPlanner`. Tests in `RescueRulesTests.swift`, `SpeechQueueTests.swift`, `StoryDirectorTests.swift`, `HintPlannerTests.swift`.
  - Done when (each is a test):
    - **Rescue:**
      - HP back to max, invulnerability set
      - starter topped up to ≥ 1 magazine; inventory, quick slots, ammo and datachips unchanged
      - puzzle states kept
      - powered-down enemies stay down; living ones are marked for full HP and return home
      - `rescues += 1`
    - **Speech queue:**
      - a third queued line drops the oldest
      - duration formula correct
      - lines over 60 chars are rejected in debug
      - the talk-level filter works for lots / some / quiet
      - the low-HP line plays at most once per 60 s
    - **Story:** each beat fires once per level; `firstEnemy:boltbot` fires on first sight, not first contact
    - **Hints:**
      - on generated L2/L4 seeds, the planner never points behind a closed door
      - it points at a floor item when the machine needs one and the bag lacks it
      - it gives `need_*` when the item is in the bag
      - it points at the exit pad once all elements are on
      - pings start only after `pointerAfterSec`

- [ ] **M3-5 swift-coder (pass B) — Scene: pickups, Pixel, rescue, leftovers**
  - Outputs: `PixelNode`, `PixelController`, `GameScene` changes, `Particles` poof v2, `PickupNode` halo/shadow/bob (§13.8), enemy-shot under-glow on L4/L5, QA-008 fix (`LevelGenerator`/`LevelBuilder` agree on the exit pad; test), QA comment fix (leftover 8), debug `spawnCrowd` (12 boltbots + 2 crates in the current room) and `damageHero`
  - Done when:
    - all pickups route through `PickupResolver`, and the bag-full "!" stays on the floor
    - items dropped from the inventory appear at the hero's feet and can be picked up again
    - Pixel follows, bobs and passes through walls; tapping Pixel gives a hint (fly 2 s, arrow 6 s, return, 10 s cooldown) and never starts a stick
    - the idle hint fires after `hintIdleSec` without progress
    - the scan line plays on the first boltbot; story beats play
    - at 0 HP: slow-mo 0.3 × for 0.6 s, beam 0.8 s, hero at the last checkpoint with full HP and 2 s invulnerability, living enemies healed and sent home, "Gotcha!" line, no "game over" anywhere
    - poof v2 visible on all 5 floors (render test like `VisualCheckTests`)
    - still under 1500 nodes and ~60 fps on the simulator with `spawnCrowd` on L4; result logged

- [ ] **M3-6 swift-coder (pass B) — HUD, inventory, pause, intro, save flow, UI tests**
  - Outputs: `QuickSlotBar`, `InventoryView`, `ItemInfoPanel`, `PauseMenuView`, `PixelBubbleView`, `LevelIntroView`, `RootView`/`GameModel` changes; `StrikeUITests/StrikeInventoryUITests.swift`
  - Done when:
    - quick slots show icon and total, tap = use, greyed at 0, shake + toast at full HP
    - the inventory opens from the HUD button and the pause menu, game time stops, and Use / Drop / Put in quick slot / Tidy work
    - the Pixel bubble shows the queued lines top-centre and taps dismiss it
    - the intro card is shown before each level and outro lines on the Level complete card
    - Continue after relaunch restores loadout, inventory, quick slots and unlocked level; New game asks before overwriting
    - all text goes through the catalog; buttons ≥ 64 pt
    - UI test (landscape): `-StrikeLevel l1 -StrikeSeed 42 -StrikeFreshSave`, tap through the intro, Q1 shows the healpack count 1, `debug.damageHero` then Q1 → count 0 and HP up, open the inventory, `inventory.tidy`, close, relaunch without `-StrikeFreshSave` → `title.continue` exists
    - full `xcodegen generate` + `xcodebuild … test` green (own derivedDataPath + simulator per CLAUDE.md)

- [ ] **M3-7 qa-tester — M3 verification**
  - Outputs: `docs/QA_REPORT.md` M3 section; `StrikeTests/InventoryFuzzTests.swift`; `LocalizationKeyTests` extended to every string-array key in `levels.json → story` (leftover 9); main-actor warnings fixed in `StrikePlayPassUITests` (leftover 7)
  - Inventory fuzz: 10,000 random add / remove / use / drop / tidy / assign sequences. Invariants: ≤ 25 slots used, every stack ≤ `stackSize`, item totals conserved (picked − used − dropped), quick links only to inventory item ids.
  - Done when:
    - suite green with no new warnings
    - **leash checked by hand** (leftover 5): lure a boltbot two rooms away, wait 4 s, it walks home and is at full HP
    - rescue checked by hand (slow-mo, beam, checkpoint, enemies home)
    - save, kill app, relaunch → Continue restores everything
    - Pixel lines read in de and en on device-size screenshots (no clipping in the bubble)
    - kid-safety pass on all new text
    - `spawnCrowd` on L4: FPS / node count logged on the simulator; ask the owner for the device number (owner question)

- [ ] **M3-8 game-manager — M3 review**: check deliverables against GDD/ART_BIBLE, update ROADMAP/TASKS/DECISIONS, plan M4

## Questions for the owner
- Performance check on your iPad 10th gen: in a DEBUG device build of M3, open L4 (`-StrikeLevel l4`), tap `spawnCrowd` once, fight for 30 s, and tell us the FPS shown in the corner (needed for the 60 fps goal on iPad 9th gen+)
- Final title and character names (designer proposed options in GDD §19)
- Gemini commercial-use terms for generated images (owner to confirm)
- Music/SFX source (default: CC0 packs)
- Minimum iPad model (default iPadOS 18, iPad 9th gen+)
- GDD §19 items 6–9 (Easy setting, hero looks, left-handed prompt, replay with new seed) are still open
