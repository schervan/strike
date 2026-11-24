import Foundation

nonisolated enum PickupOutcome: Sendable, Equatable {
    /// Heal, food or puzzle item went into the bag.
    case stored
    /// Ammo went into its reserve; `overflowPacks` ammo-pack items went into the bag for the rest.
    case reserve(overflowPacks: Int)
    /// Bolts and other score collectibles: add this to the score.
    case score(Int)
    /// Count it in `LevelSession.collectDatachip` (which adds the item's `scoreValue`).
    case datachip
    /// Nothing changed: the pickup stays on the floor with the "!" marker.
    case staysBagFull
    /// A blaster pickup (GDD §5): `added` = new blaster with one full magazine (not equipped);
    /// otherwise it was already owned and one magazine of its ammo went to the reserve
    /// (`overflowPacks` ammo packs into the bag for the rest).
    case weapon(id: String, added: Bool, overflowPacks: Int)
}

/// What happens when the hero walks over a pickup (GDD §5.1, §6, §7). Pure: the scene applies
/// the outcome (score, toast, sound, removing the node).
nonisolated enum PickupResolver {
    /// `weapons` is needed for blaster pickups (magazine size, ammo type).
    static func resolve(_ item: ItemDef, count: Int = 1, inventory: inout Inventory,
                        loadout: inout Loadout, weapons: [String: WeaponDef] = [:]) -> PickupOutcome {
        let count = max(1, count)
        switch item.category {
        case .collectible:
            if item.id == LevelGenerator.datachipItemId { return .datachip }
            return .score((item.scoreValue ?? 0) * count)
        case .weapon:
            return weapon(item, inventory: &inventory, loadout: &loadout, weapons: weapons)
        case .ammo:
            guard let ammoId = item.ammoId, let perPack = item.ammoAmount, perPack > 0 else {
                return store(item, count, &inventory)
            }
            // Fill the reserve; what is left over becomes ammo packs (rounded up) if they fit,
            // otherwise nothing is taken and the pickup stays on the floor.
            let amount = perPack * count
            let overflow = max(0, amount - loadout.ammo.space(ammoId))
            let packs = (overflow + perPack - 1) / perPack
            if packs > 0 {
                guard inventory.addAll(item.id, count: packs) else { return .staysBagFull }
            }
            loadout.ammo.add(ammoId, amount: amount)
            return .reserve(overflowPacks: packs)
        case .heal, .food, .puzzle:
            return store(item, count, &inventory)
        }
    }

    private static func weapon(_ item: ItemDef, inventory: inout Inventory, loadout: inout Loadout,
                               weapons: [String: WeaponDef]) -> PickupOutcome {
        let id = item.weaponId ?? item.id
        guard let w = weapons[id] else { return .weapon(id: id, added: false, overflowPacks: 0) }
        if loadout.addWeapon(w) { return .weapon(id: id, added: true, overflowPacks: 0) }
        // Already owned (replay): one magazine of its ammo, overflow as ammo packs if they fit.
        let amount = w.magazineSize
        let overflow = max(0, amount - loadout.ammo.space(w.ammoId))
        var packs = 0
        if overflow > 0, let pack = inventory.catalog[w.ammoId], let per = pack.ammoAmount, per > 0 {
            packs = (overflow + per - 1) / per
            guard inventory.addAll(pack.id, count: packs) else { return .staysBagFull }
        }
        loadout.ammo.add(w.ammoId, amount: amount)
        return .weapon(id: id, added: false, overflowPacks: packs)
    }

    private static func store(_ item: ItemDef, _ count: Int, _ inventory: inout Inventory) -> PickupOutcome {
        inventory.addAll(item.id, count: count) ? .stored : .staysBagFull
    }
}
