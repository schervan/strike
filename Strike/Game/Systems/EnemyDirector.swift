import GameplayKit
import SpriteKit

/// The enemies of the running scene: spawn from the generated level, tick, power-down removal,
/// path resets when doors open, the rescue reset and the debug crowd. It is the `EnemyWorld`
/// the enemy brains ask (hero position, solid map, pathfinder). Leash rules live in `Leash`
/// inside each `EnemyNode`. Split out of `GameScene` in M4-3 with no behaviour change.
@MainActor
final class EnemyDirector: EnemyWorld {
    unowned let scene: GameScene
    private(set) var enemies: [EnemyNode] = []
    /// Crates added by `spawnCrowd` (debug).
    private(set) var extraCrates: [CrateNode] = []

    /// `debug.spawnCrowd`: 12 boltbots + 2 crates in the hero's room (M3-5 performance check).
    static let crowdEnemies = 12
    static let crowdCrates = 2

    init(scene: GameScene) {
        self.scene = scene
    }

    // MARK: EnemyWorld

    var heroPosition: CGPoint { scene.hero.position }
    var solidGrid: TileGrid { scene.solidGrid }
    var pathfinder: Pathfinder { scene.pathfinder }
    var random: GKRandom { scene.random }
    var activeEnemies: [EnemyNode] { enemies.filter { !$0.isPoweredDown } }

    func enemyDidSpotHero(_ enemy: EnemyNode) {
        scene.audio?.play(.enemyAlert)
    }

    func enemyFire(_ enemy: EnemyNode, angles: [CGFloat], attack: EnemyAttackDef) {
        scene.combat.fireEnemyShots(from: enemy, angles: angles, attack: attack)
    }

    // MARK: Life cycle

    /// Level start: one enemy per generated spawn.
    func spawnInitial() {
        let data = scene.data
        for s in scene.level.enemySpawns {
            guard let def = data.enemies[s.enemyId] else { continue }
            add(EnemyNode(def: def, at: s.position, world: self, homeRoomId: s.roomId, leash: data.rules.leash))
        }
    }

    func add(_ enemy: EnemyNode) {
        enemy.darkFloor = scene.darkFloor
        enemies.append(enemy)
        scene.worldNode.addChild(enemy)
    }

    /// One `enemyId` at `p` (boss spawns, splits, debug). `aware` skips Idle (straight to the "!").
    @discardableResult
    func spawn(_ enemyId: String, at p: CGPoint, aware: Bool = false) -> EnemyNode? {
        guard let def = scene.data.enemies[enemyId] else { return nil }
        let cell = scene.level.grid.cell(at: p)
        let e = EnemyNode(def: def, at: p, world: self, homeRoomId: scene.level.room(at: cell)?.id, leash: scene.data.rules.leash)
        add(e)
        if aware { e.brain.enter(AlertState.self) }
        return e
    }

    /// Slime split (GDD §8.1): `splitInto` children pop out of the parent's body, never in a wall.
    func split(_ parent: EnemyNode) {
        guard let s = parent.def.splitInto, let child = scene.data.enemies[s.enemyId] else { return }
        let grid = scene.solidGrid
        let kids = SplitterPolicy.spawns(for: parent.def, childRadius: CGFloat(child.radius), at: parent.position,
                                         isFree: { !grid.isBlocked($0, radius: $1) })
        for k in kids {
            guard let e = spawn(k.enemyId, at: k.position) else { continue }
            e.beginPopOut(from: parent.position, delaySec: k.delaySec)
        }
        if !kids.isEmpty {
            let ring = SKShapeNode(circleOfRadius: 20)
            ring.strokeColor = Palette.hex(0x8CF07F)
            ring.lineWidth = 2
            ring.position = parent.position
            ring.zPosition = Particles.zPosition
            ring.run(.sequence([.group([.scale(to: 3, duration: 0.25), .fadeOut(withDuration: 0.25)]), .removeFromParent()]))
            scene.worldNode.addChild(ring)
        }
    }

    /// `debug.spawn.<enemyId>`: one enemy two tiles in front of the hero (or the nearest free spot).
    func debugSpawn(_ enemyId: String) {
        let h = scene.hero.position, grid = scene.solidGrid
        for d in [192, 160, 128, 96] as [CGFloat] {
            for k in 0..<8 {
                let a = CGFloat(k) * .pi / 4
                let p = CGPoint(x: h.x + cos(a) * d, y: h.y + sin(a) * d)
                if !grid.isBlocked(p, radius: 24), grid.hasLineOfSight(from: h, to: p) { spawn(enemyId, at: p); return }
            }
        }
    }

    func remove(_ enemy: EnemyNode) {
        enemy.removeFromParent()
        enemies.removeAll { $0 === enemy }
    }

    func tick(dt: Double) {
        for e in enemies { e.tick(dt: dt) }
    }

    /// A door opened: every enemy re-plans its path.
    func clearPaths() {
        for e in enemies { e.clearPath() }
    }

    /// Rescue (GDD §12 step 6): the listed living enemies heal to full and walk home.
    func resetForRescue(_ ids: Set<String>) {
        for e in enemies where ids.contains(Self.rescueId(e)) {
            e.health = Health(max: e.def.hp)
            if !(e.brain.currentState is ReturnHomeState) { e.brain.enter(ReturnHomeState.self) }
        }
    }

    var rescueEnemies: [RescueEnemy] {
        // The boss resets through its own brain (GDD §9 phase top), not to full HP.
        // Boss-phase spawns (core carriers) keep their HP too (QA-016).
        enemies.filter { !$0.isBoss && $0.bossSpawnId == nil }.map { RescueEnemy(id: Self.rescueId($0), isPoweredDown: $0.isPoweredDown) }
    }

    private static func rescueId(_ e: EnemyNode) -> String { ObjectIdentifier(e).debugDescription }

    /// Draw order: lower on screen = in front.
    func depthSort(_ z: (CGFloat) -> CGFloat) {
        for e in enemies { e.zPosition = z(e.position.y) }
    }

    // MARK: Debug

    func spawnCrowd() {
        let level = scene.level, data = scene.data, random = scene.random
        let cell = level.grid.cell(at: scene.hero.position)
        let room = level.room(at: cell)?.rect ?? RoomRect(x: cell.x - 3, y: cell.y - 3, width: 7, height: 7)
        var free: [GridPoint] = []
        for y in room.y..<room.maxY { for x in room.x..<room.maxX {
            let c = GridPoint(x, y)
            if scene.solidGrid.isWalkable(c), c.chebyshev(cell) >= 2 { free.append(c) }
        } }
        guard !free.isEmpty, let bot = data.enemies["boltbot"] else { return }
        for i in 0..<Self.crowdEnemies {
            let c = free[random.nextInt(upperBound: free.count)]
            let e = EnemyNode(def: bot, at: level.grid.world(c), world: self, homeRoomId: level.room(at: c)?.id,
                              leash: data.rules.leash)
            e.name = "enemy_crowd_\(i)"
            add(e)
        }
        for i in 0..<Self.crowdCrates {
            let c = free[random.nextInt(upperBound: free.count)]
            let crate = CrateNode(crate: CratePlacement(id: "crowd_crate_\(i)", cell: c, roomId: level.room(at: c)?.id ?? 0,
                                                        lootTableId: scene.levelDef.pickups.crates.lootTableId),
                                  grid: level.grid, hp: data.rules.crate.hp)
            extraCrates.append(crate)
            scene.built.root.addChild(crate)
        }
    }
}
