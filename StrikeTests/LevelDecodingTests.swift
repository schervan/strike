import Foundation
import Testing
@testable import Strike

/// Marker class: `Bundle(for:)` gives the test bundle, which has no `Data/rules.json`.
final class TestBundleMarker {}

struct LevelDecodingTests {
    let data: GameData
    init() throws { data = try TestData.load() }

    @Test func allFiveLevelsDecodeInOrder() {
        #expect(data.levels.count == 5)
        #expect(data.levelOrder.map(\.id) == ["l1", "l2", "l3", "l4", "l5"])
        #expect(data.levelOrder.map(\.index) == [1, 2, 3, 4, 5])
        #expect(data.level(after: "l1")?.id == "l2")
        #expect(data.level(after: "l5") == nil)
    }

    @Test func levelFieldsMatchTheRecipes() throws {
        let l2 = try #require(data.levels["l2"])
        #expect(l2.generator.zones == 2)
        #expect(l2.puzzle.gates.count == 1)
        #expect(l2.puzzle.gates[0].opensWith[0].type == .button)
        #expect(l2.puzzle.elements.contains { $0.zone == .any && $0.type == .lever })
        #expect(l2.puzzle.elements.contains { $0.requiresItem == "fuse" && $0.zone == .index(2) })
        #expect(l2.pickups.weaponPickup == "blaster_spread")
        let l4 = try #require(data.levels["l4"])
        #expect(l4.generator.zones == 3)
        #expect(l4.puzzle.gates.map(\.zone) == [2, 3])
        #expect(l4.puzzle.gates[1].opensWith[0].requiresItem == "keycard")
        let l5 = try #require(data.levels["l5"])
        #expect(l5.puzzle.elements.compactMap(\.itemPlacement) == [.earlierZone, .sameZone])
        #expect(l5.bossId == "megamech")
        for l in data.levelOrder {
            #expect(l.pickups.datachips == 3, "\(l.id)")
            #expect(l.fallbackSeed > 0, "\(l.id)")
        }
    }

    @Test func validateResolvesLevelReferences() {
        #expect(data.validateLevels() == [])
        #expect(data.validate() == [])
    }

    @Test func validateReportsBrokenLevelReferences() throws {
        let url = try #require(Bundle(for: GameModel.self).url(forResource: "levels", withExtension: "json", subdirectory: "Data"))
        var text = try String(contentsOf: url, encoding: .utf8)
        text = text.replacingOccurrences(of: "\"enemyId\": \"boltbot\"", with: "\"enemyId\": \"nobot\"")
        text = text.replacingOccurrences(of: "\"requiresItem\": \"fuse\"", with: "\"requiresItem\": \"nofuse\"")
        text = text.replacingOccurrences(of: "\"lootTableId\": \"loot_crate_small\"", with: "\"lootTableId\": \"nocrate\"")
        let levels = try JSONDecoder().decode(LevelsFile.self, from: Data(text.utf8)).levels
        let loot = LootFile(version: 1, modifiers: data.lootModifiers, tables: Array(data.lootTables.values))
        let hero = HeroFile(version: 1, hero: data.hero, controls: data.controls, camera: data.camera)
        let broken = GameData(weapons: Array(data.weapons.values), enemies: Array(data.enemies.values),
                              items: Array(data.items.values), loot: loot, hero: hero, levels: levels, rules: data.rules)
        let problems = broken.validate().joined(separator: "\n")
        #expect(problems.contains("nobot"))
        #expect(problems.contains("nofuse"))
        #expect(problems.contains("nocrate"))
    }

    @Test func zoneSpecDecodesIntOrAny() throws {
        struct Box: Decodable { let zone: ZoneSpec }
        #expect(try JSONDecoder().decode(Box.self, from: Data(#"{"zone": 2}"#.utf8)).zone == .index(2))
        #expect(try JSONDecoder().decode(Box.self, from: Data(#"{"zone": "any"}"#.utf8)).zone == .any)
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(Box.self, from: Data(#"{"zone": "all"}"#.utf8)) }
        #expect(ZoneSpec.any.allows(3))
        #expect(!ZoneSpec.index(1).allows(2))
    }

    @Test func rulesComeFromRulesJSON() {
        let r = data.rules
        #expect(r.puzzle.leverPullSec == 0.4)
        #expect(r.puzzle.plateHoldSec == 1.0)
        #expect(r.puzzle.doorPanSec == 1.0)
        #expect(r.puzzle.doorMaxLights == 8)
        #expect(r.leash.rangeFactor == 2.0)
        #expect(r.leash.returnAfterSec == 4.0)
        #expect(r.minimap.revealOnEnter)
        #expect(r.minimap.updateHz == 10)
    }

    @Test func missingRulesFileFallsBackToGDDDefaults() throws {
        let rules = try GameData.loadRules(Bundle(for: TestBundleMarker.self))
        #expect(rules == RulesDef.fallback)
        #expect(rules.leash.rangeFactor == 2.0)
        #expect(rules.puzzle.plateHoldSec == 1.0)
    }

    @Test func rulesToleratesUnknownAndOptionalFields() throws {
        let json = #"{"version": 1, "puzzle": {"leverPullSec": 0.5, "plateHoldSec": 2, "doorPanSec": 1, "doorMaxLights": 6, "new": 1},"#
            + #""leash": {"rangeFactor": 3, "returnAfterSec": 5}, "minimap": {"revealOnEnter": false, "updateHz": 5}}"#
        let r = RulesDef(file: try JSONDecoder().decode(RulesFile.self, from: Data(json.utf8)))
        #expect(r.puzzle.interactFocusRadius == nil)
        #expect(r.puzzle.leverPullSec == 0.5)
        #expect(r.toast == RulesDef.fallback.toast)
    }

    @Test func enemyKnockbackComesFromJSON() throws {
        let b = try #require(data.enemies["boltbot"])
        #expect(b.knockbackSec == 0.1)
        #expect(data.enemies.values.allSatisfy { $0.knockbackSec != nil })
    }
}
