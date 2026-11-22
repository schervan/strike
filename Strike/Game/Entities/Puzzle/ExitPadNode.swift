import SpriteKit

/// Exit pad behind the exit door (ART_BIBLE §13.6): lights up once the exit door is open.
@MainActor
final class ExitPadNode: SKNode {
    private let sprite: SKSpriteNode
    private let glow: SKSpriteNode
    private(set) var isOn = false

    static let triggerRadius: CGFloat = 28
    /// Seconds the hero must stand on the pad.
    static let standSec = 0.3
    static let glowDiameter: CGFloat = 120
    /// White flash ring time before the Level complete card (ART_BIBLE §13.6).
    static let flashSec = 0.4

    init(position p: CGPoint) {
        let t = TileGrid.tileSize
        sprite = SKSpriteNode(texture: Textures.texture("puzzle_exitpad_off", in: .puzzle), size: CGSize(width: t, height: t))
        glow = Textures.glow(diameter: Self.glowDiameter, color: Palette.star, alpha: 0)
        super.init()
        name = "exitPad"
        position = p
        glow.zPosition = 1.9
        sprite.zPosition = InteractableNode.Z.floorProp
        addChild(glow)
        addChild(sprite)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not supported") }

    func setOn(_ on: Bool) {
        guard on != isOn else { return }
        isOn = on
        sprite.texture = Textures.texture(on ? "puzzle_exitpad_on" : "puzzle_exitpad_off", in: .puzzle)
        glow.removeAllActions()
        guard on else { glow.alpha = 0; return }
        let up = SKAction.fadeAlpha(to: 0.45, duration: 0.6), down = SKAction.fadeAlpha(to: 0.25, duration: 0.6)
        glow.run(.repeatForever(.sequence([up, down])))
    }

    func playReached() {
        let ring = SKShapeNode(circleOfRadius: TileGrid.tileSize / 2)
        ring.strokeColor = .white
        ring.lineWidth = 3
        ring.fillColor = .clear
        ring.setScale(0.5)
        ring.alpha = 0.9
        ring.zPosition = 3
        ring.run(.sequence([.group([.scale(to: 2.2, duration: 0.4), .fadeOut(withDuration: 0.4)]), .removeFromParent()]))
        addChild(ring)
    }
}
