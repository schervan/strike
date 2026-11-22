import Foundation
import Testing
@testable import Strike

struct SolvabilityTests {
    static func copy(_ l: GeneratedLevel, items: [ItemPlacement]? = nil, elements: [PlacedElement]? = nil,
                     enemies: [EnemySpawn]? = nil, gates: [GateDoor]? = nil) -> GeneratedLevel {
        GeneratedLevel(levelId: l.levelId, levelIndex: l.levelIndex, seedUsed: l.seedUsed, attempts: l.attempts,
                       usedFallback: l.usedFallback, grid: l.grid, rooms: l.rooms, corridors: l.corridors,
                       startRoomId: l.startRoomId, exitRoomId: l.exitRoomId, criticalPath: l.criticalPath,
                       gates: gates ?? l.gates, exitDoor: l.exitDoor, elements: elements ?? l.elements,
                       itemPlacements: items ?? l.itemPlacements, enemySpawns: enemies ?? l.enemySpawns,
                       pickups: l.pickups, crates: l.crates, checkpoints: l.checkpoints, exitPad: l.exitPad)
    }

    static func level(_ id: String, seed: UInt64 = 7) -> (GeneratedLevel, LevelDef) {
        let def = GeneratedCorpus.def(id)
        return (LevelGenerator.generate(def, seed: seed, catalog: GeneratedCorpus.catalog), def)
    }

    @Test(arguments: ["l1", "l2", "l3", "l4", "l5"])
    func fallbackSeedValidatesOnItsFirstAttempt(_ id: String) throws {
        let def = GeneratedCorpus.def(id)
        let l = try #require(LevelGenerator.attempt(def, seed: def.fallbackSeed, catalog: GeneratedCorpus.catalog),
                             "\(id) fallbackSeed \(def.fallbackSeed) does not generate")
        #expect(SolvabilityChecker.problems(l, def: def, catalog: GeneratedCorpus.catalog) == [])
    }

    @Test func validLevelsPassLockAndKey() {
        for id in ["l1", "l2", "l3", "l4", "l5"] {
            let (l, def) = Self.level(id)
            #expect(SolvabilityChecker.lockAndKey(l) == [], "\(id)")
            #expect(SolvabilityChecker.isValid(l, def: def, catalog: GeneratedCorpus.catalog))
        }
    }

    @Test func itemBehindItsGateIsCaught() throws {
        let (l, def) = Self.level("l4")
        // The keycard opens gate_3; move it into zone 3.
        let keycard = try #require(l.itemPlacements.first { $0.itemId == "keycard" })
        let zone3 = try #require(l.rooms.first { $0.zone == 3 && $0.id != l.exitRoomId } ?? l.rooms.first { $0.zone == 3 })
        let moved = ItemPlacement(id: keycard.id, itemId: keycard.itemId, cell: zone3.rect.centerCell,
                                  roomId: zone3.id, zone: 3, elementId: keycard.elementId)
        let broken = Self.copy(l, items: l.itemPlacements.map { $0.id == keycard.id ? moved : $0 })
        let problems = SolvabilityChecker.problems(broken, def: def, catalog: GeneratedCorpus.catalog)
        #expect(problems.contains { $0.contains("behind gate_3") })
        #expect(problems.contains { $0.hasPrefix("lock-and-key") })
    }

    @Test func missingItemMakesTheLevelStuck() throws {
        let (l, _) = Self.level("l2")
        let broken = Self.copy(l, items: [])
        #expect(SolvabilityChecker.lockAndKey(broken).first?.contains("stuck") == true)
    }

    @Test func enemyNextToAnElementIsCaught() throws {
        let (l, def) = Self.level("l1")
        let e = try #require(l.elements.first)
        let next = GridPoint(e.cell.x + 1, e.cell.y)
        let room = try #require(l.rooms.first { $0.id == e.roomId })
        let bad = EnemySpawn(id: "enemy_bad", enemyId: "boltbot", cell: next, roomId: room.id)
        let problems = SolvabilityChecker.problems(Self.copy(l, enemies: l.enemySpawns + [bad]), def: def,
                                                   catalog: GeneratedCorpus.catalog)
        #expect(problems.contains { $0.contains("enemy_bad within") })
    }

    @Test func elementsTooCloseAreCaught() throws {
        let (l, def) = Self.level("l1")
        let a = try #require(l.elements.first)
        let b = l.elements[1]
        let moved = PlacedElement(id: b.id, type: b.type, cell: GridPoint(a.cell.x, a.cell.y + 1), roomId: a.roomId,
                                  zone: a.zone, required: b.required, requiresItem: b.requiresItem, gateId: b.gateId,
                                  itemPlacement: b.itemPlacement)
        let problems = SolvabilityChecker.problems(Self.copy(l, elements: l.elements.map { $0.id == b.id ? moved : $0 }),
                                                   def: def, catalog: GeneratedCorpus.catalog)
        #expect(problems.contains { $0.contains("closer than") })
    }

    @Test func gateWithoutItsCorridorIsCaught() throws {
        let (l, def) = Self.level("l3")
        let g = try #require(l.gates.first)
        // Shift the door into the room behind it: it no longer seals the zone.
        let room = l.rooms[g.toRoomId].rect
        let wrong = GateDoor(id: g.id, zone: g.zone, cells: [room.centerCell, GridPoint(room.centerCell.x + 1, room.centerCell.y)],
                             orientation: g.orientation, fromRoomId: g.fromRoomId, toRoomId: g.toRoomId, elementIds: g.elementIds)
        let problems = SolvabilityChecker.problems(Self.copy(l, gates: [wrong]), def: def, catalog: GeneratedCorpus.catalog)
        #expect(problems.contains { $0.contains("not on a corridor") })
        #expect(problems.contains { $0.contains("reachable without its gate") })
    }
}
