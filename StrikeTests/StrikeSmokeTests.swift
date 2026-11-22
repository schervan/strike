import SpriteKit
import Testing
@testable import Strike

@MainActor
struct StrikeSmokeTests {
    @Test func gameModelStartsOnTitleAndSwitchesToGame() {
        let model = GameModel()
        #expect(model.screen == .title)
        model.startGame()
        #expect(model.screen == .game)
        model.returnToTitle()
        #expect(model.screen == .title)
    }

    @Test func gameSceneShowsPlaceholderLabel() {
        let scene = GameScene.makeDefault()
        let view = SKView(frame: CGRect(origin: .zero, size: GameScene.logicalSize))
        view.presentScene(scene)
        #expect(scene.size == GameScene.logicalSize)
        #expect(scene.childNode(withName: "placeholderLabel") is SKLabelNode)
    }

    @Test func stringCatalogHasGermanAndEnglish() {
        let localizations = Bundle.main.localizations
        #expect(localizations.contains("de"))
        #expect(localizations.contains("en"))
    }
}
