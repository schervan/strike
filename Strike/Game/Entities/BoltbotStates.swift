import GameplayKit
import SpriteKit

/// Base for enemy brain states. `GKState` callbacks are nonisolated; the state machine is only
/// ever driven from `EnemyNode.tick` on the main actor, so they hop in with `assumeIsolated`.
/// `@unchecked Sendable` is sound for the same reason: states are only touched on the main actor.
class EnemyState: GKState, @unchecked Sendable {
    unowned let enemy: EnemyNode

    init(enemy: EnemyNode) {
        self.enemy = enemy
        super.init()
    }

    override func didEnter(from previousState: GKState?) {
        MainActor.assumeIsolated { enter() }
    }

    override func update(deltaTime seconds: TimeInterval) {
        MainActor.assumeIsolated { tick(dt: seconds) }
    }

    override func isValidNextState(_ stateClass: AnyClass) -> Bool {
        ObjectIdentifier(stateClass) != ObjectIdentifier(type(of: self))
    }

    @MainActor func enter() {}
    @MainActor func tick(dt: Double) {}

    @MainActor var distanceToHero: CGFloat {
        guard let w = enemy.world else { return .infinity }
        return hypot(w.heroPosition.x - enemy.position.x, w.heroPosition.y - enemy.position.y)
    }

    @MainActor var canSeeHero: Bool {
        guard let w = enemy.world else { return false }
        return w.solidGrid.hasLineOfSight(from: enemy.position, to: w.heroPosition)
    }
}

/// Waits until the hero is within `detectRange` with line of sight.
final class IdleState: EnemyState, @unchecked Sendable {
    @MainActor override func enter() {
        enemy.desiredVelocity = .zero
    }

    @MainActor override func tick(dt: Double) {
        enemy.desiredVelocity = .zero
        if distanceToHero <= CGFloat(enemy.def.detectRange), canSeeHero {
            stateMachine?.enter(AlertState.self)
        }
    }
}

/// Shows "!" for `alertSec` (GDD §8 fairness) before chasing.
final class AlertState: EnemyState, @unchecked Sendable {
    private var remaining: Double = 0

    @MainActor override func enter() {
        remaining = enemy.def.effectiveAlertSec
        enemy.desiredVelocity = .zero
        enemy.showAlert(duration: remaining)
        if let w = enemy.world {
            enemy.animator.face(along: CGVector(dx: w.heroPosition.x - enemy.position.x, dy: 0))
        }
    }

    @MainActor override func tick(dt: Double) {
        enemy.desiredVelocity = .zero
        remaining -= dt
        if remaining <= 0 { stateMachine?.enter(ChaseState.self) }
    }
}

/// Chases the hero (straight when visible, else along the grid path); every `hopEverySec` it
/// may pause for `hopPauseSec`. Leash: far away for `returnAfterSec` → `ReturnHomeState`.
final class ChaseState: EnemyState, @unchecked Sendable {
    private var hopTimer: Double = 0

    @MainActor override func enter() {
        hopTimer = enemy.def.hopEverySec ?? 0
    }

    @MainActor override func tick(dt: Double) {
        guard let w = enemy.world else { return }
        if enemy.leash.update(dt: dt, distanceToHero: Double(distanceToHero), detectRange: enemy.def.detectRange) {
            stateMachine?.enter(ReturnHomeState.self)
            return
        }
        enemy.moveToward(w.heroPosition, dt: dt)
        guard let every = enemy.def.hopEverySec, every > 0,
              let chance = enemy.def.hopChance, chance > 0 else { return }
        hopTimer -= dt
        if hopTimer <= 0 {
            hopTimer += every
            if Double(w.random.nextUniform()) < chance {
                stateMachine?.enter(HopState.self)
            }
        }
    }
}

/// Breather pause (a small hop in place), then back to chasing.
final class HopState: EnemyState, @unchecked Sendable {
    private var remaining: Double = 0

    @MainActor override func enter() {
        remaining = enemy.def.hopPauseSec ?? 0
        enemy.desiredVelocity = .zero
        let up = SKAction.moveBy(x: 0, y: 8, duration: remaining * 0.4)
        up.timingMode = .easeOut
        let down = SKAction.moveBy(x: 0, y: -8, duration: remaining * 0.4)
        down.timingMode = .easeIn
        enemy.animator.root.run(.sequence([up, down]), withKey: "hop")
    }

    @MainActor override func tick(dt: Double) {
        enemy.desiredVelocity = .zero
        remaining -= dt
        if remaining <= 0 { stateMachine?.enter(ChaseState.self) }
    }
}

/// Leash (GDD §8): walk back to the spawn point, heal to full on arrival, then idle. The hero
/// is ignored on the way home.
final class ReturnHomeState: EnemyState, @unchecked Sendable {
    @MainActor override func enter() {
        if !enemy.leash.isReturning { enemy.leash.forceReturn() }
        enemy.clearPath()
    }

    @MainActor override func tick(dt: Double) {
        enemy.moveToward(enemy.spawnPoint, dt: dt)
        if enemy.leash.updateReturn(position: enemy.position, home: enemy.spawnPoint, health: &enemy.health) {
            enemy.desiredVelocity = .zero
            stateMachine?.enter(IdleState.self)
        }
    }
}

/// Terminal state: no AI, the node is shrinking into sparkles.
final class PoweredDownState: EnemyState, @unchecked Sendable {
    @MainActor override func enter() {
        enemy.desiredVelocity = .zero
        enemy.animator.root.removeAction(forKey: "hop")
    }

    override func isValidNextState(_ stateClass: AnyClass) -> Bool { false }
}
