# Tasks

## M0 Setup
- [x] M0-1 Create agents, CLAUDE.md, git, docs skeleton (main session)
- [x] M0-2 game-designer: write `docs/GDD.md` incl. data schemas + `docs/levels/L1–L5.md`
- [x] M0-3 visual-artist: write `docs/ART_BIBLE.md` + placeholder generator
- [x] M0-4 swift-coder: `project.yml`, empty SwiftUI+SpriteView app, landscape, builds on simulator
- [ ] M0-5 qa-tester: test targets run (smoke test green)
- [ ] M0-6 game-manager: review M0, plan M1 tasks

## Art (Gemini lite set)
- [x] ART-1 visual-artist: manifest LITE + SHEETS, 5 new assets (bolt, datachip, crate, checkpoint, exitpad) with placeholders
- [x] ART-2 visual-artist: `art/prompts/gemini/PROMPTS.md` (~35 copy-paste prompts) + Artifact page with copy buttons
- [x] ART-3 visual-artist: Gemini-proof slicer (auto background, despill, watermark removal, blob split, seamless tiles, app icon) + `tools/test_slice.py`
- [x] ART-4 Claude: generate images via Gemini API (`tools/gen_art.py`); owner picked hero v1 (43 calls)
- [x] ART-5 sliced all 35 sheets; regenerated #14, #35
- [ ] ART-6 visual-artist: make slicer derive `ui_icon_blaster_*` from `pickup_blaster_*` (currently copied by hand; re-slicing `ui_icons_b` would bring back gun-like icons). Optional: polish `proj_starter` green fringe, Pixel glow tint

## M1 (planned)
- [ ] M1-x swift-coder: `PoseAnimator` component (idle bob, walk squash/tilt, hit flash/shake, shoot recoil, xScale facing; uses frame animations if present in the atlas) + hit/poof particle emitters

## Questions for the owner
- Final title and character names (designer proposed options in GDD §19)
- Gemini commercial-use terms for generated images (owner to confirm)
- Music/SFX source (default: CC0 packs)
- Apple Developer account for device/TestFlight builds?
- Minimum iPad model (default iPadOS 18, iPad 9th gen+)
