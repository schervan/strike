import Testing
@testable import Strike

struct SpeechQueueTests {
    static var rules: RulesDef { GeneratedCorpus.data.rules }

    static func queue(_ talk: PixelTalk = .lots) -> SpeechQueue {
        SpeechQueue(rules: rules.pixel, talk: talk, keyCooldowns: StoryDirector.keyCooldowns(rules))
    }

    @Test func pixelRulesComeFromRulesJSON() {
        let p = Self.rules.pixel
        #expect(p.maxChars == 60 && p.queueMax == 2 && p.bubbleBaseSec == 3.0 && p.bubblePerCharSec == 0.04)
        #expect(p.repeatCooldownSec == 10 && p.tapRadius == 80)
        #expect(Self.rules.lowHp.threshold == 25 && Self.rules.lowHp.lineCooldownSec == 60)
        #expect(Self.rules.hints.pointerAfterSec == 60)
    }

    @Test func aThirdQueuedLineDropsTheOldest() {
        var q = Self.queue()
        do { let v = q.enqueue(key: "pixel.a", text: "A", kind: .story); #expect(v == .shown) }
        do { let v = q.enqueue(key: "pixel.b", text: "B", kind: .story); #expect(v == .queued) }
        do { let v = q.enqueue(key: "pixel.c", text: "C", kind: .story); #expect(v == .queued) }
        do { let v = q.enqueue(key: "pixel.d", text: "D", kind: .story); #expect(v == .queued) }   // drops b
        #expect(q.current?.key == "pixel.a")
        #expect(q.pending.map(\.key) == ["pixel.c", "pixel.d"])
        q.dismiss()
        #expect(q.current?.key == "pixel.c")
        q.tick(dt: q.current!.duration + 0.01)
        #expect(q.current?.key == "pixel.d")
        q.tick(dt: 100)
        #expect(q.current == nil && q.pending.isEmpty)
    }

    @Test func durationFormula() {
        let q = Self.queue()
        let text = String(repeating: "x", count: 25)
        #expect(abs(q.duration(for: text) - (3.0 + 0.04 * 25)) < 1e-9)
        var q2 = q
        q2.enqueue(key: "pixel.x", text: text, kind: .story)
        q2.tick(dt: 3.9)
        #expect(q2.current?.key == "pixel.x")
        q2.tick(dt: 0.11)
        #expect(q2.current == nil)
    }

    @Test func linesOverMaxCharsAreRejectedInDebug() {
        var q = Self.queue()
        let long = String(repeating: "y", count: 61)
        #if DEBUG
        do { let v = q.enqueue(key: "pixel.long", text: long, kind: .story); #expect(v == .tooLong) }
        #expect(q.current == nil)
        #endif
        do { let v = q.enqueue(key: "pixel.ok", text: String(repeating: "y", count: 60), kind: .story); #expect(v == .shown) }
    }

    @Test func talkLevelFilter() {
        let kinds: [LineKind] = [.story, .hint, .chatter]
        let expected: [PixelTalk: [LineKind]] = [.lots: [.story, .hint, .chatter], .some: [.story, .hint], .quiet: [.story]]
        for talk in PixelTalk.allCases {
            var q = Self.queue(talk)
            var passed: [LineKind] = []
            for (i, k) in kinds.enumerated() where q.enqueue(key: "pixel.k\(i)", text: "hi", kind: k) != .filtered {
                passed.append(k)
            }
            #expect(passed == expected[talk], "\(talk)")
        }
    }

    @Test func lowHpLinePlaysAtMostOncePer60s() {
        var q = Self.queue()
        let key = StoryDirector.Key.lowHp
        do { let v = q.enqueue(key: key, text: "Ouch!", kind: .chatter); #expect(v == .shown) }
        q.tick(dt: 30)
        do { let v = q.enqueue(key: key, text: "Ouch!", kind: .chatter); #expect(v == .suppressed) }
        q.tick(dt: 29)
        do { let v = q.enqueue(key: key, text: "Ouch!", kind: .chatter); #expect(v == .suppressed) }
        q.tick(dt: 1.01)
        do { let v = q.enqueue(key: key, text: "Ouch!", kind: .chatter); #expect(v == .shown) }
    }

    @Test func repeatGuardForOtherKeysAndStoryExempt() {
        var q = Self.queue()
        do { let v = q.enqueue(key: "pixel.generic.element_on", text: "Yes!", kind: .chatter); #expect(v == .shown) }
        q.tick(dt: 9)
        do { let v = q.enqueue(key: "pixel.generic.element_on", text: "Yes!", kind: .chatter); #expect(v == .suppressed) }
        q.tick(dt: 1.01)
        do { let v = q.enqueue(key: "pixel.generic.element_on", text: "Yes!", kind: .chatter); #expect(v == .shown) }
        q.clear()
        do { let v = q.enqueue(key: "pixel.generic.rescue", text: "Gotcha!", kind: .story); #expect(v == .shown) }
        q.dismiss()
        do { let v = q.enqueue(key: "pixel.generic.rescue", text: "Gotcha!", kind: .story); #expect(v == .shown) }
    }
}
