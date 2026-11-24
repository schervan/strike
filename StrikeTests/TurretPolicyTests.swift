import CoreGraphics
import Testing
@testable import Strike

/// M4-4: sporeplant (GDD §8.1).
struct TurretPolicyTests {
    static var def: EnemyDef { GeneratedCorpus.data.enemies["sporeplant"]! }
    static func config() throws -> TurretPolicy.Config { try #require(TurretPolicy.Config(def: def)) }

    @Test func neverMovesAndFiresAThirtyDegreeFanAfterItsTelegraph() throws {
        let c = try Self.config()
        #expect(Self.def.moveSpeed == 0 && c.projectileCount == 3 && c.spreadDeg == 30 && c.telegraphSec == 0.6)
        var p = TurretPolicy(config: c)
        let dt = 1.0 / 60
        let hero = CGPoint(x: 0, y: 200)
        var opens: [Double] = [], fires: [(Double, [CGFloat])] = []
        var t = 0.0
        while t < 12 {
            let r = p.tick(dt: dt, position: .zero, hero: hero, canSee: true)
            #expect(r.velocity == .zero)
            if r.event == .petalsOpen { opens.append(t) }
            if case .fire(let a) = r.event { fires.append((t, a)) }
            t += dt
        }
        #expect(fires.count >= 4)
        for (ft, angles) in fires {
            #expect(angles.count == c.projectileCount)
            let deg = angles.map { Double($0) * 180 / .pi }
            #expect(abs((deg.max()! - deg.min()!) - c.spreadDeg) < 1e-6)
            #expect(abs(deg[1] - 90) < 1e-6, "centred on the hero")
            let o = try #require(opens.last { $0 < ft })
            #expect(abs((ft - o) - c.telegraphSec) < 2 * dt, "petals open \(c.telegraphSec) s first")
        }
    }

    @Test func shyBelowShyRangeHalvesDamageForShySec() throws {
        let c = try Self.config()
        #expect(c.shyRange == 80 && c.shyDamageMultiplier == 0.5 && c.shySec == 1.0)
        var p = TurretPolicy(config: c)
        let dt = 1.0 / 60
        #expect(p.damageMultiplier == 1)
        var r = p.tick(dt: dt, position: .zero, hero: CGPoint(x: 70, y: 0), canSee: true)
        #expect(r.event == .closed && p.isShy && p.damageMultiplier == 0.5)
        #expect(DamageModel.finalDamage(base: 10, shyMultiplier: p.damageMultiplier) == 5)
        // Hero steps back out: still shy for shySec, no attack meanwhile.
        var t = 0.0
        while p.isShy {
            r = p.tick(dt: dt, position: .zero, hero: CGPoint(x: 200, y: 0), canSee: true)
            #expect(r.event == .none || r.event == .reopened)
            t += dt
        }
        #expect(abs(t - c.shySec) < 2 * dt)
        #expect(p.damageMultiplier == 1)
    }

    @Test func closingCancelsATelegraph() throws {
        var p = TurretPolicy(config: try Self.config())
        let v25 = p.tick(dt: 0.01, position: .zero, hero: CGPoint(x: 200, y: 0), canSee: true)
        #expect(v25.event == .petalsOpen)
        _ = p.tick(dt: 0.01, position: .zero, hero: CGPoint(x: 50, y: 0), canSee: true)
        #expect(!p.isTelegraphing && p.isShy)
    }
}
