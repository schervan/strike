import Foundation
import Observation

/// Player audio settings, persisted in `UserDefaults` (the M3 save can absorb this later).
/// Volumes are 0…1; every setter clamps, saves and notifies `onChange` (the audio mix).
@MainActor
@Observable
final class SettingsStore {
    static let shared = SettingsStore()

    /// Owner request: both sliders start at 80 %.
    static let defaultVolume = 0.8

    enum Key {
        static let music = "settings.musicVolume"
        static let sfx = "settings.sfxVolume"
        static let muteAll = "settings.muteAll"
    }

    private(set) var musicVolume: Double
    private(set) var sfxVolume: Double
    private(set) var muteAll: Bool

    @ObservationIgnored private let defaults: UserDefaults
    /// Called after every change (live mix update).
    @ObservationIgnored var onChange: (@MainActor () -> Void)?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        musicVolume = Self.clamp(defaults.object(forKey: Key.music) as? Double ?? Self.defaultVolume)
        sfxVolume = Self.clamp(defaults.object(forKey: Key.sfx) as? Double ?? Self.defaultVolume)
        muteAll = defaults.bool(forKey: Key.muteAll)
    }

    /// Music volume the mixer uses (0 while muted).
    var effectiveMusic: Double { muteAll ? 0 : musicVolume }
    var effectiveSFX: Double { muteAll ? 0 : sfxVolume }

    func setMusicVolume(_ v: Double) {
        let c = Self.clamp(v)
        guard c != musicVolume else { return }
        musicVolume = c
        defaults.set(c, forKey: Key.music)
        onChange?()
    }

    func setSFXVolume(_ v: Double) {
        let c = Self.clamp(v)
        guard c != sfxVolume else { return }
        sfxVolume = c
        defaults.set(c, forKey: Key.sfx)
        onChange?()
    }

    func setMuteAll(_ on: Bool) {
        guard on != muteAll else { return }
        muteAll = on
        defaults.set(on, forKey: Key.muteAll)
        onChange?()
    }

    /// Back to defaults (UI tests: `-StrikeResetSettings`).
    func reset() {
        for k in [Key.music, Key.sfx, Key.muteAll] { defaults.removeObject(forKey: k) }
        musicVolume = Self.defaultVolume
        sfxVolume = Self.defaultVolume
        muteAll = false
        onChange?()
    }

    static func clamp(_ v: Double) -> Double {
        guard v.isFinite else { return defaultVolume }
        return min(1, max(0, v))
    }
}
