# Roadmap – Season 1 MVP

- **M0 Setup**: agents, CLAUDE.md, git, docs skeleton, XcodeGen project builds an empty landscape iPad app
- **M1 Core loop**: JSON data loading, static test room, hero with twin-stick controls + auto-fire + aim-assist, starter blaster (mag/reserve/reload, pooled shots), PoseAnimator on lite-set art, boltbot (chaser) with power-down sparkles + loot, SwiftUI HUD (HP, ammo, reload), camera follow, unit + UI tests
- **M1 status**: done 2026-11-22 (branch `m1-core-loop`)
- **M2 Levels**: procedural generator (BSP rooms + corridors, seeded, solvability-checked) for L1–L5 in their themes, 64 pt room-size re-check, door puzzle (buttons, levers, pressure plates, machines with carried puzzle items, gates, exit door + pad), checkpoints saved on touch, enemy leash + grid pathfinding, minimap, "Level complete" card, debug seed tools
- **M2 status**: done 2026-11-22 (branch `m2-levels`)
- **M3 Systems**: inventory (25 + 4 quick slots, replaces `PuzzleBag`), per-type ammo reserves + ammo-pack overflow, heal packs and food, all pickups into the bag, checkpoint rescue with the Pixel beam, Pixel drone buddy (follow, hints, minimap pings, tips, story beats, intro/outro cards), pause menu, save game basics (run state + Continue); M2 leftovers (exit pad offset, poof v2, pickup halos)
- **M3 status**: done 2026-11-24 (branch `m3-systems`); audio run (music, SFX, Settings volume) merged 2026-11-23
- **M4 Content**: GameScene split; all 5 enemy behaviours (chaser, kiter, splitter, shielded, turret) with telegraphs, enemy shots and spore slow; 3 blasters + SWAP + weapon wheel + live weapon pickups; L1–L5 content and balance pass; MEGA-MECH Unit Zero in a fixed arena (3 phases, energy-core shield puzzle, kid-safe retries), boss music, Season complete card; M3 leftovers (hint chevron, settings controls, gear icon, QA-011/012/014/015)
- **M4 status**: done 2026-11-24 (branch `m4-content`)
- **M5 Presentation**: all orientations and window sizes with the turn-me card (QA-013), title and menu polish, level map with stars / best score and time / replay, datachip Pixel facts, one Settings store (audio, Pixel talk, aim help, left-handed, Easy if accepted), save v2 migration, DE/EN text review, accessibility (Dynamic Type menus, VoiceOver, Reduce Motion), audio polish (jingles, boss intro sting, UI/star SFX), app icon variants and launch screen; M4 leftovers (§15 extras, gear icon, debug overlay, first encounter per zone)
- **M6 Polish**: balancing after an owner/kid playtest (incl. boss length), 60 fps on iPad 9th/10th gen (crowd + boss), final kid-safety review, App Store Kids metadata inputs, TestFlight build

## Later (not MVP)
Game controller support, more seasons, more weapons, achievements, frame-by-frame character animations (lite set is enough for MVP), decor props (generator step 8).
