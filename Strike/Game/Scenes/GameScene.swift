import GameplayKit
import SpriteKit
import UIKit

/// Main gameplay scene (M1 core loop): test room, hero with twin-stick controls and the starter
/// blaster, three boltbots, loot pickups and the M1 placeholder rescue. All numbers come from
/// `GameData`.
@MainActor
final class GameScene: SKScene, @preconcurrency SKPhysicsContactDelegate, EnemyWorld {
    /// Logical scene size (iPad landscape points); `.aspectFill` scales to the device.
    static let logicalSize = CGSize(width: 1194, height: 834)
    /// GDD §5: projectile pool size for the hero.
    static let projectileCapacity = 64
    /// M1 is a single level-1 test room.
    static let level = 1

    weak var model: GameModel? {
        didSet {
            model?.commandHandler = { [weak self] command in self?.handle(command) }
            lastHUD = nil
            pushHUD()
        }
    }

    let data: GameData
    let room: TestRoom.Layout
    let worldNode = SKNode()
    let cameraNode = SKCameraNode()
    let hero: HeroNode
    let pool: ProjectilePool
    private(set) var enemies: [EnemyNode] = []
    private(set) var pickups: [PickupNode] = []
    private(set) var score = 0
    /// Items picked up that have no M1 effect (inventory arrives in M3).
    private(set) var collectedCounts: [String: Int] = [:]
    let random: GKRandom
    var aimAssistEnabled: Bool

