import CoreGraphics
import Foundation

/// Leash logic for one enemy (GDD §8, `rules.json → leash`): when the hero stays farther than
/// `rangeFactor × detectRange` for `returnAfterSec`, the enemy walks back to its home spawn and
/// heals to full on arrival. Pure value type; `ReturnHomeState` drives it.
nonisolated struct Leash: Sendable, Equatable {
    let rangeFactor: Double
    let returnAfterSec: Double
    /// Continuous time the hero has been beyond the leash range.
    private(set) var outOfRangeTime: Double = 0
    private(set) var isReturning = false

    /// Arrival tolerance at the home spawn: half a tile (geometry, not balance).
    static let arriveDistance = Double(TileGrid.tileSize) / 2

    init(rules: LeashRulesDef) {
        rangeFactor = rules.rangeFactor
        returnAfterSec = rules.returnAfterSec
    }

    func range(detectRange: Double) -> Double { rangeFactor * detectRange }

    /// Call every frame while the enemy is chasing. Returns true on the frame the enemy should
    /// start returning home.
    mutating func update(dt: Double, distanceToHero: Double, detectRange: Double) -> Bool {
        guard !isReturning else { return false }
        if distanceToHero > range(detectRange: detectRange) {
            outOfRangeTime += max(0, dt)
            if outOfRangeTime + 1e-9 >= returnAfterSec {
                isReturning = true
                outOfRangeTime = 0
                return true
            }
        } else {
            outOfRangeTime = 0
        }
        return false
    }

    /// True once `position` is within `arriveDistance` of `home`.
    static func hasArrived(_ position: CGPoint, home: CGPoint) -> Bool {
        hypot(Double(position.x - home.x), Double(position.y - home.y)) <= arriveDistance
    }

    /// Call while returning. On arrival heals `health` to full, ends the return and returns true.
    mutating func updateReturn(position: CGPoint, home: CGPoint, health: inout Health) -> Bool {
        guard isReturning, Self.hasArrived(position, home: home) else { return false }
        health.reset(invulnerableFor: 0)
        isReturning = false
        outOfRangeTime = 0
        return true
    }

    /// Hero rescue (GDD §12 step 6): living enemies go home; also used when the level resets.
    mutating func forceReturn() {
        isReturning = true
        outOfRangeTime = 0
    }

    mutating func reset() {
        isReturning = false
        outOfRangeTime = 0
    }
}
