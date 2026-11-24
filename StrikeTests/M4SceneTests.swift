import Foundation
import SpriteKit
import Testing
@testable import Strike

/// M4-5 / M4-6 scene checks: real enemy behaviours in a debug spawn room (telegraph before every
/// damaging attack, shots stop at walls, shield block, spore slow, slime split), blaster pickup +
/// SWAP, rescue clears enemy shots, the boss arena (rescue reset, Continue), the HUD camera
/// nudge (QA-015), the hint chevron, live settings, QA-011 and the node budget.
@MainActor
struct M4SceneTests {
    static var data: GameData { GeneratedCorpus.data }

    static func scene(_ id: String = "l1", seed: UInt64 = 42, run: RunState? = nil, stage: LevelStage = .level,
                      clearEnemies: Bool = true) -> GameScene {
        let s = GameScene(data: data, levelId: id, seed: seed, run: run, stage: stage)
        let v = SKView(frame: CGRect(origin: .zero, size: GameScene.logicalSize))
        v.presentScene(s)
        if clearEnemies { for e in s.enemies { s.enemyDirector.remove(e) } }
        s.step(dt: 1.0 / 60)
        return s
    }

    /// One frame: scene step + enemy movement by hand (physics does not run headless).
    static func frame(_ s: GameScene, dt: Double = 1.0 / 30) {
        s.step(dt: dt)
        for e in s.enemies where !e.isPoweredDown && !e.isBoss {
            let p = CGPoint(x: e.position.x + e.desiredVelocity.dx * CGFloat(dt), y: e.position.y + e.desiredVelocity.dy * CGFloat(dt))
            if !s.solidGrid.isBlocked(p, radius: e.radius * 0.8) { e.position = p }
        }
    }

    /// A walkable spot `d` pt from the hero with line of sight.
    static func spot(_ s: GameScene, _ d: CGFloat) -> CGPoint? {
        for k in 0..<16 {
            let a = CGFloat(k) * .pi / 8
            let p = CGPoint(x: s.hero.position.x + cos(a) * d, y: s.hero.position.y + sin(a) * d)
            if !s.solidGrid.isBlocked(p, radius: 24), s.solidGrid.hasLineOfSight(from: s.hero.position, to: p) { return p }
        }
        return nil
    }

    static func add(_ s: GameScene, _ id: String, at p: CGPoint) throws -> EnemyNode {
        try #require(s.enemyDirector.spawn(id, at: p, aware: true))
    }

    // MARK: Behaviours (GDD §8.1)

    @Test func everyBehaviourGetsItsOwnStateMachine() throws {
        let s = Self.scene()
        let expected: [String: AnyClass] = ["boltbot": ChaseState.self, "slimemutant_small": ChaseState.self,
                                            "slimemutant": ChaseState.self, "laserdrone": KiteState.self,
                                            "shieldandroid": ShieldState.self, "sporeplant": TurretState.self]
        let p = try #require(Self.spot(s, 200))
        for (id, cls): (String, AnyClass) in expected {
            let e = try Self.add(s, id, at: p)
            #expect(ObjectIdentifier(e.activeState) == ObjectIdentifier(cls), "\(id)")
            for _ in 0..<20 { Self.frame(s) }
            #expect(e.brain.currentState.map { ObjectIdentifier(type(of: $0)) } != ObjectIdentifier(IdleState.self), "\(id) woke up")
            s.enemyDirector.remove(e)
        }
    }

