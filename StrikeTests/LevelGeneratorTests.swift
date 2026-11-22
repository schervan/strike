import Foundation
import Testing
@testable import Strike

/// Generated levels shared by the generator tests (computed once, thread-safe static init).
enum GeneratedCorpus {
    static let seeds: [UInt64] = Array(0..<200)
    static let data: GameData = try! TestData.load()
    static let catalog = GeneratorCatalog(data: data)
    /// Level id → levels for `seeds`.
    static let levels: [String: [GeneratedLevel]] = {
        var out: [String: [GeneratedLevel]] = [:]
        for l in data.levelOrder { out[l.id] = seeds.map { LevelGenerator.generate(l, seed: $0, catalog: catalog) } }
        return out
    }()

    static func def(_ id: String) -> LevelDef { data.levels[id]! }
}

struct LevelGeneratorTests {
    static let levelIds = ["l1", "l2", "l3", "l4", "l5"]

    @Test func sameSeedGivesIdenticalLevel() throws {
        let c = GeneratedCorpus.catalog
        for id in Self.levelIds {
            let def = GeneratedCorpus.def(id)
            let a = LevelGenerator.generate(def, seed: 42, catalog: c)
            let b = LevelGenerator.generate(def, seed: 42, catalog: c)
            #expect(a == b, "\(id)")
            #expect(a.stableHash == b.stableHash, "\(id)")
            let other = LevelGenerator.generate(def, seed: 43, catalog: c)
            #expect(other.stableHash != a.stableHash || other.seedUsed == a.seedUsed, "\(id)")
        }
    }

    @Test(arguments: levelIds)
    func seeds0to199AllValidate(_ id: String) {
        let def = GeneratedCorpus.def(id)
        let levels = GeneratedCorpus.levels[id]!
        var fallbacks = 0
        var attempts = 0
        for l in levels {
            let problems = SolvabilityChecker.problems(l, def: def, catalog: GeneratedCorpus.catalog)
            #expect(problems.isEmpty, "\(id) seed \(l.seedUsed): \(problems)")
            if l.usedFallback { fallbacks += 1 }
            attempts += l.attempts
        }
        print("[generator] \(id): \(levels.count) seeds, fallback \(fallbacks), mean attempts \(Double(attempts) / Double(levels.count))")
        #expect(Double(fallbacks) <= Double(levels.count) * 0.05, "\(id): \(fallbacks) fallbacks")
    }

