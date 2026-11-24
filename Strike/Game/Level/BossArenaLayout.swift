import CoreGraphics
import Foundation

/// The fixed boss arena at the end of L5 (GDD §9, DECISIONS 2026-11-24): one `width × height`
/// tile room (`levels.json → bossArena`), `pillars` 2 × 2 pillars for cover, `coreMachines`
/// core machines (`requiresItem` = the boss's `unlockBy.requiresItem`) on the left and right
/// walls, the entrance checkpoint just inside the sealed entrance door, and `pickups.fixed` next
/// to the pillars. The output is a `GeneratedLevel`, so `LevelBuilder`, the minimap and the
/// `Pathfinder` work unchanged. Pure and deterministic (no seed).
///
/// Notes for the scene (M4-6): the "exit door" is the sealed entrance (2 cells in the bottom wall,
/// niche behind it). It has no elements and must never open on the arena stage; the boss's
/// defeat ends the level. The core machines are not `required` (they pop the boss shield).
nonisolated enum BossArenaLayout {
    struct Arena: Sendable, Equatable {
        let level: GeneratedLevel
        /// Pillar footprints (tile rects, walls in `level.grid`).
        let pillars: [RoomRect]
        /// Boss start cell (the body centre sits in the cell centre).
        let bossSpawn: GridPoint
        /// Where phase spawns (core carriers) appear.
        let carrierSpawns: [GridPoint]
        let coreMachineIds: [String]

        var room: RoomRect { level.rooms[0].rect }
        var pillarWorldRects: [CGRect] { pillars.map(BossArenaLayout.worldRect) }
        /// The arena floor in world points (dash bounds).
        var floorWorldRect: CGRect { BossArenaLayout.worldRect(room) }
        var bossSpawnPosition: CGPoint { level.grid.world(bossSpawn) }
    }

    static let entranceCheckpointId = "checkpoint_arena"
    static let pillarSize = 2
    /// Rows below the room: entrance door row + one niche row (the bottom border is the wall).
    static let entranceRows = 2

    /// Nil when the level has no `bossArena`.
    static func build(_ def: LevelDef, coreItemId: String) -> Arena? {
        guard let a = def.bossArena, a.width >= 12, a.height >= 10 else { return nil }
        let w = a.width, h = a.height
        let room = RoomRect(x: 1, y: 1 + entranceRows, width: w - 2, height: h - 2 - entranceRows)
        var grid = TileGrid(width: w, height: h)
        BSPLayout.carveRooms([room], into: &grid)

        // Entrance (sealed exit door) in the bottom wall, niche behind it.
        let cx = w / 2
        let door = [GridPoint(cx - 1, room.y - 1), GridPoint(cx, room.y - 1)]
        let niche = [GridPoint(cx - 1, room.y - 2), GridPoint(cx, room.y - 2)]
        BSPLayout.carve(door + niche, into: &grid)

        // Pillars: a symmetric 2 × 2 pattern at the quarter points (up to 4).
        let px = [room.x + room.width / 4 - 1, room.x + 3 * room.width / 4 - 1]
        let py = [room.y + room.height / 3 - 1, room.y + 2 * room.height / 3 - 1]
        let spots = [(px[0], py[0]), (px[1], py[0]), (px[0], py[1]), (px[1], py[1])]
        let pillars = spots.prefix(max(0, a.pillars)).map { RoomRect(x: $0.0, y: $0.1, width: pillarSize, height: pillarSize) }
        for p in pillars { for c in p.cells { grid[c] = .wall } }

        // Core machines against the left and right walls (a third one at the top wall).
        let my = room.y + room.height / 2 - 1
        let machineSpots: [(String, GridPoint)] = [
            ("core_left", GridPoint(room.x, my)), ("core_right", GridPoint(room.maxX - 2, my)),
            ("core_top", GridPoint(cx - 1, room.maxY - 2)),
        ]
        let elements = machineSpots.prefix(max(0, a.coreMachines)).map { id, cell in
            PlacedElement(id: id, type: .machine, cell: cell, roomId: 0, zone: 1, required: false,
                          requiresItem: coreItemId, gateId: nil, itemPlacement: nil)
        }

        let checkpoint = CheckpointPlacement(id: entranceCheckpointId, cell: GridPoint(cx, room.y + 1), roomId: 0,
                                             zone: 1, gateId: nil)
        let boss = GridPoint(cx, room.y + 2 * room.height / 3)
        let carriers = [GridPoint(room.x + 1, room.maxY - 2), GridPoint(room.maxX - 2, room.maxY - 2)]

        // Fixed pickups: the floor cell next to a pillar that is closest to the arena centre.
        let centre = GridPoint(cx, room.y + room.height / 2)
        var used = Set([checkpoint.cell, boss] + carriers + elements.flatMap(\.cells))
        var pickups: [PickupPlacement] = []
        for (i, f) in (def.pickups.fixed ?? []).enumerated() where !pillars.isEmpty {
            let p = pillars[i % pillars.count]
            let ring = p.cells.flatMap(\.neighbors4).filter { !p.contains($0) && grid.isWalkable($0) && !used.contains($0) }
            guard let cell = ring.min(by: { ($0.distance(centre), $0) < ($1.distance(centre), $1) }) else { continue }
            used.insert(cell)
            pickups.append(PickupPlacement(id: "fixed_\(i)_\(f.itemId)", itemId: f.itemId, count: max(1, f.count),
                                           cell: cell, roomId: 0, kind: .floor))
        }

        let level = GeneratedLevel(
            levelId: def.id, levelIndex: def.index, seedUsed: 0, attempts: 1, usedFallback: false,
            grid: grid, rooms: [LevelRoom(id: 0, rect: room, zone: 1, isOnPath: true, pathIndex: 0, isDeadEnd: true)],
            corridors: [], startRoomId: 0, exitRoomId: 0, criticalPath: [0], gates: [],
            exitDoor: ExitDoor(cells: door, orientation: .northSouth, roomId: 0, niche: niche, elementIds: []),
            elements: Array(elements), itemPlacements: [], enemySpawns: [], pickups: pickups, crates: [],
            checkpoints: [checkpoint], exitPad: GridPoint(cx, room.y - 2))
        return Arena(level: level, pillars: Array(pillars), bossSpawn: boss, carrierSpawns: carriers,
                     coreMachineIds: elements.map(\.id))
    }

    static func worldRect(_ r: RoomRect) -> CGRect {
        let t = TileGrid.tileSize
        return CGRect(x: CGFloat(r.x) * t, y: CGFloat(r.y) * t, width: CGFloat(r.width) * t, height: CGFloat(r.height) * t)
    }

    /// The arena as if every core carrier dropped its core where it spawns: for
    /// `SolvabilityChecker.lockAndKey` (every core machine can be powered).
    static func withCarrierCores(_ a: Arena) -> GeneratedLevel {
        let l = a.level
        let items = l.elements.enumerated().map { i, m in
            ItemPlacement(id: "carrier_core_\(i)", itemId: m.requiresItem ?? "", cell: a.carrierSpawns[i % a.carrierSpawns.count],
                          roomId: 0, zone: 1, elementId: m.id)
        }
        return GeneratedLevel(
            levelId: l.levelId, levelIndex: l.levelIndex, seedUsed: l.seedUsed, attempts: l.attempts,
            usedFallback: l.usedFallback, grid: l.grid, rooms: l.rooms, corridors: l.corridors,
            startRoomId: l.startRoomId, exitRoomId: l.exitRoomId, criticalPath: l.criticalPath, gates: l.gates,
            exitDoor: ExitDoor(cells: l.exitDoor.cells, orientation: l.exitDoor.orientation, roomId: 0,
                               niche: l.exitDoor.niche, elementIds: l.elements.map(\.id)),
            elements: l.elements, itemPlacements: items, enemySpawns: l.enemySpawns, pickups: l.pickups,
            crates: l.crates, checkpoints: l.checkpoints, exitPad: l.exitPad)
    }

    /// Layout checks (empty = fine): connected floor, reachable machines/spawns/pickups with the
    /// entrance sealed, room for the boss body, pillars clear of walls and machines, fixed pickups
    /// next to pillars, and lock-and-key with carrier cores.
    static func problems(_ a: Arena, bossRadius: CGFloat, def: LevelDef) -> [String] {
        var out: [String] = []
        let l = a.level, g = l.grid
        let all = g.floodFill(from: [l.heroStart])
        if g.tiles.indices.contains(where: { g.tiles[$0] == .floor && !all[$0] }) { out.append("floor not connected") }
        let sealed = g.floodFill(from: [l.heroStart], blocked: Set(l.exitDoor.cells))
        func reach(_ c: GridPoint) -> Bool { g.contains(c) && sealed[g.index(c)] }
        for m in l.elements where !m.cells.flatMap(\.neighbors4).contains(where: reach) { out.append("\(m.id) unreachable") }
        for c in a.carrierSpawns where !reach(c) { out.append("carrier spawn \(c) unreachable") }
        if !reach(a.bossSpawn) { out.append("boss spawn unreachable") }
        let k = Int((bossRadius / CGFloat(TileGrid.tileSize)).rounded(.up))
        for dy in -k...k { for dx in -k...k where !g.isWalkable(GridPoint(a.bossSpawn.x + dx, a.bossSpawn.y + dy)) {
            out.append("boss body blocked at \(GridPoint(a.bossSpawn.x + dx, a.bossSpawn.y + dy))")
        } }
        if a.pillars.count != def.bossArena?.pillars { out.append("pillars \(a.pillars.count) ≠ \(def.bossArena?.pillars ?? 0)") }
        if a.coreMachineIds.count != def.bossArena?.coreMachines { out.append("core machines \(a.coreMachineIds.count) ≠ \(def.bossArena?.coreMachines ?? 0)") }
        let machineCells = Set(l.elements.flatMap(\.cells))
        for p in a.pillars {
            let ring = p.cells.flatMap { c in (-1...1).flatMap { dy in (-1...1).map { dx in GridPoint(c.x + dx, c.y + dy) } } }
                .filter { !p.contains($0) }
            if ring.contains(where: { cell in !g.isWalkable(cell) && !a.pillars.contains { $0.contains(cell) } }) {
                out.append("pillar \(p) touches a wall")
            }
            if ring.contains(where: machineCells.contains) { out.append("pillar \(p) touches a machine") }
        }
        let pillarCells = Set(a.pillars.flatMap(\.cells))
        if l.pickups.count != (def.pickups.fixed ?? []).count { out.append("fixed pickups \(l.pickups.count) ≠ \((def.pickups.fixed ?? []).count)") }
        for p in l.pickups {
            if !reach(p.cell) { out.append("\(p.id) unreachable") }
            if !p.cell.neighbors4.contains(where: pillarCells.contains) { out.append("\(p.id) not next to a pillar") }
        }
        out += SolvabilityChecker.lockAndKey(withCarrierCores(a))
        return out
    }
}
