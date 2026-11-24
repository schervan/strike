import Testing
@testable import Strike

struct ItemUseTests {
    static var data: GameData { GeneratedCorpus.data }

    struct Rig {
        var inv = Inventory(items: ItemUseTests.data.items, rules: ItemUseTests.data.rules.inventory)
        var hp = Health(max: ItemUseTests.data.hero.maxHp)
        var loadout = Loadout(start: ItemUseTests.data.hero.startLoadout, weapons: ItemUseTests.data.weapons)
        var cd = UseCooldowns(cooldownSec: ItemUseTests.data.rules.inventory.useCooldownSec)

        mutating func use(_ id: String, at now: Double) -> UseResult {
            ItemUse.use(itemId: id, slot: nil, inventory: &inv, health: &hp, loadout: &loadout, cooldowns: &cd, now: now)
        }

        mutating func useSlot(_ slot: Int, at now: Double) -> UseResult {
            ItemUse.useSlot(slot, inventory: &inv, health: &hp, loadout: &loadout, cooldowns: &cd, now: now)
        }
    }

    @Test func healIsRefusedAtFullHpAndCappedAtMax() {
        var r = Rig()
        _ = r.inv.add("healpack", count: 2)
        do { let v = r.use("healpack", at: 0); #expect(v == .alreadyFull) }
        #expect(r.inv.count(of: "healpack") == 2)                   // nothing consumed
        _ = r.hp.applyDamage(20)                                     // 80 / 100
        do { let v = r.use("healpack", at: 1); #expect(v == .used(heal: 20, ammo: nil)) }   // +50 capped at max
        #expect(r.hp.current == r.hp.max)
        #expect(r.inv.count(of: "healpack") == 1)
    }

    @Test func secondUseOfTheSameItemInsideTheCooldownIsCoolingDown() {
        var r = Rig()
        _ = r.inv.add("food_apple", count: 3)
        _ = r.inv.add("food_cookie", count: 1)
        _ = r.hp.applyDamage(90)
        do { let v = r.use("food_apple", at: 10); #expect(v == .used(heal: 10, ammo: nil)) }
        do { let v = r.use("food_apple", at: 10.3); #expect(v == .coolingDown) }
        #expect(r.inv.count(of: "food_apple") == 2)
        do { let v = r.use("food_cookie", at: 10.3); #expect(v == .used(heal: 15, ammo: nil)) }   // other id: allowed
        do { let v = r.use("food_apple", at: 10.5); #expect(v == .used(heal: 10, ammo: nil)) }    // 0.5 s later
        #expect(abs(r.cd.remaining("food_apple", now: 10.75) - 0.25) < 1e-9)
    }

    @Test func ammoPackAddsItsAmountToTheMatchingReserve() throws {
        var r = Rig()
        let pack = try #require(Self.data.items["ammo_spread"])
        _ = r.inv.add("ammo_spread", count: 1)
        let before = r.loadout.ammo.reserve("ammo_spread")
        do { let v = r.use("ammo_spread", at: 0); #expect(v == .used(heal: 0, ammo: AmmoGain(ammoId: "ammo_spread", amount: pack.ammoAmount!))) }
        #expect(r.loadout.ammo.reserve("ammo_spread") == before + pack.ammoAmount!)
        #expect(r.inv.count(of: "ammo_spread") == 0)
        // Full reserve: refused, pack kept.
        r.loadout.ammo.set("ammo_starter", 1_000)
        _ = r.inv.add("ammo_starter", count: 1)
        do { let v = r.use("ammo_starter", at: 5); #expect(v == .alreadyFull) }
        #expect(r.inv.count(of: "ammo_starter") == 1)
    }

    @Test func puzzleItemsAreNeverUsedFromTheBag() {
        var r = Rig()
        _ = r.inv.add("fuse", count: 1)
        _ = r.hp.applyDamage(50)
        do { let v = r.use("fuse", at: 0); #expect(v == .notUsable) }
        do { let v = r.useSlot(0, at: 0); #expect(v == .notUsable) }
        #expect(r.inv.count(of: "fuse") == 1)
        do { let v = r.useSlot(5, at: 0); #expect(v == .none) }
        do { let v = r.use("healpack", at: 0); #expect(v == .none) }
    }

    @Test func useSlotTakesFromThatSlot() {
        var r = Rig()
        _ = r.inv.add("food_apple", count: 12)                      // slot 0: 10, slot 1: 2
        _ = r.hp.applyDamage(50)
        do { let v = r.useSlot(1, at: 0); #expect(v == .used(heal: 10, ammo: nil)) }
        #expect(r.inv.slots[0]?.count == 10)
        #expect(r.inv.slots[1]?.count == 1)
    }
}
