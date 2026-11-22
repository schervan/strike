import Foundation

nonisolated struct StartLoadoutDef: Codable, Sendable, Equatable {
    let weaponId: String
    let magazine: Int
    let reserve: Int
}

/// Starter-blaster safety net (GDD §5.1).
nonisolated struct SafetyNetDef: Codable, Sendable, Equatable {
    let rechargeEverySec: Double
    let rechargeTo: Int
}

/// Hero stats (`hero.json → hero`, GDD §4 / §16.6).
nonisolated struct HeroDef: Codable, Sendable, Equatable {
    let maxHp: Int
    let moveSpeed: Double
    let radius: Double
    let invulnerableSec: Double
    let knockbackDistance: Double
    let knockbackSec: Double
    let pickupRadius: Double
    let magnetRadius: Double
    let interactRadius: Double
    let startLoadout: StartLoadoutDef
    let starterSafetyNet: SafetyNetDef
    /// Invulnerability after the M1 placeholder rescue (TASKS M1-9: "2 s").
    let respawnInvulnerableSec: Double?

    static let defaultRespawnInvulnerableSec = 2.0
    var effectiveRespawnInvulnerableSec: Double { respawnInvulnerableSec ?? Self.defaultRespawnInvulnerableSec }
}

/// Twin-stick tuning (`hero.json → controls`, GDD §3.2). Widths/heights are screen fractions,
/// dead zones / full magnitude are fractions of `stickRadius`.
nonisolated struct ControlsDef: Codable, Sendable, Equatable {
    let moveZoneWidth: Double
    let aimZoneWidth: Double
    let hudBandHeight: Double
    let stickRadius: Double
    let moveDeadZone: Double
    let aimDeadZone: Double
    let fullMagnitudeAt: Double
    let followFactor: Double
    let fadeSec: Double
    let aimAssistStrength: Double
    let aimAssistDefaultOn: Bool
}

nonisolated struct CameraDef: Codable, Sendable, Equatable {
    let smoothingSec: Double
    let lookAhead: Double
}

nonisolated struct HeroFile: Codable, Sendable {
    let version: Int
    let hero: HeroDef
    let controls: ControlsDef
    let camera: CameraDef
}
