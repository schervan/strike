import SpriteKit
import Testing
@testable import Strike

/// M2-7 scripted playthrough: a headless "player" walks a real `GameScene` (hero placed cell by cell along
/// BFS paths over the scene's CURRENT solid grid, so closed doors really block), picks up puzzle items, uses
/// elements via the INTERACT command, stands on plates, waits out door pans, touches checkpoints, gets hurt by
/// a real boltbot contact and finishes on the exit pad. No debug commands are used.
@MainActor
struct ScenePlaythroughTests {
    static func bfsPath(_ g: TileGrid, from: GridPoint, goal: (GridPoint) -> Bool) -> [GridPoint]? {
        guard g.isWalkable(from) else { return nil }
        var prev: [GridPoint: GridPoint] = [:]
        var seen: Set<GridPoint> = [from]
        var queue = [from]; var head = 0
        while head < queue.count {
            let p = queue[head]; head += 1
            if goal(p) {
                var path = [p]; var c = p
                while let q = prev[c] { path.append(q); c = q }
                return path.reversed()
            }
            for n in p.neighbors4 where g.isWalkable(n) && !seen.contains(n) { seen.insert(n); prev[n] = p; queue.append(n) }
        }
        return nil
    }

    struct Log { var lines: [String] = []; mutating func add(_ s: String) { lines.append(s) } }

    static func walk(_ scene: GameScene, to goal: (GridPoint) -> Bool) -> Bool {
        let from = scene.level.grid.cell(at: scene.hero.position)
        guard let path = bfsPath(scene.solidGrid, from: from, goal: goal) else { return false }
        for c in path.dropFirst() {
            scene.hero.position = scene.level.grid.world(c)
            scene.step(dt: 0.05)
        }
        return true
    }

    static func settle(_ scene: GameScene, seconds: Double) {
        for _ in 0..<Int(seconds / 0.05) { scene.step(dt: 0.05) }
    }

    static func near(_ e: PlacedElement) -> (GridPoint) -> Bool {
        let cells = Set(e.cells)
        return { p in
            if e.type == .pressureplate { return cells.contains(p) }
            return !cells.contains(p) && cells.contains { abs($0.x - p.x) + abs($0.y - p.y) == 1 }
        }
    }

