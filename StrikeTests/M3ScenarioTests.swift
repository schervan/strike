import SpriteKit
import Testing
@testable import Strike

/// M3-7 scripted scenarios on a real `GameScene`: leash (enemy goes home) and rescue (beam, checkpoint,
/// enemies reset, bag kept). The test steps the scene itself and integrates enemy velocities by hand because
/// SpriteKit's physics only runs inside a live render loop.
@MainActor
struct M3ScenarioTests {
    static func makeScene(_ id: String, _ seed: UInt64) throws -> GameScene {
        let data = try TestData.load()
        let s = GameScene(data: data, level: try #require(data.levels[id]), seed: seed)
        let v = SKView(frame: CGRect(origin: .zero, size: GameScene.logicalSize))
        v.presentScene(s)
        return s
    }

    /// One 50 ms frame: scene step, then move enemies by their desired velocity (no wall physics needed:
    /// the AI paths around walls itself).
    static func frame(_ s: GameScene, dt: Double = 0.05) {
        s.step(dt: dt)
        for e in s.enemies where !e.isPoweredDown {
            e.position.x += e.desiredVelocity.dx * CGFloat(dt)
            e.position.y += e.desiredVelocity.dy * CGFloat(dt)
        }
    }

    static func stateName(_ e: EnemyNode) -> String { String(describing: type(of: e.brain.currentState as Any)).replacingOccurrences(of: "Optional<", with: "") }

    /// A walkable cell at path distance >= `minSteps` from `from`.
    static func farCell(_ g: TileGrid, from: GridPoint, minSteps: Int) -> GridPoint? {
        var dist: [GridPoint: Int] = [from: 0]
        var q = [from]; var h = 0
        var best: GridPoint?
        while h < q.count {
            let p = q[h]; h += 1
            if dist[p]! >= minSteps { best = p; break }
            for n in p.neighbors4 where g.isWalkable(n) && dist[n] == nil { dist[n] = dist[p]! + 1; q.append(n) }
        }
        return best
    }

    @Test(arguments: [("l1", UInt64(11)), ("l3", UInt64(222))])
    func leashSendsALuredEnemyHomeAtFullHP(levelId: String, seed: UInt64) throws {
        let s = try Self.makeScene(levelId, seed)
        s.hero.health.reset(invulnerableFor: 1_000_000)
        let e = try #require(s.enemies.first { $0.def.id == "boltbot" })
        let home = e.spawnPoint
        let rules = s.data.rules.leash
        // 1. Lure: hero 200 pt away with line of sight until the boltbot chases.
        let offs: [CGPoint] = [CGPoint(x: 200, y: 0), CGPoint(x: -200, y: 0), CGPoint(x: 0, y: 200), CGPoint(x: 0, y: -200)]
        var placed = false
        for o in offs {
            let p = CGPoint(x: home.x + o.x, y: home.y + o.y)
            if s.solidGrid.isWalkable(s.level.grid.cell(at: p)), s.solidGrid.hasLineOfSight(from: home, to: p) { s.hero.position = p; placed = true; break }
        }
        #expect(placed)
        for _ in 0..<40 { Self.frame(s) }
        #expect(e.isAware, "boltbot should have noticed the hero (state \(Self.stateName(e)))")
        // 2. Hurt it, then the hero runs two rooms away (walk the path in 1-cell steps, enemy keeps chasing).
        _ = e.health.applyDamage(e.health.max / 2)
        let hurt = e.health.current
        #expect(hurt < e.health.max)
        let target = try #require(Self.farCell(s.solidGrid, from: s.level.grid.cell(at: s.hero.position), minSteps: 45))
        let farDist = hypot(s.level.grid.world(target).x - home.x, s.level.grid.world(target).y - home.y)
        #expect(farDist > rules.rangeFactor * e.def.detectRange, "hero must end outside the leash range (\(Int(farDist)) pt)")
        s.hero.position = s.level.grid.world(target)
        // 3. Leash: after returnAfterSec out of range the enemy walks home and heals.
        var sawReturn = false, t = 0.0, returnedAt: Double?
        while t < 40 {
            Self.frame(s); t += 0.05
            if e.isReturningHome { sawReturn = true }
            if sawReturn, !e.isReturningHome, returnedAt == nil { returnedAt = t }
            if returnedAt != nil { break }
        }
        let dHome = hypot(e.position.x - home.x, e.position.y - home.y)
        print("LEASH \(levelId): returned home after \(String(format: "%.1f", returnedAt ?? -1)) s, HP \(e.health.current)/\(e.health.max) (was \(hurt)), distance to spawn \(Int(dHome)) pt, state \(Self.stateName(e))")
        #expect(sawReturn, "enemy never started returning (state \(Self.stateName(e)))")
        #expect(returnedAt != nil && returnedAt! >= rules.returnAfterSec, "returned too early")
        #expect(dHome <= Leash.arriveDistance + 2, "enemy not at its spawn (\(dHome) pt)")
        #expect(e.health.current == e.health.max, "enemy must be at full HP at home")
        #expect(e.brain.currentState is IdleState, "enemy should idle at home")
    }

    @Test(arguments: [("l1", UInt64(11)), ("l2", UInt64(11)), ("l4", UInt64(7))])
    func rescueBeamsToCheckpointKeepsBagAndResetsEnemies(levelId: String, seed: UInt64) throws {
        let s = try Self.makeScene(levelId, seed)
        let start = s.level.heroStart
        s.hero.position = s.level.grid.world(start)
        for _ in 0..<5 { Self.frame(s) }
        // Fill the bag from the floor (only L1 has a start gift), then touch the last gate checkpoint.
        for p in s.pickups.map({ ($0.position, $0) }).prefix(40) {
            s.hero.position = p.0
            for _ in 0..<12 { Self.frame(s) }
        }
        s.handle(.debugSolveAll)
        if let gate = s.level.checkpoints.last, gate.gateId != nil, let node = s.built.checkpoints[gate.id] {
            s.hero.position = node.position
            for _ in 0..<6 { Self.frame(s) }
        }
        s.hero.health.reset(invulnerableFor: 0)
        let bagBefore = s.inventory
        let ammoBefore = s.hero.loadout.ammo
        let ownedBefore = s.hero.loadout.owned
        let cp = s.session.lastCheckpointId
        let rescuesBefore = s.session.rescues
        #expect(!bagBefore.isEmpty, "start gift should be in the bag")
        // Make trouble: wake every enemy and hurt it.
        let foe = try #require(s.enemies.first { $0.def.contactDamage > 0 })
        s.hero.position = CGPoint(x: foe.position.x + 150, y: foe.position.y)
        for _ in 0..<20 { Self.frame(s) }
        for e in s.enemies where !e.isPoweredDown { _ = e.health.applyDamage(e.health.max / 2) }
        // Walk the hero away from the checkpoint so the teleport is visible.
        let away = try #require(Self.farCell(s.solidGrid, from: s.level.grid.cell(at: s.hero.position), minSteps: 20))
        s.hero.position = s.level.grid.world(away)
        let atDeath = s.hero.position
        // DMG to 0 HP -> beam.
        s.damageHero(1000)
        #expect(s.rescue != nil, "rescue sequence should start at 0 HP")
        var t = 0.0, sawBeam = false
        while s.rescue != nil, t < 8 {
            Self.frame(s); t += 0.05
            if s.worldNode.childNode(withName: "rescue_beam") != nil { sawBeam = true }
        }
        #expect(sawBeam, "beam node should appear during the rescue")
        #expect(s.rescue == nil, "rescue should end")
        let rp = s.respawnPoint
        let moved = hypot(s.hero.position.x - atDeath.x, s.hero.position.y - atDeath.y)
        print("RESCUE \(levelId): took \(String(format: "%.2f", t)) s, hero moved \(Int(moved)) pt to checkpoint \(cp ?? "start"), rescues \(s.session.rescues), HP \(s.hero.health.current)/\(s.hero.health.max)")
        #expect(hypot(s.hero.position.x - rp.x, s.hero.position.y - rp.y) < 40, "hero should stand on the last checkpoint")
        #expect(s.hero.health.current == s.hero.health.max)
        #expect(s.session.rescues == rescuesBefore + 1)
        #expect(s.session.lastCheckpointId == cp)
        #expect(s.inventory == bagBefore, "bag must be unchanged by a rescue")
        #expect(s.hero.loadout.ammo == ammoBefore || s.hero.loadout.ammo.reserve("ammo_starter") >= ammoBefore.reserve("ammo_starter"), "other ammo must stay")
        #expect(s.hero.loadout.owned == ownedBefore)
        #expect(s.hero.alpha == 1 && s.hero.xScale == 1, "hero must be fully visible again")
        for e in s.enemies where !e.isPoweredDown {
            #expect(e.health.current == e.health.max || e.isReturningHome, "enemy not reset (HP \(e.health.current))")
            #expect(e.isReturningHome || e.brain.currentState is IdleState, "enemy should be going home, state \(Self.stateName(e))")
        }
    }
}
