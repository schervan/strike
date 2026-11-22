import SpriteKit

/// Machine (2 × 2): INTERACT with `requiresItem` in the bag consumes it and latches on;
/// without it a "needs item" bubble pops (ART_BIBLE §13.5).
@MainActor
final class MachineNode: InteractableNode {
    let requiresItem: String?
    private let bubble = SKNode()

    enum Bubble {
        static let size = CGSize(width: 56, height: 44)
        static let corner: CGFloat = 12
        static let tail = CGSize(width: 10, height: 8)
        static let gapAboveSprite: CGFloat = 8
        static let icon: CGFloat = 32
        static let holdSec = 2.0
    }

    init(element: PlacedElement, requiresItem: String?) {
        self.requiresItem = requiresItem
        super.init(element: element)
        let w = Bubble.size.width, h = Bubble.size.height
        let path = CGMutablePath()
        path.addRoundedRect(in: CGRect(x: -w / 2, y: Bubble.tail.height, width: w, height: h),
                            cornerWidth: Bubble.corner, cornerHeight: Bubble.corner)
        path.move(to: CGPoint(x: -Bubble.tail.width / 2, y: Bubble.tail.height + 1))
        path.addLine(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: Bubble.tail.width / 2, y: Bubble.tail.height + 1))
        let shape = SKShapeNode(path: path)
        shape.fillColor = .white
        shape.strokeColor = Palette.outline
        shape.lineWidth = 3
        bubble.addChild(shape)
        if let item = requiresItem {
            let icon = SKSpriteNode(texture: Textures.texture("pickup_\(item)", in: .items),
                                    size: CGSize(width: Bubble.icon, height: Bubble.icon))
            icon.position = CGPoint(x: 0, y: Bubble.tail.height + h / 2)
            icon.zPosition = 0.1
            bubble.addChild(icon)
        }
        bubble.position = CGPoint(x: 0, y: spriteSize / 2 + Bubble.gapAboveSprite)
        bubble.zPosition = 30
        bubble.isHidden = true
        addChild(bubble)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not supported") }

    var isBubbleShown: Bool { !bubble.isHidden }

    func showNeedsItem() {
        bubble.removeAllActions()
        bubble.isHidden = false
        bubble.alpha = 1
        bubble.setScale(0)
        bubble.run(.sequence([
            .scale(to: 1.15, duration: 0.14), .scale(to: 1.0, duration: 0.06),
            .wait(forDuration: Bubble.holdSec),
            .fadeOut(withDuration: 0.2), .hide(),
        ]))
        sprite.run(.sequence([.moveBy(x: 3, y: 0, duration: 0.04), .moveBy(x: -6, y: 0, duration: 0.04),
                              .moveBy(x: 6, y: 0, duration: 0.04), .moveBy(x: -3, y: 0, duration: 0.04)]))
    }

    override func setOn(_ on: Bool, animated: Bool) {
        if on {
            bubble.removeAllActions()
            bubble.isHidden = true
        }
        super.setOn(on, animated: animated)
    }
}
