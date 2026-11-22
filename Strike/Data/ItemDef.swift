import Foundation

nonisolated enum ItemCategory: String, Codable, Sendable, CaseIterable {
    case heal, food, ammo, puzzle, collectible, weapon
}

/// One item from `items.json` (GDD §16.3).
nonisolated struct ItemDef: Codable, Sendable, Equatable, Identifiable {
    let id: String
    let nameKey: String
    let descKey: String
    let category: ItemCategory
    let stackSize: Int
    let storesInInventory: Bool
    let usable: Bool
    let droppable: Bool
    let healAmount: Int?
    let ammoId: String?
    let ammoAmount: Int?
    let weaponId: String?
    let scoreValue: Int?
    let magnet: Bool?

    /// Pickup texture in the `items` atlas (ART_BIBLE §6).
    var pickupTextureName: String { "pickup_\(id)" }
    var isMagnetic: Bool { magnet ?? false }
}

nonisolated struct ItemsFile: Codable, Sendable {
    let version: Int
    let items: [ItemDef]
}