    @Test func droneTelegraphsBeforeEveryShotAndItsShotHurts() throws {
        let s = Self.scene()
        s.hero.health.reset(invulnerableFor: 0)
        let p = try #require(Self.spot(s, 260))
        let drone = try Self.add(s, "laserdrone", at: p)
        let tel = try #require(drone.def.attack?.telegraphSec)
        var t = 0.0, telegraphAt: [Double] = [], shots: [Double] = []
        var hpBefore = s.hero.health.current, hurt = false
        var lastShots = 0
        while t < 12 {
            let hadTelegraph = drone.telegraphNode != nil
            Self.frame(s)
            t += 1.0 / 30
            if drone.telegraphNode != nil, !hadTelegraph { telegraphAt.append(t) }
            if s.enemyShots.activeCount > lastShots { shots.append(t) }
            lastShots = s.enemyShots.activeCount
            if s.hero.health.current < hpBefore { hurt = true; hpBefore = s.hero.health.current }
        }
        #expect(shots.count >= 3, "drone fired \(shots.count) times")
        for shot in shots {
            let glow = try #require(telegraphAt.last { $0 <= shot }, "no telegraph before the shot at \(shot)")
            #expect(shot - glow >= tel - 1.0 / 30 - 1e-6, "glow \(shot - glow) s before the shot")
        }
        #expect(hurt, "the laser ball hurts the hero")
    }

