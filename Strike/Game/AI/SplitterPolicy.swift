import CoreGraphics
import Foundation

/// Slimemutant (GDD §8.1): a slow chaser (movement = `ChaserPolicy` at its own `moveSpeed`) that
/// squashes when hit and splits on power-down into `splitInto.count` smalls at ±`spawnOffset`.
/// The smalls pop out over `spawnDelaySec`: harmless and not damageable until then. Smalls never
/// split. Spawn points are never inside a wall. Pure.
nonisolated enum SplitterPolicy {
    /// One child to spawn when the parent powers down.
    struct Spawn: Sendable, Equatable {
        let enemyId: String
        let position: CGPoint
        let delaySec: Double
    }

    /// Squash-and-grow on a hit (presentation hook for the state; GDD §8.1). x/y scale peaks.
    static let squashScale = CGSize(width: 1.25, height: 0.8)

    /// The children of `def` powering down at `origin`. Empty when it does not split (smalls).
    /// `isFree(point, radius)` is false inside walls. Children sit at ±offset along x; a blocked
    /// side tries other angles, then shorter offsets, and finally the parent's own spot.
    static func spawns(for def: EnemyDef, childRadius: CGFloat, at origin: CGPoint,
                       isFree: (CGPoint, CGFloat) -> Bool) -> [Spawn] {
        guard let s = def.splitInto, s.count > 0, s.enemyId != def.id else { return [] }
        let offset = CGFloat(s.spawnOffset)
        var out: [Spawn] = []
        for i in 0..<s.count {
            let base = CGFloat.pi * 2 * CGFloat(i) / CGFloat(s.count)   // 2 children: 0 and π → ±x
            out.append(Spawn(enemyId: s.enemyId,
                             position: point(around: origin, baseAngle: base, offset: offset, radius: childRadius,
                                             taken: out.map(\.position), isFree: isFree),
                             delaySec: s.spawnDelaySec))
        }
        return out
    }

    private static func point(around o: CGPoint, baseAngle: CGFloat, offset: CGFloat, radius: CGFloat,
                              taken: [CGPoint], isFree: (CGPoint, CGFloat) -> Bool) -> CGPoint {
        let turns: [CGFloat] = [0, 0.5, -0.5, 1.0, -1.0, 1.5, -1.5, .pi]
        for scale in [1.0, 0.75, 0.5, 0.25] as [CGFloat] {
            for t in turns {
                let a = baseAngle + t
                let p = CGPoint(x: o.x + cos(a) * offset * scale, y: o.y + sin(a) * offset * scale)
                let clear = !taken.contains { hypot($0.x - p.x, $0.y - p.y) < radius }
                if isFree(p, radius), clear { return p }
            }
        }
        return o
    }

    /// The pop-out window of a fresh small.
    struct PopOut: Sendable, Equatable {
        private(set) var remaining: Double

        init(delaySec: Double) { remaining = max(0, delaySec) }

        var isActive: Bool { remaining > 0 }
        /// Contact damage is off during the pop-out.
        var isHarmless: Bool { isActive }
        /// Hero shots pass through during the pop-out.
        var isDamageable: Bool { !isActive }
        /// 0 → 1 scale-in progress.
        func progress(total: Double) -> Double { total > 0 ? 1 - remaining / total : 1 }

        mutating func tick(dt: Double) { remaining = max(0, remaining - dt) }
    }
}
