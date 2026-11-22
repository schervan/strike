import Foundation

nonisolated struct LootEntry: Codable, Sendable, Equatable {
    let itemId: String
    let weight: Double
    let min: Int
    let max: Int
}

nonisolated struct LootGuaranteed: Codable, Sendable, Equatable {
    let itemId: String
    let count: Int
}

/// Loot table (GDD §10, §16.4).
nonisolated struct LootTable: Codable, Sendable, Equatable, Identifiable {
    let id: String
    let boltsMin: Int
    let boltsMax: Int
    let dropChance: Double
    let rolls: Int
    let entries: [LootEntry]
    let guaranteed: [LootGuaranteed]
}

/// Kid-friendly weight modifier (GDD §10 step 4). `condition` / `appliesTo` stay strings so
/// new modifier kinds in the JSON do not break decoding; unknown ones are ignored by `LootRoller`.
nonisolated struct LootModifier: Codable, Sendable, Equatable, Identifiable {
    let id: String
    let condition: String
    let threshold: Double?
    let appliesTo: String
    let weightMultiplier: Double
    /// While the condition holds, this many `appliesTo` items (count 1 each) are added to the
    /// guaranteed drops of every roll (GDD §16.4, `ammo_rescue`). Absent = 0.
    let guaranteeCount: Int?

    enum Condition: String, Sendable {
        case heroHpRatioBelow, equippedAmmoRatioBelow, weaponNotOwned, equippedAmmoBelowMagazines
    }

    var knownCondition: Condition? { Condition(rawValue: condition) }
}

nonisolated struct LootFile: Codable, Sendable {
    let version: Int
    let modifiers: [LootModifier]
    let tables: [LootTable]
}