    private var cameraController: CameraController!
    private var sticks: TwinStickController!
    private var aimAngle: CGFloat = 0
    private var lastUpdateTime: TimeInterval?
    private var lastHUD: HUDState?
    private var pendingHits: [(ProjectileNode, EnemyNode?)] = []
    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)
    private let mediumHaptic = UIImpactFeedbackGenerator(style: .medium)

    /// Ignores aim-stick noise when the finger rests on the base.
    private static let aimEpsilon: CGFloat = 0.05
    private static let maxStep = 1.0 / 30

    // MARK: Setup

    static func makeDefault() -> GameScene {
        let data: GameData
        do {
            data = try GameData.load()
        } catch {
            fatalError("Bundled game data failed to load: \(error)")
        }
        return GameScene(data: data)
    }

    init(data: GameData, size: CGSize = GameScene.logicalSize, seed: UInt64 = UInt64(Date().timeIntervalSince1970)) {
        self.data = data
        self.random = GKMersenneTwisterRandomSource(seed: seed)
        self.aimAssistEnabled = data.controls.aimAssistDefaultOn
        room = TestRoom.build()
        guard let weapon = data.weapons[data.hero.startLoadout.weaponId] else {
            fatalError("hero.json startLoadout.weaponId \(data.hero.startLoadout.weaponId) not in weapons.json")
        }
        hero = HeroNode(def: data.hero, weapon: weapon)
        pool = ProjectilePool(capacity: Self.projectileCapacity, bodyRadius: CGFloat(weapon.projectileRadius))
        super.init(size: size)
        scaleMode = .aspectFill
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        backgroundColor = Palette.hex(0x1E1B3D)
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self
        buildWorld()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not supported") }

    private func buildWorld() {
        worldNode.name = "world"
        addChild(worldNode)
        worldNode.addChild(room.node)

        hero.position = room.heroSpawn
        worldNode.addChild(hero)

        if let boltbot = data.enemies["boltbot"] {
            for p in room.enemySpawns {
                let e = EnemyNode(def: boltbot, at: p, world: self)
                enemies.append(e)
                worldNode.addChild(e)
            }
        }

        cameraNode.name = "camera"
        addChild(cameraNode)
        camera = cameraNode
        cameraController = CameraController(camera: cameraNode, def: data.camera, bounds: room.bounds)
        cameraController.snap(to: hero.position, visibleSize: visibleSize)
        sticks = TwinStickController(controls: data.controls, layer: cameraNode)
    }

    override func didMove(to view: SKView) {
        view.isMultipleTouchEnabled = true
        cameraController.snap(to: hero.position, visibleSize: visibleSize)
        lightHaptic.prepare()
        mediumHaptic.prepare()
    }

    /// Part of the scene actually on screen with `.aspectFill`.
    var visibleSize: CGSize {
        guard let view, view.bounds.width > 0, view.bounds.height > 0 else { return size }
        let scale = max(view.bounds.width / size.width, view.bounds.height / size.height)
        return CGSize(width: view.bounds.width / scale, height: view.bounds.height / scale)
    }

    // MARK: EnemyWorld

    var heroPosition: CGPoint { hero.position }
    var roomGeometry: RoomGeometry { room.geometry }
    var activeEnemies: [EnemyNode] { enemies.filter { !$0.isPoweredDown } }

    // MARK: Commands

    func handle(_ command: GameCommand) {
        switch command {
        case .reload:
            hero.weapon.startReload()
            pushHUD()
        }
    }

    // MARK: Touches (sticks live in the scene; HUD buttons swallow their touches first)

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let view else { return }
        sticks.touchesBegan(touches, view: view)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        sticks.touchesMoved(touches)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        sticks.touchesEnded(touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        sticks.touchesEnded(touches)
    }

    // MARK: Frame

    override func update(_ currentTime: TimeInterval) {
        let dt = lastUpdateTime.map { min(Self.maxStep, max(0, currentTime - $0)) } ?? 0
        lastUpdateTime = currentTime
        step(dt: dt)
    }

    /// One simulation step (separate from `update` so tests can drive it).
    func step(dt: Double) {
        updateHero(dt: dt)
        for e in enemies { e.tick(dt: dt) }
        updateProjectiles(dt: dt)
        checkContactDamage()
        updatePickups(dt: dt)
        let aimVec: CGVector? = isAiming ? CGVector(dx: cos(aimAngle), dy: sin(aimAngle)) : nil
        cameraController.update(dt: dt, target: hero.position, aim: aimVec, visibleSize: visibleSize)
        depthSort()
        pushHUD()
    }

    private var isAiming: Bool {
        guard let a = sticks.aim else { return false }
        return a.rawMagnitude > Self.aimEpsilon
    }

    private func updateHero(dt: Double) {
        if let m = sticks.move, m.isActive {
            hero.drive(direction: m.direction, magnitude: m.magnitude, dt: dt)
        } else {
            hero.drive(direction: .zero, magnitude: 0, dt: dt)
        }
        if let a = sticks.aim, isAiming {
            aimAngle = a.angle
            hero.animator.face(along: a.direction)
        } else if let m = sticks.move, m.isActive {
            aimAngle = m.angle
            hero.animator.face(along: m.direction)
        }
        hero.tick(dt: dt)
        if hero.weapon.tryFire(triggerHeld: sticks.fireHeld) {
            fire()
        }
    }

    private func fire() {
        let w = hero.weapon.def
        var angle = aimAngle
        if aimAssistEnabled {
            let origin = hero.position
            angle = AimAssist.adjust(
                stickAngle: aimAngle, origin: origin,
                targets: activeEnemies.map(\.position),
                coneDeg: CGFloat(w.aimAssistConeDeg), range: CGFloat(w.range),
                strength: CGFloat(data.controls.aimAssistStrength),
                hasLineOfSight: { [room] in room.geometry.hasLineOfSight(from: origin, to: $0) })
        }
        if w.jitterDeg > 0 {
            angle += CGFloat((Double(random.nextUniform()) * 2 - 1) * w.jitterDeg) * .pi / 180
        }
        let texture = Textures.texture(w.projectileTextureName, in: .items)
        let pellets = max(1, w.pellets)
        let spread = CGFloat(w.spreadDeg) * .pi / 180
        let muzzle = hero.muzzlePoint(angle: angle)
        for i in 0..<pellets {
            let offset = pellets > 1 ? -spread / 2 + spread * CGFloat(i) / CGFloat(pellets - 1) : 0
            _ = pool.spawn(weapon: w, texture: texture, at: muzzle, angle: angle + offset, in: worldNode)
        }
        hero.animator.playRecoil(angle: angle)
        worldNode.addChild(Particles.muzzle(color: Palette.projectile(style: w.projectileStyle), at: muzzle, angle: angle))
    }

    private func updateProjectiles(dt: Double) {
        var expired: [ProjectileNode] = []
        pool.forEachActive { p in
            if !p.step(dt: dt) { expired.append(p) }
        }
        expired.forEach(pool.recycle)
    }

    // MARK: Contacts (shots)

    func didBegin(_ contact: SKPhysicsContact) {
        let a = contact.bodyA.node, b = contact.bodyB.node
        if let p = a as? ProjectileNode { pendingHits.append((p, b as? EnemyNode)) }
        else if let p = b as? ProjectileNode { pendingHits.append((p, a as? EnemyNode)) }
    }

    override func didSimulatePhysics() {
        guard !pendingHits.isEmpty else { return }
        let hits = pendingHits
        pendingHits.removeAll(keepingCapacity: true)
        for (shot, enemy) in hits where shot.isActive {
            let color = Palette.projectile(style: shot.style)
            if let enemy {
                guard !enemy.isPoweredDown else { continue } // shots pass through powered-down enemies
                hitEnemy(enemy, with: shot)
            } else {
                worldNode.addChild(Particles.hitSparkle(color: color, at: shot.position, shotAngle: shot.angle, small: true))
            }
            pool.recycle(shot)
        }
    }

    private func hitEnemy(_ enemy: EnemyNode, with shot: ProjectileNode) {
        let dir = CGVector(dx: cos(shot.angle), dy: sin(shot.angle))
        worldNode.addChild(Particles.hitSparkle(color: Palette.projectile(style: shot.style),
                                                at: shot.position, shotAngle: shot.angle,
                                                small: shot.style == "foam"))
        switch enemy.health.applyDamage(shot.damage) {
        case .ignored:
            return
        case .hit:
            enemy.knockBack(along: dir, distance: shot.knockback)
            enemy.animator.playHit(from: dir)
            if enemy.brain.currentState is IdleState { enemy.brain.enter(AlertState.self) }
        case .depleted:
            powerDown(enemy)
        }
    }

    private func powerDown(_ enemy: EnemyNode) {
        score += enemy.def.scoreValue
        mediumHaptic.impactOccurred()
        let origin = enemy.position
        worldNode.addChild(Particles.poof(at: origin))
        let drops = LootRoller.roll(tableId: enemy.def.lootTableId, data: data, context: lootContext, random: random)
        enemy.powerDown { [weak self, weak enemy] in
            guard let self, let enemy else { return }
            self.spawnLoot(drops, at: origin)
            enemy.removeFromParent()
            self.enemies.removeAll { $0 === enemy }
        }
    }

    var lootContext: LootContext {
        let w = hero.weapon
        let cap = max(1, w.def.magazineSize + w.def.reserveMax)
        return LootContext(level: Self.level, heroHpRatio: hero.health.ratio,
                           equippedWeaponId: w.def.id,
                           equippedAmmoRatio: Double(w.totalAmmo) / Double(cap),
                           ownedWeaponIds: [data.hero.startLoadout.weaponId])
    }

    // MARK: Loot

    /// Safety cap on pickup nodes per drop entry.
    private static let maxNodesPerDrop = 12

    func spawnLoot(_ drops: [LootDrop], at origin: CGPoint) {
        for drop in drops {
            guard let item = data.items[drop.itemId] else { continue }
            for _ in 0..<min(drop.count, Self.maxNodesPerDrop) {
                let target = popTarget(from: origin)
                let node = PickupNode(item: item, from: origin, to: target)
                pickups.append(node)
                worldNode.addChild(node)
            }
        }
    }

    private func popTarget(from origin: CGPoint) -> CGPoint {
        let geo = room.geometry
        let clearance: CGFloat = 12
        for _ in 0..<8 {
            let a = CGFloat(random.nextUniform()) * 2 * .pi
            let d = CGFloat(random.nextUniform()) * PickupNode.maxPopDistance
            let p = CGPoint(x: origin.x + cos(a) * d, y: origin.y + sin(a) * d)
            if !geo.isBlocked(p, radius: clearance) { return p }
        }
        return origin
    }

    private func updatePickups(dt: Double) {
        let h = hero.position
        let pickupR = CGFloat(data.hero.pickupRadius)
        let magnetR = CGFloat(data.hero.magnetRadius)
        let magnetSpeed = CGFloat(data.hero.moveSpeed) * PickupNode.magnetSpeedFactor
        var collected: [PickupNode] = []
        for p in pickups {
            let g = p.groundPosition
            let d = hypot(g.x - h.x, g.y - h.y)
            let pull = p.hasLanded && p.item.isMagnetic && d <= magnetR
            p.step(dt: dt, magnetTarget: pull ? h : nil, magnetSpeed: magnetSpeed)
            if p.hasLanded, d <= pickupR, apply(pickup: p.item) {
                collected.append(p)
            }
        }
        for p in collected {
            worldNode.addChild(Particles.collect(at: p.position))
            p.collect()
            pickups.removeAll { $0 === p }
        }
    }

    /// M1 pickup effects (DECISIONS 2026-11-22). Returns false when the pickup stays on the floor.
    private func apply(pickup item: ItemDef) -> Bool {
        if let value = item.scoreValue, item.category == .collectible {
            score += value
            return true
        }
        if item.category == .ammo, item.ammoId == hero.weapon.def.ammoId, let amount = item.ammoAmount {
            let overflow = hero.weapon.addReserve(amount)
            if overflow == amount { return false } // reserve full: leave it (no inventory until M3)
            return true
        }
        collectedCounts[item.id, default: 0] += 1
        return true
    }

    // MARK: Hero damage + M1 rescue

    private func checkContactDamage() {
        guard !hero.health.isInvulnerable else { return }
        for e in enemies where !e.isPoweredDown && e.def.contactDamage > 0 {
            let dx = hero.position.x - e.position.x, dy = hero.position.y - e.position.y
            guard hypot(dx, dy) < hero.radius + e.radius else { continue }
            let dir = CGVector(dx: dx, dy: dy)
            switch hero.health.applyDamage(e.def.contactDamage) {
            case .ignored:
                continue
            case .hit:
                hero.knockBack(along: dir)
                hero.animator.playHit(from: dir)
                worldNode.addChild(Particles.heroHit(at: hero.position))
                lightHaptic.impactOccurred()
            case .depleted:
                lightHaptic.impactOccurred()
                rescueHero()
            }
            return
        }
    }

    /// M1 placeholder for the Pixel rescue (M3): sparkle out, reappear at the room spawn with full
    /// HP and a short invulnerability window. No "game over".
    func rescueHero() {
        worldNode.addChild(Particles.teleport(at: hero.position))
        hero.clearKnockback()
        hero.position = room.heroSpawn
        hero.health.reset(invulnerableFor: data.hero.effectiveRespawnInvulnerableSec)
        hero.animator.reset()
        worldNode.addChild(Particles.teleport(at: hero.position))
        for e in enemies where !e.isPoweredDown { e.brain.enter(IdleState.self) }
        cameraController.snap(to: hero.position, visibleSize: visibleSize)
    }

    // MARK: Draw order + HUD

    private func depthSort() {
        let h = max(1, room.bounds.height)
        func z(_ y: CGFloat) -> CGFloat { 10 + (room.bounds.maxY - y) / h }
        hero.zPosition = z(hero.position.y)
        for e in enemies { e.zPosition = z(e.position.y) }
    }

    var hudState: HUDState {
        let w = hero.weapon
        return HUDState(
            hp: hero.health.current, maxHp: hero.health.max,
            magazine: w.magazine, reserve: w.reserve, magazineSize: w.def.magazineSize,
            isReloading: w.isReloading,
            reloadProgress: (w.reloadProgress * 20).rounded(.down) / 20,
            canReload: w.canReload, score: score, weaponId: w.def.id)
    }

    private func pushHUD() {
        guard let model else { return }
        let s = hudState
        guard s != lastHUD else { return }
        lastHUD = s
        model.hud = s
    }
}
