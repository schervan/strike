import GameplayKit
import Testing
@testable import Strike

struct LootRollerTests {
    let data: GameData
    init() throws { data = try TestData.load() }

    func ctx(level: Int = 1, hp: Double = 1, ammo: Double = 1, total: Int = 60) -> LootContext {
        LootContext(level: level, heroHpRatio: hp, equippedWeaponId: "blaster_starter",
                    equippedAmmoRatio: ammo, equippedAmmoTotal: total, ownedWeaponIds: ["blaster_starter"])
    }

    @Test func seededRollsAreIdentical() {
        let a = GKMersenneTwisterRandomSource(seed: 42)
        let b = GKMersenneTwisterRandomSource(seed: 42)
        for _ in 0..<200 {
            #expect(LootRoller.roll(tableId: "loot_boltbot", data: data, context: ctx(), random: a)
                == LootRoller.roll(tableId: "loot_boltbot", data: data, context: ctx(), random: b))
        }
    }

    @Test func boltsWithinRange() throws {
        let t = try #require(data.lootTables["loot_boltbot"])
        let r = GKMersenneTwisterRandomSource(seed: 7)
        var seen = Set<Int>()
        for _ in 0..<500 {
            let drops = LootRoller.roll(tableId: t.id, data: data, context: ctx(), random: r)
            let bolts = drops.filter { $0.itemId == "bolt" }.map(\.count).reduce(0, +)
            #expect(bolts >= t.boltsMin && bolts <= t.boltsMax)
            seen.insert(bolts)
        }
        #expect(seen.count == t.boltsMax - t.boltsMin + 1)
    }

    @Test func unownedAmmoNeverDropsInLevel1() {
        let r = GKMersenneTwisterRandomSource(seed: 99)
        var ids = Set<String>()
        for _ in 0..<2000 {
            for d in LootRoller.roll(tableId: "loot_boltbot", data: data, context: ctx(), random: r) {
                ids.insert(d.itemId)
            }
        }
        #expect(!ids.contains("ammo_spread"))
        #expect(!ids.contains("ammo_rapid"))
        #expect(ids.contains("ammo_starter"))
        #expect(ids.contains("food_apple"))
    }

    @Test func unownedAmmoAllowedFromUnlockLevel() {
        let m = LootRoller.multiplier(for: "ammo_spread", modifiers: data.lootModifiers, items: data.items,
                                      weapons: data.weapons, context: ctx(level: 2))
        #expect(m == 1)
    }

    @Test func lowHpDoublesHealAndFood() {
        let normal = LootRoller.multiplier(for: "food_apple", modifiers: data.lootModifiers, items: data.items,
                                           weapons: data.weapons, context: ctx(hp: 0.8))
        let low = LootRoller.multiplier(for: "food_apple", modifiers: data.lootModifiers, items: data.items,
                                        weapons: data.weapons, context: ctx(hp: 0.2))
        let heal = LootRoller.multiplier(for: "healpack", modifiers: data.lootModifiers, items: data.items,
                                         weapons: data.weapons, context: ctx(hp: 0.2))
        let ammo = LootRoller.multiplier(for: "ammo_starter", modifiers: data.lootModifiers, items: data.items,
                                         weapons: data.weapons, context: ctx(hp: 0.2))
        #expect(normal == 1)
        #expect(low == 2)
        #expect(heal == 2)
        #expect(ammo == 1)
    }

    @Test func lowAmmoBoostsEquippedAmmo() {
        let m = LootRoller.multiplier(for: "ammo_starter", modifiers: data.lootModifiers, items: data.items,
                                      weapons: data.weapons, context: ctx(ammo: 0.1))
        #expect(m == 2.5)
    }

    /// QA-004 `ammo_rescue`: below one magazine every power-down guarantees the equipped ammo.
    @Test func ammoRescueGuaranteesEquippedAmmoBelowOneMagazine() throws {
        let rescue = try #require(data.lootModifiers.first { $0.id == "ammo_rescue" })
        let n = rescue.guaranteeCount ?? 0
        #expect(n > 0)
        let r = GKMersenneTwisterRandomSource(seed: 3)
        for total in [0, 5, 11] {
            for _ in 0..<50 {
                let drops = LootRoller.roll(tableId: "loot_boltbot", data: data, context: ctx(ammo: 0.05, total: total), random: r)
                let packs = drops.filter { $0.itemId == "ammo_starter" }.map(\.count).reduce(0, +)
                #expect(packs >= n)
            }
        }
        // At or above one magazine there is no guarantee: some rolls give no ammo.
        var withoutAmmo = 0
        for _ in 0..<200 {
            let drops = LootRoller.roll(tableId: "loot_boltbot", data: data, context: ctx(total: 12), random: r)
            if !drops.contains(where: { $0.itemId == "ammo_starter" }) { withoutAmmo += 1 }
        }
        #expect(withoutAmmo > 0)
    }

    @Test func guaranteedEntriesAlwaysDrop() {
        let r = GKMersenneTwisterRandomSource(seed: 1)
        let drops = LootRoller.roll(tableId: "loot_megamech", data: data, context: ctx(level: 5), random: r)
        #expect(drops.contains(LootDrop(itemId: "healpack", count: 2)))
        #expect(drops.contains(LootDrop(itemId: "food_onigiri", count: 3)))
        #expect(drops.contains(LootDrop(itemId: "bolt", count: 40)))
    }
}
