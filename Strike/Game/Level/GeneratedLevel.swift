import CoreGraphics
import Foundation

// Output types of `LevelGenerator` (pure data, no SpriteKit). Moved out of
// LevelGenerator.swift in M4-3 to keep files under 600 lines; unchanged.

/// Direction a door's corridor runs (ART_BIBLE §13.2: door art is drawn for a west–east
/// corridor; rotate the sprite by π/2 for north–south).
nonisolated enum DoorOrientation: String, Sendable, Equatable, Codable {
    case eastWest, northSouth
}

/// A generated room with its zone and position along the critical path.
nonisolated struct LevelRoom: Sendable, Equatable, Identifiable {
    let id: Int
    let rect: RoomRect
    /// 1-based zone.
    let zone: Int
    let isOnPath: Bool
    /// Index of the critical-path room this room hangs off (its own index when on the path).
    let pathIndex: Int
    /// Exactly one neighbouring room.
    let isDeadEnd: Bool
}

/// Gate door on the corridor where `zone` begins (GDD §11).
nonisolated struct GateDoor: Sendable, Equatable, Identifiable {
    let id: String
    /// Zone behind the gate.
    let zone: Int
    /// One line of `corridorWidth` corridor cells (the door spans all of them).
    let cells: [GridPoint]
    let orientation: DoorOrientation
    /// Room on the open side (zone − 1) and the room behind the gate (zone).
    let fromRoomId: Int
    let toRoomId: Int
    /// Elements that open this gate (all of them must be on).
    let elementIds: [String]
}

/// The level's single exit door, at the mouth of a niche off the exit room; the exit pad
/// lies behind it inside the niche.
nonisolated struct ExitDoor: Sendable, Equatable {
    let cells: [GridPoint]
    let orientation: DoorOrientation
    let roomId: Int
    /// Niche floor cells behind the door (door cells excluded).
    let niche: [GridPoint]
    /// Every `required` element.
    let elementIds: [String]
}

nonisolated struct PlacedElement: Sendable, Equatable, Identifiable {
    let id: String
    let type: ElementType
    /// Bottom-left cell; machines cover `cell … cell + (1, 1)`.
    let cell: GridPoint
    let roomId: Int
    let zone: Int
    let required: Bool
    let requiresItem: String?
    /// Gate this element opens (nil = counts for the exit door).
    let gateId: String?
    /// Machines: where its item was placed (resolved from the element or the level default).
    let itemPlacement: ItemPlacementRule?

    var cells: [GridPoint] {
        let n = type.footprint
        var out: [GridPoint] = []
        for dy in 0..<n { for dx in 0..<n { out.append(GridPoint(cell.x + dx, cell.y + dy)) } }
        return out
    }

    /// Centre in tile units (continuous). Spacing uses the anchor `cell`.
    var center: (x: Double, y: Double) {
        let h = Double(type.footprint) / 2
        return (Double(cell.x) + h, Double(cell.y) + h)
    }

    /// Centre in world points.
    var position: CGPoint {
        let c = center
        return CGPoint(x: c.x * TileGrid.tileSize, y: c.y * TileGrid.tileSize)
    }
}

/// A puzzle item (fuse, battery, keycard, energycore) for a machine.
nonisolated struct ItemPlacement: Sendable, Equatable, Identifiable {
    let id: String
    let itemId: String
    let cell: GridPoint
    let roomId: Int
    let zone: Int
    /// Machine the item was placed for.
    let elementId: String
}

nonisolated struct EnemySpawn: Sendable, Equatable, Identifiable {
    let id: String
    let enemyId: String
    let cell: GridPoint
    /// Home room for the leash.
    let roomId: Int

    var position: CGPoint {
        CGPoint(x: (CGFloat(cell.x) + 0.5) * TileGrid.tileSize, y: (CGFloat(cell.y) + 0.5) * TileGrid.tileSize)
    }
}

nonisolated enum PickupKind: String, Sendable, Equatable {
    case floor, datachip, weapon
}

nonisolated struct PickupPlacement: Sendable, Equatable, Identifiable {
    let id: String
    let itemId: String
    let count: Int
    let cell: GridPoint
    let roomId: Int
    let kind: PickupKind
}

nonisolated struct CratePlacement: Sendable, Equatable, Identifiable {
    let id: String
    let cell: GridPoint
    let roomId: Int
    let lootTableId: String
}

nonisolated struct CheckpointPlacement: Sendable, Equatable, Identifiable {
    let id: String
    let cell: GridPoint
    let roomId: Int
    let zone: Int
    /// Gate this checkpoint sits behind (nil for the start pad).
    let gateId: String?
}

