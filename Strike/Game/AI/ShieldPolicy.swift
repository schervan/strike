import CoreGraphics
import Foundation

/// Shieldandroid (GDD §8.1): the front shield covers `arcDeg` and blocks every hero shot from
/// that side; it turns toward the hero at most `turnRateDeg` per second (so circling works).
/// Attack: crouch + shield glow for `telegraphSec` → dash `dashDistance` at `dashSpeed` along
/// its facing → dizzy for `dizzySec` (shield down, × `dizzyDamageMultiplier`). `cooldownSec` runs
/// start to start. Pure: the state turns the returned velocity into movement.
nonisolated struct ShieldPolicy: Sendable, Equatable {
    struct Config: Sendable, Equatable {
        let speed: CGFloat
        let arcDeg: Double
        let turnRateDeg: Double
        let dizzySec: Double
        let dizzyDamageMultiplier: Double
        let telegraphSec: Double
        let cooldownSec: Double
        let attackRange: CGFloat
        let dashDistance: CGFloat
        let dashSpeed: CGFloat

        init?(def: EnemyDef) {
            guard let s = def.shield, let a = def.attack, a.type == "dash" else { return nil }
            speed = CGFloat(def.moveSpeed)
            arcDeg = s.arcDeg
            turnRateDeg = s.turnRateDeg
            dizzySec = s.dizzySec
            dizzyDamageMultiplier = s.dizzyDamageMultiplier
            telegraphSec = a.telegraphSec
            cooldownSec = a.cooldownSec
            attackRange = CGFloat(a.range)
            dashDistance = CGFloat(a.dashDistance ?? a.range)
            dashSpeed = CGFloat(a.dashSpeed ?? def.moveSpeed)
        }
    }

    enum Mode: Sendable, Equatable {
        case walk
        case crouch(remaining: Double)
        case dash(remaining: CGFloat)
        case dizzy(remaining: Double)
    }

    enum Event: Sendable, Equatable {
        case none, crouch, dash, dizzy, recovered
    }

    let config: Config
    private(set) var mode: Mode = .walk
    /// Facing angle in radians (the shield's centre).
    private(set) var facing: CGFloat
    private(set) var cooldown: Double = 0

    init(config: Config, facing: CGFloat = 0) {
        self.config = config
        self.facing = facing
    }

    var isDizzy: Bool { if case .dizzy = mode { true } else { false } }
    var isDashing: Bool { if case .dash = mode { true } else { false } }
    var isCrouching: Bool { if case .crouch = mode { true } else { false } }
    var shieldUp: Bool { !isDizzy }

    /// Damage multiplier on this enemy right now.
    var damageMultiplier: Double { isDizzy ? config.dizzyDamageMultiplier : 1 }

    /// True when a hero shot travelling along `shotAngle` is blocked by the shield.
    func blocks(shotAngle: CGFloat) -> Bool {
        shieldUp && DamageModel.shieldBlocks(facing: facing, shotAngle: shotAngle, arcDeg: config.arcDeg)
    }

    /// `blocks(hitDirection:)` from the module map: the shot's travel direction as a vector.
    func blocks(hitDirection v: CGVector) -> Bool { blocks(shotAngle: atan2(v.dy, v.dx)) }

    /// One AI step toward the hero at `h` (aware state; the alert "!" is the caller's).
    mutating func tick(dt: Double, position p: CGPoint, hero h: CGPoint, canSee: Bool) -> (velocity: CGVector, event: Event) {
        cooldown = max(0, cooldown - dt)
        let toHero = atan2(h.y - p.y, h.x - p.x)
        let d = hypot(h.x - p.x, h.y - p.y)
        switch mode {
        case .walk:
            turn(toward: toHero, dt: dt)
            if cooldown <= 0, canSee, d <= config.attackRange {
                mode = .crouch(remaining: config.telegraphSec)
                cooldown = config.cooldownSec
                return (.zero, .crouch)
            }
            return (CGVector(dx: cos(facing) * config.speed, dy: sin(facing) * config.speed), .none)
        case .crouch(let r):
            // Keeps turning while it winds up; the dash goes where it faces at the end.
            turn(toward: toHero, dt: dt)
            let left = r - dt
            if left <= 0 {
                // This step already moves: count it against the dash distance.
                mode = .dash(remaining: config.dashDistance - config.dashSpeed * CGFloat(dt))
                return (dashVelocity, .dash)
            }
            mode = .crouch(remaining: left)
            return (.zero, .none)
        case .dash(let r):
            let left = r - config.dashSpeed * CGFloat(dt)
            if left <= 0 { return (.zero, startDizzy()) }
            mode = .dash(remaining: left)
            return (dashVelocity, .none)
        case .dizzy(let r):
            let left = r - dt
            if left <= 0 {
                mode = .walk
                return (.zero, .recovered)
            }
            mode = .dizzy(remaining: left)
            return (.zero, .none)
        }
    }

    /// The dash hit a wall or the hero early: dizzy now.
    mutating func dashBlocked() -> Event {
        guard isDashing else { return .none }
        return startDizzy()
    }

    private var dashVelocity: CGVector {
        CGVector(dx: cos(facing) * config.dashSpeed, dy: sin(facing) * config.dashSpeed)
    }

    private mutating func startDizzy() -> Event {
        mode = .dizzy(remaining: config.dizzySec)
        return .dizzy
    }

    private mutating func turn(toward target: CGFloat, dt: Double) {
        let maxStep = CGFloat(config.turnRateDeg * dt) * .pi / 180
        let diff = AimAssist.angleDifference(from: facing, to: target)
        facing += max(-maxStep, min(maxStep, diff))
    }
}
