import Foundation
import GameplayKit
import Testing
@testable import Strike

/// M4-7: GDD §8.3 time-to-power-down per enemy x blaster, recomputed two ways from the shipped JSON:
/// 1. the closed formula of §8.3 (must match the doc table within +-10 %), and
/// 2. a Monte Carlo "scripted scene": the real `WeaponFire` pellet fan and `DamageModel` against an enemy circle at the
///    fight distance, a kid who puts a volley on target with probability `a`, real magazine/reload timing starting at a
///    random point of the magazine (must be within +-25 % of the doc table).
struct BalanceSmokeTests {
    static let data: GameData = try! TestData.load()

    /// GDD §8.3 table (seconds): starter, spread, rapid.
    static let table: [String: (starter: Double, spread: Double, rapid: Double)] = [
        "boltbot": (1.67, 1.31, 1.45), "laserdrone": (1.11, 2.62, 1.69), "slimemutant": (2.22, 1.75, 1.93),
        "slimemutant_small": (0.67, 0.52, 0.58), "shieldandroid": (4.44, 3.50, 3.87), "sporeplant": (2.50, 5.90, 2.32),
    ]
    /// Fight distance per enemy (GDD §8.3 assumptions).
    static let distance: [String: Double] = [
        "boltbot": 120, "laserdrone": 270, "slimemutant": 120, "slimemutant_small": 100, "shieldandroid": 140, "sporeplant": 200,
    ]
    static let weaponIds = ["blaster_starter", "blaster_spread", "blaster_rapid"]

    static func accuracy(_ w: WeaponDef) -> Double { w.pellets > 1 ? 0.85 : 0.6 }

    // MARK: Closed formula

    static func sustainedRate(_ w: WeaponDef) -> Double {
        Double(w.magazineSize) / (Double(w.magazineSize) / w.fireRate + w.reloadSec)
    }

    static func jitterFactor(_ w: WeaponDef, _ e: EnemyDef, d: Double) -> Double {
        guard w.pellets == 1, w.jitterDeg > 0 else { return 1 }
        return min(1, (e.radius + w.projectileRadius) / (d * tan(w.jitterDeg * .pi / 180)))
    }

    static func bubblesOnTarget(_ w: WeaponDef, _ e: EnemyDef, d: Double) -> Double {
        guard w.pellets > 1 else { return 1 }
        let step = tan(w.spreadDeg / Double(w.pellets - 1) * .pi / 180)
        let k = floor((e.radius + w.projectileRadius) / (d * step))
        return min(Double(w.pellets), 1 + 2 * k)
    }

    static func formulaT(_ e: EnemyDef, _ w: WeaponDef) -> Double {
        let d = distance[e.id]!
        var m = 1.0
        if let s = e.shield, let cd = e.attack?.cooldownSec {
            m = (s.dizzySec * s.dizzyDamageMultiplier + (cd - s.dizzySec) * 0.3) / cd
        }
        let dps = sustainedRate(w) * accuracy(w) * jitterFactor(w, e, d: d) * bubblesOnTarget(w, e, d: d) * Double(w.damage) * m
        return Double(e.hp) / dps
    }

    /// Slime family: big + pop-out delay + both smalls one after another.
    static func formulaFamily(_ w: WeaponDef) -> Double {
        let big = data.enemies["slimemutant"]!, small = data.enemies["slimemutant_small"]!, s = big.splitInto!
        return formulaT(big, w) + s.spawnDelaySec + Double(s.count) * formulaT(small, w)
    }

    @Test func closedFormulaMatchesTheGDDTableWithinTenPercent() {
        for (id, row) in Self.table {
            let e = Self.data.enemies[id]!
            let docs = [row.starter, row.spread, row.rapid]
            for (i, wid) in Self.weaponIds.enumerated() {
                let t = Self.formulaT(e, Self.data.weapons[wid]!)
                #expect(abs(t - docs[i]) / docs[i] <= 0.10, "\(id) x \(wid): formula \(String(format: "%.2f", t)) s vs GDD \(docs[i]) s")
            }
        }
        // Family totals from the doc: 3.86 / 3.10 / 3.39.
        for (i, expected) in [3.86, 3.10, 3.39].enumerated() {
            let t = Self.formulaFamily(Self.data.weapons[Self.weaponIds[i]]!)
            #expect(abs(t - expected) / expected <= 0.10, "slime family \(Self.weaponIds[i]): \(t) vs \(expected)")
        }
    }

    @Test func everyBlasterPowersDownEveryEnemyUnderSixSecondsAndWrongBlasterCostsLittle() {
        for (id, _) in Self.table {
            let e = Self.data.enemies[id]!
            let ts = Self.weaponIds.map { Self.formulaT(e, Self.data.weapons[$0]!) }
            #expect(ts.allSatisfy { $0 < 6.0 }, "\(id): \(ts)")
            #expect(ts.max()! / ts.min()! <= 2.6, "\(id): worst/best blaster ratio \(ts.max()! / ts.min()!)")
        }
    }

    // MARK: Monte Carlo scripted scene

