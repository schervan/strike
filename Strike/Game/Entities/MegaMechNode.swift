import SpriteKit

/// MEGA-MECH Unit Zero (GDD §9): the lite key pose at 192 pt animated by `PoseAnimator`, the
/// OVERMIND face screen as a code-drawn overlay with 4 moods (ART_BIBLE §15.13), the phase-2
/// bubble shield (§15.9) and the phase-change flash (§15.11). Moved and driven by `BossDirector`.
@MainActor
final class MegaMechNode: EnemyNode {
    enum Mood: CaseIterable { case smug, angry, panic, smiley }

    /// Key pose height on screen (ART_BIBLE §11 boss).
    static let poseHeight: CGFloat = 192
    /// Face screen patch relative to the sprite, over the printed visor of the key pose (measured
    /// on `boss_megamech_idle_01`: centre 55 % across, 77 % up; §15.13 "on the head").
    static let faceSize = CGSize(width: 0.32, height: 0.15)
    static let faceCentre = CGPoint(x: 0.55, y: 0.77)

    private(set) var mood: Mood = .smug
    private var faces: [Mood: SKNode] = [:]
    private let face = SKNode()
    private var blinkTimer = 0.0
    private(set) var bubble: SKNode?

    static var style: PoseStyle {
        var s = PoseStyle()
        s.idleBobAmplitude = 3
        s.idlePeriod = 1.8
        s.walkCadenceBase = 1.4
        s.walkCadencePerSpeed = 0.6
        s.hopAmplitude = 4
        s.swayDeg = 3
        s.maxTiltDeg = 5
        return s
    }

