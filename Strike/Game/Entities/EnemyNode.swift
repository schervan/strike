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
}

extension EnemyWorld {
    func enemyDidSpotHero(_ enemy: EnemyNode) {}
}

/// Generic enemy built from an `EnemyDef`: key-pose sprite, `PoseAnimator`, `Health` and a
/// `GKStateMachine` brain. Every enemy uses the chaser brain until its own behaviour lands in M4
/// (DECISIONS); static enemies (`moveSpeed 0`) just stand still.
@MainActor
final class EnemyNode: SKNode {
    let def: EnemyDef
    let animator: PoseAnimator
    var health: Health
    let spawnPoint: CGPoint
    /// Room the enemy was spawned in (leash target).
    let homeRoomId: Int?
    var leash: Leash
    weak var world: EnemyWorld?
    private(set) var brain: GKStateMachine!

    /// Desired walking velocity set by the brain each frame.
    var desiredVelocity = CGVector.zero
    private var knockbackVelocity = CGVector.zero
    private var knockbackRemaining: Double = 0

    private let alertBubble: SKLabelNode

    /// Seek, grid path and steering (pure, M4-4).
    private var chaser = ChaserPolicy()

    init(def: EnemyDef, at point: CGPoint, world: EnemyWorld, homeRoomId: Int? = nil, leash: LeashRulesDef) {
        self.def = def
        self.spawnPoint = point
        self.homeRoomId = homeRoomId
        self.leash = Leash(rules: leash)
        self.world = world
        animator = PoseAnimator(textureName: def.keyPoseTextureName, atlas: .enemies, style: .boltbot)
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

        brain = GKStateMachine(states: [
            IdleState(enemy: self), AlertState(enemy: self), ChaseState(enemy: self),
            HopState(enemy: self), ReturnHomeState(enemy: self), PoweredDownState(enemy: self),
        ])
        brain.enter(IdleState.self)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not supported") }

    var radius: CGFloat { CGFloat(def.radius) }
    var isPoweredDown: Bool { brain.currentState is PoweredDownState }
    var isAware: Bool { !(brain.currentState is IdleState) && !isPoweredDown }
    var isReturningHome: Bool { brain.currentState is ReturnHomeState }

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
        brain.update(deltaTime: dt)
        guard !isPoweredDown else {
            animator.update(dt: dt)
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
        animator.setMotion(speed01: def.moveSpeed > 0 ? speed / CGFloat(def.moveSpeed) : 0, moveDX: desiredVelocity.dx)
        if speed > 1 { animator.face(along: desiredVelocity) }
        animator.update(dt: dt)
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
        desiredVelocity = .zero
        physicsBody = nil
        alertBubble.removeAllActions()
        alertBubble.alpha = 0
        animator.playPowerDown(completion: completion)
    }
}
