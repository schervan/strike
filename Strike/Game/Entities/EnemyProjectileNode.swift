import SpriteKit

/// One enemy shot: laser ball, spore puff or boss star rocket (GDD §8: big, slow, colourful).
/// Moved by `CombatController` without physics (headless tests and exact wall pops); owned and
/// reused by `EnemyShotPool`.
@MainActor
final class EnemyProjectileNode: SKSpriteNode {
    enum Kind: Sendable { case laser, spore, star }

    private(set) var isActive = false
    private(set) var kind: Kind = .laser
    private(set) var velocity = CGVector.zero
    private(set) var radius: CGFloat = 8
    private(set) var damage = 0
    private(set) var remainingRange: CGFloat = 0
    private(set) var slowMultiplier: Double?
    private(set) var slowSec: Double?
    private let underGlow: SKSpriteNode

    init() {
        underGlow = Textures.glow(diameter: 40, color: .white, alpha: 0.35)
        super.init(texture: Textures.texture("proj_enemy", in: .items), color: .white, size: CGSize(width: 16, height: 16))
        name = "enemy_shot"
        zPosition = 21
        underGlow.zPosition = -1
        underGlow.name = "under_glow"
        addChild(underGlow)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not supported") }

    var angle: CGFloat { atan2(velocity.dy, velocity.dx) }

    /// `glow`: dark floors (L4/L5) get the under-glow (ART_BIBLE §13.8).
    func activate(kind k: Kind, at p: CGPoint, angle a: CGFloat, speed: CGFloat, radius r: CGFloat, damage d: Int,
                  range: CGFloat, slowMultiplier sm: Double? = nil, slowSec ss: Double? = nil, glow: Bool) {
        kind = k
        position = p
        velocity = CGVector(dx: cos(a) * speed, dy: sin(a) * speed)
        radius = r
        damage = d
        remainingRange = max(1, range)
        slowMultiplier = sm
        slowSec = ss
        let diameter = 2 * r + 6
        size = CGSize(width: diameter, height: diameter)
        switch k {
        case .laser: color = EnemyFX.warnRed; colorBlendFactor = 0.25
        case .spore: color = EnemyFX.sporePink; colorBlendFactor = 0.7
        case .star: color = Palette.star; colorBlendFactor = 0.95
        }
        underGlow.isHidden = !glow
        underGlow.color = color
        underGlow.size = CGSize(width: diameter * 2, height: diameter * 2)
        zRotation = a
        alpha = 1
        setScale(0.6)
        run(.scale(to: 1, duration: 0.08))
        isActive = true
    }

    func deactivate() {
        isActive = false
        removeAllActions()
        removeFromParent()
    }

    /// Moves; false when the range ran out.
    func step(dt: Double) -> Bool {
        guard isActive else { return false }
        position.x += velocity.dx * CGFloat(dt)
        position.y += velocity.dy * CGFloat(dt)
        if kind == .spore { zRotation += CGFloat(dt) * 4 }
        remainingRange -= hypot(velocity.dx, velocity.dy) * CGFloat(dt)
        return remainingRange > 0
    }
}

/// Fixed-size pool of enemy shots (no allocation during play).
@MainActor
final class EnemyShotPool {
    private let nodes: [EnemyProjectileNode]
    private var free: [EnemyProjectileNode]

    init(capacity: Int) {
        nodes = (0..<capacity).map { _ in EnemyProjectileNode() }
        free = nodes.reversed()
    }

    var activeCount: Int { nodes.count - free.count }

    func spawn(in parent: SKNode, _ configure: (EnemyProjectileNode) -> Void) -> EnemyProjectileNode? {
        guard let n = free.popLast() else { return nil }
        configure(n)
        parent.addChild(n)
        return n
    }

    func recycle(_ n: EnemyProjectileNode) {
        guard n.isActive else { return }
        n.deactivate()
        free.append(n)
    }

    func forEachActive(_ body: (EnemyProjectileNode) -> Void) {
        for n in nodes where n.isActive { body(n) }
    }

    /// Every shot pops (rescue beam, boss phase change, boss defeat).
    func recycleAll(popInto world: SKNode?) {
        for n in nodes where n.isActive {
            world?.addChild(Particles.hitSparkle(color: n.color, at: n.position, small: true))
            recycle(n)
        }
    }
}
