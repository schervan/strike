import GameplayKit
import SpriteKit

/// What an enemy brain may ask the scene.
@MainActor
protocol EnemyWorld: AnyObject {
    var heroPosition: CGPoint { get }
    /// Current solid map (closed doors are walls).
    var solidGrid: TileGrid { get }
    var pathfinder: Pathfinder { get }
    var activeEnemies: [EnemyNode] { get }
    var random: GKRandom { get }
    /// An idle enemy noticed the hero (alert "!" starts).
    func enemyDidSpotHero(_ enemy: EnemyNode)
    /// An enemy attack fires projectiles along `angles` (laser ball, spores).
    func enemyFire(_ enemy: EnemyNode, angles: [CGFloat], attack: EnemyAttackDef)
}

extension EnemyWorld {
    func enemyDidSpotHero(_ enemy: EnemyNode) {}
    func enemyFire(_ enemy: EnemyNode, angles: [CGFloat], attack: EnemyAttackDef) {}
}

/// Generic enemy built from an `EnemyDef`: key-pose sprite, `PoseAnimator`, `Health` and a
/// `GKStateMachine` brain made by `EnemyBehaviorFactory` (GDD §8.1). The behaviour policies live
/// on the node so combat can ask them (shield block, dizzy/shy damage, pop-out).
@MainActor
class EnemyNode: SKNode {
    let def: EnemyDef
    let animator: PoseAnimator
    var health: Health
    let spawnPoint: CGPoint
    /// Room the enemy was spawned in (leash target).
    let homeRoomId: Int?
    var leash: Leash
    weak var world: EnemyWorld?
    private(set) var brain: GKStateMachine!
    /// The behaviour's main state (Alert enters it).
    private(set) var activeState: AnyClass = ChaseState.self

    /// Desired walking velocity set by the brain each frame.
    var desiredVelocity = CGVector.zero
    private var knockbackVelocity = CGVector.zero
    private var knockbackRemaining: Double = 0

    private let alertBubble: SKLabelNode

    /// Seek, grid path and steering (pure, M4-4).
    private var chaser = ChaserPolicy()
    /// Behaviour policies (only the one matching `def.behavior` is set).
    var kiter: KiterPolicy?
    var shield: ShieldPolicy?
    var turret: TurretPolicy?
    /// Slime child popping out (GDD §8.1): harmless and not damageable meanwhile.
    private(set) var popOut: SplitterPolicy.PopOut?
    private var popFrom = CGPoint.zero, popTo = CGPoint.zero, popTotal = 0.0
    /// Boss-phase spawn id (core carriers) and the item it drops for sure.
    var bossSpawnId: Int?
    private(set) var carriesItem: String?
    /// Behaviour visuals (EnemyFX): telegraph, shield arc, dizzy stars, carry icon.
    var telegraphNode: SKNode?
    var shieldArc: SKNode?
    var dizzyStars: SKNode?
    var carryIcon: SKNode?
    /// Dark floor (L4/L5): telegraphs get the white inner line (ART_BIBLE §15).
    var darkFloor = false
    /// Power-down completion (loot, removal). Fired by the animation, or by `tick` once the
    /// animation time has passed, so game logic never depends on rendering (headless tests).
    private var powerDownDone: (@MainActor () -> Void)?
    private var powerDownAge = 0.0

