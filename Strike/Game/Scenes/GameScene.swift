import GameplayKit
import SpriteKit
import UIKit

/// Main gameplay scene: one generated level (`levels.json` + seed) with the hero, enemies, loot,
/// puzzle elements, doors, checkpoints and the exit pad. All numbers come from `GameData`.
@MainActor
final class GameScene: SKScene, @preconcurrency SKPhysicsContactDelegate, EnemyWorld {
    /// Logical scene size (iPad landscape points); `.aspectFill` scales to the device.
    static let logicalSize = CGSize(width: 1194, height: 834)
    /// GDD §5: projectile pool size for the hero.
    static let projectileCapacity = 64

    weak var model: GameModel? {
        didSet {
            model?.commandHandler = { [weak self] command in self?.handle(command) }
            lastHUD = nil
            pushHUD()
            pushMinimap(force: true)
        }
    }

    let data: GameData
    let levelDef: LevelDef
    let level: GeneratedLevel
    let built: LevelBuilder.Built
    /// Current solid map: closed doors are walls.
    private(set) var solidGrid: TileGrid
    let pathfinder: Pathfinder
    let worldNode = SKNode()
    let cameraNode = SKCameraNode()
    let hero: HeroNode
    let pool: ProjectilePool
    private(set) var enemies: [EnemyNode] = []
    private(set) var pickups: [PickupNode] = []
    private(set) var puzzle: PuzzleState
    /// The hero's bag (M3 pass B feeds it from `RunState`).
    private(set) var inventory: Inventory
    private(set) var session: LevelSession
    /// Items picked up that have no effect before M3 (inventory) / M4 (weapons).
    private(set) var collectedCounts: [String: Int] = [:]
    let random: GKRandom
    var aimAssistEnabled: Bool
    private(set) var focusedId: String?
    private(set) var isComplete = false

