import SpriteKit

/// The boss fight in the arena stage (GDD §9, ART_BIBLE §15.1/§15.8–§15.12). `BossBrain` decides
/// (phases, attack schedule, spawns, core guarantee, dizzy); this class feeds it time, hits, core
/// inserts and the core census, runs the attacks it starts (telegraph → hit test with
/// `BossAttacks`), spawns its boltbots, moves the boss and plays the defeat sparkle burst.
@MainActor
final class BossDirector {
    unowned let scene: GameScene
    let arena: BossArenaLayout.Arena
    let node: MegaMechNode
    private(set) var brain: BossBrain
    let coreItemId: String

    /// A running attack (from its telegraph start).
    private struct Running {
        let attack: BossAttackDef
        var t: Double = 0
        let origin: CGPoint
        var angles: [CGFloat] = []
        var startAngle: CGFloat = 0
        var dash: BossDash.Path?
        var impacted = false
        var fired = false
        var fx: SKNode
    }

    private var running: Running?
    private var spawns: [Int: EnemyNode] = [:]
    private(set) var coresInFlight = 0
    /// Phase change pause (§15.11): no attacks, invulnerable, enemy shots cleared.
    private var phaseLock = 0.0
    private(set) var defeatT: Double?
    private var defeatStep = 0
    private var lootDropped = false
    private let fixedRespawn: [String: Bool]
    private var sockets: [String: SKNode] = [:]
    private var saidShield = false
    private var coreNeededAt = -Double.infinity

    /// `pixel.boss.core_needed` repeats at most this often (ART_BIBLE §15.10).
    static let coreNeededCooldownSec = 20.0

    /// Phase change pause (ART_BIBLE §15.11). Feel timing, not balance.
    static let phaseLockSec = 0.8
    /// The defeat sequence before the Season complete card (§15.12).
    static let defeatSec = 3.4
    /// The boss keeps this far from the hero while walking (it never stands on the kid).
    static let walkStopDistance: CGFloat = 150

    init?(scene: GameScene, arena: BossArenaLayout.Arena, def: EnemyDef) {
        guard let brain = BossBrain(def: def) else { return nil }
        self.scene = scene
        self.arena = arena
        self.brain = brain
        coreItemId = def.phases?.compactMap(\.unlockBy).first?.requiresItem ?? arena.level.elements.first?.requiresItem ?? ""
        node = MegaMechNode(def: def, at: arena.bossSpawnPosition, world: scene.enemyDirector, leash: scene.data.rules.leash)
        var respawn: [String: Bool] = [:]
        for (i, f) in (scene.levelDef.pickups.fixed ?? []).enumerated() { respawn["fixed_\(i)_\(f.itemId)"] = f.respawnOnBossPhase ?? false }
        fixedRespawn = respawn
    }

    func start() {
        scene.enemyDirector.add(node)
        node.brain.enter(BossState.self)
        for id in arena.coreMachineIds { addSocket(id) }
        scene.pixelBrain.handle(.bossPhase(1))
    }

    // MARK: State for HUD and tests

    var isDefeated: Bool { brain.isDefeated }

    var barState: BossBarState {
        BossBarState(nameKey: node.def.nameKey, hpRatio: (brain.hpRatio * 200).rounded() / 200, notches: brain.phaseNotches,
                     phase: brain.phaseIndex + 1, phases: brain.phases.count, immune: brain.isImmune,
                     coresIn: min(brain.coresInserted, brain.phase.unlockBy?.count ?? 0),
                     coresNeeded: brain.phase.unlockBy?.count ?? 0, defeated: brain.isDefeated)
    }

    var census: BossBrain.CoreCensus {
        let floor = scene.pickups.filter { !$0.isCollected && $0.item.id == coreItemId }.reduce(0) { $0 + $1.count }
        return .init(inBag: scene.inventory.count(of: coreItemId), onFloor: floor, inFlight: coresInFlight)
    }

    // MARK: Frame

