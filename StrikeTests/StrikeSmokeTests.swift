import SpriteKit
import Testing
@testable import Strike

@MainActor
struct StrikeSmokeTests {
    static func scene(_ id: String = "l1", seed: UInt64 = 42) throws -> GameScene {
        GameScene(data: try TestData.load(), levelId: id, seed: seed)
    }

    @Test func gameModelFlowsThroughLevels() throws {
        let model = GameModel(data: try TestData.load())
        #expect(model.screen == .title)
        model.startGame()
        #expect(model.screen == .game)
        #expect(model.run?.levelId == "l1")
        for (i, id) in ["l1", "l2", "l3", "l4", "l5"].enumerated() {
            #expect(model.run?.levelId == id)
            model.completeLevel(LevelResult(levelId: id, nameKey: "level.\(id).name", timeSec: 10, score: 1,
                                            datachips: 0, datachipsTotal: 3, isLast: i == 4))
            model.nextLevel()
        }
        #expect(model.screen == .title)
        model.startGame()
        model.returnToTitle()
        #expect(model.screen == .title && model.run == nil)
    }

    @Test func launchArgumentsPickLevelAndSeedOnce() throws {
        let o = LaunchOptions.parse(["app", "-StrikeAutoStart", "-StrikeLevel", "l3", "-StrikeSeed", "1234"])
        #expect(o.autoStart && o.levelId == "l3" && o.seed == 1234)
        let model = GameModel(screen: .game, data: try TestData.load(), launch: o)
        #expect(model.run?.levelId == "l3" && model.run?.seed == 1234)
        model.returnToTitle()
        model.startGame()
        #expect(model.run?.levelId == "l1")
        #expect(LaunchOptions.parse(["app"]) == LaunchOptions())
    }

    @Test func gameSceneBuildsLevelHeroAndEnemies() throws {
        let scene = try Self.scene()
        let view = SKView(frame: CGRect(origin: .zero, size: GameScene.logicalSize))
        view.presentScene(scene)
        #expect(scene.size == GameScene.logicalSize)
        #expect(scene.childNode(withName: "//level") != nil)
        #expect(scene.childNode(withName: "//tiles") is SKTileMapNode)
        #expect(scene.childNode(withName: "//hero") is HeroNode)
        #expect(scene.enemies.count == scene.level.enemySpawns.count)
        #expect(scene.built.interactables.count == scene.level.elements.count)
        #expect(scene.camera === scene.cameraNode)
        #expect(scene.hero.magazine == 12)
        #expect(scene.hero.reserve == 48)
        #expect(scene.level.grid.cell(at: scene.hero.position) == scene.level.heroStart)
    }

    @Test func sceneStepsAndPushesHUD() throws {
        let model = GameModel(data: try TestData.load())
        let scene = try Self.scene()
        scene.model = model
        #expect(model.hud.magazine == 12)
        #expect(model.hud.reserve == 48)
        #expect(model.hud.hp == model.hud.maxHp)
        #expect(model.minimap.gridWidth == scene.level.grid.width)
        #expect(model.minimap.rooms.count == 1) // the start room is revealed
        for _ in 0..<120 { scene.step(dt: 1.0 / 60) }
        model.requestReload() // full mag: ignored, no crash
        #expect(!model.hud.isReloading)
    }

    @Test func rescueReturnsHeroToTheLastCheckpoint() throws {
        let data = try TestData.load()
        let scene = try Self.scene("l2")
        let gateCheckpoint = try #require(scene.level.checkpoints.last)
        scene.hero.position = scene.level.grid.world(gateCheckpoint.cell)
        scene.step(dt: 1.0 / 60)
        #expect(scene.session.lastCheckpointId == gateCheckpoint.id)
        _ = scene.hero.health.applyDamage(data.hero.maxHp)
        scene.hero.position = scene.level.grid.world(scene.level.heroStart)
        scene.rescueHero()
        #expect(scene.hero.health.current == data.hero.maxHp)
        #expect(scene.hero.health.isInvulnerable)
        #expect(scene.hero.position == scene.level.grid.world(gateCheckpoint.cell))
        #expect(scene.session.rescues == 1)
    }

