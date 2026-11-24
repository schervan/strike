import SpriteKit

/// One enemy shot: laser ball, spore puff or boss star rocket (GDD §8: big, slow, colourful;
/// ART_BIBLE §15.16 looks, no red bodies). Moved by `CombatController` without physics (headless
/// tests and exact wall pops); owned and reused by `EnemyShotPool`.
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
    private let laserGlow: SKSpriteNode
    private let rocketTail = SKNode()
    private let sporeTrail = ShotTextures.trail(color: ShotTextures.mint, size: 8, star: false)
    private let laserTrail = ShotTextures.trail(color: ShotTextures.pink, size: 7, star: true)

    init() {
        underGlow = Textures.glow(diameter: 40, color: ShotTextures.pinkLight, alpha: 0.35)
        laserGlow = Textures.glow(diameter: 36, color: ShotTextures.pink, alpha: 0.25)
        super.init(texture: ShotTextures.laser, color: .white, size: ShotTextures.laser.size())
        name = "enemy_shot"
        zPosition = 21
        colorBlendFactor = 0
        underGlow.zPosition = -2
        underGlow.name = "under_glow"
        addChild(underGlow)
        laserGlow.zPosition = -1
        addChild(laserGlow)
        // Star tail behind the rocket (§15.16): 12 / 10 / 8 pt at 8 / 20 / 32 pt behind the rear.
        for (i, (size, offset, color)) in [(CGFloat(12), CGFloat(8), ShotTextures.paleYellow), (10, 20, Palette.star),
                                           (8, 32, SKColor.white)].enumerated() {
            let s = SKSpriteNode(texture: Textures.particleStar, size: CGSize(width: size, height: size))
            s.color = color
            s.colorBlendFactor = 1
            s.alpha = i == 2 ? 0.6 : 1
            s.position = CGPoint(x: -26 - offset, y: 0)
            s.run(.repeatForever(.sequence([.scale(to: 1.1, duration: 0.05), .scale(to: 0.8, duration: 0.05)])))
            rocketTail.addChild(s)
        }
        rocketTail.zPosition = -1
        addChild(rocketTail)
        addChild(sporeTrail)
        addChild(laserTrail)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not supported") }

    var angle: CGFloat { atan2(velocity.dy, velocity.dx) }

    /// Colour of the pop sparkles for this shot.
    var popColor: SKColor {
        switch kind {
        case .laser: ShotTextures.pink
        case .spore: ShotTextures.lilac
        case .star: Palette.star
        }
    }

    /// `glow`: dark floors (L4/L5) get the under-glow (ART_BIBLE §13.8). `world` keeps the trails.
    func activate(kind k: Kind, at p: CGPoint, angle a: CGFloat, speed: CGFloat, radius r: CGFloat, damage d: Int,
                  range: CGFloat, slowMultiplier sm: Double? = nil, slowSec ss: Double? = nil, glow: Bool, world: SKNode? = nil) {
        kind = k
        position = p
        velocity = CGVector(dx: cos(a) * speed, dy: sin(a) * speed)
        radius = r
        damage = d
        remainingRange = max(1, range)
        slowMultiplier = sm
        slowSec = ss
        removeAllActions()
        switch k {
        case .laser:
            texture = ShotTextures.laser
            size = CGSize(width: 20, height: 20)
            zRotation = 0
            laserGlow.run(.repeatForever(.sequence([.fadeAlpha(to: 0.35, duration: 1.0 / 6), .fadeAlpha(to: 0.2, duration: 1.0 / 6)])))
        case .spore:
            texture = ShotTextures.spore
            size = CGSize(width: 28, height: 28)
            zRotation = 0
            run(.repeatForever(.rotate(byAngle: -2 * .pi, duration: 1)))
            run(.repeatForever(.sequence([.scale(to: 1.06, duration: 0.1), .scale(to: 0.94, duration: 0.1)])))
        case .star:
            texture = ShotTextures.rocket
            size = CGSize(width: 52, height: 24)
            zRotation = a                                  // the rocket points along its travel
        }
        laserGlow.isHidden = k != .laser
        rocketTail.isHidden = k != .star
        for (trail, on) in [(sporeTrail, k == .spore), (laserTrail, k == .laser)] {
            trail.isHidden = !on
            trail.targetNode = world
            trail.particleBirthRate = on ? 10 : 0
            if on { trail.resetSimulation() }
        }
        underGlow.isHidden = !glow
        underGlow.size = CGSize(width: 40, height: 40)
        alpha = 1
        if k != .spore {
            setScale(0.6)
            run(.scale(to: 1, duration: 0.08))
        }
        isActive = true
    }

    func deactivate() {
        isActive = false
        removeAllActions()
        laserGlow.removeAllActions()
        sporeTrail.particleBirthRate = 0
        laserTrail.particleBirthRate = 0
        removeFromParent()
    }

    /// Moves; false when the range ran out.
    func step(dt: Double) -> Bool {
        guard isActive else { return false }
        position.x += velocity.dx * CGFloat(dt)
        position.y += velocity.dy * CGFloat(dt)
        remainingRange -= hypot(velocity.dx, velocity.dy) * CGFloat(dt)
        return remainingRange > 0
    }

    /// Pop when the shot ends on a wall or the hero (§15.16): lilac/mint puffs, stars, pink sparkles.
    func popEffect() -> SKNode {
        switch kind {
        case .spore:
            return Particles.group(at: position, [
                Particles.Burst(texture: Textures.particleDot, color: ShotTextures.lilac, count: 4, lifetime: 0.5, speed: 30...70,
                                size: 10, blend: .alpha),
                Particles.Burst(texture: Textures.particleDot, color: ShotTextures.mint, count: 4, lifetime: 0.5, speed: 30...70,
                                size: 8, blend: .alpha),
            ])
        case .star:
            return Particles.group(at: position, [
                Particles.Burst(texture: Textures.particleStar, color: Palette.star, count: 3, lifetime: 0.4, speed: 60...140, size: 10),
                Particles.Burst(texture: Textures.particleStar, color: Palette.pixelCyan, count: 2, lifetime: 0.4, speed: 60...140, size: 10),
                Particles.Burst(texture: Textures.particleStar, color: .white, count: 1, lifetime: 0.4, speed: 60...140, size: 10),
            ])
        case .laser:
            return Particles.hitSparkle(color: ShotTextures.pink, at: position, small: true)
        }
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
            world?.addChild(n.popEffect())
            recycle(n)
        }
    }
}
