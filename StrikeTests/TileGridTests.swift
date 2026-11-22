import CoreGraphics
import Testing
@testable import Strike

struct TileGridTests {
    /// 10 × 8 room: wall ring, 2 × 2 pillar at (4, 3).
    static func room() -> TileGrid {
        var g = TileGrid(width: 10, height: 8)
        for y in 1..<7 { for x in 1..<9 { g[x, y] = .floor } }
        for y in 3...4 { for x in 4...5 { g[x, y] = .wall } }
        return g
    }

    @Test func worldAndCellRoundTrip() {
        let g = Self.room()
        #expect(TileGrid.tileSize == 64)
        let p = GridPoint(3, 5)
        #expect(g.world(p) == CGPoint(x: 224, y: 352))
        #expect(g.cell(at: g.world(p)) == p)
        #expect(g.cell(at: CGPoint(x: 0, y: 0)) == GridPoint(0, 0))
        #expect(g.cell(at: CGPoint(x: -1, y: 63.9)) == GridPoint(-1, 0))
        #expect(g.bounds == CGRect(x: 0, y: 0, width: 640, height: 512))
    }

    @Test func outOfBoundsReadsAsWall() {
        let g = Self.room()
        #expect(g[GridPoint(-1, 0)] == .wall)
        #expect(g[GridPoint(10, 3)] == .wall)
        #expect(!g.isWalkable(GridPoint(20, 20)))
        #expect(g.isWalkable(GridPoint(1, 1)))
        #expect(!g.isWalkable(GridPoint(4, 3)))
        #expect(g.floorCount == 8 * 6 - 4)
    }

    @Test func lineOfSightIsBlockedByThePillar() {
        let g = Self.room()
        #expect(!g.hasLineOfSight(from: g.world(GridPoint(2, 3)), to: g.world(GridPoint(7, 4))))
        #expect(g.hasLineOfSight(from: g.world(GridPoint(2, 1)), to: g.world(GridPoint(7, 1))))
        #expect(g.hasLineOfSight(from: g.world(GridPoint(2, 6)), to: g.world(GridPoint(7, 6))))
        #expect(g.hasLineOfSight(from: g.world(GridPoint(2, 2)), to: g.world(GridPoint(2, 2))))
        // Into a wall cell is never visible.
        #expect(!g.hasLineOfSight(from: g.world(GridPoint(2, 2)), to: g.world(GridPoint(0, 2))))
    }

    @Test func lineOfSightDoesNotSlipThroughDiagonalCorners() {
        var g = TileGrid(width: 4, height: 4, fill: .floor)
        g[1, 2] = .wall
        g[2, 1] = .wall
        // Exactly through the shared corner of the two walls.
        #expect(!g.hasLineOfSight(from: g.world(GridPoint(1, 1)), to: g.world(GridPoint(2, 2))))
        #expect(g.hasLineOfSight(from: g.world(GridPoint(0, 0)), to: g.world(GridPoint(1, 1))))
    }

    @Test func isBlockedTouchesWallsAndPillars() {
        let g = Self.room()
        let c = g.world(GridPoint(2, 2))
        #expect(!g.isBlocked(c, radius: 16))
        #expect(g.isBlocked(CGPoint(x: 64 + 10, y: c.y), radius: 16))      // 10 pt from the left wall
        #expect(!g.isBlocked(CGPoint(x: 64 + 20, y: c.y), radius: 16))
        #expect(g.isBlocked(CGPoint(x: 4 * 64 - 8, y: 3.5 * 64), radius: 16)) // next to the pillar
        #expect(g.isBlocked(g.world(GridPoint(4, 3)), radius: 0))           // inside the pillar
        #expect(g.isBlocked(CGPoint(x: -10, y: 100), radius: 1))            // off the map
    }

    @Test func sweepAndFloodFill() {
        let g = Self.room()
        #expect(!g.isSweepClear(from: g.world(GridPoint(2, 3)), to: g.world(GridPoint(7, 3)), radius: 16))
        #expect(g.isSweepClear(from: g.world(GridPoint(2, 1)), to: g.world(GridPoint(7, 1)), radius: 16))
        let reach = g.floodFill(from: [GridPoint(1, 1)])
        #expect(reach.filter { $0 }.count == g.floorCount)
        // A wall line across x = 3 splits the room.
        let split = g.settingWalls((1..<7).map { GridPoint(3, $0) })
        let half = split.floodFill(from: [GridPoint(1, 1)])
        #expect(!half[split.index(GridPoint(7, 1))])
        #expect(half[split.index(GridPoint(2, 6))])
    }
}
