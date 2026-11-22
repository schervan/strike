import Testing
@testable import Strike

struct HealthTests {
    @Test func damageReducesHp() {
        var h = Health(max: 100, invulnerableSec: 0.8)
        let r6 = h.applyDamage(8)
        #expect(r6 == .hit)
        #expect(h.current == 92)
    }

    @Test func secondHitInsideWindowIgnored() {
        var h = Health(max: 100, invulnerableSec: 0.8)
        _ = h.applyDamage(8)
        h.tick(dt: 0.5)
        let r15 = h.applyDamage(8)
        #expect(r15 == .ignored)
        #expect(h.current == 92)
        h.tick(dt: 0.31)
        let r19 = h.applyDamage(8)
        #expect(r19 == .hit)
        #expect(h.current == 84)
    }

    @Test func clampsAtZeroAndDepletes() {
        var h = Health(max: 30)
        let r26 = h.applyDamage(25)
        #expect(r26 == .hit)
        let r28 = h.applyDamage(25)
        #expect(r28 == .depleted)
        #expect(h.current == 0)
        let r31 = h.applyDamage(5)
        #expect(r31 == .ignored)
    }

    @Test func healCapsAtMax() {
        var h = Health(max: 100)
        _ = h.applyDamage(30)
        let r38 = h.heal(50)
        #expect(r38 == 30)
        #expect(h.current == 100)
    }

    @Test func resetRestoresAndProtects() {
        var h = Health(max: 100, invulnerableSec: 0.8)
        _ = h.applyDamage(100)
        h.reset(invulnerableFor: 2)
        #expect(h.current == 100)
        h.tick(dt: 1.9)
        #expect(h.isInvulnerable)
        h.tick(dt: 0.2)
        #expect(!h.isInvulnerable)
    }
}
