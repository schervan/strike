import Foundation
import SpriteKit
import Testing
import UIKit
@testable import Strike

/// M3-5 / M3-6 scene and model checks: pickups through `PickupResolver`, drops, quick slots,
/// Pixel (follow, tap hint, idle hint, scan, story), the rescue sequence, QA-008, poof v2, the
/// crowd debug spawn and the save flow.
@MainActor
struct M3SceneTests {
    static var data: GameData { GeneratedCorpus.data }

    static func run(with items: [(String, Int)] = []) -> RunState {
        var r = RunState.newGame(data: data)
        for (id, n) in items { _ = r.inventory.add(id, count: n) }
        return r
    }

    static func scene(_ id: String = "l1", seed: UInt64 = 42, run: RunState? = nil) -> GameScene {
        let s = GameScene(data: data, levelId: id, seed: seed, run: run)
        s.hero.health.reset(invulnerableFor: 1_000_000)
        return s
    }

    /// A walkable spot `d` pt from the hero (no wall in between).
    static func spot(near s: GameScene, distance d: CGFloat) -> CGPoint? {
        for a in stride(from: 0.0, to: 2 * Double.pi, by: Double.pi / 8) {
            let p = CGPoint(x: s.hero.position.x + d * CGFloat(cos(a)), y: s.hero.position.y + d * CGFloat(sin(a)))
            if s.solidGrid.isWalkable(s.level.grid.cell(at: p)), s.solidGrid.hasLineOfSight(from: s.hero.position, to: p) { return p }
        }
        return nil
    }

    // MARK: Pickups and the bag

