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

/// Kiter distance band (`keepDistance`, GDD §8.1 laserdrone).
nonisolated struct KeepDistanceDef: Codable, Sendable, Equatable {
    let min: Double
    let max: Double
}

/// Splitter children (`splitInto`, GDD §8.1 slimemutant). `spawnOffset` is in pt.
nonisolated struct SplitDef: Codable, Sendable, Equatable {
    let enemyId: String
    let count: Int
    let spawnDelaySec: Double
    let spawnOffset: Double
}

/// Front shield (`shield`, GDD §8.1 shieldandroid).
nonisolated struct ShieldDef: Codable, Sendable, Equatable {
    let arcDeg: Double
    let turnRateDeg: Double
    let dizzySec: Double
    let dizzyDamageMultiplier: Double
}

/// One boss attack inside a phase (GDD §9, §16.2). Geometry fields are optional per type.
nonisolated struct BossAttackDef: Codable, Sendable, Equatable {
    /// `stomp` / `volley` / `laser_sweep` / `dash`.
    let type: String
    let damage: Int
    let cooldownSec: Double
    let telegraphSec: Double
    let range: Double
    let telegraphRadius: Double?
    let projectileSpeed: Double?
    let projectileCount: Int?
    let spreadDeg: Double?
    let projectileRadius: Double?
    let gaps: Int?
    let sweepDegPerSec: Double?
    let dashSpeed: Double?
    let pillarDizzySec: Double?
    /// Dash: damage multiplier while dizzy after a pillar hit (default 1 = dizzy only stops attacks).
    let pillarDizzyDamageMultiplier: Double?
    /// Stomp: seconds the shockwave takes from `telegraphRadius` to `range`.
    let waveSec: Double?
    /// Laser sweep: width of each safe gap in degrees.
    let gapDeg: Double?
    /// Laser sweep: seconds the beam rotates after the telegraph.
    let sweepSec: Double?

    static let stomp = "stomp", volley = "volley", laserSweep = "laser_sweep", dash = "dash"

    /// Used only while `enemies.json` has no `waveSec` / `gapDeg` / `sweepSec` (designer field
    /// names pending, M4-1). This is the single place these numbers exist in code.
    static let fallbackWaveSec = 0.4
    static let fallbackGapDeg = 50.0
    static let fallbackSweepSec = 4.0

    var effectiveWaveSec: Double { waveSec ?? Self.fallbackWaveSec }
    var effectiveGapDeg: Double { gapDeg ?? Self.fallbackGapDeg }
    var effectiveSweepSec: Double { sweepSec ?? Self.fallbackSweepSec }
}

/// Phase spawns (`spawn`, GDD §9 phase 2): boltbots, the first `carryCount` carry `carryItemFirst`.
nonisolated struct BossSpawnDef: Codable, Sendable, Equatable {
    let enemyId: String
    let everySec: Double
    let maxAlive: Int
    let carryItemFirst: String?
    let carryCount: Int?
}

/// Phase shield puzzle (`unlockBy`, GDD §9 phase 2): `count` machines with `requiresItem` on →
/// shield pops and the boss is dizzy for `dizzySec` taking × `dizzyDamageMultiplier`.
nonisolated struct BossUnlockDef: Codable, Sendable, Equatable {
    let elementType: ElementType
    let requiresItem: String
    let count: Int
    let dizzySec: Double
    let dizzyDamageMultiplier: Double
}

/// One boss phase (GDD §9). HP runs from `hpFrom` down to `hpTo`.
nonisolated struct BossPhaseDef: Codable, Sendable, Equatable, Identifiable {
    let id: String
    let hpFrom: Int
    let hpTo: Int
    let immune: Bool
    let cooldownMultiplier: Double?
    let attacks: [BossAttackDef]
    let spawn: BossSpawnDef?
    let unlockBy: BossUnlockDef?

    var effectiveCooldownMultiplier: Double { cooldownMultiplier ?? 1 }
}

/// One enemy from `enemies.json` (GDD §16.2) with every behaviour block (M4).
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
    /// Kiter (laserdrone).
    let keepDistance: KeepDistanceDef?
    let retreatRange: Double?
    let strafeSec: Double?
    /// Splitter (slimemutant).
    let splitInto: SplitDef?
    /// Shielded (shieldandroid).
    let shield: ShieldDef?
    /// Turret (sporeplant) close-range defence.
    let shyRange: Double?
    let shyDamageMultiplier: Double?
    let shySec: Double?
    /// Boss (megamech).
    let phases: [BossPhaseDef]?
    let rescueResetsToPhaseTop: Bool?

    /// Behaviour names (GDD §16.2).
    static let chaser = "chaser", kiter = "kiter", splitter = "splitter", shielded = "shielded",
               turret = "turret", boss = "boss"

    /// GDD §8 common rule: "alert shows a '!' bubble for 0.4 s". Used when the JSON has no
    /// per-enemy `alertSec`.
    static let defaultAlertSec = 0.4

    var effectiveAlertSec: Double { alertSec ?? Self.defaultAlertSec }

    /// Duration of the blaster knockback shove (`enemies.json → knockbackSec`, M2-1).
    let knockbackSec: Double?

    /// M1 value, used only when an enemy has no `knockbackSec` in the JSON.
    static let defaultKnockbackSec = 0.1

    var effectiveKnockbackSec: Double { knockbackSec ?? Self.defaultKnockbackSec }

    /// Key pose texture in the `enemies` atlas (ART_BIBLE §11).
    var keyPoseTextureName: String { "enemy_\(id)_idle_01" }

    /// Boss phases must form one chain `hp → … → 0` with no gaps (GDD §9). Empty when fine.
    var phaseChainProblems: [String] {
        guard let phases else { return behavior == Self.boss ? ["enemy \(id): boss without phases"] : [] }
        var out: [String] = []
        guard let first = phases.first, let last = phases.last else { return ["enemy \(id): phases empty"] }
        if first.hpFrom != hp { out.append("enemy \(id): first phase starts at \(first.hpFrom), hp is \(hp)") }
        if last.hpTo != 0 { out.append("enemy \(id): last phase ends at \(last.hpTo), not 0") }
        for p in phases where p.hpFrom <= p.hpTo { out.append("enemy \(id): phase \(p.id) does not go down") }
        for (a, b) in zip(phases, phases.dropFirst()) where a.hpTo != b.hpFrom {
            out.append("enemy \(id): gap between \(a.id) (\(a.hpTo)) and \(b.id) (\(b.hpFrom))")
        }
        return out
    }
}

nonisolated struct EnemiesFile: Codable, Sendable {
    let version: Int
    let enemies: [EnemyDef]
}
