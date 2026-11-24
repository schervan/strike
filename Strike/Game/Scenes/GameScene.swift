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
            model?.carriedProvider = { [weak self] in
                guard let self else { return (Loadout(start: StartLoadoutDef(weaponId: "", magazine: 0, reserve: 0), weapons: [:]),
                                              Inventory(items: [:], slotCount: 0, quickCount: 0)) }
                return (self.hero.loadout, self.inventory)
            }
            lastHUD = nil
            pushHUD()
            pushBag()
            pushMinimap(force: true)
            model?.bubble = pixelBrain.currentLine
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
    /// Weapon pickups (they become blasters in M4).
    private(set) var collectedCounts: [String: Int] = [:]
    let random: GKRandom
    var aimAssistEnabled: Bool
    let pixel: PixelNode
    let pixelBrain: PixelController
    /// L4/L5 dark floors (halo strength, poof contrast ring; ART_BIBLE §13.8 / §14.9).
    let darkFloor: Bool
    /// Clock for item-use cooldowns (real time, so uses inside the paused inventory work).
    var useClock: () -> Double = { CACurrentMediaTime() }
    private(set) var useCooldowns: UseCooldowns
    private(set) var rescue: RescueRun?
    private(set) var arrow: HintArrowNode?
    private var hint: ActiveHint?
    private var bagHintUntil: Double = 0
    private var feedbackCounter = 0
    private var wasLowHp = false
    private var startedStory = false
    private var sightTimer: Double = 0
    private var sightedEnemyTypes = Set<String>()
    private var sightedElements = Set<String>()
    private var sightedGate = false
    private var lastZone = 1
    private var pointerPings: [String] = []
    private var pointerExit = false
    private var pointerTimer: Double = 0
    private var pendingPixelTouch: PendingTouch?
    private(set) var extraCrates: [CrateNode] = []

    /// A touch near Pixel, held back up to `pixel.tapMaxSec` (GDD §13 tap rule).
    private struct PendingTouch {
        let touch: UITouch
        let viewPoint: CGPoint
        let layerPoint: CGPoint
        let viewSize: CGSize
        let start: TimeInterval
    }

    /// The hint that is running (arrow, minimap ping).
    private struct ActiveHint {
        let target: CGPoint
        let elementId: String?
        let floorId: String?
        var remaining: Double
    }

    /// The rescue sequence in progress (GDD §12, ART_BIBLE §14.7); `t` is real seconds since 0 HP.
    struct RescueRun {
        var t: Double = 0
        var teleported = false
        var beamOut: SKNode?
        var beamIn: SKNode?
        var tint: SKSpriteNode?
    }
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

    /// `run`: the carried loadout, bag and settings (nil = a fresh run, tests).
    init(data: GameData, level def: LevelDef, seed: UInt64, size: CGSize = GameScene.logicalSize, run: RunState? = nil) {
        self.data = data
        self.levelDef = def
        self.random = GKMersenneTwisterRandomSource(seed: seed)
        self.aimAssistEnabled = run?.settings.aimAssist ?? data.controls.aimAssistDefaultOn
        darkFloor = def.index >= 4
        pixel = PixelNode(rules: data.rules.pixel, hints: data.rules.hints)
        pixelBrain = PixelController(level: def, rules: data.rules, talk: run?.settings.pixelTalk ?? .lots)
        useCooldowns = UseCooldowns(cooldownSec: data.rules.inventory.useCooldownSec)
        level = LevelGenerator.generate(def, seed: seed, data: data)
        built = LevelBuilder.build(level, def: def, data: data)
        solidGrid = level.gridAllDoorsClosed
        pathfinder = Pathfinder(grid: solidGrid)
        puzzle = PuzzleState(level: level, rules: data.rules.puzzle)
        inventory = run?.inventory ?? Inventory(items: data.items, rules: data.rules.inventory)
        session = LevelSession(level: level)
        guard let weapon = data.weapons[data.hero.startLoadout.weaponId] else {
            fatalError("hero.json startLoadout.weaponId \(data.hero.startLoadout.weaponId) not in weapons.json")
        }
        hero = HeroNode(def: data.hero, weapons: data.weapons, loadout: run?.loadout)
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
    convenience init(data: GameData, levelId: String, seed: UInt64, size: CGSize = GameScene.logicalSize,
                     run: RunState? = nil) {
        guard let def = data.levels[levelId] ?? data.levelOrder.first else { fatalError("levels.json has no levels") }
        self.init(data: data, level: def, seed: seed, size: size, run: run)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not supported") }

    private func buildWorld() {
        worldNode.name = "world"
        addChild(worldNode)
        worldNode.addChild(built.root)

        hero.position = level.grid.world(level.heroStart)
        worldNode.addChild(hero)
        pixel.snap(to: hero.position)
        pixel.zPosition = 30
        worldNode.addChild(pixel)
        pixelBrain.onBubble = { [weak self] line in
            self?.model?.bubble = line
            self?.pixel.setTalking(line != nil)
        }
        pixelBrain.onLineShown = { [weak self] _ in self?.audio?.playPixelBeep(index: nil) }
        lastZone = level.room(at: level.heroStart)?.zone ?? 1

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
        let node = PickupNode(item: item, from: p, to: p, darkFloor: darkFloor)
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
            pendingPixelTouch = nil
            hero.drive(direction: .zero, magnitude: 0, dt: 0)
        case .useQuick(let i):
            useItem(quickSlot: i, slot: nil)
        case .useItem(let slot):
            useItem(quickSlot: nil, slot: slot)
        case .dropItem(let slot, let count):
            dropItem(slot: slot, count: count)
        case .assignQuick(let itemId, let slot):
            inventory.assignQuick(itemId: itemId, to: slot)
        case .tidy:
            inventory.tidy()
        case .dismissBubble:
            pixelBrain.dismiss()
        case .debugSpawnCrowd:
            spawnCrowd()
        case .debugDamageHero:
            damageHero(Self.debugDamage)
        }
        pushHUD()
        pushBag()
    }

    // MARK: Item use and drop (GDD §6, §7)

    private func useItem(quickSlot: Int?, slot: Int?) {
        guard rescue == nil, !isComplete else { return }
        let now = useClock()
        let result: UseResult
        if let q = quickSlot {
            // Tapping an empty quick slot opens the bag (ART_BIBLE §14.1).
            guard inventory.quickItem(q) != nil else { model?.openInventory(); return }
            result = ItemUse.useQuick(q, inventory: &inventory, health: &hero.health, loadout: &hero.loadout,
                                      cooldowns: &useCooldowns, now: now)
        } else if let slot {
            result = ItemUse.useSlot(slot, inventory: &inventory, health: &hero.health, loadout: &hero.loadout,
                                     cooldowns: &useCooldowns, now: now)
        } else {
            return
        }
        switch result {
        case .used(let heal, let ammo):
            feedback(.used, quickSlot: quickSlot)
            audio?.play(ammo != nil ? .pickupAmmo : .pickupHeal)
            worldNode.addChild(Particles.stateOn(at: hero.position, color: heal > 0 ? Palette.heal : Palette.star, count: 8))
        case .alreadyFull:
            feedback(.refused, quickSlot: quickSlot)
            showToast("ui.toast.already_full")
        case .coolingDown, .notUsable, .none:
            break
        }
    }

    private func feedback(_ kind: UseFeedback.Kind, quickSlot: Int?) {
        feedbackCounter += 1
        model?.useFeedback = UseFeedback(id: feedbackCounter, quickSlot: quickSlot, kind: kind)
    }

    /// Drops at the hero's feet, up to `inventory.dropScatter` away (a wall spot → the hero centre).
    /// Dropped items never despawn; they wait until the hero has stepped away once.
    private func dropItem(slot: Int, count: Int) {
        guard rescue == nil, let stack = inventory.drop(slot: slot, count: count), let item = data.items[stack.itemId] else { return }
        let r = CGFloat(data.rules.inventory.dropScatter)
        let a = CGFloat(random.nextUniform()) * 2 * .pi, d = CGFloat(random.nextUniform()) * r
        var p = CGPoint(x: hero.position.x + cos(a) * d, y: hero.position.y + sin(a) * d)
        if solidGrid.isBlocked(p, radius: 8) { p = hero.position }
        let node = PickupNode(item: item, from: p, to: p, count: stack.count, darkFloor: darkFloor)
        node.waitsForHeroToLeave = true
        pickups.append(node)
        worldNode.addChild(node)
        showToast("ui.toast.dropped", arg: itemName(item.id), key: "ui.toast.dropped.\(item.id)")
    }

    /// The scene's bag for the inventory screen.
    private func pushBag() {
        guard let model, model.bag != inventory else { return }
        model.bag = inventory
    }

    // MARK: Touches (sticks live in the scene; HUD buttons swallow their touches first)

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if pan != nil {
            skipPan()
            return
        }
        guard rescue == nil, let view else { return }
        for t in touches {
            let vp = t.location(in: view)
            if pendingPixelTouch == nil, isPixelTap(viewPoint: vp, view: view) {
                pendingPixelTouch = PendingTouch(touch: t, viewPoint: vp, layerPoint: t.location(in: cameraNode),
                                                 viewSize: view.bounds.size, start: t.timestamp)
            } else {
                sticks.begin(t, viewPoint: vp, layerPoint: t.location(in: cameraNode), viewSize: view.bounds.size)
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let p = pendingPixelTouch, touches.contains(p.touch), let view {
            let vp = p.touch.location(in: view)
            if hypot(vp.x - p.viewPoint.x, vp.y - p.viewPoint.y) >= CGFloat(data.rules.pixel.tapMaxMovePt) {
                releasePendingTouchAsStick()
            }
        }
        sticks.touchesMoved(touches)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let p = pendingPixelTouch, touches.contains(p.touch) {
            pendingPixelTouch = nil
            if p.touch.timestamp - p.start <= data.rules.pixel.tapMaxSec { pixelTapped() }
        }
        sticks.touchesEnded(touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let p = pendingPixelTouch, touches.contains(p.touch) { pendingPixelTouch = nil }
        sticks.touchesEnded(touches)
    }

    /// GDD §13: a touch that starts within `pixel.tapRadius` of Pixel's on-screen centre.
    func isPixelTap(viewPoint: CGPoint, view: SKView) -> Bool {
        let p = convertPoint(toView: worldNode.convert(pixel.position, to: self))
        return hypot(viewPoint.x - p.x, viewPoint.y - p.y) <= CGFloat(data.rules.pixel.tapRadius)
    }

    /// The held-back touch was not a tap: it becomes a normal stick touch from its start point.
    private func releasePendingTouchAsStick() {
        guard let p = pendingPixelTouch else { return }
        pendingPixelTouch = nil
        sticks.begin(p.touch, viewPoint: p.viewPoint, layerPoint: p.layerPoint, viewSize: p.viewSize)
    }

    private func checkPendingTouchTimeout() {
        guard let p = pendingPixelTouch else { return }
        if ProcessInfo.processInfo.systemUptime - p.start > data.rules.pixel.tapMaxSec { releasePendingTouchAsStick() }
    }

    // MARK: Frame

    override func update(_ currentTime: TimeInterval) {
        // Pause menu, bag and intro card stop game time (the view may still tick while frozen).
        if model?.isGameFrozen == true {
            lastUpdateTime = nil
            return
        }
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
                model?.completeLevel(r, loadout: hero.loadout, inventory: inventory)
            }
        }
        guard !isComplete else { return }
        clock += dt
        pixelBrain.tick(realDt: dt)
        if rescue != nil {
            updateRescue(dt: dt)
            pushHUD()
            return
        }
        if pan != nil {
            updatePan(dt: dt)
            pixel.update(dt: dt, hero: hero.position)
            pushHUD()
            return
        }
        if !startedStory {
            startedStory = true
            pixelBrain.handle(.levelStart)
        }
        checkPendingTouchTimeout()
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
        updatePixel(dt: dt)
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
            if hero.magazine == 0 { pixelBrain.handle(.magazineEmpty) }
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
        worldNode.addChild(Particles.poof(at: origin, bodyColors: Self.poofColors(enemy.def.id), darkFloor: darkFloor))
        let drops = LootRoller.roll(tableId: enemy.def.lootTableId, data: data, context: lootContext, random: random)
        enemy.powerDown { [weak self, weak enemy] in
            guard let self, let enemy else { return }
            self.spawnLoot(drops, at: origin)
            enemy.removeFromParent()
            self.enemies.removeAll { $0 === enemy }
        }
    }

    /// Poof v2 chip colours per enemy family (ART_BIBLE §14.9): robots silver, slimes green, spores pink.
    static func poofColors(_ enemyId: String) -> [SKColor] {
        if enemyId.hasPrefix("slime") { return [Palette.hex(0x6FE06A), Palette.hex(0x8CF07F)] }
        if enemyId.hasPrefix("spore") { return [Palette.hex(0xE36BD8), Palette.hex(0xFFB3F2)] }
        return [Palette.robotMetal, Palette.robotMetalLight]
    }

    private func breakCrate(_ crate: CrateNode) {
        audio?.play(.crateBreak)
        worldNode.addChild(Particles.poof(at: crate.position, bodyColors: [Palette.star, Palette.robotMetalLight], darkFloor: darkFloor))
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
            p.updateMarker(heroDistance: d)
            if p.waitsForHeroToLeave {
                if d > pickupR { p.waitsForHeroToLeave = false }
                continue
            }
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

    /// Pickup effects through `PickupResolver` (GDD §5.1, §6, §7). Returns false when the pickup
    /// stays on the floor (bag full: "!" marker, toast and Pixel line once per refusal).
    private func apply(pickup p: PickupNode) -> Bool {
        let item = p.item
        let outcome = PickupResolver.resolve(item, count: p.count, inventory: &inventory, loadout: &hero.loadout)
        switch outcome {
        case .score(let points):
            if item.id == LootRoller.boltItemId {
                session.addBolts(p.count, scoreEach: item.scoreValue ?? 0)
            } else {
                session.addScore(points)
            }
        case .datachip:
            session.collectDatachip(p.placementId ?? "datachip_\(session.datachipsFound.count)", score: item.scoreValue ?? 0)
        case .stored:
            pixelBrain.progress()
            if item.category == .puzzle {
                showToast("ui.toast.got_item", arg: itemName(item.id), key: "ui.toast.got_item.\(item.id)")
            }
        case .reserve:
            break
        case .staysBagFull:
            if !p.isBlocked {
                p.setBlocked(true)
                showToast("ui.toast.bag_full")
                pixelBrain.handle(.bagFull)
            }
            return false
        case .weaponPlaceholder:
            collectedCounts[item.id, default: 0] += p.count
        }
        pixelBrain.handle(.pickup(itemId: item.id, stored: outcome == .stored))
        return true
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
            // GDD §13: Pixel's `need_*` line replaces the toast when the talk level lets it through.
            if pixelBrain.say(StoryDirector.Key.need(item), kind: .hint) == .filtered {
                showToast("ui.toast.need_item", arg: itemName(item), key: "ui.toast.need_item.\(item)")
            }
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

    /// After an element changed: door counters, Pixel, then doors that just became satisfied.
    private func elementChanged(_ id: String) {
        refreshDoorCounters(pop: id)
        if puzzle.isOn(id) {
            pixelBrain.progress()
            if hint?.elementId == id { endHint() }
            let required = level.exitDoor.elementIds.contains(id) || puzzle.elements[id]?.gateId != nil
            if required {
                let p = puzzle.requiredProgress
                let lastOfExit = level.exitDoor.elementIds.contains(id) && p.on == p.total
                pixelBrain.handle(lastOfExit ? .allElementsOn : .elementOn)
            }
        }
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
        pixelBrain.progress()
        if door === built.exitDoor {
            built.exitPad.setOn(true)
            pixelBrain.handle(.doorOpen)
        } else {
            // GDD §13: `pixel.generic.gate_open` replaces the toast.
            pixelBrain.handle(.gateOpen)
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
                // GDD §13: `pixel.generic.checkpoint` replaces the toast. Mid-level save (§16.10).
                pixelBrain.handle(.checkpoint)
                pixelBrain.progress()
                model?.checkpointReached(loadout: hero.loadout, inventory: inventory)
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
                                 datachipsTotal: levelDef.pickups.datachips, isLast: data.level(after: levelDef.id) == nil,
                                 rescues: session.rescues)
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
                beginRescue()
            }
            return
        }
    }

    /// Where a rescue puts the hero: the last touched checkpoint.
    var respawnPoint: CGPoint {
        if let id = session.lastCheckpointId, let node = built.checkpoints[id] { return node.position }
        return level.grid.world(level.heroStart)
    }

    /// GDD §12 steps 3–7 at once (`RescueRules`): hero at the last checkpoint with full HP and
    /// invulnerability, starter topped up, living enemies healed and sent home, `rescues + 1`.
    /// Bag, quick slots, other ammo, datachips and puzzle state stay as they are. The beam sequence
    /// (`beginRescue`) calls this at the teleport moment.
    func rescueHero() {
        audio?.play(.rescue)
        worldNode.addChild(Particles.teleport(at: hero.position))
        hero.clearKnockback()
        guard let starter = data.weapons[data.hero.startLoadout.weaponId] else { return }
        let outcome = RescueRules.apply(
            health: &hero.health, loadout: &hero.loadout, session: &session,
            enemies: enemies.map { RescueEnemy(id: ObjectIdentifier($0).debugDescription, isPoweredDown: $0.isPoweredDown) },
            starter: starter, rules: data.rules.rescue, invulnerableSec: data.hero.effectiveRespawnInvulnerableSec)
        hero.position = respawnPoint
        hero.animator.reset()
        let reset = Set(outcome.enemiesToReset)
        for e in enemies where reset.contains(ObjectIdentifier(e).debugDescription) {
            e.health = Health(max: e.def.hp)
            if !(e.brain.currentState is ReturnHomeState) { e.brain.enter(ReturnHomeState.self) }
        }
        worldNode.addChild(Particles.teleport(at: hero.position))
        pixel.snap(to: hero.position)
        cameraController.snap(to: hero.position, visibleSize: visibleSize)
    }

    /// Starts the rescue sequence (ART_BIBLE §14.7): slow-mo, Pixel's beam up, teleport, beam down.
    /// Input is off until the hero stands at the checkpoint; never a "game over".
    func beginRescue() {
        guard rescue == nil, !isComplete else { return }
        sticks.reset()
        pendingPixelTouch = nil
        hero.clearKnockback()
        hero.drive(direction: .zero, magnitude: 0, dt: 0)
        pixel.setRescue(true)
        endHint()
        var r = RescueRun()
        let tint = SKSpriteNode(color: Palette.pixelLight, size: CGSize(width: 4000, height: 4000))
        tint.name = "rescue_tint"
        tint.alpha = 0
        tint.zPosition = 900
        cameraNode.addChild(tint)
        r.tint = tint
        rescue = r
    }

    private func updateRescue(dt: Double) {
        guard var r = rescue else { return }
        let rules = data.rules.rescue
        r.t += dt
        let world = dt * RescueRules.timeScale(at: r.t, rules: rules)
        // The world keeps running (slowed); the hero takes no input and no damage.
        for e in enemies { e.tick(dt: world) }
        updateProjectiles(dt: world)
        hero.drive(direction: .zero, magnitude: 0, dt: world)
        hero.animator.update(dt: world)
        let half = rules.beamSec / 2
        let beamStart = rules.slowMoSec
        if r.t < beamStart {
            r.tint?.alpha = CGFloat(min(0.18, r.t / 0.3 * 0.18))
        } else if !r.teleported {
            if r.beamOut == nil {
                let b = Self.beam()
                b.position = hero.position
                worldNode.addChild(b)
                r.beamOut = b
            }
            let k = min(1, (r.t - beamStart) / half)
            hero.alpha = CGFloat(1 - k)
            hero.setScale(CGFloat(1 - 0.8 * k))
            if r.t >= beamStart + half {
                r.teleported = true
                r.beamOut?.run(.sequence([.fadeOut(withDuration: 0.15), .removeFromParent()]))
                r.beamOut = nil
                rescueHero()
                let b = Self.beam()
                b.position = hero.position
                worldNode.addChild(b)
                r.beamIn = b
            }
        } else {
            let k = min(1, (r.t - beamStart - half) / half)
            hero.alpha = CGFloat(k)
            hero.setScale(CGFloat(0.2 + 0.8 * k))
            r.tint?.alpha = CGFloat(0.18 * (1 - k))
        }
        pixel.update(dt: dt, hero: hero.position)
        cameraController.update(dt: dt, target: hero.position, aim: nil, visibleSize: visibleSize)
        rescue = r
        if r.t >= RescueRules.duration(rules) { endRescue() }
    }

    private func endRescue() {
        guard let r = rescue else { return }
        r.beamOut?.removeFromParent()
        r.beamIn?.run(.sequence([.fadeOut(withDuration: 0.15), .removeFromParent()]))
        r.tint?.removeFromParent()
        if !r.teleported { rescueHero() }
        rescue = nil
        hero.alpha = 1
        hero.setScale(1)
        pixel.setRescue(false)
        pixelBrain.handle(.rescue)
        wasLowHp = false
    }

    /// Pixel's teleport column (ART_BIBLE §14.7): white core, cyan layers, ground ring.
    static func beam() -> SKNode {
        let n = SKNode()
        n.name = "rescue_beam"
        n.zPosition = 45
        // ART_BIBLE §14.7: from 20 pt below the feet to 220 pt above; outer cyan 96, inner 50, core 24.
        let footY: CGFloat = -40, height: CGFloat = 240 + 20
        let layers: [(CGFloat, SKColor, CGFloat)] = [(96, Palette.pixelCyan, 0.55), (50, Palette.pixelLight, 0.8), (24, .white, 0.95)]
        for (i, (w, c, a)) in layers.enumerated() {
            let col = SKSpriteNode(texture: Textures.beamGradient, size: CGSize(width: w, height: height))
            col.anchorPoint = CGPoint(x: 0.5, y: 0)
            col.position = CGPoint(x: 0, y: footY - 20)
            col.color = c
            col.colorBlendFactor = 1
            col.alpha = a
            col.blendMode = .add
            col.xScale = 0.05
            // Width 0 → full in 0.2 s, then a slight pulse (±8 %, layers out of phase).
            let pulse = SKAction.sequence([.scaleX(to: 1.08, duration: 0.18 + 0.03 * Double(i)),
                                           .scaleX(to: 0.94, duration: 0.18 + 0.03 * Double(i))])
            col.run(.sequence([.scaleX(to: 1, duration: 0.2), .repeatForever(pulse)]))
            n.addChild(col)
        }
        let ring = SKSpriteNode(texture: Textures.radialGlow, size: CGSize(width: 88, height: 32))
        ring.position = CGPoint(x: 0, y: footY)
        ring.color = Palette.pixelCyan
        ring.colorBlendFactor = 1
        ring.alpha = 0.8
        ring.blendMode = .add
        ring.setScale(0.6)
        ring.run(.scale(to: 1, duration: 0.2))
        n.addChild(ring)
        // Rising sparkles along the column for as long as the beam lives.
        let rise = SKEmitterNode()
        rise.particleTexture = Textures.particleDot
        rise.particleBirthRate = 36
        rise.particleLifetime = 0.5
        rise.particlePositionRange = CGVector(dx: 50, dy: 30)
        rise.position = CGPoint(x: 0, y: footY + 10)
        rise.emissionAngle = .pi / 2
        rise.emissionAngleRange = 0.2
        rise.particleSpeed = 170
        rise.particleSpeedRange = 100
        rise.particleScale = 0.6
        rise.particleScaleSpeed = -1.1
        rise.particleAlphaSpeed = -1.6
        rise.particleColor = Palette.pixelLight
        rise.particleColorBlendFactor = 1
        rise.particleColorSequence = SKKeyframeSequence(keyframeValues: [Palette.pixelLight, SKColor.white, Palette.pixelCyan],
                                                        times: [0, 0.5, 1])
        rise.particleBlendMode = .add
        rise.zPosition = 1
        n.addChild(rise)
        n.addChild(Particles.group(at: CGPoint(x: 0, y: footY + 40), [
            Particles.Burst(texture: Textures.particleStar, color: Palette.star, count: 4, lifetime: 0.5, speed: 80...160,
                            size: 9, angle: .pi / 2, angleRange: 0.6),
        ]))
        return n
    }

    // MARK: Pixel (GDD §13)

    /// Sight checks for "first seen" run at this rate (presentation cadence, not balance).
    static let sightHz = 6.0
    /// The arrow ends when the hero gets this close to the target (ART_BIBLE §14.6).
    static let hintReachedDistance: CGFloat = 128
    /// The bag glow for a hint whose item is in the bag (ART_BIBLE §14.6).
    static let bagHintSec = 4.0

    private func updatePixel(dt: Double) {
        pixel.update(dt: dt, hero: hero.position)
        if var h = hint {
            h.remaining -= dt
            arrow?.update(dt: dt, hero: hero.position)
            let reached = hypot(h.target.x - hero.position.x, h.target.y - hero.position.y) <= Self.hintReachedDistance
            let pickedUp = h.floorId.map { id in !pickups.contains { floorId($0) == id } } ?? false
            hint = h
            if h.remaining <= 0 || reached || pickedUp { endHint() }
        }
        if pixelBrain.tickIdle(gameDt: dt) { runHint(.idle) }

        // Low HP (GDD §4): line + heart pulse on the way down.
        let low = hero.health.current > 0 && hero.health.current <= data.rules.lowHp.threshold
        if low, !wasLowHp { pixelBrain.handle(.lowHp) }
        wasLowHp = low

        // New zone.
        if let room = level.room(at: level.grid.cell(at: hero.position)), room.zone != lastZone {
            if room.zone > lastZone { pixelBrain.handle(.zoneEntered(room.zone)) }
            lastZone = room.zone
        }

        // Minimap pointer pings after `hints.pointerAfterSec` (recomputed twice a second).
        pointerTimer -= dt
        if pointerTimer <= 0, session.elapsed >= data.rules.hints.pointerAfterSec {
            pointerTimer = 0.5
            let p = HintPlanner.pings(afterSec: session.elapsed, rules: data.rules.hints, level: level, puzzle: puzzle,
                                      heroAt: hero.position)
            pointerPings = p.elementIds
            pointerExit = p.exitPad
        }

        sightTimer -= dt
        if sightTimer <= 0 {
            sightTimer = 1 / Self.sightHz
            checkSights()
        }
    }

    /// First sight of enemy types, element types and gates: on screen and in line of sight.
    private func checkSights() {
        let vis = visibleSize
        let rect = CGRect(x: cameraNode.position.x - vis.width / 2, y: cameraNode.position.y - vis.height / 2,
                          width: vis.width, height: vis.height)
        let h = hero.position
        for e in enemies where !e.isPoweredDown && !sightedEnemyTypes.contains(e.def.id) {
            guard StoryDirector.isSighted(e.position, from: h, visibleRect: rect, grid: solidGrid) else { continue }
            sightedEnemyTypes.insert(e.def.id)
            if pixelBrain.handle(.enemySeen(e.def.id)) != nil { pixel.scan(toward: e.position) }
        }
        for el in level.elements where !sightedElements.contains(el.type.rawValue) {
            guard rect.contains(el.position), solidGrid.hasLineOfSight(from: h, to: closestFloor(to: el)) else { continue }
            sightedElements.insert(el.type.rawValue)
            pixelBrain.handle(.elementSeen(el.type))
        }
        if !sightedGate {
            for g in level.gates where !puzzle.isGateOpen(g.id) {
                guard let d = built.gates[g.id], rect.contains(d.position) else { continue }
                sightedGate = true
                pixelBrain.handle(.gateSeen)
                break
            }
        }
    }

    /// A floor cell next to an element (elements block their own cells for line of sight).
    private func closestFloor(to e: PlacedElement) -> CGPoint {
        let h = level.grid.cell(at: hero.position)
        let cands = e.cells.flatMap { [$0] + $0.neighbors4 }.filter { solidGrid.isWalkable($0) }
        let best = cands.min { $0.distance(h) < $1.distance(h) }
        return best.map { level.grid.world($0) } ?? e.position
    }

    private func floorId(_ p: PickupNode) -> String {
        p.placementId ?? "drop_\(ObjectIdentifier(p).hashValue)"
    }

    /// Pickups on the floor for `HintPlanner`.
    var floorItems: [FloorItem] {
        pickups.filter { !$0.isCollected }.map { FloorItem(id: floorId($0), itemId: $0.item.id, position: $0.groundPosition) }
    }

    /// Tap on Pixel (GDD §13): nothing while a hint runs, `hint_wait` during the cooldown.
    func pixelTapped() {
        guard rescue == nil, pan == nil else { return }
        if pixelBrain.isHintRunning { return }
        if !pixelBrain.canHint {
            pixelBrain.say(StoryDirector.Key.hintWait, kind: .hint)
            return
        }
        runHint(.tap)
    }

    /// Plans and shows a hint: fly + dotted arrow + minimap ping, or a line only.
    func runHint(_ trigger: HintTrigger) {
        let plan = HintPlanner.plan(level: level, puzzle: puzzle, heroAt: hero.position, carrier: inventory,
                                    floorItems: floorItems, trigger: trigger)
        if let key = plan.lineKey { pixelBrain.say(key, kind: .hint) }
        guard let target = plan.flyTo else {
            if case .none = plan.target { pixelBrain.progress() } else { pixelBrain.beginLineOnlyHint() }
            return
        }
        pixelBrain.beginHint()
        pixel.flyTo(target)
        pixel.scan(toward: target)
        arrow?.removeFromParent()
        let a = HintArrowNode(target: target, lifetime: data.rules.hints.arrowSec)
        worldNode.addChild(a)
        arrow = a
        var elementId: String?, floorId: String?
        switch plan.target {
        case .element(let id): elementId = id
            if let item = level.element(id)?.requiresItem, inventory.count(of: item) > 0 { bagHintUntil = clock + Self.bagHintSec }
        case .item(let f, _, _): floorId = f
        default: break
        }
        hint = ActiveHint(target: target, elementId: elementId, floorId: floorId,
                          remaining: data.rules.hints.flySec + data.rules.hints.arrowSec)
        pushMinimap(force: true)
    }

    private func endHint() {
        guard hint != nil || arrow != nil else { return }
        hint = nil
        if let a = arrow {
            arrow = nil
            a.run(.sequence([.fadeOut(withDuration: 0.3), .removeFromParent()]))
        }
        pixel.returnToHero()
        pixelBrain.endHint()
        pushMinimap(force: true)
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
        let p0 = built.exitPad.position
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
        // Pings (ART_BIBLE §14.6): the running hint's target plus the pointer pings.
        var pings: [MinimapMark] = pointerPings.compactMap { id in
            level.element(id).map { MinimapMark(x: $0.center.x, y: $0.center.y, on: false) }
        }
        if pointerExit { pings.append(MinimapMark(x: Double(p0.x / TileGrid.tileSize), y: Double(p0.y / TileGrid.tileSize), on: true)) }
        if let h = hint {
            pings.append(MinimapMark(x: Double(h.target.x / TileGrid.tileSize), y: Double(h.target.y / TileGrid.tileSize), on: false))
        }
        s.pings = pings
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
            interact: interact, carried: inventory.totals(in: .puzzle),
            quickSlots: quickSlotStates,
            lowHp: hero.health.current > 0 && hero.health.current <= data.rules.lowHp.threshold,
            bagFull: inventory.freeSlots == 0,
            bagHint: clock < bagHintUntil)
    }

    /// Q1…Q4: linked id, total count, cooldown sweep, and whether a use would be refused.
    var quickSlotStates: [QuickSlotState] {
        let now = useClock()
        let cd = max(0.01, useCooldowns.cooldownSec)
        return (0..<inventory.quickCount).map { i in
            guard let id = inventory.quickItem(i) else { return QuickSlotState() }
            let left = useCooldowns.remaining(id, now: now) / cd
            return QuickSlotState(itemId: id, count: inventory.count(of: id), cooldown: (left * 10).rounded(.up) / 10,
                                  usable: wouldAccept(id))
        }
    }

    /// False when using `itemId` now would be `alreadyFull` (HP full, reserve full).
    func wouldAccept(_ itemId: String) -> Bool {
        guard let d = data.items[itemId] else { return false }
        switch d.category {
        case .heal, .food: return hero.health.current < hero.health.max
        case .ammo: return d.ammoId.map { !hero.loadout.ammo.isFull($0) } ?? false
        default: return false
        }
    }

    private func pushHUD() {
        guard let model else { return }
        pushBag()
        let s = hudState
        guard s != lastHUD else { return }
        lastHUD = s
        model.hud = s
    }

    // MARK: Debug (DEBUG overlay only)

    /// `debug.damageHero` amount (QA tool, not balance).
    static let debugDamage = 30
    /// `debug.spawnCrowd`: 12 boltbots + 2 crates in the hero's room (M3-5 performance check).
    static let crowdEnemies = 12
    static let crowdCrates = 2

    func damageHero(_ amount: Int) {
        guard rescue == nil else { return }
        // Ignores the invulnerability window (debug): rebuild Health at the target HP.
        let target = max(0, hero.health.current - max(0, amount))
        hero.health = Health(max: hero.health.max, invulnerableSec: hero.health.invulnerableSec)
        if target < hero.health.max { _ = hero.health.applyDamage(hero.health.max - target) }
        pushHUD()
        if hero.health.isDepleted { beginRescue() }
    }

    func spawnCrowd() {
        let cell = level.grid.cell(at: hero.position)
        let room = level.room(at: cell)?.rect ?? RoomRect(x: cell.x - 3, y: cell.y - 3, width: 7, height: 7)
        var free: [GridPoint] = []
        for y in room.y..<room.maxY { for x in room.x..<room.maxX {
            let c = GridPoint(x, y)
            if solidGrid.isWalkable(c), c.chebyshev(cell) >= 2 { free.append(c) }
        } }
        guard !free.isEmpty, let bot = data.enemies["boltbot"] else { return }
        for i in 0..<Self.crowdEnemies {
            let c = free[random.nextInt(upperBound: free.count)]
            let e = EnemyNode(def: bot, at: level.grid.world(c), world: self, homeRoomId: level.room(at: c)?.id,
                              leash: data.rules.leash)
            e.name = "enemy_crowd_\(i)"
            enemies.append(e)
            worldNode.addChild(e)
        }
        for i in 0..<Self.crowdCrates {
            let c = free[random.nextInt(upperBound: free.count)]
            let crate = CrateNode(crate: CratePlacement(id: "crowd_crate_\(i)", cell: c, roomId: level.room(at: c)?.id ?? 0,
                                                        lootTableId: levelDef.pickups.crates.lootTableId),
                                  grid: level.grid, hp: data.rules.crate.hp)
            extraCrates.append(crate)
            built.root.addChild(crate)
        }
    }
}