    func tick(dt: Double) {
        if defeatT != nil { updateDefeat(dt: dt); return }
        node.updateFace(dt: dt, hero: scene.hero.position)
        if phaseLock > 0 {
            phaseLock -= dt
            node.desiredVelocity = .zero
            return
        }
        handle(brain.tick(dt: dt, census: census))
        updateAttack(dt: dt)
        walk(dt: dt)
        updateMood()
        node.setBubble(brain.isImmune)
        updateSockets()
    }

    /// The rescue's slow-mo: the boss holds still and its attack is gone already.
    func tickDuringRescue(dt: Double) {
        node.desiredVelocity = .zero
    }

    private func walk(dt: Double) {
        let h = scene.hero.position, p = node.position
        let dx = h.x - p.x, dy = h.y - p.y, d = hypot(dx, dy)
        guard running == nil, !brain.isDizzy, d > Self.walkStopDistance, node.def.moveSpeed > 0 else {
            node.desiredVelocity = .zero
            return
        }
        let v = CGFloat(node.def.moveSpeed)
        let step = CGPoint(x: p.x + dx / d * v * CGFloat(dt), y: p.y + dy / d * v * CGFloat(dt))
        node.desiredVelocity = CGVector(dx: dx / d * v, dy: dy / d * v)
        if !scene.solidGrid.isBlocked(step, radius: node.radius * 0.8) { node.position = step }
    }

    private func updateMood() {
        if brain.isDizzy { node.setMood(.panic) }
        else if running != nil || brain.phase.id == brain.phases.last?.id { node.setMood(.angry) }
        else { node.setMood(.smug) }
    }

    // MARK: Brain events

    private func handle(_ events: [BossBrain.Event]) {
        for e in events {
            switch e {
            case .phaseStarted(let i, _):
                scene.pixelBrain.handle(.bossPhase(i + 1))
                cancelAttack()
                phaseLock = Self.phaseLockSec
                scene.enemyShots.recycleAll(popInto: scene.worldNode)
                node.phaseFlash()
                node.setMood(.panic)
                EnemyFX.setDizzy(node, false)
                phaseRing()
                respawnFixedPickups()
            case .attack(let a):
                begin(a)
            case .spawn(let id, let enemyId, let item):
                let cell = arena.carrierSpawns[(id - 1) % max(1, arena.carrierSpawns.count)]
                let p = arena.level.grid.world(cell)
                guard let e = scene.enemyDirector.spawn(enemyId, at: p, aware: true) else { continue }
                e.bossSpawnId = id
                e.setCarry(item)
                spawns[id] = e
                scene.worldNode.addChild(Particles.teleport(at: p))
            case .giveItem(let id, let item):
                spawns[id]?.setCarry(item)
            case .shieldPopped:
                node.setBubble(false)
                node.setMood(.panic)
                scene.audio?.play(.gateUnlocked)
            case .dizzyStarted:
                cancelAttack()
                EnemyFX.setDizzy(node, true)
            case .dizzyEnded:
                EnemyFX.setDizzy(node, false)
            case .defeated:
                beginDefeat()
            }
        }
    }

    // MARK: Scene reports

    /// A hero shot reached the boss.
    func hit(with shot: ProjectileNode) {
        guard defeatT == nil else { return }
        if phaseLock > 0 || brain.isImmune {
            scene.worldNode.addChild(node.bubbleRipple(at: shot.position))
            if brain.isImmune, !saidShield {
                saidShield = true
                scene.pixelBrain.say(StoryDirector.Key.bossShield, kind: .story)
            }
            return
        }
        let r = brain.takeDamage(shot.damage)
        let dir = CGVector(dx: cos(shot.angle), dy: sin(shot.angle))
        scene.worldNode.addChild(Particles.hitSparkle(color: Palette.projectile(style: shot.style), at: shot.position,
                                                      shotAngle: shot.angle, small: shot.style == "foam"))
        if case .hit = r.result {
            node.animator.playHit(from: dir)
            scene.audio?.play(.enemyHit)
            if brain.isDizzy { scene.worldNode.addChild(Particles.stateOn(at: shot.position, color: .white, count: 5)) }
        }
        handle(r.events)
    }

