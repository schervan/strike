import SpriteKit
import UIKit

/// What the hero touches and uses in the running scene: floor pickups (`PickupResolver`), item
/// use and drop, interactable focus and INTERACT, pressure plates, door counters, the door pan,
/// checkpoints and the exit pad (level complete). Split out of `GameScene` in M4-3 with no
/// behaviour change.
@MainActor
final class InteractionController {
    unowned let scene: GameScene

    private(set) var pickups: [PickupNode] = []
    private(set) var focusedId: String?
    private(set) var isComplete = false
    /// Blaster pickups collected this level.
    private(set) var collectedCounts: [String: Int] = [:]
    private(set) var useCooldowns: UseCooldowns

    // Door pan (GDD §11: 1.0 s to the door, input locked, tap skips).
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
        let level = scene.level
        let door = level.exitDoor.cells
        func dist(_ c: GridPoint) -> Int { door.map { $0.chebyshev(c) }.min() ?? 0 }
        let far = level.exitDoor.niche.map(dist).max() ?? 0
        return Set(level.exitDoor.niche.filter { dist($0) == far } + [level.exitPad])
    }()

    /// Door pan: camera rests on the opening door this long before control returns.
    static let panHoldSec = 0.6

    init(scene: GameScene, useCooldownSec: Double) {
        self.scene = scene
        useCooldowns = UseCooldowns(cooldownSec: useCooldownSec)
    }

    var isPanning: Bool { pan != nil }

    // MARK: Pickups (GDD §5.1, §6, §7)

    /// Level start: generated floor pickups and item placements.
    func spawnInitial() {
        let level = scene.level, data = scene.data
        for p in level.pickups {
            guard let item = data.items[p.itemId] else { continue }
            addPlacedPickup(item, at: level.grid.world(p.cell), placementId: p.id)
        }
        for i in level.itemPlacements {
            guard let item = data.items[i.itemId] else { continue }
            addPlacedPickup(item, at: level.grid.world(i.cell), placementId: i.id)
        }
    }

    private func addPlacedPickup(_ item: ItemDef, at p: CGPoint, placementId: String?) {
        let node = PickupNode(item: item, from: p, to: p, darkFloor: scene.darkFloor)
        node.placementId = placementId
        addPickup(node)
    }

    func addPickup(_ node: PickupNode) {
        pickups.append(node)
        scene.worldNode.addChild(node)
    }

    func updatePickups(dt: Double) {
        let data = scene.data
        let h = scene.hero.position
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
            scene.audio?.play(Self.pickupSound(p.item))
            scene.worldNode.addChild(Particles.collect(at: p.position))
            p.collect()
            pickups.removeAll { $0 === p }
        }
    }

    /// Pickup effects through `PickupResolver`. Returns false when the pickup stays on the floor
    /// (bag full: "!" marker, toast and Pixel line once per refusal).
    private func apply(pickup p: PickupNode) -> Bool {
        let item = p.item
        let session = scene.session
        let outcome = PickupResolver.resolve(item, count: p.count, inventory: &scene.inventory, loadout: &scene.hero.loadout,
                                             weapons: scene.data.weapons)
        switch outcome {
        case .score(let points):
            if item.id == LootRoller.boltItemId {
                scene.session.addBolts(p.count, scoreEach: item.scoreValue ?? 0)
            } else {
                scene.session.addScore(points)
            }
        case .datachip:
            scene.session.collectDatachip(p.placementId ?? "datachip_\(session.datachipsFound.count)", score: item.scoreValue ?? 0)
        case .stored:
            scene.pixelBrain.progress()
            if item.category == .puzzle {
                scene.hud.showToast("ui.toast.got_item", arg: scene.hud.itemName(item.id), key: "ui.toast.got_item.\(item.id)")
            }
        case .reserve:
            break
        case .staysBagFull:
            if !p.isBlocked {
                p.setBlocked(true)
                scene.hud.showToast("ui.toast.bag_full")
                scene.pixelBrain.handle(.bagFull)
            }
            return false
        case .weapon:
            // The blaster is owned now; SWAP, the wheel and Pixel's line arrive in M4-5.
            collectedCounts[item.id, default: 0] += p.count
        }
        scene.pixelBrain.handle(.pickup(itemId: item.id, stored: outcome == .stored))
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

    // MARK: Item use and drop (GDD §6, §7)

    func useItem(quickSlot: Int?, slot: Int?) {
        guard scene.rescue == nil, !isComplete else { return }
        let hero = scene.hero, hud = scene.hud
        let now = scene.useClock()
        let result: UseResult
        if let q = quickSlot {
            // Tapping an empty quick slot opens the bag (ART_BIBLE §14.1).
            guard scene.inventory.quickItem(q) != nil else { scene.model?.openInventory(); return }
            result = ItemUse.useQuick(q, inventory: &scene.inventory, health: &hero.health, loadout: &hero.loadout,
                                      cooldowns: &useCooldowns, now: now)
        } else if let slot {
            result = ItemUse.useSlot(slot, inventory: &scene.inventory, health: &hero.health, loadout: &hero.loadout,
                                     cooldowns: &useCooldowns, now: now)
        } else {
            return
        }
        switch result {
        case .used(let heal, let ammo):
            hud.feedback(.used, quickSlot: quickSlot)
            scene.audio?.play(ammo != nil ? .pickupAmmo : .pickupHeal)
            scene.worldNode.addChild(Particles.stateOn(at: hero.position, color: heal > 0 ? Palette.heal : Palette.star, count: 8))
        case .alreadyFull:
            hud.feedback(.refused, quickSlot: quickSlot)
            hud.showToast("ui.toast.already_full")
        case .coolingDown, .notUsable, .none:
            break
        }
    }

    /// Drops at the hero's feet, up to `inventory.dropScatter` away (a wall spot → the hero centre).
    /// Dropped items never despawn; they wait until the hero has stepped away once.
    func dropItem(slot: Int, count: Int) {
        guard scene.rescue == nil, let stack = scene.inventory.drop(slot: slot, count: count),
              let item = scene.data.items[stack.itemId] else { return }
        let hero = scene.hero, random = scene.random
        let r = CGFloat(scene.data.rules.inventory.dropScatter)
        let a = CGFloat(random.nextUniform()) * 2 * .pi, d = CGFloat(random.nextUniform()) * r
        var p = CGPoint(x: hero.position.x + cos(a) * d, y: hero.position.y + sin(a) * d)
        if scene.solidGrid.isBlocked(p, radius: 8) { p = hero.position }
        let node = PickupNode(item: item, from: p, to: p, count: stack.count, darkFloor: scene.darkFloor)
        node.waitsForHeroToLeave = true
        addPickup(node)
        scene.hud.showToast("ui.toast.dropped", arg: scene.hud.itemName(item.id), key: "ui.toast.dropped.\(item.id)")
    }

    // MARK: Puzzle

    private var interactRadius: CGFloat {
        CGFloat(scene.data.rules.puzzle.interactFocusRadius ?? scene.data.hero.interactRadius)
    }

    /// GDD §11 M2 notes: the nearest interactable within range gets focus (plates are stood on).
    func updateFocus() {
        let built = scene.built
        var best: (id: String, d: CGFloat)?
        for (id, node) in built.interactables where node.type != .pressureplate {
            let d = node.interactDistance(from: scene.hero.position)
            guard d <= interactRadius else { continue }
            if best == nil || d < best!.d || (d == best!.d && id < best!.id) { best = (id, d) }
        }
        let newId = best?.id
        if newId != focusedId, let old = focusedId { built.interactables[old]?.setFocus(.none) }
        focusedId = newId
        if let id = newId, let node = built.interactables[id] { node.setFocus(isUsable(id) ? .usable : .unusable) }
    }

    func isUsable(_ id: String) -> Bool {
        guard let e = scene.puzzle.elements[id] else { return false }
        switch e.type {
        case .button: return !e.isOn
        case .lever: return e.pullRemaining <= 0
        case .machine: return !e.isOn && (e.requiresItem.map { scene.inventory.count(of: $0) > 0 } ?? true)
        case .pressureplate: return false
        }
    }

    func interact() {
        guard pan == nil, let id = focusedId, let node = scene.built.interactables[id] else { return }
        let result = scene.puzzle.interact(id, carrier: &scene.inventory)
        switch result {
        case .activated:
            scene.lightHaptic.impactOccurred()
            scene.audio?.play(node.type == .machine ? .machineOn : .buttonPress)
            node.setOn(true, animated: true)
            elementChanged(id)
        case .toggled:
            scene.lightHaptic.impactOccurred()
            scene.audio?.play(.leverPull)
            (node as? LeverNode)?.playPull(to: scene.puzzle.isOn(id), duration: scene.data.rules.puzzle.leverPullSec)
            elementChanged(id)
        case .needsItem(let item):
            (node as? MachineNode)?.showNeedsItem()
            // GDD §13: Pixel's `need_*` line replaces the toast when the talk level lets it through.
            if scene.pixelBrain.say(StoryDirector.Key.need(item), kind: .hint) == .filtered {
                scene.hud.showToast("ui.toast.need_item", arg: scene.hud.itemName(item), key: "ui.toast.need_item.\(item)")
            }
        case .alreadyOn, .notReady:
            break
        }
    }

    func updatePlates(dt: Double) {
        let level = scene.level
        let heroCell = level.grid.cell(at: scene.hero.position)
        for e in level.elements where e.type == .pressureplate {
            guard let node = scene.built.interactables[e.id] as? PressurePlateNode else { continue }
            let held = e.cells.contains(heroCell)
            if scene.puzzle.updatePlate(e.id, occupied: held, dt: dt) == .activated {
                scene.audio?.play(.plateOn)
                node.setOn(true, animated: true)
                elementChanged(e.id)
            } else {
                node.setProgress(scene.puzzle.plateProgress(e.id), held: held)
            }
        }
    }

    /// After an element changed: door counters, Pixel, then doors that just became satisfied.
    private func elementChanged(_ id: String) {
        let level = scene.level, built = scene.built, puzzle = scene.puzzle
        refreshDoorCounters(pop: id)
        if puzzle.isOn(id) {
            scene.pixelBrain.progress()
            scene.pixelDirector.elementTurnedOn(id)
            let required = level.exitDoor.elementIds.contains(id) || puzzle.elements[id]?.gateId != nil
            if required {
                let p = puzzle.requiredProgress
                let lastOfExit = level.exitDoor.elementIds.contains(id) && p.on == p.total
                scene.pixelBrain.handle(lastOfExit ? .allElementsOn : .elementOn)
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

    func refreshDoorCounters(pop: String?) {
        let level = scene.level, built = scene.built, puzzle = scene.puzzle
        for g in level.gates {
            let p = puzzle.gateProgress(g.id)
            built.gates[g.id]?.setProgress(on: p.on, total: p.total, pop: pop.map { g.elementIds.contains($0) } ?? false)
        }
        let p = puzzle.requiredProgress
        built.exitDoor.setProgress(on: p.on, total: p.total, pop: pop.map { level.exitDoor.elementIds.contains($0) } ?? false)
    }

    func updateDoorsInfo() {
        let h = scene.hero.position
        for d in scene.built.gates.values { d.updateInfo(heroDistance: hypot(d.position.x - h.x, d.position.y - h.y)) }
        let e = scene.built.exitDoor
        e.updateInfo(heroDistance: hypot(e.position.x - h.x, e.position.y - h.y))
    }

    // MARK: Door pan

    private func startNextPan() {
        guard pan == nil, !panQueue.isEmpty else { return }
        let door = panQueue.removeFirst()
        scene.physicsWorld.speed = 0
        scene.hero.drive(direction: .zero, magnitude: 0, dt: 0)
        scene.sticks.reset()
        pan = DoorPan(door: door, from: scene.cameraNode.position, to: scene.clampedCameraTarget(door.position))
    }

    func updatePan(dt: Double) {
        guard var p = pan else { return }
        let dur = max(0.01, scene.data.rules.puzzle.doorPanSec)
        p.t += dt
        let k = CGFloat(min(1, p.t / dur))
        let e = k * k * (3 - 2 * k)
        scene.cameraNode.position = CGPoint(x: p.from.x + (p.to.x - p.from.x) * e, y: p.from.y + (p.to.y - p.from.y) * e)
        if !p.opened, p.t >= dur {
            p.opened = true
            openDoor(p.door, animated: true)
        }
        pan = p
        if p.t >= dur + Self.panHoldSec { endPan() }
    }

    func skipPan() {
        guard let p = pan else { return }
        if !p.opened { openDoor(p.door, animated: true) }
        endPan()
    }

    private func endPan() {
        pan = nil
        scene.physicsWorld.speed = 1
        // Control returns when the queue is empty; the follow camera eases back to the hero.
        if !panQueue.isEmpty { startNextPan() }
    }

    private func openDoor(_ door: DoorNode, animated: Bool) {
        guard !door.isOpen else { return }
        let built = scene.built
        door.open(animated: animated)
        scene.openCells(door.cells)
        scene.enemyDirector.clearPaths()
        scene.audio?.play(door === built.exitDoor ? .doorOpen : .gateUnlocked)
        scene.pixelBrain.progress()
        if door === built.exitDoor {
            built.exitPad.setOn(true)
            scene.pixelBrain.handle(.doorOpen)
        } else {
            // GDD §13: `pixel.generic.gate_open` replaces the toast.
            scene.pixelBrain.handle(.gateOpen)
        }
        scene.hud.pushMinimap(force: true)
    }

    /// Debug "turn all on": every element on, every door open at once (no pan).
    func solveAll() {
        let built = scene.built
        scene.puzzle.forceAllOn()
        for (id, node) in built.interactables { node.setOn(scene.puzzle.isOn(id), animated: false) }
        refreshDoorCounters(pop: nil)
        panQueue.removeAll()
        if pan != nil { endPan() }
        for d in built.gates.values { openDoor(d, animated: false) }
        openDoor(built.exitDoor, animated: false)
    }

    // MARK: Checkpoints, exit

    func updateCheckpoints() {
        let h = scene.hero.position
        for c in scene.level.checkpoints {
            guard let node = scene.built.checkpoints[c.id],
                  hypot(node.position.x - h.x, node.position.y - h.y) <= CheckpointNode.triggerRadius
            else { continue }
            if scene.session.touchCheckpoint(c.id) {
                node.setOn(true, animated: true)
                scene.audio?.play(.checkpoint)
                // GDD §13: `pixel.generic.checkpoint` replaces the toast. Mid-level save (§16.10).
                scene.pixelBrain.handle(.checkpoint)
                scene.pixelBrain.progress()
                scene.model?.checkpointReached(loadout: scene.hero.loadout, inventory: scene.inventory)
                scene.hud.pushMinimap(force: true)
            }
        }
    }

    func updateExit(dt: Double) {
        let pad = scene.built.exitPad, h = scene.hero.position
        let onPad = hypot(pad.position.x - h.x, pad.position.y - h.y) <= ExitPadNode.triggerRadius
            || exitPadCells.contains(scene.level.grid.cell(at: h))
        guard scene.puzzle.isExitOpen, scene.built.exitDoor.isOpen, onPad else { exitStand = 0; return }
        exitStand += dt
        guard exitStand >= ExitPadNode.standSec else { return }
        completeLevel()
    }

    private func completeLevel() {
        guard !isComplete else { return }
        let data = scene.data, def = scene.levelDef
        isComplete = true
        scene.session.complete()
        scene.built.exitPad.playReached()
        scene.audio?.playJingle(data.level(after: def.id) == nil ? MusicID.seasonComplete : MusicID.levelComplete)
        scene.hero.drive(direction: .zero, magnitude: 0, dt: 0)
        let session = scene.session
        let result = LevelResult(levelId: def.id, nameKey: def.nameKey, timeSec: Int(session.elapsed.rounded()),
                                 score: session.score, datachips: session.datachipsFound.count,
                                 datachipsTotal: def.pickups.datachips, isLast: data.level(after: def.id) == nil,
                                 rescues: session.rescues)
        // Driven by `step` (not an SKAction) so headless tests reach the card too.
        pendingResult = result
        completionDelay = ExitPadNode.flashSec
    }

    /// Counts the exit flash down and hands the result to the model.
    func tickCompletion(dt: Double) {
        guard var t = completionDelay else { return }
        t -= dt
        completionDelay = t
        if t <= 0, let r = pendingResult {
            completionDelay = nil
            pendingResult = nil
            scene.model?.completeLevel(r, loadout: scene.hero.loadout, inventory: scene.inventory)
        }
    }
}
