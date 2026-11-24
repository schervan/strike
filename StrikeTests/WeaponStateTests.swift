import Testing
@testable import Strike

/// M3: `WeaponState` keeps only timers; magazine and reserve live in `Loadout`. This rig pairs
/// the two with the pre-M3 API so the M1/QA-004 test bodies below are unchanged.
private struct Rig {
    var w: WeaponState
    var l: Loadout

    init(def: WeaponDef, magazine: Int, reserve: Int, safetyNet: SafetyNetDef? = nil) {
        w = WeaponState(def: def, safetyNet: safetyNet)
        l = Loadout(start: StartLoadoutDef(weaponId: def.id, magazine: magazine, reserve: reserve),
                    weapons: [def.id: def])
    }

    var def: WeaponDef { w.def }
    var magazine: Int { w.magazine(in: l) }
    var reserve: Int { w.reserve(in: l) }
    var totalAmmo: Int { w.totalAmmo(in: l) }
    var isReloading: Bool { w.isReloading }
    var reloadProgress: Double { w.reloadProgress }
    var safetyNetActive: Bool { w.safetyNetActive }

    mutating func tick(dt: Double) { w.tick(dt: dt, loadout: &l) }
    mutating func tryFire(triggerHeld: Bool) -> Bool { w.tryFire(triggerHeld: triggerHeld, loadout: &l) }
    @discardableResult mutating func startReload() -> Bool { w.startReload(loadout: l) }
    mutating func cancelReload() { w.cancelReload() }
    @discardableResult mutating func addReserve(_ n: Int) -> Int { l.ammo.add(def.ammoId, amount: n) }
}

struct WeaponStateTests {
    let def: WeaponDef
    let net = SafetyNetDef(rechargeEverySec: 1.5, rechargeTo: 12)

    init() throws { def = try TestData.starter() }

    @Test func fireUsesMagazineOnly() {
        var w = Rig(def: def, magazine: 12, reserve: 48)
        let r11 = w.tryFire(triggerHeld: true)
        #expect(r11)
        #expect(w.magazine == 11)
        #expect(w.reserve == 48)
    }

    @Test func noFireWithoutTrigger() {
        var w = Rig(def: def, magazine: 12, reserve: 48)
        let r19 = w.tryFire(triggerHeld: false)
        #expect(!r19)
        #expect(w.magazine == 12)
    }

    @Test func fireRateIsRespected() {
        var w = Rig(def: def, magazine: 12, reserve: 0)
        let dt = 1.0 / 60
        var shots = 0
        var lastShot = -1.0
        var minGap = Double.infinity
        for frame in 0..<120 { // 2 s
            if w.tryFire(triggerHeld: true) {
                let t = Double(frame) * dt
                if lastShot >= 0 { minGap = min(minGap, t - lastShot) }
                lastShot = t
                shots += 1
            }
            w.tick(dt: dt)
        }
        #expect(shots == 8) // 4 / s for 2 s
        #expect(minGap >= 1 / def.fireRate - 1e-9)
    }

    @Test func emptyMagazineCannotFire() {
        var w = Rig(def: def, magazine: 0, reserve: 0)
        let r45 = w.tryFire(triggerHeld: true)
        #expect(!r45)
        #expect(!w.isReloading)
    }

    @Test func reloadMovesMinOfMissingAndReserve() {
        var w = Rig(def: def, magazine: 4, reserve: 48)
        let r52 = w.startReload()
        #expect(r52)
        w.tick(dt: def.reloadSec * 0.5)
        #expect(w.isReloading)
        #expect(abs(w.reloadProgress - 0.5) < 0.01)
        #expect(w.magazine == 4) // nothing moves before the end
        w.tick(dt: def.reloadSec * 0.6)
        #expect(!w.isReloading)
        #expect(w.magazine == 12)
        #expect(w.reserve == 40)

        var low = Rig(def: def, magazine: 2, reserve: 3)
        low.startReload()
        low.tick(dt: def.reloadSec + 0.01)
        #expect(low.magazine == 5)
        #expect(low.reserve == 0)
    }

    @Test func reloadRefusedWhenFullOrNoReserve() {
        var full = Rig(def: def, magazine: 12, reserve: 48)
        let r72 = full.startReload()
        #expect(!r72)
        var empty = Rig(def: def, magazine: 5, reserve: 0)
        let r75 = empty.startReload()
        #expect(!r75)
    }

    @Test func cancelLosesNoAmmo() {
        var w = Rig(def: def, magazine: 3, reserve: 20)
        w.startReload()
        w.tick(dt: def.reloadSec * 0.9)
        w.cancelReload()
        #expect(!w.isReloading)
        #expect(w.magazine == 3)
        #expect(w.reserve == 20)
        w.tick(dt: 5)
        #expect(w.magazine == 3)
    }

    @Test func autoReloadAtEmptyMagWithTriggerHeld() {
        var w = Rig(def: def, magazine: 1, reserve: 10)
        let r93 = w.tryFire(triggerHeld: true)
        #expect(r93)
        w.tick(dt: 1)
        let r96 = w.tryFire(triggerHeld: false)
        #expect(!r96)
        #expect(!w.isReloading) // trigger not held: no auto-reload
        let r99 = w.tryFire(triggerHeld: true)
        #expect(!r99)
        #expect(w.isReloading)
        w.tick(dt: def.reloadSec + 0.01)
        #expect(w.magazine == 10)
        #expect(w.reserve == 0)
    }

