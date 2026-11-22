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

    @Test func gameSceneBuildsRoomHeroAndBoltbots() throws {
        let scene = GameScene(data: try TestData.load(), seed: 1)
        let view = SKView(frame: CGRect(origin: .zero, size: GameScene.logicalSize))
        view.presentScene(scene)
        #expect(scene.size == GameScene.logicalSize)
        #expect(scene.childNode(withName: "//room") != nil)
        #expect(scene.childNode(withName: "//hero") is HeroNode)
        #expect(scene.enemies.count == 3)
        #expect(scene.camera === scene.cameraNode)
        #expect(scene.hero.weapon.magazine == 12)
        #expect(scene.hero.weapon.reserve == 48)
        #expect(scene.hero.animator.sprite.texture != nil)
    }

    @Test func sceneStepsAndPushesHUD() throws {
        let model = GameModel()
        let scene = GameScene(data: try TestData.load(), seed: 1)
        scene.model = model
        #expect(model.hud.magazine == 12)
        #expect(model.hud.reserve == 48)
        #expect(model.hud.hp == model.hud.maxHp)
        #expect(!model.hud.canReload)
        for _ in 0..<120 { scene.step(dt: 1.0 / 60) }
        #expect(model.hud.hp == model.hud.maxHp) // boltbots are far away and idle
        model.requestReload() // full mag: ignored, no crash
        #expect(!model.hud.isReloading)
    }

    @Test func rescueRestoresHeroAtSpawn() throws {
        let data = try TestData.load()
        let scene = GameScene(data: data, seed: 1)
        _ = scene.hero.health.applyDamage(data.hero.maxHp)
        scene.hero.position = CGPoint(x: 600, y: 400)
        scene.rescueHero()
        #expect(scene.hero.health.current == data.hero.maxHp)
        #expect(scene.hero.health.isInvulnerable)
        #expect(scene.hero.position == scene.room.heroSpawn)
    }

    @Test func boltbotContactHurtsOncePerWindow() throws {
        let data = try TestData.load()
        let scene = GameScene(data: data, seed: 1)
        let bot = try #require(scene.enemies.first)
        bot.position = CGPoint(x: scene.hero.position.x + 10, y: scene.hero.position.y)
        scene.step(dt: 1.0 / 60)
        let afterFirst = scene.hero.health.current
        #expect(afterFirst == data.hero.maxHp - bot.def.contactDamage)
        bot.position = CGPoint(x: scene.hero.position.x + 10, y: scene.hero.position.y)
        scene.step(dt: 1.0 / 60)
        #expect(scene.hero.health.current == afterFirst) // invulnerable
    }

    @Test func boltbotNoticesHeroAndAlertsThenChases() throws {
        let scene = GameScene(data: try TestData.load(), seed: 1)
        let bot = try #require(scene.enemies.first)
        bot.position = CGPoint(x: scene.hero.position.x + 200, y: scene.hero.position.y)
        scene.step(dt: 1.0 / 60)
        #expect(bot.brain.currentState is AlertState)
        for _ in 0..<30 { scene.step(dt: 1.0 / 60) } // 0.5 s > alertSec
        #expect(bot.brain.currentState is ChaseState || bot.brain.currentState is HopState)
    }

    @Test func heroStarterHasSafetyNetWired() throws {
        let data = try TestData.load()
        let scene = GameScene(data: data, seed: 1)
        #expect(scene.hero.weapon.safetyNet == data.hero.starterSafetyNet)
    }

    @Test func stringCatalogHasGermanAndEnglish() {
        let localizations = Bundle.main.localizations
        #expect(localizations.contains("de"))
        #expect(localizations.contains("en"))
    }
}
