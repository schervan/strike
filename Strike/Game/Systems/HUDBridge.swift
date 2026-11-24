import SpriteKit

/// Everything the scene pushes into `GameModel` for SwiftUI: HUD snapshot, bag, minimap
/// (fog-of-war reveal included), toasts and quick-slot feedback. Values are only pushed when
/// they changed. Split out of `GameScene` in M4-3 with no behaviour change.
@MainActor
final class HUDBridge {
    unowned let scene: GameScene

    private var lastHUD: HUDState?
    private var lastMinimap: MinimapSnapshot?
    private var minimapTimer: Double = 0
    private var revealedCorridor = Set<GridPoint>()
    private var corridorCells = Set<GridPoint>()
    private var lastHeroCell = GridPoint(-1, -1)
    private var toastLastShown: [String: Double] = [:]
    private var toastCounter = 0
    private var toastClearTask: Task<Void, Never>?
    private var feedbackCounter = 0

    /// ART_BIBLE §13.1: corridor cells within this Chebyshev distance of the hero get revealed.
    static let corridorRevealCells = 3

    init(scene: GameScene) {
        self.scene = scene
    }

    /// Level start: corridor cells for the fog of war (and everything revealed when the rules say so).
    func setUp() {
        for c in scene.level.corridors { corridorCells.formUnion(c.cells) }
        if !scene.data.rules.minimap.revealOnEnter { revealAll() }
    }

    /// A model was attached: push everything once.
    func attach() {
        lastHUD = nil
        pushHUD()
        pushBag()
        pushMinimap(force: true)
        scene.model?.bubble = scene.pixelBrain.currentLine
    }

    // MARK: HUD

    var hudState: HUDState {
        let hero = scene.hero
        let w = hero.weapon
        var interact: InteractPrompt?
        if let id = scene.interaction.focusedId, let node = scene.built.interactables[id] {
            interact = InteractPrompt(elementId: id, kind: node.type.rawValue, usable: scene.interaction.isUsable(id))
        }
        return HUDState(
            hp: hero.health.current, maxHp: hero.health.max,
            magazine: hero.magazine, reserve: hero.reserve, magazineSize: w.def.magazineSize,
            isReloading: w.isReloading,
            reloadProgress: (w.reloadProgress * 20).rounded(.down) / 20,
            canReload: hero.canReload, score: scene.session.score, weaponId: w.def.id,
            interact: interact, carried: scene.inventory.totals(in: .puzzle),
            quickSlots: quickSlotStates,
            lowHp: hero.health.current > 0 && hero.health.current <= scene.data.rules.lowHp.threshold,
            bagFull: scene.inventory.freeSlots == 0,
            bagHint: scene.clock < scene.pixelDirector.bagHintUntil,
            weapons: weaponSlots, isSwapping: hero.weapon.isSwapping, slowed: hero.status.isSlowed,
            boss: scene.bossDirector?.barState)
    }

    /// Wheel / SWAP slots in GDD order: owned, equipped, magazine and reserve.
    var weaponSlots: [WeaponSlotState] {
        let l = scene.hero.loadout
        return scene.weaponOrder.compactMap { id in
            guard let w = scene.data.weapons[id] else { return nil }
            return WeaponSlotState(id: id, nameKey: w.nameKey, owned: l.owns(id), equipped: l.equipped == id,
                                   magazine: l.magazine(id), reserve: l.reserve(for: w))
        }
    }

    /// Q1…Q4: linked id, total count, cooldown sweep, and whether a use would be refused.
    var quickSlotStates: [QuickSlotState] {
        let now = scene.useClock()
        let inventory = scene.inventory
        let cooldowns = scene.interaction.useCooldowns
        let cd = max(0.01, cooldowns.cooldownSec)
        return (0..<inventory.quickCount).map { i in
            guard let id = inventory.quickItem(i) else { return QuickSlotState() }
            let left = cooldowns.remaining(id, now: now) / cd
            return QuickSlotState(itemId: id, count: inventory.count(of: id), cooldown: (left * 10).rounded(.up) / 10,
                                  usable: wouldAccept(id))
        }
    }

