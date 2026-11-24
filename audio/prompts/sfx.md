# SFX descriptions (synthesized by tools/synth_sfx.py; Lyria attempt rejected)

Parsed by `tools/gen_audio.py` and `tools/process_audio.py`. Lyria is a music model and returns clips of about 30 s;
`process_audio.py` cuts the strongest sound (first transient) of at most `MaxLen` seconds. The generator appends the
shared SFX suffix (isolated, dry, no music) to every prompt. Kind is always `sfx`.

Shared suffix: Single short sound effect, isolated, dry, no music, no melody, no vocals, no speech, no background noise, no reverb tail, soft and friendly, not harsh, not loud. Cartoon video-game style.

## sfx_shot_starter

- **File:** sfx_shot_starter
- **Kind:** sfx
- **MaxLen:** 0.3

```text
Cute toy laser blaster shot, short bright 'pew', a quick downward pitch zap with a little sparkle, like a toy ray gun. Not a realistic gunshot.
```

## sfx_shot_spread

- **File:** sfx_shot_spread
- **Kind:** sfx
- **MaxLen:** 0.45

```text
Bubble blaster shot, a soft bubbly 'bloop-pop-pop' burst of several quick water bubbles popping outward. Playful, wet and squishy, not a realistic gunshot.
```

## sfx_shot_rapid

- **File:** sfx_shot_rapid
- **Kind:** sfx
- **MaxLen:** 0.18

```text
Tiny foam pellet shot, a very short soft 'pfft' pop like a toy foam dart gun. Very short and light, repeatable.
```

## sfx_shot_enemy

- **File:** sfx_shot_enemy
- **Kind:** sfx
- **MaxLen:** 0.35

```text
Robot enemy toy blaster shot, a low-pitched boingy 'bwoop' zap, slightly comical, softer than a laser.
```

## sfx_alert

- **File:** sfx_alert
- **Kind:** sfx
- **MaxLen:** 0.5

```text
Cartoon alert sound for a robot noticing the hero, a quick two-note rising 'bi-doing!' blip like an exclamation mark. Cute, not alarming.
```

## sfx_powerdown_poof

- **File:** sfx_powerdown_poof
- **Kind:** sfx
- **MaxLen:** 0.9

```text
Cheerful poof of a robot powering down into sparkles: a descending 'wheeoo' wind-down followed by a soft puff and twinkling glittery chimes. Happy, not violent.
```

## sfx_hit_enemy

- **File:** sfx_hit_enemy
- **Kind:** sfx
- **MaxLen:** 0.2

```text
Soft bouncy hit on a toy robot, a short rubbery 'boing-tick' like tapping a plastic toy. Light and friendly.
```

## sfx_hero_hurt

- **File:** sfx_hero_hurt
- **Kind:** sfx
- **MaxLen:** 0.45

```text
Gentle cartoon 'oof' bonk sound for a hero bumped by a toy, a soft thud with a little wobbly descending whistle. Not painful, no voice, no scream.
```

## sfx_rescue_teleport

- **File:** sfx_rescue_teleport
- **Kind:** sfx
- **MaxLen:** 1.6

```text
Magical teleport rescue sound, a rising shimmering sweep of sparkly synth chimes that lands with a soft 'ding'. Warm and reassuring.
```

## sfx_reload

- **File:** sfx_reload
- **Kind:** sfx
- **MaxLen:** 0.8

```text
Toy blaster reload: a cute mechanical 'click-clack-ching' of a plastic magazine snapping in, light and crisp.
```

## sfx_empty_click

- **File:** sfx_empty_click
- **Kind:** sfx
- **MaxLen:** 0.15

```text
Tiny dry plastic 'tk' click of an empty toy blaster trigger. Very quiet and short.
```

## sfx_pickup_ammo

- **File:** sfx_pickup_ammo
- **Kind:** sfx
- **MaxLen:** 0.5

```text
Ammo pickup: a quick cheerful 'ka-ching' chiptune blip with two rising notes and a tiny rattle.
```

## sfx_pickup_heal

- **File:** sfx_pickup_heal
- **Kind:** sfx
- **MaxLen:** 0.9

```text
Healing pickup: a warm gentle rising 'ding-ling' chime arpeggio, soft and soothing with a sparkly tail.
```

