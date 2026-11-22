import SpriteKit

/// One hero blaster shot. Owned and reused by `ProjectilePool`; never created during play.
@MainActor
final class ProjectileNode: SKSpriteNode {
    private(set) var isActive = false
    private(set) var velocity = CGVector.zero
    private(set) var remainingRange: CGFloat = 0
    private(set) var totalRange: CGFloat = 1
    private(set) var damage = 0
    private(set) var knockback: CGFloat = 0
    private(set) var angle: CGFloat = 0
    private(set) var style = ""
    private var age: Double = 0
    private(set) var bodyRadius: CGFloat

    /// Spawn pop: scale 0.6 → 1.0 over this time (ART_BIBLE §12 misc timings).
    static let spawnPopSec = 0.05
    /// Last fraction of the range over which the shot fades out.
    static let fadeFraction: CGFloat = 0.15

    init(bodyRadius: CGFloat) {
        self.bodyRadius = bodyRadius
        super.init(texture: nil, color: .clear, size: CGSize(width: 16, height: 16))
        name = "projectile"
        zPosition = 20
        physicsBody = Self.makeBody(radius: bodyRadius)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not supported") }

    private static func makeBody(radius: CGFloat) -> SKPhysicsBody {
        let b = SKPhysicsBody(circleOfRadius: max(1, radius))
        b.affectedByGravity = false
        b.allowsRotation = false
        b.linearDamping = 0
        b.friction = 0
        b.categoryBitMask = PhysicsCategory.heroShot
        b.collisionBitMask = PhysicsCategory.none
        b.contactTestBitMask = PhysicsCategory.wall | PhysicsCategory.enemy
        b.usesPreciseCollisionDetection = true
        return b
    }

    func activate(weapon: WeaponDef, texture tex: SKTexture, at point: CGPoint, angle a: CGFloat) {
        let r = CGFloat(weapon.projectileRadius)
        if r != bodyRadius {
            // Only allocates when the blaster's projectile size changes (weapon swap, M3).
            bodyRadius = r
            physicsBody = Self.makeBody(radius: r)
        }
        texture = tex
        size = tex.size()
        color = .white
        colorBlendFactor = 0
        position = point
        angle = a
        zRotation = a
        let speed = CGFloat(weapon.projectileSpeed)
        velocity = CGVector(dx: cos(a) * speed, dy: sin(a) * speed)
        totalRange = max(1, CGFloat(weapon.range))
        remainingRange = totalRange
        damage = weapon.damage
        knockback = CGFloat(weapon.knockback)
        style = weapon.projectileStyle
        age = 0
        alpha = 1
        setScale(0.6)
        physicsBody?.velocity = velocity
        isActive = true
    }

    func deactivate() {
        isActive = false
        physicsBody?.velocity = .zero
        removeFromParent()
    }

    /// Advances range/fade. Returns false when the shot ran out of range.
    func step(dt: Double) -> Bool {
        guard isActive else { return false }
        age += dt
        remainingRange -= hypot(velocity.dx, velocity.dy) * CGFloat(dt)
        if remainingRange <= 0 { return false }
        let fadeLen = totalRange * Self.fadeFraction
        alpha = min(1, remainingRange / fadeLen)
        let pop = min(1, age / Self.spawnPopSec)
        setScale(0.6 + 0.4 * CGFloat(pop))
        // Keep velocity exact even if something nudged the body.
        physicsBody?.velocity = velocity
        return true
    }
}
