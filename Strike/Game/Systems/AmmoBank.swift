import Foundation

/// One reserve per ammo id (GDD §5.1), capped at the firing blaster's `reserveMax` from
/// `weapons.json`. Ammo for blasters the hero does not own yet still counts.
/// Only `reserves` is saved (GDD §16.10); after decoding, `applyCaps` re-attaches the caps
/// (`RunState.bind`). Until then every add overflows.
nonisolated struct AmmoBank: Codable, Sendable, Equatable {
    private(set) var reserves: [String: Int]
    /// `reserveMax` per ammo id (configuration, not saved).
    private(set) var caps: [String: Int]

    enum CodingKeys: String, CodingKey {
        case reserves
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        reserves = (try c.decodeIfPresent([String: Int].self, forKey: .reserves) ?? [:]).mapValues { max(0, $0) }
        caps = [:]
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(reserves, forKey: .reserves)
    }

    /// Content equality (caps are configuration). Zero reserves equal missing ones.
    static func == (a: AmmoBank, b: AmmoBank) -> Bool {
        a.reserves.filter { $0.value != 0 } == b.reserves.filter { $0.value != 0 }
    }

    init(caps: [String: Int], reserves: [String: Int] = [:]) {
        self.caps = caps.mapValues { max(0, $0) }
        self.reserves = [:]
        for (id, n) in reserves { set(id, n) }
    }

    /// Caps for every ammo id fired by a blaster (the larger `reserveMax` if two share one).
    init(weapons: some Sequence<WeaponDef>) {
        self.init(caps: Self.caps(from: weapons))
    }

    static func caps(from weapons: some Sequence<WeaponDef>) -> [String: Int] {
        weapons.reduce(into: [:]) { $0[$1.ammoId] = max($0[$1.ammoId] ?? 0, $1.reserveMax) }
    }

    func reserve(_ ammoId: String) -> Int { reserves[ammoId, default: 0] }
    func cap(_ ammoId: String) -> Int { caps[ammoId, default: 0] }
    func space(_ ammoId: String) -> Int { max(0, cap(ammoId) - reserve(ammoId)) }
    func isFull(_ ammoId: String) -> Bool { space(ammoId) == 0 }

    /// Adds up to the cap. Returns the overflow that did not fit (all of it for unknown ammo ids).
    @discardableResult
    mutating func add(_ ammoId: String, amount: Int) -> Int {
        guard amount > 0 else { return 0 }
        let fit = min(amount, space(ammoId))
        if fit > 0 { reserves[ammoId] = reserve(ammoId) + fit }
        return amount - fit
    }

    /// Takes up to `amount` out of the reserve; returns what was taken.
    @discardableResult
    mutating func take(_ ammoId: String, upTo amount: Int) -> Int {
        let n = min(max(0, amount), reserve(ammoId))
        if n > 0 { reserves[ammoId] = reserve(ammoId) - n }
        return n
    }

    /// Sets a reserve, clamped to `0…cap`.
    mutating func set(_ ammoId: String, _ value: Int) {
        reserves[ammoId] = min(max(0, value), cap(ammoId))
    }

    /// Attaches caps after loading a save; reserves are clamped, unknown ammo ids dropped.
    mutating func applyCaps(_ newCaps: [String: Int]) {
        caps = newCaps.mapValues { max(0, $0) }
        reserves = reserves.filter { caps[$0.key] != nil }
        for (id, n) in reserves { reserves[id] = min(n, cap(id)) }
    }
}
