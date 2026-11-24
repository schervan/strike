import SpriteKit

/// Pixel's rescue at 0 HP (GDD §12, ART_BIBLE §14.7): slow-mo, beam up, teleport to the last
/// checkpoint, beam down. Never a "game over". The rules are in `RescueRules`.
/// Split out of `GameScene` in M4-3 with no behaviour change.
@MainActor
final class RescueController {
    unowned let scene: GameScene

    /// The rescue sequence in progress; `t` is real seconds since 0 HP.
    struct Run {
        var t: Double = 0
        var teleported = false
        var beamOut: SKNode?
        var beamIn: SKNode?
        var tint: SKSpriteNode?
    }

    private(set) var run: Run?

    init(scene: GameScene) {
        self.scene = scene
    }

    /// Where a rescue puts the hero: the last touched checkpoint.
    var respawnPoint: CGPoint {
        if let id = scene.session.lastCheckpointId, let node = scene.built.checkpoints[id] { return node.position }
        return scene.level.grid.world(scene.level.heroStart)
    }

    /// GDD §12 steps 3–7 at once (`RescueRules`): hero at the last checkpoint with full HP and
    /// invulnerability, starter topped up, living enemies healed and sent home, `rescues + 1`.
    /// Bag, quick slots, other ammo, datachips and puzzle state stay as they are. The beam sequence
    /// (`begin`) calls this at the teleport moment.
    func rescueHero() {
        let hero = scene.hero, data = scene.data
        scene.audio?.play(.rescue)
        scene.worldNode.addChild(Particles.teleport(at: hero.position))
        hero.clearKnockback()
        guard let starter = data.weapons[data.hero.startLoadout.weaponId] else { return }
        let outcome = RescueRules.apply(
            health: &hero.health, loadout: &hero.loadout, session: &scene.session,
            enemies: scene.enemyDirector.rescueEnemies,
            starter: starter, rules: data.rules.rescue, invulnerableSec: data.hero.effectiveRespawnInvulnerableSec)
        hero.position = respawnPoint
        hero.animator.reset()
        scene.enemyDirector.resetForRescue(Set(outcome.enemiesToReset))
        scene.worldNode.addChild(Particles.teleport(at: hero.position))
        scene.pixel.snap(to: hero.position)
        scene.snapCamera()
    }

    /// Starts the rescue sequence. Input is off until the hero stands at the checkpoint.
    func begin() {
        guard run == nil, !scene.isComplete else { return }
        scene.resetTouches()
        let hero = scene.hero
        hero.clearKnockback()
        hero.drive(direction: .zero, magnitude: 0, dt: 0)
        scene.pixel.setRescue(true)
        scene.pixelDirector.endHint()
        var r = Run()
        let tint = SKSpriteNode(color: Palette.pixelLight, size: CGSize(width: 4000, height: 4000))
        tint.name = "rescue_tint"
        tint.alpha = 0
        tint.zPosition = 900
        scene.cameraNode.addChild(tint)
        r.tint = tint
        run = r
    }

    func update(dt: Double) {
        guard var r = run else { return }
        let hero = scene.hero
        let rules = scene.data.rules.rescue
        r.t += dt
        let world = dt * RescueRules.timeScale(at: r.t, rules: rules)
        // The world keeps running (slowed); the hero takes no input and no damage.
        scene.enemyDirector.tick(dt: world)
        scene.combat.updateProjectiles(dt: world)
        hero.drive(direction: .zero, magnitude: 0, dt: world)
        hero.animator.update(dt: world)
        let half = rules.beamSec / 2
        let beamStart = rules.slowMoSec
        if r.t < beamStart {
            r.tint?.alpha = CGFloat(min(0.18, r.t / 0.3 * 0.18))
        } else if !r.teleported {
            if r.beamOut == nil {
                let b = Self.beam()
                b.position = hero.position
                scene.worldNode.addChild(b)
                r.beamOut = b
            }
            let k = min(1, (r.t - beamStart) / half)
            hero.alpha = CGFloat(1 - k)
            hero.setScale(CGFloat(1 - 0.8 * k))
            if r.t >= beamStart + half {
                r.teleported = true
                r.beamOut?.run(.sequence([.fadeOut(withDuration: 0.15), .removeFromParent()]))
                r.beamOut = nil
                rescueHero()
                let b = Self.beam()
                b.position = hero.position
                scene.worldNode.addChild(b)
                r.beamIn = b
            }
        } else {
            let k = min(1, (r.t - beamStart - half) / half)
            hero.alpha = CGFloat(k)
            hero.setScale(CGFloat(0.2 + 0.8 * k))
            r.tint?.alpha = CGFloat(0.18 * (1 - k))
        }
        scene.pixel.update(dt: dt, hero: hero.position)
        scene.updateCamera(dt: dt, aim: nil)
        run = r
        if r.t >= RescueRules.duration(rules) { end() }
    }

