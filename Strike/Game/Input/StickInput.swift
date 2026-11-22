import CoreGraphics
import Foundation

/// One floating virtual stick (GDD §3.2). Pure value type; all lengths in points.
nonisolated struct StickInput: Sendable, Equatable {
    /// Where the base is drawn (follows the finger when dragged far away).
    private(set) var origin: CGPoint
    private(set) var touch: CGPoint
    let radius: CGFloat
    /// Fraction of `radius` below which the stick is inactive.
    let deadZone: CGFloat
    /// Fraction of `radius` at and above which magnitude counts as 1.
    let fullAt: CGFloat

    init(origin: CGPoint, touch: CGPoint, radius: CGFloat, deadZone: CGFloat, fullAt: CGFloat) {
        self.origin = origin
        self.touch = touch
        self.radius = max(1, radius)
        self.deadZone = deadZone
        self.fullAt = fullAt
    }

    private var offset: CGVector { CGVector(dx: touch.x - origin.x, dy: touch.y - origin.y) }
    var distance: CGFloat { hypot(offset.dx, offset.dy) }

    /// Unclamped-to-dead-zone magnitude, 0…1.
    var rawMagnitude: CGFloat { min(1, distance / radius) }

    /// True at or above the dead zone (move: walking; aim: firing).
    var isActive: Bool { rawMagnitude >= deadZone && distance > 0 }

    /// 0 below the dead zone, 1 at or above `fullAt`, raw value in between.
    var magnitude: CGFloat {
        guard isActive else { return 0 }
        return rawMagnitude >= fullAt ? 1 : rawMagnitude
    }

    /// Unit direction from origin to touch (zero vector when the finger is on the origin).
    var direction: CGVector {
        let d = distance
        guard d > 0 else { return .zero }
        return CGVector(dx: offset.dx / d, dy: offset.dy / d)
    }

    var angle: CGFloat { atan2(offset.dy, offset.dx) }

    /// Knob position, clamped to the stick radius.
    var knob: CGPoint {
        let r = min(distance, radius)
        return CGPoint(x: origin.x + direction.dx * r, y: origin.y + direction.dy * r)
    }

    /// Moves the finger. If it is more than `followFactor × radius` from the base, the base
    /// is dragged along so it stays exactly at that distance.
    mutating func move(touch newTouch: CGPoint, followFactor: CGFloat) {
        touch = newTouch
        let limit = radius * followFactor
        let d = distance
        if d > limit, d > 0 {
            let dir = direction
            origin = CGPoint(x: touch.x - dir.dx * limit, y: touch.y - dir.dy * limit)
        }
    }
}
