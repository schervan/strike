import SpriteKit

/// A dropped item: pops out in a short arc, bobs, and is collected when the hero is within
/// `hero.pickupRadius` (magnetic items are pulled in from `hero.magnetRadius`). Readability
/// (ART_BIBLE §13.8): additive halo and a plum shadow on the ground. A pickup the bag cannot take
/// shows a floating "!" (§14.3) while the hero is near.
@MainActor
final class PickupNode: SKSpriteNode {
    let item: ItemDef
    /// Stack size of this pickup (drops from the bag can be whole stacks).
    let count: Int
    /// Generator placement id (datachips, puzzle items); nil for loot drops.
    var placementId: String?
    /// Dropped from the bag: not picked up again until the hero has left the pickup radius once.
    var waitsForHeroToLeave = false
    /// The last try was refused (`staysBagFull`).
    private(set) var isBlocked = false

    private let halo: SKSpriteNode
    private let shadowNode: SKShapeNode
    private var marker: SKNode?
    private let haloAlpha: CGFloat
    private var haloPhase = Double.random(in: 0..<1)

    private var basePosition: CGPoint
    private var popFrom: CGPoint
    private var popTo: CGPoint
    private var popAge: Double = 0
    private var bobPhase = Double.random(in: 0..<1)
    private(set) var isCollected = false

    /// Pop-out arc timing and height (ART_BIBLE §12 power-down step 3).
    static let popSec = 0.25
    static let popHeight: CGFloat = 24
    /// Max distance from the drop point (GDD §10 step 5).
    static let maxPopDistance: CGFloat = 48
    static let bobAmplitude: CGFloat = 3
    static let bobPeriod = 1.2
    /// "!" marker shows while the hero is within this distance (ART_BIBLE §14.3: 3 tiles).
    static let markerRange: CGFloat = 192
    /// Magnet pull speed relative to the hero's move speed (feel constant).
    static let magnetSpeedFactor: CGFloat = 2.0

    /// `darkFloor`: L4/L5 halo strength (ART_BIBLE §13.8).
    init(item: ItemDef, from: CGPoint, to: CGPoint, count: Int = 1, darkFloor: Bool = false) {
        self.item = item
        self.count = max(1, count)
        basePosition = from
        popFrom = from
        popTo = to
        haloAlpha = darkFloor ? 0.38 : 0.28
        halo = Textures.glow(diameter: item.id == "energycore" ? 52 : 44, color: .white, alpha: haloAlpha)
        halo.zPosition = -0.2
        shadowNode = SKShapeNode(ellipseOf: CGSize(width: 22, height: 8))
        shadowNode.fillColor = Palette.outline.withAlphaComponent(0.25)
        shadowNode.strokeColor = .clear
        shadowNode.zPosition = -0.3
        let tex = Textures.texture(item.pickupTextureName, in: .items)
        super.init(texture: tex, color: .white, size: tex.size())
        name = "pickup_\(item.id)"
        position = from
        zPosition = 5
        addChild(shadowNode)
        addChild(halo)
    }

    /// Bag full: the "!" marker and a dimmed halo; cleared when the bag takes it.
    func setBlocked(_ on: Bool) {
        guard on != isBlocked else { return }
        isBlocked = on
        if on {
            run(.sequence([.moveBy(x: 3, y: 0, duration: 0.02), .moveBy(x: -6, y: 0, duration: 0.04),
                           .moveBy(x: 6, y: 0, duration: 0.04), .moveBy(x: -3, y: 0, duration: 0.02)]))
        } else {
            marker?.removeFromParent()
            marker = nil
        }
    }

    /// Shows the "!" only while the hero is near (call per frame for blocked pickups).
    func updateMarker(heroDistance d: CGFloat) {
        guard isBlocked else { return }
        let show = d <= Self.markerRange
        if show, marker == nil {
            let m = Self.makeMarker()
            m.position = CGPoint(x: 0, y: 22 + size.height / 2)
            m.alpha = 0
            m.run(.fadeIn(withDuration: 0.15))
            m.run(.repeatForever(.sequence([.moveBy(x: 0, y: 3, duration: 0.5), .moveBy(x: 0, y: -3, duration: 0.5)])))
            addChild(m)
            marker = m
        } else if !show, let m = marker {
            marker = nil
            m.run(.sequence([.fadeOut(withDuration: 0.15), .removeFromParent()]))
        }
    }

    var hasMarker: Bool { marker != nil }

    static func makeMarker() -> SKNode {
        let n = SKShapeNode(circleOfRadius: 11)
        n.name = "bagFullMarker"
        n.fillColor = Palette.star
        n.strokeColor = Palette.outline
        n.lineWidth = 2
        n.zPosition = 1
        let l = SKLabelNode(text: "!")
        l.fontName = "AvenirNext-Heavy"
        l.fontSize = 16
        l.fontColor = Palette.outline
        l.verticalAlignmentMode = .center
        n.addChild(l)
        return n
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not supported") }

    var hasLanded: Bool { popAge >= Self.popSec }
    var groundPosition: CGPoint { basePosition }

    /// Moves along the pop arc, bobs, and drifts toward `magnetTarget` when given.
    func step(dt: Double, magnetTarget: CGPoint?, magnetSpeed: CGFloat) {
        guard !isCollected else { return }
        if !hasLanded {
            popAge = min(Self.popSec, popAge + dt)
            let t = CGFloat(popAge / Self.popSec)
            let e = 1 - (1 - t) * (1 - t)
            basePosition = CGPoint(x: popFrom.x + (popTo.x - popFrom.x) * e,
                                   y: popFrom.y + (popTo.y - popFrom.y) * e)
            position = CGPoint(x: basePosition.x, y: basePosition.y + Self.popHeight * sin(.pi * t))
            return
        }
        if let target = magnetTarget {
            let dx = target.x - basePosition.x, dy = target.y - basePosition.y
            let d = hypot(dx, dy)
            if d > 0 {
                let stepLen = min(d, magnetSpeed * CGFloat(dt))
                basePosition.x += dx / d * stepLen
                basePosition.y += dy / d * stepLen
            }
        }
        bobPhase += dt / Self.bobPeriod
        let bob = Self.bobAmplitude * CGFloat(sin(bobPhase * 2 * .pi))
        position = CGPoint(x: basePosition.x, y: basePosition.y + bob)
        // Halo and shadow stay on the ground while the sprite bobs.
        halo.position = CGPoint(x: 0, y: -bob)
        shadowNode.position = CGPoint(x: 0, y: -bob - 12)
        haloPhase += dt / 1.4
        let base = isBlocked ? 0.12 : haloAlpha
        halo.alpha = base + (isBlocked ? 0 : 0.06 * CGFloat(sin(haloPhase * 2 * .pi)))
    }

    /// Flies up 20 pt while shrinking, then removes itself.
    func collect() {
        guard !isCollected else { return }
        isCollected = true
        run(.sequence([
            .group([.moveBy(x: 0, y: 20, duration: 0.15), .scale(to: 0, duration: 0.15)]),
            .removeFromParent(),
        ]))
    }
}
