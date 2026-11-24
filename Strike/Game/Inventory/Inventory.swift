import Foundation

/// The hero's bag (GDD §7): `slots` (25) of `ItemStack?` plus quick links (4). A quick slot links
/// to an item **id**, not a slot, and shows the total count of that id; it stays linked at 0.
///
/// Item rules (`stackSize`, `storesInInventory`, `droppable`, category) come from `items.json` via
/// `catalog`. The catalog is not saved: after decoding, call `bind(items:rules:)` (RunState does).
/// Replaces the M2 `PuzzleBag` behind `ItemCarrier`.
nonisolated struct Inventory: ItemCarrier, Codable, Sendable, Equatable {
    private(set) var slots: [ItemStack?]
    /// Item id per quick slot (Q1…Q4).
    private(set) var quick: [String?]
    /// Item definitions by id (not encoded).
    private(set) var catalog: [String: ItemDef] = [:]

    enum CodingKeys: String, CodingKey {
        case slots, quick
    }

    /// Tolerant decoding (GDD §16.10): missing arrays are empty; `bind` pads them to the rules'
    /// sizes and drops unknown item ids.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        slots = try c.decodeIfPresent([ItemStack?].self, forKey: .slots) ?? []
        quick = try c.decodeIfPresent([String?].self, forKey: .quick) ?? []
    }

    /// GDD §7 tidy order: puzzle → heal → food → ammo, then everything else.
    static let tidyOrder: [ItemCategory] = [.puzzle, .heal, .food, .ammo]
    /// Auto-assign targets: first heal → Q1, first food → Q2.
    static let autoAssign: [ItemCategory: Int] = [.heal: 0, .food: 1]

    init(items: [String: ItemDef], slotCount: Int, quickCount: Int) {
        catalog = items
        slots = Array(repeating: nil, count: max(0, slotCount))
        quick = Array(repeating: nil, count: max(0, quickCount))
    }

    init(items: [String: ItemDef], rules: InventoryRulesDef) {
        self.init(items: items, slotCount: rules.slots, quickCount: rules.quickSlots)
    }

    /// Content equality (the catalog is configuration, not state).
    static func == (a: Inventory, b: Inventory) -> Bool {
        a.slots == b.slots && a.quick == b.quick
    }

    // MARK: Queries

    var slotCount: Int { slots.count }
    var quickCount: Int { quick.count }
    var usedSlots: Int { slots.reduce(0) { $0 + ($1 == nil ? 0 : 1) } }
    var freeSlots: Int { slotCount - usedSlots }
    var isEmpty: Bool { usedSlots == 0 }

    /// True when the item can live in the bag at all (bolts, datachips and blasters cannot).
    func canStore(_ itemId: String) -> Bool {
        guard let d = catalog[itemId] else { return false }
        return d.storesInInventory && d.stackSize > 0
    }

    func stackSize(of itemId: String) -> Int { max(0, catalog[itemId]?.stackSize ?? 0) }

    func count(of itemId: String) -> Int {
        slots.reduce(0) { $0 + ($1?.itemId == itemId ? $1!.count : 0) }
    }

    /// How many more of `itemId` fit (partial stacks plus empty slots).
    func space(for itemId: String) -> Int {
        guard canStore(itemId) else { return 0 }
        let size = stackSize(of: itemId)
        return slots.reduce(0) { sum, s in
            guard let s else { return sum + size }
            return s.itemId == itemId ? sum + max(0, size - s.count) : sum
        }
    }

    /// Total per item id.
    var totals: [String: Int] {
        slots.reduce(into: [:]) { if let s = $1 { $0[s.itemId, default: 0] += s.count } }
    }

    /// Totals of one category (HUD key chips use `.puzzle`).
    func totals(in category: ItemCategory) -> [String: Int] {
        totals.filter { catalog[$0.key]?.category == category }
    }

    func quickItem(_ index: Int) -> String? {
        quick.indices.contains(index) ? quick[index] : nil
    }

    /// Total count of the item linked to quick slot `index` (0 when unlinked or used up).
    func quickCount(_ index: Int) -> Int {
        quickItem(index).map { count(of: $0) } ?? 0
    }

    // MARK: ItemCarrier

    /// Fills existing stacks of `itemId` up to `stackSize`, then the first empty slots. Returns what
    /// did not fit. Items that do not store in the bag are rejected whole.
    mutating func add(_ itemId: String, count: Int) -> Int {
        guard count > 0 else { return 0 }
        guard canStore(itemId) else { return count }
        let size = stackSize(of: itemId)
        var left = count
        for i in slots.indices where left > 0 {
            guard var s = slots[i], s.itemId == itemId, s.count < size else { continue }
            let n = min(left, size - s.count)
            s.count += n
            slots[i] = s
            left -= n
        }
        for i in slots.indices where left > 0 && slots[i] == nil {
            let n = min(left, size)
            slots[i] = ItemStack(itemId: itemId, count: n)
            left -= n
        }
        if left < count { autoAssignIfNeeded(itemId) }
        return left
    }

    /// Adds all `count` items or nothing. Returns true when everything was stored.
    mutating func addAll(_ itemId: String, count: Int) -> Bool {
        guard count > 0 else { return true }
        guard space(for: itemId) >= count else { return false }
        return add(itemId, count: count) == 0
    }

    /// Removes `count` items, taking from the first stacks in slot order. All or nothing.
    mutating func remove(_ itemId: String, count: Int) -> Bool {
        guard count > 0 else { return true }
        guard self.count(of: itemId) >= count else { return false }
        var left = count
        for i in slots.indices where left > 0 {
            guard var s = slots[i], s.itemId == itemId else { continue }
            let n = min(left, s.count)
            s.count -= n
            left -= n
            slots[i] = s.count > 0 ? s : nil
        }
        return true
    }

    // MARK: Slot actions

    /// Removes `count` from one slot (inventory "Use" on a chosen slot). All or nothing.
    mutating func remove(slot: Int, count: Int) -> Bool {
        guard count > 0 else { return true }
        guard slots.indices.contains(slot), var s = slots[slot], s.count >= count else { return false }
        s.count -= count
        slots[slot] = s.count > 0 ? s : nil
        return true
    }

    /// Takes up to `count` items out of `slot` to drop them at the hero's feet. Nil for an empty
    /// slot or an item that is not droppable.
    mutating func drop(slot: Int, count: Int) -> ItemStack? {
        guard count > 0, slots.indices.contains(slot), var s = slots[slot] else { return nil }
        guard catalog[s.itemId]?.droppable ?? true else { return nil }
        let n = min(count, s.count)
        s.count -= n
        slots[slot] = s.count > 0 ? s : nil
        return ItemStack(itemId: s.itemId, count: n)
    }

    /// Links quick slot `index` to `itemId` (nil clears it). An id is linked to at most one quick
    /// slot: assigning it elsewhere moves the link. Returns false for a bad index or an id that
    /// cannot live in the bag.
    @discardableResult
    mutating func assignQuick(itemId: String?, to index: Int) -> Bool {
        guard quick.indices.contains(index) else { return false }
        if let id = itemId {
            guard canStore(id) else { return false }
            for i in quick.indices where quick[i] == id { quick[i] = nil }
        }
        quick[index] = itemId
        return true
    }

    /// "Tidy up": merges stacks of the same id, then sorts puzzle → heal → food → ammo, then by id.
    /// Items no longer in the catalog keep their stacks and go last.
    mutating func tidy() {
        var totals: [String: Int] = [:]
        var unknown: [ItemStack] = []
        for s in slots.compactMap({ $0 }) {
            if canStore(s.itemId) { totals[s.itemId, default: 0] += s.count } else { unknown.append(s) }
        }
        let ids = totals.keys.sorted { a, b in
            let ra = rank(a), rb = rank(b)
            return ra != rb ? ra < rb : a < b
        }
        var out: [ItemStack] = []
        for id in ids {
            var left = totals[id]!
            let size = stackSize(of: id)
            while left > 0 {
                let n = min(left, size)
                out.append(ItemStack(itemId: id, count: n))
                left -= n
            }
        }
        out += unknown
        slots = (0..<slotCount).map { $0 < out.count ? out[$0] : nil }
    }

    private func rank(_ itemId: String) -> Int {
        guard let c = catalog[itemId]?.category, let i = Self.tidyOrder.firstIndex(of: c) else {
            return Self.tidyOrder.count
        }
        return i
    }

    private mutating func autoAssignIfNeeded(_ itemId: String) {
        guard let c = catalog[itemId]?.category, let q = Self.autoAssign[c], quick.indices.contains(q),
              quick[q] == nil, !quick.contains(itemId) else { return }
        quick[q] = itemId
    }

    // MARK: Binding after load

    /// Attaches the item catalog after decoding and repairs the content against it: the slot and
    /// quick counts follow `rules`, stacks above a (lowered) `stackSize` are split, items that no
    /// longer store in the bag are removed, quick links to such items are cleared.
    mutating func bind(items: [String: ItemDef], rules: InventoryRulesDef) {
        catalog = items
        let old = slots.compactMap { $0 }
        slots = Array(repeating: nil, count: max(0, rules.slots))
        for s in old where s.count > 0 { _ = addPreservingQuick(s.itemId, count: s.count) }
        var q = Array(quick.prefix(max(0, rules.quickSlots)))
        q += Array(repeating: nil, count: max(0, rules.quickSlots - q.count))
        quick = q.map { id in id.flatMap { canStore($0) ? $0 : nil } }
    }

    /// Removes every item of a category (puzzle items at level start and end, GDD §16.10).
    /// Quick links stay.
    mutating func removeAll(category: ItemCategory) {
        for i in slots.indices where slots[i].map({ catalog[$0.itemId]?.category == category }) ?? false {
            slots[i] = nil
        }
    }

    private mutating func addPreservingQuick(_ itemId: String, count: Int) -> Int {
        let saved = quick
        let left = add(itemId, count: count)
        quick = saved
        return left
    }
}
