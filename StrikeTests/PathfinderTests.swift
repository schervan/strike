import CoreGraphics
import Testing
@testable import Strike

@MainActor
struct PathfinderTests {
    /// 12 × 10 open room with a 2 × 2 pillar at (5, 4).
    static func pillarRoom() -> TileGrid {
        var g = TileGrid(width: 12, height: 10)
        for y in 1..<9 { for x in 1..<11 { g[x, y] = .floor } }
        for y in 4...5 { for x in 5...6 { g[x, y] = .wall } }
        return g
    }

    /// Two 5 × 5 rooms joined by a 2-wide corridor; door cells at x = 7.
    static func twoRooms() -> (TileGrid, [GridPoint]) {
        var g = TileGrid(width: 16, height: 8)
        for y in 1..<6 { for x in 1..<6 { g[x, y] = .floor } }
        for y in 1..<6 { for x in 10..<15 { g[x, y] = .floor } }
        for x in 6..<10 { for y in 2...3 { g[x, y] = .floor } }
        return (g, [GridPoint(7, 2), GridPoint(7, 3)])
    }

    @Test func pathAroundAPillarNeverEntersAWall() {
        let g = Self.pillarRoom()
        let pf = Pathfinder(grid: g)
        let cells = pf.cellPath(from: GridPoint(3, 4), to: GridPoint(8, 5))
        #expect(!cells.isEmpty)
        #expect(cells.first == GridPoint(3, 4) && cells.last == GridPoint(8, 5))
        #expect(cells.allSatisfy { g.isWalkable($0) })
        for (a, b) in zip(cells, cells.dropFirst()) { #expect(abs(a.x - b.x) + abs(a.y - b.y) == 1) }  // no diagonals

        let radius: CGFloat = 16
        let from = g.world(GridPoint(3, 4)), to = g.world(GridPoint(8, 5))
        let points = pf.path(from: from, to: to, radius: radius)
        #expect(points.last == to)
        #expect(points.count >= 2)                        // must bend around the pillar
        var prev = from
        for p in points {
            #expect(g.isSweepClear(from: prev, to: p, radius: radius))
            #expect(g.isWalkable(g.cell(at: p)))
            prev = p
        }
    }

    @Test func noPathThroughAClosedDoorUntilItOpens() {
        let (open, door) = Self.twoRooms()
        let pf = Pathfinder(grid: open.settingWalls(door))
        let a = open.world(GridPoint(2, 2)), b = open.world(GridPoint(12, 3))
        #expect(pf.path(from: a, to: b, radius: 16).isEmpty)
        #expect(pf.steps(from: GridPoint(2, 2), to: GridPoint(12, 3)) == nil)
        pf.setCells(door, walkable: true)
        let p = pf.path(from: a, to: b, radius: 16)
        #expect(!p.isEmpty)
        #expect(p.last == b)
        #expect(pf.steps(from: GridPoint(2, 2), to: GridPoint(12, 3)) != nil)
        pf.setCells(door, walkable: false)
        #expect(pf.path(from: a, to: b, radius: 16).isEmpty)
    }

    @Test func straightLineWhenVisibleAndEmptyInTheSameCell() {
        let g = Self.pillarRoom()
        let pf = Pathfinder(grid: g)
        let a = g.world(GridPoint(2, 2)), b = g.world(GridPoint(9, 2))
        #expect(pf.path(from: a, to: b, radius: 16) == [b])
        #expect(pf.path(from: a, to: CGPoint(x: a.x + 5, y: a.y), radius: 16).isEmpty)
    }

    @Test func startInsideAWallSnapsToTheNearestFloor() {
        let g = Self.pillarRoom()
        let pf = Pathfinder(grid: g)
        let cells = pf.cellPath(from: GridPoint(0, 3), to: GridPoint(9, 7))
        #expect(cells.first == GridPoint(1, 3))
        #expect(cells.last == GridPoint(9, 7))
    }

    @Test func pathsExistAcrossAGeneratedLevelWithDoorsOpen() {
        let l = LevelGenerator.generate(GeneratedCorpus.def("l4"), seed: 3, catalog: GeneratedCorpus.catalog)
        let pf = Pathfinder(grid: l.gridAllDoorsClosed)
        let exitRoom = l.rooms[l.exitRoomId].rect.centerCell
        #expect(pf.cellPath(from: l.heroStart, to: exitRoom).isEmpty)
        pf.rebuild(grid: l.grid)
        let p = pf.cellPath(from: l.heroStart, to: exitRoom)
        #expect(!p.isEmpty && p.allSatisfy { l.grid.isWalkable($0) })
    }
}
