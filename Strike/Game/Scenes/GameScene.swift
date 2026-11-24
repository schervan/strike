import GameplayKit
import SpriteKit
import UIKit

/// Main gameplay scene: one generated level (`levels.json` + seed) with the hero, enemies, loot,
/// puzzle elements, doors, checkpoints and the exit pad. All numbers come from `GameData`.
///
/// The scene owns the scene graph, the shared level state, input and the update order. The work
/// is done by its controllers (M4-3): `CombatController` (shots, hits, contact damage),
/// `EnemyDirector` (enemies, `EnemyWorld`), `InteractionController` (pickups, items, puzzle,
/// doors, checkpoints, exit), `RescueController` (0 HP), `PixelDirector` (hints, story cues)
/// and `HUDBridge` (HUD, bag, minimap, toasts).
@MainActor
final class GameScene: SKScene, @preconcurrency SKPhysicsContactDelegate {
    /// Logical scene size (iPad landscape points); `.aspectFill` scales to the device.
    static let logicalSize = CGSize(width: 1194, height: 834)
    /// GDD §5: projectile pool size for the hero.
    static let projectileCapacity = 64
    /// Enemy shots alive at once (laser balls, spores, boss stars).
    static let enemyShotCapacity = 48

    weak var model: GameModel? {
        didSet {
            model?.commandHandler = { [weak self] command in self?.handle(command) }
            model?.carriedProvider = { [weak self] in
                guard let self else { return (Loadout(start: StartLoadoutDef(weaponId: "", magazine: 0, reserve: 0), weapons: [:]),
                                              Inventory(items: [:], slotCount: 0, quickCount: 0)) }
                return (self.hero.loadout, self.inventory)
            }
            hud.attach()
        }
    }

    // MARK: Shared level state (read and written by the controllers)

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
    let enemyShots = EnemyShotPool(capacity: GameScene.enemyShotCapacity)
    /// Generated level or the fixed boss arena (DECISIONS 2026-11-24).
    let stage: LevelStage
    let arena: BossArenaLayout.Arena?
    var isArena: Bool { arena != nil }
    /// SWAP / wheel order (GDD §5).
    let weaponOrder: [String]
    private var ownedAtStart = 1
    private var swapShown = false
    var puzzle: PuzzleState
    /// The hero's bag (carried over from `RunState`).
    var inventory: Inventory
    var session: LevelSession
    let random: GKRandom
    var aimAssistEnabled: Bool
    let pixel: PixelNode
    let pixelBrain: PixelController
    /// L4/L5 dark floors (halo strength, poof contrast ring; ART_BIBLE §13.8 / §14.9).
    let darkFloor: Bool
    /// Clock for item-use cooldowns (real time, so uses inside the paused inventory work).
    var useClock: () -> Double = { CACurrentMediaTime() }
    /// Sound effects and jingles (tests swap in a recorder).
    var audio: AudioSink? = AudioManager.shared
    /// Game time since the level started (toasts, bag hint).
    private(set) var clock: Double = 0
    /// Last aim direction (stick, or the move direction while not aiming).
    private(set) var aimAngle: CGFloat = 0
    let lightHaptic = UIImpactFeedbackGenerator(style: .light)
    let mediumHaptic = UIImpactFeedbackGenerator(style: .medium)
    private(set) var sticks: TwinStickController!
    private var cameraController: CameraController!

    // MARK: Controllers

    private(set) lazy var hud = HUDBridge(scene: self)
    private(set) lazy var enemyDirector = EnemyDirector(scene: self)
    private(set) lazy var combat = CombatController(scene: self)
    private(set) lazy var interaction = InteractionController(scene: self, useCooldownSec: data.rules.inventory.useCooldownSec)
    private(set) lazy var rescueController = RescueController(scene: self)
    private(set) lazy var pixelDirector = PixelDirector(scene: self)
    /// Only on the arena stage.
    private(set) var bossDirector: BossDirector?