## sfx_pickup_item

- **File:** sfx_pickup_item
- **Kind:** sfx
- **MaxLen:** 0.6

```text
Item pickup: a bright happy two-note 'pling-pling' glockenspiel blip, short and sweet.
```

## sfx_pickup_bolt

- **File:** sfx_pickup_bolt
- **Kind:** sfx
- **MaxLen:** 0.25

```text
Collecting a small metal bolt coin: a tiny high 'tink' ping, bright and short, like a coin in a retro game.
```

## sfx_button_press

- **File:** sfx_button_press
- **Kind:** sfx
- **MaxLen:** 0.35

```text
Big floor button pressed: a chunky satisfying 'ka-chunk' plastic click with a small happy beep after it.
```

## sfx_lever_pull

- **File:** sfx_lever_pull
- **Kind:** sfx
- **MaxLen:** 0.7

```text
Cartoon lever being pulled: a chunky 'clack-ka-chunk' of a big toy lever flipping with a short spring 'boing'.
```

## sfx_plate_on

- **File:** sfx_plate_on
- **Kind:** sfx
- **MaxLen:** 0.5

```text
Pressure plate activated: a soft low 'thunk' followed by a rising two-note confirmation chime. Friendly.
```

## sfx_machine_on

- **File:** sfx_machine_on
- **Kind:** sfx
- **MaxLen:** 1.8

```text
A machine powering up: a cute whirring spin-up of servos rising in pitch with a few happy beeps, ending with a steady soft hum start. Toy-like.
```

## sfx_door_open

- **File:** sfx_door_open
- **Kind:** sfx
- **MaxLen:** 1.5

```text
Sliding sci-fi door opening: a smooth soft 'shhhk-whoosh' slide with a pleasant rising two-note chime. Gentle, not loud.
```

## sfx_gate_unlocked

- **File:** sfx_gate_unlocked
- **Kind:** sfx
- **MaxLen:** 1.2

```text
Gate unlocked: a satisfying 'clunk-click' unlock then a bright sparkling ascending chime. Triumphant but small.
```

## sfx_checkpoint

- **File:** sfx_checkpoint
- **Kind:** sfx
- **MaxLen:** 1.2

```text
Checkpoint activated: a warm bright three-note rising chime 'ding-ding-dingg' with a soft sparkle, calm and happy.
```

## sfx_crate_break

- **File:** sfx_crate_break
- **Kind:** sfx
- **MaxLen:** 0.7

```text
Cardboard toy crate bursting open: a light 'crunch-pop' with little cartoonish clatter and tiny bounces, soft and playful.
```

## sfx_ui_tap

- **File:** sfx_ui_tap
- **Kind:** sfx
- **MaxLen:** 0.15

```text
Menu button tap: a short soft rounded 'pop-tick' UI click, friendly and clean.
```

## sfx_ui_back

- **File:** sfx_ui_back
- **Kind:** sfx
- **MaxLen:** 0.2

```text
Menu back button: a short soft downward two-note 'bu-bup' UI blip, gentle.
```

## sfx_level_start

- **File:** sfx_level_start
- **Kind:** sfx
- **MaxLen:** 1.5

```text
Level start whoosh: a quick upward sparkle sweep with a bright 'ta-da' two-note chiptune sting, energetic and happy.
```

## sfx_pixel_beep_1

- **File:** sfx_pixel_beep_1
- **Kind:** sfx
- **MaxLen:** 0.5

```text
Cute little robot drone 'talking': a chirpy sequence of 3 to 4 quick rising electronic beeps and warbles like a friendly R2-style droid saying hi. High-pitched, happy.
```

## sfx_pixel_beep_2

- **File:** sfx_pixel_beep_2
- **Kind:** sfx
- **MaxLen:** 0.5

```text
Cute little robot drone 'talking': a curious two-part 'bee-doo-bee' beeping with a questioning rise at the end. High-pitched and friendly.
```

## sfx_pixel_beep_3

- **File:** sfx_pixel_beep_3
- **Kind:** sfx
- **MaxLen:** 0.5

```text
Cute little robot drone 'talking': a bubbly fast trill of tiny beeps and a happy chirp, excited and cheerful. High-pitched.
```
