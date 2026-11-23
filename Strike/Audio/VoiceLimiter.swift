import Foundation

/// Voice allocation for the SFX pool (pure, no AVFoundation so it can be unit-tested).
///
/// Rules, in order:
/// 1. An id started less than `cooldown` ago is rejected.
/// 2. An id already playing on `maxVoices` voices steals its own oldest voice.
/// 3. Otherwise a free voice is used; with none free, the oldest voice overall is stolen.
nonisolated struct VoiceLimiter: Sendable, Equatable {
    struct Slot: Sendable, Equatable {
        var id: String?
        var start: Double = 0
        var end: Double = 0

        func isActive(at now: Double) -> Bool { id != nil && end > now }
    }

    enum Decision: Sendable, Equatable {
        /// Play on `voice`; `stealing` means it is still sounding and must be stopped first.
        case play(voice: Int, stealing: Bool)
        case rejectedCooldown
        case rejectedNoVoices
    }

    private(set) var slots: [Slot]
    private var lastStart: [String: Double] = [:]

    init(voices: Int) {
        slots = Array(repeating: Slot(), count: max(0, voices))
    }

    var voiceCount: Int { slots.count }

    func activeCount(at now: Double) -> Int { slots.count { $0.isActive(at: now) } }

    func activeCount(of id: String, at now: Double) -> Int { slots.count { $0.id == id && $0.isActive(at: now) } }

    mutating func request(id: String, now: Double, duration: Double, maxVoices: Int, cooldown: Double) -> Decision {
        guard !slots.isEmpty else { return .rejectedNoVoices }
        if let last = lastStart[id], now - last < cooldown { return .rejectedCooldown }

        let voice: Int
        let stealing: Bool
        let own = slots.indices.filter { slots[$0].id == id && slots[$0].isActive(at: now) }
        if own.count >= max(1, maxVoices), let oldest = own.min(by: { slots[$0].start < slots[$1].start }) {
            voice = oldest
            stealing = true
        } else if let free = slots.firstIndex(where: { !$0.isActive(at: now) }) {
            voice = free
            stealing = false
        } else {
            voice = slots.indices.min { slots[$0].start < slots[$1].start }!
            stealing = true
        }
        slots[voice] = Slot(id: id, start: now, end: now + max(0, duration))
        lastStart[id] = now
        return .play(voice: voice, stealing: stealing)
    }

    /// All voices free (pause menu, background); cooldowns are kept.
    mutating func releaseAll() {
        for i in slots.indices { slots[i] = Slot() }
    }
}
