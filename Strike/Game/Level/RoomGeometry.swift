import CoreGraphics
import Foundation

/// Solid geometry of a room for line-of-sight and steering queries. Pure value type.
nonisolated struct RoomGeometry: Sendable, Equatable {
    /// Whole room including the outer wall ring.
    let bounds: CGRect
    /// Walkable interior (inside the outer walls).
    let interior: CGRect
    /// Solid rectangles (outer walls and pillars).
    let solids: [CGRect]

    /// True when the segment from `a` to `b` does not cross any solid.
    func hasLineOfSight(from a: CGPoint, to b: CGPoint) -> Bool {
        !solids.contains { Self.segment(a, b, intersects: $0) }
    }

    /// True if a circle at `p` with `radius` overlaps a solid or leaves the interior.
    func isBlocked(_ p: CGPoint, radius: CGFloat) -> Bool {
        if !interior.insetBy(dx: radius, dy: radius).contains(p) { return true }
        return solids.contains { $0.insetBy(dx: -radius, dy: -radius).contains(p) }
    }

    /// Liang–Barsky segment/rect test.
    static func segment(_ a: CGPoint, _ b: CGPoint, intersects r: CGRect) -> Bool {
        let dx = b.x - a.x, dy = b.y - a.y
        var t0: CGFloat = 0, t1: CGFloat = 1
        for (p, q) in [(-dx, a.x - r.minX), (dx, r.maxX - a.x), (-dy, a.y - r.minY), (dy, r.maxY - a.y)] {
            if p == 0 {
                if q < 0 { return false }
            } else {
                let t = q / p
                if p < 0 { if t > t1 { return false }; if t > t0 { t0 = t } }
                else { if t < t0 { return false }; if t < t1 { t1 = t } }
            }
        }
        return t0 <= t1
    }
}
