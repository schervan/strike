import GameplayKit
import SpriteKit

/// What an enemy brain may ask the scene.
@MainActor
protocol EnemyWorld: AnyObject {
    var heroPosition: CGPoint { get }
    var roomGeometry: RoomGeometry { get }
    var activeEnemies: [EnemyNode] { get }
    var random: GKRandom { get }
}

/// Generic enemy built from an `EnemyDef`: key-pose sprite, `PoseAnimator`, `Health` and a
/// `GKStateMachine` brain. M1 ships the boltbot (chaser) brain.
@MainActor
final class EnemyNode: SKNode {
    let def: EnemyDef
    let animator: PoseAnimator
    var health: Health
    let spawnPoint: CGPoint
    weak var world: EnemyWorld?
    private(set) var brain: GKStateMachine!

    /// Desired walking velocity set by the brain each frame.
    var desiredVelocity = CGVector.zero
    private var knockbackVelocity = CGVector.zero
    private var knockbackRemaining: Double = 0
    /// Short shove time for blaster knockback (feel constant; distance comes from weapons.json).
    static let knockbackSec = 0.1

    private let alertBubble: SKLabelNode

    init(def: EnemyDef, at point: CGPoint, world: EnemyWorld) {
        self.def = def
        self.spawnPoint = point
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
        body.collisionBitMask = PhysicsCategory.wall | PhysicsCategory.enemy
        body.contactTestBitMask = PhysicsCategory.heroShot
        physicsBody = body

        brain = GKStateMachine(states: [
            IdleState(enemy: self), AlertState(enemy: self), ChaseState(enemy: self),
            HopState(enemy: self), PoweredDownState(enemy: self),
        ])
        brain.enter(IdleState.self)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not supported") }

    var radius: CGFloat { CGFloat(def.radius) }
    var isPoweredDown: Bool { brain.currentState is PoweredDownState }
    var isAware: Bool { !(brain.currentState is IdleState) && !isPoweredDown }

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
        let speed = distance / CGFloat(Self.knockbackSec)
        knockbackVelocity = CGVector(dx: direction.dx / len * speed, dy: direction.dy / len * speed)
        knockbackRemaining = Self.knockbackSec
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

    /// Steering toward `target`: seek + wall avoidance (feelers) + separation from allies.
    func steer(toward target: CGPoint) {
        guard let world else { desiredVelocity = .zero; return }
        let speed = CGFloat(def.moveSpeed)
        var dx = target.x - position.x, dy = target.y - position.y
        let d = hypot(dx, dy)
        guard d > radius * 0.5 else { desiredVelocity = .zero; return }
        dx /= d; dy /= d

        // Separation from same-type allies.
        let sepDist = CGFloat(def.separation ?? 0)
        if sepDist > 0 {
            var sx: CGFloat = 0, sy: CGFloat = 0
            for other in world.activeEnemies where other !== self && other.def.id == def.id {
                let ox = position.x - other.position.x, oy = position.y - other.position.y
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

        // Wall avoidance: probe ahead; if blocked, try rotated headings.
        let geo = world.roomGeometry
        let probe = radius + 20
        func free(_ a: CGFloat) -> Bool {
            let p = CGPoint(x: position.x + cos(a) * probe, y: position.y + sin(a) * probe)
            return !geo.isBlocked(p, radius: radius * 0.8)
        }
        var heading = atan2(dy, dx)
        if !free(heading) {
            let toTarget = atan2(target.y - position.y, target.x - position.x)
            let options: [CGFloat] = [0.6, -0.6, 1.2, -1.2, 1.8, -1.8]
            // Prefer the side closer to the direct line to the target.
            let sorted = options.sorted {
                abs(AimAssist.angleDifference(from: toTarget, to: heading + $0))
                    < abs(AimAssist.angleDifference(from: toTarget, to: heading + $1))
            }
            if let alt = sorted.first(where: { free(heading + $0) }) { heading += alt }
        }
        desiredVelocity = CGVector(dx: cos(heading) * speed, dy: sin(heading) * speed)
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
