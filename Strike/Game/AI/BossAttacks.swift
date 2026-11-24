import CoreGraphics
import Foundation

/// Stomp (GDD §9): after the telegraph the foot lands; everything within `telegraphRadius` is hit
/// at impact, then a shockwave ring (`bandWidth` thick) expands from `telegraphRadius` to `range`
/// over `waveSec`. Step out of it; it cannot be jumped. Pure geometry.
nonisolated enum StompWave {
    /// Thickness of the travelling ring (presentation, matches the drawn ring).
    static let bandWidth: CGFloat = 36

    /// Outer radius of the ring `t` seconds after impact, nil once the wave is over.
    static func radius(at t: Double, attack a: BossAttackDef) -> CGFloat? {
        let from = CGFloat(a.telegraphRadius ?? a.range), to = CGFloat(a.range)
        let dur = max(0.001, a.effectiveWaveSec)
        guard t >= 0, t <= dur else { return nil }
        return from + (to - from) * CGFloat(t / dur)
    }

    /// The impact itself: the hero's body overlaps the telegraphed circle.
    static func impactHits(heroDistance d: CGFloat, heroRadius r: CGFloat, attack a: BossAttackDef) -> Bool {
        d - r <= CGFloat(a.telegraphRadius ?? a.range)
    }

    /// The travelling ring at time `t` after impact overlaps the hero's body.
    static func waveHits(heroDistance d: CGFloat, heroRadius r: CGFloat, at t: Double, attack a: BossAttackDef) -> Bool {
        guard let outer = radius(at: t, attack: a) else { return false }
        let inner = max(0, outer - bandWidth)
        return d - r <= outer && d + r >= inner
    }
}

/// Firework volley (GDD §9): `projectileCount` slow star rockets in a `spreadDeg` fan at the hero.
nonisolated enum StarVolley {
    static func angles(toward heroAngle: CGFloat, attack a: BossAttackDef) -> [CGFloat] {
        WeaponFire.fan(center: heroAngle, count: a.projectileCount ?? 1, spreadDeg: a.spreadDeg ?? 0)
    }
}

/// Laser sweep (GDD §9): a beam ring around the boss out to `range`, with `gaps` safe gaps of
/// `gapDeg` each, rotating at `sweepDegPerSec` for `sweepSec` after the telegraph line. A hero
/// whose whole body is inside a gap is never hit; pillars give cover (line of sight). Pure.
nonisolated enum LaserSweep {
    /// Centres of the safe gaps (radians) `t` seconds after the sweep began. The first gap starts
    /// at `startAngle` (the scene points it at the hero's side so a gap is always reachable).
    static func gapCenters(at t: Double, startAngle: CGFloat, attack a: BossAttackDef) -> [CGFloat] {
        let n = max(1, a.gaps ?? 1)
        let turn = CGFloat((a.sweepDegPerSec ?? 0) * t) * .pi / 180
        return (0..<n).map { startAngle + turn + 2 * .pi * CGFloat($0) / CGFloat(n) }
    }

    /// Half-width of the hero's body as seen from the boss, in radians.
    static func angularHalfWidth(heroDistance d: CGFloat, heroRadius r: CGFloat) -> CGFloat {
        guard d > r else { return .pi }
        return asin(r / d)
    }

    /// True when the hero (whole body) is inside one of the gaps.
    static func isInGap(heroAngle: CGFloat, heroDistance d: CGFloat, heroRadius r: CGFloat, at t: Double,
                        startAngle: CGFloat, attack a: BossAttackDef) -> Bool {
        let half = CGFloat(a.effectiveGapDeg / 2) * .pi / 180
        let body = angularHalfWidth(heroDistance: d, heroRadius: r)
        return gapCenters(at: t, startAngle: startAngle, attack: a).contains {
            abs(AimAssist.angleDifference(from: $0, to: heroAngle)) + body <= half
        }
    }

    /// The beam hits the hero at time `t` of the sweep (0 … `sweepSec`).
    static func hits(heroAngle: CGFloat, heroDistance d: CGFloat, heroRadius r: CGFloat, at t: Double,
                     startAngle: CGFloat, attack a: BossAttackDef, hasLineOfSight: Bool = true) -> Bool {
        guard t >= 0, t <= a.effectiveSweepSec, hasLineOfSight, d - r <= CGFloat(a.range) else { return false }
        return !isInGap(heroAngle: heroAngle, heroDistance: d, heroRadius: r, at: t, startAngle: startAngle, attack: a)
    }
}

