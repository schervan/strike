import SpriteKit

/// Code-drawn boss telegraphs and effects (ART_BIBLE §15.1, §15.11, §15.12).
extension BossDirector {
    /// Laser warning (§15.1): beam sectors in soft red, gaps as green wedges.
    func laserPie(_ a: BossAttackDef, startAngle: CGFloat) -> SKNode {
        let n = SKNode()
        n.zRotation = 0
        let gaps = LaserSweep.gapCenters(at: 0, startAngle: startAngle, attack: a)
        let half = CGFloat(a.effectiveGapDeg / 2) * .pi / 180
        let range = CGFloat(a.range), inner = node.radius
        for (i, g) in gaps.enumerated() {
            let wedge = CGMutablePath()
            wedge.addArc(center: .zero, radius: range, startAngle: g - half, endAngle: g + half, clockwise: false)
            wedge.addArc(center: .zero, radius: inner, startAngle: g + half, endAngle: g - half, clockwise: true)
            wedge.closeSubpath()
            let gw = SKShapeNode(path: wedge)
            gw.fillColor = Palette.heal.withAlphaComponent(0.25)
            gw.strokeColor = .clear
            n.addChild(gw)
            let next = gaps[(i + 1) % gaps.count] + (i + 1 == gaps.count ? 2 * .pi : 0)
            let beam = CGMutablePath()
            beam.addArc(center: .zero, radius: range, startAngle: g + half, endAngle: next - half, clockwise: false)
            beam.addArc(center: .zero, radius: inner, startAngle: next - half, endAngle: g + half, clockwise: true)
            beam.closeSubpath()
            let bw = SKShapeNode(path: beam)
            bw.fillColor = EnemyFX.warnRed.withAlphaComponent(0.22)
            bw.strokeColor = EnemyFX.warnRed.withAlphaComponent(0.8)
            bw.lineWidth = 2
            n.addChild(bw)
        }
        n.alpha = 0.4
        return n
    }

    /// Dash arrow (§15.1): shaft + head from the boss to the end of the dash.
    func dashArrow(_ path: BossDash.Path) -> SKNode {
        let len = max(1, path.length)
        let angle = atan2(path.end.y - path.start.y, path.end.x - path.start.x)
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 0, y: -18))
        p.addLine(to: CGPoint(x: len - 60, y: -18))
        p.addLine(to: CGPoint(x: len - 60, y: -36))
        p.addLine(to: CGPoint(x: len, y: 0))
        p.addLine(to: CGPoint(x: len - 60, y: 36))
        p.addLine(to: CGPoint(x: len - 60, y: 18))
        p.addLine(to: CGPoint(x: 0, y: 18))
        p.closeSubpath()
        let arrow = SKShapeNode(path: p)
        arrow.fillColor = Palette.star.withAlphaComponent(0.3)
        arrow.strokeColor = EnemyFX.warnRed
        arrow.lineWidth = 3
        arrow.zRotation = angle
        return arrow
    }

    func phaseRing() {
        let ring = SKShapeNode(circleOfRadius: 60)
        ring.strokeColor = .white
        ring.lineWidth = 4
        ring.blendMode = .add
        ring.position = node.position
        ring.zPosition = Particles.zPosition
        ring.run(.sequence([.group([.scale(to: 700.0 / 60, duration: 0.5), .fadeOut(withDuration: 0.5)]), .removeFromParent()]))
        scene.worldNode.addChild(ring)
        scene.worldNode.addChild(Particles.poof(at: node.position, bodyColors: [Palette.star, Palette.pixelCyan, Palette.hex(0xD61F8F)],
                                                darkFloor: true))
    }

    func confetti() {
        let e = SKEmitterNode()
        e.particleTexture = Textures.particleStar
        e.particleBirthRate = 34
        e.numParticlesToEmit = 40
        e.particleLifetime = 1.6
        e.particlePositionRange = CGVector(dx: scene.visibleSize.width, dy: 0)
        e.position = CGPoint(x: 0, y: scene.visibleSize.height / 2 + 10)
        e.emissionAngle = -.pi / 2
        e.particleSpeed = 220
        e.particleSpeedRange = 80
        e.particleScale = 0.9
        e.particleRotationSpeed = 3
        e.particleColorSequence = SKKeyframeSequence(keyframeValues: [Palette.star, Palette.pixelCyan, Palette.hex(0xD61F8F),
                                                                      Palette.heal, Palette.hex(0xB05CFF)],
                                                     times: [0, 0.25, 0.5, 0.75, 1])
        e.particleColorBlendFactor = 1
        e.zPosition = 870
        e.run(.sequence([.wait(forDuration: 3), .removeFromParent()]))
        scene.cameraNode.addChild(e)
    }
}