    init(def: EnemyDef, at point: CGPoint, world: EnemyWorld, homeRoomId: Int? = nil, leash: LeashRulesDef,
         texture: String? = nil, atlas: Textures.Atlas = .enemies, style: PoseStyle = .boltbot) {
        self.def = def
        self.spawnPoint = point
        self.homeRoomId = homeRoomId
        self.leash = Leash(rules: leash)
        self.world = world
        animator = PoseAnimator(textureName: texture ?? def.keyPoseTextureName, atlas: atlas, style: style)
        health = Health(max: def.hp)
        alertBubble = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        super.init()
        name = "enemy_\(def.id)"
        position = point
        animator.root.position = CGPoint(x: 0, y: -CGFloat(def.radius))
        addChild(animator.root)

        alertBubble.text = "!"
        alertBubble.fontSize = 30
        alertBubble.fontColor = Palette.star
        alertBubble.verticalAlignmentMode = .bottom
        alertBubble.position = CGPoint(x: 0, y: animator.sprite.size.height - CGFloat(def.radius) + 2)
        alertBubble.zPosition = 2
        alertBubble.alpha = 0
        let outline = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        outline.text = "!"
        outline.fontSize = 30
        outline.fontColor = Palette.outline
        outline.verticalAlignmentMode = .bottom
        outline.position = CGPoint(x: 1.5, y: -1.5)
        outline.zPosition = -1
        alertBubble.addChild(outline)
        addChild(alertBubble)

        let body = SKPhysicsBody(circleOfRadius: CGFloat(def.radius))
        body.affectedByGravity = false
        body.allowsRotation = false
        body.linearDamping = 0
        body.friction = 0
        body.restitution = 0
        body.categoryBitMask = PhysicsCategory.enemy
        body.collisionBitMask = PhysicsCategory.wall | PhysicsCategory.enemy | PhysicsCategory.crate
        body.contactTestBitMask = PhysicsCategory.heroShot
        physicsBody = body

        let made = EnemyBehaviorFactory.make(for: self)
        activeState = made.active
        brain = GKStateMachine(states: made.states)
        brain.enter(IdleState.self)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not supported") }

    var radius: CGFloat { CGFloat(def.radius) }
    var isPoweredDown: Bool { brain.currentState is PoweredDownState }
    var isAware: Bool { !(brain.currentState is IdleState) && !isPoweredDown }
    var isReturningHome: Bool { brain.currentState is ReturnHomeState }
    var isBoss: Bool { def.behavior == EnemyDef.boss }

    /// Contact damage is off (slime pop-out).
    var isHarmless: Bool { popOut?.isActive ?? false }
    /// Hero shots pass through (slime pop-out).
    var isDamageable: Bool { !(popOut?.isActive ?? false) }
    /// Dizzy (shield) and shy (turret) damage factor.
    var damageMultiplier: Double { shield?.damageMultiplier ?? turret?.damageMultiplier ?? 1 }
    /// The front shield blocks a shot travelling along `angle`.
    func blocksShot(angle: CGFloat) -> Bool { shield?.blocks(shotAngle: angle) ?? false }
    /// Touch damage right now: the shield dash hits harder (`attack.damage`).
    var contactDamageNow: Int {
        if shield?.isDashing == true, let a = def.attack { return a.damage }
        return def.contactDamage
    }

    /// Slime child: pops out from `from` to its own position over `delaySec`.
    func beginPopOut(from: CGPoint, delaySec: Double) {
        popOut = SplitterPolicy.PopOut(delaySec: delaySec)
        popFrom = from
        popTo = position
        popTotal = max(0.01, delaySec)
        position = from
        animator.root.setScale(0.2)
    }

    /// The boss gives this spawn an item to drop (energy core).
    func setCarry(_ itemId: String?) {
        carriesItem = itemId
        EnemyFX.updateCarryIcon(self)
    }

    func showAlert(duration: Double) {
        alertBubble.removeAllActions()
        alertBubble.alpha = 1
        alertBubble.setScale(0)
        alertBubble.run(.sequence([
            .scale(to: 1.2, duration: 0.1),
            .scale(to: 1.0, duration: 0.05),
            .wait(forDuration: max(0, duration - 0.15)),
            .fadeOut(withDuration: 0.1),
        ]))
    }

    func knockBack(along direction: CGVector, distance: CGFloat) {
        let len = hypot(direction.dx, direction.dy)
        guard len > 0, distance > 0 else { return }
        let sec = def.effectiveKnockbackSec
        guard sec > 0 else { return }
        let speed = distance / CGFloat(sec)
        knockbackVelocity = CGVector(dx: direction.dx / len * speed, dy: direction.dy / len * speed)
        knockbackRemaining = sec
    }

    /// Runs the brain, then writes the physics velocity and drives the pose.
    func tick(dt: Double) {
        if var p = popOut, p.isActive {
            p.tick(dt: dt)
            popOut = p
            let k = CGFloat(p.progress(total: popTotal))
            let e = 1 - (1 - k) * (1 - k)
            position = CGPoint(x: popFrom.x + (popTo.x - popFrom.x) * e, y: popFrom.y + (popTo.y - popFrom.y) * e)
            animator.root.setScale(0.2 + 0.8 * e)
            animator.sprite.alpha = Int(p.remaining / 0.08) % 2 == 0 ? 1 : 0.6
            physicsBody?.velocity = .zero
            if !p.isActive { animator.root.setScale(1); animator.sprite.alpha = 1 }
            animator.update(dt: dt)
            return
        }
        brain.update(deltaTime: dt)
        guard !isPoweredDown else {
            animator.update(dt: dt)
            if powerDownDone != nil {
                powerDownAge += dt
                if powerDownAge > animator.style.powerDownSec + 0.2 { finishPowerDown() }
            }
            return
        }
        var v = desiredVelocity
        if knockbackRemaining > 0 {
            knockbackRemaining -= dt
            v.dx += knockbackVelocity.dx
            v.dy += knockbackVelocity.dy
        }
        physicsBody?.velocity = v
        let speed = hypot(desiredVelocity.dx, desiredVelocity.dy)
        animator.setMotion(speed01: def.moveSpeed > 0 ? min(1, speed / CGFloat(def.moveSpeed)) : 0, moveDX: desiredVelocity.dx)
        if speed > 1 { animator.face(along: desiredVelocity) }
        animator.update(dt: dt)
        EnemyFX.update(self, dt: dt)
    }

    /// Walks toward `target`: straight when a body-wide line is clear, else along the grid path
    /// (`Pathfinder`, re-planned every `ChaserPolicy.repathSec`). Returns false when no path exists.
    @discardableResult
    func moveToward(_ target: CGPoint, dt: Double) -> Bool {
        guard let world, def.moveSpeed > 0 else { desiredVelocity = .zero; return true }
        let pathfinder = world.pathfinder
        let r = chaser.velocity(from: position, toward: target, dt: dt, speed: CGFloat(def.moveSpeed), radius: radius,
                                separation: CGFloat(def.separation ?? 0), grid: world.solidGrid,
                                allies: { self.allyPositions(world) },
                                nextWaypoint: { pathfinder.nextWaypoint(from: $0, to: $1, radius: $2) })
        desiredVelocity = r.velocity
        return r.found
    }

    /// Drops the cached waypoint (doors changed, teleported).
    func clearPath() {
        chaser.clearPath()
    }

    /// Steering toward `target`: seek + wall avoidance (feelers) + separation from allies.
    func steer(toward target: CGPoint) {
        guard let world else { desiredVelocity = .zero; return }
        let grid = world.solidGrid
        desiredVelocity = ChaserPolicy.steer(from: position, toward: target, speed: CGFloat(def.moveSpeed), radius: radius,
                                             separation: CGFloat(def.separation ?? 0), allies: { self.allyPositions(world) },
                                             isBlocked: { grid.isBlocked($0, radius: $1) })
    }

    /// Living same-type allies (separation).
    private func allyPositions(_ world: EnemyWorld) -> [CGPoint] {
        world.activeEnemies.filter { $0 !== self && $0.def.id == def.id }.map(\.position)
    }

    func powerDown(completion: @escaping @MainActor () -> Void) {
        brain.enter(PoweredDownState.self)
        EnemyFX.clearAll(self)
        desiredVelocity = .zero
        physicsBody = nil
        alertBubble.removeAllActions()
        alertBubble.alpha = 0
        powerDownDone = completion
        powerDownAge = 0
        animator.playPowerDown { [weak self] in self?.finishPowerDown() }
    }

    private func finishPowerDown() {
        guard let done = powerDownDone else { return }
        powerDownDone = nil
        done()
    }
}
