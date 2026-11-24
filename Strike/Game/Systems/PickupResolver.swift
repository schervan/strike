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
    /// Blasters become real pickups in M4.
    case weaponPlaceholder
}

/// What happens when the hero walks over a pickup (GDD §5.1, §6, §7). Pure: the scene applies
/// the outcome (score, toast, sound, removing the node).
nonisolated enum PickupResolver {
    static func resolve(_ item: ItemDef, count: Int = 1, inventory: inout Inventory,
                        loadout: inout Loadout) -> PickupOutcome {
        let count = max(1, count)
        switch item.category {
        case .collectible:
            if item.id == LevelGenerator.datachipItemId { return .datachip }
            return .score((item.scoreValue ?? 0) * count)
        case .weapon:
            return .weaponPlaceholder
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

    private static func store(_ item: ItemDef, _ count: Int, _ inventory: inout Inventory) -> PickupOutcome {
        inventory.addAll(item.id, count: count) ? .stored : .staysBagFull
    }
}
