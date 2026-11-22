# Art licenses and provenance

Rule: never commit an image whose license is unclear. One row per raw batch (`art/raw/<group_key>/`). Before App Store submission every row must be "cleared".

Generator terms checklist (verify per tool, per date): commercial use allowed? Kids/App Store distribution allowed? Output ownership/attribution required? Subscription tier at generation time?

| Date | Batch / group keys | Generator tool + version/model | Plan / account tier | Prompt file | Commercial use OK? | Attribution needed | Reviewed by | Status |
|---|---|---|---|---|---|---|---|---|
| YYYY-MM-DD | e.g. hero_* | e.g. (tool name, model) | e.g. paid | art/prompts/hero.md | yes/no | none / text | name | pending / cleared |
| (fill at generation) | art/raw/*.png, prompts #1-35 | Gemini API (Google), image model auto-picked by `tools/gen_art.py`; exact model name cached in `art/raw/.gen_model` and per-call log in `art/raw/.gen_log.jsonl` | owner's own API key (free or paid tier: record which) | art/prompts/gemini/PROMPTS.md | verify Google Gemini API terms for commercial/kids use | none expected (verify; Gemini may add a SynthID watermark invisibly) | owner | pending |

## Placeholders
`tools/make_placeholders.py` output is original, procedurally generated, and public-domain-equivalent (CC0) project work.

## Other assets
| Asset | Source | License | Link / proof |
|---|---|---|---|
| App icon | | | |
| Fonts | | | |
| Sounds / music | | | |

## Gemini API generation (note)
Images in `art/raw/` are generated via the Gemini API using the owner's API key (`GEMINI_API_KEY`, never stored in the repo), driven by `tools/gen_art.py`. After each generation run, record the date, the model name (see `art/raw/.gen_model`) and the account tier in the table above. The manual Gemini app route (PROMPTS.md) uses the same prompts and the same row. Status stays "pending" until the owner confirms the Google terms for commercial and App Store Kids use.