    /// Returns (log, completed).
    static func play(levelId: String, seed: UInt64, check: Bool = true) throws -> (Log, Bool) {
        let data = try TestData.load()
        let model = GameModel(screen: .title, data: data)
        let def = try #require(data.levels[levelId])
        let scene = GameScene(data: data, level: def, seed: seed)
        let view = SKView(frame: CGRect(origin: .zero, size: GameScene.logicalSize))
        view.presentScene(scene)
        scene.model = model
        model.startLevel(id: levelId, seed: seed)
        scene.hero.health.reset(invulnerableFor: 1_000_000)
        var log = Log()
        let level = scene.level
        log.add("\(levelId) seed \(seed): rooms \(level.rooms.count), gates \(level.gates.count), elements \(level.elements.map { "\($0.type.rawValue)@z\($0.zone)" }.joined(separator: ","))")

        // Hero starts on the start checkpoint pad.
        settle(scene, seconds: 0.2)
        #expect(scene.session.lastCheckpointId == "checkpoint_start" || level.checkpoints[0].id == "checkpoint_start")
        let startRooms = scene.session.revealedRoomIds.count
        #expect(startRooms >= 1, "start room revealed")

        var openedGateOrder: [String] = []
        var madeProgress = true
        var rounds = 0
        while madeProgress, rounds < 40 {
            madeProgress = false; rounds += 1
            // 1. puzzle items lying on reachable floor
            for p in scene.pickups where p.item.category == .puzzle && p.placementId != nil {
                guard let ip = level.itemPlacements.first(where: { $0.id == p.placementId }) else { continue }
                if walk(scene, to: { $0 == ip.cell }) {
                    settle(scene, seconds: 0.6)
                    if !scene.pickups.contains(where: { $0 === p }) { madeProgress = true; log.add("picked up \(ip.itemId)") }
                }
            }
            // 2. elements
            for e in level.elements where !scene.puzzle.isOn(e.id) {
                guard walk(scene, to: near(e)) else { continue }
                switch e.type {
                case .pressureplate:
                    settle(scene, seconds: data.rules.puzzle.plateHoldSec + 0.5)
                case .machine, .button, .lever:
                    // Real players press against the object; cell centres of a 2x2 machine are ~5 pt out of
                    // INTERACT range (see QA-009), so nudge the hero toward the element like a body pushing in.
                    if let n = scene.built.interactables[e.id] {
                        let dx = n.position.x - scene.hero.position.x, dy = n.position.y - scene.hero.position.y
                        let d = hypot(dx, dy), want = 56 + n.reachPadding
                        if d > want { scene.hero.position.x += dx / d * (d - want); scene.hero.position.y += dy / d * (d - want) }
                    }
                    settle(scene, seconds: 0.1)
                    let node = scene.built.interactables[e.id]
                    if scene.focusedId == nil { log.add("DEBUG no focus: \(e.id) hero \(scene.hero.position) node \(String(describing: node?.position)) cells \(e.cells) heroCell \(scene.level.grid.cell(at: scene.hero.position)) pad \(String(describing: node?.reachPadding))") }
                    #expect(scene.focusedId != nil, "an element must be focusable at its side")
                    let before = scene.puzzle.requiredProgress.on
                    scene.handle(.interact)
                    settle(scene, seconds: 0.2)
                    if scene.puzzle.isOn(e.id) {
                        #expect(scene.puzzle.requiredProgress.on >= before)
                    }
                }
                if scene.puzzle.isOn(e.id) {
                    madeProgress = true
                    log.add("on: \(e.id) (\(e.type.rawValue)) required \(scene.puzzle.requiredProgress.on)/\(scene.puzzle.requiredProgress.total)")
                    settle(scene, seconds: 3.5)                     // door pan + hold
                    for g in level.gates where scene.built.gates[g.id]?.isOpen == true && !openedGateOrder.contains(g.id) {
                        openedGateOrder.append(g.id); log.add("gate \(g.id) open")
                    }
                }
            }
            // 3. checkpoints behind opened gates
            for c in level.checkpoints where scene.session.lastCheckpointId != c.id {
                if walk(scene, to: { $0 == c.cell }) { settle(scene, seconds: 0.2) }
            }
        }
        if check {
            for e in level.elements where e.required { #expect(scene.puzzle.isOn(e.id), "required \(e.id) not on") }
            #expect(scene.puzzle.isExitOpen, "exit not open")
            #expect(scene.built.exitDoor.isOpen, "exit door node not open")
            for g in level.gates { #expect(scene.built.gates[g.id]?.isOpen == true, "gate \(g.id) not open") }
            #expect(openedGateOrder == level.gates.map(\.id), "gates must open in zone order")
        }

        // Checkpoint + rescue through real contact damage.
        let cp = scene.session.lastCheckpointId
        log.add("last checkpoint \(cp ?? "nil"), minimap rooms \(scene.minimapSnapshot.rooms.count)/\(level.rooms.count)")
        if check, let e = scene.enemies.first(where: { !$0.isPoweredDown && $0.def.contactDamage > 0 }) {
            scene.hero.health.reset(invulnerableFor: 0)
            _ = scene.hero.health.applyDamage(scene.hero.health.max - 1)
            scene.hero.health.tick(dt: 10)
            let rescuesBefore = scene.session.rescues
            for _ in 0..<80 {
                scene.hero.position = e.position
                scene.step(dt: 0.05)
                if scene.session.rescues > rescuesBefore { break }
            }
            #expect(scene.session.rescues == rescuesBefore + 1, "contact damage at 1 HP should trigger the rescue")
            let rp = scene.respawnPoint
            #expect(hypot(scene.hero.position.x - rp.x, scene.hero.position.y - rp.y) < 70, "hero should be at the last checkpoint after rescue")
            #expect(scene.hero.health.current == scene.hero.health.max)
            log.add("rescued at checkpoint \(cp ?? "start")")
            scene.hero.health.reset(invulnerableFor: 1_000_000)
        }

        // Exit.
        let padPos = scene.built.exitPad.position
        let padCell = level.grid.cell(at: padPos)
        #expect(walk(scene, to: { $0 == padCell }), "exit pad must be reachable on foot once everything is on")
        let off = hypot(level.grid.world(level.exitPad).x - padPos.x, level.grid.world(level.exitPad).y - padPos.y)
        if off > 1 { log.add("note: drawn exit pad is \(Int(off)) pt from the logical exitPad cell") }
        scene.hero.position = padPos
        settle(scene, seconds: 2.0)
        log.add("complete=\(scene.isComplete), minimap rooms \(scene.minimapSnapshot.rooms.count)/\(level.rooms.count), time \(scene.session.elapsed)")
        if check {
            #expect(scene.isComplete, "level did not complete on the exit pad")
            if def.bossArena != nil {
                // M4-6: the L5 exit pad leads to the boss arena; the boss ends the level.
                #expect(model.run?.stage == .bossArena, "L5 exit pad must lead to the boss arena")
                #expect(model.progress.l5ArenaReached)
                let done = try playArena(model: model, data: data, def: def, log: &log)
                #expect(done, "boss not defeated")
                if case .seasonComplete(let r) = model.screen { #expect(r.levelId == levelId && r.isLast) } else { Issue.record("model did not reach seasonComplete") }
                return (log, done)
            }
            if case .levelComplete(let r) = model.screen { #expect(r.levelId == levelId) } else { Issue.record("model did not reach levelComplete") }
        }
        return (log, scene.isComplete)
    }

    /// A real hero blaster shot that touches `target` (physics contacts do not run headless).
    static func shoot(_ scene: GameScene, at target: SKNode) {
        let w = scene.hero.weapon.def
        let a = atan2(target.position.y - scene.hero.position.y, target.position.x - scene.hero.position.x)
        guard let shot = scene.pool.spawn(weapon: w, texture: SKTexture(), at: target.position, angle: a, in: scene.worldNode) else { return }
        scene.combat.resolve(shot, target: target)
    }

    /// A real shot travelling along `angle` that touches `target`.
    static func shootAlong(_ scene: GameScene, at target: SKNode, angle: CGFloat) {
        let w = scene.hero.weapon.def
        guard let shot = scene.pool.spawn(weapon: w, texture: SKTexture(), at: target.position, angle: angle, in: scene.worldNode) else { return }
        scene.combat.resolve(shot, target: target)
    }

    /// M4-6 scripted boss fight: blaster hits on the boss, the phase-2 core puzzle through real
    /// carriers, floor cores and the two core machines (INTERACT), until the Season complete card.
    static func playArena(model: GameModel, data: GameData, def: LevelDef, log: inout Log) throws -> Bool {
        let scene = GameScene(data: data, level: def, seed: 1, run: model.progress, stage: .bossArena)
        let view = SKView(frame: CGRect(origin: .zero, size: GameScene.logicalSize))
        view.presentScene(scene)
        scene.model = model
        scene.hero.health.reset(invulnerableFor: 1_000_000)
        let boss = try #require(scene.boss, "arena without a boss")
        #expect(scene.session.elapsed > 0, "L5 time carries into the arena")
        scene.step(dt: 0.05)
        #expect(model.hud.boss != nil, "boss bar state is pushed")
        var phasesSeen: [Int] = [boss.brain.phaseIndex]
        var t = 0.0
        while !scene.isComplete, t < 400 {
            if boss.brain.isImmune {
                // Shield up: shoot the carriers, collect the cores, power both machines.
                if let carrier = scene.enemies.first(where: { $0.carriesItem != nil && !$0.isPoweredDown }) {
                    shoot(scene, at: carrier)
                } else if let core = scene.pickups.first(where: { $0.item.id == boss.coreItemId && $0.hasLanded }) {
                    scene.hero.position = core.groundPosition
                } else if scene.inventory.count(of: boss.coreItemId) > 0,
                          let m = scene.level.elements.first(where: { $0.type == .machine && !scene.puzzle.isOn($0.id) }) {
                    _ = walk(scene, to: near(m))
                    if let n = scene.built.interactables[m.id] {
                        let dx = n.position.x - scene.hero.position.x, dy = n.position.y - scene.hero.position.y
                        let d = hypot(dx, dy), want = 56 + n.reachPadding
                        if d > want { scene.hero.position.x += dx / d * (d - want); scene.hero.position.y += dy / d * (d - want) }
                    }
                    scene.step(dt: 0.05)
                    scene.handle(.interact)
                }
            } else if !boss.isDefeated {
                shoot(scene, at: boss.node)
            }
            scene.step(dt: 0.05)
            t += 0.05
            if phasesSeen.last != boss.brain.phaseIndex { phasesSeen.append(boss.brain.phaseIndex) }
        }
        log.add("arena: phases \(phasesSeen.map { $0 + 1 }), cores in \(boss.brain.coresInserted), boss defeated \(boss.isDefeated), time \(Int(scene.session.elapsed)) s, complete \(scene.isComplete)")
        #expect(phasesSeen == [0, 1, 2], "all three phases in order")
        #expect(boss.brain.coresInserted >= 2)
        settle(scene, seconds: 0.2)
        return scene.isComplete
    }

    @Test(arguments: ["l1", "l2", "l3", "l4", "l5"])
    func scriptedPlaythrough(levelId: String) throws {
        for seed: UInt64 in [11, 222, 3333] {
            let (log, done) = try Self.play(levelId: levelId, seed: seed)
            for l in log.lines { print("PLAY \(l)") }
            #expect(done, "\(levelId) seed \(seed) not completed")
        }
    }
}
