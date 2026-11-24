import Testing
@testable import Strike

struct RescueRulesTests {
    static var data: GameData { GeneratedCorpus.data }

    struct Rig {
        let data = RescueRulesTests.data
        var health = Health(max: RescueRulesTests.data.hero.maxHp, invulnerableSec: RescueRulesTests.data.hero.invulnerableSec)
        var loadout = Loadout(start: StartLoadoutDef(weaponId: "blaster_starter", magazine: 0, reserve: 0),
                              weapons: RescueRulesTests.data.weapons)
        var inventory = Inventory(items: RescueRulesTests.data.items, rules: RescueRulesTests.data.rules.inventory)
        var session = LevelSession(levelId: "l2", seed: 7, startCheckpointId: "cp_0")

        var starter: WeaponDef { data.weapons["blaster_starter"]! }

        mutating func rescue(_ enemies: [RescueEnemy] = []) -> RescueOutcome {
            RescueRules.apply(health: &health, loadout: &loadout, session: &session, enemies: enemies,
                              starter: starter, rules: data.rules.rescue,
                              invulnerableSec: data.hero.effectiveRespawnInvulnerableSec)
        }
    }

    @Test func hpBackToMaxAndInvulnerabilitySet() {
        var r = Rig()
        _ = r.health.applyDamage(1_000)
        #expect(r.health.isDepleted)
        let o = r.rescue()
        #expect(r.health.current == r.health.max)
        #expect(r.health.invulnerableRemaining == Self.data.hero.effectiveRespawnInvulnerableSec)
        #expect(o.invulnerableSec == 2)
    }

    @Test func starterToppedUpOthersUnchanged() throws {
        var r = Rig()
        _ = r.inventory.add("healpack", count: 2)
        _ = r.inventory.add("fuse", count: 1)
        r.inventory.assignQuick(itemId: "fuse", to: 2)
        r.loadout.ammo.add("ammo_spread", amount: 9)
        r.session.collectDatachip("dc_1", score: 250)
        let invBefore = r.inventory
        let o = r.rescue()
        let min = Self.data.rules.rescue.starterMinMagazine
        #expect(r.loadout.totalAmmo(r.starter) == min)
        #expect(r.loadout.magazine(r.starter.id) >= 1)
        #expect(o.starterRoundsAdded == min)
        #expect(r.inventory == invBefore)                             // bag + quick slots
        #expect(r.loadout.ammo.reserve("ammo_spread") == 9)
        #expect(r.session.datachipsFound == ["dc_1"])
        // Already above one magazine: nothing added.
        r.loadout.ammo.add("ammo_starter", amount: 40)
        let before = r.loadout.totalAmmo(r.starter)
        do { let v = r.rescue().starterRoundsAdded; #expect(v == 0) }
        #expect(r.loadout.totalAmmo(r.starter) == before)
    }

    @Test func puzzleStatesKept() {
        var r = Rig()
        var puzzle = PuzzleStateTests.state()
        var bag = PuzzleStateTests.bag()
        _ = puzzle.interact("button_0", carrier: &bag)
        _ = puzzle.interact("button_g", carrier: &bag)
        let before = puzzle
        _ = r.rescue()
        #expect(puzzle == before)                                     // rescue never touches it
        #expect(puzzle.isOn("button_0") && puzzle.isGateOpen("gate_2"))
    }

    @Test func poweredDownStayDownLivingOnesAreReset() {
        var r = Rig()
        let o = r.rescue([RescueEnemy(id: "e1", isPoweredDown: false), RescueEnemy(id: "e2", isPoweredDown: true),
                          RescueEnemy(id: "e3", isPoweredDown: false)])
        #expect(o.enemiesToReset == ["e1", "e3"])
        #expect(o.checkpointId == "cp_0")
    }

    @Test func rescuesCounterIncrements() {
        var r = Rig()
        _ = r.rescue()
        _ = r.rescue()
        #expect(r.session.rescues == 2)
    }

    @Test func timelineFromRulesJSON() {
        let rules = Self.data.rules.rescue
        #expect(rules.slowMoScale == 0.3 && rules.slowMoSec == 0.6 && rules.beamSec == 0.8)
        #expect(RescueRules.phase(at: 0, rules: rules) == .slowMo)
        #expect(RescueRules.timeScale(at: 0.3, rules: rules) == 0.3)
        #expect(RescueRules.phase(at: 0.7, rules: rules) == .beam)
        #expect(RescueRules.timeScale(at: 0.7, rules: rules) == 1)
        #expect(RescueRules.phase(at: 1.41, rules: rules) == .done)
        #expect(abs(RescueRules.duration(rules) - 1.4) < 1e-9)
    }
}
