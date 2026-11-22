import SpriteKit

/// The hero: container at the collision centre (circle `hero.radius`), key-pose sprite child
/// with its feet at y = −radius.
@MainActor
final class HeroNode: SKNode {
    let def: HeroDef
    let animator: PoseAnimator
    var health: Health
    var weapon: WeaponState

    private var knockbackVelocity = CGVector.zero
    private var knockbackRemaining: Double = 0

    init(def: HeroDef, weapon: WeaponDef) {
        self.def = def
        animator = PoseAnimator(textureName: "hero_idle_01", atlas: .hero, style: .hero)
        health = Health(max: def.maxHp, invulnerableSec: def.invulnerableSec)
        let isStarter = weapon.id == def.startLoadout.weaponId
        self.weapon = WeaponState(def: weapon, magazine: def.startLoadout.magazine,
                                  reserve: def.startLoadout.reserve,
                                  safetyNet: isStarter ? def.starterSafetyNet : nil)
        super.init()
        name = "hero"
        animator.root.position = CGPoint(x: 0, y: -CGFloat(def.radius))
        addChild(animator.root)

        let body = SKPhysicsBody(circleOfRadius: CGFloat(def.radius))
        body.affectedByGravity = false
        body.allowsRotation = false
        body.linearDamping = 0
        body.friction = 0
        body.restitution = 0
        body.categoryBitMask = PhysicsCategory.hero
        body.collisionBitMask = PhysicsCategory.wall | PhysicsCategory.crate
        body.contactTestBitMask = PhysicsCategory.none
        physicsBody = body
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not supported") }

    var radius: CGFloat { CGFloat(def.radius) }

    /// Where shots leave the blaster (in the parent's coordinates).
    func muzzlePoint(angle: CGFloat) -> CGPoint {
        let reach = radius + 10
        return CGPoint(x: position.x + cos(angle) * reach, y: position.y + sin(angle) * reach)
    }

    /// Sets the physics velocity from the move stick (unit direction × 0…1) plus knockback.
    func drive(direction: CGVector, magnitude: CGFloat, dt: Double) {
        let speed = CGFloat(def.moveSpeed) * magnitude
        var v = CGVector(dx: direction.dx * speed, dy: direction.dy * speed)
        if knockbackRemaining > 0 {
            knockbackRemaining -= dt
            v.dx += knockbackVelocity.dx
            v.dy += knockbackVelocity.dy
        }
        physicsBody?.velocity = v
        animator.setMotion(speed01: magnitude, moveDX: direction.dx)
    }

    /// Pushes the hero `hero.knockbackDistance` along `direction` over `hero.knockbackSec`.
    func knockBack(along direction: CGVector) {
        let len = hypot(direction.dx, direction.dy)
        guard len > 0, def.knockbackSec > 0 else { return }
        let speed = CGFloat(def.knockbackDistance / def.knockbackSec)
        knockbackVelocity = CGVector(dx: direction.dx / len * speed, dy: direction.dy / len * speed)
        knockbackRemaining = def.knockbackSec
    }

    func clearKnockback() {
        knockbackRemaining = 0
        knockbackVelocity = .zero
        physicsBody?.velocity = .zero
    }

    func tick(dt: Double) {
        health.tick(dt: dt)
        weapon.tick(dt: dt)
        animator.setBlinking(health.isInvulnerable)
        animator.update(dt: dt)
    }
}
