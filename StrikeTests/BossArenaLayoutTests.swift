import SpriteKit
import Testing
@testable import Strike

/// M4-4: the fixed boss arena (GDD §9).
struct BossArenaLayoutTests {
    static var data: GameData { GeneratedCorpus.data }
    static var l5: LevelDef { data.levels["l5"]! }
    static var core: String { data.enemies["megamech"]!.phases![1].unlockBy!.requiresItem }
    static func arena() throws -> BossArenaLayout.Arena { try #require(BossArenaLayout.build(l5, coreItemId: core)) }

    @Test func onlyTheBossLevelHasAnArena() {
        #expect(BossArenaLayout.build(Self.data.levels["l1"]!, coreItemId: Self.core) == nil)
        #expect(Self.l5.bossId == "megamech" && Self.l5.bossArena == BossArenaDef(width: 22, height: 16, coreMachines: 2, pillars: 4))
    }

    @Test func layoutIsValidAndSolvable() throws {
        let a = try Self.arena()
        let l = a.level
        #expect(l.grid.width == 22 && l.grid.height == 16)
        let problems = BossArenaLayout.problems(a, bossRadius: CGFloat(Self.data.enemies["megamech"]!.radius), def: Self.l5)
        #expect(problems.isEmpty, "\(problems)")
        #expect(SolvabilityChecker.lockAndKey(l).isEmpty)
        #expect(SolvabilityChecker.lockAndKey(BossArenaLayout.withCarrierCores(a)).isEmpty, "both core machines can be powered")
        #expect(l.heroStart == l.checkpoints[0].cell && l.checkpoints[0].id == BossArenaLayout.entranceCheckpointId)
        #expect(l.exitDoor.elementIds.isEmpty, "the sealed entrance never opens from elements")
    }

    @Test func coreMachinesSitOnTheLeftAndRightWalls() throws {
        let a = try Self.arena()
        let room = a.room
        let ms = a.level.elements
        #expect(ms.count == 2 && ms.allSatisfy { $0.type == .machine && $0.requiresItem == Self.core && !$0.required })
        let xs = ms.map(\.cell.x).sorted()
        #expect(xs[0] == room.x && xs[1] + 1 == room.maxX - 1)
        #expect(ms[0].cell.y == ms[1].cell.y)
    }

    @Test func fixedPickupsSitNextToPillars() throws {
        let a = try Self.arena()
        let fixed = try #require(Self.l5.pickups.fixed)
        #expect(a.pillars.count == 4)
        let pillarCells = Set(a.pillars.flatMap(\.cells))
        #expect(a.level.pickups.map(\.itemId) == fixed.map(\.itemId))
        for p in a.level.pickups {
            #expect(p.cell.neighbors4.contains(where: pillarCells.contains), "\(p.id) at \(p.cell)")
            #expect(a.level.grid.isWalkable(p.cell))
        }
        #expect(Set(a.level.pickups.map(\.cell)).count == a.level.pickups.count, "no two on one cell")
    }

    /// Pass B builds the arena with the normal builder: make sure that works today.
    @MainActor @Test func levelBuilderAndPathfinderAcceptTheArena() throws {
        let a = try Self.arena()
        let built = LevelBuilder.build(a.level, def: Self.l5, data: Self.data)
        #expect(built.interactables.count == 2)
        #expect(built.checkpoints[BossArenaLayout.entranceCheckpointId] != nil)
        let pf = Pathfinder(grid: a.level.gridAllDoorsClosed)
        let from = a.level.grid.world(a.level.heroStart)
        for c in a.carrierSpawns + [a.bossSpawn] {
            #expect(pf.nextWaypoint(from: a.level.grid.world(c), to: from, radius: 16) != nil, "path from \(c)")
        }
    }
}
