import Foundation

/// Pixel's brain in the scene (GDD §13): the speech queue, the story director, the idle-hint timer
/// and the hint/cooldown state. Pushes the current line to the HUD through `onBubble`.
@MainActor
final class PixelController {
    private(set) var speech: SpeechQueue
    private(set) var story: StoryDirector
    let hints: HintRulesDef
    let idleSec: Double

    /// Game seconds without progress (paused while frozen, in the door pan and in the rescue).
    private(set) var idleTime: Double = 0
    /// Real seconds left of the running hint (fly + arrow), 0 when none.
    private(set) var hintRemaining: Double = 0
    /// Real seconds left of the tap cooldown after a hint ended.
    private(set) var cooldownRemaining: Double = 0

    /// Called with the line on screen (nil = bubble hidden).
    var onBubble: (@MainActor (PixelLine?) -> Void)?
    /// Called when a new line appears (speech beep).
    var onLineShown: (@MainActor (PixelLine) -> Void)?
    /// Localized text for a key (tests may inject).
    var localize: (String) -> String = { String(localized: String.LocalizationValue($0)) }

    init(level: LevelDef, rules: RulesDef, talk: PixelTalk) {
        speech = SpeechQueue(rules: rules.pixel, talk: talk, keyCooldowns: StoryDirector.keyCooldowns(rules))
        story = StoryDirector(story: level.effectiveStory)
        hints = rules.hints
        idleSec = Double(level.effectiveHintIdleSec)
    }

    var currentLine: PixelLine? { speech.current }
    var isHintRunning: Bool { hintRemaining > 0 }
    var canHint: Bool { hintRemaining <= 0 && cooldownRemaining <= 0 }

    // MARK: Speech

    /// Story event → level beats / generic line. Returns the enemy id to scan, if any.
    @discardableResult
    func handle(_ event: StoryEvent) -> String? {
        let r = story.handle(event)
        // QA-011: a tip without a string (e.g. a new enemy) is skipped, never shown as a raw key.
        for c in r.cues where !(c.key.hasPrefix("pixel.tip.") && localize(c.key) == c.key) { say(c.key, kind: c.kind) }
        return r.scanEnemyId
    }

    /// Settings → Pixel talk, live.
    func setTalk(_ t: PixelTalk) {
        speech.talk = t
    }

    @discardableResult
    func say(_ key: String, kind: LineKind) -> EnqueueResult {
        let before = speech.current
        let result = speech.enqueue(key: key, text: localize(key), kind: kind)
        publishIfChanged(before)
        return result
    }

    /// Bubble tap.
    func dismiss() {
        let before = speech.current
        speech.dismiss()
        publishIfChanged(before)
    }

    /// Real-time clock for the bubble and the hint timers.
    func tick(realDt dt: Double) {
        let before = speech.current
        speech.tick(dt: dt)
        publishIfChanged(before)
        if hintRemaining > 0 {
            hintRemaining = max(0, hintRemaining - dt)
            if hintRemaining == 0 { cooldownRemaining = hints.cooldownSec }
        } else if cooldownRemaining > 0 {
            cooldownRemaining = max(0, cooldownRemaining - dt)
        }
    }

    private func publishIfChanged(_ before: PixelLine?) {
        let now = speech.current
        guard now != before else { return }
        onBubble?(now)
        if let now { onLineShown?(now) }
    }

    // MARK: Idle hint

    /// Progress (GDD §13): element/gate on, item stored, door open, new room, checkpoint.
    func progress() { idleTime = 0 }

    /// Game time. Returns true when the idle hint should fire now (it waits for the tap cooldown).
    func tickIdle(gameDt dt: Double) -> Bool {
        idleTime += max(0, dt)
        return idleTime >= idleSec && canHint
    }

    /// A hint starts (fly + arrow); also resets the idle timer.
    func beginHint() {
        hintRemaining = hints.flySec + hints.arrowSec
        idleTime = 0
    }

    /// A hint without a flight (`need_*`): straight to the cooldown.
    func beginLineOnlyHint() {
        hintRemaining = 0
        cooldownRemaining = hints.cooldownSec
        idleTime = 0
    }

    /// Target solved or reached: the arrow ends early, the cooldown starts.
    func endHint() {
        guard hintRemaining > 0 else { return }
        hintRemaining = 0
        cooldownRemaining = hints.cooldownSec
    }
}
