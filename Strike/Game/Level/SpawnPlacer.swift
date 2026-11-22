import Foundation

/// GDD §14.1 steps 6–7: enemies by threat budget, floor pickups, crates, datachips and the
/// weapon pickup. Checkpoint pads and the exit pad are placed by `LevelGenerator`.
nonisolated enum SpawnPlacer {
    struct Result: Sendable {
        let enemies: [EnemySpawn]
        let pickups: [PickupPlacement]
        let crates: [CratePlacement]
    }

    /// GDD §14.3: no element or item within this many tiles of an enemy spawn (Euclidean, centres).
    static let enemyClearance = 3.0
    /// GDD §14.1 step 6: room area per threat point before `enemyDensity`.
    static let areaPerThreat = 40.0

    /// Threat points of a room (GDD §14.1 step 6), before the start/checkpoint exemption.
    static func threat(area: Int, params: GeneratorParams) -> Int {
        let t = Int((Double(area) / areaPerThreat * params.enemyDensity).rounded())
        return min(max(1, t), max(0, params.maxThreatPerRoom))
    }

    static func place(_ level: LevelDef, catalog: GeneratorCatalog, rooms: [LevelRoom], path: [Int], startRoom: Int,
                      checkpoints: [CheckpointPlacement], doorwayReserve: Set<GridPoint>,
                      elements: [PlacedElement], items: [ItemPlacement], random: LevelRandom) -> Result? {
        let p = level.generator
        let checkpointRooms = Set(checkpoints.map(\.roomId))
        let elementCells = elements.flatMap(\.cells)
        var occupied = Set(elementCells)
        occupied.formUnion(items.map(\.cell))
        occupied.formUnion(checkpoints.map(\.cell))

        func free(_ room: LevelRoom, minRing: Int = 1) -> [GridPoint] {
            room.rect.cells.filter { room.rect.ring($0) >= minRing && !doorwayReserve.contains($0) && !occupied.contains($0) }
        }
        let nonStart = rooms.filter { $0.id != startRoom }

        // Weapon pickup: zone 1, off the path ("treasure room"), dead ends first.
        var pickups: [PickupPlacement] = []
        var weaponRoom: LevelRoom?
        if let weapon = level.pickups.weaponPickup {
            let cands = random.shuffled(nonStart.filter { $0.zone == 1 && !$0.isOnPath })
                .enumerated().sorted { a, b in
                    a.element.isDeadEnd != b.element.isDeadEnd ? a.element.isDeadEnd : a.offset < b.offset
                }.map(\.element)
            for room in cands {
                guard let cell = random.pick(free(room)) else { continue }
                pickups.append(PickupPlacement(id: "weapon_0", itemId: weapon, count: 1, cell: cell, roomId: room.id, kind: .weapon))
                occupied.insert(cell)
                weaponRoom = room
                break
            }
            guard weaponRoom != nil else { return nil }
        }

        // Datachips: off-path rooms first (dead ends first), then the rest; ≥ 1 off the path.
        if level.pickups.datachips > 0 {
            let off = random.shuffled(nonStart.filter { !$0.isOnPath }).enumerated().sorted { a, b in
                a.element.isDeadEnd != b.element.isDeadEnd ? a.element.isDeadEnd : a.offset < b.offset
            }.map(\.element)
            let on = random.shuffled(nonStart.filter(\.isOnPath))
            var order = off + on
            if order.isEmpty { return nil }
            while order.count < level.pickups.datachips { order += off + on }
            var placedOff = false
            var n = 0
            for room in order where n < level.pickups.datachips {
                guard let cell = random.pick(free(room)) else { continue }
                pickups.append(PickupPlacement(id: "datachip_\(n)", itemId: LevelGenerator.datachipItemId, count: 1,
                                               cell: cell, roomId: room.id, kind: .datachip))
                occupied.insert(cell)
                if !room.isOnPath { placedOff = true }
                n += 1
            }
            guard n == level.pickups.datachips, placedOff else { return nil }
        }

        // Crates: against a wall (outer ring), one per room, outside the doorway reserve.
        var crates: [CratePlacement] = []
        let crateCount = random.int(level.pickups.crates.min, level.pickups.crates.max)
        for room in random.shuffled(nonStart) where crates.count < crateCount {
            let cells = room.rect.cells.filter { c in
                room.rect.ring(c) == 0 && !doorwayReserve.contains(c) && !occupied.contains(c)
                    && elementCells.allSatisfy { $0.chebyshev(c) > 1 }
            }
            guard let cell = random.pick(cells) else { continue }
            crates.append(CratePlacement(id: "crate_\(crates.count)", cell: cell, roomId: room.id,
                                         lootTableId: level.pickups.crates.lootTableId))
            occupied.insert(cell)
        }

        // Enemies.
        let keepAway = elementCells + items.map(\.cell)
        let pathLen = max(1, path.count - 1)
        var enemies: [EnemySpawn] = []
        func enemyCell(_ room: LevelRoom) -> GridPoint? {
            let cells = free(room).filter { c in
                keepAway.allSatisfy { $0.distance(c) > enemyClearance }
                    && enemies.allSatisfy { $0.cell.chebyshev(c) >= 2 }
            }
            return random.pick(cells)
        }
        func spawn(_ enemyId: String, in room: LevelRoom) -> Bool {
            guard let cell = enemyCell(room) else { return false }
            enemies.append(EnemySpawn(id: "enemy_\(enemies.count)", enemyId: enemyId, cell: cell, roomId: room.id))
            occupied.insert(cell)
            return true
        }
        var firstRoom: Int?
        if let first = level.firstEncounterRoom, path.count > 1 {
            let room = rooms[path[1]]
            if room.id != startRoom, !checkpointRooms.contains(room.id), spawn(first, in: room) { firstRoom = room.id }
        }
        for room in rooms where room.id != startRoom && !checkpointRooms.contains(room.id) && room.id != firstRoom {
            var budget = threat(area: room.rect.area, params: p)
            var perEntry: [String: Int] = [:]
            let fraction = Double(room.pathIndex) / Double(pathLen)
            while budget > 0 {
                let options = level.enemyMix.filter { m in
                    let cost = catalog.threatCost[m.enemyId] ?? 0
                    return cost > 0 && cost <= budget && m.weight > 0
                        && room.zone >= (m.zoneMin ?? 1)
                        && fraction >= (m.minPathFraction ?? 0)
                        && perEntry[m.enemyId, default: 0] < (m.maxPerRoom ?? Int.max)
                }
                guard let i = random.weightedIndex(options.map(\.weight)) else { break }
                let m = options[i]
                let cost = catalog.threatCost[m.enemyId] ?? 1
                budget -= cost
                // A turret needs ≥ 2 tiles from walls; `free(minRing: 1)` already keeps 2 from walls
                // and the doorway reserve keeps it ≥ 3 from doorways.
                if spawn(m.enemyId, in: room) { perEntry[m.enemyId, default: 0] += 1 }
            }
        }

        // Floor pickups: per non-start room by chance. Ammo for a blaster that is neither owned
        // nor picked up earlier on the path is skipped.
        for room in nonStart {
            for entry in level.pickups.perRoom where random.chance(entry.chance) {
                if catalog.itemCategory[entry.itemId] == .ammo, let weapon = catalog.weaponForAmmo[entry.itemId],
                   !catalog.ownsWeapon(weapon, atLevel: level.index) {
                    guard weapon == level.pickups.weaponPickup, let wr = weaponRoom, room.pathIndex > wr.pathIndex else { continue }
                }
                guard let cell = random.pick(free(room)) else { continue }
                pickups.append(PickupPlacement(id: "pickup_\(pickups.count)", itemId: entry.itemId, count: 1,
                                               cell: cell, roomId: room.id, kind: .floor))
                occupied.insert(cell)
            }
        }
        return Result(enemies: enemies, pickups: pickups, crates: crates)
    }
}