    @Test(arguments: levelIds)
    func roomsAndConnectivity(_ id: String) {
        let def = GeneratedCorpus.def(id)
        let p = def.generator
        for l in GeneratedCorpus.levels[id]! {
            #expect(p.roomCount.contains(l.rooms.count), "\(id) \(l.seedUsed)")
            for r in l.rooms {
                #expect((p.minRoomSize...p.maxRoomSize).contains(r.rect.width))
                #expect((p.minRoomSize...p.maxRoomSize).contains(r.rect.height))
            }
            #expect(l.startRoomId != l.exitRoomId)
            #expect(l.criticalPath.count >= p.zones + 1)
            #expect(l.criticalPath.first == l.startRoomId && l.criticalPath.last == l.exitRoomId)
            // Every floor cell reachable with all doors open.
            let reach = l.grid.floodFill(from: [l.heroStart])
            #expect(zip(l.grid.tiles, reach).allSatisfy { $0 != .floor || $1 }, "\(id) \(l.seedUsed)")
            // Map edge stays solid.
            for x in 0..<l.grid.width { #expect(l.grid[x, 0] == .wall && l.grid[x, l.grid.height - 1] == .wall) }
            #expect(l.grid.isWalkable(l.heroStart))
            #expect(l.room(at: l.heroStart)?.id == l.startRoomId)
        }
    }

    @Test(arguments: levelIds)
    func gatesSitWhereTheirZoneBegins(_ id: String) {
        let def = GeneratedCorpus.def(id)
        for l in GeneratedCorpus.levels[id]! {
            #expect(l.gates.count == def.generator.zones - 1)
            for g in l.gates {
                // On corridor cells, between the last room of zone − 1 and the first of zone.
                #expect(g.cells.allSatisfy { l.room(at: $0) == nil && l.grid.isWalkable($0) })
                #expect(g.cells.count == def.generator.corridorWidth)
                #expect(l.rooms[g.fromRoomId].zone == g.zone - 1 && l.rooms[g.toRoomId].zone == g.zone)
                let i = try! #require(l.criticalPath.firstIndex(of: g.fromRoomId))
                #expect(l.criticalPath[i + 1] == g.toRoomId)
                // Closed, it cuts every room of its zone (and later) off from the start.
                let closed = l.gates.filter { $0.zone >= g.zone }.flatMap(\.cells) + l.exitDoor.cells
                let reach = l.grid.floodFill(from: [l.heroStart], blocked: Set(closed))
                for r in l.rooms { #expect(reach[l.grid.index(r.rect.centerCell)] == (r.zone < g.zone)) }
                // Gate elements are in zone − 1.
                for eid in g.elementIds { #expect(l.element(eid)?.zone == g.zone - 1) }
            }
            // Machine items are never behind the gate they open, never later than their machine.
            for m in l.elements where m.type == .machine {
                let item = try! #require(l.itemPlacements.first { $0.elementId == m.id })
                #expect(item.itemId == m.requiresItem)
                #expect(item.zone <= m.zone)
                if let gid = m.gateId, let g = l.gates.first(where: { $0.id == gid }) { #expect(item.zone < g.zone) }
            }
        }
    }

    @Test(arguments: levelIds)
    func spacingDoorwaysAndEnemyClearance(_ id: String) {
        let def = GeneratedCorpus.def(id)
        for l in GeneratedCorpus.levels[id]! {
            let graph = LevelGraph.build(grid: l.grid, rooms: l.rooms.map(\.rect))
            let reserve = LevelGraph.doorwayReserve(grid: l.grid, graph: graph, depth: 1)
            for (i, a) in l.elements.enumerated() {
                for b in l.elements[(i + 1)...] {
                    #expect(hypot(a.center.x - b.center.x, a.center.y - b.center.y) >= Double(def.generator.minElementSpacing))
                }
                // Not in corridors, not next to a corridor mouth, not in the start room.
                #expect(a.cells.allSatisfy { l.room(at: $0)?.id == a.roomId && !reserve.contains($0) })
                #expect(a.roomId != l.startRoomId)
            }
            for c in l.crates { #expect(!reserve.contains(c.cell)) }
            let keep = l.elements.flatMap(\.cells) + l.itemPlacements.map(\.cell)
            let noEnemyRooms = Set(l.checkpoints.map(\.roomId)).union([l.startRoomId])
            for e in l.enemySpawns {
                #expect(keep.allSatisfy { $0.distance(e.cell) > 3 }, "\(id) \(l.seedUsed) \(e.id)")
                #expect(!noEnemyRooms.contains(e.roomId))
                #expect(l.room(at: e.cell)?.id == e.roomId)
            }
            #expect(!l.enemySpawns.isEmpty)
        }
    }

    @Test(arguments: levelIds)
    func datachipsAndWeaponPickup(_ id: String) {
        let def = GeneratedCorpus.def(id)
        for l in GeneratedCorpus.levels[id]! {
            let chips = l.pickups.filter { $0.kind == .datachip }
            #expect(chips.count == 3)
            #expect(chips.contains { !l.rooms[$0.roomId].isOnPath })
            #expect(Set(chips.map(\.cell)).count == 3)
            let weapons = l.pickups.filter { $0.kind == .weapon }
            if let w = def.pickups.weaponPickup {
                #expect(weapons.count == 1)
                #expect(weapons.first?.itemId == w)
                if let r = weapons.first.map({ l.rooms[$0.roomId] }) { #expect(r.zone == 1 && !r.isOnPath) }
            } else {
                #expect(weapons.isEmpty)
            }
        }
    }

    @Test func firstEncounterRoomHoldsOneEnemy() {
        for id in ["l1", "l3"] {
            let def = GeneratedCorpus.def(id)
            for l in GeneratedCorpus.levels[id]!.prefix(50) {
                let room = l.criticalPath[1]
                let inRoom = l.enemySpawns.filter { $0.roomId == room }
                if !l.checkpoints.contains(where: { $0.roomId == room }) {
                    #expect(inRoom.map(\.enemyId) == [def.firstEncounterRoom!], "\(id) \(l.seedUsed)")
                }
            }
        }
    }

    @Test func noUnownedAmmoBeforeTheWeaponPickup() {
        let l2 = GeneratedCorpus.def("l2")
        for l in GeneratedCorpus.levels["l2"]!.prefix(50) {
            let weaponRoom = l.rooms[l.pickups.first { $0.kind == .weapon }!.roomId]
            for p in l.pickups where p.itemId == "ammo_spread" {
                #expect(l.rooms[p.roomId].pathIndex > weaponRoom.pathIndex)
            }
            #expect(l2.pickups.weaponPickup == "blaster_spread")
        }
        // L1: only starter ammo.
        for l in GeneratedCorpus.levels["l1"]!.prefix(50) {
            #expect(l.pickups.allSatisfy { $0.itemId != "ammo_spread" && $0.itemId != "ammo_rapid" })
        }
    }

    @Test func l4GeneratesUnder150ms() {
        let def = GeneratedCorpus.def("l4")
        let c = GeneratedCorpus.catalog
        _ = LevelGenerator.generate(def, seed: 999, catalog: c) // warm-up
        var times: [Double] = []
        for seed in UInt64(1000)..<1020 {
            let t0 = DispatchTime.now().uptimeNanoseconds
            _ = LevelGenerator.generate(def, seed: seed, catalog: c)
            times.append(Double(DispatchTime.now().uptimeNanoseconds - t0) / 1e6)
        }
        let mean = times.reduce(0, +) / Double(times.count)
        let worst = times.max() ?? 0
        print(String(format: "[generator] l4: mean %.1f ms, max %.1f ms over %d seeds", mean, worst, times.count))
        #expect(mean < 150, "mean \(mean) ms")
        // Generous CI margin for a single slow seed (several retries on a loaded machine).
        #expect(worst < 450, "max \(worst) ms")
    }
}
