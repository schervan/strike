import Foundation
import os

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

/// All balance data, decoded once from `<bundle>/Data/*.json`.
nonisolated struct GameData: Sendable {
    let weapons: [String: WeaponDef]
    let enemies: [String: EnemyDef]
    let items: [String: ItemDef]
    let lootTables: [String: LootTable]
    let lootModifiers: [LootModifier]
    let hero: HeroDef
    let controls: ControlsDef
    let camera: CameraDef
    /// Levels by id.
    let levels: [String: LevelDef]
    /// Levels ordered by `index` (L1 first).
    let levelOrder: [LevelDef]
    /// `rules.json` (or `RulesDef.fallback` while the file is missing).
    let rules: RulesDef
    /// `audio.json` (or `AudioDef.empty` while the file is missing).
    let audio: AudioDef
    /// Ids that appeared more than once in their file (reported by `validate()`).
    let duplicateIds: [String]

    init(weapons: [WeaponDef], enemies: [EnemyDef], items: [ItemDef], loot: LootFile, hero: HeroFile,
         levels: [LevelDef] = [], rules: RulesDef = .fallback, audio: AudioDef = .empty) {
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
        self.levels = index(levels, "levels")
        self.levelOrder = self.levels.values.sorted { $0.index < $1.index }
        self.rules = rules
        self.audio = audio
        self.duplicateIds = dupes
    }

    static func load(bundle: Bundle = .main) throws -> GameData {
        let weapons: WeaponsFile = try decode("weapons", bundle)
        let enemies: EnemiesFile = try decode("enemies", bundle)
        let items: ItemsFile = try decode("items", bundle)
        let loot: LootFile = try decode("loot", bundle)
        let hero: HeroFile = try decode("hero", bundle)
        let levels: LevelsFile = try decode("levels", bundle)
        return GameData(weapons: weapons.weapons, enemies: enemies.enemies, items: items.items, loot: loot, hero: hero,
                        levels: levels.levels, rules: try loadRules(bundle), audio: try loadAudio(bundle))
    }

    /// `audio.json`, tolerant while the file is missing (silent game). A file that exists but does
    /// not decode still throws.
    static func loadAudio(_ bundle: Bundle) throws -> AudioDef {
        do {
            return try decode("audio", bundle)
        } catch GameDataError.missingFile {
            Logger(subsystem: "io.schervan.strike", category: "data").warning("audio.json missing, audio is silent")
            return .empty
        }
    }

    /// `rules.json`, tolerant while the file is not in the bundle yet (TASKS M2-3): falls back to
    /// `RulesDef.fallback` and logs. A file that exists but does not decode still throws.
    static func loadRules(_ bundle: Bundle) throws -> RulesDef {
        do {
            let file: RulesFile = try decode("rules", bundle)
            return RulesDef(file: file)
        } catch GameDataError.missingFile {
            Logger(subsystem: "io.schervan.strike", category: "data")
                .warning("rules.json missing, using RulesDef.fallback (GDD defaults)")
            return .fallback
        }
    }

    /// Level that follows `id` by index, nil after the last one.
    func level(after id: String) -> LevelDef? {
        guard let i = levelOrder.firstIndex(where: { $0.id == id }), i + 1 < levelOrder.count else { return nil }
        return levelOrder[i + 1]
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
        problems += validateEnemies()
        problems += validateLevels()
        return problems.sorted()
    }

    /// Behaviour blocks (M4): boss phase chain, split / spawn / unlock references.
    func validateEnemies() -> [String] {
        var problems: [String] = []
        for e in enemies.values {
            problems += e.phaseChainProblems
            if let s = e.splitInto {
                if enemies[s.enemyId] == nil { problems.append("enemy \(e.id): splitInto \(s.enemyId) not in enemies") }
                else if enemies[s.enemyId]?.splitInto != nil { problems.append("enemy \(e.id): \(s.enemyId) would split again") }
            }
            for p in e.phases ?? [] {
                if let s = p.spawn {
                    if enemies[s.enemyId] == nil { problems.append("enemy \(e.id) \(p.id): spawn \(s.enemyId) not in enemies") }
                    if let c = s.carryItemFirst, items[c] == nil { problems.append("enemy \(e.id) \(p.id): carry \(c) not in items") }
                }
                if let u = p.unlockBy, items[u.requiresItem] == nil {
                    problems.append("enemy \(e.id) \(p.id): unlockBy \(u.requiresItem) not in items")
                }
            }
        }
        return problems
    }

    /// Level references (enemies, items, loot tables, weapons) and puzzle/zone consistency.
    func validateLevels() -> [String] {
        var problems: [String] = []
        if Set(levelOrder.map(\.index)).count != levelOrder.count { problems.append("levels: duplicate index") }
        for l in levelOrder {
            let g = l.generator
            let p = "level \(l.id)"
            for m in l.enemyMix {
                guard let e = enemies[m.enemyId] else { problems.append("\(p): enemyMix \(m.enemyId) not in enemies"); continue }
                if e.threatCost <= 0 { problems.append("\(p): enemyMix \(m.enemyId) has threatCost 0") }
                if let z = m.zoneMin, z < 1 || z > g.zones { problems.append("\(p): enemyMix \(m.enemyId) zoneMin \(z) out of range") }
            }
            if let f = l.firstEncounterRoom, enemies[f] == nil { problems.append("\(p): firstEncounterRoom \(f) not in enemies") }
            if let b = l.bossId, enemies[b] == nil { problems.append("\(p): bossId \(b) not in enemies") }
            if l.bossId != nil, l.bossArena == nil { problems.append("\(p): bossId without bossArena") }
            for f in l.pickups.fixed ?? [] where items[f.itemId] == nil { problems.append("\(p): fixed \(f.itemId) not in items") }
            for e in l.puzzle.elements {
                if case .index(let z) = e.zone, z < 1 || z > g.zones { problems.append("\(p): element \(e.type) zone \(z) out of range") }
                problems += checkMachineItem(p, e.type, e.requiresItem)
            }
            let gateZones = l.puzzle.gates.map(\.zone)
            if Set(gateZones) != Set(g.zones > 1 ? Array(2...g.zones) : []) || gateZones.count != g.zones - 1 {
                problems.append("\(p): gates \(gateZones) do not cover zones 2…\(g.zones)")
            }
            for gate in l.puzzle.gates {
                if gate.opensWith.isEmpty { problems.append("\(p): gate \(gate.zone) has no elements") }
                for e in gate.opensWith { problems += checkMachineItem(p, e.type, e.requiresItem) }
            }
            for r in l.pickups.perRoom where items[r.itemId] == nil { problems.append("\(p): perRoom \(r.itemId) not in items") }
            for s in l.pickups.startGift ?? [] where items[s.itemId] == nil { problems.append("\(p): startGift \(s.itemId) not in items") }
            if lootTables[l.pickups.crates.lootTableId] == nil { problems.append("\(p): crates \(l.pickups.crates.lootTableId) not in loot") }
            if let w = l.pickups.weaponPickup {
                if weapons[w] == nil { problems.append("\(p): weaponPickup \(w) not in weapons") }
                if items[w] == nil { problems.append("\(p): weaponPickup \(w) has no pickup item") }
            }
            if l.pickups.datachips > 0, items[LevelGenerator.datachipItemId] == nil {
                problems.append("\(p): items lacks \(LevelGenerator.datachipItemId)")
            }
            if g.minRoomSize > g.maxRoomSize || g.roomCount.min > g.roomCount.max || g.zones < 1 || g.corridorWidth < 1 {
                problems.append("\(p): generator ranges inconsistent")
            }
        }
        return problems
    }

    private func checkMachineItem(_ p: String, _ type: ElementType, _ item: String?) -> [String] {
        switch (type, item) {
        case (.machine, nil): return ["\(p): machine without requiresItem"]
        case (.machine, let i?): return items[i] == nil ? ["\(p): requiresItem \(i) not in items"] : []
        case (_, let i?): return ["\(p): \(type) has requiresItem \(i)"]
        default: return []
        }
    }

    /// Weapon that fires the given ammo item (`ammo_spread` → `blaster_spread`).
    func weapon(forAmmo ammoId: String) -> WeaponDef? {
        weapons.values.first { $0.ammoId == ammoId }
    }
}
