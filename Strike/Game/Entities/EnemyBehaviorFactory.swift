import GameplayKit

/// `EnemyDef.behavior` → the enemy's state machine (GDD §8.1). Replaces the M2 fallback where
/// every enemy used the chaser brain (DECISIONS 2026-11-22). Unknown behaviours chase.
@MainActor
enum EnemyBehaviorFactory {
    static func make(for e: EnemyNode) -> (states: [GKState], active: AnyClass) {
        var states: [GKState] = [IdleState(enemy: e), AlertState(enemy: e), ReturnHomeState(enemy: e),
                                 PoweredDownState(enemy: e)]
        let active: AnyClass
        switch e.def.behavior {
        case EnemyDef.kiter where KiterPolicy.Config(def: e.def) != nil:
            states.append(KiteState(enemy: e)); active = KiteState.self
        case EnemyDef.shielded where ShieldPolicy.Config(def: e.def) != nil:
            states.append(ShieldState(enemy: e)); active = ShieldState.self
        case EnemyDef.turret where TurretPolicy.Config(def: e.def) != nil:
            states.append(TurretState(enemy: e)); active = TurretState.self
        case EnemyDef.boss:
            states.append(BossState(enemy: e)); active = BossState.self
        default:
            // chaser, splitter (the split happens on power-down, CombatController).
            states += [ChaseState(enemy: e), HopState(enemy: e)]; active = ChaseState.self
        }
        return (states, active)
    }
}
