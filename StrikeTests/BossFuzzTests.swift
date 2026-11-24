import Foundation
import Testing
@testable import Strike

/// M4-7: 10,000 random boss sequences driven through the real `BossBrain`, checked against QA's OWN model of the
/// GDD §9 rules (phase HP ranges, shield immunity, dizzy windows, core supply) written without reading `BossBrain`'s
/// internals beyond its public API. After the chaos part every sequence is handed to a competent "hero" that must
/// finish the fight in bounded simulated time (no soft-lock).
struct BossFuzzTests {
    struct SplitMix: RandomNumberGenerator {
        var s: UInt64
        mutating func next() -> UInt64 {
            s &+= 0x9E37_79B9_7F4A_7C15
            var z = s
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
    }

    static let data: GameData = try! TestData.load()
    static let def: EnemyDef = data.enemies["megamech"]!

    /// The world around the boss, as the scene would report it.
    struct World {
        var bag = 0
        var floor = 0
        /// Cores popping out of a dead carrier: seconds left each.
        var inFlight: [Double] = []
        var carrying: Set<Int> = []
        var alive: Set<Int> = []
        var machinesFilled = 0
        var census: BossBrain.CoreCensus { .init(inBag: bag, onFloor: floor, inFlight: inFlight.count) }
    }

    /// QA's independent expectation of the boss state.
    struct Model {
        var phase = 0
        var hp: Int
        var inserted = 0
        var dizzy = 0.0
        var defeated = false
        let phases: [BossPhaseDef]
        init(_ phases: [BossPhaseDef]) { self.phases = phases; hp = phases[0].hpFrom }
        var p: BossPhaseDef { phases[phase] }
        var shieldUp: Bool { p.immune && (p.unlockBy.map { inserted < $0.count } ?? true) }
        var mult: Double { dizzy > 0 ? (p.unlockBy?.dizzyDamageMultiplier ?? 1) : 1 }

        mutating func nextPhase() {
            // QA-021: each phase counts its own inserted cores.
            if phase + 1 < phases.count { phase += 1; hp = p.hpFrom; dizzy = 0; inserted = 0 } else { hp = 0; defeated = true; dizzy = 0 }
        }
        /// Returns true when the hit did damage.
        mutating func damage(_ base: Int, dizzyMult: Double) -> Bool {
            if defeated || shieldUp { return false }
            let d = max(1, Int((Double(base) * dizzyMult).rounded()))
            hp = max(p.hpTo, hp - d)
            if hp <= p.hpTo { nextPhase() }
            return true
        }
    }

    /// One whole sequence. Nil = all invariants held.
    struct Coverage { var shieldPopped = 0, dizzy = 0, rescues = 0, immuneHits = 0, phaseSkips = 0, pillar = 0, chaosDefeats = 0, coreLost = 0 }