    /// One kill. Time of the killing volley (kid fires continuously; magazine phase random).
    static func killTime(_ e: EnemyDef, _ w: WeaponDef, d: Double, rng: GKMersenneTwisterRandomSource, start: Double = 0) -> Double {
        var hp = e.hp
        // Engagement starts at a random point of the shield cycle and of the magazine.
        let cycleLen = e.attack?.cooldownSec ?? 1
        var t = e.shield == nil ? start : start + Double(rng.nextUniform()) * cycleLen
        let t0 = t
        var inMag = 1 + rng.nextInt(upperBound: w.magazineSize)       // random point inside the magazine cycle
        let a = accuracy(w)
        let dt = 1 / w.fireRate
        let cycle = e.shield.flatMap { s in e.attack.map { ($0.cooldownSec, s) } }
        var guardCount = 0
        while hp > 0, guardCount < 100_000 {
            guardCount += 1
            if inMag == 0 { t += w.reloadSec; inMag = w.magazineSize }
            t += dt
            inMag -= 1
            var onTarget = Double(rng.nextUniform()) < a
            var mult = 1.0
            if let (cd, s) = cycle {
                // Shielded: only the dizzy window is open; outside it 30 % of volleys find the side/back.
                let phase = t.truncatingRemainder(dividingBy: cd)
                if phase < s.dizzySec { mult = s.dizzyDamageMultiplier } else { onTarget = onTarget && Double(rng.nextUniform()) < 0.3 }
            }
            guard onTarget else { continue }
            let shot = WeaponFire.shot(def: w, aimAngle: 0, rng: rng)
            for ang in shot.angles where cos(ang) > 0 && abs(d * sin(Double(ang))) <= e.radius + w.projectileRadius {
                hp -= DamageModel.finalDamage(base: w.damage, dizzyMultiplier: mult)
            }
        }
        // Convention: a volley counts at the middle of its interval (the doc formula is continuous).
        return t - t0 - dt / 2
    }

    static func meanKill(_ id: String, _ wid: String, trials: Int = 3000, seed: UInt64 = 7) -> Double {
        let rng = GKMersenneTwisterRandomSource(seed: seed)
        let e = data.enemies[id]!, w = data.weapons[wid]!
        var sum = 0.0
        for _ in 0..<trials { sum += killTime(e, w, d: distance[id]!, rng: rng) }
        return sum / Double(trials)
    }

    @Test func measuredTimeToPowerDownIsWithinTwentyFivePercentOfTheGDDTable() {
        var report: [String] = []
        for (id, row) in Self.table.sorted(by: { $0.key < $1.key }) {
            let docs = [row.starter, row.spread, row.rapid]
            var line = "\(id):"
            for (i, wid) in Self.weaponIds.enumerated() {
                let m = Self.meanKill(id, wid)
                line += " \(wid.dropFirst(8)) \(String(format: "%.2f", m)) (doc \(docs[i]), \(String(format: "%+.0f", (m / docs[i] - 1) * 100)) %)"
                // The doc formula is continuous. When whole hits overshoot the HP a lot (12 HP minis need two 10-damage
                // starter hits = 20), real kills are slower; those pairs get 40 % (QA-016).
                let w = Self.data.weapons[wid]!, e = Self.data.enemies[id]!
                let perVolley = Self.bubblesOnTarget(w, e, d: Self.distance[id]!) * Double(w.damage)
                let overkill = (Double(e.hp) / perVolley).rounded(.up) * perVolley / Double(e.hp)
                let tol = overkill > 1.3 ? 0.40 : 0.25
                #expect(abs(m - docs[i]) / docs[i] <= tol, "\(id) x \(wid) (overkill x\(String(format: "%.2f", overkill))): measured \(String(format: "%.2f", m)) s vs GDD \(docs[i]) s")
            }
            report.append(line)
        }
        for l in report { print("BALANCE \(l)") }
    }

    // MARK: Boss damage time

    @Test func bossDamageTimeMatchesTheGDDPhaseTable() {
        let boss = Self.data.enemies["megamech"]!
        // Phase uptimes from §8.3: phases 1/2 0.7 (dizzy window 4 s at x2 and uptime 1), phase 3 0.6.
        let docs: [String: Double] = ["blaster_starter": 93, "blaster_spread": 72, "blaster_rapid": 80]
        for (wid, doc) in docs {
            let w = Self.data.weapons[wid]!
            let d = 250.0
            let n = Self.bubblesOnTarget(w, boss, d: d)
            let dps = Self.sustainedRate(w) * Self.accuracy(w) * Self.jitterFactor(w, boss, d: d) * n * Double(w.damage)
            var total = 0.0
            for (i, p) in boss.phases!.enumerated() {
                let hp = Double(p.hpFrom - p.hpTo)
                let uptime = i == 2 ? 0.6 : 0.7
                if let u = p.unlockBy {
                    let dizzyDamage = u.dizzySec * dps * u.dizzyDamageMultiplier
                    total += u.dizzySec + max(0, hp - dizzyDamage) / (dps * uptime)
                } else {
                    total += hp / (dps * uptime)
                }
            }
            #expect(abs(total - doc) / doc <= 0.10, "boss \(wid): \(String(format: "%.1f", total)) s vs GDD \(doc) s")
        }
    }
}
