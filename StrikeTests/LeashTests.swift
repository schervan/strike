import CoreGraphics
import Testing
@testable import Strike

struct LeashTests {
    static let rules = LeashRulesDef(rangeFactor: 2.0, returnAfterSec: 4.0)
    static let detect = 360.0

    @Test func triggersAfterReturnAfterSecBeyondRange() {
        var l = Leash(rules: Self.rules)
        #expect(l.range(detectRange: Self.detect) == 720)
        // Inside the range nothing happens.
        for _ in 0..<600 { let v = l.update(dt: 1.0 / 60, distanceToHero: 700, detectRange: Self.detect); #expect(!v) }
        // 3.9 s beyond, then back in range: the timer resets.
        for _ in 0..<234 { let v = l.update(dt: 1.0 / 60, distanceToHero: 800, detectRange: Self.detect); #expect(!v) }
        do { let v = l.update(dt: 1.0 / 60, distanceToHero: 500, detectRange: Self.detect); #expect(!v) }
        #expect(l.outOfRangeTime == 0)
        // Continuous 4 s beyond triggers exactly once.
        var fired = 0
        for _ in 0..<240 { if l.update(dt: 1.0 / 60, distanceToHero: 800, detectRange: Self.detect) { fired += 1 } }
        #expect(fired == 1)
        #expect(l.isReturning)
        do { let v = l.update(dt: 1, distanceToHero: 2000, detectRange: Self.detect); #expect(!v) }
    }

    @Test func restoresFullHPAtHome() {
        var l = Leash(rules: Self.rules)
        var hp = Health(max: 30)
        _ = hp.applyDamage(20)
        #expect(hp.current == 10)
        _ = l.update(dt: 5, distanceToHero: 1000, detectRange: Self.detect)
        #expect(l.isReturning)
        let home = CGPoint(x: 640, y: 320)
        do { let v = l.updateReturn(position: CGPoint(x: 400, y: 320), home: home, health: &hp); #expect(!v) }
        #expect(hp.current == 10)
        do { let v = l.updateReturn(position: CGPoint(x: 630, y: 330), home: home, health: &hp); #expect(v) }
        #expect(hp.current == 30)
        #expect(!l.isReturning)
    }

    @Test func usesRulesJSONNumbers() {
        let r = GeneratedCorpus.data.rules.leash
        var l = Leash(rules: r)
        let d = GeneratedCorpus.data.enemies["boltbot"]!.detectRange
        do { let v = l.update(dt: r.returnAfterSec * 0.99, distanceToHero: r.rangeFactor * d + 1, detectRange: d); #expect(!v) }
        do { let v = l.update(dt: r.returnAfterSec * 0.02, distanceToHero: r.rangeFactor * d + 1, detectRange: d); #expect(v) }
    }

    @Test func forceReturnAndReset() {
        var l = Leash(rules: Self.rules)
        l.forceReturn()
        #expect(l.isReturning)
        l.reset()
        #expect(!l.isReturning && l.outOfRangeTime == 0)
    }
}
