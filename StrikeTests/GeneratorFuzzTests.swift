import Foundation
import Testing
@testable import Strike

/// M2-7: independent generator fuzz. The reachability model here is written from the GDD rules and does
/// NOT call `SolvabilityChecker`: flood-fill the grid with every door closed, interact with whatever
/// is reachable (machines need their item), open doors whose elements are all on, repeat to a fixpoint.
@Suite(.serialized)
struct GeneratorFuzzTests {
    /// Default 400 seeds per level keeps the shared-simulator unit run short (a 2,000-seed run takes ~3.5 minutes and was
    /// killed by the test host when other xcodebuild jobs shared the simulator). Full run: TEST_RUNNER_FUZZ_SEEDS=2000.
    static let seedCount = Int(ProcessInfo.processInfo.environment["FUZZ_SEEDS"] ?? "") ?? 400

    struct Outcome { var problems: [String] = [] }

    /// Cells reachable from `start` over floor, treating `blocked` as walls (4-neighbour walk).
    static func flood(_ g: TileGrid, from start: GridPoint, blocked: Set<GridPoint>) -> Set<GridPoint> {
        guard g.isWalkable(start), !blocked.contains(start) else { return [] }
        var seen: Set<GridPoint> = [start]
        var queue = [start]
        var head = 0
        while head < queue.count {
            let p = queue[head]; head += 1
            for n in p.neighbors4 where g.isWalkable(n) && !blocked.contains(n) && !seen.contains(n) {
                seen.insert(n); queue.append(n)
            }
        }
        return seen
    }

    /// An element is usable when the player can stand next to (or on) any of its cells.
    static func touches(_ cells: [GridPoint], _ reach: Set<GridPoint>) -> Bool {
        for c in cells {
            if reach.contains(c) { return true }
            for dx in -1...1 { for dy in -1...1 where reach.contains(GridPoint(c.x + dx, c.y + dy)) { return true } }
        }
        return false
    }

