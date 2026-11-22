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
        e.particleScaleSpeed = -e.particleScale / max(0.01, b.lifetime)
        e.particleAlpha = 1
        e.particleAlphaSpeed = -1 / max(0.01, b.lifetime)
        e.particleColor = b.color
        e.particleColorBlendFactor = 1
        e.particleBlendMode = .add
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

    /// Power-down poof: stars, body-coloured chips, sparkles and an expanding white ring.
    static func poof(at point: CGPoint = .zero, bodyColors: [SKColor] = [Palette.robotMetal, Palette.robotMetalLight]) -> SKNode {
        let ring = SKShapeNode(circleOfRadius: 28)
        ring.strokeColor = SKColor(white: 1, alpha: 0.6)
        ring.lineWidth = 3
        ring.fillColor = .clear
        ring.setScale(0.3)
        ring.run(.group([.scale(to: 1.4, duration: 0.3), .fadeOut(withDuration: 0.3)]))
        var bursts = [
            Burst(texture: Textures.particleStar, color: Palette.star, count: 3, lifetime: 0.5, speed: 90...220, size: 12, rotationSpeed: 6),
            Burst(texture: Textures.particleStar, color: .white, count: 3, lifetime: 0.5, speed: 90...220, size: 12, rotationSpeed: -6),
            Burst(color: Palette.pixelLight, count: 4, lifetime: 0.5, speed: 90...220, size: 6),
        ]
        for c in bodyColors.prefix(2) {
            bursts.append(Burst(color: c, count: 2, lifetime: 0.5, speed: 90...220, size: 8, gravity: -60, rotationSpeed: 6))
        }
        return group(at: point, bursts, extra: [ring])
    }

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