    init(def: EnemyDef, at point: CGPoint, world: EnemyWorld, leash: LeashRulesDef) {
        super.init(def: def, at: point, world: world, homeRoomId: nil, leash: leash,
                   texture: "boss_megamech_idle_01", atlas: .boss, style: Self.style)
        name = "boss_megamech"
        let sprite = animator.sprite
        let k = Self.poseHeight / max(1, sprite.size.height)
        sprite.size = CGSize(width: sprite.size.width * k, height: Self.poseHeight)
        // The boss is moved by BossDirector, not by physics (hero shots still make contact).
        physicsBody?.isDynamic = false
        buildFace()
        setMood(.smug, animated: false)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not supported") }

    // MARK: Face (§15.13)

    private static let screen = Palette.hex(0x12304A)
    private static let magenta = Palette.hex(0xD61F8F)

    private func buildFace() {
        let sprite = animator.sprite
        let w = sprite.size.width * Self.faceSize.width, h = sprite.size.height * Self.faceSize.height
        // The sprite's anchor is at (0.5, 0.1): its local y = 0 is 10 % up from its bottom.
        face.position = CGPoint(x: (Self.faceCentre.x - sprite.anchorPoint.x) * sprite.size.width,
                                y: (Self.faceCentre.y - sprite.anchorPoint.y) * sprite.size.height)
        face.zPosition = 1
        face.name = "boss_face"
        sprite.addChild(face)
        for m in Mood.allCases {
            let n = Self.faceNode(m, size: CGSize(width: w, height: h))
            n.isHidden = true
            face.addChild(n)
            faces[m] = n
        }
    }

    static func faceNode(_ m: Mood, size: CGSize) -> SKNode {
        let root = SKNode()
        let rim: SKColor
        switch m {
        case .smug, .angry: rim = magenta
        case .panic: rim = Palette.star
        case .smiley: rim = Palette.heal
        }
        let plate = SKShapeNode(rect: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height),
                                cornerRadius: size.height * 0.3)
        plate.fillColor = screen
        plate.strokeColor = rim
        plate.lineWidth = 3
        let outline = SKShapeNode(rect: plate.frame.insetBy(dx: -2, dy: -2), cornerRadius: size.height * 0.3 + 2)
        outline.strokeColor = Palette.outline
        outline.lineWidth = 1.5
        outline.fillColor = .clear
        root.addChild(outline)
        root.addChild(plate)
        if m == .angry {
            plate.run(.repeatForever(.sequence([.customAction(withDuration: 0.5) { n, _ in (n as? SKShapeNode)?.strokeColor = EnemyFX.warnRed },
                                                .customAction(withDuration: 0.5) { n, _ in (n as? SKShapeNode)?.strokeColor = magenta }])))
        }
        let eyes = SKNode()
        eyes.name = "eyes"
        let ex = size.width * 0.22, ey = size.height * 0.1
        let red = EnemyFX.warnRed
        for side in [-1, 1] as [CGFloat] {
            let eye: SKShapeNode
            switch m {
            case .smug:
                eye = SKShapeNode(ellipseOf: CGSize(width: 22 * size.width / 77, height: 12 * size.height / 42))
                eye.fillColor = red
                eye.strokeColor = .clear
                let lid = SKShapeNode(rect: CGRect(x: -12, y: 1, width: 24, height: 8))
                lid.fillColor = screen
                lid.strokeColor = .clear
                eye.addChild(lid)
            case .angry:
                eye = SKShapeNode(ellipseOf: CGSize(width: 24 * size.width / 77, height: 14 * size.height / 42))
                eye.fillColor = red
                eye.strokeColor = .clear
                eye.zRotation = side * -18 * .pi / 180
                let pupil = SKShapeNode(circleOfRadius: 2.5)
                pupil.fillColor = .white
                pupil.strokeColor = .clear
                eye.addChild(pupil)
                let brow = SKShapeNode(rect: CGRect(x: -11, y: 8, width: 22, height: 4))
                brow.fillColor = red
                brow.strokeColor = .clear
                eye.addChild(brow)
            case .panic:
                eye = SKShapeNode(circleOfRadius: 11 * size.height / 42)
                eye.fillColor = .white
                eye.strokeColor = .clear
                let pupil = SKShapeNode(circleOfRadius: 3)
                pupil.fillColor = Palette.outline
                pupil.strokeColor = .clear
                eye.addChild(pupil)
                eye.run(.repeatForever(.sequence([.moveBy(x: 1.5, y: 0, duration: 0.04), .moveBy(x: -1.5, y: 0, duration: 0.04)])))
            case .smiley:
                let p = CGMutablePath()
                p.addArc(center: .zero, radius: 7, startAngle: 0.2, endAngle: .pi - 0.2, clockwise: false)
                eye = SKShapeNode(path: p)
                eye.strokeColor = Palette.heal
                eye.lineWidth = 3
                eye.lineCap = .round
            }
            eye.position = CGPoint(x: side * ex, y: ey)
            eyes.addChild(eye)
        }
        root.addChild(eyes)
        // Mouth.
        let mouth = CGMutablePath()
        let my = -size.height * 0.22, mw = size.width * 0.2
        switch m {
        case .smug:
            mouth.move(to: CGPoint(x: -mw, y: my))
            mouth.addQuadCurve(to: CGPoint(x: mw, y: my + 6), control: CGPoint(x: 0, y: my - 8))
        case .angry:
            mouth.move(to: CGPoint(x: -mw, y: my))
            mouth.addLine(to: CGPoint(x: -mw / 3, y: my + 4))
            mouth.addLine(to: CGPoint(x: mw / 3, y: my))
            mouth.addLine(to: CGPoint(x: mw, y: my + 4))
        case .panic:
            mouth.move(to: CGPoint(x: -mw, y: my))
            for i in 1...4 { mouth.addLine(to: CGPoint(x: -mw + CGFloat(i) * mw / 2, y: my + (i % 2 == 0 ? 0 : 4))) }
        case .smiley:
            mouth.addArc(center: CGPoint(x: 0, y: my + 4), radius: mw, startAngle: .pi + 0.3, endAngle: -0.3, clockwise: false)
        }
        let mouthNode = SKShapeNode(path: mouth)
        mouthNode.strokeColor = m == .smiley ? Palette.heal : (m == .panic ? .white : red)
        mouthNode.lineWidth = 3
        mouthNode.lineCap = .round
        root.addChild(mouthNode)
        if m == .panic {
            let drop = SKShapeNode(circleOfRadius: 4)
            drop.fillColor = Palette.l1Sky
            drop.strokeColor = Palette.outline
            drop.lineWidth = 1
            drop.position = CGPoint(x: size.width * 0.42, y: size.height * 0.25)
            root.addChild(drop)
        }
        return root
    }

    func setMood(_ m: Mood, animated: Bool = true) {
        guard m != mood || faces[m]?.isHidden == true else { return }
        let old = faces[mood]
        mood = m
        let new = faces[m]
        new?.isHidden = false
        if animated, let old, old !== new {
            new?.alpha = 0
            new?.run(.fadeIn(withDuration: 0.12))
            old.run(.sequence([.fadeOut(withDuration: 0.12), .hide(), .fadeIn(withDuration: 0)]))
        } else if old !== new {
            old?.isHidden = true
        }
    }