    static func check(_ l: GeneratedLevel, def: LevelDef) -> [String] {
        var out: [String] = []
        let g = l.grid
        func floor(_ p: GridPoint, _ what: String) { if !g.isWalkable(p) { out.append("\(what) at \(p) not on floor") } }

        // Placement sanity.
        floor(l.heroStart, "hero start")
        floor(l.exitPad, "exit pad")
        for e in l.elements { for c in e.cells { floor(c, "element \(e.id)") } }
        for i in l.itemPlacements { floor(i.cell, "item \(i.id)") }
        for s in l.enemySpawns { floor(s.cell, "enemy \(s.id)") }
        for p in l.pickups { floor(p.cell, "pickup \(p.id)") }
        for c in l.crates { floor(c.cell, "crate \(c.id)") }
        for c in l.checkpoints { floor(c.cell, "checkpoint \(c.id)") }
        for gate in l.gates { for c in gate.cells { floor(c, "gate \(gate.id)") } }
        for c in l.exitDoor.cells { floor(c, "exit door") }

        let doorCells = Set(l.gates.flatMap(\.cells) + l.exitDoor.cells)
        var occupied: [GridPoint: String] = [:]
        func claim(_ cells: [GridPoint], _ who: String) {
            for c in cells {
                if let o = occupied[c] { out.append("overlap at \(c): \(o) vs \(who)") } else { occupied[c] = who }
                if doorCells.contains(c) { out.append("\(who) stands in a door cell \(c)") }
            }
        }
        for e in l.elements { claim(e.cells, "element \(e.id)") }
        for i in l.itemPlacements { claim([i.cell], "item \(i.id)") }
        for p in l.pickups { claim([p.cell], "pickup \(p.id)") }
        for c in l.crates { claim([c.cell], "crate \(c.id)") }
        for c in l.checkpoints { claim([c.cell], "checkpoint \(c.id)") }
        claim([l.exitPad], "exit pad")
        // Enemies may share cells with nothing solid.
        for s in l.enemySpawns where occupied[s.cell] != nil { out.append("enemy \(s.id) on \(occupied[s.cell]!) at \(s.cell)") }
        for s in l.enemySpawns where doorCells.contains(s.cell) { out.append("enemy \(s.id) in door") }

        // Fixpoint simulation with all doors closed.
        var openGates = Set<String>()
        var exitOpen = false
        var active = Set<String>()
        var items = Set<String>()          // placement ids picked up
        var heldItemIds: [String: Int] = [:]
        var progress = true
        var reach = Set<GridPoint>()
        while progress {
            progress = false
            var blocked = Set<GridPoint>()
            for gt in l.gates where !openGates.contains(gt.id) { blocked.formUnion(gt.cells) }
            if !exitOpen { blocked.formUnion(l.exitDoor.cells) }
            reach = flood(g, from: l.heroStart, blocked: blocked)
            for ip in l.itemPlacements where !items.contains(ip.id) && touches([ip.cell], reach) {
                items.insert(ip.id); heldItemIds[ip.itemId, default: 0] += 1; progress = true
            }
            for e in l.elements where !active.contains(e.id) && touches(e.cells, reach) {
                if e.type == .machine, let need = e.requiresItem {
                    guard (heldItemIds[need] ?? 0) > 0 else { continue }
                    heldItemIds[need]! -= 1
                }
                active.insert(e.id); progress = true
            }
            for gt in l.gates where !openGates.contains(gt.id) && !gt.elementIds.isEmpty
                && gt.elementIds.allSatisfy({ active.contains($0) }) {
                openGates.insert(gt.id); progress = true
            }
            if !exitOpen, l.exitDoor.elementIds.allSatisfy({ active.contains($0) }) {
                exitOpen = true; progress = true
            }
        }
        for e in l.elements where e.required && !active.contains(e.id) { out.append("required element \(e.id) (\(e.type)) never activatable") }
        for gt in l.gates where !openGates.contains(gt.id) { out.append("gate \(gt.id) never opens") }
        for gt in l.gates where gt.elementIds.isEmpty { out.append("gate \(gt.id) has no opener elements") }
        if !exitOpen { out.append("exit never opens") }
        // The exit door must wait for every required, non-gate element.
        let exitSet = Set(l.exitDoor.elementIds)
        for e in l.elements where e.required && e.gateId == nil && !exitSet.contains(e.id) { out.append("required \(e.id) not wired to exit") }
        if !reach.contains(l.exitPad) { out.append("exit pad unreachable after everything is on") }
        for ip in l.itemPlacements where !items.contains(ip.id) { out.append("item \(ip.id) never reachable") }
        for s in l.enemySpawns where !reach.contains(s.cell) { out.append("enemy \(s.id) unreachable at \(s.cell)") }
        for p in l.pickups where !reach.contains(p.cell) { out.append("pickup \(p.id) unreachable") }
        for c in l.checkpoints where !reach.contains(c.cell) { out.append("checkpoint \(c.id) unreachable") }

        // Exit pad is sealed while the exit door is closed, even with every gate open.
        var onlyExit = Set(l.exitDoor.cells)
        let sealed = flood(g, from: l.heroStart, blocked: onlyExit)
        if sealed.contains(l.exitPad) { out.append("exit pad reachable without opening the exit") }
        onlyExit.removeAll()

        // With everything closed from the start, the start room is connected to the first elements only
        // through floor: the hero start must reach at least one cell besides itself.
        let start = flood(g, from: l.heroStart, blocked: doorCells)
        if start.count < 20 { out.append("start area tiny (\(start.count) cells)") }

        // Whole-map connectivity with doors open: every floor cell belongs to one component.
        let all = flood(g, from: l.heroStart, blocked: [])
        if all.count != g.floorCount { out.append("floor disconnected: \(all.count) of \(g.floorCount)") }
        return out
    }

