import Foundation
import Testing
@testable import Strike

struct InventoryTests {
    static var data: GameData { GeneratedCorpus.data }

    static func empty() -> Inventory {
        Inventory(items: data.items, rules: data.rules.inventory)
    }

    // MARK: Storage

    @Test func rulesComeFromRulesJSON() {
        let r = Self.data.rules.inventory
        #expect(r.slots == 25 && r.quickSlots == 4 && r.useCooldownSec == 0.5)
        let inv = Self.empty()
        #expect(inv.slotCount == 25 && inv.quickCount == 4)
    }

    @Test func stacksFillUpToStackSizeThenANewSlot() {
        var inv = Self.empty()
        let size = Self.data.items["food_apple"]!.stackSize   // 10
        do { let v = inv.add("food_apple", count: size - 3); #expect(v == 0) }
        #expect(inv.usedSlots == 1)
        do { let v = inv.add("food_apple", count: 5); #expect(v == 0) }          // 3 top up the first stack, 2 start slot 2
        #expect(inv.slots[0] == ItemStack(itemId: "food_apple", count: size))
        #expect(inv.slots[1] == ItemStack(itemId: "food_apple", count: 2))
        #expect(inv.count(of: "food_apple") == size + 2)
        // A gap is filled first (first empty slot).
        do { let v = inv.add("fuse", count: 1); #expect(v == 0) }
        _ = inv.drop(slot: 1, count: 2)
        do { let v = inv.add("healpack", count: 1); #expect(v == 0) }
        #expect(inv.slots[1]?.itemId == "healpack")
    }

    @Test func the26thDistinctStackIsRejectedAndOverflowReturned() {
        var inv = Self.empty()
        // 25 full healpack stacks (stackSize 5).
        do { let v = inv.add("healpack", count: 25 * 5); #expect(v == 0) }
        #expect(inv.freeSlots == 0)
        do { let v = inv.add("food_apple", count: 3); #expect(v == 3) }
        do { let v = inv.add("healpack", count: 2); #expect(v == 2) }
        #expect(inv.count(of: "food_apple") == 0)

        var mixed = Self.empty()
        do { let v = mixed.add("food_cookie", count: 24 * 10); #expect(v == 0) }
        do { let v = mixed.add("fuse", count: 5); #expect(v == 2) }                 // 3 fit in the last slot
        #expect(mixed.count(of: "fuse") == 3)
        do { let ok = !mixed.addAll("battery", count: 1); #expect(ok) }
        #expect(mixed.count(of: "battery") == 0)
    }

    @Test func nonInventoryItemsAreRejected() {
        var inv = Self.empty()
        for id in ["bolt", "datachip", "blaster_starter", "blaster_spread", "blaster_rapid", "unknown"] {
            do { let v = inv.add(id, count: 1); #expect(v == 1, "\(id)") }
            #expect(!inv.canStore(id), "\(id)")
            do { let ok = !inv.assignQuick(itemId: id, to: 2); #expect(ok, "\(id)") }
        }
        #expect(inv.isEmpty)
    }

    // MARK: Quick slots

    @Test func quickSlotShowsTotalStaysLinkedAtZeroAndUsesTheFirstStack() {
        var inv = Self.empty()
        _ = inv.add("food_apple", count: 12)                     // 10 + 2
        #expect(inv.quickItem(1) == "food_apple")                  // auto-assign Q2
        #expect(inv.quickCount(1) == 12)
        var hp = Health(max: 100)
        _ = hp.applyDamage(90)
        var loadout = Loadout(start: Self.data.hero.startLoadout, weapons: Self.data.weapons)
        var cd = UseCooldowns(cooldownSec: 0.5)
        let r = ItemUse.useQuick(1, inventory: &inv, health: &hp, loadout: &loadout, cooldowns: &cd, now: 0)
        #expect(r == .used(heal: 10, ammo: nil))
        #expect(inv.slots[0]?.count == 9)                          // first stack
        #expect(inv.slots[1]?.count == 2)
        do { let ok = inv.remove("food_apple", count: 11); #expect(ok) }
        #expect(inv.quickCount(1) == 0)
        #expect(inv.quickItem(1) == "food_apple")                  // link stays at 0
        let none = ItemUse.useQuick(1, inventory: &inv, health: &hp, loadout: &loadout, cooldowns: &cd, now: 5)
        #expect(none == .none)
        _ = inv.add("food_apple", count: 1)
        #expect(inv.quickCount(1) == 1)
    }

    @Test func autoAssignFirstHealToQ1FirstFoodToQ2OnlyIntoEmptySlots() {
        var inv = Self.empty()
        _ = inv.add("ammo_starter", count: 1)
        _ = inv.add("fuse", count: 1)
        #expect(inv.quick == [nil, nil, nil, nil])                 // ammo/puzzle: no auto-assign
        _ = inv.add("food_cookie", count: 1)
        _ = inv.add("healpack", count: 1)
        #expect(inv.quick == ["healpack", "food_cookie", nil, nil])
        _ = inv.add("food_apple", count: 1)                        // Q2 taken: stays
        #expect(inv.quickItem(1) == "food_cookie")

        var manual = Self.empty()
        do { let ok = manual.assignQuick(itemId: "food_onigiri", to: 0); #expect(ok) }
        _ = manual.add("healpack", count: 1)                       // Q1 taken by the kid's choice
        #expect(manual.quick == ["food_onigiri", nil, nil, nil])
        _ = manual.add("food_onigiri", count: 1)                   // already linked: no second link
        #expect(manual.quick == ["food_onigiri", nil, nil, nil])
    }

    @Test func assignQuickMovesALinkAndClears() {
        var inv = Self.empty()
        _ = inv.add("healpack", count: 2)
        #expect(inv.quickItem(0) == "healpack")
        do { let ok = inv.assignQuick(itemId: "healpack", to: 3); #expect(ok) }
        #expect(inv.quick == [nil, nil, nil, "healpack"])
        do { let ok = inv.assignQuick(itemId: nil, to: 3); #expect(ok) }
        #expect(inv.quick == [nil, nil, nil, nil])
        do { let ok = !inv.assignQuick(itemId: "healpack", to: 4); #expect(ok) }
    }

    // MARK: Drop and tidy

    @Test func dropReturnsTheStack() {
        var inv = Self.empty()
        _ = inv.add("battery", count: 3)
        do { let v = inv.drop(slot: 0, count: 1); #expect(v == ItemStack(itemId: "battery", count: 1)) }
        #expect(inv.count(of: "battery") == 2)
        do { let v = inv.drop(slot: 0, count: 99); #expect(v == ItemStack(itemId: "battery", count: 2)) }   // "all"
        #expect(inv.slots[0] == nil)
        do { let v = inv.drop(slot: 0, count: 1); #expect(v == nil) }
        do { let v = inv.drop(slot: 30, count: 1); #expect(v == nil) }
    }

    @Test func tidyOrderIsPuzzleHealFoodAmmoThenIdAndMergesStacks() {
        var inv = Self.empty()
        _ = inv.add("ammo_spread", count: 1)
        _ = inv.add("food_cookie", count: 10)
        _ = inv.add("keycard", count: 1)
        _ = inv.add("food_apple", count: 3)
        _ = inv.add("healpack", count: 2)
        _ = inv.add("ammo_rapid", count: 1)
        _ = inv.add("battery", count: 1)
        // Cookies in two partial stacks (slots 1 and 7): 6 + 3.
        _ = inv.add("food_cookie", count: 3)
        _ = inv.drop(slot: 1, count: 4)
        #expect(inv.slots[7] == ItemStack(itemId: "food_cookie", count: 3))
        let quickBefore = inv.quick
        inv.tidy()
        let order = inv.slots.compactMap { $0 }
        #expect(order.map(\.itemId) == ["battery", "keycard", "healpack", "food_apple", "food_cookie",
                                        "ammo_rapid", "ammo_spread"])
        #expect(order.first { $0.itemId == "food_cookie" }?.count == 9)
        #expect(inv.slots[7...].allSatisfy { $0 == nil })
        #expect(inv.quick == quickBefore)
        #expect(inv.totals == ["battery": 1, "keycard": 1, "healpack": 2, "food_apple": 3, "food_cookie": 9,
                               "ammo_rapid": 1, "ammo_spread": 1])
    }

    @Test func puzzleItemsAreClearedByCategory() {
        var inv = Self.empty()
        _ = inv.add("fuse", count: 2)
        _ = inv.add("healpack", count: 1)
        inv.removeAll(category: .puzzle)
        #expect(inv.count(of: "fuse") == 0)
        #expect(inv.count(of: "healpack") == 1)
        #expect(inv.totals(in: .puzzle).isEmpty)
    }

    // MARK: ItemCarrier (M2 machines)

    @Test func machineConsumesFromTheInventoryCarrier() {
        var s = PuzzleStateTests.state()
        var inv = Self.empty()
        do { let v = s.interact("machine_0", carrier: &inv); #expect(v == .needsItem("fuse")) }
        _ = inv.add("fuse", count: 2)
        do { let v = s.interact("machine_0", carrier: &inv); #expect(v == .activated) }
        #expect(inv.count(of: "fuse") == 1)
        #expect(inv.totals(in: .puzzle) == ["fuse": 1])
    }

    // MARK: Binding after load

    @Test func bindPadsDropsUnknownAndSplitsOversizedStacks() throws {
        let json = #"{"slots":[{"itemId":"healpack","count":7},{"itemId":"gone_item","count":1},null],"quick":["healpack","gone_item"]}"#
        var inv = try JSONDecoder().decode(Inventory.self, from: Data(json.utf8))
        inv.bind(items: Self.data.items, rules: Self.data.rules.inventory)
        #expect(inv.slotCount == 25 && inv.quickCount == 4)
        #expect(inv.slots[0] == ItemStack(itemId: "healpack", count: 5))
        #expect(inv.slots[1] == ItemStack(itemId: "healpack", count: 2))
        #expect(inv.count(of: "gone_item") == 0)
        #expect(inv.quick == ["healpack", nil, nil, nil])
    }
}
