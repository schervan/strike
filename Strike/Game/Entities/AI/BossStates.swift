import GameplayKit
import SpriteKit

/// MEGA-MECH (GDD §9): the pure `BossBrain` decides; `BossDirector` moves the boss, runs the
/// attacks and feeds the brain. This state only keeps the generic AI out of the way.
final class BossState: EnemyState, @unchecked Sendable {
    @MainActor override func enter() { enemy.desiredVelocity = .zero }
    @MainActor override func tick(dt: Double) {}
}
