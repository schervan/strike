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
