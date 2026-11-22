import Foundation

/// GDD §14.3 validation. `problems` is empty when the level is valid. The lock-and-key part
/// simulates play: flood fill from the start with all doors closed, collect reachable items,
/// switch on reachable elements (machines consume an item), open satisfied gates, repeat.
nonisolated enum SolvabilityChecker {
    static func isValid(_ l: GeneratedLevel, def: LevelDef, catalog: GeneratorCatalog) -> Bool {
        problems(l, def: def, catalog: catalog).isEmpty
    }

    static func problems(_ l: GeneratedLevel, def: LevelDef, catalog: GeneratorCatalog) -> [String] {
        var out: [String] = []
        let p = def.generator
        let grid = l.grid
        let rects = l.rooms.map(\.rect)
        let graph = LevelGraph.build(grid: grid, rooms: rects)

        // Rooms and connectivity.
        if !p.roomCount.contains(l.rooms.count) { out.append("room count \(l.rooms.count) not in \(p.roomCount)") }
        for r in l.rooms where !(p.minRoomSize...p.maxRoomSize).contains(r.rect.width)
            || !(p.minRoomSize...p.maxRoomSize).contains(r.rect.height) {
            out.append("room \(r.id) size \(r.rect.width)×\(r.rect.height) out of range")
        }
        if l.startRoomId == l.exitRoomId { out.append("start == exit") }
        if l.criticalPath.count < p.zones + 1 { out.append("critical path \(l.criticalPath.count) < zones + 1") }
        if l.criticalPath.first != l.startRoomId || l.criticalPath.last != l.exitRoomId { out.append("critical path ends wrong") }
        let allOpen = grid.floodFill(from: [l.heroStart])
        if allOpen.enumerated().contains(where: { grid.tiles[$0.offset] == .floor && !$0.element }) {
            out.append("floor not fully connected with all doors open")
        }
        if Set(l.rooms.map(\.zone)) != Set(1...max(1, p.zones)) { out.append("zones \(Set(l.rooms.map(\.zone)).sorted()) ≠ 1…\(p.zones)") }
        if l.rooms[l.startRoomId].zone != 1 { out.append("start not in zone 1") }

        // Doors.
        if l.gates.count != p.zones - 1 { out.append("gate count \(l.gates.count) ≠ zones − 1") }
        let w = p.corridorWidth
        for g in l.gates {
            if g.cells.count != w { out.append("\(g.id) has \(g.cells.count) cells") }
            if g.cells.contains(where: { graph.roomId(at: $0) != nil || !grid.isWalkable($0) }) { out.append("\(g.id) not on a corridor") }
            if l.rooms[g.toRoomId].zone != g.zone || l.rooms[g.fromRoomId].zone != g.zone - 1 { out.append("\(g.id) not between zone \(g.zone - 1) and \(g.zone)") }
            if g.elementIds.isEmpty { out.append("\(g.id) has no elements") }
        }
        if l.exitDoor.cells.count != w { out.append("exit door has \(l.exitDoor.cells.count) cells") }
        if l.exitDoor.roomId != l.exitRoomId { out.append("exit door not at the exit room") }
        if !l.exitDoor.niche.contains(l.exitPad) { out.append("exit pad not behind the exit door") }

        // Zone separation: with gates ≥ z closed, no cell of a room in zone ≥ z is reachable.
        let exitCells = Set(l.exitDoor.cells)
        for z in 2...max(2, p.zones) where p.zones >= 2 {
            let closed = Set(l.gates.filter { $0.zone >= z }.flatMap(\.cells)).union(exitCells)
            let reach = grid.floodFill(from: [l.heroStart], blocked: closed)
            if l.rooms.contains(where: { $0.zone >= z && reach[grid.index($0.rect.centerCell)] }) {
                out.append("zone \(z) reachable without its gate")
            }
        }
        // The exit pad is only reachable through the exit door.
        let reachNoExit = grid.floodFill(from: [l.heroStart], blocked: exitCells)
        if reachNoExit[grid.index(l.exitPad)] { out.append("exit pad reachable with the exit door closed") }

        // Elements.
        let reserve = LevelGraph.doorwayReserve(grid: grid, graph: graph, depth: LevelGenerator.doorwayReserveDepth)
        let required = l.elements.filter(\.required)
        let expectedRequired = def.puzzle.elements.filter(\.required).reduce(0) { $0 + $1.count }
        if required.count != expectedRequired { out.append("required elements \(required.count) ≠ \(expectedRequired)") }
        if Set(l.exitDoor.elementIds) != Set(required.map(\.id)) { out.append("exit door elements ≠ required elements") }
        for e in l.elements {
            for c in e.cells {
                guard let rid = graph.roomId(at: c), rid == e.roomId else { out.append("\(e.id) not inside its room"); break }
                if reserve.contains(c) { out.append("\(e.id) blocks a doorway"); break }
            }
            if e.roomId == l.startRoomId { out.append("\(e.id) in the start room") }
            if l.rooms[e.roomId].zone != e.zone { out.append("\(e.id) zone mismatch") }
            if let gid = e.gateId {
                guard let g = l.gates.first(where: { $0.id == gid }) else { out.append("\(e.id) gate \(gid) missing"); continue }
                if e.zone != g.zone - 1 { out.append("\(e.id) not in zone \(g.zone - 1)") }
                if !g.elementIds.contains(e.id) { out.append("\(e.id) not listed on \(gid)") }
            }
        }
        for (i, a) in l.elements.enumerated() {
            for b in l.elements[(i + 1)...] where hypot(a.center.x - b.center.x, a.center.y - b.center.y) < Double(p.minElementSpacing) {
                out.append("\(a.id)–\(b.id) closer than \(p.minElementSpacing)")
            }
        }

        // Machine items: never behind the gate they open, never in a later zone than the machine.
        for m in l.elements where m.type == .machine {
            let its = l.itemPlacements.filter { $0.elementId == m.id }
            guard its.count == 1, let item = its.first else { out.append("\(m.id) has \(its.count) items"); continue }
            if item.itemId != m.requiresItem { out.append("\(item.id) is not \(m.requiresItem ?? "?")") }
            if item.zone > m.zone { out.append("\(item.id) in a later zone than \(m.id)") }
            if let gid = m.gateId, let g = l.gates.first(where: { $0.id == gid }), item.zone >= g.zone {
                out.append("\(item.id) behind \(gid)")
            }
            switch m.itemPlacement ?? def.puzzle.itemPlacement {
            case .sameZone where item.zone != m.zone || item.roomId == m.roomId:
                out.append("\(item.id) not sameZone")
            case .earlierZone where m.zone > 1 && item.zone >= m.zone:
                out.append("\(item.id) not earlierZone")
            default: break
            }
            if reserve.contains(item.cell) { out.append("\(item.id) blocks a doorway") }
        }

        // Enemies.
        let keepAway = l.elements.flatMap(\.cells) + l.itemPlacements.map(\.cell)
        let checkpointRooms = Set(l.checkpoints.map(\.roomId))
        var threat: [Int: Int] = [:]
        var perRoomType: [String: Int] = [:]
        for e in l.enemySpawns {
            if !grid.isWalkable(e.cell) || graph.roomId(at: e.cell) != e.roomId { out.append("\(e.id) not in its room") }
            if e.roomId == l.startRoomId || checkpointRooms.contains(e.roomId) { out.append("\(e.id) in a start/checkpoint room") }
            if keepAway.contains(where: { $0.distance(e.cell) <= SpawnPlacer.enemyClearance }) {
                out.append("\(e.id) within \(SpawnPlacer.enemyClearance) tiles of an element or item")
            }
            threat[e.roomId, default: 0] += catalog.threatCost[e.enemyId] ?? 0
            perRoomType["\(e.roomId):\(e.enemyId)", default: 0] += 1
            if let m = def.enemyMix.first(where: { $0.enemyId == e.enemyId }), let zmin = m.zoneMin, l.rooms[e.roomId].zone < zmin,
               e.enemyId != def.firstEncounterRoom {
                out.append("\(e.id) before zoneMin")
            }
        }
        for (room, t) in threat where t > p.maxThreatPerRoom { out.append("room \(room) threat \(t) > \(p.maxThreatPerRoom)") }
        for m in def.enemyMix {
            guard let cap = m.maxPerRoom else { continue }
            for r in l.rooms where perRoomType["\(r.id):\(m.enemyId)", default: 0] > cap { out.append("room \(r.id) has > \(cap) \(m.enemyId)") }
        }

        // Datachips and the weapon pickup.
        let chips = l.pickups.filter { $0.kind == .datachip }
        if chips.count != def.pickups.datachips { out.append("datachips \(chips.count) ≠ \(def.pickups.datachips)") }
        if def.pickups.datachips > 0, !chips.contains(where: { !l.rooms[$0.roomId].isOnPath }) { out.append("no datachip off the path") }
        if let wid = def.pickups.weaponPickup {
            let ws = l.pickups.filter { $0.kind == .weapon }
            if ws.count != 1 || ws[0].itemId != wid { out.append("weapon pickup missing") }
            else if l.rooms[ws[0].roomId].zone != 1 || l.rooms[ws[0].roomId].isOnPath { out.append("weapon pickup not in zone 1 off the path") }
        }
        for c in l.crates where reserve.contains(c.cell) { out.append("\(c.id) blocks a doorway") }
        if !l.checkpoints.isEmpty, l.checkpoints[0].roomId != l.startRoomId { out.append("first checkpoint not in the start room") }
        if l.checkpoints.count != l.gates.count + 1 { out.append("checkpoints \(l.checkpoints.count) ≠ gates + 1") }

        // Lock and key.
        out += lockAndKey(l)
        return out
    }

    /// GDD §14.3 simulation. Empty when the exit door opens and the exit pad is then reachable.
    static func lockAndKey(_ l: GeneratedLevel) -> [String] {
        let grid = l.grid
        var openGates = Set<String>()
        var on = Set<String>()
        var collected = Set<String>()
        var bag: [String: Int] = [:]
        var exitOpen = false
        while true {
            var closed = Set(l.gates.filter { !openGates.contains($0.id) }.flatMap(\.cells))
            if !exitOpen { closed.formUnion(l.exitDoor.cells) }
            let reach = grid.floodFill(from: [l.heroStart], blocked: closed)
            var changed = false
            for i in l.itemPlacements where !collected.contains(i.id) && reach[grid.index(i.cell)] {
                collected.insert(i.id)
                bag[i.itemId, default: 0] += 1
                changed = true
            }
            for e in l.elements where !on.contains(e.id) && e.cells.contains(where: { reach[grid.index($0)] || adjacentReach($0, reach, grid) }) {
                if let item = e.requiresItem {
                    guard bag[item, default: 0] > 0 else { continue }
                    bag[item]! -= 1
                }
                on.insert(e.id)
                changed = true
            }
            for g in l.gates where !openGates.contains(g.id) && g.elementIds.allSatisfy(on.contains) {
                openGates.insert(g.id)
                changed = true
            }
            if !exitOpen, l.exitDoor.elementIds.allSatisfy(on.contains) {
                exitOpen = true
                changed = true
            }
            if !changed {
                guard exitOpen else {
                    return ["lock-and-key: stuck (on \(on.count)/\(l.elements.count), gates \(openGates.sorted()))"]
                }
                return reach[grid.index(l.exitPad)] ? [] : ["lock-and-key: exit pad unreachable"]
            }
        }
    }

    private static func adjacentReach(_ c: GridPoint, _ reach: [Bool], _ grid: TileGrid) -> Bool {
        c.neighbors4.contains { grid.contains($0) && reach[grid.index($0)] }
    }
}
