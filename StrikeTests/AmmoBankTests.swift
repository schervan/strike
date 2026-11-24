import Foundation
import Testing
@testable import Strike

struct AmmoBankTests {
    static var data: GameData { GeneratedCorpus.data }

    @Test func oneReservePerAmmoIdWithReserveMaxFromWeaponsJSON() {
        let bank = AmmoBank(weapons: Self.data.weapons.values)
        for w in Self.data.weapons.values {
            #expect(bank.cap(w.ammoId) == w.reserveMax, "\(w.id)")
            #expect(bank.reserve(w.ammoId) == 0)
        }
    }

    @Test func addReturnsOverflowAboveReserveMax() {
        var bank = AmmoBank(weapons: Self.data.weapons.values)
        let max = bank.cap("ammo_starter")
        do { let v = bank.add("ammo_starter", amount: max - 10); #expect(v == 0) }
        do { let v = bank.add("ammo_starter", amount: 24); #expect(v == 14) }
        #expect(bank.reserve("ammo_starter") == max)
        #expect(bank.isFull("ammo_starter"))
        do { let v = bank.add("nonsense", amount: 5); #expect(v == 5) }
        do { let v = bank.take("ammo_starter", upTo: 1_000); #expect(v == max) }
        #expect(bank.reserve("ammo_starter") == 0)
    }

    @Test func ammoForABlasterNotOwnedYetStillFillsItsReserve() throws {
        var inv = Inventory(items: Self.data.items, rules: Self.data.rules.inventory)
        var loadout = Loadout(start: Self.data.hero.startLoadout, weapons: Self.data.weapons)
        #expect(!loadout.owns("blaster_rapid"))
        let item = try #require(Self.data.items["ammo_rapid"])
        let r = PickupResolver.resolve(item, inventory: &inv, loadout: &loadout)
        #expect(r == .reserve(overflowPacks: 0))
        #expect(loadout.ammo.reserve("ammo_rapid") == item.ammoAmount)
        #expect(inv.isEmpty)
    }

    @Test func loadoutStartsFromHeroJSON() throws {
        let start = Self.data.hero.startLoadout
        let starter = try #require(Self.data.weapons[start.weaponId])
        let l = Loadout(start: start, weapons: Self.data.weapons)
        #expect(l.owned == [start.weaponId] && l.equipped == start.weaponId)
        #expect(l.magazine(start.weaponId) == start.magazine)
        #expect(l.reserve(for: starter) == start.reserve)
    }

    @Test func addWeaponGivesAFullMagazineAndEquipNeedsOwnership() throws {
        let spread = try #require(Self.data.weapons["blaster_spread"])
        var l = Loadout(start: Self.data.hero.startLoadout, weapons: Self.data.weapons)
        do { let ok = !l.equip(spread.id); #expect(ok) }
        do { let ok = l.addWeapon(spread); #expect(ok) }
        do { let ok = !l.addWeapon(spread); #expect(ok) }
        #expect(l.magazine(spread.id) == spread.magazineSize)
        do { let ok = l.equip(spread.id); #expect(ok) }
        #expect(l.equipped == spread.id)
    }

    @Test func levelStartAndRescueTopUps() throws {
        let start = Self.data.hero.startLoadout
        let starter = try #require(Self.data.weapons[start.weaponId])
        var l = Loadout(start: StartLoadoutDef(weaponId: starter.id, magazine: 3, reserve: 5), weapons: Self.data.weapons)
        l.topUp(starter, magazine: start.magazine, reserve: start.reserve)
        #expect(l.magazine(starter.id) == start.magazine && l.reserve(for: starter) == start.reserve)
        var empty = Loadout(start: StartLoadoutDef(weaponId: starter.id, magazine: 0, reserve: 0), weapons: Self.data.weapons)
        do { let v = empty.topUpTotal(starter, atLeast: 12); #expect(v == 12) }
        #expect(empty.magazine(starter.id) == min(12, starter.magazineSize))
        // Partly filled: the gap goes to the reserve, then the magazine fills from it.
        var low = Loadout(start: StartLoadoutDef(weaponId: starter.id, magazine: 0, reserve: 5), weapons: Self.data.weapons)
        low.topUpTotal(starter, atLeast: 12)
        #expect(low.magazine(starter.id) == min(12, starter.magazineSize))
        #expect(low.totalAmmo(starter) == 12)
        #expect(empty.totalAmmo(starter) == 12)
        do { let v = empty.topUpTotal(starter, atLeast: 12); #expect(v == 0) }
    }

    @Test func bindRepairsADecodedLoadout() throws {
        let json = #"{"owned":["blaster_rapid","blaster_gone"],"equipped":"blaster_gone","magazines":{"blaster_rapid":999},"ammo":{"reserves":{"ammo_starter":9999,"ammo_gone":3}}}"#
        var l = try JSONDecoder().decode(Loadout.self, from: Data(json.utf8))
        l.bind(weapons: Self.data.weapons, starterId: "blaster_starter")
        let rapid = try #require(Self.data.weapons["blaster_rapid"])
        #expect(l.owned == ["blaster_starter", "blaster_rapid"])
        #expect(l.equipped == "blaster_starter")
        #expect(l.magazine("blaster_rapid") == rapid.magazineSize)
        #expect(l.ammo.reserve("ammo_starter") == Self.data.weapons["blaster_starter"]!.reserveMax)
        #expect(l.ammo.reserve("ammo_gone") == 0)
    }
}
