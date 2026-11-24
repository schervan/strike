import Testing
@testable import Strike

struct PickupResolverTests {
    static var data: GameData { GeneratedCorpus.data }

    struct Rig {
        var inv = Inventory(items: PickupResolverTests.data.items, rules: PickupResolverTests.data.rules.inventory)
        var loadout = Loadout(start: PickupResolverTests.data.hero.startLoadout, weapons: PickupResolverTests.data.weapons)

        mutating func pick(_ id: String, count: Int = 1) -> PickupOutcome {
            PickupResolver.resolve(PickupResolverTests.data.items[id]!, count: count, inventory: &inv, loadout: &loadout,
                                   weapons: PickupResolverTests.data.weapons)
        }
    }

    @Test func boltScoresAndDatachipIsCounted() {
        var r = Rig()
        do { let v = r.pick("bolt"); #expect(v == .score(Self.data.items["bolt"]!.scoreValue!)) }
        do { let v = r.pick("bolt", count: 3); #expect(v == .score(3 * Self.data.items["bolt"]!.scoreValue!)) }
        do { let v = r.pick("datachip"); #expect(v == .datachip) }
        #expect(r.inv.isEmpty)
    }

    @Test func healFoodAndPuzzleGoIntoTheBagOrStayWhenFull() {
        var r = Rig()
        do { let v = r.pick("healpack"); #expect(v == .stored) }
        do { let v = r.pick("food_onigiri"); #expect(v == .stored) }
        do { let v = r.pick("keycard"); #expect(v == .stored) }
        #expect(r.inv.count(of: "keycard") == 1)
        _ = r.inv.add("food_cookie", count: r.inv.freeSlots * 10)
        #expect(r.inv.freeSlots == 0)
        do { let v = r.pick("keycard"); #expect(v == .staysBagFull) }                 // stackSize 1: needs a new slot
        do { let v = r.pick("healpack"); #expect(v == .stored) }                      // tops up the existing stack
        #expect(r.inv.count(of: "keycard") == 1)
    }

    /// M4-4 (GDD §5): the blaster pickup adds the blaster with one full magazine, not equipped.
    @Test func blasterPickupAddsTheBlasterWithAFullMagazine() {
        var r = Rig()
        let w = Self.data.weapons["blaster_spread"]!
        do { let v = r.pick("blaster_spread"); #expect(v == .weapon(id: w.id, added: true, overflowPacks: 0)) }
        #expect(r.loadout.owns(w.id))
        #expect(r.loadout.magazine(w.id) == w.magazineSize)
        #expect(r.loadout.equipped == Self.data.hero.startLoadout.weaponId)
        #expect(r.inv.isEmpty)
    }

    @Test func ammoAboveReserveMaxBecomesPacksWhenASlotIsFree() {
        var r = Rig()
        let max = r.loadout.ammo.cap("ammo_starter")
        r.loadout.ammo.set("ammo_starter", max - 4)
        do { let v = r.pick("ammo_starter"); #expect(v == .reserve(overflowPacks: 1)) }   // 4 fill the reserve, 20 → 1 pack
        #expect(r.loadout.ammo.reserve("ammo_starter") == max)
        #expect(r.inv.count(of: "ammo_starter") == 1)
        do { let v = r.pick("ammo_starter"); #expect(v == .reserve(overflowPacks: 1)) }   // reserve full: whole pack to the bag
        #expect(r.inv.count(of: "ammo_starter") == 2)
    }

    @Test func ammoOverflowWithAFullBagStaysOnTheFloorAndTakesNothing() {
        var r = Rig()
        _ = r.inv.add("food_cookie", count: r.inv.freeSlots * 10)
        let max = r.loadout.ammo.cap("ammo_starter")
        r.loadout.ammo.set("ammo_starter", max - 4)
        do { let v = r.pick("ammo_starter"); #expect(v == .staysBagFull) }
        #expect(r.loadout.ammo.reserve("ammo_starter") == max - 4)    // nothing taken (no duplication)
        r.loadout.ammo.set("ammo_starter", 0)
        do { let v = r.pick("ammo_starter"); #expect(v == .reserve(overflowPacks: 0)) }  // fits entirely: bag not needed
    }
}
