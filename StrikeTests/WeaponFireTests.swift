import CoreGraphics
import GameplayKit
import Testing
@testable import Strike

/// M4-4: blaster patterns (GDD §5) from `weapons.json`.
struct WeaponFireTests {
    static var data: GameData { GeneratedCorpus.data }
    static func w(_ id: String) -> WeaponDef { data.weapons[id]! }
    static func deg(_ r: CGFloat) -> Double { Double(r) * 180 / .pi }

    @Test func spreadFiresItsPelletsSymmetricAcrossItsSpread() {
        let w = Self.w("blaster_spread")
        #expect(w.pellets == 5 && w.spreadDeg == 40, "GDD §5 numbers")
        let aim: CGFloat = 0.7
        let shot = WeaponFire.shot(def: w, aimAngle: aim, rng: GKMersenneTwisterRandomSource(seed: 1))
        #expect(shot.angles.count == w.pellets)
        #expect(shot.center == aim, "spread has no jitter")
        let offs = shot.angles.map { Self.deg($0 - aim) }
        #expect(abs((offs.max()! - offs.min()!) - w.spreadDeg) < 1e-6)
        for (a, b) in zip(offs, offs.reversed()) { #expect(abs(a + b) < 1e-6, "symmetric") }
        let steps = zip(offs, offs.dropFirst()).map { $1 - $0 }
        for s in steps { #expect(abs(s - w.spreadDeg / Double(w.pellets - 1)) < 1e-6, "even") }
    }

    @Test(arguments: ["blaster_starter", "blaster_rapid"])
    func jitterStaysWithinItsLimit(id: String) {
        let w = Self.w(id)
        let rng = GKMersenneTwisterRandomSource(seed: 7)
        var maxSeen = 0.0
        for _ in 0..<5000 {
            let shot = WeaponFire.shot(def: w, aimAngle: 1.0, rng: rng)
            #expect(shot.angles == [shot.center])
            let d = abs(Self.deg(shot.center - 1.0))
            maxSeen = max(maxSeen, d)
            #expect(d <= w.jitterDeg + 1e-9)
        }
        #expect(maxSeen > w.jitterDeg * 0.9, "jitter is actually used (\(maxSeen)°)")
    }

    @Test func jitterLimitsMatchTheGDD() {
        #expect(Self.w("blaster_starter").jitterDeg == 2)
        #expect(Self.w("blaster_rapid").jitterDeg == 7)
    }

    @Test func fanIsSymmetricAndSingleShotsGoStraight() {
        #expect(WeaponFire.fan(center: 0.3, count: 1, spreadDeg: 40) == [0.3])
        let f = WeaponFire.fan(center: 0, count: 3, spreadDeg: 30)
        #expect(f.count == 3 && abs(Self.deg(f[0]) + 15) < 1e-9 && abs(f[1]) < 1e-12 && abs(Self.deg(f[2]) - 15) < 1e-9)
    }

    /// Fire rate per blaster with the trigger held (start of the run: one shot at t = 0).
    @Test(arguments: ["blaster_starter", "blaster_spread", "blaster_rapid"])
    func fireRateIsRespected(id: String) {
        let w = Self.w(id)
        var loadout = Loadout(start: StartLoadoutDef(weaponId: w.id, magazine: w.magazineSize, reserve: 0),
                              weapons: Self.data.weapons)
        var state = WeaponState(def: w)
        let dt = 1.0 / 240
        // Long enough for several shots, short enough to stay inside one magazine.
        let window = min(2.0, Double(w.magazineSize - 1) / w.fireRate)
        var shots: [Double] = []
        var t = 0.0
        while t < window {
            if state.tryFire(triggerHeld: true, loadout: &loadout) { shots.append(t) }
            state.tick(dt: dt, loadout: &loadout)
            t += dt
        }
        let expected = Int((window * w.fireRate).rounded(.down)) + 1
        #expect(abs(shots.count - expected) <= 1, "\(id): \(shots.count) shots in \(window) s, expected ≈ \(expected)")
        for (a, b) in zip(shots, shots.dropFirst()) { #expect(b - a >= 1 / w.fireRate - dt - 1e-9) }
    }
}
