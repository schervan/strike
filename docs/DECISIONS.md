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
