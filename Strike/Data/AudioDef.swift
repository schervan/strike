import Foundation

/// `audio.json` (owned by sound-designer, docs/AUDIO_BIBLE.md): music tracks and SFX with their
/// mix numbers. Files live in `<bundle>/Audio/`.
nonisolated struct AudioDef: Codable, Sendable, Equatable {
    let version: Int
    let music: MusicDef
    let sfx: SFXDef

    /// Used while `audio.json` is missing: everything stays silent.
    static let empty = AudioDef(
        version: 0,
        music: MusicDef(crossfadeSec: 0, fadeInSec: 0, fadeOutSec: 0, jingleDuckLevel: 1, duckAttackSec: 0,
                        duckReleaseSec: 0, masterVolume: 0, tracks: [:]),
        sfx: SFXDef(masterVolume: 0, maxTotalVoices: 0, sounds: [:]))
}

nonisolated struct MusicDef: Codable, Sendable, Equatable {
    let crossfadeSec: Double
    let fadeInSec: Double
    let fadeOutSec: Double
    /// Music level (0…1) while a jingle plays.
    let jingleDuckLevel: Double
    let duckAttackSec: Double
    let duckReleaseSec: Double
    let masterVolume: Double?
    let tracks: [String: MusicTrackDef]

    var effectiveMasterVolume: Double { masterVolume ?? 1 }
}

nonisolated struct MusicTrackDef: Codable, Sendable, Equatable {
    let file: String
    let volume: Double
    /// False for jingles (played once over ducked music).
    let loop: Bool
    let bpm: Double?
    let lengthSec: Double?
}

nonisolated struct SFXDef: Codable, Sendable, Equatable {
    let masterVolume: Double
    /// Size of the SFX voice pool.
    let maxTotalVoices: Int
    let sounds: [String: SoundDef]
}

nonisolated struct SoundDef: Codable, Sendable, Equatable {
    let file: String
    let volume: Double
    /// Random playback-rate offset, ± this fraction (0.05 → 0.95…1.05).
    let pitchVariance: Double
    /// Simultaneous voices of this id; a new one steals the oldest.
    let maxVoices: Int
    /// Minimum time between two starts of this id.
    let cooldownSec: Double
}
