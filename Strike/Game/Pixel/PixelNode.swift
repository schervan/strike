import SpriteKit

/// Pixel, the hologram drone buddy (GDD §13, ART_BIBLE §14.4). Floats at `pixel.followOffset`
/// (world axes) from the hero with a critically damped lerp, bobs, ignores walls and physics.
/// `flyTo` runs the hint flight; `scan(toward:)` the scan cone. Numbers from `rules.json → pixel/hints`.
@MainActor
final class PixelNode: SKNode {
    let rules: PixelRulesDef
    let hints: HintRulesDef

    private let bobNode = SKNode()
    private let sprite: SKSpriteNode
    private let glow: SKSpriteNode
    private let shadow: SKShapeNode
    private var time = Double.random(in: 0..<10)
    private var talking = false
    private var talkFrame = 0.0
    private let idleTexture: SKTexture
    private let talkTextures: [SKTexture]

    /// ART_BIBLE §14.4 / §14.6 feel values (presentation, not balance).
    enum Feel {
        static let maxSpeed: CGFloat = 520
        static let leashSnap: CGFloat = 240
        static let leashTo: CGFloat = 120
        static let flightSpeed: CGFloat = 480
        static let stopShort: CGFloat = 64
        static let glowDiameter: CGFloat = 56
        static let talkWiggleRad: CGFloat = 6 * .pi / 180
        static let talkHz = 5.0
        static let maxLean: CGFloat = 8 * .pi / 180
        static let drift: CGFloat = 2
        static let driftPeriod = 3.1
    }

    enum Mode: Equatable {
        case follow
        /// Hint: fly toward `target`, then hold there until `holdUntil` (seconds of `time`).
        case hint(target: CGPoint, holdUntil: Double)
        /// Rescue: stay above the hero, in real time.
        case rescue
    }

    private(set) var mode: Mode = .follow

    init(rules: PixelRulesDef, hints: HintRulesDef) {
        self.rules = rules
        self.hints = hints
        idleTexture = Textures.texture("pixel_idle_01", in: .pixel)
        talkTextures = (1...3).map { Textures.texture(String(format: "pixel_talk_%02d", $0), in: .pixel) }
        sprite = SKSpriteNode(texture: idleTexture)
        let target: CGFloat = 48
        let w = max(1, idleTexture.size().width)
        sprite.setScale(target / w)
        glow = Textures.glow(diameter: Feel.glowDiameter, color: Palette.pixelCyan, alpha: 0.25)
        shadow = SKShapeNode(ellipseOf: CGSize(width: 20, height: 7))
        shadow.fillColor = Palette.outline.withAlphaComponent(0.18)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: -30)
        super.init()
        name = "pixel"
        addChild(shadow)
        addChild(bobNode)
        bobNode.addChild(glow)
        bobNode.addChild(sprite)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not supported") }

    var offset: CGPoint { CGPoint(x: rules.followOffset.x, y: rules.followOffset.y) }

    func followTarget(for hero: CGPoint) -> CGPoint {
        CGPoint(x: hero.x + offset.x, y: hero.y + offset.y)
    }

    /// Jump to the follow spot (level start, teleports).
    func snap(to hero: CGPoint) {
        position = followTarget(for: hero)
    }

    var isBusy: Bool { mode != .follow }

    /// Hint flight (ART_BIBLE §14.6): toward `target`, stopping short, holding for the arrow time.
    func flyTo(_ target: CGPoint) {
        mode = .hint(target: target, holdUntil: time + hints.flySec + hints.arrowSec)
    }

    /// Ends a hint early (target solved, hero near it).
    func returnToHero() {
        if case .hint = mode { mode = .follow }
    }

    func setRescue(_ on: Bool) { mode = on ? .rescue : .follow }

    func setTalking(_ on: Bool) {
        guard on != talking else { return }
        talking = on
        if !on {
            sprite.texture = idleTexture
            sprite.zRotation = 0
        }
    }

    /// Per frame. `dt` is real time (Pixel ignores the rescue slow-mo).
    func update(dt: Double, hero: CGPoint) {
        guard dt > 0 else { return }
        time += dt
        var target = followTarget(for: hero)
        var maxSpeed = Feel.maxSpeed
        switch mode {
        case .follow:
            break
        case .rescue:
            target = CGPoint(x: hero.x, y: hero.y + 36 + 20)
            maxSpeed = Feel.maxSpeed * 2
        case .hint(let t, let holdUntil):
            let dx = t.x - hero.x, dy = t.y - hero.y
            let d = max(1, hypot(dx, dy))
            target = CGPoint(x: t.x - dx / d * Feel.stopShort, y: t.y - dy / d * Feel.stopShort)
            maxSpeed = Feel.flightSpeed
            if time >= holdUntil {
                mode = .follow
                target = followTarget(for: hero)
            }
        }
        // Critically damped follow with a speed cap; hints move at a steady flight speed.
        let k = CGFloat(1 - exp(-dt / max(0.01, rules.followLerpSec)))
        var step = CGVector(dx: (target.x - position.x) * k, dy: (target.y - position.y) * k)
        if case .hint = mode {
            let dx = target.x - position.x, dy = target.y - position.y
            let d = hypot(dx, dy)
            let len = min(d, maxSpeed * CGFloat(dt))
            step = d > 0 ? CGVector(dx: dx / d * len, dy: dy / d * len) : .zero
        }
        let len = hypot(step.dx, step.dy), cap = maxSpeed * CGFloat(dt)
        if len > cap { step = CGVector(dx: step.dx / len * cap, dy: step.dy / len * cap) }
        position.x += step.dx
        position.y += step.dy
        if mode == .follow {
            let fx = position.x - hero.x, fy = position.y - hero.y
            let fd = hypot(fx, fy)
            if fd > Feel.leashSnap {
                position = CGPoint(x: hero.x + fx / fd * Feel.leashTo, y: hero.y + fy / fd * Feel.leashTo)
            }
        }
        // Bob, drift, lean, talk wiggle.
        let bob = CGFloat(rules.bobAmplitude) * CGFloat(sin(time * rules.bobHz * 2 * .pi))
        let drift = Feel.drift * CGFloat(sin(time / Feel.driftPeriod * 2 * .pi))
        bobNode.position = CGPoint(x: drift, y: bob)
        let speed = len / CGFloat(dt)
        let lean = speed > 60 ? max(-Feel.maxLean, min(Feel.maxLean, -step.dx / max(1, len) * Feel.maxLean)) : 0
        glow.alpha = 0.25 + 0.05 * CGFloat(sin(time / 1.8 * 2 * .pi))
        if talking {
            sprite.zRotation = lean + Feel.talkWiggleRad * CGFloat(sin(time * Feel.talkHz * 2 * .pi))
            bobNode.setScale(1 + 0.03 * CGFloat(1 + sin(time * 4 * 2 * .pi)))
            talkFrame += dt * 8
            sprite.texture = talkTextures[Int(talkFrame) % talkTextures.count]
        } else {
            sprite.zRotation = lean
            bobNode.setScale(1)
        }
    }

