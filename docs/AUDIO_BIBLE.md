# Strike Audio Bible

Music is generated with Google AI Studio (Lyria 3.5 via the Gemini API, owner's key). **Sound effects are synthesized by our own script** (`tools/synth_sfx.py`): Lyria returned short music pieces, not effects, so the owner switched SFX to code (see `docs/DECISIONS.md`). No third-party audio. Pixel has no voice: it "talks" with beeps (SFX).

## Style
- Bright chiptune / anime-pop, 110-140 BPM, 4/4, mostly major keys. Playful, never aggressive.
- L5 (OVERMIND Core) and the boss are "goofy-evil": minor key, bouncy staccato bass, silly organ/brass. Cartoon villain, never scary.
- Blasters sound like toys: pew, bubble, foam. No realistic gunshots, no explosions.
- Hits are soft and bouncy. Power-downs are a cheerful "poof" with sparkles. No blood, no screams, no grunts.
- No horror stingers, no harsh or sudden loud sounds, no speech or vocals.

## Technical targets
| Item | Target |
|---|---|
| Sample rate | 48 kHz |
| Music | `.m4a` AAC 128 kbps, about -20 dBFS RMS (about -18 LUFS), peak below -1 dBFS |
| SFX | `.caf` 16-bit PCM, peak -3 dBFS, 5 ms fade in, 10 ms fade out, trimmed at -50 dB |
| Loops | whole bars (4/4 from BPM), 50 ms equal-power crossfade of the tail into the head, zero-crossing aligned |
| Naming | music id `music_<name>` (matches `levels.json`), file `mus_<name>.m4a`; SFX id and file `sfx_<name>` (`.caf`) |

Pipeline: music: `tools/gen_audio.py` (raw WAV in `audio/raw/`) then `tools/process_audio.py`. SFX: `tools/synth_sfx.py` (raw WAV in `audio/raw/`) then `tools/process_audio.py`. Output goes to `Strike/Resources/Audio/`. The rejected Lyria SFX attempts are kept in `audio/raw/_lyria_sfx_rejected/`. Loudness is an RMS approximation of LUFS, not a K-weighted measurement.

## Music (9)
Music ids equal the `music` / `bossMusic` values in `levels.json`. Prompts: `audio/prompts/music.md`.

| Id | File | Kind | BPM | Target s | Volume |
|---|---|---|---|---|---|
| `music_title` | mus_title.m4a | loop | 120 | 64 | 0.9 |
| `music_rooftop` | mus_l1.m4a | loop | 124 | 76 | 0.8 |
| `music_factory` | mus_l2.m4a | loop | 120 | 76 | 0.8 |
| `music_greenhouse` | mus_l3.m4a | loop | 112 | 80 | 0.8 |
| `music_server` | mus_l4.m4a | loop | 132 | 80 | 0.8 |
| `music_core` | mus_l5.m4a | loop | 136 | 84 | 0.8 |
| `music_boss` | mus_boss.m4a | loop | 140 | 64 | 0.85 |
| `music_level_complete` | mus_level_complete.m4a | jingle | 120 | 4 | 0.9 |
| `music_season_complete` | mus_season_complete.m4a | jingle | 120 | 8 | 0.9 |

Level mapping: L1 `music_rooftop` (sunny, G major), L2 `music_factory` (clockwork march, D major), L3 `music_greenhouse` (bubbly marimba, F major), L4 `music_server` (neon synth-pop), L5 `music_core` (goofy-evil D minor), boss `music_boss` (A minor, urgent but silly). Title `music_title` (hero theme). Jingles play once with the level music ducked.

Playback timing lives in `audio.json` `music`: `crossfadeSec` 1.5 between loops, `fadeInSec` 0.8, `fadeOutSec` 1.0, `jingleDuckLevel` 0.2 with `duckAttackSec` 0.2 / `duckReleaseSec` 1.2.

## SFX (29)
Recipes: `RECIPES` in `tools/synth_sfx.py`; `audio/prompts/sfx.md` keeps the id list, `MaxLen` and the original descriptions. Per-id numbers in `Strike/Resources/Data/audio.json` (never in code). Pitch variance is a +-fraction applied per play (against repetition); max voices caps simultaneous plays of one id; cooldown is the minimum gap between plays.

| Id | File | Volume | Pitch var | Max voices | Cooldown s |
|---|---|---|---|---|---|
| `sfx_shot_starter` | sfx_shot_starter.caf | 0.7 | 0.05 | 4 | 0.05 |
| `sfx_shot_spread` | sfx_shot_spread.caf | 0.7 | 0.05 | 3 | 0.12 |
| `sfx_shot_rapid` | sfx_shot_rapid.caf | 0.5 | 0.06 | 6 | 0.04 |
| `sfx_shot_enemy` | sfx_shot_enemy.caf | 0.55 | 0.05 | 3 | 0.1 |
| `sfx_alert` | sfx_alert.caf | 0.6 | 0.02 | 2 | 0.4 |
| `sfx_powerdown_poof` | sfx_powerdown_poof.caf | 0.75 | 0.04 | 4 | 0.08 |
| `sfx_hit_enemy` | sfx_hit_enemy.caf | 0.6 | 0.05 | 5 | 0.04 |
| `sfx_hero_hurt` | sfx_hero_hurt.caf | 0.7 | 0.03 | 2 | 0.3 |
| `sfx_rescue_teleport` | sfx_rescue_teleport.caf | 0.75 | 0.0 | 1 | 0.5 |
| `sfx_reload` | sfx_reload.caf | 0.6 | 0.02 | 1 | 0.2 |
| `sfx_empty_click` | sfx_empty_click.caf | 0.45 | 0.03 | 1 | 0.15 |
| `sfx_pickup_ammo` | sfx_pickup_ammo.caf | 0.65 | 0.03 | 2 | 0.08 |
| `sfx_pickup_heal` | sfx_pickup_heal.caf | 0.7 | 0.0 | 1 | 0.2 |
| `sfx_pickup_item` | sfx_pickup_item.caf | 0.65 | 0.03 | 2 | 0.08 |
| `sfx_pickup_bolt` | sfx_pickup_bolt.caf | 0.55 | 0.06 | 4 | 0.03 |
| `sfx_button_press` | sfx_button_press.caf | 0.7 | 0.02 | 2 | 0.1 |
| `sfx_lever_pull` | sfx_lever_pull.caf | 0.7 | 0.02 | 1 | 0.2 |
| `sfx_plate_on` | sfx_plate_on.caf | 0.65 | 0.0 | 1 | 0.2 |
| `sfx_machine_on` | sfx_machine_on.caf | 0.7 | 0.0 | 1 | 0.5 |
| `sfx_door_open` | sfx_door_open.caf | 0.75 | 0.0 | 1 | 0.5 |
| `sfx_gate_unlocked` | sfx_gate_unlocked.caf | 0.75 | 0.0 | 1 | 0.5 |
| `sfx_checkpoint` | sfx_checkpoint.caf | 0.7 | 0.0 | 1 | 0.5 |
| `sfx_crate_break` | sfx_crate_break.caf | 0.7 | 0.05 | 3 | 0.1 |
| `sfx_ui_tap` | sfx_ui_tap.caf | 0.6 | 0.02 | 2 | 0.05 |
| `sfx_ui_back` | sfx_ui_back.caf | 0.6 | 0.02 | 2 | 0.05 |
| `sfx_level_start` | sfx_level_start.caf | 0.7 | 0.0 | 1 | 0.5 |
| `sfx_pixel_beep_1` | sfx_pixel_beep_1.caf | 0.6 | 0.04 | 1 | 0.1 |
| `sfx_pixel_beep_2` | sfx_pixel_beep_2.caf | 0.6 | 0.04 | 1 | 0.1 |
| `sfx_pixel_beep_3` | sfx_pixel_beep_3.caf | 0.6 | 0.04 | 1 | 0.1 |

Groups: hero blasters (3), enemies (3), hits (2), hero (3), pickups (4), puzzle (8), UI (3), Pixel beeps (3).

## Rules for new assets
1. Add a prompt entry (`## <id>` with File/Kind/BPM or MaxLen and a ```text prompt block).
2. Add the id to `audio.json`.
3. Generate, process, check `process_audio.py --report` (duration, peak, RMS, loop seam, silence share).
4. Measurements only: reports are analysis, not listening. Owner listens on the iPad.

## SFX synthesis notes (`tools/synth_sfx.py`)
Pure stdlib, mono 48 kHz, deterministic (noise seeded by a CRC of the id). Toolkit: square (duty) / saw / triangle / sine / noise oscillators, exponential pitch glides, arpeggios (`notes` + `step`), vibrato, ADSR with snappy quadratic decay, swept one-pole low/high-pass, bit-crush, feedback echo. Master chain: 7.5 kHz low-pass (no harsh highs), 30 Hz DC blocker, 3 ms fade in, 15 ms fade out, peak -3 dBFS. Each clip stays within its `MaxLen`.

| Sound | Recipe idea |
|---|---|
| Starter shot | square (duty .25) + triangle, fast downward glide 1500 to 320 Hz, high sine sparkle ("pew") |
| Bubble blaster | three rising sine "bloops" 75 ms apart with soft noise puffs |
| Foam blaster | 70 ms square (duty .125) glide plus a short noise puff ("pfft-tick") |
| Enemy shot | triangle 320 to 170 Hz with 24 Hz vibrato: wobbly lower blip |
| Alert | square C6 then G6 plus a sine ding, light echo ("!") |
| Power-down poof | descending square, noise puff, rising sparkle arpeggio C7 to E8 with echo |
| Hit / hurt | rubbery sine+triangle "boing-tick"; hurt is a wobbly falling triangle with a soft thump, no voice |
| Rescue teleport | sine sweep 300 to 2400 Hz, triangle pentatonic run, final ding, echo |
| Reload / empty | click (noise), clack (triangle thud), "ching" (sine 3136 Hz); empty is a tiny dry tick |
| Pickups | ammo: two-note square coin; heal: sine arpeggio C5 to C6 with echo; item: square+sine C6 G6 C7; bolt: inharmonic sine clink |
| Puzzle | button: thunk plus beep; lever: clack, chunk, spring boing; plate: thunk plus two notes; machine: saw/square spin-up 60 to 240 Hz, beeps, hum; door: noise slide with chime; gate: clunk, click, six-note arpeggio; checkpoint: three-note chime; crate: noise burst plus seeded clatter |
| UI / level start | soft sine pops; start: rising saw sweep, four-note fanfare, held triad |
| Pixel beeps | square+vibrato sine chirps with glides: rising run, "bee-doo-bee", trill |
