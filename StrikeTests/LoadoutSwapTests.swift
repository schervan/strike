import Testing
@testable import Strike

/// M4-4: blaster pickup, SWAP order, swap time and reload cancel (GDD §5, §5.1).
struct LoadoutSwapTests {
    static var data: GameData { GeneratedCorpus.data }
    static var order: [String] { Loadout.order(data.weapons) }
    static func w(_ id: String) -> WeaponDef { data.weapons[id]! }
    static func fresh() -> Loadout { Loadout(start: data.hero.startLoadout, weapons: data.weapons) }

    @Test func orderIsStarterSpreadRapid() {
        #expect(Self.order == ["blaster_starter", "blaster_spread", "blaster_rapid"])
    }

    @Test func pickingUpABlasterAddsItWithOneFullMagazine() {
        var l = Self.fresh()
        var inv = Inventory(items: Self.data.items, rules: Self.data.rules.inventory)
        let spread = Self.w("blaster_spread")
        let before = l.ammo.reserve(spread.ammoId)
        let v = PickupResolver.resolve(Self.data.items[spread.id]!, inventory: &inv, loadout: &l, weapons: Self.data.weapons)
        #expect(v == .weapon(id: spread.id, added: true, overflowPacks: 0))
        #expect(l.owns(spread.id) && l.magazine(spread.id) == spread.magazineSize)
        #expect(l.ammo.reserve(spread.ammoId) == before, "the magazine is new, the reserve is untouched")
        #expect(l.equipped == "blaster_starter", "not equipped automatically")
        // Second pickup (replay): one magazine of ammo into the reserve.
        let again = PickupResolver.resolve(Self.data.items[spread.id]!, inventory: &inv, loadout: &l, weapons: Self.data.weapons)
        #expect(again == .weapon(id: spread.id, added: false, overflowPacks: 0))
        #expect(l.ammo.reserve(spread.ammoId) == before + spread.magazineSize)
    }

    @Test func swapNextCyclesOnlyOwnedBlastersInOrder() {
        var l = Self.fresh()
        let v1 = l.swapNext(order: Self.order)
        #expect(v1 == nil, "one blaster: nothing to swap to")
        l.addWeapon(Self.w("blaster_rapid"))
        let v2 = l.swapNext(order: Self.order)
        #expect(v2 == "blaster_rapid", "spread is skipped (not owned)")
        let v3 = l.swapNext(order: Self.order)
        #expect(v3 == "blaster_starter", "wraps")
        l.addWeapon(Self.w("blaster_spread"))
        let v4 = l.swapNext(order: Self.order)
        #expect(v4 == "blaster_spread")
        let v5 = l.swapNext(order: Self.order)
        #expect(v5 == "blaster_rapid")
        let v6 = l.swapNext(order: Self.order)
        #expect(v6 == "blaster_starter")
        let v7 = l.swap(to: "blaster_rapid")
        #expect(v7 && l.equipped == "blaster_rapid")
        let v8 = l.swap(to: "blaster_rapid")
        #expect(!v8, "already equipped")
    }

    @Test func swapCancelsTheReloadWithNoAmmoLostAndBlocksFireForSwapSec() {
        let swapSec = Self.data.rules.weapons.swapSec
        #expect(swapSec == 0.25)
        let starter = Self.w("blaster_starter"), spread = Self.w("blaster_spread")
        var l = Self.fresh()
        l.addWeapon(spread)
        var s = WeaponState(def: starter)
        // Empty part of the starter magazine, then start a reload.
        for _ in 0..<3 { _ = s.tryFire(triggerHeld: true, loadout: &l); s.tick(dt: 1, loadout: &l) }
        let mag = l.magazine(starter.id), reserve = l.reserve(for: starter)
        let v9 = s.startReload(loadout: l)
        #expect(v9 && s.isReloading)
        s.tick(dt: starter.reloadSec / 2, loadout: &l)
        // Swap mid-reload.
        let v10 = l.swapNext(order: Self.order)
        #expect(v10 == spread.id)
        s.beginSwap(to: spread, swapSec: swapSec)
        #expect(!s.isReloading, "reload cancelled")
        #expect(l.magazine(starter.id) == mag && l.reserve(for: starter) == reserve, "no ammo lost")
        #expect(s.def.id == spread.id)
        let v11 = s.tryFire(triggerHeld: true, loadout: &l)
        #expect(!v11, "no fire while swapping")
        #expect(!s.canReload(in: l), "no reload while swapping")
        s.tick(dt: swapSec - 0.01, loadout: &l)
        let v12 = s.tryFire(triggerHeld: true, loadout: &l)
        #expect(!v12)
        s.tick(dt: 0.02, loadout: &l)
        let v13 = s.tryFire(triggerHeld: true, loadout: &l)
        #expect(v13, "fires after \(swapSec) s")
        #expect(l.magazine(spread.id) == spread.magazineSize - 1)
    }

    @Test func ammoForAnUnownedBlasterFillsItsReserve() {
        var l = Self.fresh()
        var inv = Inventory(items: Self.data.items, rules: Self.data.rules.inventory)
        let rapid = Self.w("blaster_rapid")
        let pack = Self.data.items[rapid.ammoId]!
        #expect(!l.owns(rapid.id))
        let before = l.ammo.reserve(rapid.ammoId)
        let v = PickupResolver.resolve(pack, inventory: &inv, loadout: &l, weapons: Self.data.weapons)
        #expect(v == .reserve(overflowPacks: 0))
        #expect(l.ammo.reserve(rapid.ammoId) == before + pack.ammoAmount!)
        #expect(!l.owns(rapid.id))
    }
}
