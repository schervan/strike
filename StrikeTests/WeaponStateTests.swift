import Testing
@testable import Strike

struct WeaponStateTests {
    let def: WeaponDef
    let net = SafetyNetDef(rechargeEverySec: 1.5, rechargeTo: 12)

    init() throws { def = try TestData.starter() }

    @Test func fireUsesMagazineOnly() {
        var w = WeaponState(def: def, magazine: 12, reserve: 48)
        let r11 = w.tryFire(triggerHeld: true)
        #expect(r11)
        #expect(w.magazine == 11)
        #expect(w.reserve == 48)
    }

    @Test func noFireWithoutTrigger() {
        var w = WeaponState(def: def, magazine: 12, reserve: 48)
        let r19 = w.tryFire(triggerHeld: false)
        #expect(!r19)
        #expect(w.magazine == 12)
    }

    @Test func fireRateIsRespected() {
        var w = WeaponState(def: def, magazine: 12, reserve: 0)
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
        var w = WeaponState(def: def, magazine: 0, reserve: 0)
        let r45 = w.tryFire(triggerHeld: true)
        #expect(!r45)
        #expect(!w.isReloading)
    }

    @Test func reloadMovesMinOfMissingAndReserve() {
        var w = WeaponState(def: def, magazine: 4, reserve: 48)
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

        var low = WeaponState(def: def, magazine: 2, reserve: 3)
        low.startReload()
        low.tick(dt: def.reloadSec + 0.01)
        #expect(low.magazine == 5)
        #expect(low.reserve == 0)
    }

    @Test func reloadRefusedWhenFullOrNoReserve() {
        var full = WeaponState(def: def, magazine: 12, reserve: 48)
        let r72 = full.startReload()
        #expect(!r72)
        var empty = WeaponState(def: def, magazine: 5, reserve: 0)
        let r75 = empty.startReload()
        #expect(!r75)
    }

    @Test func cancelLosesNoAmmo() {
        var w = WeaponState(def: def, magazine: 3, reserve: 20)
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
        var w = WeaponState(def: def, magazine: 1, reserve: 10)
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
        var w = WeaponState(def: def, magazine: 0, reserve: 0, safetyNet: net)
        w.tick(dt: 1.4)
        #expect(w.reserve == 0)
        w.tick(dt: 0.2)
        #expect(w.reserve == 1)
        for _ in 0..<100 { w.tick(dt: 0.5) } // 50 s
        #expect(w.reserve == 12)

        var notEmpty = WeaponState(def: def, magazine: 1, reserve: 0, safetyNet: net)
        notEmpty.tick(dt: 10)
        #expect(notEmpty.reserve == 0)

        var noNet = WeaponState(def: def, magazine: 0, reserve: 0)
        noNet.tick(dt: 10)
        #expect(noNet.reserve == 0)
    }

    @Test func addReserveReturnsOverflow() {
        var w = WeaponState(def: def, magazine: 12, reserve: 90)
        let r127 = w.addReserve(24)
        #expect(r127 == 18)
        #expect(w.reserve == def.reserveMax)
        let r130 = w.addReserve(5)
        #expect(r130 == 5)
        var e = WeaponState(def: def, magazine: 0, reserve: 0)
        let r133 = e.addReserve(24)
        #expect(r133 == 0)
        #expect(e.reserve == 24)
    }
}