    private var cameraController: CameraController!
    private var sticks: TwinStickController!
    private var aimAngle: CGFloat = 0
    private var lastUpdateTime: TimeInterval?
    private var lastHUD: HUDState?
    private var pendingHits: [(ProjectileNode, SKNode?)] = []
    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)
    /// Sound effects and jingles (tests swap in a recorder).
    var audio: AudioSink? = AudioManager.shared
    private var playedLevelStart = false
    private var wasReloading = false
    private var wasTriggerHeld = false
    private let mediumHaptic = UIImpactFeedbackGenerator(style: .medium)

    // Door pan, exit, minimap, toasts.
    private struct DoorPan {
        let door: DoorNode
        let from: CGPoint
        let to: CGPoint
        var t: Double = 0
        var opened = false
    }
    private var pan: DoorPan?
    private var panQueue: [DoorNode] = []
    private var exitStand: Double = 0
    /// Counts down from `ExitPadNode.flashSec` after the pad is reached, then shows the card.
    private var completionDelay: Double?
    private var pendingResult: LevelResult?
    /// Niche cells of the pad's row: standing on any of them counts (2-wide niches put the pad
    /// sprite between two cells).
    private lazy var exitPadCells: Set<GridPoint> = {
        let door = level.exitDoor.cells
        func dist(_ c: GridPoint) -> Int { door.map { $0.chebyshev(c) }.min() ?? 0 }
        let far = level.exitDoor.niche.map(dist).max() ?? 0
        return Set(level.exitDoor.niche.filter { dist($0) == far } + [level.exitPad])
    }()
    private var clock: Double = 0
    private var minimapTimer: Double = 0
    private var lastMinimap: MinimapSnapshot?
    private var revealedCorridor = Set<GridPoint>()
    private var corridorCells = Set<GridPoint>()
    private var lastHeroCell = GridPoint(-1, -1)
    private var toastLastShown: [String: Double] = [:]
    private var toastCounter = 0
    private var toastClearTask: Task<Void, Never>?

    /// Ignores aim-stick noise when the finger rests on the base.
    private static let aimEpsilon: CGFloat = 0.05
    private static let maxStep = 1.0 / 30
    /// Door pan: camera rests on the opening door this long before control returns.
    static let panHoldSec = 0.6
    /// ART_BIBLE §13.1: corridor cells within this Chebyshev distance of the hero get revealed.
    static let corridorRevealCells = 3

    // MARK: Setup

    init(data: GameData, level def: LevelDef, seed: UInt64, size: CGSize = GameScene.logicalSize) {
        self.data = data
        self.levelDef = def
        self.random = GKMersenneTwisterRandomSource(seed: seed)
        self.aimAssistEnabled = data.controls.aimAssistDefaultOn
        level = LevelGenerator.generate(def, seed: seed, data: data)
        built = LevelBuilder.build(level, def: def, data: data)
        solidGrid = level.gridAllDoorsClosed
        pathfinder = Pathfinder(grid: solidGrid)
        puzzle = PuzzleState(level: level, rules: data.rules.puzzle)
        inventory = Inventory(items: data.items, rules: data.rules.inventory)
        session = LevelSession(level: level)
        guard let weapon = data.weapons[data.hero.startLoadout.weaponId] else {
            fatalError("hero.json startLoadout.weaponId \(data.hero.startLoadout.weaponId) not in weapons.json")
        }
        hero = HeroNode(def: data.hero, weapons: data.weapons)
        pool = ProjectilePool(capacity: Self.projectileCapacity, bodyRadius: CGFloat(weapon.projectileRadius))
        super.init(size: size)
        scaleMode = .aspectFill
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        backgroundColor = Palette.background
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self
        buildWorld()
    }

    /// Level by id (debug launch arguments, tests).
    convenience init(data: GameData, levelId: String, seed: UInt64, size: CGSize = GameScene.logicalSize) {
        guard let def = data.levels[levelId] ?? data.levelOrder.first else { fatalError("levels.json has no levels") }
        self.init(data: data, level: def, seed: seed, size: size)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not supported") }

    private func buildWorld() {
        worldNode.name = "world"
        addChild(worldNode)
        worldNode.addChild(built.root)

        hero.position = level.grid.world(level.heroStart)
        worldNode.addChild(hero)

        for s in level.enemySpawns {
            guard let def = data.enemies[s.enemyId] else { continue }
            let e = EnemyNode(def: def, at: s.position, world: self, homeRoomId: s.roomId, leash: data.rules.leash)
            enemies.append(e)
            worldNode.addChild(e)
        }
        for p in level.pickups {
            guard let item = data.items[p.itemId] else { continue }
            addPickup(item, at: level.grid.world(p.cell), placementId: p.id)
        }
        for i in level.itemPlacements {
            guard let item = data.items[i.itemId] else { continue }
            addPickup(item, at: level.grid.world(i.cell), placementId: i.id)
        }
        for c in level.corridors { corridorCells.formUnion(c.cells) }
        if let start = level.checkpoints.first { built.checkpoints[start.id]?.setOn(true, animated: false) }
        if !data.rules.minimap.revealOnEnter { revealAll() }
        refreshDoorCounters(pop: nil)

        cameraNode.name = "camera"
        addChild(cameraNode)
        camera = cameraNode
        cameraController = CameraController(camera: cameraNode, def: data.camera, bounds: level.grid.bounds,
                                            hudBand: CGFloat(data.controls.hudBandHeight))
        cameraController.snap(to: hero.position, visibleSize: visibleSize)
        sticks = TwinStickController(controls: data.controls, layer: cameraNode)
        updateReveal()
    }

    private func addPickup(_ item: ItemDef, at p: CGPoint, placementId: String?) {
        let node = PickupNode(item: item, from: p, to: p)
        node.placementId = placementId
        pickups.append(node)
        worldNode.addChild(node)
    }

    override func didMove(to view: SKView) {
        view.isMultipleTouchEnabled = true
        cameraController.snap(to: hero.position, visibleSize: visibleSize)
        lightHaptic.prepare()
        mediumHaptic.prepare()
        if !playedLevelStart {
            playedLevelStart = true
            audio?.play(.levelStart)
        }
    }

    /// Part of the scene actually on screen with `.aspectFill`.
    var visibleSize: CGSize {
        guard let view, view.bounds.width > 0, view.bounds.height > 0 else { return size }
        let scale = max(view.bounds.width / size.width, view.bounds.height / size.height)
        return CGSize(width: view.bounds.width / scale, height: view.bounds.height / scale)
    }

    // MARK: EnemyWorld

    var heroPosition: CGPoint { hero.position }
    var activeEnemies: [EnemyNode] { enemies.filter { !$0.isPoweredDown } }

    func enemyDidSpotHero(_ enemy: EnemyNode) {
        audio?.play(.enemyAlert)
    }

    // MARK: Commands

    func handle(_ command: GameCommand) {
        switch command {
        case .reload:
            hero.startReload()
        case .interact:
            interact()
        case .debugSolveAll:
            solveAll()
        case .debugGotoExit:
            hero.clearKnockback()
            hero.position = built.exitPad.position
            cameraController.snap(to: hero.position, visibleSize: visibleSize)
        case .debugRevealMap:
            revealAll()
            pushMinimap(force: true)
        case .resetInput:
            sticks.reset()
            hero.drive(direction: .zero, magnitude: 0, dt: 0)
        }
        pushHUD()
    }

    // MARK: Touches (sticks live in the scene; HUD buttons swallow their touches first)

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if pan != nil {
            skipPan()
            return
        }
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
        if var t = completionDelay {
            t -= dt
            completionDelay = t
            if t <= 0, let r = pendingResult {
                completionDelay = nil
                pendingResult = nil
                model?.completeLevel(r)
            }
        }
        guard !isComplete else { return }
        clock += dt
        if pan != nil {
            updatePan(dt: dt)
            pushHUD()
            return
        }
        session.tick(dt: dt)
        puzzle.tick(dt: dt)
        updateHero(dt: dt)
        for e in enemies { e.tick(dt: dt) }
        updateProjectiles(dt: dt)
        checkContactDamage()
        updatePickups(dt: dt)
        updatePlates(dt: dt)
        updateFocus()
        updateCheckpoints()
        updateDoorsInfo()
        updateExit(dt: dt)
        updateReveal()
        let aimVec: CGVector? = isAiming ? CGVector(dx: cos(aimAngle), dy: sin(aimAngle)) : nil
        cameraController.update(dt: dt, target: hero.position, aim: aimVec, visibleSize: visibleSize)
        depthSort()
        pushHUD()
        minimapTimer -= dt
        if minimapTimer <= 0 {
            minimapTimer = 1 / max(1, data.rules.minimap.updateHz)
            pushMinimap(force: false)
        }
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
        let held = sticks.fireHeld
        let pressed = held && !wasTriggerHeld
        wasTriggerHeld = held
        if hero.tryFire(triggerHeld: held) {
            fire()
        } else if pressed, hero.magazine == 0, !hero.weapon.isReloading {
            // Trigger pulled with nothing to fire and nothing to reload.
            audio?.play(.emptyClick)
        }
        let reloading = hero.weapon.isReloading
        if reloading, !wasReloading { audio?.play(.reload) }
        wasReloading = reloading
    }

    private func fire() {
        let w = hero.weapon.def
        var angle = aimAngle
        if aimAssistEnabled {
            let origin = hero.position
            let grid = solidGrid
            angle = AimAssist.adjust(
                stickAngle: aimAngle, origin: origin,
                targets: activeEnemies.map(\.position),
                coneDeg: CGFloat(w.aimAssistConeDeg), range: CGFloat(w.range),
                strength: CGFloat(data.controls.aimAssistStrength),
                hasLineOfSight: { grid.hasLineOfSight(from: origin, to: $0) })
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
        audio?.play(.shot(weaponId: w.id))
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
        if let p = a as? ProjectileNode { pendingHits.append((p, b)) }
        else if let p = b as? ProjectileNode { pendingHits.append((p, a)) }
    }

    override func didSimulatePhysics() {
        guard !pendingHits.isEmpty else { return }
        let hits = pendingHits
        pendingHits.removeAll(keepingCapacity: true)
        for (shot, target) in hits where shot.isActive {
            let color = Palette.projectile(style: shot.style)
            if let enemy = target as? EnemyNode {
                guard !enemy.isPoweredDown else { continue } // shots pass through powered-down enemies
                hitEnemy(enemy, with: shot)
            } else if let crate = target as? CrateNode {
                guard !crate.isBroken else { continue }
                worldNode.addChild(Particles.hitSparkle(color: color, at: shot.position, shotAngle: shot.angle, small: true))
                if crate.hit(damage: shot.damage) { breakCrate(crate) }
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
            audio?.play(.enemyHit)
            if enemy.brain.currentState is IdleState { enemy.brain.enter(AlertState.self) }
        case .depleted:
            powerDown(enemy)
        }
    }

    private func powerDown(_ enemy: EnemyNode) {
        session.addScore(enemy.def.scoreValue)
        mediumHaptic.impactOccurred()
        audio?.play(.enemyPowerDown)
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

    private func breakCrate(_ crate: CrateNode) {
        audio?.play(.crateBreak)
        worldNode.addChild(Particles.poof(at: crate.position, bodyColors: [Palette.star, Palette.robotMetalLight]))
        let drops = LootRoller.roll(tableId: crate.lootTableId, data: data, context: lootContext, random: random)
        spawnLoot(drops, at: crate.position)
    }

    var lootContext: LootContext {
        let w = hero.weapon
        let cap = max(1, w.def.magazineSize + w.def.reserveMax)
        return LootContext(level: levelDef.index, heroHpRatio: hero.health.ratio,
                           equippedWeaponId: w.def.id,
                           equippedAmmoRatio: Double(hero.totalAmmo) / Double(cap),
                           equippedAmmoTotal: hero.totalAmmo,
                           ownedWeaponIds: Set(hero.loadout.owned))
    }

    // MARK: Loot

    /// Safety cap on pickup nodes per drop entry.
    private static let maxNodesPerDrop = 12

    func spawnLoot(_ drops: [LootDrop], at origin: CGPoint) {
        for drop in drops {
            guard let item = data.items[drop.itemId] else { continue }
            for _ in 0..<min(drop.count, Self.maxNodesPerDrop) {
                let node = PickupNode(item: item, from: origin, to: popTarget(from: origin))
                pickups.append(node)
                worldNode.addChild(node)
            }
        }
    }

    private func popTarget(from origin: CGPoint) -> CGPoint {
        let clearance: CGFloat = 12
        for _ in 0..<8 {
            let a = CGFloat(random.nextUniform()) * 2 * .pi
            let d = CGFloat(random.nextUniform()) * PickupNode.maxPopDistance
            let p = CGPoint(x: origin.x + cos(a) * d, y: origin.y + sin(a) * d)
            if !solidGrid.isBlocked(p, radius: clearance) { return p }
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
            if p.hasLanded, d <= pickupR, apply(pickup: p) {
                collected.append(p)
            }
        }
        for p in collected {
            audio?.play(Self.pickupSound(p.item))
            worldNode.addChild(Particles.collect(at: p.position))
            p.collect()
            pickups.removeAll { $0 === p }
        }
    }

    /// Pickup effects. Returns false when the pickup stays on the floor.
    private func apply(pickup p: PickupNode) -> Bool {
        let item = p.item
        switch item.category {
        case .collectible:
            if item.id == LevelGenerator.datachipItemId {
                session.collectDatachip(p.placementId ?? "datachip_\(session.datachipsFound.count)", score: item.scoreValue ?? 0)
            } else if item.id == LootRoller.boltItemId {
                session.addBolts(1, scoreEach: item.scoreValue ?? 0)
            } else {
                session.addScore(item.scoreValue ?? 0)
            }
            return true
        case .puzzle:
            guard inventory.add(item.id, count: 1) == 0 else {
                showToast("ui.toast.bag_full")
                return false
            }
            showToast("ui.toast.got_item", arg: itemName(item.id), key: "ui.toast.got_item.\(item.id)")
            return true
        case .ammo:
            if let ammoId = item.ammoId, let amount = item.ammoAmount {
                let overflow = hero.loadout.ammo.add(ammoId, amount: amount)
                return overflow != amount // reserve full: leave it (pass B: PickupResolver, overflow packs)
            }
            collectedCounts[item.id, default: 0] += 1
            return true
        default:
            collectedCounts[item.id, default: 0] += 1
            return true
        }
    }

    static func pickupSound(_ item: ItemDef) -> AudioEvent {
        switch item.category {
        case .ammo: .pickupAmmo
        case .heal, .food: .pickupHeal
        case .collectible where item.id == LootRoller.boltItemId: .pickupBolt
        default: .pickupItem
        }
    }

    private func itemName(_ itemId: String) -> String {
        guard let key = data.items[itemId]?.nameKey else { return itemId }
        return String(localized: String.LocalizationValue(key))
    }

    // MARK: Puzzle

    private var interactRadius: CGFloat {
        CGFloat(data.rules.puzzle.interactFocusRadius ?? data.hero.interactRadius)
    }

    /// GDD §11 M2 notes: the nearest interactable within range gets focus (plates are stood on).
    private func updateFocus() {
        var best: (id: String, d: CGFloat)?
        for (id, node) in built.interactables where node.type != .pressureplate {
            let d = node.interactDistance(from: hero.position)
            guard d <= interactRadius else { continue }
            if best == nil || d < best!.d || (d == best!.d && id < best!.id) { best = (id, d) }
        }
        let newId = best?.id
        if newId != focusedId, let old = focusedId { built.interactables[old]?.setFocus(.none) }
        focusedId = newId
        if let id = newId, let node = built.interactables[id] { node.setFocus(isUsable(id) ? .usable : .unusable) }
    }

    private func isUsable(_ id: String) -> Bool {
        guard let e = puzzle.elements[id] else { return false }
        switch e.type {
        case .button: return !e.isOn
        case .lever: return e.pullRemaining <= 0
        case .machine: return !e.isOn && (e.requiresItem.map { inventory.count(of: $0) > 0 } ?? true)
        case .pressureplate: return false
        }
    }

    private func interact() {
        guard pan == nil, let id = focusedId, let node = built.interactables[id] else { return }
        let result = puzzle.interact(id, carrier: &inventory)
        switch result {
        case .activated:
            lightHaptic.impactOccurred()
            audio?.play(node.type == .machine ? .machineOn : .buttonPress)
            node.setOn(true, animated: true)
            elementChanged(id)
        case .toggled:
            lightHaptic.impactOccurred()
            audio?.play(.leverPull)
            (node as? LeverNode)?.playPull(to: puzzle.isOn(id), duration: data.rules.puzzle.leverPullSec)
            elementChanged(id)
        case .needsItem(let item):
            (node as? MachineNode)?.showNeedsItem()
            showToast("ui.toast.need_item", arg: itemName(item), key: "ui.toast.need_item.\(item)")
        case .alreadyOn, .notReady:
            break
        }
    }

    private func updatePlates(dt: Double) {
        let heroCell = level.grid.cell(at: hero.position)
        for e in level.elements where e.type == .pressureplate {
            guard let node = built.interactables[e.id] as? PressurePlateNode else { continue }
            let held = e.cells.contains(heroCell)
            if puzzle.updatePlate(e.id, occupied: held, dt: dt) == .activated {
                audio?.play(.plateOn)
                node.setOn(true, animated: true)
                elementChanged(e.id)
            } else {
                node.setProgress(puzzle.plateProgress(e.id), held: held)
            }
        }
    }

    /// After an element changed: door counters, then doors that just became satisfied.
    private func elementChanged(_ id: String) {
        refreshDoorCounters(pop: id)
        for g in level.gates where puzzle.isGateOpen(g.id) {
            if let d = built.gates[g.id], !d.isOpen, !panQueue.contains(where: { $0 === d }), pan?.door !== d {
                panQueue.append(d)
            }
        }
        if puzzle.isExitOpen, !built.exitDoor.isOpen, !panQueue.contains(where: { $0 === built.exitDoor }),
           pan?.door !== built.exitDoor {
            panQueue.append(built.exitDoor)
        }
        startNextPan()
    }

    private func refreshDoorCounters(pop: String?) {
        for g in level.gates {
            let p = puzzle.gateProgress(g.id)
            built.gates[g.id]?.setProgress(on: p.on, total: p.total, pop: pop.map { g.elementIds.contains($0) } ?? false)
        }
        let p = puzzle.requiredProgress
        built.exitDoor.setProgress(on: p.on, total: p.total, pop: pop.map { level.exitDoor.elementIds.contains($0) } ?? false)
    }

    private func updateDoorsInfo() {
        for d in built.gates.values { d.updateInfo(heroDistance: hypot(d.position.x - hero.position.x, d.position.y - hero.position.y)) }
        let e = built.exitDoor
        e.updateInfo(heroDistance: hypot(e.position.x - hero.position.x, e.position.y - hero.position.y))
    }

    // MARK: Door pan (GDD §11: 1.0 s to the door, input locked, tap skips)

    private func startNextPan() {
        guard pan == nil, !panQueue.isEmpty else { return }
        let door = panQueue.removeFirst()
        physicsWorld.speed = 0
        hero.drive(direction: .zero, magnitude: 0, dt: 0)
        sticks.reset()
        pan = DoorPan(door: door, from: cameraNode.position,
                      to: cameraController.clamped(door.position, visibleSize: visibleSize))
    }

    private func updatePan(dt: Double) {
        guard var p = pan else { return }
        let dur = max(0.01, data.rules.puzzle.doorPanSec)
        p.t += dt
        let k = CGFloat(min(1, p.t / dur))
        let e = k * k * (3 - 2 * k)
        cameraNode.position = CGPoint(x: p.from.x + (p.to.x - p.from.x) * e, y: p.from.y + (p.to.y - p.from.y) * e)
        if !p.opened, p.t >= dur {
            p.opened = true
            openDoor(p.door, animated: true)
        }
        pan = p
        if p.t >= dur + Self.panHoldSec { endPan() }
    }

    private func skipPan() {
        guard let p = pan else { return }
        if !p.opened { openDoor(p.door, animated: true) }
        endPan()
    }

    private func endPan() {
        pan = nil
        physicsWorld.speed = 1
        if panQueue.isEmpty {
            // Control returns; the follow camera eases back to the hero.
        } else {
            startNextPan()
        }
    }

    private func openDoor(_ door: DoorNode, animated: Bool) {
        guard !door.isOpen else { return }
        door.open(animated: animated)
        for c in door.cells { solidGrid[c] = .floor }
        pathfinder.setCells(door.cells, walkable: true)
        for e in enemies { e.clearPath() }
        audio?.play(door === built.exitDoor ? .doorOpen : .gateUnlocked)
        if door === built.exitDoor {
            built.exitPad.setOn(true)
            showToast("ui.toast.door_open")
        } else {
            showToast("ui.toast.gate_open")
        }
        pushMinimap(force: true)
    }

    /// Debug "turn all on": every element on, every door open at once (no pan).
    private func solveAll() {
        puzzle.forceAllOn()
        for (id, node) in built.interactables { node.setOn(puzzle.isOn(id), animated: false) }
        refreshDoorCounters(pop: nil)
        panQueue.removeAll()
        if pan != nil { endPan() }
        for d in built.gates.values { openDoor(d, animated: false) }
        openDoor(built.exitDoor, animated: false)
    }

    // MARK: Checkpoints, exit

    private func updateCheckpoints() {
        for c in level.checkpoints {
            guard let node = built.checkpoints[c.id],
                  hypot(node.position.x - hero.position.x, node.position.y - hero.position.y) <= CheckpointNode.triggerRadius
            else { continue }
            if session.touchCheckpoint(c.id) {
                node.setOn(true, animated: true)
                audio?.play(.checkpoint)
                showToast("ui.toast.checkpoint")
                pushMinimap(force: true)
            }
        }
    }

    private func updateExit(dt: Double) {
        let pad = built.exitPad
        let onPad = hypot(pad.position.x - hero.position.x, pad.position.y - hero.position.y) <= ExitPadNode.triggerRadius
            || exitPadCells.contains(level.grid.cell(at: hero.position))
        guard puzzle.isExitOpen, built.exitDoor.isOpen, onPad else { exitStand = 0; return }
        exitStand += dt
        guard exitStand >= ExitPadNode.standSec else { return }
        completeLevel()
    }

    private func completeLevel() {
        guard !isComplete else { return }
        isComplete = true
        session.complete()
        built.exitPad.playReached()
        audio?.playJingle(data.level(after: levelDef.id) == nil ? MusicID.seasonComplete : MusicID.levelComplete)
        hero.drive(direction: .zero, magnitude: 0, dt: 0)
        let result = LevelResult(levelId: levelDef.id, nameKey: levelDef.nameKey, timeSec: Int(session.elapsed.rounded()),
                                 score: session.score, datachips: session.datachipsFound.count,
                                 datachipsTotal: levelDef.pickups.datachips, isLast: data.level(after: levelDef.id) == nil)
        // Driven by `step` (not an SKAction) so headless tests reach the card too.
        pendingResult = result
        completionDelay = ExitPadNode.flashSec
    }

    // MARK: Hero damage + rescue

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
                audio?.play(.heroHurt)
            case .depleted:
                lightHaptic.impactOccurred()
                rescueHero()
            }
            return
        }
    }

    /// Where a rescue puts the hero: the last touched checkpoint.
    var respawnPoint: CGPoint {
        if let id = session.lastCheckpointId, let node = built.checkpoints[id] { return node.position }
        return level.grid.world(level.heroStart)
    }

    /// M2 rescue (the Pixel beam is M3): sparkle out, reappear at the last checkpoint with full HP
    /// and a short invulnerability window; living enemies walk home. No "game over".
    func rescueHero() {
        audio?.play(.rescue)
        worldNode.addChild(Particles.teleport(at: hero.position))
        hero.clearKnockback()
        hero.position = respawnPoint
        hero.health.reset(invulnerableFor: data.hero.effectiveRespawnInvulnerableSec)
        hero.animator.reset()
        session.recordRescue()
        worldNode.addChild(Particles.teleport(at: hero.position))
        for e in enemies where !e.isPoweredDown && e.isAware { e.brain.enter(ReturnHomeState.self) }
        cameraController.snap(to: hero.position, visibleSize: visibleSize)
    }

    // MARK: Minimap

    private func updateReveal() {
        let cell = level.grid.cell(at: hero.position)
        guard cell != lastHeroCell else { return }
        lastHeroCell = cell
        if let room = level.room(at: cell), session.reveal(room: room.id) { pushMinimap(force: true) }
        let r = Self.corridorRevealCells
        for dy in -r...r {
            for dx in -r...r {
                let c = GridPoint(cell.x + dx, cell.y + dy)
                if corridorCells.contains(c) { revealedCorridor.insert(c) }
            }
        }
    }

    private func revealAll() {
        for r in level.rooms { session.reveal(room: r.id) }
        revealedCorridor = corridorCells
    }

    var minimapSnapshot: MinimapSnapshot {
        let revealed = session.revealedRoomIds
        var s = MinimapSnapshot()
        s.gridWidth = level.grid.width
        s.gridHeight = level.grid.height
        s.rooms = level.rooms.filter { revealed.contains($0.id) }
            .map { MinimapRect(x: $0.rect.x, y: $0.rect.y, w: $0.rect.width, h: $0.rect.height) }
        s.corridorCells = revealedCorridor.sorted()
        for g in level.gates where revealed.contains(g.fromRoomId) || revealed.contains(g.toRoomId)
            || g.cells.contains(where: revealedCorridor.contains) {
            s.doors.append(MinimapDoor(cells: g.cells, open: built.gates[g.id]?.isOpen ?? false))
        }
        if revealed.contains(level.exitDoor.roomId) {
            s.doors.append(MinimapDoor(cells: level.exitDoor.cells, open: built.exitDoor.isOpen))
            let p = built.exitPad.position
            s.exit = MinimapMark(x: Double(p.x / TileGrid.tileSize), y: Double(p.y / TileGrid.tileSize), on: puzzle.isExitOpen)
        }
        s.elements = level.elements.filter { revealed.contains($0.roomId) }
            .map { MinimapMark(x: $0.center.x, y: $0.center.y, on: puzzle.isOn($0.id)) }
        s.checkpoints = level.checkpoints.filter { revealed.contains($0.roomId) }
            .map { MinimapMark(x: Double($0.cell.x) + 0.5, y: Double($0.cell.y) + 0.5, on: built.checkpoints[$0.id]?.isOn ?? false) }
        s.heroX = Double(hero.position.x / TileGrid.tileSize)
        s.heroY = Double(hero.position.y / TileGrid.tileSize)
        return s
    }

    private func pushMinimap(force: Bool) {
        guard let model else { return }
        let s = minimapSnapshot
        guard force || s != lastMinimap else { return }
        lastMinimap = s
        model.minimap = s
    }

    // MARK: Toasts

    /// Shows `ui.toast.*` (optionally formatted with `arg`); the same `key` is not repeated within
    /// `rules.toast.repeatCooldownSec`.
    func showToast(_ stringKey: String, arg: String? = nil, key: String? = nil) {
        let k = key ?? stringKey
        let rules = data.rules.toast
        if let last = toastLastShown[k], clock - last < rules.repeatCooldownSec { return }
        toastLastShown[k] = clock
        let format = String(localized: String.LocalizationValue(stringKey))
        let text = arg.map { String(format: format, $0) } ?? format
        toastCounter += 1
        let id = toastCounter
        model?.toast = ToastMessage(id: id, text: text)
        toastClearTask?.cancel()
        toastClearTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(rules.showSec))
            guard !Task.isCancelled, let model = self?.model, model.toast?.id == id else { return }
            model.toast = nil
        }
    }

    // MARK: Draw order + HUD

    private func depthSort() {
        let bounds = level.grid.bounds
        let h = max(1, bounds.height)
        func z(_ y: CGFloat) -> CGFloat { 10 + (bounds.maxY - y) / h }
        hero.zPosition = z(hero.position.y)
        for e in enemies { e.zPosition = z(e.position.y) }
    }

    var hudState: HUDState {
        let w = hero.weapon
        var interact: InteractPrompt?
        if let id = focusedId, let node = built.interactables[id] {
            interact = InteractPrompt(elementId: id, kind: node.type.rawValue, usable: isUsable(id))
        }
        return HUDState(
            hp: hero.health.current, maxHp: hero.health.max,
            magazine: hero.magazine, reserve: hero.reserve, magazineSize: w.def.magazineSize,
            isReloading: w.isReloading,
            reloadProgress: (w.reloadProgress * 20).rounded(.down) / 20,
            canReload: hero.canReload, score: session.score, weaponId: w.def.id,
            interact: interact, carried: inventory.totals(in: .puzzle))
    }

    private func pushHUD() {
        guard let model else { return }
        let s = hudState
        guard s != lastHUD else { return }
        lastHUD = s
        model.hud = s
    }
}
