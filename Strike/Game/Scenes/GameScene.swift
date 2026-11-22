import SpriteKit

/// Main gameplay scene. M0: empty dark scene with a placeholder label.
final class GameScene: SKScene {
    /// Logical scene size (iPad landscape points); `.aspectFill` scales to the device.
    static let logicalSize = CGSize(width: 1194, height: 834)

    weak var model: GameModel?

    static func makeDefault() -> GameScene {
        let scene = GameScene(size: logicalSize)
        scene.scaleMode = .aspectFill
        scene.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        return scene
    }

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.05, green: 0.06, blue: 0.10, alpha: 1)
        guard childNode(withName: "placeholderLabel") == nil else { return }

        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.name = "placeholderLabel"
        label.text = String(localized: "game.placeholder")
        label.fontSize = 48
        label.fontColor = SKColor(white: 1, alpha: 0.85)
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        addChild(label)
    }
}
