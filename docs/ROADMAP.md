# Roadmap – Season 1 MVP

- **M0 Setup**: agents, CLAUDE.md, git, docs skeleton, XcodeGen project builds an empty landscape iPad app
- **M1 Core loop**: JSON data loading, static test room, hero with twin-stick controls + auto-fire + aim-assist, starter blaster (mag/reserve/reload, pooled shots), PoseAnimator on lite-set art, boltbot (chaser) with power-down sparkles + loot, SwiftUI HUD (HP, ammo, reload), camera follow, unit + UI tests
- **M1 status**: done 2026-11-22 (branch `m1-core-loop`)
- **M2 Levels**: procedural generator (BSP rooms + corridors, seeded, solvability-checked) for L1–L5 in their themes, 64 pt room-size re-check, door puzzle (buttons, levers, pressure plates, machines with carried puzzle items, gates, exit door + pad), checkpoints saved on touch, enemy leash + grid pathfinding, minimap, "Level complete" card, debug seed tools
- **M3 Systems**: inventory (25 + 4 quick slots, replaces M2 `PuzzleBag`), full loot effects + ammo-pack overflow, heal packs and food, Pixel rescue beam at checkpoints, Pixel drone buddy (hints, minimap pings)
- **M4 Content**: all 5 enemy types, 3 blasters, levels 1–5 data, boss (MEGA-MECH Unit Zero)
- **M5 Presentation**: AI-generated art integrated, audio, DE/EN localization, menus, save game
- **M6 Polish**: balancing, 60 fps on iPad 9th gen+, kid-safety review, TestFlight build

## Later (not MVP)
Game controller support, more seasons, more weapons, achievements, frame-by-frame character animations (lite set is enough for MVP), decor props (generator step 8).
