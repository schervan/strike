import CoreGraphics
import Foundation

/// Laserdrone (GDD §8.1): keeps `keepDistance` from the hero while strafing sideways for
/// `strafeSec`, then stops, glows for `telegraphSec` and fires one laser ball at the hero.
/// Backs off at full speed when the hero is closer than `retreatRange`. `cooldownSec` runs start
/// to start (telegraph to telegraph). Flying: it ignores plates, walls still block it (the
/// caller's `isFree` flips the strafe side at a wall). Pure.
nonisolated struct KiterPolicy: Sendable, Equatable {
    struct Config: Sendable, Equatable {
        let speed: CGFloat
        let keepMin: CGFloat
        let keepMax: CGFloat
        let retreatRange: CGFloat
        let strafeSec: Double
        let telegraphSec: Double
        let cooldownSec: Double
        let attackRange: CGFloat

        init(speed: CGFloat, keepMin: CGFloat, keepMax: CGFloat, retreatRange: CGFloat, strafeSec: Double,
             telegraphSec: Double, cooldownSec: Double, attackRange: CGFloat) {
            self.speed = speed
            self.keepMin = keepMin
            self.keepMax = keepMax
            self.retreatRange = retreatRange
            self.strafeSec = strafeSec
            self.telegraphSec = telegraphSec
            self.cooldownSec = cooldownSec
            self.attackRange = attackRange
        }

        /// Nil when the enemy has no kiter blocks.
        init?(def: EnemyDef) {
            guard let k = def.keepDistance, let a = def.attack, a.type == "projectile" else { return nil }
            self.init(speed: CGFloat(def.moveSpeed), keepMin: CGFloat(k.min), keepMax: CGFloat(k.max),
                      retreatRange: CGFloat(def.retreatRange ?? k.min), strafeSec: def.strafeSec ?? 0,
                      telegraphSec: a.telegraphSec, cooldownSec: a.cooldownSec, attackRange: CGFloat(a.range))
        }
    }

    enum Event: Sendable, Equatable {
        case none
        /// Stop and glow red (telegraph) now.
        case telegraph
        /// Fire one laser ball along `angle` (radians).
        case fire(angle: CGFloat)
    }

    enum Mode: Sendable, Equatable {
        case strafe(remaining: Double)
        case telegraph(remaining: Double)
    }

    let config: Config
    private(set) var mode: Mode
    private(set) var cooldown: Double = 0
    /// +1 = counter-clockwise around the hero, −1 = clockwise.
    private(set) var strafeSide: CGFloat = 1

    init(config: Config) {
        self.config = config
        mode = .strafe(remaining: config.strafeSec)
    }

    var isTelegraphing: Bool { if case .telegraph = mode { true } else { false } }

    /// One AI step. `canSee`: line of sight to the hero. `isFree`: a probe point is not in a wall.
    mutating func tick(dt: Double, position p: CGPoint, hero h: CGPoint, canSee: Bool,
                       isFree: (CGPoint) -> Bool = { _ in true }) -> (velocity: CGVector, event: Event) {
        cooldown = max(0, cooldown - dt)
        let dx = h.x - p.x, dy = h.y - p.y
        let d = max(0.001, hypot(dx, dy))
        let ux = dx / d, uy = dy / d
        switch mode {
        case .telegraph(let r):
            let left = r - dt
            if left <= 0 {
                mode = .strafe(remaining: config.strafeSec)
                strafeSide = -strafeSide
                return (.zero, .fire(angle: atan2(dy, dx)))
            }
            mode = .telegraph(remaining: left)
            return (.zero, .none)
        case .strafe(let r):
            let left = r - dt
            if left <= 0, cooldown <= 0, canSee, d >= config.retreatRange, d <= config.attackRange {
                mode = .telegraph(remaining: config.telegraphSec)
                cooldown = config.cooldownSec
                return (.zero, .telegraph)
            }
            mode = .strafe(remaining: max(0, left))
            return (velocity(dt: dt, d: d, ux: ux, uy: uy, position: p, isFree: isFree), .none)
        }
    }

    /// Radial correction toward the band (full retreat below `retreatRange`) plus sideways strafe.
    private mutating func velocity(dt: Double, d: CGFloat, ux: CGFloat, uy: CGFloat, position p: CGPoint,
                                   isFree: (CGPoint) -> Bool) -> CGVector {
        let v = config.speed
        guard v > 0 else { return .zero }
        if d < config.retreatRange {
            return CGVector(dx: -ux * v, dy: -uy * v)
        }
        // Radial speed that lands inside [keepMin, keepMax] this step (negative = away).
        let step = v * CGFloat(max(dt, 1e-6))
        var radial: CGFloat = 0
        if d > config.keepMax { radial = min(v, (d - config.keepMax) / CGFloat(max(dt, 1e-6)) + v * 0.5) }
        else if d < config.keepMin { radial = -min(v, (config.keepMin - d) / CGFloat(max(dt, 1e-6)) + v * 0.5) }
        else if d > config.keepMax - step { radial = min(v, (d - (config.keepMax - step)) / CGFloat(max(dt, 1e-6))) }
        else if d < config.keepMin + step { radial = -min(v, ((config.keepMin + step) - d) / CGFloat(max(dt, 1e-6))) }
        radial = max(-v, min(v, radial))
        let tangential = (v * v - radial * radial).squareRoot()
        // Perpendicular (counter-clockwise for side +1); flip at a wall.
        var tx = -uy * strafeSide, ty = ux * strafeSide
        let probe = CGPoint(x: p.x + tx * (v * 0.3), y: p.y + ty * (v * 0.3))
        if !isFree(probe) {
            strafeSide = -strafeSide
            tx = -tx; ty = -ty
        }
        return CGVector(dx: ux * radial + tx * tangential, dy: uy * radial + ty * tangential)
    }
}
