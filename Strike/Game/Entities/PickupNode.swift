import SpriteKit

/// A dropped item: pops out in a short arc, bobs, and is collected when the hero is within
/// `hero.pickupRadius` (magnetic items are pulled in from `hero.magnetRadius`).
@MainActor
final class PickupNode: SKSpriteNode {
    let item: ItemDef

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
    static let bobAmplitude: CGFloat = 2
    static let bobPeriod = 1.2
    /// Magnet pull speed relative to the hero's move speed (feel constant).
    static let magnetSpeedFactor: CGFloat = 2.0

    init(item: ItemDef, from: CGPoint, to: CGPoint) {
        self.item = item
        basePosition = from
        popFrom = from
        popTo = to
        let tex = Textures.texture(item.pickupTextureName, in: .items)
        super.init(texture: tex, color: .white, size: tex.size())
        name = "pickup_\(item.id)"
        position = from
        zPosition = 5
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
        position = CGPoint(x: basePosition.x,
                           y: basePosition.y + Self.bobAmplitude * CGFloat(sin(bobPhase * 2 * .pi)))
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
