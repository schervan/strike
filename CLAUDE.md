# Strike (working title)

A kid-friendly (ages 7–12) top-down 2D shooter for **iPad, landscape only**, built in Xcode with **SpriteKit + SwiftUI + GameplayKit** (Swift 6, iPadOS 18+). It is offline, with no ads, IAP, or tracking (App Store Kids category). Languages: German + English.

**Story:** the evil AI OVERMIND builds evil androids and gene-monsters to rule the world. The hero stops it with the help of Pixel, a good AI drone buddy.

**MVP (Season 1):** 5 procedurally generated levels (rooms + corridors, fixed theme per level). Each exit door opens via buttons, levers, or machines. 3 blasters with separate ammo, heal packs and food, a 25-slot inventory with 4 quick slots, loot drops, checkpoint rescue at 0 HP, and a boss in level 5.

## Agents (`.claude/agents/`)
| Agent | Model | Use for |
|---|---|---|
| game-manager | opus | Milestones, task breakdown, reviews, scope, decisions |
| game-designer | opus | GDD, levels, balance, story/text, data JSON |
| swift-coder | opus | All Swift + Xcode project |
| visual-artist | sonnet | Art bible, AI-image prompts, placeholders, atlases, HUD layout |
| qa-tester | sonnet | Tests, generator fuzzing, kid-safety checks, QA report |
| sound-designer | sonnet | Audio bible, AI Studio music/SFX prompts and generation, audio processing, audio.json |

Workflow per milestone: game-manager plans → designer/artist specify → coder implements → qa-tester verifies → game-manager reviews.

## Key docs
`docs/ROADMAP.md`, `docs/TASKS.md`, `docs/DECISIONS.md`, `docs/GDD.md`, `docs/levels/L1–L5.md`, `docs/ART_BIBLE.md`, `docs/QA_REPORT.md`

## Layout
```
project.yml               XcodeGen spec (never hand-edit Strike.xcodeproj)
Strike/App|Game|UI|Data|Persistence|Resources
StrikeTests/ StrikeUITests/
art/prompts/ art/raw/     AI image prompts and raw generated images
tools/                    Python asset scripts
```

## Commands
```
xcodegen generate
xcodebuild -project Strike.xcodeproj -scheme Strike -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M5)' build
xcodebuild -project Strike.xcodeproj -scheme Strike -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M5)' test
```

XcodeGen lives at `~/.local/opt/xcodegen-dl/xcodegen/bin/xcodegen` (not on PATH). Add `,OS=latest` to simulator destinations.

**Parallel agents:** each agent builds with its own `-derivedDataPath build/DerivedData-<agent>` and, when running tests in parallel with others, its own simulator. Sharing one makes runs die with "signal kill". After the slicer writes into an `.atlas` folder, its mtime must change (the slicer does this); otherwise Xcode keeps stale textures.

## Hard rules
- No blood, gore, or realistic guns. Enemies "power down" into sparkles and loot.
- No networking, analytics, ads, IAP, or third-party SDKs.
- Balance numbers live in `Strike/Resources/Data/*.json`, never in code.
- All UI text goes through `Localizable.xcstrings` (de, en).
