import SpriteKit

/// Behaviour visuals of the M4 enemies (ART_BIBLE §15.1–15.5, §15.10 carriers): telegraphs,
/// the shield arc, dizzy stars, shy petals and the core-carrier badge. Code-drawn, kid-safe
/// (soft glows and lines, never splats). All nodes hang off the enemy node.
@MainActor
enum EnemyFX {
    enum Telegraph { case droneGlow, shieldDash, sporePetals }

    static let warnRed = Palette.hex(0xFF3B5C)
    static let sporePink = Palette.hex(0xE36BD8)
    static let sporeLight = Palette.hex(0xFFB3F2)
    static let shieldCyan = Palette.pixelCyan

    // MARK: Telegraphs (§15.1; always last at least `sec`)

    static func showTelegraph(_ e: EnemyNode, kind: Telegraph, sec: Double) {
        clearTelegraph(e)
        let n = SKNode()
        n.name = "telegraph"
        n.zPosition = -1
        let toHero = e.world.map { atan2($0.heroPosition.y - e.position.y, $0.heroPosition.x - e.position.x) } ?? 0
        switch kind {
        case .droneGlow:
            let glow = Textures.glow(diameter: 28, color: warnRed, alpha: 0.2)
            glow.position = CGPoint(x: cos(toHero) * 14, y: sin(toHero) * 14 + e.radius * 0.4)
            glow.setScale(0.6)
            glow.zPosition = 3
            glow.run(.group([.fadeAlpha(to: 0.9, duration: sec), .scale(to: 1.1, duration: sec)]))
            n.addChild(glow)
            for i in 0..<3 {
                let d = SKShapeNode(circleOfRadius: 2)
                d.fillColor = warnRed.withAlphaComponent(0.6)
                d.strokeColor = .clear
                let r = e.radius + 18 + CGFloat(i) * 10
                d.position = CGPoint(x: cos(toHero) * r, y: sin(toHero) * r)
                n.addChild(d)
            }
            n.zPosition = 3
        case .shieldDash:
            let len = CGFloat(e.def.attack?.dashDistance ?? 260)
            let lane = SKShapeNode(rect: CGRect(x: 0, y: -14, width: len, height: 28), cornerRadius: 14)
            lane.fillColor = Palette.star.withAlphaComponent(0.18)
            lane.strokeColor = Palette.star.withAlphaComponent(0.8)
            lane.lineWidth = 2
            lane.zRotation = e.shield?.facing ?? toHero
            lane.alpha = 0
            lane.name = "lane"
            lane.run(.sequence([.wait(forDuration: 0.2), .fadeIn(withDuration: 0.1)]))
            n.addChild(lane)
        case .sporePetals:
            let glow = Textures.glow(diameter: 24, color: sporeLight, alpha: 0.3)
            glow.position = CGPoint(x: 0, y: e.radius)
            glow.zPosition = 3
            glow.run(.repeatForever(.sequence([.fadeAlpha(to: 0.9, duration: 0.15), .fadeAlpha(to: 0.3, duration: 0.15)])))
            n.addChild(glow)
            for i in 0..<4 {
                let petal = SKShapeNode(ellipseOf: CGSize(width: 16, height: 26))
                petal.fillColor = i % 2 == 0 ? sporePink : sporeLight
                petal.strokeColor = Palette.outline
                petal.lineWidth = 1.5
                let base = CGFloat(i) * .pi / 2 + .pi / 4
                petal.position = CGPoint(x: cos(base) * 10, y: e.radius + sin(base) * 10)
                petal.zRotation = base - .pi / 2
                petal.zPosition = 2
                petal.run(.rotate(byAngle: (i % 2 == 0 ? 1 : -1) * 35 * .pi / 180, duration: 0.4))
                n.addChild(petal)
            }
            for k in -1...1 {
                let a = toHero + CGFloat(k) * 15 * .pi / 180
                let t = SKShapeNode(circleOfRadius: 2)
                t.fillColor = .white
                t.strokeColor = .clear
                t.position = CGPoint(x: cos(a) * 40, y: sin(a) * 40)
                n.addChild(t)
            }
            n.zPosition = 3
        }
        e.addChild(n)
        e.telegraphNode = n
    }

    static func clearTelegraph(_ e: EnemyNode, pop: Bool = false) {
        guard let n = e.telegraphNode else { return }
        e.telegraphNode = nil
        if pop {
            n.run(.sequence([.group([.scale(to: 1.4, duration: 0.1), .fadeOut(withDuration: 0.1)]), .removeFromParent()]))
        } else {
            n.removeFromParent()
        }
    }

    // MARK: Shield arc (§15.2), dizzy stars (§15.3)

    static func shieldArcNode(radius r: CGFloat, arcDeg: Double) -> SKNode {
        let half = CGFloat(arcDeg / 2) * .pi / 180
        let outer = r + 4, inner = r - 4
        let path = CGMutablePath()
        path.addArc(center: .zero, radius: outer, startAngle: -half, endAngle: half, clockwise: false)
        path.addArc(center: .zero, radius: inner, startAngle: half, endAngle: -half, clockwise: true)
        path.closeSubpath()
        let arc = SKShapeNode(path: path)
        arc.fillColor = shieldCyan.withAlphaComponent(0.55)
        arc.strokeColor = Palette.outline
        arc.lineWidth = 2
        let rim = SKShapeNode(path: { let p = CGMutablePath(); p.addArc(center: .zero, radius: inner + 1, startAngle: -half, endAngle: half, clockwise: false); return p }())
        rim.strokeColor = Palette.pixelLight
        rim.lineWidth = 1.5
        arc.addChild(rim)
        arc.name = "shield_arc"
        arc.zPosition = 4
        arc.alpha = 0.75
        return arc
    }