    static func run(seed: UInt64, chaosActions: Int, cov: inout Coverage) -> String? {
        var rng = SplitMix(s: seed)
        guard var brain = BossBrain(def: def) else { return "seed \(seed): no brain" }
        var world = World()
        var model = Model(def.phases!)
        var log: [String] = []
        var simTime = 0.0
        var defeatedEvents = 0

        func fail(_ why: String) -> String { "seed \(seed): \(why) after [\(log.suffix(6).joined(separator: ", "))]" }

        func absorb(_ events: [BossBrain.Event], dizzyBefore: Bool, busyBefore: Bool) -> String? {
            var attacks = 0
            for ev in events {
                switch ev {
                case .attack:
                    attacks += 1
                    if dizzyBefore { return fail("attack while dizzy") }
                    if busyBefore { return fail("attack while another attack was running") }
                case .spawn(let id, _, let item):
                    world.alive.insert(id)
                    if item != nil { world.carrying.insert(id) }
                case .giveItem(let id, _):
                    guard world.alive.contains(id) else { return fail("giveItem to a dead spawn \(id)") }
                    world.carrying.insert(id)
                case .shieldPopped:
                    cov.shieldPopped += 1
                    model.dizzy = model.p.unlockBy?.dizzySec ?? 0
                case .dizzyStarted(let sec): cov.dizzy += 1; model.dizzy = max(model.dizzy, sec)
                case .dizzyEnded: model.dizzy = 0
                case .phaseStarted(let i, _):
                    // New phase: spawns of the old one are irrelevant to the model.
                    if i != brain.phaseIndex { return fail("phaseStarted index \(i) != brain phase \(brain.phaseIndex)") }
                case .defeated: defeatedEvents += 1
                }
            }
            if attacks > 1 { return fail("\(attacks) attacks in one tick") }
            return nil
        }

        func compare() -> String? {
            if brain.isDefeated != model.defeated { return fail("defeated \(brain.isDefeated) vs model \(model.defeated)") }
            if brain.isDefeated { return brain.hp == 0 ? nil : fail("defeated with hp \(brain.hp)") }
            if brain.phaseIndex != model.phase { return fail("phase \(brain.phaseIndex) vs model \(model.phase)") }
            if brain.hp != model.hp { return fail("hp \(brain.hp) vs model \(model.hp) in phase \(model.phase)") }
            if brain.hp > model.p.hpFrom || brain.hp < model.p.hpTo { return fail("hp \(brain.hp) outside phase range") }
            if brain.coresInserted != model.inserted { return fail("cores inserted \(brain.coresInserted) vs model \(model.inserted)") }
            if brain.isImmune != model.shieldUp && model.p.immune { return fail("immune \(brain.isImmune) vs model shield \(model.shieldUp)") }
            if defeatedEvents > 1 { return fail("defeated emitted \(defeatedEvents) times") }
            return nil
        }

        /// Time passes: world timers, brain tick, core guarantee check.
        func advance(_ dt: Double) -> String? {
            simTime += dt
            let flights = world.inFlight.count
            world.inFlight = world.inFlight.map { $0 - dt }.filter { $0 > 0 }
            world.floor += flights - world.inFlight.count          // landed cores lie on the floor
            // An attack that ends or a dizzy that wears off inside this very tick may be followed by a new attack in it.
            let dizzyBefore = brain.dizzyRemaining > dt, busyBefore = brain.busyRemaining > dt
            let events = brain.tick(dt: dt, census: world.census)
            if let m = absorb(events, dizzyBefore: dizzyBefore, busyBefore: busyBefore) { return m }
            // dizzy bookkeeping of the model
            if model.dizzy > 0 { model.dizzy = max(0, model.dizzy - dt) }
            if !brain.isDizzy { model.dizzy = 0 }
            // GDD §9: while the shield puzzle is open, at least `count` cores must exist (inserted + held + carried).
            if !brain.isDefeated, let u = brain.phase.unlockBy, brain.phase.spawn != nil, brain.coresInserted < u.count {
                let supply = brain.coresInserted + world.census.total + brain.carriersAlive
                if supply < u.count { return fail("core supply \(supply) < \(u.count) after a tick (inserted \(brain.coresInserted), census \(world.census.total), carriers \(brain.carriersAlive))") }
            }
            return compare()
        }

        func killSpawn(_ id: Int) {
            guard world.alive.contains(id) else { return }
            world.alive.remove(id)
            if world.carrying.remove(id) != nil { world.inFlight.append(0.5) }
            brain.spawnPoweredDown(id: id)
            // landed cores appear on the floor after the flight; keep it simple: floor now, flight accounted by timer
        }

        func settleFlights() {
            // Cores whose flight ended are on the floor.
        }

        // ---- chaos part
        for _ in 0..<chaosActions {
            if brain.isDefeated { break }
            let op = Int.random(in: 0..<12, using: &rng)
            switch op {
            case 0, 1, 2, 3:
                let dt = [0.02, 0.05, 0.1, 0.3, 1.0, 2.5].randomElement(using: &rng)!
                if let m = advance(dt) { return m }
                log.append("tick \(dt)")
            case 4, 5:
                let base = [1, 3, 5, 6, 10, 20, 50].randomElement(using: &rng)!
                let hpBefore = brain.hp
                let wasShield = model.shieldUp
                let dm = model.mult
                let (res, events) = brain.takeDamage(base)
                let did = model.damage(base, dizzyMult: dm)
                if wasShield {
                    cov.immuneHits += 1
                    if res != .immune { return fail("shielded boss took a hit: \(res)") }
                    if brain.hp != hpBefore { return fail("shielded boss lost HP \(hpBefore) -> \(brain.hp)") }
                }
                if !wasShield, !did, !model.defeated { return fail("model refused a legal hit") }
                if let m = absorb(events, dizzyBefore: false, busyBefore: false) { return m }
                if let m = compare() { return m }
                log.append("hit \(base)->\(res)")
            case 6:
                // hero kills a random living spawn (carrier drops a core)
                if let id = world.alive.randomElement(using: &rng) { killSpawn(id) }
                log.append("killSpawn")
            case 7:
                // hero picks up a core from the floor
                if world.floor > 0 { world.floor -= 1; world.bag += 1 }
                log.append("pickup")
            case 8:
                // hero inserts a core (only legal while the puzzle is open and the bag holds one)
                if world.bag > 0, let u = brain.phase.unlockBy, brain.coresInserted < u.count, brain.phase.spawn != nil {
                    world.bag -= 1
                    let dizzyWas = brain.isDizzy
                    _ = dizzyWas
                    let wasDown = brain.shieldDown
                    let events = brain.coreInserted()
                    model.inserted += 1
                    if !wasDown, model.inserted >= u.count { model.dizzy = u.dizzySec }
                    if let m = absorb(events, dizzyBefore: false, busyBefore: false) { return m }
                    if let m = compare() { return m }
                }
                log.append("insert")
            case 9:
                // a core is lost (falls away) from the bag or the floor (a carrier only loses its core by dying)
                if world.bag > 0 { world.bag -= 1; cov.coreLost += 1 } else if world.floor > 0 { world.floor -= 1; cov.coreLost += 1 }
                log.append("coreLost")
            case 10:
                // hero rescued (QA-016): the boss keeps its damage, cores and dizzy; only attack timing resets
                brain.rescueReset(); cov.rescues += 1
                if !model.defeated, def.rescueResetsToPhaseTop ?? false { model.hp = model.p.hpFrom }
                if let m = compare() { return m }
                log.append("rescue")
            default:
                if Int.random(in: 0..<6, using: &rng) == 0 {
                    // phase skip (debug) or pillar dash
                    let events = brain.debugNextPhase()
                    if !model.defeated { model.hp = model.p.hpTo; model.nextPhase() }
                    world.alive.removeAll(); world.carrying.removeAll()
                    if let m = absorb(events, dizzyBefore: false, busyBefore: false) { return m }
                    if let m = compare() { return m }
                    cov.phaseSkips += 1
                    log.append("phaseSkip")
                } else if let dash = brain.phase.attacks.first(where: { $0.type == BossAttackDef.dash }) {
                    let events = brain.dashHitPillar(dash)
                    if let m = absorb(events, dizzyBefore: false, busyBefore: false) { return m }
                    model.dizzy = max(model.dizzy, dash.pillarDizzySec ?? 0)
                    cov.pillar += 1
                    log.append("pillar")
                }
            }
        }

        if brain.isDefeated { cov.chaosDefeats += 1 }
        // ---- competent hero: must finish the fight (no soft-lock), within bounded game time
        let limit = simTime + 900
        while !brain.isDefeated, simTime < limit {
            // kill carriers first, collect, insert
            for id in world.alive.sorted() where world.carrying.contains(id) { killSpawn(id) }
            if let m = advance(0.25) { return m }
            let before = world.inFlight.count
            _ = before
            // flights land (0.5 s timers were decremented by advance)
            // cores on the floor get picked up
            world.bag += world.floor; world.floor = 0
            // inflight cores that just landed: advance() removes them; count them as floor next round
            if let u = brain.phase.unlockBy, brain.phase.spawn != nil, brain.coresInserted < u.count {
                while world.bag > 0, brain.coresInserted < u.count {
                    world.bag -= 1
                    let wasDown = brain.shieldDown
                    let events = brain.coreInserted()
                    model.inserted += 1
                    if !wasDown, model.inserted >= u.count { model.dizzy = u.dizzySec }
                    if let m = absorb(events, dizzyBefore: false, busyBefore: false) { return m }
                }
            }
            if !brain.isImmune {
                let (_, events) = brain.takeDamage(10)
                _ = model.damage(10, dizzyMult: model.mult)
                if let m = absorb(events, dizzyBefore: false, busyBefore: false) { return m }
            }
            if let m = compare() { return m }
            // landed in-flight cores: world.inFlight shrinks inside advance(); recover them as floor
            // (keep the census honest: the brain counted them while in flight)
            world.floor += 0
        }
        if !brain.isDefeated { return fail("soft-lock: not defeated after \(Int(simTime)) s (phase \(brain.phaseIndex), hp \(brain.hp), cores \(brain.coresInserted), census \(world.census), carriers alive \(brain.carriersAlive))") }
        if defeatedEvents != 1 { return fail("defeated events: \(defeatedEvents)") }
        return nil
    }