    /// False when using `itemId` now would be `alreadyFull` (HP full, reserve full).
    func wouldAccept(_ itemId: String) -> Bool {
        guard let d = scene.data.items[itemId] else { return false }
        let hero = scene.hero
        switch d.category {
        case .heal, .food: return hero.health.current < hero.health.max
        case .ammo: return d.ammoId.map { !hero.loadout.ammo.isFull($0) } ?? false
        default: return false
        }
    }

    func pushHUD() {
        guard let model = scene.model else { return }
        pushBag()
        let s = hudState
        guard s != lastHUD else { return }
        lastHUD = s
        model.hud = s
    }

    /// The scene's bag for the inventory screen.
    func pushBag() {
        guard let model = scene.model, model.bag != scene.inventory else { return }
        model.bag = scene.inventory
    }

    func feedback(_ kind: UseFeedback.Kind, quickSlot: Int?) {
        feedbackCounter += 1
        scene.model?.useFeedback = UseFeedback(id: feedbackCounter, quickSlot: quickSlot, kind: kind)
    }

    // MARK: Toasts

    /// Shows `ui.toast.*` (optionally formatted with `arg`); the same `key` is not repeated within
    /// `rules.toast.repeatCooldownSec`.
    func showToast(_ stringKey: String, arg: String? = nil, key: String? = nil) {
        let k = key ?? stringKey
        let rules = scene.data.rules.toast
        let clock = scene.clock
        if let last = toastLastShown[k], clock - last < rules.repeatCooldownSec { return }
        toastLastShown[k] = clock
        let format = String(localized: String.LocalizationValue(stringKey))
        let text = arg.map { String(format: format, $0) } ?? format
        toastCounter += 1
        let id = toastCounter
        scene.model?.toast = ToastMessage(id: id, text: text)
        toastClearTask?.cancel()
        toastClearTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(rules.showSec))
            guard !Task.isCancelled, let model = self?.scene.model, model.toast?.id == id else { return }
            model.toast = nil
        }
    }

    func itemName(_ itemId: String) -> String {
        guard let key = scene.data.items[itemId]?.nameKey else { return itemId }
        return String(localized: String.LocalizationValue(key))
    }

    // MARK: Minimap

    /// Called every step: pushes the minimap at `rules.minimap.updateHz`.
    func tickMinimap(dt: Double) {
        minimapTimer -= dt
        if minimapTimer <= 0 {
            minimapTimer = 1 / max(1, scene.data.rules.minimap.updateHz)
            pushMinimap(force: false)
        }
    }

    func updateReveal() {
        let level = scene.level
        let cell = level.grid.cell(at: scene.hero.position)
        guard cell != lastHeroCell else { return }
        lastHeroCell = cell
        if let room = level.room(at: cell), scene.session.reveal(room: room.id) { pushMinimap(force: true) }
        let r = Self.corridorRevealCells
        for dy in -r...r {
            for dx in -r...r {
                let c = GridPoint(cell.x + dx, cell.y + dy)
                if corridorCells.contains(c) { revealedCorridor.insert(c) }
            }
        }
    }

    func revealAll() {
        for r in scene.level.rooms { scene.session.reveal(room: r.id) }
        revealedCorridor = corridorCells
    }

    var minimapSnapshot: MinimapSnapshot {
        let level = scene.level, built = scene.built, puzzle = scene.puzzle
        let revealed = scene.session.revealedRoomIds
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
        s.heroX = Double(scene.hero.position.x / TileGrid.tileSize)
        s.heroY = Double(scene.hero.position.y / TileGrid.tileSize)
        // Pings (ART_BIBLE §14.6): the running hint's target plus the pointer pings.
        let px = scene.pixelDirector
        var pings: [MinimapMark] = px.pointerPings.compactMap { id in
            level.element(id).map { MinimapMark(x: $0.center.x, y: $0.center.y, on: false) }
        }
        if px.pointerExit { pings.append(MinimapMark(x: Double(p0.x / TileGrid.tileSize), y: Double(p0.y / TileGrid.tileSize), on: true)) }
        if let target = px.hintTarget {
            pings.append(MinimapMark(x: Double(target.x / TileGrid.tileSize), y: Double(target.y / TileGrid.tileSize), on: false))
        }
        s.pings = pings
        return s
    }

    func pushMinimap(force: Bool) {
        guard let model = scene.model else { return }
        let s = minimapSnapshot
        guard force || s != lastMinimap else { return }
        lastMinimap = s
        model.minimap = s
    }
}