    static func setDizzy(_ e: EnemyNode, _ on: Bool) {
        if on {
            guard e.dizzyStars == nil else { return }
            let n = dizzyNode(starSize: e.isBoss ? 22 : 12, rx: e.radius * 0.9, above: e.animator.sprite.size.height - e.radius + (e.isBoss ? 20 : 6))
            e.addChild(n)
            e.dizzyStars = n
            e.animator.sprite.color = Palette.star
            e.animator.sprite.colorBlendFactor = 0.25
            e.shieldArc?.run(.group([.fadeOut(withDuration: 0.2), .scale(to: 0.8, duration: 0.2)]), withKey: "dizzy")
        } else {
            e.dizzyStars?.removeFromParent()
            e.dizzyStars = nil
            e.animator.sprite.colorBlendFactor = 0
            if let arc = e.shieldArc {
                arc.removeAction(forKey: "dizzy")
                arc.setScale(1.15)
                arc.run(.group([.fadeAlpha(to: 0.75, duration: 0.2), .scale(to: 1, duration: 0.2)]))
            }
        }
    }

    /// 3 stars orbiting an ellipse (1.4 rev/s), front stars bigger.
    static func dizzyNode(starSize: CGFloat, rx: CGFloat, above: CGFloat) -> SKNode {
        let n = SKNode()
        n.name = "dizzy_stars"
        n.position = CGPoint(x: 0, y: above)
        n.zPosition = 6
        let ry = rx * 0.4
        for i in 0..<3 {
            let s = SKSpriteNode(texture: Textures.outlinedStar, size: CGSize(width: starSize, height: starSize))
            let phase = CGFloat(i) / 3
            let orbit = SKAction.customAction(withDuration: 1 / 1.4) { node, t in
                let a = 2 * .pi * (phase + t * 1.4)
                node.position = CGPoint(x: cos(a) * rx, y: sin(a) * ry)
                node.setScale(0.97 - 0.12 * sin(a))
                node.zPosition = sin(a) > 0 ? -1 : 1
            }
            s.run(.repeatForever(orbit))
            n.addChild(s)
        }
        n.alpha = 0
        n.run(.fadeIn(withDuration: 0.12))
        return n
    }

    static func setShy(_ e: EnemyNode, _ on: Bool) {
        e.animator.sprite.color = sporeLight
        e.animator.sprite.colorBlendFactor = on ? 0.2 : 0
    }

    // MARK: Core carrier (§15.10)

    static func updateCarryIcon(_ e: EnemyNode) {
        e.carryIcon?.removeFromParent()
        e.carryIcon = nil
        guard let item = e.carriesItem else { return }
        let n = SKNode()
        n.name = "carry_icon"
        n.position = CGPoint(x: 0, y: e.radius + 14)
        n.zPosition = 5
        n.addChild(Textures.glow(diameter: 36, color: shieldCyan, alpha: 0.7))
        let icon = SKSpriteNode(texture: Textures.texture("pickup_\(item)", in: .items))
        let k = 20 / max(1, icon.size.height)
        icon.setScale(k)
        icon.run(.repeatForever(.sequence([.scaleX(to: -k, duration: 1), .scaleX(to: k, duration: 1)])))
        n.addChild(icon)
        e.addChild(n)
        e.carryIcon = n
    }

    // MARK: Per frame

    static func update(_ e: EnemyNode, dt: Double) {
        if let s = e.shield {
            if e.shieldArc == nil {
                let arc = shieldArcNode(radius: e.radius + 8, arcDeg: s.config.arcDeg)
                e.addChild(arc)
                e.shieldArc = arc
            }
            if let arc = e.shieldArc as? SKShapeNode {
                arc.zRotation = s.facing
                let glowing = s.isCrouching || s.isDashing
                arc.fillColor = (glowing ? Palette.star : shieldCyan).withAlphaComponent(0.55)
                arc.zPosition = sin(s.facing) > 0.3 ? -0.5 : 4
            }
        }
    }

    static func clearAll(_ e: EnemyNode) {
        clearTelegraph(e)
        e.shieldArc?.removeFromParent(); e.shieldArc = nil
        e.dizzyStars?.removeFromParent(); e.dizzyStars = nil
        e.carryIcon?.removeFromParent(); e.carryIcon = nil
    }

    /// Shot bounces off the shield (§15.2): sparkles + star flash + clink ring, no damage.
    static func shieldBounce(at p: CGPoint, shotAngle: CGFloat) -> SKNode {
        let ring = SKShapeNode(circleOfRadius: 6)
        ring.strokeColor = .white
        ring.lineWidth = 2
        ring.fillColor = .clear
        ring.run(.group([.scale(to: 22.0 / 6, duration: 0.2), .fadeOut(withDuration: 0.2)]))
        return Particles.group(at: p, [
            Particles.Burst(texture: Textures.particleStar, color: Palette.pixelLight, count: 6, lifetime: 0.35, speed: 60...140,
                            size: 10, angle: shotAngle + .pi, angleRange: 2.2),
        ], extra: [ring])
    }
}
