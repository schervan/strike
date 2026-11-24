import GameplayKit
import SpriteKit

/// Shield android (GDD §8.1) driven by `ShieldPolicy`: turns toward the hero, crouch + glow,
/// dash along its facing, dizzy. Walls stop the dash early (dizzy at once).
final class ShieldState: EnemyState, @unchecked Sendable {
    @MainActor override func enter() {
        if enemy.shield == nil, let c = ShieldPolicy.Config(def: enemy.def), let w = enemy.world {
            let face = atan2(w.heroPosition.y - enemy.position.y, w.heroPosition.x - enemy.position.x)
            enemy.shield = ShieldPolicy(config: c, facing: face)
        }
    }

    @MainActor override func tick(dt: Double) {
        guard let w = enemy.world, var s = enemy.shield else { return }
        if s.mode == .walk, leashSendsHome(dt: dt) { return }
        let see = canSeeHero
        var out = s.tick(dt: dt, position: enemy.position, hero: w.heroPosition, canSee: see)
        if s.isDashing {
            let probe = CGPoint(x: enemy.position.x + out.velocity.dx * 0.06, y: enemy.position.y + out.velocity.dy * 0.06)
            if w.solidGrid.isBlocked(probe, radius: enemy.radius * 0.9) {
                out = (.zero, s.dashBlocked())
            }
        }
        enemy.shield = s
        switch s.mode {
        case .walk:
            if see { enemy.desiredVelocity = out.velocity } else { enemy.moveToward(w.heroPosition, dt: dt) }
            if see, w.solidGrid.isBlocked(CGPoint(x: enemy.position.x + cos(s.facing) * (enemy.radius + 12),
                                                  y: enemy.position.y + sin(s.facing) * (enemy.radius + 12)),
                                          radius: enemy.radius * 0.8) {
                enemy.moveToward(w.heroPosition, dt: dt)
            }
        default:
            enemy.desiredVelocity = out.velocity
        }
        switch out.event {
        case .crouch: EnemyFX.showTelegraph(enemy, kind: .shieldDash, sec: s.config.telegraphSec)
        case .dash: EnemyFX.clearTelegraph(enemy)
        case .dizzy: EnemyFX.setDizzy(enemy, true)
        case .recovered: EnemyFX.setDizzy(enemy, false)
        case .none: break
        }
    }

    @MainActor override func exit() {
        EnemyFX.clearTelegraph(enemy)
        EnemyFX.setDizzy(enemy, false)
    }
}