    @Test func healAndFoodPickupsGoIntoTheBagAndDropsCanBePickedUpAgain() throws {
        let s = Self.scene(run: Self.run(with: [("food_apple", 3)]))
        let model = GameModel(data: Self.data)
        s.model = model
        s.step(dt: 1.0 / 60)
        let slot = try #require(s.inventory.slots.firstIndex { $0?.itemId == "food_apple" })
        s.handle(.dropItem(slot: slot, count: 2))
        #expect(s.inventory.count(of: "food_apple") == 1)
        let dropped = try #require(s.pickups.first { $0.item.id == "food_apple" && $0.count == 2 })
        #expect(hypot(dropped.groundPosition.x - s.hero.position.x, dropped.groundPosition.y - s.hero.position.y)
                <= CGFloat(Self.data.rules.inventory.dropScatter) + 1)
        for _ in 0..<30 { s.step(dt: 1.0 / 30) }
        #expect(s.inventory.count(of: "food_apple") == 1, "not re-picked while the hero still stands on it")
        // Step away and come back.
        let away = try #require(Self.spot(near: s, distance: 120))
        let back = s.hero.position
        s.hero.position = away
        s.step(dt: 1.0 / 60)
        s.hero.position = back
        for _ in 0..<20 { s.step(dt: 1.0 / 30) }
        #expect(s.inventory.count(of: "food_apple") == 3)
        #expect(model.bag.count(of: "food_apple") == 3)
    }

    @Test func pickupsRouteThroughPickupResolverAndBagFullStaysWithMarker() throws {
        var run = Self.run()
        _ = run.inventory.add("food_cookie", count: 25 * 10)
        let s = Self.scene(run: run)
        s.step(dt: 1.0 / 60)
        let before = s.pickups.count
        s.spawnLoot([LootDrop(itemId: "healpack", count: 1), LootDrop(itemId: "bolt", count: 1)], at: s.hero.position)
        #expect(s.pickups.count == before + 2)
        let heal = try #require(s.pickups.last { $0.item.id == "healpack" })
        for _ in 0..<40 { s.step(dt: 1.0 / 30) }
        #expect(s.session.bolts == 1, "bolt → score")
        // The heal pack popped within 48 pt; put the hero on it.
        s.hero.position = heal.groundPosition
        for _ in 0..<10 { s.step(dt: 1.0 / 30) }
        #expect(s.pickups.contains { $0 === heal }, "bag full: the pickup stays on the floor")
        #expect(heal.isBlocked && heal.hasMarker)
        #expect(s.inventory.count(of: "healpack") == 0)
        // Make room: it goes in.
        let slot = try #require(s.inventory.slots.firstIndex { $0 != nil })
        s.handle(.dropItem(slot: slot, count: 10))
        let away = try #require(Self.spot(near: s, distance: 150))
        let here = s.hero.position
        s.hero.position = away
        s.step(dt: 1.0 / 60)
        s.hero.position = here
        for _ in 0..<10 { s.step(dt: 1.0 / 30) }
        #expect(s.inventory.count(of: "healpack") == 1)
    }

    @Test func quickSlotUseHealsAndRefusesAtFullHp() throws {
        let model = GameModel(data: Self.data)
        model.startGame()                                  // L1 start gift: 1 healpack (Q1), 2 apples (Q2)
        model.dismissIntro()
        let s = Self.scene(run: model.progress)
        s.model = model
        s.step(dt: 1.0 / 60)
        #expect(model.hud.quickSlots.first?.itemId == "healpack" && model.hud.quickSlots.first?.count == 1)
        #expect(model.hud.quickSlots.first?.usable == false, "full HP: dimmed")
        s.handle(.useQuick(0))
        #expect(model.useFeedback?.kind == .refused)
        #expect(model.toast != nil)
        #expect(s.inventory.count(of: "healpack") == 1)
        s.handle(.debugDamageHero)
        let hp = s.hero.health.current
        #expect(hp < s.hero.health.max)
        s.handle(.useQuick(0))
        #expect(s.hero.health.current > hp)
        #expect(model.hud.quickSlots.first?.count == 0 && model.hud.quickSlots.first?.itemId == "healpack")
        #expect(model.useFeedback?.kind == .used)
        // Empty quick slot opens the bag.
        s.handle(.useQuick(3))
        #expect(model.isInventoryOpen)
    }

    // MARK: Pixel

    @Test func pixelFollowsBobsAndIgnoresWalls() {
        let s = Self.scene()
        #expect(s.pixel.physicsBody == nil)
        for _ in 0..<60 { s.step(dt: 1.0 / 60) }
        let t = s.pixel.followTarget(for: s.hero.position)
        #expect(hypot(s.pixel.position.x - t.x, s.pixel.position.y - t.y) < 4)
        // Hero jumps away: Pixel catches up (never further than the leash).
        s.hero.position.x += 200
        s.step(dt: 1.0 / 60)
        #expect(hypot(s.pixel.position.x - s.hero.position.x, s.pixel.position.y - s.hero.position.y) <= PixelNode.Feel.leashSnap + 1)
        for _ in 0..<60 { s.step(dt: 1.0 / 60) }
        let t2 = s.pixel.followTarget(for: s.hero.position)
        #expect(hypot(s.pixel.position.x - t2.x, s.pixel.position.y - t2.y) < 4)
    }

    @Test func tappingPixelGivesAHintWithArrowAndCooldown() throws {
        let s = Self.scene()
        s.step(dt: 1.0 / 60)
        s.pixelTapped()
        #expect(s.arrow != nil)
        #expect(s.pixel.isBusy)
        #expect(s.pixelBrain.isHintRunning)
        #expect(!s.minimapSnapshot.pings.isEmpty)
        s.pixelTapped()                                       // ignored while running
        let rules = Self.data.rules.hints
        var t = 0.0
        while t < rules.flySec + rules.arrowSec + 0.2 { s.step(dt: 0.05); t += 0.05 }
        #expect(!s.pixelBrain.isHintRunning)
        #expect(!s.pixel.isBusy)
        #expect(!s.pixelBrain.canHint, "cooldown")
        s.pixelTapped()
        let said = [s.pixelBrain.speech.current?.key].compactMap { $0 } + s.pixelBrain.speech.pending.map(\.key)
        #expect(said.contains(StoryDirector.Key.hintWait))
        t = 0
        while t < rules.cooldownSec + 0.2 { s.step(dt: 0.05); t += 0.05 }
        #expect(s.pixelBrain.canHint || s.pixelBrain.isHintRunning)
    }

    @Test func idleHintFiresAfterHintIdleSecWithoutProgress() {
        let s = Self.scene()
        for e in s.enemies { e.removeFromParent() }
        let idle = Double(s.levelDef.effectiveHintIdleSec)
        var t = 0.0
        while t < idle - 0.5 { s.step(dt: 0.05); t += 0.05 }
        #expect(s.arrow == nil)
        while t < idle + 0.5 { s.step(dt: 0.05); t += 0.05 }
        #expect(s.arrow != nil, "idle hint after \(idle) s")
    }

    @Test func storyStartBeatAndFirstBoltbotScanOnSight() throws {
        let s = Self.scene()
        s.step(dt: 1.0 / 60)
        #expect(s.pixelBrain.story.seenTriggers.contains("start"))
        #expect(s.pixelBrain.speech.current?.key == "pixel.l1.move")
        let bot = try #require(s.enemies.first { $0.def.id == "boltbot" })
        let p = try #require(Self.spot(near: s, distance: 260))
        bot.position = p
        for _ in 0..<12 { s.step(dt: 1.0 / 30) }
        #expect(s.pixelBrain.story.seenTriggers.contains("firstEnemy:boltbot"), "first sight, 260 pt away (no contact)")
        #expect(s.pixel.childNode(withName: "//pixel_scan") != nil, "scan beam")
    }

    // MARK: Rescue

    @Test func rescueSequenceSlowMoBeamCheckpointFullHpEnemiesHome() throws {
        let s = Self.scene("l2", run: Self.run(with: [("healpack", 2)]))
        let model = GameModel(data: Self.data)
        s.model = model
        let cp = try #require(s.level.checkpoints.last)
        s.hero.position = s.level.grid.world(cp.cell)
        s.step(dt: 1.0 / 60)
        #expect(s.session.lastCheckpointId == cp.id)
        s.hero.position = s.level.grid.world(s.level.heroStart)
        let living = s.enemies.filter { !$0.isPoweredDown }
        living.first?.health = Health(max: living.first!.def.hp)
        _ = living.first?.health.applyDamage(1)
        s.hero.health.reset(invulnerableFor: 0)
        s.handle(.debugDamageHero); s.handle(.debugDamageHero); s.handle(.debugDamageHero); s.handle(.debugDamageHero)
        let r = Self.data.rules.rescue
        #expect(s.rescue != nil, "0 HP starts the rescue")
        let bag = s.inventory
        s.step(dt: 0.1)
        #expect(RescueRules.timeScale(at: s.rescue!.t, rules: r) == r.slowMoScale)
        var t = 0.1
        while t < r.slowMoSec + r.beamSec / 2 + 0.05 { s.step(dt: 0.05); t += 0.05 }
        #expect(s.hero.position == s.level.grid.world(cp.cell))
        #expect(s.rescue != nil, "beam-in still running")
        while t < RescueRules.duration(r) + 0.1 { s.step(dt: 0.05); t += 0.05 }
        #expect(s.rescue == nil)
        #expect(s.hero.health.current == s.hero.health.max)
        #expect(s.hero.health.isInvulnerable)
        #expect(s.session.rescues == 1)
        #expect(s.inventory == bag)
        for e in living where !e.isPoweredDown {
            #expect(e.health.current == e.health.max)
        }
        #expect(s.pixelBrain.story.seenTriggers.isEmpty == false)
        let said = [s.pixelBrain.speech.current?.key].compactMap { $0 } + s.pixelBrain.speech.pending.map(\.key)
        #expect(said.contains(StoryDirector.Key.rescue))
    }

    // MARK: Leftovers

    /// QA-008: the drawn pad, `GeneratedLevel.exitPadPosition` and Pixel's exit hint agree.
    @Test func exitPadPositionAgreesWithTheDrawnPad() {
        for id in ["l1", "l2", "l3", "l4", "l5"] {
            for seed: UInt64 in [1, 11, 222] {
                let s = GameScene(data: Self.data, levelId: id, seed: seed)
                #expect(s.built.exitPad.position == s.level.exitPadPosition, "\(id) seed \(seed)")
                #expect(s.level.exitDoor.niche.contains(s.level.grid.cell(at: s.level.exitPadPosition))
                        || s.level.grid.cell(at: s.level.exitPadPosition) == s.level.exitPad, "\(id) seed \(seed)")
            }
        }
    }

    @Test func crowdSpawnStaysUnderTheNodeBudgetOnL4() {
        let s = Self.scene("l4", seed: 7)
        let before = s.enemies.count
        s.handle(.debugSpawnCrowd)
        #expect(s.enemies.count == before + GameScene.crowdEnemies)
        #expect(s.extraCrates.count == GameScene.crowdCrates)
        for _ in 0..<60 { s.step(dt: 1.0 / 60) }
        func count(_ n: SKNode) -> Int { 1 + n.children.reduce(0) { $0 + count($1) } }
        let n = count(s)
        print("[nodes] l4 + crowd: \(n)")
        #expect(n < 1500)
    }

    /// Poof v2 (QA-009): renders on every floor and changes clearly more pixels than v1 did.
    @Test func poofV2IsVisibleOnAllFloors() throws {
        for id in ["l1", "l2", "l3", "l4", "l5"] {
            let s = GameScene(data: Self.data, levelId: id, seed: 11)
            let view = SKView(frame: CGRect(origin: .zero, size: GameScene.logicalSize))
            view.presentScene(s)
            let o = s.hero.position
            let crop = CGRect(x: o.x - 80, y: o.y - 80, width: 160, height: 160)
            s.hero.isHidden = true
            s.pixel.isHidden = true
            VisualCheckTests.spin(0.05)
            let before = try #require(view.texture(from: s.worldNode, crop: crop)?.cgImage())
            s.worldNode.addChild(Particles.poof(at: o, darkFloor: s.darkFloor))
            // Particles are random and real-time: keep the strongest of three frames.
            var changed = 0.0
            var after = before
            for _ in 0..<3 {
                VisualCheckTests.spin(0.08)
                let frame = try #require(view.texture(from: s.worldNode, crop: crop)?.cgImage())
                let c = Self.changedFraction(before, frame)
                if c > changed { changed = c; after = frame }
            }
            if let d = UIImage(cgImage: after).pngData() {
                try? d.write(to: URL(fileURLWithPath: "\(VisualCheckTests.dir)/qa_m3_poof_\(id).png"))
            }
            print("[poof] \(id): \(Int(changed * 100)) % of pixels changed")
            #expect(changed > 0.05, "\(id): poof barely visible (\(changed))")
        }
    }

    static func changedFraction(_ a: CGImage, _ b: CGImage) -> Double {
        func rgba(_ i: CGImage) -> [UInt8] {
            let w = i.width, h = i.height
            var buf = [UInt8](repeating: 0, count: w * h * 4)
            let ctx = CGContext(data: &buf, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            ctx?.draw(i, in: CGRect(x: 0, y: 0, width: w, height: h))
            return buf
        }
        guard a.width == b.width, a.height == b.height else { return 1 }
        let x = rgba(a), y = rgba(b)
        var changed = 0
        for p in stride(from: 0, to: x.count, by: 4) {
            let d = abs(Int(x[p]) - Int(y[p])) + abs(Int(x[p + 1]) - Int(y[p + 1])) + abs(Int(x[p + 2]) - Int(y[p + 2]))
            if d > 60 { changed += 1 }
        }
        return Double(changed) / Double(x.count / 4)
    }

    // MARK: Save flow

    @Test func saveContinueRestoresLoadoutBagAndUnlockedLevel() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("M3SaveFlow-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = SaveStore(directory: dir)
        let m1 = GameModel(data: Self.data, saveStore: store)
        #expect(!m1.hasSave)
        m1.startGame()
        #expect(m1.hasSave && m1.isIntroShowing)
        let s = Self.scene(run: m1.progress)
        s.model = m1
        s.handle(.assignQuick(itemId: "food_apple", slot: 3))
        s.hero.loadout.ammo.add("ammo_spread", amount: 7)
        m1.saveNow()
        m1.completeLevel(LevelResult(levelId: "l1", nameKey: "level.l1.name", timeSec: 50, score: 99, datachips: 1,
                                     datachipsTotal: 3, isLast: false), loadout: s.hero.loadout, inventory: s.inventory)
        // "Relaunch".
        let m2 = GameModel(data: Self.data, saveStore: store)
        #expect(m2.hasSave)
        #expect(m2.progress.unlockedLevelIndex == 2 && m2.progress.currentLevelId == "l2")
        #expect(m2.progress.inventory.quickItem(3) == "food_apple")
        #expect(m2.progress.inventory.quickItem(0) == "healpack")
        #expect(m2.progress.loadout.ammo.reserve("ammo_spread") == 7)
        #expect(m2.progress.bestResults["l1"]?.bestScore == 99)
        m2.continueGame()
        #expect(m2.run?.levelId == "l2")
        // New game wipes the save but keeps the settings.
        m2.newGame()
        #expect(m2.progress.unlockedLevelIndex == 1)
        #expect(m2.run?.levelId == "l1")
    }
}
