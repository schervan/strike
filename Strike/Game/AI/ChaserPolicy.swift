import CoreGraphics
import Foundation

/// Chaser movement (GDD §8.1 boltbot, slimemutant_small, and the slow chase of the splitter):
/// straight seek when a body-wide line is clear, else the next grid waypoint (re-planned every
/// `repathSec`); steering adds separation from same-type allies and wall feelers. Plus the hop
/// breather timer. Pure: the grid is a value, the pathfinder and the allies come in as closures.
/// The M2 code from `EnemyNode` / `BoltbotStates`, unchanged in behaviour.
nonisolated struct ChaserPolicy: Sendable, Equatable {
    /// Re-plan interval for grid paths (AI cadence, not balance).
    static let repathSec = 0.25

    private(set) var waypoint: CGPoint?
    private(set) var waypointTarget: CGPoint?
    private var repathTimer: Double = 0

    /// Drops the cached waypoint (doors changed, teleported).
    mutating func clearPath() {
        waypoint = nil
        waypointTarget = nil
    }

    /// Velocity toward `target`. `found` is false when no path exists (velocity zero).
    mutating func velocity(from position: CGPoint, toward target: CGPoint, dt: Double, speed: CGFloat,
                           radius: CGFloat, separation: CGFloat, grid: TileGrid,
                           allies: () -> [CGPoint],
                           nextWaypoint: (CGPoint, CGPoint, CGFloat) -> CGPoint?) -> (velocity: CGVector, found: Bool) {
        func steer(_ to: CGPoint) -> CGVector {
            Self.steer(from: position, toward: to, speed: speed, radius: radius, separation: separation,
                       allies: allies, isBlocked: { grid.isBlocked($0, radius: $1) })
        }
        if grid.isSweepClear(from: position, to: target, radius: radius * 0.9) {
            waypoint = nil
            return (steer(target), true)
        }
        repathTimer -= dt
        let reached = waypoint.map { hypot($0.x - position.x, $0.y - position.y) < radius } ?? true
        if waypoint == nil || reached || repathTimer <= 0
            || waypointTarget.map({ grid.cell(at: $0) != grid.cell(at: target) }) ?? true {
            repathTimer = Self.repathSec
            waypointTarget = target
            waypoint = nextWaypoint(position, target, radius)
        }
        guard let w = waypoint else { return (.zero, false) }
        return (steer(w), true)
    }

    /// Steering toward `target`: seek + separation from `allies` (same-type, alive, not self) +
    /// wall feelers that try rotated headings, preferring the side closer to the direct line.
    static func steer(from position: CGPoint, toward target: CGPoint, speed: CGFloat, radius: CGFloat,
                      separation sepDist: CGFloat, allies: () -> [CGPoint],
                      isBlocked: (CGPoint, CGFloat) -> Bool) -> CGVector {
        var dx = target.x - position.x, dy = target.y - position.y
        let d = hypot(dx, dy)
        guard d > radius * 0.5 else { return .zero }
        dx /= d; dy /= d

        if sepDist > 0 {
            var sx: CGFloat = 0, sy: CGFloat = 0
            for other in allies() {
                let ox = position.x - other.x, oy = position.y - other.y
                let od = hypot(ox, oy)
                if od > 0, od < sepDist {
                    let w = (sepDist - od) / sepDist
                    sx += ox / od * w; sy += oy / od * w
                }
            }
            dx += sx * 1.5; dy += sy * 1.5
            let l = hypot(dx, dy)
            if l > 0 { dx /= l; dy /= l }
        }

        let probe = radius + 20
        func free(_ a: CGFloat) -> Bool {
            let p = CGPoint(x: position.x + cos(a) * probe, y: position.y + sin(a) * probe)
            return !isBlocked(p, radius * 0.8)
        }
        var heading = atan2(dy, dx)
        if !free(heading) {
            let toTarget = atan2(target.y - position.y, target.x - position.x)
            let options: [CGFloat] = [0.6, -0.6, 1.2, -1.2, 1.8, -1.8]
            let sorted = options.sorted {
                abs(AimAssist.angleDifference(from: toTarget, to: heading + $0))
                    < abs(AimAssist.angleDifference(from: toTarget, to: heading + $1))
            }
            if let alt = sorted.first(where: { free(heading + $0) }) { heading += alt }
        }
        return CGVector(dx: cos(heading) * speed, dy: sin(heading) * speed)
    }

    /// Hop breather (GDD §8.1): every `hopEverySec` a `hopChance` roll for a `hopPauseSec` pause.
    struct Hop: Sendable, Equatable {
        private(set) var timer: Double = 0

        mutating func reset(every: Double?) {
            timer = every ?? 0
        }

        /// True when a hop starts now. `roll` (0…1) is called only when the timer elapsed.
        mutating func tick(dt: Double, every: Double?, chance: Double?, roll: () -> Double) -> Bool {
            guard let every, every > 0, let chance, chance > 0 else { return false }
            timer -= dt
            guard timer <= 0 else { return false }
            timer += every
            return roll() < chance
        }
    }
}