    @Test(arguments: ["l1", "l2", "l3", "l4", "l5"])
    func fuzz(levelId: String) throws {
        let data = try TestData.load()
        let def = try #require(data.levels[levelId])
        let catalog = GeneratorCatalog(data: data)
        var failures: [String] = []
        var fallbacks = 0, maxAttempts = 0
        let t0 = Date()
        for seed in 1...UInt64(Self.seedCount) {
            let l = LevelGenerator.generate(def, seed: seed, catalog: catalog)
            if l.usedFallback { fallbacks += 1 }
            maxAttempts = max(maxAttempts, l.attempts)
            let p = Self.check(l, def: def)
            if !p.isEmpty, failures.count < 12 { failures.append("seed \(seed): \(p.prefix(3).joined(separator: "; "))") }
            else if !p.isEmpty { failures.append("") }
        }
        let dt = Date().timeIntervalSince(t0)
        print("FUZZ \(levelId): \(Self.seedCount) seeds, \(String(format: "%.1f", dt)) s (\(String(format: "%.1f", dt / Double(Self.seedCount) * 1000)) ms/seed), fallbacks=\(fallbacks), maxAttempts=\(maxAttempts), failingSeeds=\(failures.count)")
        for f in failures.prefix(12) where !f.isEmpty { print("FUZZFAIL \(levelId) \(f)") }
        #expect(failures.isEmpty, "\(failures.count) of \(Self.seedCount) seeds failed, first: \(failures.first ?? "")")
    }

    // MARK: Checker self-test (mutants must be caught, otherwise a green fuzz means nothing)

    static func copy(_ l: GeneratedLevel, elements: [PlacedElement]? = nil, items: [ItemPlacement]? = nil,
                     enemies: [EnemySpawn]? = nil, exitPad: GridPoint? = nil, exitDoor: ExitDoor? = nil) -> GeneratedLevel {
        GeneratedLevel(levelId: l.levelId, levelIndex: l.levelIndex, seedUsed: l.seedUsed, attempts: l.attempts,
                       usedFallback: l.usedFallback, grid: l.grid, rooms: l.rooms, corridors: l.corridors,
                       startRoomId: l.startRoomId, exitRoomId: l.exitRoomId, criticalPath: l.criticalPath,
                       gates: l.gates, exitDoor: exitDoor ?? l.exitDoor, elements: elements ?? l.elements,
                       itemPlacements: items ?? l.itemPlacements, enemySpawns: enemies ?? l.enemySpawns,
                       pickups: l.pickups, crates: l.crates, checkpoints: l.checkpoints, exitPad: exitPad ?? l.exitPad)
    }

    @Test func checkerCatchesBrokenLevels() throws {
        let data = try TestData.load()
        let def = try #require(data.levels["l4"])
        let l = LevelGenerator.generate(def, seed: 7, data: data)
        #expect(Self.check(l, def: def).isEmpty, "unmutated level must pass")

        let wall = try #require((0..<l.grid.width * l.grid.height).map { l.grid.point($0) }.first { !l.grid.isWalkable($0) })
        #expect(!Self.check(Self.copy(l, exitPad: wall), def: def).isEmpty, "pad on wall not caught")

        let elem = l.elements[0]
        let moved = PlacedElement(id: elem.id, type: elem.type, cell: wall, roomId: elem.roomId, zone: elem.zone,
                                  required: elem.required, requiresItem: elem.requiresItem, gateId: elem.gateId,
                                  itemPlacement: elem.itemPlacement)
        #expect(!Self.check(Self.copy(l, elements: [moved] + l.elements.dropFirst()), def: def).isEmpty, "element in wall not caught")

        // Machine item sealed behind the exit door can never be fetched.
        let ip = try #require(l.itemPlacements.first)
        let sealed = ItemPlacement(id: ip.id, itemId: ip.itemId, cell: l.exitPad, roomId: ip.roomId, zone: ip.zone, elementId: ip.elementId)
        #expect(!Self.check(Self.copy(l, items: [sealed] + l.itemPlacements.dropFirst()), def: def).isEmpty, "unreachable item not caught")

        // Exit door that opens without waiting for the elements leaves the pad open from the start... only if wired wrongly.
        let bad = ExitDoor(cells: l.exitDoor.cells, orientation: l.exitDoor.orientation, roomId: l.exitDoor.roomId,
                           niche: l.exitDoor.niche, elementIds: l.exitDoor.elementIds + ["no_such_element"])
        #expect(!Self.check(Self.copy(l, exitDoor: bad), def: def).isEmpty, "exit waiting for a missing element not caught")

        let e0 = try #require(l.enemySpawns.first)
        let onElem = EnemySpawn(id: e0.id, enemyId: e0.enemyId, cell: l.elements[0].cell, roomId: e0.roomId)
        #expect(!Self.check(Self.copy(l, enemies: [onElem] + l.enemySpawns.dropFirst()), def: def).isEmpty, "enemy on element not caught")
    }
}