    @Test func enemyShotsStopAtWalls() throws {
        let s = Self.scene()
        let h = s.hero.position
        // Fire toward every direction; no shot may ever stand inside a wall.
        for k in 0..<8 {
            let a = CGFloat(k) * .pi / 4
            s.combat.spawnEnemyShot(kind: .laser, at: h, angle: a, speed: 300, radius: 10, damage: 1, range: 4000)
        }
        s.hero.position = CGPoint(x: -10_000, y: -10_000)          // out of the way
        var t = 0.0
        while s.enemyShots.activeCount > 0, t < 20 {
            s.step(dt: 1.0 / 60)
            s.enemyShots.forEachActive { #expect(!s.solidGrid.isBlocked($0.position, radius: 1), "shot inside a wall") }
            t += 1.0 / 60
        }
        #expect(s.enemyShots.activeCount == 0, "all shots popped at walls")
    }

    @Test func shieldBlocksFrontShotsAndBackShotsHurt() throws {
        let s = Self.scene()
        let p = try #require(Self.spot(s, 150))
        let android = try Self.add(s, "shieldandroid", at: p)
        for _ in 0..<20 { Self.frame(s) }
        let sp = try #require(android.shield)
        let hp = android.health.current
        // Front: the shot travels against the facing.
        ScenePlaythroughTests.shootAlong(s, at: android, angle: sp.facing + .pi)
        #expect(android.health.current == hp, "front shot blocked")
        ScenePlaythroughTests.shootAlong(s, at: android, angle: sp.facing)
        #expect(android.health.current < hp, "back shot hurts")
    }

    @Test func sporesSlowTheHeroAndThePlantNeverMoves() throws {
        let s = Self.scene()
        s.hero.health.reset(invulnerableFor: 0)
        let p = try #require(Self.spot(s, 200))
        let plant = try Self.add(s, "sporeplant", at: p)
        let a = try #require(plant.def.attack)
        var slowed = false, t = 0.0
        while t < 8, !slowed {
            Self.frame(s)
            t += 1.0 / 30
            #expect(plant.position == p, "the plant never moves")
            slowed = s.hero.status.isSlowed
        }
        #expect(slowed, "a spore slows the hero")
        #expect(abs(s.hero.status.speedMultiplier - a.slowMultiplier!) < 1e-9)
        #expect(s.hudState.slowed)
    }

    @Test func slimeSplitsIntoTwoHarmlessSmallsThatPopOut() throws {
        let s = Self.scene()
        let p = try #require(Self.spot(s, 180))
        let slime = try Self.add(s, "slimemutant", at: p)
        var shots = 0
        while !slime.isPoweredDown, shots < 50 { ScenePlaythroughTests.shoot(s, at: slime); shots += 1 }
        let smalls = s.enemies.filter { $0.def.id == "slimemutant_small" }
        #expect(smalls.count == 2)
        for k in smalls {
            #expect(k.isHarmless && !k.isDamageable, "pop-out: harmless and not damageable")
            #expect(!s.solidGrid.isBlocked(k.position, radius: k.radius * 0.9) || k.position == slime.position)
        }
        for _ in 0..<12 { Self.frame(s) }
        for k in smalls { #expect(!k.isHarmless && k.isDamageable, "after the pop-out") }
        #expect(smalls.allSatisfy { $0.def.splitInto == nil }, "smalls never split")
    }

    // MARK: Blasters (GDD §5)

    @Test func blasterPickupThenSwapWithSwapTimeAndPixelLine() throws {
        let s = Self.scene("l2", seed: 11)
        let model = GameModel(data: Self.data)
        s.model = model
        let pick = try #require(s.level.pickups.first { $0.kind == .weapon })
        #expect(!model.hud.swapVisible)
        s.hero.position = s.level.grid.world(pick.cell)
        for _ in 0..<20 { s.step(dt: 1.0 / 30) }
        #expect(s.hero.loadout.owns(pick.itemId), "picked up")
        #expect(s.hero.loadout.equipped == "blaster_starter", "not equipped automatically")
        #expect(model.hud.swapVisible && model.hud.nextWeaponId == pick.itemId)
        let said = [s.pixelBrain.speech.current?.key].compactMap { $0 } + s.pixelBrain.speech.pending.map(\.key)
        #expect(s.pixelBrain.story.seenTriggers.contains("firstSwapVisible"))
        #expect(said.contains("pixel.l2.swap") || said.contains("pixel.l2.spread"), "Pixel talks about it: \(said)")
        s.handle(.swapNext)
        #expect(s.hero.loadout.equipped == pick.itemId && s.hero.weapon.isSwapping)
        #expect(model.hud.isSwapping)
        let fired = s.hero.tryFire(triggerHeld: true)
        #expect(!fired, "no fire while swapping")
        for _ in 0..<10 { s.step(dt: 1.0 / 30) }
        #expect(!s.hero.weapon.isSwapping)
        s.handle(.swapTo("blaster_starter"))
        #expect(s.hero.loadout.equipped == "blaster_starter")
    }

    @Test func spreadFiresFivePelletsInTheScene() throws {
        let s = Self.scene()
        s.handle(.debugGiveBlasters)
        s.handle(.swapTo("blaster_spread"))
        for _ in 0..<10 { s.step(dt: 1.0 / 30) }
        #expect(s.hero.weapon.def.id == "blaster_spread" && !s.hero.weapon.isSwapping)
        let before = s.pool.activeCount
        s.combat.updateTrigger(fireHeld: true)
        #expect(s.pool.activeCount - before == s.hero.weapon.def.pellets)
    }

    // MARK: Rescue and arena

    @Test func rescueBeamPopsEveryEnemyShot() {
        let s = Self.scene()
        for k in 0..<5 {
            s.combat.spawnEnemyShot(kind: .spore, at: CGPoint(x: s.hero.position.x + 300, y: s.hero.position.y),
                                    angle: CGFloat(k), speed: 10, radius: 12, damage: 4, range: 500, slowMultiplier: 0.7, slowSec: 2)
        }
        #expect(s.enemyShots.activeCount == 5)
        s.hero.health.reset(invulnerableFor: 0)
        s.damageHero(1000)
        #expect(s.rescue != nil && s.enemyShots.activeCount == 0)
    }

    @Test func arenaHasTheBossBarAndARescueKeepsTheBossDamageAndCores() throws {
        var run = RunState.newGame(data: Self.data)
        run.arena = ArenaProgress(levelId: "l5", elapsed: 300, score: 1234, bolts: 3, datachipsFound: ["d1"], rescues: 1)
        let s = Self.scene("l5", run: run, stage: .bossArena, clearEnemies: false)
        let model = GameModel(data: Self.data)
        s.model = model
        s.step(dt: 1.0 / 60)
        let boss = try #require(s.boss)
        #expect(s.session.elapsed >= 300 && s.session.score >= 1234 && s.session.rescues == 1, "L5 session carried")
        #expect(model.hud.boss?.phase == 1 && model.hud.boss?.notches.count == 2)
        #expect(s.hero.position == s.level.grid.world(s.level.checkpoints[0].cell), "starts at the arena checkpoint")
        boss.debugNextPhase()
        for _ in 0..<30 { s.step(dt: 1.0 / 30) }
        #expect(model.hud.boss?.immune == true && model.hud.boss?.coresNeeded == 2)
        boss.coreInserted(); boss.coreInserted()
        #expect(!boss.brain.isImmune)
        for _ in 0..<30 { s.step(dt: 1.0 / 30) }                // dizzy, phase lock over
        boss.applyDamage(150)
        let hpBefore = boss.brain.hp
        #expect(hpBefore < 800)
        s.hero.health.reset(invulnerableFor: 0)
        s.hero.position = CGPoint(x: s.hero.position.x + 200, y: s.hero.position.y)
        s.damageHero(1000)
        var t = 0.0
        while s.rescue != nil, t < 5 { s.step(dt: 0.05); t += 0.05 }
        #expect(boss.brain.hp == hpBefore && boss.brain.coresInserted == 2 && !boss.brain.isImmune, "QA-016: damage and cores stay")
        #expect(hypot(s.hero.position.x - s.respawnPoint.x, s.hero.position.y - s.respawnPoint.y) < 40)
        #expect(s.session.rescues == 2)
    }

    @Test func arenaDefeatLeadsToSeasonComplete() throws {
        var run = RunState.newGame(data: Self.data)
        run.arena = ArenaProgress(levelId: "l5")
        let s = Self.scene("l5", run: run, stage: .bossArena, clearEnemies: false)
        let model = GameModel(data: Self.data)
        model.startLevel(id: "l5", seed: 1)
        s.model = model
        let boss = try #require(s.boss)
        for _ in 0..<3 { boss.debugNextPhase(); s.step(dt: 0.05) }
        #expect(boss.isDefeated)
        var t = 0.0
        while !s.isComplete, t < 6 { s.step(dt: 0.05); t += 0.05 }
        #expect(t >= BossDirector.defeatSec - 0.1, "the sparkle burst plays first (\(t) s)")
        s.step(dt: 0.05)                                       // the card is handed over next step
        if case .seasonComplete(let r) = model.screen { #expect(r.isLast && r.levelId == "l5") } else { Issue.record("no Season complete card") }
        #expect(model.progress.arena == nil, "the arena flag clears with the level")
    }

    @Test func continueResumesAtTheArenaAfterARelaunch() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("M4Arena-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = SaveStore(directory: dir)
        let m1 = GameModel(data: Self.data, saveStore: store)
        m1.startLevel(id: "l5", seed: 5)
        m1.enterBossArena(levelId: "l5", carry: ArenaProgress(levelId: "l5", elapsed: 412, score: 900),
                          loadout: m1.progress.loadout, inventory: m1.progress.inventory)
        #expect(m1.run?.stage == .bossArena)
        let m2 = GameModel(data: Self.data, saveStore: store)
        #expect(m2.hasSave && m2.progress.l5ArenaReached && m2.progress.arena?.elapsed == 412)
        m2.continueGame()
        #expect(m2.run?.stage == .bossArena && m2.run?.levelId == "l5")
        let s = GameScene(data: Self.data, levelId: "l5", seed: m2.run!.seed, run: m2.progress, stage: .bossArena)
        #expect(s.isArena && s.session.elapsed == 412 && s.session.score == 900)
    }

    @Test func l5ExitPadLeadsIntoTheArena() throws {
        let s = Self.scene("l5", seed: 11)
        let model = GameModel(data: Self.data)
        model.startLevel(id: "l5", seed: 11)
        s.model = model
        s.hero.health.reset(invulnerableFor: 1_000_000)
        s.handle(.debugSolveAll)
        s.hero.position = s.built.exitPad.position
        for _ in 0..<40 { s.step(dt: 0.05) }
        #expect(model.run?.stage == .bossArena && model.progress.arena != nil)
        #expect(model.screen == .game)
    }

    static func said(_ s: GameScene) -> [String] {
        [s.pixelBrain.speech.current?.key].compactMap { $0 } + s.pixelBrain.speech.pending.map(\.key)
    }

    /// The 3 designer lines (GDD §16.7): bubble shield (story, once), core needed (hint), slow (once).
    @Test func bossShieldCoreNeededAndSlowLines() throws {
        for key in [StoryDirector.Key.bossShield, StoryDirector.Key.coreNeeded, StoryDirector.Key.slow] {
            #expect(String(localized: String.LocalizationValue(key)) != key, "\(key) has a string")
        }
        var run = RunState.newGame(data: Self.data)
        run.arena = ArenaProgress(levelId: "l5")
        let s = Self.scene("l5", run: run, stage: .bossArena, clearEnemies: false)
        let boss = try #require(s.boss)
        boss.debugNextPhase()
        for _ in 0..<30 { s.step(dt: 1.0 / 30) }
        s.pixelBrain.dismiss(); s.pixelBrain.dismiss(); s.pixelBrain.dismiss()
        ScenePlaythroughTests.shoot(s, at: boss.node)
        #expect(Self.said(s).contains(StoryDirector.Key.bossShield))
        // A core machine without a core.
        let m = try #require(s.level.elements.first { $0.type == .machine })
        s.hero.position = s.level.grid.world(GridPoint(m.cell.x + 2, m.cell.y))
        s.step(dt: 1.0 / 30)
        #expect(s.focusedId == m.id)
        s.handle(.interact)
        #expect(Self.said(s).contains(StoryDirector.Key.coreNeeded))
        // Spore slow line, once per level.
        let l1 = Self.scene()
        l1.hero.health.reset(invulnerableFor: 0)
        l1.combat.spawnEnemyShot(kind: .spore, at: l1.hero.position, angle: 0, speed: 10, radius: 12, damage: 1, range: 100,
                                 slowMultiplier: 0.7, slowSec: 2)
        l1.step(dt: 1.0 / 30)
        #expect(l1.hero.status.isSlowed && Self.said(l1).contains(StoryDirector.Key.slow))
    }

    /// QA-020: the boss never stands on the hero, and an item under the boss slides out so it stays
    /// collectable (found by QA's spread-blaster fight: a pillar pickup under the parked boss).
    @Test func bossKeepsTheHeroAndItemsClearOfItsBody() throws {
        var run = RunState.newGame(data: Self.data)
        run.arena = ArenaProgress(levelId: "l5")
        let s = Self.scene("l5", run: run, stage: .bossArena, clearEnemies: false)
        let boss = try #require(s.boss)
        let item = try #require(Self.data.items["ammo_starter"])
        s.interaction.addPlacedPickup(item, at: boss.node.position, placementId: "test_under_boss")
        for _ in 0..<10 { s.step(dt: 1.0 / 30) }           // hero far away at the entrance
        let p = try #require(s.pickups.first { $0.placementId == "test_under_boss" })
        let pg = hypot(p.groundPosition.x - boss.node.position.x, p.groundPosition.y - boss.node.position.y)
        #expect(pg >= boss.node.radius + s.hero.radius, "item slid out (\(pg) pt)")
        s.hero.position = p.groundPosition
        for _ in 0..<6 { s.step(dt: 1.0 / 30) }
        #expect(!s.pickups.contains { $0 === p }, "collectable after the slide")
        s.hero.position = boss.node.position
        s.step(dt: 1.0 / 30)
        let gap = hypot(s.hero.position.x - boss.node.position.x, s.hero.position.y - boss.node.position.y)
        #expect(gap >= boss.node.radius + s.hero.radius, "hero pushed clear (\(gap) pt)")
    }

    // MARK: Leftovers

    @Test func hudAvoidanceNudgesAnObjectOutOfTheRightColumn() {
        let vis = GameScene.logicalSize
        let column = HUDAvoidance.rightColumn(visibleSize: vis)
        // A machine just under the RELOAD button.
        let r = column[1]
        let object = CGRect(x: r.midX - 40, y: r.midY - 40, width: 80, height: 80)
        let n = HUDAvoidance.nudge(object: object, buttons: column, maxShift: HUDAvoidance.maxShift)
        #expect(n.dx > 0 && n.dx <= HUDAvoidance.maxShift)
        let moved = object.offsetBy(dx: -n.dx, dy: n.dy)
        #expect(!column.contains { $0.intersects(moved) }, "clear of every button after the nudge")
        #expect(HUDAvoidance.nudge(object: CGRect(x: -40, y: -40, width: 80, height: 80), buttons: column, maxShift: 120) == .zero)
    }

    @Test func cameraNudgeIsAppliedEvenAtTheMapEdge() {
        let cam = SKCameraNode()
        let c = CameraController(camera: cam, def: Self.data.camera, bounds: CGRect(x: 0, y: 0, width: 2000, height: 1200))
        let vis = GameScene.logicalSize
        c.snap(to: CGPoint(x: 1990, y: 600), visibleSize: vis)        // clamped at the right edge
        let edge = cam.position
        c.nudge = CGVector(dx: 90, dy: 0)
        for _ in 0..<120 { c.update(dt: 1.0 / 60, target: CGPoint(x: 1990, y: 600), aim: nil, visibleSize: vis) }
        #expect(abs(cam.position.x - (edge.x + 90)) < 1, "nudge on top of the clamp")
        #expect(abs(c.basePosition.x - edge.x) < 1)
        c.nudge = .zero
        for _ in 0..<120 { c.update(dt: 1.0 / 60, target: CGPoint(x: 1990, y: 600), aim: nil, visibleSize: vis) }
        #expect(abs(cam.position.x - edge.x) < 1, "eases back")
    }

    @Test func hintChevronShowsForAnOffScreenTarget() {
        let s = Self.scene("l3", seed: 11)
        s.runHint(.tap)
        guard s.pixelDirector.hintTarget != nil else { return }      // a line-only hint has no target
        s.step(dt: 1.0 / 60)
        let target = s.pixelDirector.hintTarget!
        let vis = s.visibleSize
        let off = abs(target.x - s.cameraNode.position.x) > vis.width / 2 - 24 || abs(target.y - s.cameraNode.position.y) > vis.height / 2 - 24
        #expect((s.pixelDirector.chevron != nil) == off, "chevron only when the target is off screen")
        #expect(s.pixelDirector.targetRing != nil, "target ring")
        if let c = s.pixelDirector.chevron { #expect(c.position.y >= -vis.height / 2 + 160, "never in the joystick corners") }
    }

    @Test func settingsChangeAimAssistAndPixelTalkLive() {
        let s = Self.scene()
        let model = GameModel(data: Self.data)
        s.model = model
        model.setAimAssist(false)
        #expect(!s.aimAssistEnabled && !model.progress.settings.aimAssist)
        model.setPixelTalk(.quiet)
        #expect(s.pixelBrain.speech.talk == .quiet)
        model.setAimAssist(true)
        #expect(s.aimAssistEnabled)
    }

    /// QA-011: a tip key without a string is skipped, never shown raw.
    @Test func missingTipKeysAreSkipped() {
        let p = PixelController(level: Self.data.levels["l1"]!, rules: Self.data.rules, talk: .lots)
        p.localize = { $0 == "pixel.tip.unknownbot" ? $0 : "text" }
        p.handle(.enemySeen("unknownbot"))
        let said = [p.speech.current?.key].compactMap { $0 } + p.speech.pending.map(\.key)
        #expect(!said.contains("pixel.tip.unknownbot"))
        #expect(Self.data.levels["l5"] != nil && String(localized: "pixel.tip.megamech") != "pixel.tip.megamech")
    }

    @Test func l5RoomWithAllFiveTypesAndACrowdStaysUnderTheNodeBudget() throws {
        let s = Self.scene("l5", seed: 7, clearEnemies: false)
        for id in ["boltbot", "laserdrone", "slimemutant", "shieldandroid", "sporeplant"] { s.handle(.debugSpawn(id)) }
        s.handle(.debugSpawnCrowd)
        s.hero.health.reset(invulnerableFor: 1_000_000)
        for _ in 0..<120 { Self.frame(s) }
        func count(_ n: SKNode) -> Int { 1 + n.children.reduce(0) { $0 + count($1) } }
        let n = count(s)
        print("[nodes] l5 + 5 types + crowd: \(n), enemy shots \(s.enemyShots.activeCount)")
        #expect(n < 1500)
    }
}
