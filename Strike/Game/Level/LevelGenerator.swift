import CoreGraphics
import Foundation

/// Lookups the generator needs from the other data files (threat costs, which blaster an
/// ammo item belongs to). Built from `GameData` so balance numbers stay in JSON.
nonisolated struct GeneratorCatalog: Sendable {
    let threatCost: [String: Int]
    /// Enemies with `moveSpeed == 0` (turrets: GDD §14.1 step 6 keeps them ≥ 2 from walls/doorways).
    let staticEnemies: Set<String>
    /// Ammo item id → weapon id.
    let weaponForAmmo: [String: String]
    let weaponUnlockLevel: [String: Int]
    let itemCategory: [String: ItemCategory]

    init(data: GameData) {
        threatCost = data.enemies.mapValues(\.threatCost)
        staticEnemies = Set(data.enemies.values.filter { $0.moveSpeed <= 0 }.map(\.id))
        var ammo: [String: String] = [:]
        for w in data.weapons.values { ammo[w.ammoId] = w.id }
        weaponForAmmo = ammo
        weaponUnlockLevel = data.weapons.mapValues(\.unlockLevel)
        itemCategory = data.items.mapValues(\.category)
    }

    /// Blasters a player has when starting `levelIndex` on the linear path (unlocked earlier).
    func ownsWeapon(_ weaponId: String, atLevel levelIndex: Int) -> Bool {
        guard let u = weaponUnlockLevel[weaponId] else { return false }
        return u <= 1 || u < levelIndex
    }
}

