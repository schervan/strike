import SpriteKit

/// Pixel in the running scene (GDD §13): follow, hints (fly + dotted arrow + minimap ping),
/// first-sight story cues, low-HP and zone lines, minimap pointer pings. The decisions live in
/// `PixelController`, `HintPlanner` and `StoryDirector`; this class feeds them from the scene.
/// Split out of `GameScene` in M4-3 with no behaviour change.
@MainActor
final class PixelDirector {
    unowned let scene: GameScene

    /// The hint that is running (arrow, minimap ping).
    private struct ActiveHint {
        let target: CGPoint
        let elementId: String?
        let floorId: String?
        var remaining: Double
    }

    private var hint: ActiveHint?
    private(set) var arrow: HintArrowNode?
    /// ART_BIBLE §14.6: edge chevron for an off-screen target, ring on the target.
    private(set) var chevron: SKNode?
    private(set) var targetRing: SKNode?
    private(set) var bagHintUntil: Double = 0
    private(set) var pointerPings: [String] = []
    private(set) var pointerExit = false
    var wasLowHp = false
    private var startedStory = false
    private var sightTimer: Double = 0
    private var sightedEnemyTypes = Set<String>()
    private var sightedElements = Set<String>()
    private var sightedGate = false
    private var lastZone = 1
    private var pointerTimer: Double = 0

    /// Sight checks for "first seen" run at this rate (presentation cadence, not balance).
    static let sightHz = 6.0
    /// The arrow ends when the hero gets this close to the target (ART_BIBLE §14.6).
    static let hintReachedDistance: CGFloat = 128
    /// The bag glow for a hint whose item is in the bag (ART_BIBLE §14.6).
    static let bagHintSec = 4.0

    init(scene: GameScene) {
        self.scene = scene
    }

    /// Target of the running hint (minimap ping).
    var hintTarget: CGPoint? { hint?.target }

    /// Level start: bubble wiring and the start zone.
    func setUp() {
        let pixel = scene.pixel
        pixel.snap(to: scene.hero.position)
        pixel.zPosition = 30
        scene.worldNode.addChild(pixel)
        scene.pixelBrain.onBubble = { [weak scene] line in
            scene?.model?.bubble = line
            scene?.pixel.setTalking(line != nil)
        }
        scene.pixelBrain.onLineShown = { [weak scene] _ in scene?.audio?.playPixelBeep(index: nil) }
        lastZone = scene.level.room(at: scene.level.heroStart)?.zone ?? 1
    }

    /// The `start` story beat, once, on the first live step.
    func startStoryIfNeeded() {
        guard !startedStory else { return }
        startedStory = true
        // The arena continues L5: its story starts with the boss intro (`bossPhase:1`).
        if !scene.isArena { scene.pixelBrain.handle(.levelStart) }
    }

    private var saidSlow = false

    /// The first spore slow of the level: Pixel's line (chatter, once).
    func heroSlowed() {
        guard !saidSlow else { return }
        saidSlow = true
        scene.pixelBrain.say(StoryDirector.Key.slow, kind: .chatter)
    }

    /// An element turned on: a hint that pointed at it ends.
    func elementTurnedOn(_ id: String) {
        if hint?.elementId == id { endHint() }
    }

