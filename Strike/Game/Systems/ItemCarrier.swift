import Foundation

/// Anything that holds items the puzzle can ask for (DECISIONS: `PuzzleBag` in M2, the M3
/// `Inventory` conforms to the same protocol and replaces it).
nonisolated protocol ItemCarrier {
    func count(of itemId: String) -> Int
    /// Adds up to `count` items; returns how many did not fit (overflow).
    mutating func add(_ itemId: String, count: Int) -> Int
    /// Removes `count` items if that many are held; otherwise removes nothing and returns false.
    mutating func remove(_ itemId: String, count: Int) -> Bool
}

/// Minimal M2 carrier for puzzle items (fuse, battery, keycard, energycore). One stack per item
/// id, capped at the item's `stackSize` from `items.json`.
nonisolated struct PuzzleBag: ItemCarrier, Sendable, Equatable {
    private(set) var counts: [String: Int] = [:]
    /// Max per item id; ids without an entry (or with 0) cannot be stored.
    let capacity: [String: Int]

    init(capacity: [String: Int]) {
        self.capacity = capacity
    }

    /// Capacity from the `puzzle` items of `items.json`.
    init(items: [String: ItemDef]) {
        self.init(capacity: items.values.filter { $0.category == .puzzle }
            .reduce(into: [:]) { $0[$1.id] = $1.stackSize })
    }

    func count(of itemId: String) -> Int { counts[itemId, default: 0] }

    mutating func add(_ itemId: String, count: Int) -> Int {
        guard count > 0 else { return 0 }
        let cap = max(0, capacity[itemId] ?? 0)
        let have = counts[itemId, default: 0]
        let fit = min(count, max(0, cap - have))
        if fit > 0 { counts[itemId] = have + fit }
        return count - fit
    }

    mutating func remove(_ itemId: String, count: Int) -> Bool {
        guard count > 0 else { return true }
        let have = counts[itemId, default: 0]
        guard have >= count else { return false }
        counts[itemId] = have - count == 0 ? nil : have - count
        return true
    }

    /// Non-empty stacks, sorted by id (HUD key chips).
    var carried: [(itemId: String, count: Int)] { counts.sorted { $0.key < $1.key }.map { ($0.key, $0.value) } }
}
