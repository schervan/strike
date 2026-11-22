import Foundation
import SpriteKit
import Testing
@testable import Strike

@MainActor
struct RobustnessTests {
    static func enemyJSON(_ extra: String = "", drop: String? = nil) -> Data {
        var f: [String: String] = [
            "id": "\"x\"", "nameKey": "\"k\"", "behavior": "\"chaser\"", "hp": "1", "moveSpeed": "1", "radius": "1",
            "flying": "false", "contactDamage": "0", "detectRange": "1", "threatCost": "0", "scoreValue": "0",
            "lootTableId": "\"t\"",
        ]
        if let drop { f[drop] = nil }
        let body = f.map { "\"\($0.key)\": \($0.value)" }.joined(separator: ",") + extra
        return Data("{\"version\":1,\"enemies\":[{\(body)}]}".utf8)
    }

    @Test func unknownFieldsAndNestedUnknownsDecode() throws {
        let d = Self.enemyJSON(#", "future": [1,2,{"a":null}], "attack": {"type":"none","damage":0,"cooldownSec":0,"telegraphSec":0,"range":0,"newThing":1}"#)
        let f = try JSONDecoder().decode(EnemiesFile.self, from: d)
        #expect(f.enemies.count == 1)
    }

    @Test func eachRequiredFieldMissingFailsCleanlyNotCrashes() {
        for field in ["id", "hp", "moveSpeed", "lootTableId", "behavior"] {
            #expect(throws: DecodingError.self, "missing \(field)") {
                try JSONDecoder().decode(EnemiesFile.self, from: Self.enemyJSON(drop: field))
            }
        }
    }

    @Test func garbageInputThrows() {
        for s in ["", "{", "[]", "null", "{\"version\":1}", "{\"version\":1,\"enemies\":\"no\"}"] {
            #expect(throws: (any Error).self) { try JSONDecoder().decode(EnemiesFile.self, from: Data(s.utf8)) }
        }
    }

    @Test func missingBundleFileGivesTypedError() {
        let empty = Bundle(path: NSTemporaryDirectory()) ?? Bundle.main
        do { _ = try GameData.load(bundle: empty); Issue.record("expected throw") }
        catch is GameDataError {} catch { Issue.record("wrong error \(error)") }
    }

    @Test func duplicateIdsReported() throws {
        let d = try TestData.load()
        let w = Array(d.weapons.values)
        let g = GameData(weapons: w + [w[0]], enemies: Array(d.enemies.values), items: Array(d.items.values),
                         loot: LootFile(version: 1, modifiers: d.lootModifiers, tables: Array(d.lootTables.values)),
                         hero: HeroFile(version: 1, hero: d.hero, controls: d.controls, camera: d.camera))
        #expect(g.validate().contains { $0.contains("duplicate") })
    }

    @Test func projectilePoolStress() throws {
        let w = try TestData.starter()
        let pool = ProjectilePool(capacity: 48, bodyRadius: CGFloat(w.projectileRadius))
        let parent = SKNode()
        let tex = Textures.texture(w.projectileTextureName, in: .items)
        var rng = SystemRandomNumberGenerator()
        var live: [ProjectileNode] = []
        for i in 0..<20_000 {
            if Int.random(in: 0..<3, using: &rng) != 0,
               let p = pool.spawn(weapon: w, texture: tex, at: CGPoint(x: i % 50, y: 0), angle: .random(in: 0..<6.28), in: parent) {
                live.append(p)
            } else if !live.isEmpty {
                pool.recycle(live.remove(at: Int.random(in: 0..<live.count, using: &rng)))
            }
            if i % 997 == 0 { pool.recycle(pool.allNodes[0]); pool.recycle(pool.allNodes[0]) } // double recycle is safe
            #expect(pool.activeCount <= 48)
        }
        live.filter { $0.isActive }.forEach { pool.recycle($0) }
        pool.recycleAll()
        #expect(pool.activeCount == 0)
        #expect(parent.children.isEmpty, "recycled nodes must leave the scene graph (\(parent.children.count) left)")
        #expect(pool.allNodes.count == 48)
    }
}
