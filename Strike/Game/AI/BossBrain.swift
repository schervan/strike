import Foundation

/// MEGA-MECH Unit Zero (GDD §9), pure. The scene feeds it time, hero hits, core machine
/// inserts, spawn power-downs and a census of the energy cores; it answers with events (attack
/// telegraphs, spawns, shield, dizzy, phase changes, defeat).
///
/// - Phase from HP: damage never crosses a phase border in one hit, so every phase starts at its
///   `hpFrom`. The last phase ends at 0 → `defeated`.
/// - Attacks: one at a time, first ready in list order; each has its own cooldown (start to
///   start) × the phase's `cooldownMultiplier`. No new attack while dizzy. Phase start: attack
///   `i` is ready after `alertSec` + the telegraphs of the attacks before it.
/// - Phase `spawn`: one `enemyId` every `everySec` while fewer than `maxAlive` live (the first
///   right at phase start). Core guarantee (GDD §9 "always ≥ 1 core reachable"): while the shield
///   is up, if inserted + bag + floor + in flight + carried < `unlockBy.count`, a carrier spawns
///   at once (or, at `maxAlive`, a living spawn starts carrying). So the first `carryCount`
///   spawns carry, and after a lost core the next spawn carries one.
/// - `unlockBy`: immune until `count` cores are inserted → shield pops, dizzy `dizzySec` with
///   × `dizzyDamageMultiplier`; the phase then continues vulnerable to its `hpTo`.
/// - Dash into a pillar → dizzy `pillarDizzySec`.
/// - `rescueReset()` (QA-016, owner decision): the attack timing starts over (the running attack
///   ends, every cooldown restarts from full). HP stays, unless `rescueResetsToPhaseTop` is true (then HP
///   goes back to the phase's `hpFrom`). Inserted cores and a running dizzy stay.
nonisolated struct BossBrain: Sendable, Equatable {
    /// Energy cores the brain cannot see itself.
    struct CoreCensus: Sendable, Equatable {
        var inBag: Int
        var onFloor: Int
        /// Cores between owners (e.g. a carrier's drop still popping out).
        var inFlight: Int

        init(inBag: Int = 0, onFloor: Int = 0, inFlight: Int = 0) {
            self.inBag = inBag
            self.onFloor = onFloor
            self.inFlight = inFlight
        }

        var total: Int { inBag + onFloor + inFlight }
    }

    enum Event: Sendable, Equatable {
        case phaseStarted(index: Int, id: String)
        /// The telegraph of `attack` starts now.
        case attack(BossAttackDef)
        /// Spawn one `enemyId`; `carriesItem` is a guaranteed drop (energy core) or nil.
        case spawn(id: Int, enemyId: String, carriesItem: String?)
        /// The living spawn `id` now carries `itemId`.
        case giveItem(id: Int, itemId: String)
        case shieldPopped
        case dizzyStarted(sec: Double)
        case dizzyEnded
        case defeated
    }

    enum HitResult: Sendable, Equatable {
        case immune
        case hit(damage: Int)
        case defeated
    }

    let def: EnemyDef
    let phases: [BossPhaseDef]
    private(set) var hp: Int
    private(set) var phaseIndex = 0
    private(set) var coresInserted = 0
    private(set) var dizzyRemaining: Double = 0
    private(set) var dizzyMultiplier: Double = 1
    private(set) var cooldowns: [Double] = []
    /// Seconds left of the running attack (telegraph + active part); 0 = free.
    private(set) var busyRemaining: Double = 0
    private(set) var spawnTimer: Double = 0
    /// Living spawns: id → carries a core.
    private(set) var spawns: [Int: Bool] = [:]
    private(set) var carriersIssued = 0
    private(set) var isDefeated = false
    private var nextSpawnId = 1

    /// Nil when `def` has no phases.
    init?(def: EnemyDef, startPhase: Int = 0) {
        guard let phases = def.phases, !phases.isEmpty else { return nil }
        self.def = def
        self.phases = phases
        hp = phases[0].hpFrom
        _ = enterPhase(min(max(0, startPhase), phases.count - 1))
    }

    // MARK: State

    var phase: BossPhaseDef { phases[phaseIndex] }
    var isDizzy: Bool { dizzyRemaining > 0 }
    var isBusy: Bool { busyRemaining > 0 }
    /// The current phase's shield puzzle is solved.
    var shieldDown: Bool { phase.unlockBy.map { coresInserted >= $0.count } ?? false }
    var isImmune: Bool { phase.immune && !shieldDown }
    var damageMultiplier: Double { isDizzy ? dizzyMultiplier : 1 }
    var hpRatio: Double { Double(hp) / Double(max(1, phases[0].hpFrom)) }
    /// Phase borders as fractions of max HP (boss bar notches).
    var phaseNotches: [Double] { phases.dropLast().map { Double($0.hpTo) / Double(max(1, phases[0].hpFrom)) } }
    var carriersAlive: Int { spawns.values.filter { $0 }.count }

    /// Telegraph + active part of an attack (how long the boss is busy with it).
    static func busySec(_ a: BossAttackDef) -> Double {
        let active: Double
        switch a.type {
        case BossAttackDef.stomp: active = a.effectiveWaveSec
        case BossAttackDef.laserSweep: active = a.effectiveSweepSec
        case BossAttackDef.dash: active = (a.dashSpeed ?? 0) > 0 ? a.range / a.dashSpeed! : 0
        default: active = 0
        }
        return a.telegraphSec + active
    }

    // MARK: Time

    mutating func tick(dt: Double, census: CoreCensus = CoreCensus()) -> [Event] {
        guard !isDefeated else { return [] }
        var events: [Event] = []
        if isDizzy {
            dizzyRemaining = max(0, dizzyRemaining - dt)
            if !isDizzy {
                dizzyMultiplier = 1
                events.append(.dizzyEnded)
            }
        }
        busyRemaining = max(0, busyRemaining - dt)
        for i in cooldowns.indices { cooldowns[i] = max(0, cooldowns[i] - dt) }
        if !isBusy, !isDizzy, let i = cooldowns.firstIndex(where: { $0 <= 0 }) {
            let a = phase.attacks[i]
            cooldowns[i] = a.cooldownSec * phase.effectiveCooldownMultiplier
            busyRemaining = Self.busySec(a)
            events.append(.attack(a))
        }
        events += tickSpawns(dt: dt, census: census)
        return events
    }

    private mutating func tickSpawns(dt: Double, census: CoreCensus) -> [Event] {
        guard let s = phase.spawn else { return [] }
        var events: [Event] = []
        // Core guarantee first (it may spawn right away).
        if let item = coreItem {
            var deficit = coresNeeded - (census.total + carriersAlive)
            while deficit > 0 {
                if spawns.count < s.maxAlive {
                    events.append(spawn(s, carrying: item))
                    spawnTimer = s.everySec
                } else if let id = spawns.filter({ !$0.value }).keys.min() {
                    spawns[id] = true
                    carriersIssued += 1
                    events.append(.giveItem(id: id, itemId: item))
                } else {
                    break
                }
                deficit -= 1
            }
        }
        spawnTimer -= dt
        if spawnTimer <= 0, spawns.count < s.maxAlive {
            let carry = coreItem.flatMap { carriersIssued < (s.carryCount ?? 0) ? $0 : nil }
            events.append(spawn(s, carrying: carry))
            spawnTimer = s.everySec
        }
        return events
    }

    /// The item carriers bring while the shield puzzle is open, else nil.
    private var coreItem: String? {
        guard let u = phase.unlockBy, !shieldDown, let s = phase.spawn else { return nil }
        return s.carryItemFirst ?? u.requiresItem
    }

    private var coresNeeded: Int { max(0, (phase.unlockBy?.count ?? 0) - coresInserted) }

    private mutating func spawn(_ s: BossSpawnDef, carrying item: String?) -> Event {
        let id = nextSpawnId
        nextSpawnId += 1
        spawns[id] = item != nil
        if item != nil { carriersIssued += 1 }
        return .spawn(id: id, enemyId: s.enemyId, carriesItem: item)
    }

    // MARK: Scene reports

    /// A hero shot hit the boss.
    mutating func takeDamage(_ base: Int) -> (result: HitResult, events: [Event]) {
        guard !isDefeated else { return (.immune, []) }
        guard !isImmune else { return (.immune, []) }
        let dmg = DamageModel.finalDamage(base: base, dizzyMultiplier: damageMultiplier)
        hp = max(phase.hpTo, hp - dmg)
        guard hp <= phase.hpTo else { return (.hit(damage: dmg), []) }
        let events = advancePhase()
        return (isDefeated ? .defeated : .hit(damage: dmg), events)
    }

    /// A spawn powered down (its carried core, if any, is now the scene's: floor or in flight).
    mutating func spawnPoweredDown(id: Int) {
        spawns[id] = nil
    }

    /// A core went into a core machine.
    mutating func coreInserted() -> [Event] {
        let wasDown = shieldDown
        coresInserted += 1
        guard let u = phase.unlockBy, !wasDown, shieldDown else { return [] }
        busyRemaining = 0
        return [.shieldPopped] + startDizzy(sec: u.dizzySec, multiplier: u.dizzyDamageMultiplier)
    }

    /// The running attack ended early (dash stopped, attack cancelled).
    mutating func attackFinished() {
        busyRemaining = 0
    }

    /// The phase-3 dash ran into a pillar.
    mutating func dashHitPillar(_ attack: BossAttackDef) -> [Event] {
        busyRemaining = 0
        return startDizzy(sec: attack.pillarDizzySec ?? 0, multiplier: attack.pillarDizzyDamageMultiplier ?? 1)
    }

    /// Hero rescue in the arena (GDD §9 kid-safe retries, QA-016).
    mutating func rescueReset() {
        guard !isDefeated else { return }
        if def.rescueResetsToPhaseTop ?? false { hp = phase.hpFrom }
        busyRemaining = 0
        // As if every attack had just started (GDD §9, designer M4 fix round).
        cooldowns = phase.attacks.map { $0.cooldownSec * phase.effectiveCooldownMultiplier }
    }

    /// `debug.bossNextPhase`: jump to the next phase (or defeat in the last one).
    mutating func debugNextPhase() -> [Event] {
        guard !isDefeated else { return [] }
        hp = phase.hpTo
        return advancePhase()
    }

    // MARK: Phases

    private mutating func advancePhase() -> [Event] {
        guard phaseIndex + 1 < phases.count else {
            hp = 0
            isDefeated = true
            busyRemaining = 0
            dizzyRemaining = 0
            return [.defeated]
        }
        return enterPhase(phaseIndex + 1)
    }

    private mutating func enterPhase(_ i: Int) -> [Event] {
        phaseIndex = i
        hp = phase.hpFrom
        // QA-021: each phase's shield puzzle counts its own cores.
        coresInserted = 0
        dizzyRemaining = 0
        dizzyMultiplier = 1
        busyRemaining = 0
        spawnTimer = 0
        carriersIssued = 0
        resetCooldowns()
        return [.phaseStarted(index: i, id: phase.id)]
    }

    private mutating func resetCooldowns() {
        var t = def.effectiveAlertSec
        cooldowns = phase.attacks.map { a in
            defer { t += a.telegraphSec }
            return t
        }
    }

    private mutating func startDizzy(sec: Double, multiplier: Double) -> [Event] {
        guard sec > 0 else { return [] }
        dizzyRemaining = sec
        dizzyMultiplier = multiplier
        return [.dizzyStarted(sec: sec)]
    }
}
