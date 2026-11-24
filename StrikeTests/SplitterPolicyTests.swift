import CoreGraphics
import Testing
@testable import Strike

/// M4-4: slimemutant split (GDD §8.1).
struct SplitterPolicyTests {
    static var data: GameData { GeneratedCorpus.data }
    static var slime: EnemyDef { data.enemies["slimemutant"]! }
    static var small: EnemyDef { data.enemies["slimemutant_small"]! }

    @Test func splitsIntoTwoSmallsAtPlusMinusOffset() throws {
        let s = try #require(Self.slime.splitInto)
        #expect(s.count == 2 && s.spawnOffset == 40 && s.spawnDelaySec == 0.3)
        let o = CGPoint(x: 500, y: 300)
        let kids = SplitterPolicy.spawns(for: Self.slime, childRadius: CGFloat(Self.small.radius), at: o, isFree: { _, _ in true })
        #expect(kids.count == 2)
        #expect(kids.allSatisfy { $0.enemyId == "slimemutant_small" && $0.delaySec == s.spawnDelaySec })
        let xs = kids.map { $0.position.x - o.x }.sorted()
        #expect(abs(xs[0] + 40) < 1e-6 && abs(xs[1] - 40) < 1e-6)
        #expect(kids.allSatisfy { abs($0.position.y - o.y) < 1e-6 })
    }

    @Test func smallsNeverSplit() {
        #expect(Self.small.splitInto == nil)
        #expect(SplitterPolicy.spawns(for: Self.small, childRadius: 11, at: .zero, isFree: { _, _ in true }).isEmpty)
    }

    /// Next to walls (real tile grids from generated levels): children are never inside a wall.
    @Test func childrenAreNeverInsideAWall() throws {
        let r = CGFloat(Self.small.radius)
        var checked = 0, moved = 0
        for id in ["l1", "l3", "l5"] {
            for level in GeneratedCorpus.levels[id]!.prefix(10) {
                let grid = level.gridAllDoorsClosed
                for y in 0..<grid.height { for x in 0..<grid.width {
                    let c = GridPoint(x, y)
                    // Floor cells next to a wall, where the parent's body still fits.
                    let p = grid.world(c)
                    guard grid.isWalkable(c), c.neighbors4.contains(where: { !grid.isWalkable($0) }),
                          !grid.isBlocked(p, radius: CGFloat(Self.slime.radius) * 0.9) else { continue }
                    let kids = SplitterPolicy.spawns(for: Self.slime, childRadius: r, at: p,
                                                     isFree: { !grid.isBlocked($0, radius: $1) })
                    for k in kids {
                        #expect(!grid.isBlocked(k.position, radius: r * 0.99) || k.position == p, "\(id): child in a wall at \(k.position)")
                        if hypot(k.position.x - p.x, k.position.y - p.y) < 39 { moved += 1 }
                    }
                    checked += 1
                } }
            }
        }
        print("SPLIT wall cells checked \(checked), children pulled in \(moved)")
        #expect(checked > 100)
    }

    @Test func popOutIsHarmlessAndNotDamageableForTheDelay() throws {
        let s = try #require(Self.slime.splitInto)
        var pop = SplitterPolicy.PopOut(delaySec: s.spawnDelaySec)
        #expect(pop.isHarmless && !pop.isDamageable)
        pop.tick(dt: s.spawnDelaySec - 0.01)
        #expect(pop.isHarmless && !pop.isDamageable)
        pop.tick(dt: 0.02)
        #expect(!pop.isHarmless && pop.isDamageable)
    }
}
