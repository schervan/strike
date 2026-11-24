import GameplayKit
import SpriteKit
import Testing
@testable import Strike

/// M4-7 boss fight with a MORTAL hero (not invulnerable) on a real `GameScene` in the arena stage: a bot fires at the
/// boss with the real blaster cadence/ammo (`hero.tryFire`) and kid accuracy, real shot resolution (`combat.resolve`),
/// stands where a kid would (no dodging), collects pillar ammo, kills carriers, carries cores to the machines and
/// uses INTERACT. Rescues happen for real (boss resets to its phase top). Timings and rescues are printed.
@MainActor
struct M4ScenarioTests {
    static var data: GameData { GeneratedCorpus.data }

    struct Result { var done = false; var seconds = 0.0; var rescues = 0; var phaseTimes: [Double] = []; var shots = 0; var coresIn = 0; var ammoTrips = 0; var milestones: [String] = [] }

    /// One trigger pull at `target` from the hero's position: `accuracy` decides whether the volley is on target, then
    /// the real pellet fan (`WeaponFire`) decides how many pellets touch the target's circle.
    static func volley(_ s: GameScene, at target: SKNode, radius: CGFloat, accuracy: Double, rng: inout BossFuzzTests.SplitMix,
                       random: GKRandom) {
        guard Double.random(in: 0..<1, using: &rng) < accuracy else { return }
        let w = s.hero.weapon.def
        let d = Double(hypot(target.position.x - s.hero.position.x, target.position.y - s.hero.position.y))
        let shot = WeaponFire.shot(def: w, aimAngle: 0, rng: random)
        for ang in shot.angles where cos(Double(ang)) > 0 && abs(d * sin(Double(ang))) <= Double(radius) + w.projectileRadius {
            ScenePlaythroughTests.shoot(s, at: target)
        }
    }

