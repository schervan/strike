import Foundation

/// Ammo added to a reserve by using an ammo pack.
nonisolated struct AmmoGain: Sendable, Equatable {
    let ammoId: String
    let amount: Int
}

nonisolated enum UseResult: Sendable, Equatable {
    /// One item was consumed. `heal` = HP actually restored, `ammo` = rounds actually added.
    case used(heal: Int, ammo: AmmoGain?)
    /// Full HP (heal/food) or full reserve (ammo pack): nothing consumed, the button shakes.
    case alreadyFull
    /// Same item id used again inside `inventory.useCooldownSec`.
    case coolingDown
    /// Puzzle items and anything else that is not `usable`.
    case notUsable
    /// Nothing to use (empty quick slot, count 0, empty inventory slot).
    case none
}

/// Last use per item id (GDD §6: 0.5 s cooldown per item type). Time-based so the caller picks the
/// clock (game time in play; the inventory screen can pass wall time while the game is paused).
nonisolated struct UseCooldowns: Sendable, Equatable {
    let cooldownSec: Double
    private var lastUse: [String: Double] = [:]

    init(cooldownSec: Double) {
        self.cooldownSec = max(0, cooldownSec)
    }

    func isCoolingDown(_ itemId: String, now: Double) -> Bool { remaining(itemId, now: now) > 0 }

    /// Seconds left (0 when ready); the quick-slot sweep is `remaining / cooldownSec`.
    func remaining(_ itemId: String, now: Double) -> Double {
        guard let t = lastUse[itemId] else { return 0 }
        return max(0, cooldownSec - (now - t))
    }

    mutating func mark(_ itemId: String, now: Double) {
        lastUse[itemId] = now
    }
}

/// GDD §6 use rules: no heal at full HP, heal capped at max, 0.5 s per item id, ammo packs add to
/// the matching reserve, puzzle items are never used from the bag.
nonisolated enum ItemUse {
    /// Quick slot tap: uses the linked item, taking it from the first stack.
    static func useQuick(_ index: Int, inventory: inout Inventory, health: inout Health, loadout: inout Loadout,
                         cooldowns: inout UseCooldowns, now: Double) -> UseResult {
        guard let id = inventory.quickItem(index) else { return .none }
        return use(itemId: id, slot: nil, inventory: &inventory, health: &health, loadout: &loadout,
                   cooldowns: &cooldowns, now: now)
    }

    /// Inventory "Use" on a slot: takes the item from that slot.
    static func useSlot(_ slot: Int, inventory: inout Inventory, health: inout Health, loadout: inout Loadout,
                        cooldowns: inout UseCooldowns, now: Double) -> UseResult {
        guard inventory.slots.indices.contains(slot), let s = inventory.slots[slot] else { return .none }
        return use(itemId: s.itemId, slot: slot, inventory: &inventory, health: &health, loadout: &loadout,
                   cooldowns: &cooldowns, now: now)
    }

    static func use(itemId: String, slot: Int?, inventory: inout Inventory, health: inout Health,
                    loadout: inout Loadout, cooldowns: inout UseCooldowns, now: Double) -> UseResult {
        guard inventory.count(of: itemId) > 0 else { return .none }
        guard let def = inventory.catalog[itemId], def.usable, def.category != .puzzle else { return .notUsable }
        switch def.category {
        case .heal, .food:
            guard let amount = def.healAmount, amount > 0 else { return .notUsable }
            if cooldowns.isCoolingDown(itemId, now: now) { return .coolingDown }
            guard health.current < health.max else { return .alreadyFull }
            guard consume(itemId, slot: slot, &inventory) else { return .none }
            cooldowns.mark(itemId, now: now)
            return .used(heal: health.heal(amount), ammo: nil)
        case .ammo:
            guard let ammoId = def.ammoId, let amount = def.ammoAmount, amount > 0 else { return .notUsable }
            if cooldowns.isCoolingDown(itemId, now: now) { return .coolingDown }
            guard !loadout.ammo.isFull(ammoId) else { return .alreadyFull }
            guard consume(itemId, slot: slot, &inventory) else { return .none }
            cooldowns.mark(itemId, now: now)
            let overflow = loadout.ammo.add(ammoId, amount: amount)
            return .used(heal: 0, ammo: AmmoGain(ammoId: ammoId, amount: amount - overflow))
        case .puzzle, .collectible, .weapon:
            return .notUsable
        }
    }

    private static func consume(_ itemId: String, slot: Int?, _ inventory: inout Inventory) -> Bool {
        if let slot, inventory.remove(slot: slot, count: 1) { return true }
        return inventory.remove(itemId, count: 1)
    }
}