    private func end() {
        guard let r = run else { return }
        r.beamOut?.removeFromParent()
        r.beamIn?.run(.sequence([.fadeOut(withDuration: 0.15), .removeFromParent()]))
        r.tint?.removeFromParent()
        if !r.teleported { rescueHero() }
        run = nil
        scene.hero.alpha = 1
        scene.hero.setScale(1)
        scene.pixel.setRescue(false)
        scene.pixelBrain.handle(.rescue)
        scene.pixelDirector.wasLowHp = false
    }

    /// Pixel's teleport column (ART_BIBLE §14.7): white core, cyan layers, ground ring.
    static func beam() -> SKNode {
        let n = SKNode()
        n.name = "rescue_beam"
        n.zPosition = 45
        // ART_BIBLE §14.7: from 20 pt below the feet to 220 pt above; outer cyan 96, inner 50, core 24.
        let footY: CGFloat = -40, height: CGFloat = 240 + 20
        let layers: [(CGFloat, SKColor, CGFloat)] = [(96, Palette.pixelCyan, 0.55), (50, Palette.pixelLight, 0.8), (24, .white, 0.95)]
        for (i, (w, c, a)) in layers.enumerated() {
            let col = SKSpriteNode(texture: Textures.beamGradient, size: CGSize(width: w, height: height))
            col.anchorPoint = CGPoint(x: 0.5, y: 0)
            col.position = CGPoint(x: 0, y: footY - 20)
            col.color = c
            col.colorBlendFactor = 1
            col.alpha = a
            col.blendMode = .add
            col.xScale = 0.05
            // Width 0 → full in 0.2 s, then a slight pulse (±8 %, layers out of phase).
            let pulse = SKAction.sequence([.scaleX(to: 1.08, duration: 0.18 + 0.03 * Double(i)),
                                           .scaleX(to: 0.94, duration: 0.18 + 0.03 * Double(i))])
            col.run(.sequence([.scaleX(to: 1, duration: 0.2), .repeatForever(pulse)]))
            n.addChild(col)
        }
        let ring = SKSpriteNode(texture: Textures.radialGlow, size: CGSize(width: 88, height: 32))
        ring.position = CGPoint(x: 0, y: footY)
        ring.color = Palette.pixelCyan
        ring.colorBlendFactor = 1
        ring.alpha = 0.8
        ring.blendMode = .add
        ring.setScale(0.6)
        ring.run(.scale(to: 1, duration: 0.2))
        n.addChild(ring)
        // Rising sparkles along the column for as long as the beam lives.
        let rise = SKEmitterNode()
        rise.particleTexture = Textures.particleDot
        rise.particleBirthRate = 36
        rise.particleLifetime = 0.5
        rise.particlePositionRange = CGVector(dx: 50, dy: 30)
        rise.position = CGPoint(x: 0, y: footY + 10)
        rise.emissionAngle = .pi / 2
        rise.emissionAngleRange = 0.2
        rise.particleSpeed = 170
        rise.particleSpeedRange = 100
        rise.particleScale = 0.6
        rise.particleScaleSpeed = -1.1
        rise.particleAlphaSpeed = -1.6
        rise.particleColor = Palette.pixelLight
        rise.particleColorBlendFactor = 1
        rise.particleColorSequence = SKKeyframeSequence(keyframeValues: [Palette.pixelLight, SKColor.white, Palette.pixelCyan],
                                                        times: [0, 0.5, 1])
        rise.particleBlendMode = .add
        rise.zPosition = 1
        n.addChild(rise)
        n.addChild(Particles.group(at: CGPoint(x: 0, y: footY + 40), [
            Particles.Burst(texture: Textures.particleStar, color: Palette.star, count: 4, lifetime: 0.5, speed: 80...160,
                            size: 9, angle: .pi / 2, angleRange: 0.6),
        ]))
        return n
    }
}