/// GDD §14: BSP rooms + corridors, zones with gate doors, puzzle and spawn placement, then
/// validation (§14.3). Retries `seed + 1` up to `maxAttempts`, then the level's `fallbackSeed`.
nonisolated enum LevelGenerator {
    static let datachipItemId = "datachip"
    /// Exit niche depth in tiles: door row + two rows for the exit pad.
    static let exitNicheDepth = 3
    /// Room cells within this Chebyshev distance of a corridor mouth stay free (no blocking).
    static let doorwayReserveDepth = 2

    static func generate(_ level: LevelDef, seed: UInt64, data: GameData) -> GeneratedLevel {
        generate(level, seed: seed, catalog: GeneratorCatalog(data: data))
    }

    static func generate(_ level: LevelDef, seed: UInt64, catalog: GeneratorCatalog) -> GeneratedLevel {
        let tries = max(1, level.generator.maxAttempts)
        for i in 0..<tries {
            let s = seed &+ UInt64(i)
            if let l = attempt(level, seed: s, catalog: catalog, attempts: i + 1, fallback: false),
               SolvabilityChecker.problems(l, def: level, catalog: catalog).isEmpty {
                return l
            }
        }
        // Fallback: the hand-checked seed. If even that fails (data changed), keep stepping so the
        // game never breaks; `SolvabilityTests` asserts the fallback seed itself validates.
        for i in 0..<max(tries, 200) {
            let s = level.fallbackSeed &+ UInt64(i)
            if let l = attempt(level, seed: s, catalog: catalog, attempts: tries + i + 1, fallback: true),
               SolvabilityChecker.problems(l, def: level, catalog: catalog).isEmpty {
                return l
            }
        }
        // Unreachable with valid data; return the raw fallback attempt so callers still get a map.
        return attempt(level, seed: level.fallbackSeed, catalog: catalog, attempts: tries + 1, fallback: true)
            ?? emptyLevel(level)
    }

    /// One generation attempt for exactly `seed`, without validation. Nil when the layout cannot
    /// satisfy the recipe (too few rooms, no gate bridge, no exit niche, puzzle does not fit, …).
    static func attempt(_ level: LevelDef, seed: UInt64, catalog: GeneratorCatalog,
                        attempts: Int = 1, fallback: Bool = false) -> GeneratedLevel? {
        let p = level.generator
        let w = max(1, p.corridorWidth)
        let random = LevelRandom(seed: seed)

        // Step 1–2: rooms and tree corridors.
        guard let layout = BSPLayout.makeRooms(p, random) else { return nil }
        var grid = TileGrid(width: p.gridWidth, height: p.gridHeight)
        BSPLayout.carveRooms(layout.rooms, into: &grid)
        BSPLayout.connectTree(layout, width: w, grid: &grid, random: random)
        var graph = LevelGraph.build(grid: grid, rooms: layout.rooms)
        guard !graph.distances(from: 0).contains(-1) else { return nil }

        // Step 3: start, exit (needs room for the exit niche), critical path.
        let start = graph.startRoom(mapWidth: p.gridWidth)
        var exitChoice: (room: Int, niche: Niche)?
        for cand in graph.roomsByDistance(from: start).prefix(3) {
            if let n = findNiche(layout.rooms[cand], grid: grid, width: w, random: random) {
                exitChoice = (cand, n)
                break
            }
        }
        guard let (exit, niche) = exitChoice else { return nil }
        var path = graph.shortestPath(from: start, to: exit)
        guard path.count >= p.zones + 1 else { return nil }

        // Step 4: zones split by gate bridges on the critical path.
        guard let cuts = chooseCuts(level, graph: graph, path: path, start: start) else { return nil }
        var gateDrafts: [(zone: Int, from: Int, to: Int, cells: [GridPoint], orientation: DoorOrientation)] = []
        for (k, cut) in cuts.enumerated() {
            let a = path[cut.edge], b = path[cut.edge + 1]
            guard let door = gateDoorCells(graph.corridors[cut.corridor], from: a, to: b, graph: graph, grid: grid, width: w)
            else { return nil }
            gateDrafts.append((k + 2, a, b, door.cells, door.orientation))
        }
        BSPLayout.carve(niche.cells, into: &grid)

        // Loop corridors, only inside one zone and never touching gate corridors or the niche.
        var zoneOfRoom = zones(graph: graph, path: path, cutCorridors: Set(cuts.map(\.corridor)))
        var reserved = Set<GridPoint>()
        for c in cuts.map(\.corridor) { for cell in graph.corridors[c].cells { reserved.formUnion(ring8(cell)) } }
        for cell in niche.cells { reserved.formUnion(ring8(cell)) }
        addLoops(p, width: w, rooms: layout.rooms, zoneOfRoom: zoneOfRoom, graph: graph,
                 reserved: reserved, grid: &grid, random: random)

        // Rebuild the graph on the final grid and re-derive zones through the gate corridors.
        graph = LevelGraph.build(grid: grid, rooms: layout.rooms)
        var gateCorridors: [Int] = []
        for g in gateDrafts {
            guard let c = graph.corridorId(at: g.cells[0]) else { return nil }
            gateCorridors.append(c)
        }
        path = graph.shortestPath(from: start, to: exit)
        guard path.count >= p.zones + 1 else { return nil }
        zoneOfRoom = zones(graph: graph, path: path, cutCorridors: Set(gateCorridors))
        guard !zoneOfRoom.contains(0), zoneOfRoom[start] == 1, zoneOfRoom[exit] == p.zones else { return nil }

        let rooms = makeRooms(layout.rooms, graph: graph, path: path, zoneOfRoom: zoneOfRoom)
        let reserve = LevelGraph.doorwayReserve(grid: grid, graph: graph, depth: doorwayReserveDepth)

        // Checkpoints: start pad + one just behind each gate.
        var checkpoints = [CheckpointPlacement(id: "checkpoint_start", cell: rooms[start].rect.centerCell,
                                               roomId: start, zone: 1, gateId: nil)]
        for g in gateDrafts {
            guard let cell = checkpointCell(behind: g.cells, in: layout.rooms[g.to]) else { return nil }
            checkpoints.append(CheckpointPlacement(id: "checkpoint_gate_\(g.zone)", cell: cell, roomId: g.to,
                                                   zone: g.zone, gateId: "gate_\(g.zone)"))
        }

        // Step 5: puzzle elements and machine items.
        guard let puzzle = PuzzlePlacer.place(level, rooms: rooms, startRoom: start, doorwayReserve: reserve,
                                              blocked: Set(checkpoints.map(\.cell)), random: random)
        else { return nil }

        let gates = gateDrafts.map { g in
            GateDoor(id: "gate_\(g.zone)", zone: g.zone, cells: g.cells, orientation: g.orientation,
                     fromRoomId: g.from, toRoomId: g.to,
                     elementIds: puzzle.elements.filter { $0.gateId == "gate_\(g.zone)" }.map(\.id))
        }
        let exitDoor = ExitDoor(cells: niche.door, orientation: niche.orientation, roomId: exit,
                                niche: niche.cells.filter { !niche.door.contains($0) },
                                elementIds: puzzle.elements.filter(\.required).map(\.id))

        // Steps 6–7: enemies, pickups, crates, datachips, weapon pickup.
        guard let spawns = SpawnPlacer.place(level, catalog: catalog, rooms: rooms, path: path, startRoom: start,
                                             checkpoints: checkpoints, doorwayReserve: reserve,
                                             elements: puzzle.elements, items: puzzle.items, random: random)
        else { return nil }

        return GeneratedLevel(
            levelId: level.id, levelIndex: level.index, seedUsed: seed, attempts: attempts, usedFallback: fallback,
            grid: grid, rooms: rooms, corridors: graph.corridors, startRoomId: start, exitRoomId: exit,
            criticalPath: path, gates: gates, exitDoor: exitDoor, elements: puzzle.elements,
            itemPlacements: puzzle.items, enemySpawns: spawns.enemies, pickups: spawns.pickups,
            crates: spawns.crates, checkpoints: checkpoints, exitPad: niche.pad)
    }

    // MARK: Zones

    struct Cut: Sendable, Equatable {
        /// Path edge index (between `path[edge]` and `path[edge + 1]`).
        let edge: Int
        let corridor: Int
    }

    /// Picks `zones − 1` bridge corridors along the critical path. A choice is feasible when every
    /// zone has at least as many non-start rooms as fixed-zone elements (and zone 1 has an off-path
    /// room for the weapon pickup); among those the most even room count per zone wins, then the
    /// most even split of the path.
    static func chooseCuts(_ level: LevelDef, graph: LevelGraph, path: [Int], start: Int) -> [Cut]? {
        let z = level.generator.zones
        guard z > 1 else { return [] }
        var bridges: [Cut] = []
        for i in 0..<(path.count - 1) {
            let a = path[i], b = path[i + 1]
            let links = graph.corridors(between: a, b)
            guard links.count == 1, graph.corridors[links[0]].roomIds == [min(a, b), max(a, b)] else { continue }
            if graph.distances(from: a, excluding: [links[0]])[b] < 0 { bridges.append(Cut(edge: i, corridor: links[0])) }
        }
        guard bridges.count >= z - 1 else { return nil }

        var demand = Array(repeating: 0, count: z + 1)
        for e in level.puzzle.elements { if case .index(let i) = e.zone, i >= 1, i <= z { demand[i] += e.count } }
        for g in level.puzzle.gates where g.zone - 1 >= 1 && g.zone - 1 <= z {
            demand[g.zone - 1] += g.opensWith.reduce(0) { $0 + $1.count }
        }
        let needsZone1OffPath = level.pickups.weaponPickup != nil
        let onPath = Set(path)

        var best: (cuts: [Cut], balance: Int, spread: Int)?
        func evaluate(_ combo: [Cut]) {
            let label = zones(graph: graph, path: path, cutCorridors: Set(combo.map(\.corridor)))
            var rooms = Array(repeating: 0, count: z + 1)
            var free = Array(repeating: 0, count: z + 1)
            var zone1OffPath = false
            for r in graph.rooms.indices {
                rooms[label[r]] += 1
                guard r != start else { continue }
                free[label[r]] += 1
                if label[r] == 1 && !onPath.contains(r) { zone1OffPath = true }
            }
            if needsZone1OffPath && !zone1OffPath { return }
            guard (1...z).allSatisfy({ free[$0] >= demand[$0] }) else { return }
            let counts = rooms[1...z]
            let balance = (counts.max() ?? 0) - (counts.min() ?? 0)
            var segs: [Int] = []
            var prev = 0
            for c in combo { segs.append(c.edge + 1 - prev); prev = c.edge + 1 }
            segs.append(path.count - prev)
            let spread = (segs.max() ?? 0) - (segs.min() ?? 0)
            if best == nil || balance < best!.balance || (balance == best!.balance && spread < best!.spread) {
                best = (combo, balance, spread)
            }
        }
        if z == 2 {
            for b in bridges { evaluate([b]) }
        } else {
            // Up to 3 zones in S1 (GDD §14.2); larger counts use greedy even spacing.
            if z == 3 {
                for i in bridges.indices { for j in bridges.indices where j > i { evaluate([bridges[i], bridges[j]]) } }
            } else {
                let step = Double(bridges.count) / Double(z)
                evaluate((1..<z).map { bridges[min(bridges.count - 1, Int(Double($0) * step))] })
            }
        }
        return best?.cuts
    }

    /// Zone per room (1-based; 0 = not assigned) from the components left after removing the
    /// gate corridors, numbered in critical-path order.
    static func zones(graph: LevelGraph, path: [Int], cutCorridors: Set<Int>) -> [Int] {
        let comp = graph.components(excluding: cutCorridors)
        var zoneOfComp: [Int: Int] = [:]
        var z = 0
        for r in path where zoneOfComp[comp[r]] == nil {
            z += 1
            zoneOfComp[comp[r]] = z
        }
        return graph.rooms.indices.map { zoneOfComp[comp[$0]] ?? 0 }
    }

    static func makeRooms(_ rects: [RoomRect], graph: LevelGraph, path: [Int], zoneOfRoom: [Int]) -> [LevelRoom] {
        // Attach index: index of the nearest path room (multi-source BFS, lower index wins ties).
        var attach = Array(repeating: -1, count: rects.count)
        var queue: [Int] = []
        for (i, r) in path.enumerated() { attach[r] = i; queue.append(r) }
        var head = 0
        while head < queue.count {
            let r = queue[head]; head += 1
            for l in graph.adjacency[r] where attach[l.room] < 0 {
                attach[l.room] = attach[r]
                queue.append(l.room)
            }
        }
        let onPath = Set(path)
        return rects.indices.map { i in
            LevelRoom(id: i, rect: rects[i], zone: zoneOfRoom[i], isOnPath: onPath.contains(i),
                      pathIndex: max(0, attach[i]), isDeadEnd: graph.degree(i) == 1)
        }
    }

    // MARK: Doors

    /// A line of `width` cells across the gate corridor that separates `from` and `to` when
    /// closed. Scans BFS layers from the `from` mouth, preferring the one nearest `to`.
    static func gateDoorCells(_ corridor: Corridor, from a: Int, to b: Int, graph: LevelGraph, grid: TileGrid,
                              width w: Int) -> (cells: [GridPoint], orientation: DoorOrientation)? {
        let inCorridor = Set(corridor.cells)
        var dist: [GridPoint: Int] = [:]
        var queue: [GridPoint] = []
        for c in corridor.cells where c.neighbors4.contains(where: { graph.roomId(at: $0) == a }) {
            dist[c] = 0
            queue.append(c)
        }
        var head = 0
        while head < queue.count {
            let c = queue[head]; head += 1
            for n in c.neighbors4 where inCorridor.contains(n) && dist[n] == nil {
                dist[n] = dist[c]! + 1
                queue.append(n)
            }
        }
        let maxD = dist.values.max() ?? -1
        guard maxD >= 0 else { return nil }
        var layers = Array(repeating: [GridPoint](), count: maxD + 1)
        for (c, d) in dist { layers[d].append(c) }
        let aCell = graph.rooms[a].centerCell, bCell = graph.rooms[b].centerCell
        for d in stride(from: maxD, through: 0, by: -1) {
            let layer = layers[d].sorted()
            guard layer.count == w else { continue }
            let orientation: DoorOrientation
            if Set(layer.map(\.y)).count == 1, layer.last!.x - layer.first!.x == w - 1 {
                // Horizontal line of cells → blocks north–south travel.
                let y = layer[0].y
                guard !grid.isWalkable(GridPoint(layer.first!.x - 1, y)), !grid.isWalkable(GridPoint(layer.last!.x + 1, y))
                else { continue }
                orientation = .northSouth
            } else if Set(layer.map(\.x)).count == 1, layer.last!.y - layer.first!.y == w - 1 {
                let x = layer[0].x
                guard !grid.isWalkable(GridPoint(x, layer.first!.y - 1)), !grid.isWalkable(GridPoint(x, layer.last!.y + 1))
                else { continue }
                orientation = .eastWest
            } else {
                continue
            }
            let reach = grid.floodFill(from: [aCell], blocked: Set(layer))
            if !reach[grid.index(bCell)] { return (layer, orientation) }
        }
        return nil
    }

    struct Niche: Sendable {
        /// All niche cells including the door row.
        let cells: [GridPoint]
        let door: [GridPoint]
        let pad: GridPoint
        let orientation: DoorOrientation
    }

    /// A `width × exitNicheDepth` dead-end pocket off one wall of `room`, surrounded by solid wall.
    static func findNiche(_ room: RoomRect, grid: TileGrid, width w: Int, random: LevelRandom) -> Niche? {
        let d = exitNicheDepth
        var options: [Niche] = []
        func make(_ cellAt: (Int, Int) -> GridPoint, orientation: DoorOrientation) {
            // cellAt(i, k): i = 0..<w across, k = 1...d outward (k = 1 is the door row).
            var cells: [GridPoint] = []
            var door: [GridPoint] = []
            for k in 1...d { for i in 0..<w { let c = cellAt(i, k); cells.append(c); if k == 1 { door.append(c) } } }
            // Everything in the niche and around it (outside the room) must be solid and inside the map.
            for k in 1...(d + 1) {
                for i in -1...w {
                    let c = cellAt(i, k)
                    if c.x < 1 || c.y < 1 || c.x >= grid.width - 1 || c.y >= grid.height - 1 { return }
                    if grid.isWalkable(c) { return }
                }
            }
            options.append(Niche(cells: cells, door: door, pad: cellAt((w - 1) / 2, d), orientation: orientation))
        }
        guard room.width - 2 >= w, room.height - 2 >= w else { return nil }
        for x0 in (room.x + 1)...(room.maxX - 1 - w) {
            make({ GridPoint(x0 + $0, room.y - $1) }, orientation: .northSouth)          // bottom wall
            make({ GridPoint(x0 + $0, room.maxY - 1 + $1) }, orientation: .northSouth)   // top wall
        }
        for y0 in (room.y + 1)...(room.maxY - 1 - w) {
            make({ GridPoint(room.x - $1, y0 + $0) }, orientation: .eastWest)            // left wall
            make({ GridPoint(room.maxX - 1 + $1, y0 + $0) }, orientation: .eastWest)     // right wall
        }
        return random.pick(options)
    }

    /// Room cell about two tiles in from the middle of a gate door.
    static func checkpointCell(behind door: [GridPoint], in room: RoomRect) -> GridPoint? {
        let mid = door[door.count / 2]
        return room.cells.filter { room.ring($0) >= 1 && $0.distance(mid) >= 2 }
            .min { a, b in
                let da = a.distance(mid), db = b.distance(mid)
                return da != db ? da < db : a < b
            }
    }

    // MARK: Loops

    static func addLoops(_ p: GeneratorParams, width w: Int, rooms: [RoomRect], zoneOfRoom: [Int],
                         graph: LevelGraph, reserved: Set<GridPoint>, grid: inout TileGrid, random: LevelRandom) {
        guard p.loopChance > 0 else { return }
        var cellZone: [Int: Int] = [:]   // corridor id → zone
        for c in graph.corridors { if let r = c.roomIds.first { cellZone[c.id] = zoneOfRoom[r] } }
        for (a, b) in BSPLayout.loopCandidates(rooms, width: w, maxGap: p.maxRoomSize) {
            guard random.chance(p.loopChance) else { continue }
            guard zoneOfRoom[a] == zoneOfRoom[b], graph.corridors(between: a, b).isEmpty,
                  let cells = BSPLayout.straightCorridor(rooms[a], rooms[b], width: w, random: random) else { continue }
            let zone = zoneOfRoom[a]
            var ok = true
            check: for c in cells where !rooms[a].contains(c) && !rooms[b].contains(c) {
                for n in ring8(c) {
                    if reserved.contains(n) { ok = false; break check }
                    guard grid.isWalkable(n) else { continue }
                    if let r = graph.roomId(at: n) {
                        if r != a && r != b { ok = false; break check }
                    } else if let cid = graph.corridorId(at: n) {
                        if cellZone[cid] != zone { ok = false; break check }
                    } else {
                        ok = false; break check   // floor carved by an earlier loop in this pass
                    }
                }
            }
            if ok { BSPLayout.carve(cells, into: &grid) }
        }
    }

    /// The cell and its 8 neighbours.
    static func ring8(_ c: GridPoint) -> [GridPoint] {
        var out: [GridPoint] = []
        for dy in -1...1 { for dx in -1...1 { out.append(GridPoint(c.x + dx, c.y + dy)) } }
        return out
    }

    private static func emptyLevel(_ level: LevelDef) -> GeneratedLevel {
        var grid = TileGrid(width: 12, height: 10)
        let room = RoomRect(x: 1, y: 1, width: 10, height: 8)
        BSPLayout.carveRooms([room], into: &grid)
        let start = CheckpointPlacement(id: "checkpoint_start", cell: room.centerCell, roomId: 0, zone: 1, gateId: nil)
        return GeneratedLevel(
            levelId: level.id, levelIndex: level.index, seedUsed: level.fallbackSeed, attempts: 0, usedFallback: true,
            grid: grid, rooms: [LevelRoom(id: 0, rect: room, zone: 1, isOnPath: true, pathIndex: 0, isDeadEnd: false)],
            corridors: [], startRoomId: 0, exitRoomId: 0, criticalPath: [0], gates: [],
            exitDoor: ExitDoor(cells: [], orientation: .eastWest, roomId: 0, niche: [], elementIds: []),
            elements: [], itemPlacements: [], enemySpawns: [], pickups: [], crates: [], checkpoints: [start],
            exitPad: GridPoint(room.maxX - 2, room.centerCell.y))
    }
}


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

    /// Centre in tile units (continuous), used for spacing.
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

    /// Exit pad centre in world points (the middle of the niche's far row).
    var exitPadPosition: CGPoint { grid.world(exitPad) }

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