    static func fight(weaponId: String, seed: UInt64, accuracy: Double, dodge: Double = 0, maxSeconds: Double = 900) throws -> Result {
        let data = Self.data
        var run = RunState.newGame(data: data)
        for id in ["blaster_spread", "blaster_rapid"] { if let w = data.weapons[id] { _ = run.loadout.addWeapon(w) } }
        for (id, w) in data.weapons.map({ ($0.value.ammoId, $0.value) }) { run.loadout.ammo.set(id, w.reserveMax / 2) }
        _ = run.loadout.equip(weaponId)
        run.arena = ArenaProgress(levelId: "l5", elapsed: 300)
        let def = try #require(data.levels["l5"])
        let s = GameScene(data: data, level: def, seed: seed, run: run, stage: .bossArena)
        let view = SKView(frame: CGRect(origin: .zero, size: GameScene.logicalSize))
        view.presentScene(s)
        let model = GameModel(data: data)
        s.model = model
        let boss = try #require(s.boss)
        var rng = BossFuzzTests.SplitMix(s: seed &* 7919 &+ UInt64(dodge * 1000))
        let gk = GKMersenneTwisterRandomSource(seed: seed)
        var res = Result()
        var phase = boss.brain.phaseIndex
        var lastCores = 0
        var phaseStart = 0.0
        var t = 0.0
        let dt = 0.05
        func frame() {
            s.step(dt: dt)
            for e in s.enemies where !e.isPoweredDown && !e.isBoss {
                let p = CGPoint(x: e.position.x + e.desiredVelocity.dx * CGFloat(dt), y: e.position.y + e.desiredVelocity.dy * CGFloat(dt))
                if !s.solidGrid.isBlocked(p, radius: e.radius * 0.8) { e.position = p }
            }
            t += dt
            if boss.brain.coresInserted > lastCores { lastCores = boss.brain.coresInserted; res.milestones.append("core \(lastCores) in at \(Int(t))") }
            if boss.brain.phaseIndex != phase { res.phaseTimes.append(t - phaseStart); phase = boss.brain.phaseIndex; phaseStart = t }
        }
        func standOff(from target: CGPoint, _ dist: CGFloat) {
            // a spot `dist` from the target with open floor, nearest to the hero's current side
            let a0 = atan2(s.hero.position.y - target.y, s.hero.position.x - target.x)
            for k in 0..<16 {
                let a = a0 + CGFloat(k % 2 == 0 ? k / 2 : -(k + 1) / 2) * .pi / 8
                let p = CGPoint(x: target.x + cos(a) * dist, y: target.y + sin(a) * dist)
                if !s.solidGrid.isBlocked(p, radius: 24) { s.hero.position = p; return }
            }
        }
        for _ in 0..<3 { frame() }
        var wasBusy = false
        var busyT = 0.0
        var gapStart: CGFloat?
        var lastRescues = s.session.rescues
        while !s.isComplete, t < maxSeconds {
            if s.rescue != nil { frame(); continue }
            if s.hero.totalAmmo == 0, s.hero.weapon.def.id != "blaster_starter", let st = data.weapons["blaster_starter"] {
                _ = s.hero.swap(to: st, swapSec: data.rules.weapons.swapSec)
            }
            if s.session.rescues != lastRescues { res.rescues += s.session.rescues - lastRescues; lastRescues = s.session.rescues }
            // Ammo: when nearly dry, walk to the nearest pillar pickup of any kind that gives ammo.
            if s.hero.totalAmmo < 8, let p = s.pickups.filter({ !$0.isCollected && $0.item.category == .ammo && $0.hasLanded }).first {
                s.hero.position = p.groundPosition
                res.ammoTrips += 1
                for _ in 0..<6 { frame() }
                continue
            }
            if boss.brain.isImmune {
                if let carrier = s.enemies.first(where: { $0.carriesItem != nil && !$0.isPoweredDown }) {
                    // keep a kid-like distance and shoot the carrier
                    standOff(from: carrier.position, 180)
                    for _ in 0..<2 { frame() }
                    if s.hero.tryFire(triggerHeld: true) { res.shots += 1; volley(s, at: carrier, radius: carrier.radius, accuracy: 0.85, rng: &rng, random: gk) }
                    continue
                }
                if let core = s.pickups.first(where: { $0.item.id == boss.coreItemId && $0.hasLanded && !$0.isCollected }) {
                    s.hero.position = core.groundPosition
                    for _ in 0..<4 { frame() }
                    continue
                }
                if s.inventory.count(of: boss.coreItemId) > 0,
                   let m = s.level.elements.first(where: { $0.type == .machine && !s.puzzle.isOn($0.id) }) {
                    if ScenePlaythroughTests.walk(s, to: ScenePlaythroughTests.near(m)) {
                        if let n = s.built.interactables[m.id] {
                            let dx = n.position.x - s.hero.position.x, dy = n.position.y - s.hero.position.y
                            let d = hypot(dx, dy), want = 56 + n.reachPadding
                            if d > want { s.hero.position.x += dx / d * (d - want); s.hero.position.y += dy / d * (d - want) }
                        }
                        frame(); s.handle(.interact); frame()
                        res.coresIn = boss.brain.coresInserted
                    }
                    continue
                }
                // waiting for the next carrier: stand off from the boss
                standOff(from: boss.node.position, 320)
                for _ in 0..<4 { frame() }
                continue
            }
            // Kid dodge: when an attack starts, with probability `dodge` the kid sidesteps out of its danger zone.
            let busy = boss.brain.isBusy
            if busy, !wasBusy { busyT = 0; gapStart = nil }
            if busy { busyT += dt }
            // Laser sweep: a skilled kid walks with a gap (GDD §9). The first gap starts at the hero's side.
            if busy, boss.brain.phase.attacks.contains(where: { $0.type == BossAttackDef.laserSweep }) {
                let b = boss.node.position
                if !wasBusy, Double.random(in: 0..<1, using: &rng) < dodge {
                    gapStart = atan2(s.hero.position.y - b.y, s.hero.position.x - b.x)
                }
                if let a0 = gapStart {
                    let a = a0 + CGFloat(max(0, busyT - 1.0)) * (30 * .pi / 180)
                    let p = CGPoint(x: b.x + cos(a) * 250, y: b.y + sin(a) * 250)
                    if !s.solidGrid.isBlocked(p, radius: 24) { s.hero.position = p }
                }
            } else if busy, !wasBusy, Double.random(in: 0..<1, using: &rng) < dodge {
                let b = boss.node.position, h = s.hero.position
                let a = atan2(h.y - b.y, h.x - b.x) + (Bool.random(using: &rng) ? 1 : -1) * 0.9
                for r in [300.0, 250, 350] as [CGFloat] {
                    let p = CGPoint(x: b.x + cos(a) * r, y: b.y + sin(a) * r)
                    if !s.solidGrid.isBlocked(p, radius: 24) { s.hero.position = p; break }
                }
            }
            wasBusy = busy
            // Vulnerable boss: stand ~250 pt away and fire.
            if hypot(s.hero.position.x - boss.node.position.x, s.hero.position.y - boss.node.position.y) > 330 { standOff(from: boss.node.position, 250) }
            frame()
            if s.hero.tryFire(triggerHeld: true) {
                res.shots += 1
                let acc = s.hero.weapon.def.pellets > 1 ? min(0.95, accuracy + 0.25) : accuracy
                volley(s, at: boss.node, radius: boss.node.radius, accuracy: acc, rng: &rng, random: gk)
            }
        }
        res.rescues = s.session.rescues - (run.arena?.rescues ?? 0)
        res.milestones.append("end: weapon \(s.hero.weapon.def.id) ammo \(s.hero.totalAmmo) mag \(s.hero.magazine) reloading \(s.hero.weapon.isReloading) hp \(s.hero.health.current) bossHP \(boss.brain.hp) phase \(boss.brain.phaseIndex + 1) immune \(boss.brain.isImmune) pickups \(s.pickups.filter { !$0.isCollected }.map { $0.item.id })")
        res.done = s.isComplete || boss.isDefeated
        res.seconds = t
        res.phaseTimes.append(t - phaseStart)
        return res
    }