    @Test func enemyContactHurtsOncePerWindow() throws {
        let data = try TestData.load()
        let scene = try Self.scene()
        let bot = try #require(scene.enemies.first { $0.def.contactDamage > 0 })
        bot.position = CGPoint(x: scene.hero.position.x + 10, y: scene.hero.position.y)
        scene.step(dt: 1.0 / 60)
        let afterFirst = scene.hero.health.current
        #expect(afterFirst == data.hero.maxHp - bot.def.contactDamage)
        bot.position = CGPoint(x: scene.hero.position.x + 10, y: scene.hero.position.y)
        scene.step(dt: 1.0 / 60)
        #expect(scene.hero.health.current == afterFirst) // invulnerable
    }

    @Test func boltbotNoticesHeroAlertsChasesAndLeashesHome() throws {
        let data = try TestData.load()
        let scene = try Self.scene()
        let bot = try #require(scene.enemies.first { $0.def.id == "boltbot" })
        bot.position = CGPoint(x: scene.hero.position.x + 150, y: scene.hero.position.y)
        scene.step(dt: 1.0 / 60)
        #expect(bot.brain.currentState is AlertState)
        for _ in 0..<30 { scene.step(dt: 1.0 / 60) } // 0.5 s > alertSec
        #expect(bot.brain.currentState is ChaseState || bot.brain.currentState is HopState)
        // Hero far away (exit room) for longer than returnAfterSec → return home, full HP there.
        _ = bot.health.applyDamage(10)
        bot.brain.enter(ChaseState.self)
        let home = bot.spawnPoint
        let far = try #require(scene.level.rooms.map { $0.rect.centerCell }.max { a, b in
            hypot(scene.level.grid.world(a).x - home.x, scene.level.grid.world(a).y - home.y)
                < hypot(scene.level.grid.world(b).x - home.x, scene.level.grid.world(b).y - home.y)
        })
        let leash = data.rules.leash
        var returned = false
        for _ in 0..<Int((leash.returnAfterSec + 0.5) * 60) {
            scene.hero.position = scene.level.grid.world(far)
            scene.step(dt: 1.0 / 60)
            if bot.isReturningHome { returned = true; break }
        }
        #expect(returned)
        bot.position = bot.spawnPoint
        scene.step(dt: 1.0 / 60)
        #expect(bot.brain.currentState is IdleState)
        #expect(bot.health.current == bot.health.max)
    }

    @Test func interactActivatesTheFocusedButton() throws {
        let scene = try Self.scene()
        let button = try #require(scene.level.elements.first { $0.type == .button })
        scene.hero.position = CGPoint(x: button.position.x - 48, y: button.position.y)
        scene.step(dt: 1.0 / 60)
        #expect(scene.focusedId == button.id)
        #expect(scene.hudState.interact?.usable == true)
        scene.handle(.interact)
        #expect(scene.puzzle.isOn(button.id))
        #expect(scene.built.interactables[button.id]?.isOn == true)
        scene.step(dt: 1.0 / 60)
        #expect(scene.hudState.interact?.usable == false)
    }

    @Test func machineIsFocusableFromEverySideCell() throws {
        let scene = try Self.scene("l4", seed: 3)
        for m in scene.level.elements where m.type == .machine {
            let a = m.cell
            for c in [GridPoint(a.x - 1, a.y), GridPoint(a.x + 2, a.y + 1), GridPoint(a.x, a.y - 1), GridPoint(a.x + 1, a.y + 2)] {
                scene.hero.position = scene.level.grid.world(c)
                scene.step(dt: 1.0 / 60)
                #expect(scene.focusedId == m.id, "\(m.id) from \(c)")
            }
        }
    }

    @Test func exitTriggersFromEitherCellOfATwoWideNiche() throws {
        let scene = try Self.scene("l2")
        scene.handle(.debugSolveAll)
        scene.hero.position = scene.level.grid.world(scene.level.exitPad)
        for _ in 0..<30 { scene.step(dt: 1.0 / 60) }
        #expect(scene.isComplete)
    }

    @Test func plateNeedsTheHeroOnItsCell() throws {
        let data = try TestData.load()
        let scene = try Self.scene("l3")
        let plate = try #require(scene.level.elements.first { $0.type == .pressureplate })
        scene.hero.position = plate.position
        let frames = Int(data.rules.puzzle.plateHoldSec * 60) + 3
        for _ in 0..<frames {
            scene.hero.position = plate.position
            scene.step(dt: 1.0 / 60)
        }
        #expect(scene.puzzle.isOn(plate.id))
    }

    @Test func machineWithoutItemToastsAndWithItemTurnsOn() throws {
        let model = GameModel(data: try TestData.load())
        let scene = try Self.scene("l2")
        scene.model = model
        let machine = try #require(scene.level.elements.first { $0.type == .machine })
        scene.hero.position = CGPoint(x: machine.position.x - 90, y: machine.position.y)
        scene.step(dt: 1.0 / 60)
        #expect(scene.focusedId == machine.id)
        scene.handle(.interact)
        #expect(!scene.puzzle.isOn(machine.id))
        #expect(model.toast != nil)
        // Pick up the fuse, come back.
        let fuse = try #require(scene.level.itemPlacements.first { $0.elementId == machine.id })
        for _ in 0..<30 {
            scene.hero.position = scene.level.grid.world(fuse.cell)
            scene.step(dt: 1.0 / 60)
        }
        #expect(scene.inventory.count(of: "fuse") == 1)
        #expect(model.hud.carried["fuse"] == 1)
        scene.hero.position = CGPoint(x: machine.position.x - 90, y: machine.position.y)
        scene.step(dt: 1.0 / 60)
        scene.handle(.interact)
        #expect(scene.puzzle.isOn(machine.id))
        #expect(scene.inventory.count(of: "fuse") == 0)
    }

    @Test func solveAllOpensDoorsAndTheExitPadEndsTheLevel() throws {
        let scene = try Self.scene("l4", seed: 3)
        let gate = try #require(scene.level.gates.first)
        #expect(!scene.solidGrid.isWalkable(gate.cells[0]))
        scene.handle(.debugSolveAll)
        #expect(scene.puzzle.isExitOpen)
        #expect(scene.built.gates.values.allSatisfy(\.isOpen) && scene.built.exitDoor.isOpen)
        #expect(scene.solidGrid.isWalkable(gate.cells[0]))
        #expect(scene.pathfinder.grid.isWalkable(scene.level.exitDoor.cells[0]))
        let model = GameModel(data: try TestData.load())
        scene.model = model
        model.startLevel(id: "l4", seed: 3)
        scene.handle(.debugGotoExit)
        for _ in 0..<60 { scene.step(dt: 1.0 / 60) }
        #expect(scene.isComplete)
        if case .levelComplete(let r) = model.screen { #expect(r.levelId == "l4") } else { Issue.record("no Level complete card") }
    }

    @Test func lastElementStartsTheDoorPanAndATapSkipsIt() throws {
        let scene = try Self.scene()
        for e in scene.level.elements where e.type != .lever {
            scene.hero.position = CGPoint(x: e.position.x - 48, y: e.position.y)
            scene.step(dt: 1.0 / 60)
            scene.handle(.interact)
        }
        let lever = try #require(scene.level.elements.first { $0.type == .lever })
        scene.hero.position = CGPoint(x: lever.position.x - 48, y: lever.position.y)
        scene.step(dt: 1.0 / 60)
        scene.handle(.interact)
        #expect(scene.puzzle.isExitOpen)
        #expect(!scene.built.exitDoor.isOpen) // pan runs first
        let heroBefore = scene.hero.position
        scene.step(dt: 0.5)
        #expect(scene.hero.position == heroBefore) // input locked
        scene.touchesBegan([], with: nil)          // tap skips
        #expect(scene.built.exitDoor.isOpen)
    }

    @Test func crateBreaksAfterEnoughDamage() throws {
        let data = try TestData.load()
        let scene = try Self.scene("l4", seed: 3)
        let crate = try #require(scene.built.crates.first)
        var hits = 0
        while !crate.hit(damage: 10) { hits += 1; if hits > 100 { break } }
        #expect(crate.isBroken)
        #expect((hits + 1) * 10 >= data.rules.crate.hp)
    }

    @Test(arguments: ["l1", "l2", "l3", "l4", "l5"])
    func nodeBudgetPerLevel(_ id: String) throws {
        let scene = try Self.scene(id, seed: 7)
        func count(_ n: SKNode) -> Int { 1 + n.children.reduce(0) { $0 + count($1) } }
        let n = count(scene)
        print("[nodes] \(id): \(n)")
        #expect(n < 1500, "\(id): \(n) nodes")
    }

    @Test func heroStarterHasSafetyNetWired() throws {
        let data = try TestData.load()
        let scene = try Self.scene()
        #expect(scene.hero.weapon.safetyNet == data.hero.starterSafetyNet)
    }

    @Test func stringCatalogHasGermanAndEnglish() {
        let localizations = Bundle.main.localizations
        #expect(localizations.contains("de"))
        #expect(localizations.contains("en"))
    }
}
