import Foundation
import GameplayKit

nonisolated struct LootDrop: Sendable, Equatable, Hashable {
    let itemId: String
    let count: Int
}

/// Hero situation used by the loot helper modifiers (GDD §10 step 4).
nonisolated struct LootContext: Sendable, Equatable {
    /// 1-based level number.
    var level: Int
    /// current / max HP, 0…1.
    var heroHpRatio: Double
    /// Currently equipped blaster id.
    var equippedWeaponId: String
    /// (mag + reserve) / (magazineSize + reserveMax) of the equipped blaster, 0…1.
    var equippedAmmoRatio: Double
    var ownedWeaponIds: Set<String>
}

/// Rolls a loot table (GDD §10 steps 1–4). Deterministic for a seeded `GKRandom`.
nonisolated enum LootRoller {
    /// Item id of the auto-spawned score pickup (step 1).
    static let boltItemId = "bolt"

    static func roll(tableId: String, data: GameData, context: LootContext, random: GKRandom) -> [LootDrop] {
        guard let table = data.lootTables[tableId] else { return [] }
        return roll(table: table, modifiers: data.lootModifiers, items: data.items,
                    weapons: data.weapons, context: context, random: random)
    }

    static func roll(
        table: LootTable,
        modifiers: [LootModifier],
        items: [String: ItemDef],
        weapons: [String: WeaponDef],
        context: LootContext,
        random: GKRandom
    ) -> [LootDrop] {
        var drops: [LootDrop] = []

        // 1. Bolts.
        let bolts = randomInt(table.boltsMin, table.boltsMax, random)
        if bolts > 0 { drops.append(LootDrop(itemId: boltItemId, count: bolts)) }

        // 2. Guaranteed.
        for g in table.guaranteed where g.count > 0 {
            drops.append(LootDrop(itemId: g.itemId, count: g.count))
        }

        // 4. Modifiers change weights before the rolls.
        let weighted = table.entries.map { entry in
            (entry, entry.weight * multiplier(for: entry.itemId, modifiers: modifiers, items: items,
                                              weapons: weapons, context: context))
        }.filter { $0.1 > 0 }
        let total = weighted.reduce(0) { $0 + $1.1 }

        // 3. Rolls.
        guard total > 0 else { return drops }
        for _ in 0..<max(0, table.rolls) {
            guard Double(random.nextUniform()) < table.dropChance else { continue }
            var pick = Double(random.nextUniform()) * total
            var chosen = weighted[weighted.count - 1].0
            for (entry, w) in weighted {
                if pick < w { chosen = entry; break }
                pick -= w
            }
            let count = randomInt(chosen.min, chosen.max, random)
            if count > 0 { drops.append(LootDrop(itemId: chosen.itemId, count: count)) }
        }
        return drops
    }

    /// Product of every modifier that applies to `itemId` in the given context.
    static func multiplier(
        for itemId: String,
        modifiers: [LootModifier],
        items: [String: ItemDef],
        weapons: [String: WeaponDef],
        context: LootContext
    ) -> Double {
        guard let item = items[itemId] else { return 1 }
        var m = 1.0
        for mod in modifiers {
            guard let condition = mod.knownCondition else { continue }
            let applies: Bool
            switch condition {
            case .heroHpRatioBelow:
                applies = context.heroHpRatio <= (mod.threshold ?? 0) && matches(item, mod.appliesTo, weapons, context)
            case .equippedAmmoRatioBelow:
                applies = context.equippedAmmoRatio <= (mod.threshold ?? 0) && matches(item, mod.appliesTo, weapons, context)
            case .weaponNotOwned:
                applies = matches(item, mod.appliesTo, weapons, context)
            }
            if applies { m *= mod.weightMultiplier }
        }
        return m
    }

    /// `appliesTo` selector: `category:a,b` / `equippedAmmo` / `unownedAmmo`.
    static func matches(_ item: ItemDef, _ selector: String, _ weapons: [String: WeaponDef], _ context: LootContext) -> Bool {
        if selector.hasPrefix("category:") {
            let cats = selector.dropFirst("category:".count).split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
            return cats.contains(item.category.rawValue)
        }
        switch selector {
        case "equippedAmmo":
            guard item.category == .ammo, let ammo = item.ammoId,
                  let equipped = weapons[context.equippedWeaponId] else { return false }
            return ammo == equipped.ammoId
        case "unownedAmmo":
            guard item.category == .ammo, let ammo = item.ammoId,
                  let weapon = weapons.values.first(where: { $0.ammoId == ammo }) else { return false }
            // GDD §10: ammo for blasters not owned yet is suppressed, except in levels ≥ unlock level.
            return !context.ownedWeaponIds.contains(weapon.id) && context.level < weapon.unlockLevel
        default:
            return false
        }
    }

    private static func randomInt(_ lo: Int, _ hi: Int, _ random: GKRandom) -> Int {
        guard hi > lo else { return lo }
        return lo + random.nextInt(upperBound: hi - lo + 1)
    }
}
