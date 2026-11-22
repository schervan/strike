import Foundation

/// Magazine/reserve/cooldown/reload state of one blaster (GDD §5.1). Pure value type.
nonisolated struct WeaponState: Sendable, Equatable {
    let def: WeaponDef
    private(set) var magazine: Int
    private(set) var reserve: Int
    /// Seconds until the next shot is allowed.
    private(set) var cooldown: Double = 0
    /// Remaining reload time, `nil` when not reloading.
    private(set) var reloadRemaining: Double?
    /// Starter safety net (only set for the starter blaster).
    let safetyNet: SafetyNetDef?
    private(set) var safetyNetActive = false
    private var safetyNetTimer: Double = 0

    init(def: WeaponDef, magazine: Int, reserve: Int, safetyNet: SafetyNetDef? = nil) {
        self.def = def
        self.magazine = min(max(0, magazine), def.magazineSize)
        self.reserve = min(max(0, reserve), def.reserveMax)
        self.safetyNet = safetyNet
        updateSafetyNetActivation()
    }

    var isReloading: Bool { reloadRemaining != nil }

    /// 0…1 while reloading, 0 otherwise.
    var reloadProgress: Double {
        guard let r = reloadRemaining, def.reloadSec > 0 else { return 0 }
        return min(1, max(0, 1 - r / def.reloadSec))
    }

    var fireInterval: Double { def.fireRate > 0 ? 1 / def.fireRate : .infinity }

    /// True when a reload would move ammo.
    var canReload: Bool { !isReloading && magazine < def.magazineSize && reserve > 0 }

    var totalAmmo: Int { magazine + reserve }

    mutating func tick(dt: Double) {
        guard dt > 0 else { return }
        cooldown = max(0, cooldown - dt)
        if let r = reloadRemaining {
            let left = r - dt
            if left <= 0 {
                let moved = min(def.magazineSize - magazine, reserve)
                magazine += moved
                reserve -= moved
                reloadRemaining = nil
            } else {
                reloadRemaining = left
            }
        }
        tickSafetyNet(dt: dt)
    }

    /// Fires one shot if the trigger is held and the blaster is ready. Starts an auto-reload
    /// when the magazine is empty and the trigger is held.
    mutating func tryFire(triggerHeld: Bool) -> Bool {
        guard triggerHeld, !isReloading, cooldown <= 0 else { return false }
        guard magazine > 0 else {
            _ = startReload()
            return false
        }
        magazine -= 1
        cooldown = fireInterval
        updateSafetyNetActivation()
        return true
    }

    @discardableResult
    mutating func startReload() -> Bool {
        guard canReload else { return false }
        reloadRemaining = def.reloadSec
        return true
    }

    /// Cancels a running reload (e.g. weapon swap). Ammo only moves on completion, so nothing is lost.
    mutating func cancelReload() {
        reloadRemaining = nil
    }

    /// Adds ammo to the reserve, capped at `reserveMax`. Returns the overflow that did not fit.
    @discardableResult
    mutating func addReserve(_ amount: Int) -> Int {
        guard amount > 0 else { return 0 }
        let fits = min(amount, def.reserveMax - reserve)
        reserve += fits
        if fits > 0 { safetyNetActive = false; safetyNetTimer = 0 }
        updateSafetyNetActivation()
        return amount - fits
    }

    // MARK: Safety net (starter only): when mag + reserve = 0, +1 reserve per interval up to `rechargeTo`.

    private mutating func updateSafetyNetActivation() {
        guard safetyNet != nil else { return }
        if totalAmmo == 0, !safetyNetActive {
            safetyNetActive = true
            safetyNetTimer = 0
        }
    }

    private mutating func tickSafetyNet(dt: Double) {
        guard let net = safetyNet, net.rechargeEverySec > 0 else { return }
        updateSafetyNetActivation()
        guard safetyNetActive else { return }
        safetyNetTimer += dt
        while safetyNetTimer >= net.rechargeEverySec, totalAmmo < net.rechargeTo, reserve < def.reserveMax {
            safetyNetTimer -= net.rechargeEverySec
            reserve += 1
        }
        if totalAmmo >= net.rechargeTo || reserve >= def.reserveMax {
            safetyNetActive = false
            safetyNetTimer = 0
        }
    }
}