    /// Damage that does not come from a projectile (tests, the scripted playthrough).
    func applyDamage(_ amount: Int) {
        guard defeatT == nil, phaseLock <= 0 else { return }
        handle(brain.takeDamage(amount).events)
    }

    /// A core machine was powered.
    func coreInserted() {
        scene.audio?.play(.machineOn)
        handle(brain.coreInserted())
    }

    /// A core machine was used without a core. False when Pixel did not say it (cooldown or the
    /// talk filter): the caller shows the usual toast instead.
    func coreNeeded() -> Bool {
        guard scene.clock - coreNeededAt >= Self.coreNeededCooldownSec else { return true }
        guard scene.pixelBrain.say(StoryDirector.Key.coreNeeded, kind: .hint) != .filtered else { return false }
        coreNeededAt = scene.clock
        return true
    }

    func spawnPoweredDown(_ e: EnemyNode) {
        guard let id = e.bossSpawnId else { return }
        brain.spawnPoweredDown(id: id)
        spawns[id] = nil
        if e.carriesItem != nil { coresInFlight += 1 }
    }

    /// A carrier's core reached the floor.
    func coreLanded() {
        coresInFlight = max(0, coresInFlight - 1)
    }

    /// The hero was rescued in the arena: the boss goes back to its phase top (GDD §9).
    func heroRescued() {
        cancelAttack()
        brain.rescueReset()
        EnemyFX.setDizzy(node, false)
    }

    /// `debug.bossNextPhase`.
    func debugNextPhase() {
        guard defeatT == nil else { return }
        phaseLock = 0
        handle(brain.debugNextPhase())
    }

    // MARK: Attacks (telegraph → hit test)

    private static let lineRed = EnemyFX.warnRed

    private func begin(_ a: BossAttackDef) {
        cancelAttack()
        let origin = node.position
        let h = scene.hero.position
        let toHero = atan2(h.y - origin.y, h.x - origin.x)
        let fx = SKNode()
        fx.zPosition = node.zPosition - 0.5
        fx.position = origin
        fx.name = "boss_telegraph"
        var r = Running(attack: a, origin: origin, fx: fx)
        switch a.type {
        case BossAttackDef.stomp:
            let rad = CGFloat(a.telegraphRadius ?? a.range)
            let ring = SKShapeNode(circleOfRadius: rad)
            ring.strokeColor = Self.lineRed
            ring.lineWidth = 2
            ring.fillColor = Self.lineRed.withAlphaComponent(0.2)
            ring.name = "stomp_ring"
            fx.addChild(ring)
            let inner = SKShapeNode(circleOfRadius: rad)
            inner.fillColor = Self.lineRed.withAlphaComponent(0.25)
            inner.strokeColor = .clear
            inner.setScale(0.01)
            let grow = SKAction.scale(to: 1, duration: a.telegraphSec)
            grow.timingMode = .easeIn
            inner.run(grow)
            fx.addChild(inner)
        case BossAttackDef.volley:
            r.angles = StarVolley.angles(toward: toHero, attack: a)
            for ang in r.angles {
                let p = CGMutablePath()
                p.move(to: CGPoint(x: cos(ang) * node.radius, y: sin(ang) * node.radius))
                p.addLine(to: CGPoint(x: cos(ang) * (node.radius + 90), y: sin(ang) * (node.radius + 90)))
                let line = SKShapeNode(path: p.copy(dashingWithPhase: 0, lengths: [8, 6]))
                line.strokeColor = Self.lineRed.withAlphaComponent(0.7)
                line.lineWidth = 3
                line.alpha = 0
                line.run(.fadeIn(withDuration: 0.3))
                fx.addChild(line)
            }
        case BossAttackDef.laserSweep:
            // The first gap starts on the hero's side, so there is always a safe spot to step into.
            r.startAngle = toHero
            fx.addChild(laserPie(a, startAngle: toHero))
        case BossAttackDef.dash:
            let path = BossDash.path(from: origin, toward: h, radius: node.radius, maxDistance: CGFloat(a.range),
                                     bounds: arena.floorWorldRect, pillars: arena.pillarWorldRects)
            r.dash = path
            fx.addChild(dashArrow(path))
            if let i = path.pillarIndex {
                let pr = arena.pillarWorldRects[i]
                let ring = SKShapeNode(circleOfRadius: pr.width * 0.75)
                ring.strokeColor = Palette.star
                ring.lineWidth = 3
                ring.position = CGPoint(x: pr.midX - origin.x, y: pr.midY - origin.y)
                fx.addChild(ring)
            }
        default:
            break
        }
        scene.worldNode.addChild(fx)
        running = r
    }