    func update(dt: Double) {
        let hero = scene.hero, level = scene.level, data = scene.data, brain = scene.pixelBrain
        scene.pixel.update(dt: dt, hero: hero.position)
        if var h = hint {
            h.remaining -= dt
            arrow?.update(dt: dt, hero: hero.position)
            updateChevron(target: h.target)
            let reached = hypot(h.target.x - hero.position.x, h.target.y - hero.position.y) <= Self.hintReachedDistance
            let pickedUp = h.floorId.map { id in !scene.pickups.contains { floorId($0) == id } } ?? false
            hint = h
            if h.remaining <= 0 || reached || pickedUp { endHint() }
        }
        if brain.tickIdle(gameDt: dt) { runHint(.idle) }

        // Low HP (GDD §4): line + heart pulse on the way down.
        let low = hero.health.current > 0 && hero.health.current <= data.rules.lowHp.threshold
        if low, !wasLowHp { brain.handle(.lowHp) }
        wasLowHp = low

        // New zone.
        if let room = level.room(at: level.grid.cell(at: hero.position)), room.zone != lastZone {
            if room.zone > lastZone { brain.handle(.zoneEntered(room.zone)) }
            lastZone = room.zone
        }

        // Minimap pointer pings after `hints.pointerAfterSec` (recomputed twice a second).
        pointerTimer -= dt
        if pointerTimer <= 0, scene.session.elapsed >= data.rules.hints.pointerAfterSec {
            pointerTimer = 0.5
            let p = HintPlanner.pings(afterSec: scene.session.elapsed, rules: data.rules.hints, level: level,
                                      puzzle: scene.puzzle, heroAt: hero.position)
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
        let vis = scene.visibleSize
        let cam = scene.cameraNode.position
        let rect = CGRect(x: cam.x - vis.width / 2, y: cam.y - vis.height / 2, width: vis.width, height: vis.height)
        let h = scene.hero.position
        let grid = scene.solidGrid, brain = scene.pixelBrain
        for e in scene.enemies where !e.isPoweredDown && !sightedEnemyTypes.contains(e.def.id) {
            guard StoryDirector.isSighted(e.position, from: h, visibleRect: rect, grid: grid) else { continue }
            sightedEnemyTypes.insert(e.def.id)
            if brain.handle(.enemySeen(e.def.id)) != nil { scene.pixel.scan(toward: e.position) }
        }
        for el in scene.level.elements where !sightedElements.contains(el.type.rawValue) {
            guard rect.contains(el.position), grid.hasLineOfSight(from: h, to: closestFloor(to: el)) else { continue }
            sightedElements.insert(el.type.rawValue)
            brain.handle(.elementSeen(el.type))
        }
        if !sightedGate {
            for g in scene.level.gates where !scene.puzzle.isGateOpen(g.id) {
                guard let d = scene.built.gates[g.id], rect.contains(d.position) else { continue }
                sightedGate = true
                brain.handle(.gateSeen)
                break
            }
        }
    }

    /// A floor cell next to an element (elements block their own cells for line of sight).
    private func closestFloor(to e: PlacedElement) -> CGPoint {
        let level = scene.level, grid = scene.solidGrid
        let h = level.grid.cell(at: scene.hero.position)
        let cands = e.cells.flatMap { [$0] + $0.neighbors4 }.filter { grid.isWalkable($0) }
        let best = cands.min { $0.distance(h) < $1.distance(h) }
        return best.map { level.grid.world($0) } ?? e.position
    }

    private func floorId(_ p: PickupNode) -> String {
        p.placementId ?? "drop_\(ObjectIdentifier(p).hashValue)"
    }

    /// Pickups on the floor for `HintPlanner`.
    var floorItems: [FloorItem] {
        scene.pickups.filter { !$0.isCollected }.map { FloorItem(id: floorId($0), itemId: $0.item.id, position: $0.groundPosition) }
    }

    /// Tap on Pixel (GDD §13): nothing while a hint runs, `hint_wait` during the cooldown.
    func pixelTapped() {
        guard scene.rescue == nil, !scene.interaction.isPanning else { return }
        let brain = scene.pixelBrain
        if brain.isHintRunning { return }
        if !brain.canHint {
            brain.say(StoryDirector.Key.hintWait, kind: .hint)
            return
        }
        runHint(.tap)
    }

    /// Plans and shows a hint: fly + dotted arrow + minimap ping, or a line only.
    func runHint(_ trigger: HintTrigger) {
        let level = scene.level, brain = scene.pixelBrain, data = scene.data
        let plan = HintPlanner.plan(level: level, puzzle: scene.puzzle, heroAt: scene.hero.position, carrier: scene.inventory,
                                    floorItems: floorItems, trigger: trigger)
        if let key = plan.lineKey { brain.say(key, kind: .hint) }
        guard let target = plan.flyTo else {
            if case .none = plan.target { brain.progress() } else { brain.beginLineOnlyHint() }
            return
        }
        brain.beginHint()
        scene.pixel.flyTo(target)
        scene.pixel.scan(toward: target)
        arrow?.removeFromParent()
        let a = HintArrowNode(target: target, lifetime: data.rules.hints.arrowSec)
        scene.worldNode.addChild(a)
        arrow = a
        var elementId: String?, floorId: String?
        switch plan.target {
        case .element(let id): elementId = id
            if let item = level.element(id)?.requiresItem, scene.inventory.count(of: item) > 0 {
                bagHintUntil = scene.clock + Self.bagHintSec
            }
        case .item(let f, _, _): floorId = f
        default: break
        }
        hint = ActiveHint(target: target, elementId: elementId, floorId: floorId,
                          remaining: data.rules.hints.flySec + data.rules.hints.arrowSec)
        targetRing?.removeFromParent()
        let ring = SKShapeNode(circleOfRadius: 24)
        ring.strokeColor = Palette.star
        ring.lineWidth = 3
        ring.name = "hint_ring"
        ring.position = target
        ring.zPosition = 39
        ring.run(.repeatForever(.sequence([.scale(to: 1.2, duration: 0.4), .scale(to: 1.0, duration: 0.4)])))
        scene.worldNode.addChild(ring)
        targetRing = ring
        updateChevron(target: target)
        scene.hud.pushMinimap(force: true)
    }

    /// Off-screen target: a 40 pt chevron plate clamped to the screen edge (inset 24 pt), pointing
    /// at it and bobbing; it never sits in the bottom 160 pt (joystick corners).
    private func updateChevron(target: CGPoint) {
        let vis = scene.visibleSize, cam = scene.cameraNode.position
        let rel = CGPoint(x: target.x - cam.x, y: target.y - cam.y)
        let hw = vis.width / 2 - 24 - 20, hh = vis.height / 2 - 24 - 20
        let onScreen = abs(rel.x) <= vis.width / 2 - 24 && abs(rel.y) <= vis.height / 2 - 24
        guard !onScreen else { chevron?.removeFromParent(); chevron = nil; return }
        if chevron == nil {
            let n = SKNode()
            n.name = "hint_chevron"
            n.zPosition = 860
            let inner = SKNode()
            n.addChild(inner)
            let plate = SKShapeNode(circleOfRadius: 20)
            plate.fillColor = Palette.star
            plate.strokeColor = Palette.outline
            plate.lineWidth = 2
            inner.addChild(plate)
            let p = CGMutablePath()
            p.move(to: CGPoint(x: -6, y: 9)); p.addLine(to: CGPoint(x: 6, y: 0)); p.addLine(to: CGPoint(x: -6, y: -9))
            let arrowHead = SKShapeNode(path: p)
            arrowHead.strokeColor = Palette.outline
            arrowHead.lineWidth = 4
            arrowHead.lineCap = .round
            arrowHead.lineJoin = .round
            arrowHead.name = "head"
            inner.addChild(arrowHead)
            inner.run(.repeatForever(.sequence([.moveBy(x: 0, y: 4, duration: 0.4), .moveBy(x: 0, y: -4, duration: 0.4)])))
            scene.cameraNode.addChild(n)
            chevron = n
        }
        let k = min(hw / max(0.001, abs(rel.x)), hh / max(0.001, abs(rel.y)))
        var p = CGPoint(x: rel.x * k, y: rel.y * k)
        p.y = max(p.y, -vis.height / 2 + 160 + 20)
        chevron?.position = p
        chevron?.childNode(withName: "//head")?.zRotation = atan2(rel.y, rel.x)
    }

    func endHint() {
        guard hint != nil || arrow != nil else { return }
        hint = nil
        chevron?.removeFromParent()
        chevron = nil
        targetRing?.run(.sequence([.fadeOut(withDuration: 0.3), .removeFromParent()]))
        targetRing = nil
        if let a = arrow {
            arrow = nil
            a.run(.sequence([.fadeOut(withDuration: 0.3), .removeFromParent()]))
        }
        scene.pixel.returnToHero()
        scene.pixelBrain.endHint()
        scene.hud.pushMinimap(force: true)
    }
}