    // MARK: Effects

    /// Scan cone toward `target` for 0.8 s (ART_BIBLE §14.4).
    func scan(toward target: CGPoint) {
        let angle = atan2(target.y - position.y, target.x - position.x)
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: -10))
        path.addLine(to: CGPoint(x: 90, y: -40))
        path.addLine(to: CGPoint(x: 90, y: 40))
        path.addLine(to: CGPoint(x: 0, y: 10))
        path.closeSubpath()
        let cone = SKShapeNode(path: path)
        cone.name = "pixel_scan"
        cone.fillColor = Palette.pixelLight.withAlphaComponent(0.3)
        cone.strokeColor = .clear
        cone.blendMode = .add
        cone.zRotation = angle - 0.21
        cone.zPosition = -1
        let sweep = 12 * CGFloat.pi / 180
        cone.run(.sequence([
            .group([.rotate(byAngle: sweep * 2, duration: 0.8), .sequence([.wait(forDuration: 0.5), .fadeOut(withDuration: 0.3)])]),
            .removeFromParent(),
        ]))
        bobNode.addChild(cone)
    }
}

/// Dotted hint arrow from the hero toward a target (ART_BIBLE §14.6), drawn in the world.
@MainActor
final class HintArrowNode: SKNode {
    private var dots: [SKShapeNode] = []
    private let head: SKShapeNode
    private var phase: CGFloat = 0
    private var age = 0.0
    let lifetime: Double
    let target: CGPoint

    static let spacing: CGFloat = 18
    static let startGap: CGFloat = 48
    static let endGap: CGFloat = 64
    static let maxDots = 48

    init(target: CGPoint, lifetime: Double) {
        self.target = target
        self.lifetime = lifetime
        let chevron = CGMutablePath()
        chevron.move(to: CGPoint(x: -9, y: 11))
        chevron.addLine(to: CGPoint(x: 4, y: 0))
        chevron.addLine(to: CGPoint(x: -9, y: -11))
        head = SKShapeNode(path: chevron)
        head.strokeColor = Palette.star
        head.lineWidth = 5
        head.lineCap = .round
        head.lineJoin = .round
        super.init()
        name = "hint_arrow"
        zPosition = 40
        let outline = SKShapeNode(path: chevron)
        outline.strokeColor = Palette.outline
        outline.lineWidth = 8
        outline.lineCap = .round
        outline.zPosition = -0.1
        head.addChild(outline)
        for _ in 0..<Self.maxDots {
            let d = SKShapeNode(circleOfRadius: 4)
            d.fillColor = Palette.star
            d.strokeColor = Palette.outline
            d.lineWidth = 1.5
            d.isHidden = true
            dots.append(d)
            addChild(d)
        }
        addChild(head)
        alpha = 0
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not supported") }

    var isFinished: Bool { age >= lifetime }

    func update(dt: Double, hero: CGPoint) {
        age += dt
        phase = (phase + CGFloat(dt) * 90).truncatingRemainder(dividingBy: Self.spacing)
        let fadeIn = min(1, age / 0.3), fadeOut = min(1, max(0, (lifetime - age) / 0.5))
        alpha = CGFloat(min(fadeIn, fadeOut)) * 0.9
        let dx = target.x - hero.x, dy = target.y - hero.y
        let d = hypot(dx, dy)
        let len = d - Self.startGap - Self.endGap
        guard d > 1, len > 0 else { dots.forEach { $0.isHidden = true }; head.isHidden = true; return }
        let ux = dx / d, uy = dy / d
        var i = 0
        var s = Self.startGap + phase
        while s < Self.startGap + len, i < dots.count {
            let k = (s - Self.startGap) / len
            dots[i].isHidden = false
            dots[i].position = CGPoint(x: hero.x + ux * s, y: hero.y + uy * s)
            dots[i].setScale(0.6 + 0.4 * k)
            i += 1
            s += Self.spacing
        }
        for j in i..<dots.count { dots[j].isHidden = true }
        head.isHidden = false
        head.position = CGPoint(x: hero.x + ux * (Self.startGap + len), y: hero.y + uy * (Self.startGap + len))
        head.zRotation = atan2(uy, ux)
    }
}
