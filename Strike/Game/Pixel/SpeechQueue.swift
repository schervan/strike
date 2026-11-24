import Foundation

/// How important a Pixel line is, for the "Pixel talk" filter (GDD §13).
nonisolated enum LineKind: String, Sendable, Equatable, CaseIterable {
    /// Level beats, intro/outro and the rescue line: always shown; exempt from the repeat guard.
    case story
    /// `hint_*`, `need_*`, `idle`: shown on `lots` and `some`.
    case hint
    /// Everything else (generic comments, enemy tips): `lots` only.
    case chatter

    func isAllowed(_ talk: PixelTalk) -> Bool {
        switch talk {
        case .lots: true
        case .some: self != .chatter
        case .quiet: self == .story
        }
    }
}

/// One line in Pixel's top-centre bubble. `id` is unique per queue (SwiftUI transitions).
nonisolated struct PixelLine: Sendable, Equatable, Identifiable {
    let id: Int
    let key: String
    /// Localized text (the queue measures its length).
    let text: String
    let kind: LineKind
    let duration: Double
}

nonisolated enum EnqueueResult: Sendable, Equatable {
    /// On screen now.
    case shown
    /// Waiting behind the current line (an older waiting line may have been dropped).
    case queued
    /// Removed by the talk-level filter.
    case filtered
    /// Same key inside its per-key cooldown, or already on screen / waiting.
    case suppressed
    /// DEBUG only: longer than `pixel.maxChars`.
    case tooLong
}

/// Pixel's speech (GDD §13): one line at a time, at most `queueMax` waiting (older dropped),
/// on screen for `bubbleBaseSec + bubblePerCharSec × length`, talk-level filter, repeat guard
/// (`repeatCooldownSec` per key, story exempt) with per-key overrides (low HP 60 s).
nonisolated struct SpeechQueue: Sendable, Equatable {
    let rules: PixelRulesDef
    var talk: PixelTalk
    /// Per-key repeat cooldowns that replace `rules.repeatCooldownSec` (e.g. low HP).
    let keyCooldowns: [String: Double]

    private(set) var current: PixelLine?
    private(set) var pending: [PixelLine] = []
    /// Time left for `current`.
    private(set) var remaining: Double = 0
    /// Queue clock (seconds of `tick`).
    private(set) var now: Double = 0
    private var lastShown: [String: Double] = [:]
    private var nextId = 1

    init(rules: PixelRulesDef, talk: PixelTalk = .lots, keyCooldowns: [String: Double] = [:]) {
        self.rules = rules
        self.talk = talk
        self.keyCooldowns = keyCooldowns
    }

    /// Repeat guard for a key (story lines are exempt).
    func cooldown(for key: String) -> Double { keyCooldowns[key] ?? rules.repeatCooldownSec }

    func duration(for text: String) -> Double {
        rules.bubbleBaseSec + rules.bubblePerCharSec * Double(text.count)
    }

    @discardableResult
    mutating func enqueue(key: String, text: String, kind: LineKind) -> EnqueueResult {
        #if DEBUG
        if text.count > rules.maxChars { return .tooLong }
        #endif
        guard kind.isAllowed(talk) else { return .filtered }
        if current?.key == key || pending.contains(where: { $0.key == key }) { return .suppressed }
        if kind != .story, let t = lastShown[key], now - t < cooldown(for: key) { return .suppressed }
        lastShown[key] = now
        let line = PixelLine(id: nextId, key: key, text: text, kind: kind, duration: duration(for: text))
        nextId += 1
        if current == nil {
            show(line)
            return .shown
        }
        pending.append(line)
        let cap = max(0, rules.queueMax)
        if pending.count > cap { pending.removeFirst(pending.count - cap) }
        return .queued
    }

    /// Advances the clock; the next line comes up when the current one ends. Returns true when
    /// `current` changed.
    @discardableResult
    mutating func tick(dt: Double) -> Bool {
        guard dt > 0 else { return false }
        now += dt
        guard current != nil else { return false }
        remaining -= dt
        guard remaining <= 0 else { return false }
        advance()
        return true
    }

    /// Tap on the bubble: the next line (if any) comes up at once.
    mutating func dismiss() {
        guard current != nil else { return }
        advance()
    }

    /// Drops everything (level end).
    mutating func clear() {
        current = nil
        pending = []
        remaining = 0
    }

    private mutating func advance() {
        current = nil
        remaining = 0
        if !pending.isEmpty { show(pending.removeFirst()) }
    }

    private mutating func show(_ line: PixelLine) {
        current = line
        remaining = line.duration
    }
}
