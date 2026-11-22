import CoreGraphics
import Foundation

/// Aim assist (GDD §3.4). Pure; the caller passes only alive targets.
nonisolated enum AimAssist {
    /// Returns the adjusted aim angle (radians). Targets inside ±`coneDeg` around `stickAngle`,
    /// within `range` and with line of sight are candidates; the smallest angle difference wins
    /// (tie: nearest). The aim is rotated toward it by `strength` of the difference.
    static func adjust(
        stickAngle: CGFloat,
        origin: CGPoint,
        targets: [CGPoint],
        coneDeg: CGFloat,
        range: CGFloat,
        strength: CGFloat,
        hasLineOfSight: (CGPoint) -> Bool
    ) -> CGFloat {
        let cone = coneDeg * .pi / 180
        var best: (diff: CGFloat, dist: CGFloat)?
        for t in targets {
            let dx = t.x - origin.x, dy = t.y - origin.y
            let dist = hypot(dx, dy)
            guard dist > 0, dist <= range else { continue }
            let diff = angleDifference(from: stickAngle, to: atan2(dy, dx))
            guard abs(diff) <= cone else { continue }
            if let b = best {
                let better = abs(diff) < abs(b.diff) - 1e-6
                    || (abs(abs(diff) - abs(b.diff)) <= 1e-6 && dist < b.dist)
                guard better else { continue }
            }
            guard hasLineOfSight(t) else { continue }
            best = (diff, dist)
        }
        guard let b = best else { return stickAngle }
        return stickAngle + b.diff * strength
    }

    /// Signed shortest difference `to - from`, in (-π, π].
    static func angleDifference(from a: CGFloat, to b: CGFloat) -> CGFloat {
        var d = (b - a).truncatingRemainder(dividingBy: 2 * .pi)
        if d > .pi { d -= 2 * .pi }
        if d <= -.pi { d += 2 * .pi }
        return d
    }
}
