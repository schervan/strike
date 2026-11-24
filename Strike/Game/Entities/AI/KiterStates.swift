import GameplayKit
import SpriteKit

/// Laserdrone (GDD §8.1) driven by `KiterPolicy`: band keeping + strafe, then glow and one laser
/// ball. Without line of sight it paths toward the hero until it sees it again.
final class KiteState: EnemyState, @unchecked Sendable {
    @MainActor override func enter() {
        if enemy.kiter == nil, let c = KiterPolicy.Config(def: enemy.def) { enemy.kiter = KiterPolicy(config: c) }
    }

    @MainActor override func tick(dt: Double) {
        guard let w = enemy.world, var k = enemy.kiter else { return }
        if leashSendsHome(dt: dt) { EnemyFX.clearTelegraph(enemy); return }
        let see = canSeeHero
        if !see, !k.isTelegraphing {
            enemy.moveToward(w.heroPosition, dt: dt)
            return
        }
        let grid = w.solidGrid, r = enemy.radius
        let out = k.tick(dt: dt, position: enemy.position, hero: w.heroPosition, canSee: see,
                         isFree: { !grid.isBlocked($0, radius: r) })
        enemy.kiter = k
        enemy.desiredVelocity = out.velocity
        enemy.animator.face(along: CGVector(dx: w.heroPosition.x - enemy.position.x, dy: 0))
        switch out.event {
        case .telegraph:
            EnemyFX.showTelegraph(enemy, kind: .droneGlow, sec: k.config.telegraphSec)
        case .fire(let a):
            EnemyFX.clearTelegraph(enemy, pop: true)
            if let attack = enemy.def.attack { w.enemyFire(enemy, angles: [a], attack: attack) }
        case .none:
            break
        }
    }

    @MainActor override func exit() { EnemyFX.clearTelegraph(enemy) }
}
