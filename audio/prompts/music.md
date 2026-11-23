# Music prompts (Lyria 3)

Parsed by `tools/gen_audio.py` and `tools/process_audio.py`. One `## <id>` entry per track; fields are `- **Name:** value`; the prompt is the ```text block.
The generator appends no extra text for music except the `--note` correction. Ids match `levels.json` `music` / `bossMusic`.
Kind `loop` = seamless loop (processed to a bar boundary with a crossfade). Kind `jingle` = one-shot.

## music_title

- **File:** mus_title
- **Kind:** loop
- **BPM:** 120
- **Length:** 64
- **Mood:** hero theme, major, C major

```text
Bright anime-pop chiptune title theme for a kids' top-down shooter game. Tempo 120 BPM, 4/4, C major. Hopeful, adventurous and playful: square-wave lead melody, bouncy bass, light drum machine, glockenspiel sparkles. Steady loop-friendly arrangement, constant energy, no big intro, no fade-out, ends on a phrase that flows back to the start. Instrumental only, no vocals, no spoken words. Cheerful and kid-friendly, no scary sounds, no harsh or sudden loud hits, soft dynamics, even volume throughout. Approximate length 64 seconds.
```

## music_rooftop

- **File:** mus_l1
- **Kind:** loop
- **BPM:** 124
- **Length:** 76
- **Mood:** sunny, major, G major

```text
Sunny chiptune anime-pop gameplay loop for a city rooftop level in a kids' game. Tempo 124 BPM, 4/4, G major. Light and breezy: plucky square-wave arpeggios, bouncy bass, soft hi-hat groove, handclaps, a happy simple melody. Relaxed tutorial feel. Constant energy, no intro, no fade-out, loops seamlessly. Instrumental only, no vocals, no spoken words. Cheerful and kid-friendly, no scary sounds, no harsh or sudden loud hits, soft dynamics, even volume throughout. Approximate length 76 seconds.
```

## music_factory

- **File:** mus_l2
- **Kind:** loop
- **BPM:** 120
- **Length:** 76
- **Mood:** warm, major, D major

```text
Playful chiptune gameplay loop for a toy robot factory level in a kids' game. Tempo 120 BPM, 4/4, D major. Marching rhythm, rhythmic clanks and ticks used as percussion, bouncy bass, bright pulse-wave melody, xylophone accents. Warm, busy and funny, like clockwork toys. Constant energy, no intro, no fade-out, loops seamlessly. Instrumental only, no vocals, no spoken words. Cheerful and kid-friendly, no scary sounds, no harsh or sudden loud hits, soft dynamics, even volume throughout. Approximate length 76 seconds.
```

## music_greenhouse

- **File:** mus_l3
- **Kind:** loop
- **BPM:** 112
- **Length:** 80
- **Mood:** wobbly, major, F major

```text
Wobbly bubbly chiptune gameplay loop for a magical greenhouse laboratory level in a kids' game. Tempo 112 BPM, 4/4, F major. Marimba and bubble-pop synth plucks, gently wobbling bass, soft shaker groove, curious and silly mood with a touch of mystery but always friendly. Constant energy, no intro, no fade-out, loops seamlessly. Instrumental only, no vocals, no spoken words. Cheerful and kid-friendly, no scary sounds, no harsh or sudden loud hits, soft dynamics, even volume throughout. Approximate length 80 seconds.
```

## music_server

- **File:** mus_l4
- **Kind:** loop
- **BPM:** 132
- **Length:** 80
- **Mood:** neon, major-ish, A minor friendly

```text
Neon synth-pop chiptune gameplay loop for a glowing computer-server fortress level in a kids' game. Tempo 132 BPM, 4/4, E major with playful minor touches. Sparkling arpeggios, punchy but soft kick, bright digital bleeps, upbeat and determined, adventurous not dark. Constant energy, no intro, no fade-out, loops seamlessly. Instrumental only, no vocals, no spoken words. Cheerful and kid-friendly, no scary sounds, no harsh or sudden loud hits, soft dynamics, even volume throughout. Approximate length 80 seconds.
```

## music_core

- **File:** mus_l5
- **Kind:** loop
- **BPM:** 136
- **Length:** 84
- **Mood:** goofy-evil, minor, D minor

```text
Goofy-evil cartoon villain chiptune gameplay loop for the final level of a kids' game. Tempo 136 BPM, 4/4, D minor. Bouncy staccato bass, silly pipe-organ and harpsichord-style lead, comical tuba-like oom-pah, playful drums. Mischievous and funny like a cartoon supervillain's lair, NOT scary or dark. Constant energy, no intro, no fade-out, loops seamlessly. Instrumental only, no vocals, no spoken words. Cheerful and kid-friendly, no scary sounds, no harsh or sudden loud hits, soft dynamics, even volume throughout. Approximate length 84 seconds.
```

## music_boss

- **File:** mus_boss
- **Kind:** loop
- **BPM:** 140
- **Length:** 64
- **Mood:** goofy-evil, minor, A minor, urgent

```text
Energetic goofy-evil boss battle chiptune loop for a kids' game, a giant silly robot fight. Tempo 140 BPM, 4/4, A minor. Driving bouncy bass, fast pulse-wave arpeggios, comical brass stabs, snappy drums, exciting and urgent but playful and cartoonish, NOT scary or aggressive. Constant energy, no intro, no fade-out, loops seamlessly. Instrumental only, no vocals, no spoken words. Cheerful and kid-friendly, no scary sounds, no harsh or sudden loud hits, soft dynamics, even volume throughout. Approximate length 64 seconds.
```

## music_level_complete

- **File:** mus_level_complete
- **Kind:** jingle
- **BPM:** 120
- **Length:** 4
- **Mood:** victory, major

```text
Short triumphant victory jingle for a kids' game level complete, about 4 seconds. Tempo 120 BPM, C major. Sparkly rising fanfare of chiptune brass and glockenspiel, ends on a clear happy final chord, then a short natural decay. Instrumental, no vocals. Instrumental only, no vocals, no spoken words. Cheerful and kid-friendly, no scary sounds, no harsh or sudden loud hits, soft dynamics, even volume throughout. Approximate length 4 seconds.
```

## music_season_complete

- **File:** mus_season_complete
- **Kind:** jingle
- **BPM:** 120
- **Length:** 8
- **Mood:** grand victory, major

```text
Joyful grand finale celebration jingle for a kids' game, the hero saved the world, about 8 seconds. Tempo 120 BPM, C major. Chiptune fanfare, sparkling glockenspiel runs, cheerful drums, builds up and ends on a big happy final chord with a gentle decay. Instrumental, no vocals. Instrumental only, no vocals, no spoken words. Cheerful and kid-friendly, no scary sounds, no harsh or sudden loud hits, soft dynamics, even volume throughout. Approximate length 8 seconds.
```
