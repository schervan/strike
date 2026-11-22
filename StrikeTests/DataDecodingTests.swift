import Foundation
import Testing
@testable import Strike

struct DataDecodingTests {
    @Test func starterBlasterNumbers() throws {
        let w = try TestData.starter()
        #expect(w.magazineSize == 12)
        #expect(w.reserveMax == 96)
        #expect(w.reloadSec == 1.0)
        #expect(w.fireRate == 4)
        #expect(w.projectileTextureName == "proj_starter")
    }

    @Test func boltbotNumbers() throws {
        let b = try #require(try TestData.load().enemies["boltbot"])
        #expect(b.hp == 30)
        #expect(b.moveSpeed == 110)
        #expect(b.hopEverySec != nil)
        #expect(b.separation != nil)
        #expect(b.keyPoseTextureName == "enemy_boltbot_idle_01")
    }

    @Test func everythingDecodes() throws {
        let d = try TestData.load()
        #expect(d.weapons.count == 3)
        #expect(d.enemies.count >= 7)
        #expect(d.items["bolt"]?.isMagnetic == true)
        #expect(d.lootTables["loot_boltbot"] != nil)
        #expect(d.lootModifiers.count >= 3)
        #expect(d.lootModifiers.allSatisfy { $0.knownCondition != nil })
        #expect(d.hero.maxHp > 0)
        #expect(d.hero.startLoadout.magazine == 12)
        #expect(d.hero.startLoadout.reserve == 48)
        #expect(d.controls.stickRadius > 0)
        #expect(d.camera.smoothingSec > 0)
    }

    @Test func m1TimingFieldsComeFromJSON() throws {
        let d = try TestData.load()
        #expect(d.hero.respawnInvulnerableSec == 2.0)
        #expect(d.enemies["boltbot"]?.alertSec == 0.4)
    }

    @Test func validateIsEmpty() throws {
        #expect(try TestData.load().validate() == [])
    }

    @Test func unknownFieldsIgnoredAndOptionalsOptional() throws {
        let json = """
        {"version": 1, "enemies": [{"id": "x", "nameKey": "k", "behavior": "chaser", "hp": 1,
          "moveSpeed": 1, "radius": 1, "flying": false, "contactDamage": 0, "detectRange": 1,
          "threatCost": 0, "scoreValue": 0, "lootTableId": "t", "somethingNew": {"a": 1}}]}
        """
        let f = try JSONDecoder().decode(EnemiesFile.self, from: Data(json.utf8))
        #expect(f.enemies.first?.attack == nil)
        #expect(f.enemies.first?.hopChance == nil)
        #expect(f.enemies.first?.effectiveAlertSec == EnemyDef.defaultAlertSec)
    }

    @Test func validateReportsBrokenReferences() throws {
        let d = try TestData.load()
        var items = Array(d.items.values)
        items.removeAll { $0.id == "ammo_starter" }
        let loot = LootFile(version: 1, modifiers: d.lootModifiers, tables: Array(d.lootTables.values))
        let hero = HeroFile(version: 1, hero: d.hero, controls: d.controls, camera: d.camera)
        let broken = GameData(weapons: Array(d.weapons.values), enemies: Array(d.enemies.values),
                              items: items, loot: loot, hero: hero)
        #expect(!broken.validate().isEmpty)
    }
}
