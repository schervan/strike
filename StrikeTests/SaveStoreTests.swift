import Foundation
import Testing
@testable import Strike

struct SaveStoreTests {
    static var data: GameData { GeneratedCorpus.data }

    let dir: URL
    let store: SaveStore

    init() {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SaveStoreTests-\(UUID().uuidString)", isDirectory: true)
        store = SaveStore(directory: dir)
    }

    /// A run with something in every field.
    static func sampleRun() throws -> RunState {
        var run = RunState.newGame(data: data)
        run.startLevel(data.levels["l1"]!, data: data)
        _ = run.inventory.add("food_cookie", count: 3)
        _ = run.inventory.add("ammo_spread", count: 1)
        run.inventory.assignQuick(itemId: "ammo_spread", to: 3)
        let spread = try #require(data.weapons["blaster_spread"])
        run.loadout.addWeapon(spread)
        run.loadout.equip(spread.id)
        run.loadout.ammo.add("ammo_rapid", amount: 40)
        run.completeLevel(data.levels["l1"]!, result: LevelBest(stars: [true, false, true], bestScore: 2350,
                                                                bestTimeSec: 301, datachips: 2, fewestRescues: 0),
                          data: data)
        run.settings.pixelTalk = .some
        return run
    }

    @Test func runStateRoundTripsThroughSaveStore() throws {
        defer { try? FileManager.default.removeItem(at: dir) }
        #expect(store.load() == nil)
        #expect(!store.hasSave)
        let run = try Self.sampleRun()
        let savedAt = Date(timeIntervalSince1970: 1_800_000_000)
        try store.save(SaveGame(run: run, savedAt: savedAt))
        #expect(store.hasSave)
        var loaded = try #require(store.load())
        #expect(loaded.version == 1)
        #expect(loaded.savedAt == savedAt)
        loaded.run.bind(to: Self.data)
        #expect(loaded.run == run)
        #expect(loaded.run.inventory.quick == run.inventory.quick)
        #expect(loaded.run.loadout.ammo.reserves == run.loadout.ammo.reserves)
        #expect(loaded.run.currentLevelId == "l2" && loaded.run.unlockedLevelIndex == 2)
        // After binding, the restored bag and bank work with the JSON rules again.
        do { let v = loaded.run.inventory.add("healpack", count: 1); #expect(v == 0) }
        #expect(loaded.run.loadout.ammo.cap("ammo_starter") == Self.data.weapons["blaster_starter"]!.reserveMax)
        #expect(!FileManager.default.fileExists(atPath: store.backupURL.path))
    }

    @Test func corruptFileGivesNilPlusBackupAndDoesNotCrash() throws {
        defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("{ not json".utf8).write(to: store.fileURL)
        #expect(store.load() == nil)
        #expect(FileManager.default.fileExists(atPath: store.backupURL.path))
        #expect(!store.hasSave)
        // Valid JSON, valid version, wrong shape.
        try Data(#"{"version":1,"run":{"loadout":42}}"#.utf8).write(to: store.fileURL)
        #expect(store.load() == nil)
        #expect(!store.hasSave)
        let bak = try String(contentsOf: store.backupURL, encoding: .utf8)
        #expect(bak.contains("42"))                                  // newest bad file kept
        // A fresh save works afterwards.
        try store.save(SaveGame(run: RunState.newGame(data: Self.data)))
        #expect(store.load() != nil)
    }

    @Test func versionMismatchGivesNilPlusBackup() throws {
        defer { try? FileManager.default.removeItem(at: dir) }
        let game = SaveGame(run: RunState.newGame(data: Self.data), version: 2)
        try store.save(game)
        #expect(store.load() == nil)
        #expect(FileManager.default.fileExists(atPath: store.backupURL.path))
        #expect(!store.hasSave)
    }

    @Test func gddExampleSaveDecodesWithDefaults() throws {
        defer { try? FileManager.default.removeItem(at: dir) }
        // GDD §16.10 example (shortened slots, unknown extra field, no settings.aimAssist).
        let json = #"""
        {"version":1,"savedAt":"2026-11-24T10:00:00Z","extra":true,"run":{"currentLevelId":"l2","unlockedLevelIndex":2,
         "loadout":{"owned":["blaster_starter"],"equipped":"blaster_starter","magazines":{"blaster_starter":12},
                    "ammo":{"reserves":{"ammo_starter":48,"ammo_spread":12}}},
         "inventory":{"slots":[{"itemId":"healpack","count":1},{"itemId":"food_apple","count":2},null],
                      "quick":["healpack","food_apple",null,null]},
         "bestResults":{"l1":{"stars":[true,false,true],"bestScore":2350,"bestTimeSec":301,"datachips":2,"fewestRescues":0}},
         "settings":{"pixelTalk":"lots"}}}
        """#
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data(json.utf8).write(to: store.fileURL)
        var game = try #require(store.load())
        game.run.bind(to: Self.data)
        #expect(game.run.inventory.slotCount == 25)
        #expect(game.run.inventory.count(of: "food_apple") == 2)
        #expect(game.run.loadout.ammo.reserve("ammo_spread") == 12)
        #expect(game.run.settings == RunSettings(pixelTalk: .lots, aimAssist: true))
        #expect(game.run.bestResults["l1"]?.bestScore == 2350)
    }

    // MARK: Run rules

    @Test func startGiftIsAppliedOnceOnANewGameNotAgainOnReplayIfOwned() throws {
        let l1 = try #require(Self.data.levels["l1"])
        let gifts = try #require(l1.pickups.startGift)
        var run = RunState.newGame(data: Self.data)
        run.startLevel(l1, data: Self.data)
        for g in gifts { #expect(run.inventory.count(of: g.itemId) == g.count, "\(g.itemId)") }
        #expect(run.inventory.quickItem(0) == "healpack")            // auto-assigned Q1
        run.startLevel(l1, data: Self.data)                           // replay: already owned
        for g in gifts { #expect(run.inventory.count(of: g.itemId) == g.count, "\(g.itemId)") }
        _ = run.inventory.add("food_apple", count: 5)                 // more than the gift: never reduced
        run.startLevel(l1, data: Self.data)
        #expect(run.inventory.count(of: "food_apple") == 7)
        #expect(run.currentLevelId == "l1")
    }

    @Test func levelStartTopsUpTheStarterAndClearsPuzzleItems() throws {
        let start = Self.data.hero.startLoadout
        let starter = try #require(Self.data.weapons[start.weaponId])
        var run = RunState.newGame(data: Self.data)
        run.loadout.setMagazine(starter, 0)
        run.loadout.ammo.set(starter.ammoId, 2)
        _ = run.inventory.add("fuse", count: 1)
        run.startLevel(Self.data.levels["l2"]!, data: Self.data)
        #expect(run.loadout.magazine(starter.id) == start.magazine)
        #expect(run.loadout.reserve(for: starter) == start.reserve)
        #expect(run.inventory.count(of: "fuse") == 0)
    }

    @Test func completeLevelMergesBestAndUnlocksNext() {
        var run = RunState.newGame(data: Self.data)
        let l1 = Self.data.levels["l1"]!
        run.completeLevel(l1, result: LevelBest(stars: [true, false, false], bestScore: 100, bestTimeSec: 300,
                                                datachips: 1, fewestRescues: 2), data: Self.data)
        run.completeLevel(l1, result: LevelBest(stars: [false, true, false], bestScore: 80, bestTimeSec: 250,
                                                datachips: 3, fewestRescues: 0), data: Self.data)
        #expect(run.bestResults["l1"] == LevelBest(stars: [true, true, false], bestScore: 100, bestTimeSec: 250,
                                                   datachips: 3, fewestRescues: 0))
        #expect(run.unlockedLevelIndex == 2 && run.currentLevelId == "l2")
        let last = Self.data.levelOrder.last!
        run.completeLevel(last, result: LevelBest(bestScore: 1, bestTimeSec: 1, datachips: 0, fewestRescues: 0),
                          data: Self.data)
        #expect(run.currentLevelId == last.id)
        #expect(run.unlockedLevelIndex == 2)                          // completing the last unlocks nothing new
    }
}
