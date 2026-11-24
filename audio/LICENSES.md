# Audio licenses and provenance

## Music (9 tracks in `Strike/Resources/Audio/mus_*.m4a`)
AI-generated with Google AI Studio, Lyria 3.5 (`lyria-3.5`) through the Gemini API, using the project owner's own API key. Prompts are in `audio/prompts/music.md`; every call is logged (no key) in `audio/raw/.gen_log.jsonl`. Generated November 2026. Processed (trim, loop crossfade, loudness normalization, AAC) with `tools/process_audio.py`.
- Google marks Lyria output with SynthID, an inaudible watermark. Do not try to remove it.
- Usage rights follow the Gemini API / Google AI Studio terms for generated output as accepted by the owner. Owner to confirm commercial App Store use under the terms current at release time.

## Sound effects (29 files, `Strike/Resources/Audio/sfx_*.caf`)
Original. Synthesized by our own script `tools/synth_sfx.py` (pure Python, oscillators and filters, no samples, no AI model). Copyright is the project's own. Early Lyria SFX attempts were rejected and are not used (kept only in `audio/raw/_lyria_sfx_rejected/`).

## General
No third-party samples, no recorded voices, no text-to-speech. `audio/raw/` holds working files; only the processed files in `Strike/Resources/Audio/` ship.
