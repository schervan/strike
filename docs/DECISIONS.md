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