    func cancelAttack() {
        running?.fx.removeFromParent()
        running = nil
    }

    private func finishAttack() {
        running?.fx.run(.sequence([.fadeOut(withDuration: 0.15), .removeFromParent()]))
        running = nil
        brain.attackFinished()
    }

    private func hurt(_ a: BossAttackDef) {
        scene.combat.hurtHero(a.damage, from: node.position)
    }

    private func updateAttack(dt: Double) {
        guard var r = running else { return }
        r.t += dt
        let a = r.attack
        let hero = scene.hero
        let heroR = hero.radius
        let tAct = r.t - a.telegraphSec
        switch a.type {
        case BossAttackDef.stomp:
            let dist = hypot(hero.position.x - r.origin.x, hero.position.y - r.origin.y)
            if tAct >= 0, !r.impacted {
                r.impacted = true
                if StompWave.impactHits(heroDistance: dist, heroRadius: heroR, attack: a) { hurt(a) }
                r.fx.removeAllChildren()
                let wave = SKShapeNode(circleOfRadius: CGFloat(a.telegraphRadius ?? a.range))
                wave.strokeColor = .white
                wave.lineWidth = StompWave.bandWidth / 3
                wave.fillColor = .clear
                wave.glowWidth = 4
                wave.run(.scale(to: CGFloat(a.range / (a.telegraphRadius ?? a.range)), duration: a.effectiveWaveSec))
                r.fx.addChild(wave)
                scene.worldNode.addChild(Particles.group(at: r.origin, [
                    Particles.Burst(texture: Textures.particleDot, color: .white, count: 10, lifetime: 0.3, speed: 120...220, size: 8),
                ]))
            } else if tAct >= 0 {
                if StompWave.waveHits(heroDistance: dist, heroRadius: heroR, at: tAct, attack: a) { hurt(a) }
                if tAct > a.effectiveWaveSec { running = r; finishAttack(); return }
            }
        case BossAttackDef.volley:
            if tAct >= 0, !r.fired {
                r.fired = true
                for ang in r.angles {
                    let p = CGPoint(x: r.origin.x + cos(ang) * node.radius, y: r.origin.y + sin(ang) * node.radius)
                    scene.combat.spawnEnemyShot(kind: .star, at: p, angle: ang, speed: CGFloat(a.projectileSpeed ?? 200),
                                                radius: CGFloat(a.projectileRadius ?? 12), damage: a.damage, range: CGFloat(a.range))
                }
                scene.audio?.play(.enemyShot)
                running = r
                finishAttack()
                return
            }
        case BossAttackDef.laserSweep:
            if tAct >= 0 {
                let deg = (a.sweepDegPerSec ?? 0) * tAct
                r.fx.zRotation = CGFloat(deg) * .pi / 180
                r.fx.alpha = 1
                let dx = hero.position.x - r.origin.x, dy = hero.position.y - r.origin.y
                let los = scene.solidGrid.hasLineOfSight(from: r.origin, to: hero.position)
                if LaserSweep.hits(heroAngle: atan2(dy, dx), heroDistance: hypot(dx, dy), heroRadius: heroR, at: tAct,
                                   startAngle: r.startAngle, attack: a, hasLineOfSight: los) {
                    hurt(a)
                }
                if tAct > a.effectiveSweepSec { running = r; finishAttack(); return }
            } else {
                r.fx.alpha = CGFloat(0.4 + 0.6 * r.t / max(0.01, a.telegraphSec))
            }
        case BossAttackDef.dash:
            guard let path = r.dash else { running = r; finishAttack(); return }
            if tAct >= 0 {
                let speed = CGFloat(a.dashSpeed ?? 400)
                let len = path.length
                let k = len > 0 ? min(1, speed * CGFloat(tAct) / len) : 1
                let p = CGPoint(x: path.start.x + (path.end.x - path.start.x) * k, y: path.start.y + (path.end.y - path.start.y) * k)
                node.position = p
                if hypot(hero.position.x - p.x, hero.position.y - p.y) <= heroR + node.radius { hurt(a) }
                if k >= 1 {
                    running = r
                    let bonk = path.hitPillar
                    cancelAttack()
                    if bonk {
                        scene.worldNode.addChild(Particles.stateOn(at: p, color: Palette.star, count: 10))
                        scene.audio?.play(.crateBreak)
                        handle(brain.dashHitPillar(a))
                    } else {
                        brain.attackFinished()
                    }
                    return
                }
            }
        default:
            running = r
            finishAttack()
            return
        }
        running = r
    }

