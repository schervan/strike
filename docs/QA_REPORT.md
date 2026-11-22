# QA Report

## M0 - Project skeleton and data (2026-11-22)

### Commands
```
~/.local/opt/xcodegen-dl/xcodegen/bin/xcodegen generate
xcodebuild -project Strike.xcodeproj -scheme Strike \
  -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M5),OS=latest' \
  -derivedDataPath build/DerivedData test
```

### Results: TEST SUCCEEDED
- Swift Testing (StrikeTests): 8 tests in 2 suites, 8 passed, 0 failed (the 6-case texture test counts as one test).
  - StrikeSmokeTests (3): model switching, placeholder scene, de/en localizations.
  - DataIntegrityTests (5, new, `StrikeTests/DataIntegrityTests.swift`): all 5 JSON files parse (JSONSerialization) and carry `version`; cross-references resolve (weapon `ammoId` -> items, enemy `lootTableId` -> loot tables, loot `itemId` -> items, levels `itemId` / `enemyId` / `lootTableId`, 5 levels present); 6 sample textures load with non-zero size; all 9 atlases non-empty; bundle localizations contain de and en.
- XCUITest (StrikeUITests): 1 test, 0 failures.

### Kid-safety grep over Strike/
- Network/analytics/ads/IAP/web (`URLSession`, `import Network`, `NWConnection`, Firebase, Analytics, AdSupport, StoreKit, WKWebView, openURL, SafariServices) in Swift sources: 0 occurrences.
- Whole words blood, kill, die, dead, death, gore, gun in Localizable.xcstrings and Data/*.json: 0 occurrences. ("weapon" appears only as item category and nameKey prefix; blaster naming is fine.)
- Not yet covered: art content review, touch-target sizes, parental gate (no UI exists yet).

### Findings (non-blocking)
- QA-001 (low, info): Atlases ship only `@2x` PNGs. `SKTextureAtlas.textureNames` reports names with the `@2x.png` suffix, while `textureNamed("hero_idle_01")` still resolves with non-zero size. Code should look textures up by the plain name; tests accept both forms. Suspected: art pipeline in `Strike/Resources/Atlases/`.
- QA-002 (info): Localization test only checks bundle localizations (de, en). A per-key de/en completeness test is deferred until the string catalog has real UI keys (M1+).

### Open bugs
None.
