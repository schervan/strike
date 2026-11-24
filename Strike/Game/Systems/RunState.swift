import Foundation

/// Settings → "Pixel talk" (GDD §13): `lots` = everything, `some` = story + hints, `quiet` = story only.
nonisolated enum PixelTalk: String, Codable, Sendable, CaseIterable {
    case lots, some, quiet
}

/// Gameplay settings kept in the save (DECISIONS: the Settings screen for them is M5). Audio
/// volumes stay in `SettingsStore` / UserDefaults.
nonisolated struct RunSettings: Codable, Sendable, Equatable {
    var pixelTalk: PixelTalk
    var aimAssist: Bool

    init(pixelTalk: PixelTalk = .lots, aimAssist: Bool) {
        self.pixelTalk = pixelTalk
        self.aimAssist = aimAssist
    }

    enum CodingKeys: String, CodingKey { case pixelTalk, aimAssist }

    /// Missing or unknown values take the GDD §16.10 defaults (lots, aim assist on).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        pixelTalk = (try? c.decodeIfPresent(PixelTalk.self, forKey: .pixelTalk)) ?? .lots
        aimAssist = (try? c.decodeIfPresent(Bool.self, forKey: .aimAssist)) ?? true
    }
}

/// Best result of one level (GDD §16.10): each field is the best independently.
nonisolated struct LevelBest: Codable, Sendable, Equatable {
    /// The 3 stars of §15 (M5), OR-merged.
    var stars: [Bool]
    var bestScore: Int
    var bestTimeSec: Int
    var datachips: Int
    var fewestRescues: Int

    init(stars: [Bool] = [], bestScore: Int, bestTimeSec: Int, datachips: Int, fewestRescues: Int) {
        self.stars = stars
        self.bestScore = bestScore
        self.bestTimeSec = bestTimeSec
        self.datachips = datachips
        self.fewestRescues = fewestRescues
    }

    enum CodingKeys: String, CodingKey { case stars, bestScore, bestTimeSec, datachips, fewestRescues }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        stars = try c.decodeIfPresent([Bool].self, forKey: .stars) ?? []
        bestScore = try c.decodeIfPresent(Int.self, forKey: .bestScore) ?? 0
        bestTimeSec = try c.decodeIfPresent(Int.self, forKey: .bestTimeSec) ?? Int.max
        datachips = try c.decodeIfPresent(Int.self, forKey: .datachips) ?? 0
        fewestRescues = try c.decodeIfPresent(Int.self, forKey: .fewestRescues) ?? Int.max
    }

    mutating func merge(_ o: LevelBest) {
        let n = max(stars.count, o.stars.count)
        stars = (0..<n).map { (stars.indices.contains($0) && stars[$0]) || (o.stars.indices.contains($0) && o.stars[$0]) }
        bestScore = max(bestScore, o.bestScore)
        bestTimeSec = min(bestTimeSec, o.bestTimeSec)
        datachips = max(datachips, o.datachips)
        fewestRescues = min(fewestRescues, o.fewestRescues)
    }
}

/// Everything that carries over between levels (GDD §7 persistence, §16.10; DECISIONS: no
/// mid-level state). Lives in `GameModel.run` and is saved through `SaveStore`.
nonisolated struct RunState: Codable, Sendable, Equatable {
    var loadout: Loadout
    var inventory: Inventory
    /// Highest level index (1-based) the player may start.
    var unlockedLevelIndex: Int
    /// Level that "Continue" starts: the one in progress, or the next after a level complete
    /// (the last level stays current after it is complete). Nil before the first level.
    var currentLevelId: String?
    var bestResults: [String: LevelBest]
    var settings: RunSettings

    init(loadout: Loadout, inventory: Inventory, unlockedLevelIndex: Int = 1, currentLevelId: String? = nil,
         bestResults: [String: LevelBest] = [:], settings: RunSettings) {
        self.loadout = loadout
        self.inventory = inventory
        self.unlockedLevelIndex = unlockedLevelIndex
        self.currentLevelId = currentLevelId
        self.bestResults = bestResults
        self.settings = settings
    }

    enum CodingKeys: String, CodingKey {
        case loadout, inventory, unlockedLevelIndex, currentLevelId, bestResults, settings
    }

    /// Missing optional fields take their defaults (GDD §16.10); `loadout` is required.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        loadout = try c.decode(Loadout.self, forKey: .loadout)
        inventory = try c.decodeIfPresent(Inventory.self, forKey: .inventory)
            ?? Inventory(items: [:], slotCount: 0, quickCount: 0)
        unlockedLevelIndex = try c.decodeIfPresent(Int.self, forKey: .unlockedLevelIndex) ?? 1
        currentLevelId = try c.decodeIfPresent(String.self, forKey: .currentLevelId)
        bestResults = try c.decodeIfPresent([String: LevelBest].self, forKey: .bestResults) ?? [:]
        settings = try c.decodeIfPresent(RunSettings.self, forKey: .settings) ?? RunSettings(aimAssist: true)
    }

    /// Fresh run: hero start loadout, empty bag, L1 unlocked. `settings` survive "New game".
    static func newGame(data: GameData, keeping settings: RunSettings? = nil) -> RunState {
        RunState(loadout: Loadout(start: data.hero.startLoadout, weapons: data.weapons),
                 inventory: Inventory(items: data.items, rules: data.rules.inventory),
                 unlockedLevelIndex: data.levelOrder.first?.index ?? 1,
                 settings: settings ?? RunSettings(aimAssist: data.controls.aimAssistDefaultOn))
    }

    /// Re-attaches `items.json` / `weapons.json` rules after decoding a save and repairs what no
    /// longer fits them. Call once after `SaveStore.load()`.
    mutating func bind(to data: GameData) {
        inventory.bind(items: data.items, rules: data.rules.inventory)
        loadout.bind(weapons: data.weapons, starterId: data.hero.startLoadout.weaponId)
        let maxIndex = data.levelOrder.last?.index ?? 1
        unlockedLevelIndex = min(max(1, unlockedLevelIndex), maxIndex)
        if let id = currentLevelId, data.levels[id] == nil { currentLevelId = nil }
    }

    /// Level start (GDD §16.10, §5.1): puzzle items from another layout are removed, each start-gift
    /// item is topped up to its count (never more), and the starter blaster gets at least the
    /// start loadout's magazine and reserve.
    mutating func startLevel(_ level: LevelDef, data: GameData) {
        currentLevelId = level.id
        inventory.removeAll(category: .puzzle)
        for g in level.pickups.startGift ?? [] {
            let missing = g.count - inventory.count(of: g.itemId)
            if missing > 0 { _ = inventory.add(g.itemId, count: missing) }
        }
        let start = data.hero.startLoadout
        if let starter = data.weapons[start.weaponId] {
            loadout.topUp(starter, magazine: start.magazine, reserve: start.reserve)
        }
    }

    /// Level complete: puzzle items removed, best result merged, the next level unlocked and made
    /// current (the last level stays current).
    mutating func completeLevel(_ level: LevelDef, result: LevelBest, data: GameData) {
        inventory.removeAll(category: .puzzle)
        if var b = bestResults[level.id] {
            b.merge(result)
            bestResults[level.id] = b
        } else {
            bestResults[level.id] = result
        }
        if let next = data.level(after: level.id) {
            unlockedLevelIndex = max(unlockedLevelIndex, next.index)
            currentLevelId = next.id
        } else {
            currentLevelId = level.id
        }
    }
}
