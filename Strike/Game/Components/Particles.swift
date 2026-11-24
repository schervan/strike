import SpriteKit

/// Code-built particle bursts (ART_BIBLE §12 particles). Colourful stars and sparkles only:
/// no red or dark-red tints, nothing that reads as a splat. Every node removes itself.
@MainActor
enum Particles {
    static let zPosition: CGFloat = 50

    struct Burst {
        var texture: SKTexture?
        var color: SKColor
        var count: Int
        var lifetime: CGFloat
        var speed: ClosedRange<CGFloat>
        var size: CGFloat
        var angle: CGFloat = 0
        var angleRange: CGFloat = 2 * .pi
        var gravity: CGFloat = 0
        var rotationSpeed: CGFloat = 0
        var blend: SKBlendMode = .add
        /// Alpha stays 1 until this fraction of the lifetime, then fades (0 = fade from the start).
        var holdFraction: CGFloat = 0
        var endScale: CGFloat = 0
    }

    static func emitter(_ b: Burst) -> SKEmitterNode {
        let e = SKEmitterNode()
        let tex = b.texture ?? Textures.particleDot
        e.particleTexture = tex
        e.numParticlesToEmit = b.count
        e.particleBirthRate = CGFloat(b.count) / 0.02
        e.particleLifetime = b.lifetime
        e.particleLifetimeRange = b.lifetime * 0.2
        e.particleSpeed = (b.speed.lowerBound + b.speed.upperBound) / 2
        e.particleSpeedRange = b.speed.upperBound - b.speed.lowerBound
        e.emissionAngle = b.angle
        e.emissionAngleRange = b.angleRange
        let texSize = max(1, tex.size().width)
        e.particleScale = b.size / texSize
        e.particleScaleSpeed = -e.particleScale * (1 - b.endScale) / max(0.01, b.lifetime)
        e.particleAlpha = 1
        if b.holdFraction > 0 {
            let seq = SKKeyframeSequence(keyframeValues: [1, 1, 0] as [NSNumber], times: [0, b.holdFraction, 1] as [NSNumber])
            e.particleAlphaSequence = seq
        } else {
            e.particleAlphaSpeed = -1 / max(0.01, b.lifetime)
        }
        e.particleColor = b.color
        e.particleColorBlendFactor = 1
        e.particleBlendMode = b.blend
        e.yAcceleration = b.gravity
        e.particleRotationRange = .pi
        e.particleRotationSpeed = b.rotationSpeed
        return e
    }

    static func group(at point: CGPoint, _ bursts: [Burst], extra: [SKNode] = []) -> SKNode {
        let node = SKNode()
        node.name = "fx"
        node.position = point
        node.zPosition = zPosition
        var longest: CGFloat = 0.3
        for b in bursts {
            node.addChild(emitter(b))
            longest = max(longest, b.lifetime * 1.2)
        }
        extra.forEach(node.addChild)
        node.run(.sequence([.wait(forDuration: Double(longest) + 0.1), .removeFromParent()]))
        return node
    }

    /// Blaster impact: white + projectile colour, in a 140° cone away from the shot.
    static func hitSparkle(color: SKColor, at point: CGPoint = .zero, shotAngle: CGFloat? = nil, small: Bool = false) -> SKNode {
        let angle = shotAngle.map { $0 + .pi } ?? 0
        let range: CGFloat = shotAngle == nil ? 2 * .pi : 140 * .pi / 180
        let n = small ? 4 : 6
        let life: CGFloat = small ? 0.2 : 0.25
        return group(at: point, [
            Burst(color: color, count: n - n / 3, lifetime: life, speed: 120...200, size: 8, angle: angle, angleRange: range),
            Burst(color: .white, count: n / 3, lifetime: life, speed: 120...200, size: 8, angle: angle, angleRange: range),
        ])
    }

    /// Hero got bumped: white + yellow, full circle.
    static func heroHit(at point: CGPoint) -> SKNode {
        group(at: point, [
            Burst(color: .white, count: 2, lifetime: 0.25, speed: 100...160, size: 8),
            Burst(color: Palette.star, count: 3, lifetime: 0.25, speed: 100...160, size: 8),
        ])
    }

    static func muzzle(color: SKColor, at point: CGPoint, angle: CGFloat) -> SKNode {
        group(at: point, [
            Burst(color: color, count: 3, lifetime: 0.15, speed: 80...140, size: 6, angle: angle, angleRange: .pi / 3),
            Burst(color: .white, count: 1, lifetime: 0.15, speed: 80...140, size: 6, angle: angle, angleRange: .pi / 3),
        ])
    }

