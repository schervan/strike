import Foundation

/// Timed effects on the hero (GDD §4): spore slow = move speed × `slowMultiplier` for `slowSec`.
/// Slows do not stack; a new hit refreshes the time (the stronger multiplier wins while both
/// would run). Cleared by a rescue. Pure value type.
nonisolated struct StatusEffects: Sendable, Equatable {
    private(set) var slowRemaining: Double = 0
    private(set) var slowMultiplier: Double = 1

    var isSlowed: Bool { slowRemaining > 0 }

    /// Multiplier for the hero's move speed right now.
    var speedMultiplier: Double { isSlowed ? slowMultiplier : 1 }

    /// A slowing hit (`attack.slowMultiplier`, `attack.slowSec`).
    mutating func applySlow(multiplier: Double, sec: Double) {
        guard sec > 0, multiplier > 0, multiplier < 1 else { return }
        slowMultiplier = isSlowed ? min(slowMultiplier, multiplier) : multiplier
        slowRemaining = max(slowRemaining, sec)
    }

    mutating func tick(dt: Double) {
        guard isSlowed, dt > 0 else { return }
        slowRemaining = max(0, slowRemaining - dt)
        if slowRemaining == 0 { slowMultiplier = 1 }
    }

    /// Rescue (GDD §12): the hero comes back without effects.
    mutating func clear() {
        slowRemaining = 0
        slowMultiplier = 1
    }
}
