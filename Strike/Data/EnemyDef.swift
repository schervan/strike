import Foundation

/// Attack block of an enemy (GDD §16.2). Only the common fields are required.
nonisolated struct EnemyAttackDef: Codable, Sendable, Equatable {
    let type: String
    let damage: Int
    let cooldownSec: Double
    let telegraphSec: Double
    let range: Double
    let projectileSpeed: Double?
    let projectileCount: Int?
    let spreadDeg: Double?
    let projectileRadius: Double?
    let dashDistance: Double?
    let dashSpeed: Double?
    let slowMultiplier: Double?
    let slowSec: Double?
}

/// One enemy from `enemies.json` (GDD §16.2). Behaviour blocks other than `attack`, the
/// chaser hop fields and `separation` (e.g. `phases`, `shield`, `splitInto`) are ignored
/// until M4.
nonisolated struct EnemyDef: Codable, Sendable, Equatable, Identifiable {
    let id: String
    let nameKey: String
    let behavior: String
    let hp: Int
    let moveSpeed: Double
    let radius: Double
    let flying: Bool
    let contactDamage: Int
    let detectRange: Double
    let threatCost: Int
    let scoreValue: Int
    let lootTableId: String
    let attack: EnemyAttackDef?
    let hopChance: Double?
    let hopEverySec: Double?
    let hopPauseSec: Double?
    let separation: Double?
    /// Seconds the "!" bubble shows before the first chase/attack (GDD §8).
    let alertSec: Double?

    /// GDD §8 common rule: "alert shows a '!' bubble for 0.4 s". Used when the JSON has no
    /// per-enemy `alertSec`.
    static let defaultAlertSec = 0.4

    var effectiveAlertSec: Double { alertSec ?? Self.defaultAlertSec }

    /// Key pose texture in the `enemies` atlas (ART_BIBLE §11).
    var keyPoseTextureName: String { "enemy_\(id)_idle_01" }
}

nonisolated struct EnemiesFile: Codable, Sendable {
    let version: Int
    let enemies: [EnemyDef]
}