    private func respawnFixedPickups() {
        for p in arena.level.pickups where fixedRespawn[p.id] == true {
            guard !scene.pickups.contains(where: { $0.placementId == p.id }), let item = scene.data.items[p.itemId] else { continue }
            scene.interaction.addPlacedPickup(item, at: arena.level.grid.world(p.cell), placementId: p.id, count: p.count)
        }
    }

    // MARK: Core sockets (§15.10)

    private func addSocket(_ id: String) {
        guard let m = scene.built.interactables[id] else { return }
        let s = SKShapeNode(rect: CGRect(x: -20, y: -20, width: 40, height: 40), cornerRadius: 8)
        s.fillColor = Palette.background
        s.strokeColor = Palette.panelLine
        s.lineWidth = 3
        s.zPosition = 6
        s.name = "core_socket"
        s.position = CGPoint(x: 0, y: 8)
        let ghost = SKShapeNode(circleOfRadius: 11)
        ghost.strokeColor = Palette.hex(0x8FA3C8)
        ghost.lineWidth = 2
        ghost.fillColor = .clear
        ghost.name = "ghost"
        s.addChild(ghost)
        m.addChild(s)
        sockets[id] = s
    }

    private func updateSockets() {
        let haveCore = scene.inventory.count(of: coreItemId) > 0
        for (id, s) in sockets {
            guard let sock = s as? SKShapeNode else { continue }
            let on = scene.puzzle.isOn(id)
            sock.fillColor = on ? Palette.pixelCyan.withAlphaComponent(0.8) : Palette.background
            if let ghost = sock.childNode(withName: "ghost") as? SKShapeNode {
                ghost.fillColor = on ? Palette.star : .clear
                ghost.strokeColor = on ? Palette.outline : (haveCore ? Palette.star : Palette.hex(0x8FA3C8))
            }
        }
    }

    // MARK: Defeat (§15.12, sparkle burst, never an explosion look)

    private func beginDefeat() {
        cancelAttack()
        defeatT = 0
        defeatStep = 0
        node.setBubble(false)
        EnemyFX.setDizzy(node, false)
        node.setMood(.panic)
        node.phaseFlash()
        node.desiredVelocity = .zero
        scene.enemyShots.recycleAll(popInto: scene.worldNode)
        for e in scene.enemies where !e.isBoss && !e.isPoweredDown {
            scene.worldNode.addChild(Particles.poof(at: e.position, darkFloor: true))
            e.powerDown { [weak e, weak scene] in
                guard let e else { return }
                scene?.enemyDirector.remove(e)
            }
        }
        scene.pixelBrain.handle(.bossDefeated)
        scene.audio?.play(.enemyPowerDown)
    }

