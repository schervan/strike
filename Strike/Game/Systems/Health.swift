import Foundation

nonisolated enum DamageResult: Sendable, Equatable {
    /// Inside the invulnerability window (or already at 0 HP): nothing happened.
    case ignored
    case hit
    /// HP reached 0 with this hit.
    case depleted
}

/// Hit points plus an invulnerability window after each hit. Pure value type.
nonisolated struct Health: Sendable, Equatable {
    let max: Int
    private(set) var current: Int
    /// Window started by every successful hit (0 for enemies).
    let invulnerableSec: Double
    private(set) var invulnerableRemaining: Double = 0

    init(max: Int, invulnerableSec: Double = 0) {
        self.max = Swift.max(1, max)
        self.current = self.max
        self.invulnerableSec = invulnerableSec
    }

    var isInvulnerable: Bool { invulnerableRemaining > 0 }
    var isDepleted: Bool { current <= 0 }
    var ratio: Double { Double(current) / Double(max) }

    mutating func applyDamage(_ amount: Int) -> DamageResult {
        guard amount > 0, !isInvulnerable, current > 0 else { return .ignored }
        current = Swift.max(0, current - amount)
        invulnerableRemaining = invulnerableSec
        return current == 0 ? .depleted : .hit
    }

    /// Heals up to `max`. Returns the HP actually restored.
    @discardableResult
    mutating func heal(_ amount: Int) -> Int {
        guard amount > 0 else { return 0 }
        let before = current
        current = Swift.min(max, current + amount)
        return current - before
    }

    mutating func tick(dt: Double) {
        invulnerableRemaining = Swift.max(0, invulnerableRemaining - dt)
    }

    /// Full HP and a custom invulnerability window (rescue / respawn).
    mutating func reset(invulnerableFor seconds: Double) {
        current = max
        invulnerableRemaining = seconds
    }
}