    /// Per-frame face life: blink every 3.5 s, eyes toward the hero (pupils shift up to 4 pt).
    func updateFace(dt: Double, hero: CGPoint) {
        blinkTimer += dt
        let eyes = faces[mood]?.childNode(withName: "eyes")
        if blinkTimer >= 3.5 { blinkTimer = 0; eyes?.run(.sequence([.scaleY(to: 0.15, duration: 0.06), .scaleY(to: 1, duration: 0.06)])) }
        let dx = hero.x - position.x, dy = hero.y - position.y, d = max(1, hypot(dx, dy))
        eyes?.position = CGPoint(x: dx / d * 4 * (animator.facingEast ? 1 : -1), y: dy / d * 2)
    }

    // MARK: Bubble shield (§15.9)

    func setBubble(_ on: Bool) {
        if on {
            guard bubble == nil else { return }
            let r = radius + 18
            let n = SKNode()
            n.name = "boss_bubble"
            n.position = CGPoint(x: 0, y: Self.poseHeight * 0.3)
            n.zPosition = 8
            let fill = Textures.glow(diameter: 2 * r, color: Palette.pixelCyan, alpha: 0.45)
            fill.blendMode = .alpha
            n.addChild(fill)
            let rim = SKShapeNode(circleOfRadius: r)
            rim.strokeColor = Palette.pixelLight
            rim.lineWidth = 3
            rim.fillColor = Palette.pixelLight.withAlphaComponent(0.08)
            n.addChild(rim)
            let outline = SKShapeNode(circleOfRadius: r + 2)
            outline.strokeColor = Palette.outline
            outline.lineWidth = 1.5
            n.addChild(outline)
            let streaks = SKNode()
            for i in 0..<3 {
                let p = CGMutablePath()
                let a0 = CGFloat(i) * 2 * .pi / 3
                p.addArc(center: .zero, radius: r - 6, startAngle: a0, endAngle: a0 + 40 * .pi / 180, clockwise: false)
                let s = SKShapeNode(path: p)
                s.strokeColor = .white.withAlphaComponent(0.7)
                s.lineWidth = 3
                s.lineCap = .round
                s.blendMode = .add
                streaks.addChild(s)
            }
            streaks.run(.repeatForever(.rotate(byAngle: 2 * .pi, duration: 1 / 0.3)))
            n.addChild(streaks)
            n.run(.repeatForever(.sequence([.scale(to: 1.04, duration: 0.8), .scale(to: 1.0, duration: 0.8)])))
            n.setScale(0.6)
            n.alpha = 0
            n.run(.group([.scale(to: 1, duration: 0.25), .fadeIn(withDuration: 0.25)]))
            addChild(n)
            bubble = n
        } else if let b = bubble {
            bubble = nil
            b.removeAllActions()
            b.run(.sequence([.repeat(.sequence([.fadeAlpha(to: 0.3, duration: 0.08), .fadeAlpha(to: 1, duration: 0.08)]), count: 3),
                             .group([.scale(to: 1.6, duration: 0.2), .fadeOut(withDuration: 0.2)]), .removeFromParent()]))
            let shards = Particles.group(at: CGPoint(x: position.x, y: position.y + Self.poseHeight * 0.3), [
                Particles.Burst(texture: Textures.particleStar, color: Palette.pixelLight, count: 12, lifetime: 0.5,
                                speed: 200...320, size: 14),
                Particles.Burst(texture: Textures.particleDot, color: .white, count: 8, lifetime: 0.4, speed: 120...240, size: 10),
            ])
            parent?.addChild(shards)
        }
    }

    /// Shot stops at the bubble (§15.9): cyan ripple + sparkles, no damage.
    func bubbleRipple(at p: CGPoint) -> SKNode {
        let ring = SKShapeNode(circleOfRadius: 12)
        ring.strokeColor = Palette.pixelCyan
        ring.lineWidth = 2
        ring.run(.group([.scale(to: 3, duration: 0.2), .fadeOut(withDuration: 0.2)]))
        return Particles.group(at: p, [Particles.Burst(texture: Textures.particleStar, color: Palette.pixelLight, count: 4,
                                                       lifetime: 0.3, speed: 60...120, size: 9)], extra: [ring])
    }

    /// Phase change (§15.11): white flash on the sprite and the face.
    func phaseFlash() {
        let s = animator.sprite
        s.removeAction(forKey: "phaseFlash")
        s.color = .white
        s.run(.sequence([.colorize(withColorBlendFactor: 1, duration: 0.15), .colorize(withColorBlendFactor: 0, duration: 0.15)]),
              withKey: "phaseFlash")
    }
}
