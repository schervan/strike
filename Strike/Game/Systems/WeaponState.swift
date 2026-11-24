import Foundation

/// Cooldown, reload and safety-net timers of the equipped blaster (GDD §5.1). Magazine and
/// reserve live in `Loadout`; every method that moves ammo takes it `inout`. Pure value type.
nonisolated struct WeaponState: Sendable, Equatable {
    /// Equipped blaster.
    private(set) var def: WeaponDef
    /// Seconds until the next shot is allowed.
    private(set) var cooldown: Double = 0
    /// Remaining reload time, `nil` when not reloading.
    private(set) var reloadRemaining: Double?
    /// Starter safety net, applied to `safetyNetWeapon` whether or not it is equipped.
    let safetyNet: SafetyNetDef?
    let safetyNetWeapon: WeaponDef?
    private(set) var safetyNetActive = false
    private var safetyNetTimer: Double = 0
    /// Net blaster's mag + reserve after the last tick/shot; a rise means ammo was picked up.
    private var lastNetTotal: Int?
    /// Seconds left of a blaster swap (`rules.weapons.swapSec`): no fire and no reload meanwhile.
    private(set) var swapRemaining: Double = 0

    /// `safetyNetWeapon` defaults to `def` when a net is given (the starter).
    init(def: WeaponDef, safetyNet: SafetyNetDef? = nil, safetyNetWeapon: WeaponDef? = nil) {
        self.def = def
        self.safetyNet = safetyNet
        self.safetyNetWeapon = safetyNet == nil ? nil : (safetyNetWeapon ?? def)
    }

    var isReloading: Bool { reloadRemaining != nil }
    var isSwapping: Bool { swapRemaining > 0 }

    /// 0…1 while reloading, 0 otherwise.
    var reloadProgress: Double {
        guard let r = reloadRemaining, def.reloadSec > 0 else { return 0 }
        return min(1, max(0, 1 - r / def.reloadSec))
    }

    var fireInterval: Double { def.fireRate > 0 ? 1 / def.fireRate : .infinity }

    func magazine(in loadout: Loadout) -> Int { loadout.magazine(def.id) }
    func reserve(in loadout: Loadout) -> Int { loadout.reserve(for: def) }
    func totalAmmo(in loadout: Loadout) -> Int { loadout.totalAmmo(def) }

    /// True when a reload would move ammo.
    func canReload(in loadout: Loadout) -> Bool {
        !isReloading && !isSwapping && magazine(in: loadout) < def.magazineSize && reserve(in: loadout) > 0
    }

    /// Switches the equipped blaster (M4 swap). A running reload is cancelled; nothing is lost.
    mutating func equip(_ weapon: WeaponDef) {
        guard weapon.id != def.id else { return }
        def = weapon
        reloadRemaining = nil
        cooldown = 0
    }

    /// SWAP / wheel (GDD §5.1): switches to `weapon` (already equipped in the `Loadout`), cancels a
    /// running reload with no ammo lost, and blocks fire for `swapSec`.
    mutating func beginSwap(to weapon: WeaponDef, swapSec: Double) {
        guard weapon.id != def.id else { return }
        equip(weapon)
        swapRemaining = max(0, swapSec)
    }

    mutating func tick(dt: Double, loadout: inout Loadout) {
        guard dt > 0 else { return }
        cooldown = max(0, cooldown - dt)
        swapRemaining = max(0, swapRemaining - dt)
        if let r = reloadRemaining {
            let left = r - dt
            if left <= 0 {
                loadout.completeReload(def)
                reloadRemaining = nil
            } else {
                reloadRemaining = left
            }
        }
        tickSafetyNet(dt: dt, loadout: &loadout)
    }

    /// Fires one shot if the trigger is held and the blaster is ready. Starts an auto-reload
    /// when the magazine is empty and the trigger is held.
    mutating func tryFire(triggerHeld: Bool, loadout: inout Loadout) -> Bool {
        guard triggerHeld, !isReloading, !isSwapping, cooldown <= 0 else { return false }
        guard loadout.consumeRound(def) else {
            _ = startReload(loadout: loadout)
            return false
        }
        cooldown = fireInterval
        if let w = safetyNetWeapon, w.id == def.id {
            let total = loadout.totalAmmo(w)
            lastNetTotal = total
            if total == 0, !safetyNetActive { safetyNetActive = true; safetyNetTimer = 0 }
        }
        return true
    }

    @discardableResult
    mutating func startReload(loadout: Loadout) -> Bool {
        guard canReload(in: loadout) else { return false }
        reloadRemaining = def.reloadSec
        return true
    }

    /// Cancels a running reload (e.g. weapon swap). Ammo only moves on completion, so nothing is lost.
    mutating func cancelReload() {
        reloadRemaining = nil
    }

    // MARK: Safety net (starter only): when mag + reserve = 0, +1 reserve per interval up to `rechargeTo`.

    private mutating func tickSafetyNet(dt: Double, loadout: inout Loadout) {
        guard let net = safetyNet, let w = safetyNetWeapon else { return }
        var total = loadout.totalAmmo(w)
        // Ammo picked up while the net runs ends it (it restarts at the next 0 / 0).
        if safetyNetActive, let last = lastNetTotal, total > last {
            safetyNetActive = false
            safetyNetTimer = 0
        }
        if total == 0, !safetyNetActive {
            safetyNetActive = true
            safetyNetTimer = 0
        }
        if safetyNetActive, net.rechargeEverySec > 0 {
            safetyNetTimer += dt
            while safetyNetTimer >= net.rechargeEverySec, total < net.rechargeTo, !loadout.ammo.isFull(w.ammoId) {
                safetyNetTimer -= net.rechargeEverySec
                loadout.ammo.add(w.ammoId, amount: 1)
                total += 1
            }
            if total >= net.rechargeTo || loadout.ammo.isFull(w.ammoId) {
                safetyNetActive = false
                safetyNetTimer = 0
            }
        }
        lastNetTotal = total
    }
}
