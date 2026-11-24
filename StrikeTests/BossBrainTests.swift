import Foundation
import GameplayKit
import Testing
@testable import Strike

/// M4-4: enemy data blocks and the MEGA-MECH brain (GDD §8.1, §9).
struct BossBrainTests {
    static var data: GameData { GeneratedCorpus.data }
    static var mech: EnemyDef { data.enemies["megamech"]! }
    static func brain(phase: Int = 0) throws -> BossBrain { try #require(BossBrain(def: mech, startPhase: phase)) }
    static var shieldPhase: BossPhaseDef { mech.phases![1] }

    // MARK: Data

    @Test func allSevenEnemiesDecodeWithEveryBlock() throws {
        let e = Self.data.enemies
        #expect(e.count == 7)
        let bolt = try #require(e["boltbot"])
        #expect(bolt.behavior == EnemyDef.chaser && bolt.hopChance != nil && bolt.separation != nil)
        let drone = try #require(e["laserdrone"])
        #expect(drone.behavior == EnemyDef.kiter && drone.keepDistance == KeepDistanceDef(min: 220, max: 320))
        #expect(drone.retreatRange == 160 && drone.strafeSec == 1.2 && drone.attack?.projectileSpeed != nil)
        let slime = try #require(e["slimemutant"])
        #expect(slime.behavior == EnemyDef.splitter && slime.splitInto?.enemyId == "slimemutant_small")
        #expect(e["slimemutant_small"]?.behavior == EnemyDef.chaser)
        let shield = try #require(e["shieldandroid"])
        #expect(shield.behavior == EnemyDef.shielded && shield.shield?.arcDeg == 120 && shield.attack?.dashDistance != nil)
        let spore = try #require(e["sporeplant"])
        #expect(spore.behavior == EnemyDef.turret && spore.shyRange == 80 && spore.shySec == 1.0)
        #expect(spore.attack?.slowMultiplier == 0.7 && spore.attack?.slowSec == 2.0)
        let mech = try #require(e["megamech"])
        #expect(mech.behavior == EnemyDef.boss && mech.rescueResetsToPhaseTop == true)
        let phases = try #require(mech.phases)
        #expect(phases.map(\.id) == ["stomp", "shield", "overload"])
        #expect(phases[1].spawn?.carryItemFirst == "energycore" && phases[1].unlockBy?.count == 2)
        #expect(phases[1].unlockBy?.elementType == .machine)
        #expect(phases[2].effectiveCooldownMultiplier == 0.75)
        #expect(phases[2].attacks.contains { $0.type == BossAttackDef.dash && $0.pillarDizzySec == 2.5 })
    }

    @Test func bossPhasesChainFromHpToZero() {
        let p = Self.mech.phases!
        #expect([p[0].hpFrom] + p.map(\.hpTo) == [1200, 800, 400, 0])
        #expect(Self.mech.phaseChainProblems.isEmpty)
        #expect(Self.data.validateEnemies().isEmpty, "\(Self.data.validateEnemies())")
    }

    @Test func aGapInThePhaseChainIsReported() throws {
        let json = """
        {"id":"x","nameKey":"k","behavior":"boss","hp":100,"moveSpeed":0,"radius":10,"flying":false,"contactDamage":0,
         "detectRange":1,"threatCost":0,"scoreValue":0,"lootTableId":"t","phases":[
          {"id":"a","hpFrom":100,"hpTo":60,"immune":false,"attacks":[]},
          {"id":"b","hpFrom":50,"hpTo":0,"immune":false,"attacks":[]}]}
        """
        let def = try JSONDecoder().decode(EnemyDef.self, from: Data(json.utf8))
        #expect(def.phaseChainProblems.count == 1)
    }

    // MARK: Phases and shield

    @Test func phasesChangeAt800And400AndPhase2IsImmuneUntilBothCoresAreIn() throws {
        var b = try Self.brain()
        var seen: [BossBrain.Event] = []
        while b.phaseIndex == 0 { seen += b.takeDamage(37).events }
        #expect(b.hp == 800, "each phase starts at its top")
        #expect(seen.contains(.phaseStarted(index: 1, id: "shield")))
        #expect(b.isImmune)
        let v14 = b.takeDamage(50)
        #expect(v14.result == .immune && b.hp == 800)
        let v15 = b.coreInserted()
        #expect(v15.isEmpty && b.isImmune, "one core is not enough")
        let pop = b.coreInserted()
        let u = try #require(Self.shieldPhase.unlockBy)
        #expect(pop == [.shieldPopped, .dizzyStarted(sec: u.dizzySec)])
        #expect(!b.isImmune && b.isDizzy && b.damageMultiplier == u.dizzyDamageMultiplier)
        #expect(u.dizzySec == 4 && u.dizzyDamageMultiplier == 2)
        let v16 = b.takeDamage(10)
        #expect(v16.result == .hit(damage: 20), "× 2 while dizzy")
        var t = 0.0, ended = false
        while t < u.dizzySec + 0.2 { ended = ended || b.tick(dt: 0.1).contains(.dizzyEnded); t += 0.1 }
        #expect(ended && !b.isDizzy)
        let v17 = b.takeDamage(10)
        #expect(v17.result == .hit(damage: 10))
        // Vulnerable down to 400, then overload.
        while b.phaseIndex == 1 { _ = b.takeDamage(33) }
        #expect(b.phaseIndex == 2 && b.hp == 400 && b.phase.id == "overload")
        while !b.isDefeated { _ = b.takeDamage(45) }
        #expect(b.hp == 0)
        let v18 = b.takeDamage(10)
        #expect(v18.result == .immune, "nothing after the power-down")
    }

    @Test func attackCooldownsRunStartToStartAndPhase3IsTimesPointSevenFive() throws {
        for phase in [0, 2] {
            var b = try Self.brain(phase: phase)
            let mult = b.phase.effectiveCooldownMultiplier
            var starts: [String: [Double]] = [:]
            var t = 0.0
            while t < 60 {
                for case .attack(let a) in b.tick(dt: 0.05) { starts[a.type, default: []].append(t) }
                t += 0.05
            }
            for a in b.phase.attacks {
                let s = try #require(starts[a.type], "\(a.type) never started in phase \(phase)")
                #expect(s.count >= 3)
                for (x, y) in zip(s, s.dropFirst()) {
                    #expect(y - x >= a.cooldownSec * mult - 1e-6, "\(a.type): \(y - x) s")
                }
            }
        }
        var b = try Self.brain(phase: 2)
        #expect(b.phase.effectiveCooldownMultiplier == 0.75)
        var first: BossAttackDef?
        while first == nil { for case .attack(let a) in b.tick(dt: 0.05) { first = a } }
        let i = try #require(b.phase.attacks.firstIndex(of: first!))
        #expect(abs(b.cooldowns[i] - first!.cooldownSec * 0.75) < 1e-9)
    }

    @Test func aDashIntoAPillarMakesItDizzyAndStopsAttacks() throws {
        var b = try Self.brain(phase: 2)
        var dash: BossAttackDef?
        var t = 0.0
        while dash == nil, t < 60 {
            for case .attack(let a) in b.tick(dt: 0.05) where a.type == BossAttackDef.dash { dash = a }
            t += 0.05
        }
        let d = try #require(dash)
        let v19 = b.dashHitPillar(d)
        #expect(v19 == [.dizzyStarted(sec: 2.5)])
        var during: [BossBrain.Event] = []
        t = 0
        while b.isDizzy {
            // The step that ends the dizzy may start the next attack right after `dizzyEnded`.
            let e = b.tick(dt: 0.05)
            during += e.prefix { $0 != .dizzyEnded }
            t += 0.05
        }
        #expect(abs(t - 2.5) < 0.1)
        #expect(!during.contains { if case .attack = $0 { true } else { false } }, "no attack while dizzy")
    }

    // MARK: Spawns and cores

    /// Mirrors the brain's spawn events like the scene would.
    struct World {
        var alive: [Int: Bool] = [:]
        var bag = 0, floor = 0
        var spawnTimes: [(Double, Bool)] = []

        var census: BossBrain.CoreCensus { .init(inBag: bag, onFloor: floor) }

        mutating func apply(_ events: [BossBrain.Event], at t: Double) {
            for e in events {
                switch e {
                case .spawn(let id, _, let item): alive[id] = item != nil; spawnTimes.append((t, item != nil))
                case .giveItem(let id, _): alive[id] = true
                default: break
                }
            }
        }
    }

    @Test func spawnsEvery8sMax4AliveAndTheFirstTwoCarryCores() throws {
        var b = try Self.brain(phase: 1)
        let s = try #require(Self.shieldPhase.spawn)
        #expect(s.everySec == 8 && s.maxAlive == 4 && s.carryCount == 2)
        var w = World()
        var t = 0.0
        while t < 40 {
            w.apply(b.tick(dt: 0.1, census: w.census), at: t)
            #expect(b.spawns.count <= s.maxAlive)
            t += 0.1
        }
        #expect(w.spawnTimes.count == 4)
        #expect(w.spawnTimes.prefix(2).allSatisfy { $0.1 }, "the first two carry cores")
        #expect(w.spawnTimes.dropFirst(2).allSatisfy { !$0.1 })
        let regular = w.spawnTimes.dropFirst(2).map(\.0)
        #expect(abs(regular[0] - s.everySec) < 0.15 && abs(regular[1] - 2 * s.everySec) < 0.15, "\(regular)")
        // One powers down: the next comes as soon as its timer allows.
        let victim = w.alive.keys.max()!
        b.spawnPoweredDown(id: victim); w.alive[victim] = nil
        w.apply(b.tick(dt: 0.1, census: w.census), at: t)
        #expect(b.spawns.count == s.maxAlive)
    }

    @Test func afterALostCoreTheNextSpawnCarriesOne() throws {
        var b = try Self.brain(phase: 1)
        var w = World()
        w.apply(b.tick(dt: 0.1, census: w.census), at: 0)
        let carrier = try #require(w.alive.first { $0.value }?.key)
        // The carrier powers down and drops its core; then the core is lost.
        b.spawnPoweredDown(id: carrier); w.alive[carrier] = nil; w.floor = 1
        w.apply(b.tick(dt: 0.1, census: w.census), at: 0.1)
        #expect(w.spawnTimes.count == 2, "no deficit while the core lies on the floor")
        w.floor = 0
        w.apply(b.tick(dt: 0.1, census: w.census), at: 0.2)
        #expect(w.spawnTimes.count == 3 && w.spawnTimes.last!.1, "the next spawn carries a core")
    }

    @Test func atMaxAliveALivingSpawnStartsCarrying() throws {
        var b = try Self.brain(phase: 1)
        var w = World()
        var t = 0.0
        while b.spawns.count < 4 { w.apply(b.tick(dt: 0.5, census: w.census), at: t); t += 0.5 }
        // Both carriers power down and drop their cores; plain boltbots fill up to 4 again.
        for (id, carries) in w.alive where carries { b.spawnPoweredDown(id: id); w.alive[id] = nil; w.floor += 1 }
        while b.spawns.count < 4 { w.apply(b.tick(dt: 0.5, census: w.census), at: t); t += 0.5 }
        #expect(!w.alive.values.contains(true))
        // Both cores are lost: no room to spawn, so two living boltbots start carrying.
        w.floor = 0
        let events = b.tick(dt: 0.1, census: w.census)
        w.apply(events, at: t)
        #expect(events.filter { if case .giveItem = $0 { true } else { false } }.count == 2)
        #expect(w.alive.values.filter { $0 }.count == 2 && b.spawns.count == 4)
    }

    /// 1,000 random event sequences: until both cores are in, inserted + bag + floor + carried ≥ 2
    /// after every brain tick.
    @Test func aCoreIsAlwaysObtainableUntilBothAreInserted() throws {
        let needed = try #require(Self.shieldPhase.unlockBy?.count)
        var popped = 0
        for seed in 0..<1000 {
            let rng = GKMersenneTwisterRandomSource(seed: UInt64(seed))
            var b = try Self.brain(phase: 1)
            var w = World()
            var t = 0.0
            for _ in 0..<300 {
                switch rng.nextInt(upperBound: 9) {
                case 0, 1:
                    let ids = w.alive.keys.sorted()
                    if !ids.isEmpty {
                        let id = ids[rng.nextInt(upperBound: ids.count)]
                        if w.alive[id] == true { w.floor += 1 }
                        w.alive[id] = nil
                        b.spawnPoweredDown(id: id)
                    }
                case 2: if w.floor > 0 { w.floor -= 1; w.bag += 1 }
                case 3: if w.bag > 0 { w.bag -= 1; _ = b.coreInserted() }
                case 4: if w.floor > 0 { w.floor -= 1 }            // lost (unreachable)
                case 5: if w.bag > 0, rng.nextInt(upperBound: 3) == 0 { w.bag -= 1 }
                case 6: b.rescueReset()
                case 7: _ = b.takeDamage(1 + rng.nextInt(upperBound: 30))
                default: break
                }
                let dt = [0.05, 0.25, 1.0, 3.0][rng.nextInt(upperBound: 4)]
                w.apply(b.tick(dt: dt, census: w.census), at: t)
                t += dt
                if Set(w.alive.keys) != Set(b.spawns.keys) { Issue.record("seed \(seed): spawn mirror out of sync"); return }
                if b.shieldDown || b.phaseIndex != 1 { popped += 1; break }
                let have = b.coresInserted + w.bag + w.floor + w.alive.values.filter { $0 }.count
                if have < needed { Issue.record("seed \(seed): only \(have) cores obtainable"); return }
            }
        }
        print("BOSS core fuzz: 1000 sequences, shield popped in \(popped)")
    }

    // MARK: Retries

    @Test func rescueResetRestoresThePhaseTopAndKeepsInsertedCores() throws {
        var b = try Self.brain()
        _ = b.takeDamage(100)
        b.rescueReset()
        #expect(b.hp == 1200)
        b = try Self.brain(phase: 1)
        _ = b.coreInserted(); _ = b.coreInserted()
        _ = b.takeDamage(150)
        #expect(b.hp < 800)
        b.rescueReset()
        #expect(b.hp == 800 && b.coresInserted == 2 && b.shieldDown && !b.isImmune && !b.isDizzy)
        var c = try Self.brain(phase: 1)
        _ = c.coreInserted()
        c.rescueReset()
        #expect(c.coresInserted == 1 && c.isImmune)
    }

    @Test func debugNextPhaseWalksToTheEnd() throws {
        var b = try Self.brain()
        let v20 = b.debugNextPhase()
        #expect(v20 == [.phaseStarted(index: 1, id: "shield")])
        let v21 = b.debugNextPhase()
        #expect(v21 == [.phaseStarted(index: 2, id: "overload")])
        let v22 = b.debugNextPhase()
        #expect(v22 == [.defeated])
        #expect(b.isDefeated && b.hpRatio == 0)
        #expect(b.phaseNotches.map { ($0 * 1200).rounded() } == [800, 400])
    }
}