/// Output of `LevelGenerator.generate` (pure data, no SpriteKit).
nonisolated struct GeneratedLevel: Sendable, Equatable {
    let levelId: String
    let levelIndex: Int
    /// Seed that produced this layout (requested seed + retries, or the fallback seed).
    let seedUsed: UInt64
    /// Attempts made, including the successful one.
    let attempts: Int
    let usedFallback: Bool

    /// Floor/wall map with all doors open (door cells are `.floor`).
    let grid: TileGrid
    let rooms: [LevelRoom]
    let corridors: [Corridor]
    let startRoomId: Int
    let exitRoomId: Int
    /// Room ids from start to exit.
    let criticalPath: [Int]
    let gates: [GateDoor]
    let exitDoor: ExitDoor
    let elements: [PlacedElement]
    let itemPlacements: [ItemPlacement]
    let enemySpawns: [EnemySpawn]
    let pickups: [PickupPlacement]
    let crates: [CratePlacement]
    /// Start pad first, then one per gate in zone order.
    let checkpoints: [CheckpointPlacement]
    let exitPad: GridPoint

    var heroStart: GridPoint { checkpoints[0].cell }
    var zoneCount: Int { (rooms.map(\.zone).max() ?? 1) }

    func room(at p: GridPoint) -> LevelRoom? { rooms.first { $0.rect.contains(p) } }

    func element(_ id: String) -> PlacedElement? { elements.first { $0.id == id } }

    /// Grid with the given doors closed (closed door cells become walls), for physics,
    /// line of sight and pathfinding.
    func grid(closedGates: Set<String>, exitClosed: Bool) -> TileGrid {
        var cells: [GridPoint] = gates.filter { closedGates.contains($0.id) }.flatMap(\.cells)
        if exitClosed { cells += exitDoor.cells }
        return grid.settingWalls(cells)
    }

    /// Grid with every door closed (level start).
    var gridAllDoorsClosed: TileGrid { grid(closedGates: Set(gates.map(\.id)), exitClosed: true) }

    /// Exit pad centre in world points: the middle of the niche's far row (a 2-wide niche puts it
    /// between two cells). The drawn pad, Pixel's hints and tests all use this (QA-008); `exitPad`
    /// is the far-row cell nearest to it.
    var exitPadPosition: CGPoint {
        let door = exitDoor.cells
        guard !door.isEmpty, !exitDoor.niche.isEmpty else { return grid.world(exitPad) }
        func dist(_ c: GridPoint) -> Int { door.map { $0.chebyshev(c) }.min() ?? 0 }
        let far = exitDoor.niche.map(dist).max() ?? 0
        let row = exitDoor.niche.filter { dist($0) == far }.map { grid.world($0) }
        return CGPoint(x: row.map(\.x).reduce(0, +) / CGFloat(row.count), y: row.map(\.y).reduce(0, +) / CGFloat(row.count))
    }

    /// FNV-1a over the grid and every placement, stable across runs of the same build.
    var stableHash: UInt64 {
        var h = StableHasher()
        h.mix(levelId); h.mix(Int(seedUsed)); h.mix(grid.width); h.mix(grid.height)
        for t in grid.tiles { h.mix(Int(t.rawValue)) }
        for r in rooms { h.mix(r.id); h.mix(r.rect.x); h.mix(r.rect.y); h.mix(r.rect.width); h.mix(r.rect.height); h.mix(r.zone); h.mix(r.isOnPath ? 1 : 0) }
        h.mix(startRoomId); h.mix(exitRoomId); criticalPath.forEach { h.mix($0) }
        for g in gates { h.mix(g.id); h.mix(g.zone); g.cells.forEach { h.mix($0) }; g.elementIds.forEach { h.mix($0) } }
        exitDoor.cells.forEach { h.mix($0) }; exitDoor.elementIds.forEach { h.mix($0) }
        for e in elements { h.mix(e.id); h.mix(e.type.rawValue); h.mix(e.cell); h.mix(e.roomId); h.mix(e.required ? 1 : 0) }
        for i in itemPlacements { h.mix(i.id); h.mix(i.itemId); h.mix(i.cell) }
        for e in enemySpawns { h.mix(e.enemyId); h.mix(e.cell); h.mix(e.roomId) }
        for p in pickups { h.mix(p.itemId); h.mix(p.cell); h.mix(p.count) }
        for c in crates { h.mix(c.cell) }
        for c in checkpoints { h.mix(c.id); h.mix(c.cell) }
        h.mix(exitPad)
        return h.value
    }
}

nonisolated struct StableHasher {
    private(set) var value: UInt64 = 0xcbf2_9ce4_8422_2325

    mutating func mix(_ v: Int) {
        var x = UInt64(bitPattern: Int64(v))
        for _ in 0..<8 {
            value ^= x & 0xff
            value = value &* 0x100_0000_01b3
            x >>= 8
        }
    }

    mutating func mix(_ s: String) {
        for b in s.utf8 { value ^= UInt64(b); value = value &* 0x100_0000_01b3 }
        mix(s.utf8.count)
    }

    mutating func mix(_ p: GridPoint) { mix(p.x); mix(p.y) }
}
