import Foundation

/// What the rescue needs to know about one enemy.
nonisolated struct RescueEnemy: Sendable, Equatable {
    let id: String
    let isPoweredDown: Bool
}

/// Result of `RescueRules.apply`: what the scene still has to do.
nonisolated struct RescueOutcome: Sendable, Equatable {
    /// Checkpoint the hero is beamed to (nil = level start).
    let checkpointId: String?
    let invulnerableSec: Double
    /// Rounds added to the starter blaster (step 5).
    let starterRoundsAdded: Int
    /// Living enemies: full HP and walk back to their home rooms. Powered-down ones stay down.
    let enemiesToReset: [String]
}

nonisolated enum RescuePhase: Sendable, Equatable {
    /// Hero stops and sparkles; time runs at `slowMoScale`.
    case slowMo
    /// Pixel's beam to the checkpoint.
    case beam
    case done
}

/// GDD §12 rescue at 0 HP (never "game over"). Steps 3–7 are `apply`; steps 1–2 are the
/// `phase(at:)` timeline from `rules.json → rescue`. Inventory, quick slots, datachips and puzzle
/// state are not touched.
nonisolated enum RescueRules {
    static func apply(health: inout Health, loadout: inout Loadout, session: inout LevelSession,
                      enemies: [RescueEnemy], starter: WeaponDef, rules: RescueRulesDef,
                      invulnerableSec: Double) -> RescueOutcome {
        health.reset(invulnerableFor: invulnerableSec)
        let added = loadout.topUpTotal(starter, atLeast: rules.starterMinMagazine)
        session.recordRescue()
        return RescueOutcome(checkpointId: session.lastCheckpointId, invulnerableSec: invulnerableSec,
                             starterRoundsAdded: added,
                             enemiesToReset: enemies.filter { !$0.isPoweredDown }.map(\.id))
    }

    /// Total length of the sequence (real seconds).
    static func duration(_ rules: RescueRulesDef) -> Double { max(0, rules.slowMoSec) + max(0, rules.beamSec) }

    /// Phase `t` real seconds after HP reached 0.
    static func phase(at t: Double, rules: RescueRulesDef) -> RescuePhase {
        if t < rules.slowMoSec { return .slowMo }
        if t < duration(rules) { return .beam }
        return .done
    }

    /// Game-time scale at `t`: `slowMoScale` during the slow-mo, 1 otherwise.
    static func timeScale(at t: Double, rules: RescueRulesDef) -> Double {
        phase(at: t, rules: rules) == .slowMo ? rules.slowMoScale : 1
    }
}
