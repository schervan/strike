# Tasks

## M0 Setup
- [x] M0-1 Create agents, CLAUDE.md, git, docs skeleton (main session)
- [x] M0-2 game-designer: write `docs/GDD.md` incl. data schemas + `docs/levels/L1–L5.md`
- [x] M0-3 visual-artist: write `docs/ART_BIBLE.md` + placeholder generator
- [x] M0-4 swift-coder: `project.yml`, empty SwiftUI+SpriteView app, landscape, builds on simulator
- [ ] M0-5 qa-tester: test targets run (smoke test green). `StrikeTests/DataIntegrityTests.swift` exists; qa-tester to confirm a green `xcodebuild test` run and log it in `docs/QA_REPORT.md`
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
- [ ] **M1-1 game-designer — hero.json, M1 strings, GDD fixes**
  - Inputs: `docs/GDD.md` §2–§5, §16, `docs/TASKS.md` (M0 review), `Strike/Resources/Data/*.json`, `Strike/Resources/Localizable.xcstrings`
  - Outputs: `Strike/Resources/Data/hero.json`; `Localizable.xcstrings`; `docs/GDD.md` (§2 tile 64 pt + camera tiles, §3 no fire button, §5 blaster colors, new §16.6 `hero.json` schema, change log)
  - `hero.json` = `{ "version": 1, "hero": { maxHp, moveSpeed, radius, invulnerableSec, knockbackDistance, knockbackSec, pickupRadius, magnetRadius, interactRadius, startLoadout: { weaponId, magazine, reserve }, starterSafetyNet: { rechargeEverySec, rechargeTo } }, "controls": { moveZoneWidth, aimZoneWidth, hudBandHeight, stickRadius, moveDeadZone, aimDeadZone, fullMagnitudeAt, followFactor, fadeSec, aimAssistStrength, aimAssistDefaultOn }, "camera": { smoothingSec, lookAhead } }`
  - Strings (de + en): `hud.reload`, `hud.reloading`, `hud.hp.accessibility` ("Health %lld of %lld"), `hud.ammo.accessibility` ("%lld shots, %lld in reserve"), plus every `nameKey`/`descKey` referenced in weapons/items/enemies JSON
  - Done when: JSON is valid and matches GDD §4/§3/§2 numbers; every JSON text key exists in the catalog with de + en; GDD change log updated; no other code touched

- [ ] **M1-2 visual-artist — ART_BIBLE alignment + pose spec** (parallel to M1-1, not blocking the coder)
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

- [ ] **M1-12 game-manager — M1 review**: check deliverables against GDD/ART_BIBLE, update ROADMAP/TASKS, plan M2

## Questions for the owner
- Final title and character names (designer proposed options in GDD §19)
- Gemini commercial-use terms for generated images (owner to confirm)
- Music/SFX source (default: CC0 packs)
- Apple Developer account for device/TestFlight builds? (bundle id is still `com.example.strike`)
- Minimum iPad model (default iPadOS 18, iPad 9th gen+)
- GDD §19 items 6–9 (Easy setting, hero looks, left-handed prompt, replay with new seed) are still open
