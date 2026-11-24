import Testing
@testable import Strike

/// M4-4: spore slow (GDD §4) with the sporeplant's `attack.slowMultiplier` / `slowSec`.
struct StatusEffectsTests {
    static var attack: EnemyAttackDef { GeneratedCorpus.data.enemies["sporeplant"]!.attack! }

    @Test func sporeSlowIsPointSevenForTwoSecondsAndEnds() throws {
        let m = try #require(Self.attack.slowMultiplier), sec = try #require(Self.attack.slowSec)
        #expect(m == 0.7 && sec == 2.0, "GDD §4 numbers")
        var s = StatusEffects()
        #expect(s.speedMultiplier == 1)
        s.applySlow(multiplier: m, sec: sec)
        #expect(s.speedMultiplier == m)
        s.tick(dt: sec - 0.01)
        #expect(s.speedMultiplier == m)
        s.tick(dt: 0.02)
        #expect(s.speedMultiplier == 1 && !s.isSlowed)
    }

    @Test func aSecondHitRefreshesAndDoesNotStack() {
        let a = Self.attack
        var s = StatusEffects()
        s.applySlow(multiplier: a.slowMultiplier!, sec: a.slowSec!)
        s.tick(dt: 1.5)
        s.applySlow(multiplier: a.slowMultiplier!, sec: a.slowSec!)
        #expect(s.speedMultiplier == a.slowMultiplier!, "no stacking: still × \(a.slowMultiplier!), not squared")
        #expect(abs(s.slowRemaining - a.slowSec!) < 1e-9, "refreshed to the full time")
        s.tick(dt: a.slowSec! - 0.01)
        #expect(s.isSlowed, "the refresh counts from the second hit")
        s.tick(dt: 0.02)
        #expect(!s.isSlowed)
    }

    @Test func rescueClearsTheSlow() {
        var s = StatusEffects()
        s.applySlow(multiplier: 0.7, sec: 2)
        s.clear()
        #expect(s.speedMultiplier == 1 && s.slowRemaining == 0)
    }
}
