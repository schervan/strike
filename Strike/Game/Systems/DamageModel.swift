import CoreGraphics
import Foundation

/// Damage an enemy takes from a hero shot (GDD §8.1, §9): base × dizzy multiplier × shy
/// multiplier, 0 while immune; and the front-shield block test. Pure.
nonisolated enum DamageModel {
    /// Rounded to the nearest point; a hit that is not immune always does at least 1.
    static func finalDamage(base: Int, dizzyMultiplier: Double = 1, shyMultiplier: Double = 1,
                            immune: Bool = false) -> Int {
        guard !immune, base > 0 else { return 0 }
        let v = (Double(base) * dizzyMultiplier * shyMultiplier).rounded()
        return max(1, Int(v))
    }

    /// True when a shot travelling along `shotAngle` hits the front of a shield facing `facing`
    /// with a total arc of `arcDeg` (it comes from within ±arc/2 of the facing).
    static func shieldBlocks(facing: CGFloat, shotAngle: CGFloat, arcDeg: Double) -> Bool {
        // The shot comes *from* the opposite of its travel direction.
        let from = shotAngle + .pi
        let diff = abs(AimAssist.angleDifference(from: facing, to: from))
        return diff <= CGFloat(arcDeg / 2) * .pi / 180 + 1e-9
    }
}