/// Phase 3 dash (GDD §9): a straight run from the boss toward the hero's position at telegraph
/// end, across the arena. The body (circle of `radius`) stops at the first pillar (→ dizzy
/// `pillarDizzySec`) or at the arena wall. Pure geometry on world rects.
nonisolated enum BossDash {
    struct Path: Sendable, Equatable {
        let start: CGPoint
        let end: CGPoint
        /// Index into the pillar list when a pillar stopped the dash.
        let pillarIndex: Int?

        var length: CGFloat { hypot(end.x - start.x, end.y - start.y) }
        var hitPillar: Bool { pillarIndex != nil }
    }

    /// `bounds`: the walkable arena rect; `pillars`: pillar rects (world points).
    static func path(from start: CGPoint, toward target: CGPoint, radius: CGFloat, maxDistance: CGFloat,
                     bounds: CGRect, pillars: [CGRect]) -> Path {
        var dx = target.x - start.x, dy = target.y - start.y
        let len = hypot(dx, dy)
        guard len > 0.001 else { return Path(start: start, end: start, pillarIndex: nil) }
        dx /= len; dy /= len
        // Wall: where the body centre leaves the bounds shrunk by the radius.
        let inner = bounds.insetBy(dx: radius, dy: radius)
        var tMax = min(maxDistance, exitDistance(start, dx, dy, inner))
        var hit: Int?
        for (i, p) in pillars.enumerated() {
            if let t = entryDistance(start, dx, dy, p.insetBy(dx: -radius, dy: -radius)), t < tMax {
                tMax = t
                hit = i
            }
        }
        tMax = max(0, tMax)
        return Path(start: start, end: CGPoint(x: start.x + dx * tMax, y: start.y + dy * tMax), pillarIndex: hit)
    }

    /// Distance along the ray until it leaves `r` (start assumed inside).
    private static func exitDistance(_ o: CGPoint, _ dx: CGFloat, _ dy: CGFloat, _ r: CGRect) -> CGFloat {
        var t = CGFloat.infinity
        if dx > 0 { t = min(t, (r.maxX - o.x) / dx) } else if dx < 0 { t = min(t, (r.minX - o.x) / dx) }
        if dy > 0 { t = min(t, (r.maxY - o.y) / dy) } else if dy < 0 { t = min(t, (r.minY - o.y) / dy) }
        return max(0, t)
    }

    /// Distance along the ray where it enters `r` (slab test), nil when it misses or is behind.
    private static func entryDistance(_ o: CGPoint, _ dx: CGFloat, _ dy: CGFloat, _ r: CGRect) -> CGFloat? {
        var tNear = -CGFloat.infinity, tFar = CGFloat.infinity
        for (oc, dc, lo, hi) in [(o.x, dx, r.minX, r.maxX), (o.y, dy, r.minY, r.maxY)] {
            if abs(dc) < 1e-9 {
                if oc < lo || oc > hi { return nil }
            } else {
                var a = (lo - oc) / dc, b = (hi - oc) / dc
                if a > b { swap(&a, &b) }
                tNear = max(tNear, a)
                tFar = min(tFar, b)
            }
        }
        guard tNear <= tFar, tFar >= 0 else { return nil }
        return max(0, tNear)
    }

    /// Hero hit test along a dash segment (body circles touch).
    static func hits(_ path: Path, hero: CGPoint, heroRadius: CGFloat, bossRadius: CGFloat) -> Bool {
        let ax = path.start.x, ay = path.start.y
        let bx = path.end.x - ax, by = path.end.y - ay
        let l2 = bx * bx + by * by
        let t = l2 > 0 ? max(0, min(1, ((hero.x - ax) * bx + (hero.y - ay) * by) / l2)) : 0
        let cx = ax + bx * t, cy = ay + by * t
        return hypot(hero.x - cx, hero.y - cy) <= heroRadius + bossRadius
    }
}
