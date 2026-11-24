# Decisions

| Date | Decision | Reason |
|---|---|---|
| 2026-11-22 | SpriteKit + SwiftUI, iPad only, landscape, iPadOS 18+ | Native 2D, pure Xcode, no third-party engine |
| 2026-11-22 | XcodeGen generates the project (`project.yml`) | Agents can edit the project as text, reproducibly |
| 2026-11-22 | Art via AI image generation: visual-artist writes prompts, owner generates, slicer builds atlases; placeholders first | Owner choice |
| 2026-11-22 | Procedural rooms + corridors each play; fixed theme/enemies/puzzle rules per level; solvability guaranteed | Replayability with controlled difficulty |
| 2026-11-22 | Ages 7–12; at 0 HP Pixel teleports player to last checkpoint, inventory kept | Gentle failure for kids |
| 2026-11-22 | 3 blasters (starter, spread, rapid), each with own ammo type | Owner choice |
| 2026-11-22 | Good AI = floating drone buddy "Pixel" (hints, story, switch pointer, rescue) | Owner choice |
| 2026-11-22 | Offline, no ads/IAP/tracking; DE + EN; boss fight in L5 | Owner choice / Kids category |
| 2026-11-22 | Working title "Strike" | Owner choice |
| 2026-11-22 | Models: opus for manager/designer/coder, sonnet for visuals/QA | Reasoning-heavy roles get opus; spec/pipeline/test roles are well served by sonnet at lower cost |
| 2026-11-22 | Art generated with Gemini (web app); the slicer handles off-color backgrounds, the watermark and multi-item sheets | Owner choice |
| 2026-11-22 | Lite art set for MVP (~35 images, one key pose per character; code animates them); full frame animations later under the same names | Far less generation work; consistent style |
| 2026-11-22 | Joystick, slots and HP bar are drawn in code; hit and poof FX are particles | Crisper, no art needed |
| 2026-11-22 | Approved new assets: bolt, datachip, crate, checkpoint, exitpad | Owner approved the designer's proposal |
| 2026-11-22 | Claude generates the art via the Gemini API (`tools/gen_art.py`, owner's key in env `GEMINI_API_KEY`); owner approves the hero, Claude reviews and retries the rest; manual prompt page stays as a fallback | Owner wants no copy-paste or renaming |
| 2026-11-22 | Tile = 64 pt (128 px @2x); GDD §2 "48 pt" is superseded | All tile/puzzle/character art is already authored on a 64 pt grid (hero = 1 tile, machine = 2 × 2); rescaling art is costlier than adjusting room sizes in M2 |
| 2026-11-22 | Fire = right aim stick with auto-fire (GDD §3); no Fire button in the HUD, `ui_btn_fire` stays unused | One fewer button for 7-year-olds; matches the M1 scope |
| 2026-11-22 | Stick geometry follows GDD (zones 45 %, travel radius 70, dead zones 0.15 / 0.30, targets ≥ 64 pt); values live in new `hero.json → controls` | One source of truth; tunable without code |
| 2026-11-22 | Hero stats, controls and camera tuning live in new `Strike/Resources/Data/hero.json` | CLAUDE.md: balance numbers never in code |
| 2026-11-22 | Blaster/projectile colors follow the art (starter orange, spread purple, rapid yellow); GDD text is updated | Art is already generated and owner-approved |
| 2026-11-22 | PoseAnimator animates the single key pose (`*_idle_01`) procedurally; frame playback is behind an off-by-default flag | Lite set frames are identical copies; full animations later without renaming |
| 2026-11-22 | Touch split: sticks handled in the SpriteKit scene, buttons in the SwiftUI HUD overlay; HUD reads `GameModel.hud`, buttons send `GameCommand`s | Clear module boundary; SwiftUI buttons swallow touches before the scene |
| 2026-11-22 | HUD positions: ART_BIBLE §7 wins; gameplay rules: GDD wins | Avoids double ownership of layout |
| 2026-11-22 | M1 placeholders: pickups only affect score (bolt) and starter reserve (ammo_starter); at 0 HP the hero respawns at the room spawn with full HP. Inventory and Pixel rescue are M3 | Keeps M1 to one coder pass; still kid-safe (no game over) |
| 2026-11-22 | JSON wins over ART_BIBLE for collision radii (e.g. boltbot 16 pt) | GDD rule "JSON wins for numbers" |
| 2026-11-22 | M1 "Core loop" accepted (branch `m1-core-loop` @ 0c35868; 68 unit + 3 UI tests green) | All M1 done-when criteria met; leftovers carried into M2 |
| 2026-11-22 | A kid can never stay out of ammo: starter safety net recharges every 0.5 s, the `ammo_rescue` loot modifier guarantees an ammo pack below one magazine, boltbot dropChance 0.45 | QA-004: kids who miss a lot were left at 0 / 0 |
| 2026-11-22 | The camera keeps the hero below the HUD band | QA-005: the hero was hidden under the HP/ammo capsule |
| 2026-11-22 | M2 adds `rules.json` (puzzle timings, leash, door pan, minimap) instead of constants in code | CLAUDE.md: balance numbers live in JSON |
| 2026-11-22 | Chasers use `GKGridGraph` pathfinding on the tile grid when there is no direct line of sight | Boltbots caught on pillar corners in M1; the tile grid already exists |
| 2026-11-22 | Puzzle items go into a minimal `PuzzleBag` behind an `ItemCarrier` protocol in M2; the M3 `Inventory` conforms to it and replaces the bag | Machines need items before the inventory exists; no throwaway API |
| 2026-11-22 | Until M4, enemies with behaviours that are not implemented yet use the chaser AI with their own sprite and stats | All 5 levels can be generated and played in M2 |
| 2026-11-22 | Generator step 8 (decor props) moves to Later | No prop art exists in the lite set; not needed for MVP play |
| 2026-11-22 | M2 ends a level with a simple "Level complete" card (time, score, datachips, Continue); stars screen and level map are M5; L5 ends at the exit pad until the boss lands in M4 | Testable 5-level flow without pulling M4/M5 work forward |
| 2026-11-22 | Checkpoint pads are placed and saved on touch in M2, and the M1 respawn uses the last checkpoint; the Pixel beam and full rescue rules stay in M3 | Generator owns placement; rescue presentation belongs to Pixel |
| 2026-11-22 | Minimap placement is decided by visual-artist (ART_BIBLE §13), not top-centre | GDD §3.1 sketch conflicts with the top-centre zone reserved for Pixel's bubble |
| 2026-11-22 | Weapon pickups are placed by the generator in M2 but only become usable blasters in M4 | 3 blasters are M4 scope |
| 2026-11-22 | Debug-only overlay and launch args (`-StrikeLevel`, `-StrikeSeed`, `-StrikeTestRoom`) for QA and UI tests | Generated levels need reproducible seeds; debug code is compiled out of release builds |
| 2026-11-22 | Bundle ID `io.schervan.strike`, team F5N3DQNZFC, automatic signing | Device builds on owner's iPad |
| 2026-11-22 | QA-003 closed: owner played M1 on a real iPad (10th gen); move and shoot work | Real-device touch check |
| 2026-11-22 | M2 "Levels" accepted (branch `m2-levels` @ 369bef8; 138 unit + 9 UI tests, 10,000 fuzz seeds clean, scripted L1–L5 playthroughs) | All M2 done-when criteria met; leftovers carried into M3 |
| 2026-11-22 | Pixel's speech bubble is the top-centre HUD bubble (ART_BIBLE §7), not a bubble above Pixel in the world | Always readable, never off-screen or under walls; GDD §13 updated in M3-1 |
| 2026-11-22 | Tapping Pixel = touch inside `pixel.tapRadius` that ends within 0.25 s and moves < 12 pt; such a touch starts no stick | Pixel floats inside the stick zones; kids must not get a hint when they meant to move |
| 2026-11-22 | `Inventory` (25 slots, 4 quick links) replaces `PuzzleBag` via the `ItemCarrier` protocol; ammo reserves move to an `AmmoBank` per ammo type inside a `Loadout` | GDD §5.1/§7: one reserve per ammo type, inventory carries over |
| 2026-11-22 | Save game basics in M3: one `save.json` (run state: loadout, inventory, quick slots, unlocked level, best results, settings) saved on level complete, checkpoint touch and app background; no mid-level state, Continue restarts the current level with the saved loadout | Smallest save that keeps kids' progress; mid-level save would need entity serialization (not worth it for 6–12 min levels) |
| 2026-11-22 | Settings values (Pixel talk level, aim assist) live in the save from M3 with defaults; the Settings screen is M5 | Pixel's talk filter is needed now, the menu is presentation work |
| 2026-11-22 | M3 pause menu = Resume, Inventory, Quit to title | Settings and the level map arrive in M5 |
| 2026-11-22 | Story/Pixel text keys referenced by `levels.json` must be covered by `LocalizationKeyTests` | 56 keys were missing and no test caught it |
| 2026-11-23 | Music from Lyria 3.5 (title = v1, owner pick); SFX are synthesized by our own script (`tools/synth_sfx.py`) because Lyria only produces music, not usable short SFX | Owner listened to the Lyria SFX output and rejected it |
| 2026-11-23 | Settings screen with separate Music and Sound effects volume (owner request) | Owner request |
| 2026-11-24 | M3 "Systems" accepted (branch `m3-systems` @ 25a1ab2; 243 unit + 16 UI tests, inventory fuzz 10,000 clean, leash/rescue/save checked by hand) | All M3 done-when criteria met; leftovers carried into M4 |
| 2026-11-24 | TASKS lines are a snapshot of the plan; when the GDD later sets a sharper rule (e.g. the M3-4 hint wording vs GDD §13 `hint_machine`), the GDD wins and done tasks are not rewritten | Avoids double maintenance; GDD stays the source of rules |
| 2026-11-24 | The Settings screen (music/SFX volume) and the pause gear arrived with the audio run instead of M5; M4 adds the Pixel-talk and aim-assist controls to it | Owner request; the values were already in the save |
| 2026-11-24 | M4 starts with a refactor that splits `GameScene` (1,524 lines) into Combat/Enemy/Interaction/HUD controllers, with no behaviour change | Five behaviours + boss would push one file past maintainability; refactor while the tests are green |
| 2026-11-24 | Enemy AI = pure policy structs (unit-tested without SpriteKit) driven by thin `GKState`s | Behaviour must be testable without a live render loop (the M3 leash check had to integrate movement by hand) |
| 2026-11-24 | The boss arena is a separate fixed stage reached through the L5 exit pad (built as a `GeneratedLevel` from `BossArenaLayout`), not stitched into the generated map | Reuses builder, minimap and pathfinding; no generator changes |
| 2026-11-24 | Exception to "no mid-level save": `RunState.l5ArenaReached` lets Continue resume at the boss arena checkpoint | Kids should not replay all of L5 to retry the boss after closing the app |
| 2026-11-24 | Boss uses the lite key pose + `PoseAnimator`; the OVERMIND face screen is an overlay (generated sprites or code-drawn, max 4 moods); boss power-down is a "sparkle burst", never an explosion look | Lite-set decision; kid safety and the audio bible's "no explosions" rule |
| 2026-11-24 | SWAP button appears once 2 or more blasters are owned; Pixel's swap line plays only then | QA-012: never point kids at a button that is not there |
| 2026-11-24 | QA-013 (orientations) goes to the owner with a recommendation: support all orientations and window sizes with a "Turn me sideways" pause card, scheduled in M5 | Platform requirement ahead of the M6 submission; product choice belongs to the owner |
| 2026-11-24 | QA-013 orientation: support all orientations and window sizes; in portrait the game pauses and Pixel shows a "Turn me sideways!" card; gameplay stays landscape. Scheduled in M5 | Owner choice; App Store compliance before M6 TestFlight |
| 2026-11-24 | QA-016: a rescue in the boss arena keeps the boss's damage; only attack timing resets (inserted cores stay) | Owner choice; every try makes progress, no frustration for kids |
| 2026-11-24 | QA-018: no glossy red projectiles; spore shots and boss rockets get non-red kid-safe colours | Kid safety ("red only as soft glow") |
| 2026-11-24 | M4 "Content" accepted (branch `m4-content` @ 9ccbacd; 327 unit + 23 UI tests, boss fuzz 0/10,000, balance smoke within tolerance, all enemy types and the boss checked by hand) | All M4 done-when criteria met; leftovers carried into M5/M6 |
| 2026-11-24 | Generator option `firstEncounterPerZone` (L2 zone 1: one shield android alone) is added in M5 | Accepts the designer's GDD §19 q13 recommendation; reliable intro of the shield mechanic |
| 2026-11-24 | Boss length (65–98 s for the QA bot vs ~2 min in the GDD) is not tuned before an owner/kid playtest; it is an M6 balancing item | Bot skill is not kid skill; tuning on bot data alone risks making it too hard |
| 2026-11-24 | All settings (audio, Pixel talk, aim help, left-handed, Easy) move to one device-level `AppSettings` store; the save keeps progress only (save v2 with a v1 migration) | "New game" must not reset a kid's settings; one place for the Settings screen |
| 2026-11-24 | Save migration never deletes data: v1 is backed up before the first v2 write, and a save from an unknown future version is left untouched | Kids' progress is the most valuable data in the app |
| 2026-11-24 | Gameplay stays landscape; all menus (title, level map, facts, settings) also lay out in portrait; only the game screen shows the turn-me card | Implements the QA-013 owner decision without a portrait gameplay layout |
| 2026-11-24 | Easy mode is built behind a feature flag in M5 and enabled only after the owner accepts it | Open owner question (GDD §19 q6/q14); avoids blocking M5 |
| 2026-11-24 | Credits/licenses are shown as static in-app text (no outbound links) | Kids category: no links out without a parental gate |
| 2026-11-24 | Audio tasks go to the sound-designer agent (owner of AUDIO_BIBLE and `audio.json`) | Agent added with the audio run (CLAUDE.md) |
