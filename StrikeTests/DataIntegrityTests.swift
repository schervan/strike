import Foundation
import SpriteKit
import Testing
@testable import Strike

/// M0 data/asset integrity. Uses JSONSerialization because Codable models do not exist yet.
@MainActor
struct DataIntegrityTests {
    static let files = ["weapons", "items", "enemies", "loot", "levels"]

    static func load(_ name: String) throws -> [String: Any] {
        let bundle = Bundle(for: GameModel.self)
        let url = try #require(
            bundle.url(forResource: name, withExtension: "json", subdirectory: "Data")
                ?? bundle.url(forResource: name, withExtension: "json"),
            "missing \(name).json in bundle")
        let obj = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
        return try #require(obj as? [String: Any])
    }

    static func ids(_ root: [String: Any], _ key: String) -> Set<String> {
        Set((root[key] as? [[String: Any]] ?? []).compactMap { $0["id"] as? String })
    }

    /// Recursively collect string values for any of `keys` (also arrays of strings).
    static func collect(_ node: Any, keys: Set<String>, into out: inout [(String, String)]) {
        if let d = node as? [String: Any] {
            for (k, v) in d {
                if keys.contains(k) {
                    if let s = v as? String { out.append((k, s)) }
                    if let a = v as? [String] { a.forEach { out.append((k, $0)) } }
                }
                collect(v, keys: keys, into: &out)
            }
        } else if let a = node as? [Any] {
            a.forEach { collect($0, keys: keys, into: &out) }
        }
    }

    @Test func allJSONFilesDecode() throws {
        for f in Self.files {
            let root = try Self.load(f)
            #expect(root["version"] != nil, "\(f).json has no version")
        }
    }

    @Test func crossReferencesResolve() throws {
        let items = Self.ids(try Self.load("items"), "items")
        let weapons = try Self.load("weapons")
        let enemies = try Self.load("enemies")
        let loot = try Self.load("loot")
        let levels = try Self.load("levels")
        let enemyIds = Self.ids(enemies, "enemies")
        let tableIds = Self.ids(loot, "tables")
        #expect(!items.isEmpty); #expect(!enemyIds.isEmpty); #expect(!tableIds.isEmpty)

        var refs: [(String, String)] = []
        for w in weapons["weapons"] as? [[String: Any]] ?? [] {
            #expect(items.contains(w["ammoId"] as? String ?? ""), "weapon \(w["id"] ?? "?") ammoId unresolved")
        }
        for e in enemies["enemies"] as? [[String: Any]] ?? [] {
            #expect(tableIds.contains(e["lootTableId"] as? String ?? ""), "enemy \(e["id"] ?? "?") lootTableId unresolved")
        }
        Self.collect(loot, keys: ["itemId", "itemIds"], into: &refs)
        for (k, v) in refs { #expect(items.contains(v), "loot \(k)=\(v) not in items") }

        refs = []
        Self.collect(levels, keys: ["itemId", "itemIds"], into: &refs)
        for (k, v) in refs { #expect(items.contains(v), "level \(k)=\(v) not in items") }
        refs = []
        Self.collect(levels, keys: ["enemyId", "enemyIds"], into: &refs)
        #expect(!refs.isEmpty)
        for (k, v) in refs { #expect(enemyIds.contains(v), "level \(k)=\(v) not in enemies") }
        refs = []
        Self.collect(levels, keys: ["lootTableId"], into: &refs)
        for (k, v) in refs { #expect(tableIds.contains(v), "level \(k)=\(v) not in loot tables") }
        #expect((levels["levels"] as? [Any])?.count == 5)
    }

    @Test(arguments: [
        ("hero", "hero_idle_01"), ("enemies", "enemy_boltbot_idle_01"),
        ("boss", "boss_megamech_idle_01"), ("items", "pickup_healpack"),
        ("tiles", "tile_l1_floor_01"), ("ui", "ui_btn_fire"),
    ])
    func sampleTextureLoads(atlas: String, name: String) {
        let a = SKTextureAtlas(named: atlas)
        // Atlas only ships @2x art, so textureNames may carry the "@2x.png" suffix.
        let candidates: Set<String> = [name, name + "@2x.png", name + "@2x"]
        let found = a.textureNames.contains { candidates.contains($0) }
        #expect(found, "\(atlas) atlas lacks \(name)")
        let size = a.textureNamed(name).size()
        #expect(size.width > 0 && size.height > 0)
    }

    @Test func allNineAtlasesNonEmpty() {
        for n in ["hero", "enemies", "boss", "items", "tiles", "ui", "fx", "pixel", "puzzle"] {
            #expect(!SKTextureAtlas(named: n).textureNames.isEmpty, "atlas \(n) empty")
        }
    }

    @Test func localizableHasDeAndEn() throws {
        let url = try #require(Bundle(for: GameModel.self).url(forResource: "Localizable", withExtension: "xcstrings")
            ?? Bundle(for: GameModel.self).url(forResource: "Localizable", withExtension: "strings", subdirectory: nil, localization: "de"))
        _ = url
        let locs = Bundle(for: GameModel.self).localizations
        #expect(locs.contains("de")); #expect(locs.contains("en"))
    }
}
