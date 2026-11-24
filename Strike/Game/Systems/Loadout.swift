import Foundation

/// Blasters the hero owns, the equipped one, one magazine per blaster and the ammo reserves
/// (GDD §5 / §5.1). Carries over between levels and is saved. `WeaponState` keeps only the
/// timers and reads/writes magazine and reserve through this type.
nonisolated struct Loadout: Codable, Sendable, Equatable {
    /// Owned weapon ids in pickup order (the M4 wheel order).
    private(set) var owned: [String]
    private(set) var equipped: String
    /// Rounds in each blaster's magazine.
    private(set) var magazines: [String: Int]
    var ammo: AmmoBank

    enum CodingKeys: String, CodingKey {
        case owned, equipped, magazines, ammo
    }

    /// Tolerant decoding (GDD §16.10): missing fields take defaults; `bind` repairs the rest.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        owned = try c.decodeIfPresent([String].self, forKey: .owned) ?? []
        equipped = try c.decodeIfPresent(String.self, forKey: .equipped) ?? ""
        magazines = try c.decodeIfPresent([String: Int].self, forKey: .magazines) ?? [:]
        ammo = try c.decodeIfPresent(AmmoBank.self, forKey: .ammo) ?? AmmoBank(caps: [:])
    }

    /// The hero's start loadout (`hero.json → startLoadout`) with caps from `weapons.json`.
    init(start: StartLoadoutDef, weapons: [String: WeaponDef]) {
        owned = [start.weaponId]
        equipped = start.weaponId
        magazines = [:]
        ammo = AmmoBank(weapons: weapons.values)
        if let w = weapons[start.weaponId] {
            setMagazine(w, start.magazine)
            ammo.set(w.ammoId, start.reserve)
        }
    }

    func owns(_ weaponId: String) -> Bool { owned.contains(weaponId) }
    func magazine(_ weaponId: String) -> Int { magazines[weaponId, default: 0] }
    func reserve(for weapon: WeaponDef) -> Int { ammo.reserve(weapon.ammoId) }
    /// Magazine + reserve of one blaster.
    func totalAmmo(_ weapon: WeaponDef) -> Int { magazine(weapon.id) + reserve(for: weapon) }

    /// Sets a magazine, clamped to `0…magazineSize`.
    mutating func setMagazine(_ weapon: WeaponDef, _ rounds: Int) {
        magazines[weapon.id] = min(max(0, rounds), weapon.magazineSize)
    }

    /// Spends one round from the magazine. False when it is empty.
    mutating func consumeRound(_ weapon: WeaponDef) -> Bool {
        let m = magazine(weapon.id)
        guard m > 0 else { return false }
        magazines[weapon.id] = m - 1
        return true
    }

    /// Moves `min(magazineSize − mag, reserve)` from the reserve to the magazine. Returns the rounds moved.
    @discardableResult
    mutating func completeReload(_ weapon: WeaponDef) -> Int {
        let moved = ammo.take(weapon.ammoId, upTo: weapon.magazineSize - magazine(weapon.id))
        magazines[weapon.id] = magazine(weapon.id) + moved
        return moved
    }

    /// Adds a blaster (GDD §6: with one full magazine). False if already owned.
    @discardableResult
    mutating func addWeapon(_ weapon: WeaponDef) -> Bool {
        guard !owns(weapon.id) else { return false }
        owned.append(weapon.id)
        setMagazine(weapon, weapon.magazineSize)
        return true
    }

    /// Equips an owned blaster. False when not owned.
    @discardableResult
    mutating func equip(_ weaponId: String) -> Bool {
        guard owns(weaponId) else { return false }
        equipped = weaponId
        return true
    }

    /// Level start (GDD §5.1): magazine at least `magazine`, reserve at least `reserve` (both capped).
    mutating func topUp(_ weapon: WeaponDef, magazine minMag: Int, reserve minReserve: Int) {
        if magazine(weapon.id) < minMag { setMagazine(weapon, minMag) }
        if reserve(for: weapon) < minReserve { ammo.set(weapon.ammoId, minReserve) }
    }

    /// Rescue (GDD §12 step 5): if magazine + reserve is below `minTotal`, the gap goes to the reserve
    /// and the magazine then fills from the reserve (no reload animation). Returns the rounds added.
    @discardableResult
    mutating func topUpTotal(_ weapon: WeaponDef, atLeast minTotal: Int) -> Int {
        let before = totalAmmo(weapon)
        let missing = minTotal - before
        guard missing > 0 else { return 0 }
        ammo.add(weapon.ammoId, amount: missing)
        completeReload(weapon)
        return totalAmmo(weapon) - before
    }

    /// Repairs a decoded loadout against `weapons.json`: caps re-applied, unknown blasters dropped,
    /// the starter always owned, magazines clamped, the equipped blaster owned.
    mutating func bind(weapons: [String: WeaponDef], starterId: String) {
        ammo.applyCaps(AmmoBank.caps(from: weapons.values))
        owned = owned.filter { weapons[$0] != nil }
        if !owns(starterId), weapons[starterId] != nil { owned.insert(starterId, at: 0) }
        magazines = magazines.filter { owns($0.key) }
        for id in owned { if let w = weapons[id] { setMagazine(w, magazine(id)) } }
        if !owns(equipped) { equipped = owned.first ?? starterId }
    }
}
