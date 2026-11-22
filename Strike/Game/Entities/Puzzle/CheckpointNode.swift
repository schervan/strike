import SpriteKit

/// Checkpoint pad (ART_BIBLE §13.6). Touching it saves it (`LevelSession.touchCheckpoint`).
@MainActor
final class CheckpointNode: SKNode {
    let checkpointId: String
    private let sprite: SKSpriteNode
    private let glow: SKSpriteNode
    private(set) var isOn = false

    /// Hero centre within this distance of the pad centre touches it.
    static let triggerRadius: CGFloat = 28
    static let glowDiameter: CGFloat = 88

    init(checkpoint: CheckpointPlacement, grid: TileGrid) {
        checkpointId = checkpoint.id
        let t = TileGrid.tileSize
        sprite = SKSpriteNode(texture: Textures.texture("puzzle_checkpoint_off", in: .puzzle), size: CGSize(width: t, height: t))
        glow = Textures.glow(diameter: Self.glowDiameter, color: Palette.pixelCyan, alpha: 0.18)
        super.init()
        name = "checkpoint_\(checkpoint.id)"
        position = grid.world(checkpoint.cell)
        glow.zPosition = 1.9
        sprite.zPosition = InteractableNode.Z.floorProp
        addChild(glow)
        addChild(sprite)
        pulse(from: 0.10, to: 0.22)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not supported") }

    private func pulse(from a: CGFloat, to b: CGFloat) {
        let up = SKAction.fadeAlpha(to: b, duration: 0.8), down = SKAction.fadeAlpha(to: a, duration: 0.8)
        up.timingMode = .easeInEaseOut
        down.timingMode = .easeInEaseOut
        glow.removeAllActions()
        glow.run(.repeatForever(.sequence([up, down])))
    }

    func setOn(_ on: Bool, animated: Bool) {
        guard on != isOn else { return }
        isOn = on
        sprite.texture = Textures.texture(on ? "puzzle_checkpoint_on" : "puzzle_checkpoint_off", in: .puzzle)
        glow.color = on ? Palette.stateOn : Palette.pixelCyan
        pulse(from: on ? 0.2 : 0.10, to: on ? 0.35 : 0.22)
        guard on, animated else { return }
        let ring = SKShapeNode(circleOfRadius: TileGrid.tileSize / 2)
        ring.strokeColor = .white
        ring.lineWidth = 3
        ring.fillColor = .clear
        ring.setScale(0.5)
        ring.zPosition = 3
        ring.run(.sequence([.group([.scale(to: 2.0, duration: 0.4), .fadeOut(withDuration: 0.4)]), .removeFromParent()]))
        addChild(ring)
        parent?.addChild(Particles.stateOn(at: position, color: Palette.pixelCyan, count: 10))
    }
}