    /// Power-down poof v2 (ART_BIBLE §14.9, QA-009): dark pop ring (white on dark floors), shock
    /// ring, outlined stars, body-coloured chips, sparkles and a centre twinkle; 0.8 s, 34 particles.
    /// Never red, nothing stays on the floor.
    static func poof(at point: CGPoint = .zero, bodyColors: [SKColor] = [Palette.robotMetal, Palette.robotMetalLight],
                     darkFloor: Bool = false) -> SKNode {
        let pop = SKShapeNode(circleOfRadius: 46)
        pop.name = "poof_pop"
        pop.fillColor = darkFloor ? SKColor(white: 1, alpha: 0.30) : Palette.outline.withAlphaComponent(0.35)
        pop.strokeColor = .clear
        pop.zPosition = -1
        pop.setScale(24 / 92)
        pop.run(.group([.scale(to: 1, duration: 0.25), .fadeOut(withDuration: 0.25)]))

        let shock = SKShapeNode(circleOfRadius: 55)
        shock.name = "poof_shock"
        shock.strokeColor = .white
        shock.lineWidth = 4
        shock.fillColor = .clear
        let rim = SKShapeNode(circleOfRadius: 57.5)
        rim.strokeColor = Palette.outline
        rim.lineWidth = 1.5
        rim.fillColor = .clear
        shock.addChild(rim)
        shock.setScale(20 / 110)
        shock.run(.group([.scale(to: 1, duration: 0.35), .fadeOut(withDuration: 0.35)]))

        let twinkle = SKSpriteNode(texture: Textures.particleStar, size: CGSize(width: 40, height: 40))
        twinkle.blendMode = .add
        twinkle.zPosition = 2
        twinkle.setScale(0.4)
        twinkle.run(.sequence([.scale(to: 1.3, duration: 0.15), .group([.scale(to: 0, duration: 0.15), .fadeOut(withDuration: 0.15)])]))

        let starColors: [SKColor] = [Palette.star, Palette.hex(0xFF8A3D), .white, Palette.hex(0xB05CFF)]
        var bursts: [Burst] = starColors.enumerated().map { i, c in
            Burst(texture: Textures.outlinedStar, color: c, count: i < 2 ? 3 : 2, lifetime: 0.7, speed: 140...300,
                  size: 18, rotationSpeed: i.isMultiple(of: 2) ? 8 : -8, blend: .alpha, holdFraction: 0.7, endScale: 0.2)
        }
        let chips = bodyColors.isEmpty ? [Palette.robotMetal] : Array(bodyColors.prefix(2))
        for (i, c) in chips.enumerated() {
            bursts.append(Burst(texture: Textures.outlinedChip, color: c, count: i == 0 ? 4 : 8 - 4, lifetime: 0.8,
                                speed: 100...240, size: 12, gravity: -90, rotationSpeed: 10, blend: .alpha,
                                holdFraction: 0.75, endScale: 0.6))
        }
        bursts.append(Burst(texture: Textures.particleDot, color: Palette.pixelLight, count: 6, lifetime: 0.6, speed: 60...200, size: 14))
        bursts.append(Burst(texture: Textures.particleDot, color: Palette.star, count: 6, lifetime: 0.6, speed: 60...200, size: 12))
        let node = group(at: point, bursts, extra: [pop, shock, twinkle])
        node.name = "poof"
        return node
    }

    /// Total particles of one poof v2 (ART_BIBLE §14.9 budget: 34).
    static let poofParticleCount = 10 + 8 + 12

    static func collect(at point: CGPoint) -> SKNode {
        group(at: point, [
            Burst(color: Palette.star, count: 4, lifetime: 0.3, speed: 60...120, size: 6, angle: .pi / 2, angleRange: .pi),
            Burst(color: .white, count: 2, lifetime: 0.3, speed: 60...120, size: 6, angle: .pi / 2, angleRange: .pi),
        ])
    }

    /// Teleport / respawn sparkle (cyan, Pixel colours).
    static func teleport(at point: CGPoint) -> SKNode {
        group(at: point, [
            Burst(color: Palette.pixelCyan, count: 6, lifetime: 0.5, speed: 100...200, size: 8),
            Burst(color: Palette.pixelLight, count: 6, lifetime: 0.5, speed: 100...200, size: 8),
        ])
    }

    /// Puzzle element / checkpoint "on" burst (ART_BIBLE §13.4–13.6): green or cyan + white.
    static func stateOn(at point: CGPoint, color: SKColor = Palette.stateOn, count: Int = 8) -> SKNode {
        group(at: point, [
            Burst(color: color, count: count, lifetime: 0.4, speed: 50...110, size: 9),
            Burst(color: .white, count: max(2, count / 2), lifetime: 0.3, speed: 30...80, size: 6),
        ])
    }
}
