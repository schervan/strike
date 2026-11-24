import GameplayKit
import SpriteKit

/// Sporeplant (GDD §8.1) driven by `TurretPolicy`: never moves; petals open, then 3 spores.
/// Shy (closed, half damage) while the hero stands too close.
final class TurretState: EnemyState, @unchecked Sendable {
    @MainActor override func enter() {
        if enemy.turret == nil, let c = TurretPolicy.Config(def: enemy.def) { enemy.turret = TurretPolicy(config: c) }
        enemy.desiredVelocity = .zero
    }

    @MainActor override func tick(dt: Double) {
        guard let w = enemy.world, var t = enemy.turret else { return }
        enemy.desiredVelocity = .zero
        if !t.isTelegraphing, leashSendsHome(dt: dt) { return }
        let out = t.tick(dt: dt, position: enemy.position, hero: w.heroPosition, canSee: canSeeHero)
        enemy.turret = t
        enemy.animator.face(along: CGVector(dx: w.heroPosition.x - enemy.position.x, dy: 0))
        switch out.event {
        case .petalsOpen: EnemyFX.showTelegraph(enemy, kind: .sporePetals, sec: t.config.telegraphSec)
        case .fire(let angles):
            EnemyFX.clearTelegraph(enemy, pop: true)
            if let a = enemy.def.attack { w.enemyFire(enemy, angles: angles, attack: a) }
        case .closed:
            EnemyFX.clearTelegraph(enemy)
            EnemyFX.setShy(enemy, true)
        case .reopened: EnemyFX.setShy(enemy, false)
        case .none: break
        }
    }

    @MainActor override func exit() {
        EnemyFX.clearTelegraph(enemy)
        EnemyFX.setShy(enemy, false)
    }
}
