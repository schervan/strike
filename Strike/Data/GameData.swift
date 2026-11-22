import Foundation

nonisolated enum GameDataError: Error, Sendable, CustomStringConvertible {
    case missingFile(String)
    case decodingFailed(file: String, message: String)

    var description: String {
        switch self {
        case .missingFile(let f): "missing Data/\(f).json in bundle"
        case .decodingFailed(let f, let m): "\(f).json: \(m)"
        }
    }
}

/// All balance data, decoded once from `<bundle>/Data/*.json`. `levels.json` arrives in M2.
nonisolated struct GameData: Sendable {
    let weapons: [String: WeaponDef]
    let enemies: [String: EnemyDef]
    let items: [String: ItemDef]
    let lootTables: [String: LootTable]
    let lootModifiers: [LootModifier]
    let hero: HeroDef
    let controls: ControlsDef
    let camera: CameraDef
    /// Ids that appeared more than once in their file (reported by `validate()`).
    let duplicateIds: [String]

    init(weapons: [WeaponDef], enemies: [EnemyDef], items: [ItemDef], loot: LootFile, hero: HeroFile) {
        var dupes: [String] = []
        func index<T: Identifiable>(_ list: [T], _ file: String) -> [String: T] where T.ID == String {
            var out: [String: T] = [:]
            for x in list {
                if out[x.id] != nil { dupes.append("\(file):\(x.id)") } else { out[x.id] = x }
            }
            return out
        }
        self.weapons = index(weapons, "weapons")
        self.enemies = index(enemies, "enemies")
        self.items = index(items, "items")
        self.lootTables = index(loot.tables, "loot")
        self.lootModifiers = loot.modifiers
        self.hero = hero.hero
        self.controls = hero.controls
        self.camera = hero.camera
        self.duplicateIds = dupes
    }

    static func load(bundle: Bundle = .main) throws -> GameData {
        let weapons: WeaponsFile = try decode("weapons", bundle)
        let enemies: EnemiesFile = try decode("enemies", bundle)
        let items: ItemsFile = try decode("items", bundle)
        let loot: LootFile = try decode("loot", bundle)
        let hero: HeroFile = try decode("hero", bundle)
        return GameData(weapons: weapons.weapons, enemies: enemies.enemies, items: items.items, loot: loot, hero: hero)
    }

    static func decode<T: Decodable>(_ name: String, _ bundle: Bundle) throws -> T {
        guard let url = bundle.url(forResource: name, withExtension: "json", subdirectory: "Data")
            ?? bundle.url(forResource: name, withExtension: "json") else {
            throw GameDataError.missingFile(name)
        }
        do {
            return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
        } catch {
            throw GameDataError.decodingFailed(file: name, message: String(describing: error))
        }
    }

    /// Unresolved id references and duplicates. Empty means the data set is consistent.
    func validate() -> [String] {
        var problems = duplicateIds.map { "duplicate id \($0)" }
        for w in weapons.values where items[w.ammoId] == nil {
            problems.append("weapon \(w.id): ammoId \(w.ammoId) not in items")
        }
        for e in enemies.values where lootTables[e.lootTableId] == nil {
            problems.append("enemy \(e.id): lootTableId \(e.lootTableId) not in loot")
        }
        for i in items.values {
            if let w = i.weaponId, weapons[w] == nil { problems.append("item \(i.id): weaponId \(w) not in weapons") }
            if let a = i.ammoId, items[a] == nil { problems.append("item \(i.id): ammoId \(a) not in items") }
        }
        for t in lootTables.values {
            for e in t.entries where items[e.itemId] == nil { problems.append("loot \(t.id): item \(e.itemId) unknown") }
            for g in t.guaranteed where items[g.itemId] == nil { problems.append("loot \(t.id): item \(g.itemId) unknown") }
        }
        if weapons[hero.startLoadout.weaponId] == nil {
            problems.append("hero startLoadout.weaponId \(hero.startLoadout.weaponId) not in weapons")
        }
        if items[LootRoller.boltItemId] == nil { problems.append("items lacks \(LootRoller.boltItemId)") }
        return problems.sorted()
    }

    /// Weapon that fires the given ammo item (`ammo_spread` → `blaster_spread`).
    func weapon(forAmmo ammoId: String) -> WeaponDef? {
        weapons.values.first { $0.ammoId == ammoId }
    }
}
