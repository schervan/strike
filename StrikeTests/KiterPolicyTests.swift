import CoreGraphics
import Testing
@testable import Strike

/// M4-4: laserdrone kiting (GDD §8.1) from `enemies.json`.
struct KiterPolicyTests {
    static var def: EnemyDef { GeneratedCorpus.data.enemies["laserdrone"]! }
    static func config() throws -> KiterPolicy.Config { try #require(KiterPolicy.Config(def: def)) }

    struct Sim {
        var policy: KiterPolicy
        var drone: CGPoint
        var hero: CGPoint
        var t = 0.0
        var telegraphs: [Double] = []
        var fires: [Double] = []
        var distances: [CGFloat] = []

        mutating func run(seconds: Double, dt: Double = 1.0 / 60, heroVelocity: CGVector = .zero) {
            let end = t + seconds
            while t < end {
                let r = policy.tick(dt: dt, position: drone, hero: hero, canSee: true)
                switch r.event {
                case .telegraph: telegraphs.append(t)
                case .fire: fires.append(t)
                case .none: break
                }
                if policy.isTelegraphing { #expect(r.velocity == .zero, "stops while it glows") }
                let speed = hypot(r.velocity.dx, r.velocity.dy)
                #expect(speed <= policy.config.speed + 0.001)
                drone.x += r.velocity.dx * CGFloat(dt); drone.y += r.velocity.dy * CGFloat(dt)
                hero.x += heroVelocity.dx * CGFloat(dt); hero.y += heroVelocity.dy * CGFloat(dt)
                distances.append(hypot(drone.x - hero.x, drone.y - hero.y))
                t += dt
            }
        }
    }

    @Test func numbersComeFromTheJSON() throws {
        let c = try Self.config()
        #expect(c.keepMin == 220 && c.keepMax == 320 && c.retreatRange == 160)
        #expect(c.telegraphSec == 0.5 && c.strafeSec == 1.2)
        #expect(Self.def.flying)
    }

    @Test(arguments: [CGVector.zero, CGVector(dx: 40, dy: 25)])
    func staysInsideItsDistanceBand(heroVelocity: CGVector) throws {
        let c = try Self.config()
        var sim = Sim(policy: KiterPolicy(config: c), drone: CGPoint(x: 500, y: 0), hero: .zero)
        sim.run(seconds: 3, heroVelocity: heroVelocity)   // approach into the band
        let entered = try #require(sim.distances.firstIndex { $0 <= c.keepMax })
        sim.run(seconds: 20, heroVelocity: heroVelocity)
        let inBand = sim.distances[entered...]
        let lo = inBand.min()!, hi = inBand.max()!
        print("KITER band \(Int(lo))…\(Int(hi)) pt (hero moving \(heroVelocity))")
        // It stands still while it glows, so a walking hero can move the distance by that much.
        let slack = 2 + CGFloat(c.telegraphSec) * hypot(heroVelocity.dx, heroVelocity.dy)
        #expect(lo >= c.keepMin - slack && hi <= c.keepMax + slack, "left the band: \(lo)…\(hi)")
        #expect(sim.fires.count >= 5, "it keeps shooting (\(sim.fires.count))")
    }

    @Test func retreatsWhenTheHeroIsCloserThanRetreatRange() throws {
        let c = try Self.config()
        var p = KiterPolicy(config: c)
        let r = p.tick(dt: 1.0 / 60, position: CGPoint(x: 150, y: 0), hero: .zero, canSee: true)
        #expect(r.velocity.dx > 0 && abs(r.velocity.dy) < 0.001, "straight away from the hero")
        #expect(abs(hypot(r.velocity.dx, r.velocity.dy) - c.speed) < 0.001, "full speed")
        #expect(r.event == .none, "no attack while too close")
    }

    @Test func telegraphsBeforeEveryShot() throws {
        let c = try Self.config()
        var sim = Sim(policy: KiterPolicy(config: c), drone: CGPoint(x: 260, y: 0), hero: .zero)
        sim.run(seconds: 20)
        #expect(sim.fires.count >= 5)
        #expect(sim.telegraphs.count >= sim.fires.count)
        for f in sim.fires {
            let tel = try #require(sim.telegraphs.last { $0 < f })
            #expect(abs((f - tel) - c.telegraphSec) < 1.0 / 30, "fire \(f - tel) s after the glow")
        }
        for (a, b) in zip(sim.telegraphs, sim.telegraphs.dropFirst()) {
            #expect(b - a >= c.cooldownSec - 1e-6, "cooldown start to start")
        }
    }

    @Test func noShotWithoutLineOfSight() throws {
        var p = KiterPolicy(config: try Self.config())
        for _ in 0..<600 {
            let r = p.tick(dt: 1.0 / 60, position: CGPoint(x: 260, y: 0), hero: .zero, canSee: false)
            #expect(r.event == .none)
        }
    }
}
