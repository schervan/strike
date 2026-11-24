import CoreGraphics
import Testing
@testable import Strike

/// M4-4: MEGA-MECH attack geometry (GDD §9).
struct BossAttacksTests {
    static var mech: EnemyDef { GeneratedCorpus.data.enemies["megamech"]! }
    static func attack(_ type: String) -> BossAttackDef {
        mech.phases!.flatMap(\.attacks).first { $0.type == type }!
    }
    static var heroR: CGFloat { CGFloat(GeneratedCorpus.data.hero.radius) }

    @Test func stompRingExpandsFrom140To220() {
        let a = Self.attack(BossAttackDef.stomp)
        #expect(a.telegraphRadius == 140 && a.range == 220)
        #expect(StompWave.radius(at: 0, attack: a) == 140)
        #expect(abs(StompWave.radius(at: a.effectiveWaveSec, attack: a)! - 220) < 1e-9)
        #expect(StompWave.radius(at: a.effectiveWaveSec + 0.01, attack: a) == nil)
        #expect(StompWave.impactHits(heroDistance: 150, heroRadius: Self.heroR, attack: a), "body overlaps the red ring")
        #expect(!StompWave.impactHits(heroDistance: 200, heroRadius: Self.heroR, attack: a))
        // The travelling ring catches a hero at 200 pt at some moment, never one at 260 pt.
        let ts = stride(from: 0.0, through: a.effectiveWaveSec, by: 0.01)
        #expect(ts.contains { StompWave.waveHits(heroDistance: 200, heroRadius: Self.heroR, at: $0, attack: a) })
        #expect(!ts.contains { StompWave.waveHits(heroDistance: 260, heroRadius: Self.heroR, at: $0, attack: a) })
    }

    @Test func starVolleyIsSixRocketsAcross70Degrees() {
        let a = Self.attack(BossAttackDef.volley)
        let angles = StarVolley.angles(toward: 0, attack: a)
        #expect(angles.count == 6)
        let deg = angles.map { Double($0) * 180 / .pi }
        #expect(abs(deg.first! + 35) < 1e-9 && abs(deg.last! - 35) < 1e-9)
        #expect(a.projectileSpeed! <= 300 && a.projectileRadius! >= 8, "GDD §8: enemy shots big and slow")
    }

    @Test func aHeroInsideAGapIsNeverHit() {
        let a = Self.attack(BossAttackDef.laserSweep)
        #expect(a.gaps == 2 && (a.sweepDegPerSec ?? 0) > 0 && a.gapDeg != nil && a.sweepSec != nil, "values come from the JSON")
        let start: CGFloat = 0.4
        var checks = 0
        for t in stride(from: 0.0, through: a.effectiveSweepSec, by: 0.02) {
            let gaps = LaserSweep.gapCenters(at: t, startAngle: start, attack: a)
            #expect(gaps.count == 2)
            for g in gaps {
                for d in stride(from: CGFloat(Self.mech.radius) + Self.heroR, through: CGFloat(a.range), by: 40) {
                    // Anywhere in the gap where the whole body fits.
                    let room = CGFloat(a.effectiveGapDeg / 2) * .pi / 180 - LaserSweep.angularHalfWidth(heroDistance: d, heroRadius: Self.heroR)
                    #expect(room > 0, "the gap fits the hero at \(d) pt")
                    for k in [-0.99, -0.5, 0, 0.5, 0.99] as [CGFloat] {
                        #expect(!LaserSweep.hits(heroAngle: g + room * k, heroDistance: d, heroRadius: Self.heroR, at: t,
                                                 startAngle: start, attack: a))
                        checks += 1
                    }
                }
            }
        }
        #expect(checks > 1000)
    }

    @Test func outsideAGapTheBeamHitsAndPillarsAndRangeProtect() {
        let a = Self.attack(BossAttackDef.laserSweep)
        let between = LaserSweep.gapCenters(at: 1, startAngle: 0, attack: a)[0] + .pi / 2   // halfway between the 2 gaps
        #expect(LaserSweep.hits(heroAngle: between, heroDistance: 200, heroRadius: Self.heroR, at: 1, startAngle: 0, attack: a))
        #expect(!LaserSweep.hits(heroAngle: between, heroDistance: 200, heroRadius: Self.heroR, at: 1, startAngle: 0, attack: a,
                                 hasLineOfSight: false), "behind a pillar")
        #expect(!LaserSweep.hits(heroAngle: between, heroDistance: CGFloat(a.range) + 40, heroRadius: Self.heroR, at: 1,
                                 startAngle: 0, attack: a), "out of range")
        #expect(!LaserSweep.hits(heroAngle: between, heroDistance: 200, heroRadius: Self.heroR, at: a.effectiveSweepSec + 0.1,
                                 startAngle: 0, attack: a), "the sweep is over")
    }

    @Test func dashStopsAtAPillarOrTheWall() {
        let r: CGFloat = 72
        let bounds = CGRect(x: 0, y: 0, width: 1280, height: 768)
        let start = CGPoint(x: 200, y: 384)
        let pillar = CGRect(x: 600, y: 320, width: 128, height: 128)
        let hit = BossDash.path(from: start, toward: CGPoint(x: 1000, y: 384), radius: r, maxDistance: 900, bounds: bounds, pillars: [pillar])
        #expect(hit.pillarIndex == 0 && abs(hit.end.x - (600 - r)) < 1e-6 && hit.end.y == 384)
        let wall = BossDash.path(from: start, toward: CGPoint(x: 260, y: 760), radius: r, maxDistance: 2000, bounds: bounds,
                                 pillars: [pillar])
        #expect(!wall.hitPillar)
        #expect(bounds.insetBy(dx: r - 0.01, dy: r - 0.01).contains(wall.end), "stays inside the arena")
        let short = BossDash.path(from: start, toward: CGPoint(x: 200, y: 600), radius: r, maxDistance: 100, bounds: bounds, pillars: [])
        #expect(abs(short.length - 100) < 1e-6, "max distance")
        #expect(BossDash.hits(hit, hero: CGPoint(x: 400, y: 384 + 80), heroRadius: Self.heroR, bossRadius: r))
        #expect(!BossDash.hits(hit, hero: CGPoint(x: 400, y: 384 + 100), heroRadius: Self.heroR, bossRadius: r))
    }

    /// GDD §9 "stay close and walk with the gap": the hero can keep pace with a gap out to this distance.
    @Test func aWalkingHeroCanFollowAGapNearTheBoss() {
        let a = Self.attack(BossAttackDef.laserSweep)
        let omega = CGFloat(a.sweepDegPerSec!) * .pi / 180
        let followable = CGFloat(GeneratedCorpus.data.hero.moveSpeed) / omega
        print("SWEEP gap followable within \(Int(followable)) pt")
        #expect(followable >= 280, "a gap must be followable well outside the boss body")
    }

    @Test func eachAttackFitsInsideItsCooldown() {
        for p in Self.mech.phases! {
            for a in p.attacks {
                let busy = BossBrain.busySec(a)
                #expect(a.telegraphSec >= 0.4, "\(a.type): telegraph ≥ 0.4 s (GDD §8)")
                #expect(busy <= a.cooldownSec * p.effectiveCooldownMultiplier + 1e-9,
                        "\(p.id) \(a.type): busy \(busy) s > cooldown")
            }
        }
    }
}
