import CoreGraphics
import Foundation

/// Sporeplant (GDD §8.1): never moves. Opens its petals for `telegraphSec`, then sneezes
/// `projectileCount` spores in a `spreadDeg` fan at the hero (damage + slow come from `attack`).
/// A hero closer than `shyRange` makes it close up: no attack, × `shyDamageMultiplier` damage,
/// for `shySec` after the hero was last that close. `cooldownSec` runs start to start. Pure.
nonisolated struct TurretPolicy: Sendable, Equatable {
    struct Config: Sendable, Equatable {
        let telegraphSec: Double
        let cooldownSec: Double
        let range: CGFloat
        let projectileCount: Int
        let spreadDeg: Double
        let shyRange: CGFloat
        let shySec: Double
        let shyDamageMultiplier: Double

        init?(def: EnemyDef) {
            guard let a = def.attack, a.type == "projectile" else { return nil }
            telegraphSec = a.telegraphSec
            cooldownSec = a.cooldownSec
            range = CGFloat(a.range)
            projectileCount = a.projectileCount ?? 1
            spreadDeg = a.spreadDeg ?? 0
            shyRange = CGFloat(def.shyRange ?? 0)
            shySec = def.shySec ?? 0
            shyDamageMultiplier = def.shyDamageMultiplier ?? 1
        }
    }

    enum Event: Sendable, Equatable {
        case none
        /// Petals open (telegraph starts).
        case petalsOpen
        /// Spores leave along these angles (radians).
        case fire(angles: [CGFloat])
        case closed
        case reopened
    }

    let config: Config
    private(set) var telegraphRemaining: Double?
    private(set) var shyRemaining: Double = 0
    private(set) var cooldown: Double = 0

    init(config: Config) {
        self.config = config
    }

    var isShy: Bool { shyRemaining > 0 }
    var isTelegraphing: Bool { telegraphRemaining != nil }
    var damageMultiplier: Double { isShy ? config.shyDamageMultiplier : 1 }

    /// One AI step. The velocity is always zero (static); only events come out.
    mutating func tick(dt: Double, position p: CGPoint, hero h: CGPoint, canSee: Bool) -> (velocity: CGVector, event: Event) {
        cooldown = max(0, cooldown - dt)
        let d = hypot(h.x - p.x, h.y - p.y)
        if config.shySec > 0, d < config.shyRange {
            let wasShy = isShy
            shyRemaining = config.shySec
            telegraphRemaining = nil
            return (.zero, wasShy ? .none : .closed)
        }
        if isShy {
            shyRemaining = max(0, shyRemaining - dt)
            return (.zero, isShy ? .none : .reopened)
        }
        if let r = telegraphRemaining {
            let left = r - dt
            if left <= 0 {
                telegraphRemaining = nil
                let angles = WeaponFire.fan(center: atan2(h.y - p.y, h.x - p.x), count: config.projectileCount,
                                            spreadDeg: config.spreadDeg)
                return (.zero, .fire(angles: angles))
            }
            telegraphRemaining = left
            return (.zero, .none)
        }
        if cooldown <= 0, canSee, d <= config.range {
            telegraphRemaining = config.telegraphSec
            cooldown = config.cooldownSec
            return (.zero, .petalsOpen)
        }
        return (.zero, .none)
    }
}
