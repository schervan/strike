import Foundation

/// One inventory slot's content: a single item id, `1…stackSize` of it (GDD §7).
nonisolated struct ItemStack: Codable, Sendable, Equatable, Hashable {
    let itemId: String
    var count: Int

    init(itemId: String, count: Int) {
        self.itemId = itemId
        self.count = count
    }
}
