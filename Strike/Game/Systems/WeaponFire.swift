import CoreGraphics
import GameplayKit

/// Shot pattern of one trigger pull (GDD §5): one jitter roll for the whole shot, then
/// `pellets` spread evenly across `spreadDeg` around it. Pure; the scene spawns the projectiles.
nonisolated enum WeaponFire {
    /// The angles of one shot. `center` is the jittered aim (muzzle flash, recoil).
    struct Shot: Sendable, Equatable {
        let center: CGFloat
        let angles: [CGFloat]
    }

    /// Rolls `rng` once when the blaster has jitter (so the random sequence matches M1–M3).
    static func shot(def: WeaponDef, aimAngle: CGFloat, rng: GKRandom) -> Shot {
        var center = aimAngle
        if def.jitterDeg > 0 {
            center += CGFloat((Double(rng.nextUniform()) * 2 - 1) * def.jitterDeg) * .pi / 180
        }
        return Shot(center: center, angles: fan(center: center, count: def.pellets, spreadDeg: def.spreadDeg))
    }

    /// `pellets(def:aimAngle:rng:)` from the M4 module map: the pellet angles only.
    static func pellets(def: WeaponDef, aimAngle: CGFloat, rng: GKRandom) -> [CGFloat] {
        shot(def: def, aimAngle: aimAngle, rng: rng).angles
    }

    /// `count` directions spread evenly across `spreadDeg`, symmetric around `center` (count ≥ 1).
    /// Used by blasters, enemy fans (spores) and the boss star volley.
    static func fan(center: CGFloat, count: Int, spreadDeg: Double) -> [CGFloat] {
        let n = max(1, count)
        guard n > 1 else { return [center] }
        let spread = CGFloat(spreadDeg) * .pi / 180
        return (0..<n).map { i in center + (-spread / 2 + spread * CGFloat(i) / CGFloat(n - 1)) }
    }
}