    private func updateDefeat(dt: Double) {
        guard var t = defeatT else { return }
        t += dt
        defeatT = t
        let colors = [Palette.star, Palette.pixelCyan, SKColor.white, Palette.hex(0xD61F8F)]
        let torso = CGPoint(x: node.position.x, y: node.position.y + MegaMechNode.poseHeight * 0.35)
        // 3 mini bursts 0.45 s apart.
        while defeatStep < 3, t >= Double(defeatStep) * 0.45 {
            let off = CGPoint(x: CGFloat(scene.random.nextUniform() - 0.5) * 80, y: CGFloat(scene.random.nextUniform() - 0.5) * 80)
            scene.worldNode.addChild(Particles.poof(at: CGPoint(x: torso.x + off.x, y: torso.y + off.y), bodyColors: colors, darkFloor: true))
            scene.audio?.play(.enemyPowerDown)
            defeatStep += 1
        }
        node.animator.sprite.position.x = t < 1.4 ? CGFloat(sin(t * 2 * .pi * 14)) * 3 : 0
        if defeatStep == 3, t >= 1.4 {
            defeatStep = 4
            node.setMood(.smiley)
            node.animator.root.run(.scale(to: 0.85, duration: 0.4))
            scene.worldNode.addChild(Particles.group(at: torso, [
                Particles.Burst(texture: Textures.particleStar, color: Palette.star, count: 16, lifetime: 1.2, speed: 60...160,
                                size: 18, angle: .pi / 2, angleRange: 1.2),
            ]))
        }
        if defeatStep == 4, t >= 1.8 {
            defeatStep = 5
            scene.worldNode.addChild(Particles.group(at: torso, [
                Particles.Burst(texture: Textures.particleStar, color: Palette.star, count: 20, lifetime: 1.0, speed: 160...320, size: 18),
                Particles.Burst(texture: Textures.outlinedChip, color: Palette.robotMetalLight, count: 10, lifetime: 1.0,
                                speed: 120...260, size: 14, blend: .alpha),
                Particles.Burst(texture: Textures.particleDot, color: Palette.pixelCyan, count: 10, lifetime: 0.8, speed: 100...240, size: 10),
            ]))
            let ring = SKShapeNode(circleOfRadius: 80)
            ring.strokeColor = .white
            ring.lineWidth = 4
            ring.position = torso
            ring.zPosition = Particles.zPosition
            ring.run(.sequence([.group([.scale(to: 300.0 / 80, duration: 0.5), .fadeOut(withDuration: 0.5)]), .removeFromParent()]))
            scene.worldNode.addChild(ring)
            let white = SKSpriteNode(color: .white, size: CGSize(width: 4000, height: 4000))
            white.alpha = 0
            white.zPosition = 880
            white.run(.sequence([.fadeAlpha(to: 0.35, duration: 0.05), .fadeOut(withDuration: 0.1), .removeFromParent()]))
            scene.cameraNode.addChild(white)
            node.animator.root.run(.group([.scale(to: 0, duration: 0.6), .fadeOut(withDuration: 0.6)]))
        }
        if defeatStep == 5, t >= 2.4 {
            defeatStep = 6
            if !lootDropped {
                lootDropped = true
                let drops = LootRoller.roll(tableId: node.def.lootTableId, data: scene.data, context: scene.lootContext, random: scene.random)
                scene.spawnLoot(drops, at: node.position)
            }
            scene.session.addScore(node.def.scoreValue)
            confetti()
        }
        if t >= Self.defeatSec {
            defeatT = nil
            defeatStep = 7
            node.isHidden = true
            scene.interaction.completeArena()
        }
    }
}
