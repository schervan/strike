import CoreGraphics
import Testing
@testable import Strike

/// M4-4: shieldandroid (GDD §8.1) from `enemies.json`.
struct ShieldPolicyTests {
    static var def: EnemyDef { GeneratedCorpus.data.enemies["shieldandroid"]! }
    static func config() throws -> ShieldPolicy.Config { try #require(ShieldPolicy.Config(def: def)) }
    static func rad(_ d: Double) -> CGFloat { CGFloat(d) * .pi / 180 }

    @Test func frontHitsInsideHalfTheArcAreBlockedBackHitsPass() throws {
        let c = try Self.config()
        #expect(c.arcDeg == 120)
        let p = ShieldPolicy(config: c, facing: 0)          // facing +x
        // A shot from the front travels toward −x (angle π).
        #expect(p.blocks(shotAngle: .pi))
        #expect(p.blocks(shotAngle: .pi + Self.rad(59)))
        #expect(p.blocks(shotAngle: .pi - Self.rad(59)))
        #expect(!p.blocks(shotAngle: .pi + Self.rad(61)), "outside ±60°")
        #expect(!p.blocks(shotAngle: 0), "from behind")
        #expect(!p.blocks(shotAngle: Self.rad(90)), "from the side")
        #expect(p.blocks(hitDirection: CGVector(dx: -1, dy: 0)))
    }

    @Test func turningIsCappedSoCirclingGetsBehindIt() throws {
        let c = try Self.config()
        var p = ShieldPolicy(config: c, facing: 0)
        let dt = 1.0 / 60
        let heroSpeed = CGFloat(GeneratedCorpus.data.hero.moveSpeed)
        let radius: CGFloat = 80
        var angle: CGFloat = 0
        var gotBehind = false
        var lastFacing = p.facing
        for _ in 0..<(60 * 4) {
            angle += heroSpeed / radius * CGFloat(dt)
            let hero = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
            _ = p.tick(dt: dt, position: .zero, hero: hero, canSee: false)   // no attack: pure turning
            let step = abs(AimAssist.angleDifference(from: lastFacing, to: p.facing))
            #expect(step <= Self.rad(c.turnRateDeg * dt) + 1e-9, "turn rate capped")
            lastFacing = p.facing
            // The hero shoots at the android from where it stands.
            let shot = atan2(-hero.y, -hero.x)
            if !p.blocks(shotAngle: shot) { gotBehind = true }
        }
        print("SHIELD circling at \(Int(radius)) pt: hero out-turned it = \(gotBehind)")
        #expect(gotBehind, "a hero circling at full speed must get past the shield")
    }

    @Test func crouchDashThenDizzyWithShieldDownAndExtraDamage() throws {
        let c = try Self.config()
        var p = ShieldPolicy(config: c, facing: 0)
        let dt = 1.0 / 60
        let hero = CGPoint(x: 200, y: 0)
        var r = p.tick(dt: dt, position: .zero, hero: hero, canSee: true)
        #expect(r.event == .crouch && r.velocity == .zero)
        var t = 0.0, dashAt: Double?, dizzyAt: Double?, travelled: CGFloat = 0
        while t < 5, dizzyAt == nil {
            r = p.tick(dt: dt, position: .zero, hero: hero, canSee: true)
            t += dt
            if r.event == .dash { dashAt = t }
            if p.isDashing || r.event == .dash { travelled += hypot(r.velocity.dx, r.velocity.dy) * CGFloat(dt) }
            if r.event == .dizzy { dizzyAt = t }
        }
        let dash = try #require(dashAt), dizzy = try #require(dizzyAt)
        #expect(abs(dash - c.telegraphSec) < 2 * dt, "crouch + glow \(c.telegraphSec) s")
        #expect(abs(travelled - c.dashDistance) < c.dashSpeed * CGFloat(dt) + 1, "dash \(travelled) pt")
        #expect(abs((dizzy - dash) - Double(c.dashDistance / c.dashSpeed)) < 2 * dt)
        #expect(p.isDizzy && !p.shieldUp && !p.blocks(shotAngle: .pi))
        #expect(p.damageMultiplier == 1.5 && c.dizzySec == 1.5)
        #expect(DamageModel.finalDamage(base: 10, dizzyMultiplier: p.damageMultiplier) == 15)
        var recovered = 0.0
        while p.isDizzy { _ = p.tick(dt: dt, position: .zero, hero: hero, canSee: true); recovered += dt }
        #expect(abs(recovered - c.dizzySec) < 2 * dt)
        #expect(p.shieldUp && p.damageMultiplier == 1)
    }

    @Test func aBlockedDashGoesDizzyAtOnce() throws {
        var p = ShieldPolicy(config: try Self.config())
        _ = p.tick(dt: 0.01, position: .zero, hero: CGPoint(x: 100, y: 0), canSee: true)
        let v23 = p.dashBlocked()
        #expect(v23 == .none, "not dashing yet")
        while !p.isDashing { _ = p.tick(dt: 0.05, position: .zero, hero: CGPoint(x: 100, y: 0), canSee: true) }
        let v24 = p.dashBlocked()
        #expect(v24 == .dizzy && p.isDizzy)
    }
}