    /// A kid who sidesteps 75 % of the attacks must win with every blaster; the table of dodge skills is logged.
    @Test(arguments: ["blaster_starter", "blaster_spread", "blaster_rapid"])
    func mortalHeroBeatsTheBossWithEachBlaster(weaponId: String) throws {
        for seed in [1, 2, 3] as [UInt64] {
            let r = try Self.fight(weaponId: weaponId, seed: seed, accuracy: 0.6, dodge: 0.75)
            print("BOSSFIGHT \(weaponId) dodge 75% run \(seed): defeated=\(r.done) \(Int(r.seconds)) s, rescues \(r.rescues), phase times \(r.phaseTimes.map { Int($0) }), shots \(r.shots), ammo trips \(r.ammoTrips), cores in \(r.coresIn), \(r.milestones)")
            #expect(r.done, "\(weaponId) seed \(seed): boss not defeated within the time limit")
        }
    }

    /// Dodge skill sweep with the starter blaster, asserted at every skill level since QA-016 was fixed.
    @Test func dodgeSkillSweepIsLogged() throws {
        for dodge in [0.0, 0.25, 0.5, 0.75, 0.9] {
            var times: [Double] = [], rescues: [Int] = [], wins = 0
            for seed in [1, 2, 3, 4] as [UInt64] {
                let r = try Self.fight(weaponId: "blaster_starter", seed: seed, accuracy: 0.6, dodge: dodge, maxSeconds: 600)
                times.append(r.seconds); rescues.append(r.rescues); if r.done { wins += 1 }
            }
            if wins < 4 { for seed in [1, 2, 3, 4] as [UInt64] { let r = try Self.fight(weaponId: "blaster_starter", seed: seed, accuracy: 0.6, dodge: dodge, maxSeconds: 600); if !r.done { print("BOSSSTUCK dodge \(dodge) seed \(seed): phases \(r.phaseTimes.map { Int($0) }) rescues \(r.rescues) shots \(r.shots) \(r.milestones)") } } }
            print("BOSSSWEEP dodge \(Int(dodge * 100)) %: wins \(wins)/4, times \(times.map { Int($0) }), rescues \(rescues)")
            // QA-016 fixed (a rescue keeps the boss's damage): even a kid who never dodges must be able to win.
            #expect(wins == 4, "dodge \(dodge): \(wins)/4 wins")
        }
    }
}