    // MARK: Input

    /// A touch near Pixel, held back up to `pixel.tapMaxSec` (GDD §13 tap rule).
    private struct PendingTouch {
        let touch: UITouch
        let viewPoint: CGPoint
        let layerPoint: CGPoint
        let viewSize: CGSize
        let start: TimeInterval
    }
    private var pendingPixelTouch: PendingTouch?
    private var lastUpdateTime: TimeInterval?
    private var playedLevelStart = false
    #if DEBUG
    private var statsFrames = 0
    private var statsTime = 0.0
    #endif

    /// Ignores aim-stick noise when the finger rests on the base.
    private static let aimEpsilon: CGFloat = 0.05
    private static let maxStep = 1.0 / 30

    // MARK: Setup

    /// `run`: the carried loadout, bag and settings (nil = a fresh run, tests).
    init(data: GameData, level def: LevelDef, seed: UInt64, size: CGSize = GameScene.logicalSize, run: RunState? = nil,
         stage: LevelStage = .level) {
        self.data = data
        self.levelDef = def
        self.random = GKMersenneTwisterRandomSource(seed: seed)
        self.aimAssistEnabled = run?.settings.aimAssist ?? data.controls.aimAssistDefaultOn
        darkFloor = def.index >= 4
        pixel = PixelNode(rules: data.rules.pixel, hints: data.rules.hints)
        pixelBrain = PixelController(level: def, rules: data.rules, talk: run?.settings.pixelTalk ?? .lots)
        let bossDef = def.bossId.flatMap { data.enemies[$0] }
        let core = bossDef?.phases?.compactMap(\.unlockBy).first?.requiresItem
        arena = stage == .bossArena ? core.flatMap { BossArenaLayout.build(def, coreItemId: $0) } : nil
        self.stage = arena == nil ? .level : .bossArena
        level = arena?.level ?? LevelGenerator.generate(def, seed: seed, data: data)
        weaponOrder = Loadout.order(data.weapons)
        built = LevelBuilder.build(level, def: def, data: data)
        solidGrid = level.gridAllDoorsClosed
        pathfinder = Pathfinder(grid: solidGrid)
        puzzle = PuzzleState(level: level, rules: data.rules.puzzle)
        inventory = run?.inventory ?? Inventory(items: data.items, rules: data.rules.inventory)
        session = LevelSession(level: level)
        if arena != nil, let carry = run?.arena { session.resume(carry) }
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
                     run: RunState? = nil, stage: LevelStage = .level) {
        guard let def = data.levels[levelId] ?? data.levelOrder.first else { fatalError("levels.json has no levels") }
        self.init(data: data, level: def, seed: seed, size: size, run: run, stage: stage)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not supported") }

    private func buildWorld() {
        worldNode.name = "world"
        addChild(worldNode)
        worldNode.addChild(built.root)

        hero.position = level.grid.world(level.heroStart)
        worldNode.addChild(hero)
        pixelDirector.setUp()
        enemyDirector.spawnInitial()
        interaction.spawnInitial()
        hud.setUp()
        if let start = level.checkpoints.first { built.checkpoints[start.id]?.setOn(true, animated: false) }
        built.exitDoor.hidesCounter = arena != nil
        interaction.refreshDoorCounters(pop: nil)

        cameraNode.name = "camera"
        addChild(cameraNode)
        camera = cameraNode
        cameraController = CameraController(camera: cameraNode, def: data.camera, bounds: level.grid.bounds,
                                            hudBand: CGFloat(data.controls.hudBandHeight))
        cameraController.snap(to: hero.position, visibleSize: visibleSize)
        sticks = TwinStickController(controls: data.controls, layer: cameraNode)
        hud.updateReveal()
        ownedAtStart = hero.loadout.owned.count
        swapShown = ownedAtStart >= 2
        if let arena, let id = levelDef.bossId, let def = data.enemies[id], let boss = BossDirector(scene: self, arena: arena, def: def) {
            bossDirector = boss
            boss.start()
        }
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

    // MARK: Shared helpers for the controllers

    /// A door opened: its cells become floor for walking, line of sight and paths.
    func openCells(_ cells: [GridPoint]) {
        for c in cells { solidGrid[c] = .floor }
        pathfinder.setCells(cells, walkable: true)
    }

    /// Current HUD-avoidance offset of the camera (QA-015; tests).
    var cameraNudge: CGVector { cameraController.appliedNudge }

    func snapCamera() {
        cameraController.snap(to: hero.position, visibleSize: visibleSize)
    }

    func updateCamera(dt: Double, aim: CGVector?) {
        cameraController.update(dt: dt, target: hero.position, aim: aim, visibleSize: visibleSize)
    }

    func clampedCameraTarget(_ p: CGPoint) -> CGPoint {
        cameraController.clamped(p, visibleSize: visibleSize)
    }

    /// Drops every stick and a held-back Pixel touch.
    func resetTouches() {
        sticks.reset()
        pendingPixelTouch = nil
    }

    // MARK: Controller state (read by tests and the HUD)

    var enemies: [EnemyNode] { enemyDirector.enemies }
    var boss: BossDirector? { bossDirector }
    var extraCrates: [CrateNode] { enemyDirector.extraCrates }
    var pickups: [PickupNode] { interaction.pickups }
    var focusedId: String? { interaction.focusedId }
    var isComplete: Bool { interaction.isComplete }
    var collectedCounts: [String: Int] { interaction.collectedCounts }
    var rescue: RescueController.Run? { rescueController.run }
    var respawnPoint: CGPoint { rescueController.respawnPoint }
    var arrow: HintArrowNode? { pixelDirector.arrow }
    var floorItems: [FloorItem] { pixelDirector.floorItems }
    var hudState: HUDState { hud.hudState }
    var minimapSnapshot: MinimapSnapshot { hud.minimapSnapshot }
    var lootContext: LootContext { combat.lootContext }
    func spawnLoot(_ drops: [LootDrop], at origin: CGPoint) { combat.spawnLoot(drops, at: origin) }
    func rescueHero() { rescueController.rescueHero() }
    func beginRescue() { rescueController.begin() }
    func damageHero(_ amount: Int) { combat.damageHero(amount) }
    func spawnCrowd() { enemyDirector.spawnCrowd() }
    func pixelTapped() { pixelDirector.pixelTapped() }
    func runHint(_ trigger: HintTrigger) { pixelDirector.runHint(trigger) }
    func showToast(_ stringKey: String, arg: String? = nil, key: String? = nil) { hud.showToast(stringKey, arg: arg, key: key) }
    static func pickupSound(_ item: ItemDef) -> AudioEvent { InteractionController.pickupSound(item) }
    static func poofColors(_ enemyId: String) -> [SKColor] { CombatController.poofColors(enemyId) }
    static func beam() -> SKNode { RescueController.beam() }
    static var crowdEnemies: Int { EnemyDirector.crowdEnemies }
    static var crowdCrates: Int { EnemyDirector.crowdCrates }
    /// `debug.damageHero` amount (QA tool, not balance).
    static let debugDamage = 30

    /// QA-012: Pixel's swap line once, when SWAP first becomes visible in this level.
    private func checkSwapVisible() {
        guard !swapShown, hero.loadout.owned.count >= 2 else { return }
        swapShown = true
        pixelBrain.handle(.swapVisible)
    }

    // MARK: Touches (sticks live in the scene; HUD buttons swallow their touches first)

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if interaction.isPanning {
            interaction.skipPan()
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
            if p.touch.timestamp - p.start <= data.rules.pixel.tapMaxSec { pixelDirector.pixelTapped() }
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

    // MARK: Physics contacts (shots)

    func didBegin(_ contact: SKPhysicsContact) {
        combat.didBegin(contact)
    }

    override func didSimulatePhysics() {
        combat.resolveHits()
    }

    // MARK: Frame

    override func update(_ currentTime: TimeInterval) {
        // Pause menu, bag and intro card stop game time (the view may still tick while frozen).
        if model?.isGameFrozen == true {
            lastUpdateTime = nil
            return
        }
        let raw = lastUpdateTime.map { max(0, currentTime - $0) } ?? 0
        var dt = min(Self.maxStep, raw)
        lastUpdateTime = currentTime
        #if DEBUG
        statsFrames += 1
        statsTime += raw
        if statsTime >= 0.5 {
            func count(_ n: SKNode) -> Int { 1 + n.children.reduce(0) { $0 + count($1) } }
            model?.debugStats = "fps \(Int((Double(statsFrames) / statsTime).rounded())) · nodes \(count(self))"
            statsFrames = 0
            statsTime = 0
        }
        #endif
        // ART_BIBLE §15.7: the weapon wheel slows game time.
        if model?.isWheelOpen == true { dt *= data.rules.weapons.wheelTimeScale ?? 1 }
        step(dt: dt)
    }

    /// One simulation step (separate from `update` so tests can drive it). This is the update order.
    func step(dt: Double) {
        interaction.tickCompletion(dt: dt)
        guard !isComplete else { return }
        clock += dt
        pixelBrain.tick(realDt: dt)
        if rescue != nil {
            rescueController.update(dt: dt)
            hud.pushHUD()
            return
        }
        if interaction.isPanning {
            interaction.updatePan(dt: dt)
            pixel.update(dt: dt, hero: hero.position)
            hud.pushHUD()
            return
        }
        pixelDirector.startStoryIfNeeded()
        checkPendingTouchTimeout()
        session.tick(dt: dt)
        puzzle.tick(dt: dt)
        updateHero(dt: dt)
        enemyDirector.tick(dt: dt)
        bossDirector?.tick(dt: dt)
        combat.updateProjectiles(dt: dt)
        combat.updateEnemyShots(dt: dt)
        combat.checkContactDamage()
        interaction.updatePickups(dt: dt)
        interaction.updatePlates(dt: dt)
        interaction.updateFocus()
        interaction.updateCheckpoints()
        interaction.updateDoorsInfo()
        interaction.updateExit(dt: dt)
        checkSwapVisible()
        hud.updateReveal()
        pixelDirector.update(dt: dt)
        cameraController.nudge = hudNudge()
        updateCamera(dt: dt, aim: isAiming ? CGVector(dx: cos(aimAngle), dy: sin(aimAngle)) : nil)
        depthSort()
        hud.pushHUD()
        hud.tickMinimap(dt: dt)
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
        combat.updateTrigger(fireHeld: sticks.fireHeld)
    }

    /// QA-015: the focused interactable is shifted out from under the right-column HUD buttons.
    private func hudNudge() -> CGVector {
        guard let id = interaction.focusedId, let node = built.interactables[id] else { return .zero }
        let vis = visibleSize
        let cam = cameraController.basePosition
        let rel = CGPoint(x: node.position.x - cam.x, y: node.position.y - cam.y)
        let r: CGFloat = node.type == .machine ? 64 : 32
        let object = CGRect(x: rel.x - r, y: rel.y - r, width: 2 * r, height: 2 * r)
        return HUDAvoidance.nudge(object: object, buttons: HUDAvoidance.rightColumn(visibleSize: vis),
                                  maxShift: HUDAvoidance.maxShift)
    }

    /// Draw order: lower on screen = in front.
    private func depthSort() {
        let bounds = level.grid.bounds
        let h = max(1, bounds.height)
        func z(_ y: CGFloat) -> CGFloat { 10 + (bounds.maxY - y) / h }
        hero.zPosition = z(hero.position.y)
        enemyDirector.depthSort(z)
    }
}