    @Test func tenThousandRandomBossSequencesStayLegalAndAlwaysFinish() {
        var failures: [String] = []
        var count = 0
        var cov = Coverage()
        for seed in 1...10_000 {
            if let why = Self.run(seed: UInt64(seed), chaosActions: 80, cov: &cov) {
                count += 1
                if failures.count < 6 { failures.append(why) }
            }
        }
        for f in failures { print("BOSSFAIL \(f)") }
        print("BOSSCOV \(cov)")
        #expect(cov.shieldPopped > 1000 && cov.immuneHits > 1000 && cov.rescues > 1000 && cov.dizzy > 1000 && cov.coreLost > 100 && cov.pillar > 100,
                "fuzz must exercise shields, rescues, core losses and pillar dizzies: \(cov)")
        print("BOSSFUZZ 10000 sequences x 80 chaos actions + finisher, failing: \(count)")
        #expect(count == 0, "\(count) failing sequences, first: \(failures.first ?? "")")
    }

    /// Sanity of the model itself: a hero who never inserts cores can never hurt the boss in phase 2.
    @Test func shieldStaysUpWithoutCores() {
        var brain = BossBrain(def: Self.def, startPhase: 1)!
        for _ in 0..<200 { _ = brain.tick(dt: 0.5, census: .init()) }
        for _ in 0..<500 {
            let (r, _) = brain.takeDamage(20)
            #expect(r == .immune)
        }
        #expect(brain.hp == 800)
        // ... and the supply guarantee held the whole time.
        #expect(brain.coresInserted + brain.carriersAlive >= 2)
    }
}