    @Test func safetyNetRechargesOnlyWhenEmpty() {
        var w = Rig(def: def, magazine: 0, reserve: 0, safetyNet: net)
        w.tick(dt: 1.4)
        #expect(w.reserve == 0)
        w.tick(dt: 0.2)
        #expect(w.reserve == 1)
        for _ in 0..<100 { w.tick(dt: 0.5) } // 50 s
        #expect(w.reserve == 12)

        var notEmpty = Rig(def: def, magazine: 1, reserve: 0, safetyNet: net)
        notEmpty.tick(dt: 10)
        #expect(notEmpty.reserve == 0)

        var noNet = Rig(def: def, magazine: 0, reserve: 0)
        noNet.tick(dt: 10)
        #expect(noNet.reserve == 0)
    }

    @Test func addReserveReturnsOverflow() {
        var w = Rig(def: def, magazine: 12, reserve: 90)
        let r127 = w.addReserve(24)
        #expect(r127 == 18)
        #expect(w.reserve == def.reserveMax)
        let r130 = w.addReserve(5)
        #expect(r130 == 5)
        var e = Rig(def: def, magazine: 0, reserve: 0)
        let r133 = e.addReserve(24)
        #expect(r133 == 0)
        #expect(e.reserve == 24)
    }

    // QA-004: values straight from hero.json.
    @Test func safetyNetFromHeroJSONRefillsToCapAndNeverAbove() throws {
        let hero = try TestData.load().hero
        let net = hero.starterSafetyNet
        var w = Rig(def: def, magazine: 0, reserve: 0, safetyNet: net)
        w.tick(dt: net.rechargeEverySec * 0.9)
        #expect(w.reserve == 0)
        w.tick(dt: net.rechargeEverySec * 0.2)
        #expect(w.reserve == 1)
        for _ in 0..<600 { w.tick(dt: 0.1) } // 60 s
        #expect(w.totalAmmo == net.rechargeTo)
        #expect(!w.safetyNetActive)
        // Spend some, but not all: the net stays off until mag + reserve hits 0 again.
        _ = w.startReload()
        w.tick(dt: def.reloadSec + 0.01)
        for _ in 0..<3 {
            _ = w.tryFire(triggerHeld: true)
            w.tick(dt: 1)
        }
        let before = w.totalAmmo
        for _ in 0..<100 { w.tick(dt: 0.5) }
        #expect(w.totalAmmo == before)
        #expect(w.totalAmmo <= net.rechargeTo)
    }

    /// QA-004: with the trigger held at 0 / 0 the safety net still yields about one shot per
    /// `rechargeEverySec` and never exceeds `rechargeTo`.
    @Test func safetyNetUnderSustainedFireTrickles() throws {
        let net = try TestData.load().hero.starterSafetyNet
        var w = Rig(def: def, magazine: 0, reserve: 0, safetyNet: net)
        var shots = 0
        let dt = 1.0 / 60
        for _ in 0..<(30 * 60) { // 30 s holding fire
            if w.tryFire(triggerHeld: true) { shots += 1 }
            w.tick(dt: dt)
        }
        let expected = 30 / net.rechargeEverySec
        #expect(Double(shots) >= expected * 0.8 && Double(shots) <= expected)
        #expect(w.totalAmmo <= net.rechargeTo)
    }

    // MARK: M3 refactor

    /// The net refills the starter even while another blaster is equipped, and a pickup during
    /// the net ends it (as `addReserve` did before M3).
    @Test func safetyNetWorksThroughTheLoadout() throws {
        let data = try TestData.load()
        let spread = try #require(data.weapons["blaster_spread"])
        var l = Loadout(start: StartLoadoutDef(weaponId: def.id, magazine: 0, reserve: 0), weapons: data.weapons)
        l.addWeapon(spread)
        l.equip(spread.id)
        var w = WeaponState(def: spread, safetyNet: net, safetyNetWeapon: def)
        w.tick(dt: 1.6, loadout: &l)
        #expect(l.reserve(for: def) == 1)
        #expect(w.safetyNetActive)
        l.ammo.add(def.ammoId, amount: 2)               // picked up a little ammo
        w.tick(dt: 0.1, loadout: &l)
        #expect(!w.safetyNetActive)
        w.tick(dt: 10, loadout: &l)
        #expect(l.reserve(for: def) == 3)
    }

    @Test func reloadAndFireGoThroughTheLoadout() {
        var w = WeaponState(def: def)
        var l = Loadout(start: StartLoadoutDef(weaponId: def.id, magazine: 1, reserve: 30), weapons: [def.id: def])
        do { let ok = w.tryFire(triggerHeld: true, loadout: &l); #expect(ok) }
        #expect(l.magazine(def.id) == 0)
        w.tick(dt: 1, loadout: &l)
        do { let ok = !w.tryFire(triggerHeld: true, loadout: &l); #expect(ok) }   // empty → auto-reload
        w.tick(dt: def.reloadSec + 0.01, loadout: &l)
        #expect(l.magazine(def.id) == def.magazineSize)
        #expect(l.ammo.reserve(def.ammoId) == 30 - def.magazineSize)
    }
}
