import AVFoundation
import Foundation
import Testing
@testable import Strike

struct AudioDataTests {
    static let bundle = Bundle(for: GameModel.self)

    @Test func audioJSONDecodes() throws {
        let audio = try GameData.loadAudio(Self.bundle)
        #expect(audio.version >= 1)
        #expect(!audio.music.tracks.isEmpty)
        #expect(!audio.sfx.sounds.isEmpty)
        #expect(audio.sfx.maxTotalVoices > 0)
        #expect((0...1).contains(audio.music.jingleDuckLevel))
        for (id, s) in audio.sfx.sounds {
            #expect(s.maxVoices >= 1 && s.maxVoices <= audio.sfx.maxTotalVoices, "\(id) maxVoices")
            #expect(s.cooldownSec >= 0 && (0...0.5).contains(s.pitchVariance), "\(id) cooldown/pitch")
            #expect((0...1).contains(s.volume), "\(id) volume")
        }
        #expect(try TestData.load().audio == audio)
    }

    @Test func everyAudioEventIsInAudioJSON() throws {
        let audio = try GameData.loadAudio(Self.bundle)
        for e in AudioEvent.allCases {
            #expect(audio.sfx.sounds[e.id] != nil, "AudioEvent.\(e) → \(e.id) missing in audio.json")
        }
    }

    @Test func everyMusicIdIsInAudioJSON() throws {
        let data = try TestData.load()
        var ids = Set(MusicID.all)
        for l in data.levelOrder {
            ids.insert(l.music)
            if let b = l.bossMusic { ids.insert(b) }
        }
        for id in ids.sorted() { #expect(data.audio.music.tracks[id] != nil, "music \(id) missing in audio.json") }
        for id in MusicID.all.dropFirst() { #expect(data.audio.music.tracks[id]?.loop == false, "\(id) is a jingle") }
    }

    @Test func blasterShotSounds() throws {
        #expect(AudioEvent.shot(weaponId: "blaster_starter") == .shotStarter)
        #expect(AudioEvent.shot(weaponId: "blaster_spread") == .shotSpread)
        #expect(AudioEvent.shot(weaponId: "blaster_rapid") == .shotRapid)
        #expect(AudioEvent.shot(weaponId: "unknown") == .shotStarter)
        for w in try TestData.load().weapons.keys {
            #expect(AudioEvent(rawValue: "sfx_shot_\(w.replacingOccurrences(of: "blaster_", with: ""))") != nil, "\(w) has no shot sound")
        }
    }

    /// Tolerant until the sound designer's files land: fails only once the bundled Audio folder
    /// has files and an id still has none.
    @Test func everyIdHasABundledFileOnceAudioLands() throws {
        let audio = try GameData.loadAudio(Self.bundle)
        let dir = Self.bundle.resourceURL!.appendingPathComponent("Audio")
        let present = ((try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? [])
            .filter { $0.hasSuffix(".caf") || $0.hasSuffix(".m4a") }
        let files = audio.sfx.sounds.map { ($0.key, $0.value.file) } + audio.music.tracks.map { ($0.key, $0.value.file) }
        let missing = files.filter { AudioManager.url(for: $0.1, in: Self.bundle) == nil }.map { "\($0.0) (\($0.1))" }.sorted()
        if present.isEmpty {
            print("AudioTests: no audio bundled yet; \(missing.count) of \(files.count) files missing")
            return
        }
        #expect(missing.isEmpty, "bundled Audio folder lacks: \(missing.joined(separator: ", "))")
    }

    /// Every bundled file decodes into the engine formats (48 kHz, mono SFX / stereo music).
    @Test func bundledFilesDecode() throws {
        let audio = try GameData.loadAudio(Self.bundle)
        let mono = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1)!
        let stereo = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2)!
        let files = audio.sfx.sounds.values.map { ($0.file, mono) } + audio.music.tracks.values.map { ($0.file, stereo) }
        for (file, format) in files {
            guard let url = AudioManager.url(for: file, in: Self.bundle) else { continue }
            let b = try AudioFileLoader.load(url: url, format: format)
            #expect(b.frameLength > 0, "\(file) is empty")
            #expect(b.format.channelCount == format.channelCount)
        }
    }
}

struct VoiceLimiterTests {
    @Test func cooldownRejectsTooSoon() {
        var v = VoiceLimiter(voices: 4)
        #expect(v.request(id: "a", now: 0, duration: 1, maxVoices: 4, cooldown: 0.1) == .play(voice: 0, stealing: false))
        #expect(v.request(id: "a", now: 0.05, duration: 1, maxVoices: 4, cooldown: 0.1) == .rejectedCooldown)
        #expect(v.request(id: "a", now: 0.1, duration: 1, maxVoices: 4, cooldown: 0.1) == .play(voice: 1, stealing: false))
        // Another id is not affected by a's cooldown.
        #expect(v.request(id: "b", now: 0.11, duration: 1, maxVoices: 4, cooldown: 0.1) == .play(voice: 2, stealing: false))
    }

    @Test func perIdLimitStealsOwnOldest() {
        var v = VoiceLimiter(voices: 8)
        _ = v.request(id: "a", now: 0, duration: 5, maxVoices: 2, cooldown: 0)
        _ = v.request(id: "b", now: 0.1, duration: 5, maxVoices: 2, cooldown: 0)
        _ = v.request(id: "a", now: 0.2, duration: 5, maxVoices: 2, cooldown: 0)
        #expect(v.activeCount(of: "a", at: 0.3) == 2)
        #expect(v.request(id: "a", now: 0.3, duration: 5, maxVoices: 2, cooldown: 0) == .play(voice: 0, stealing: true))
        #expect(v.activeCount(of: "a", at: 0.3) == 2)
        #expect(v.activeCount(of: "b", at: 0.3) == 1)
    }

    @Test func totalLimitStealsOldestOverall() {
        var v = VoiceLimiter(voices: 3)
        for (i, id) in ["a", "b", "c"].enumerated() {
            #expect(v.request(id: id, now: Double(i), duration: 10, maxVoices: 4, cooldown: 0) == .play(voice: i, stealing: false))
        }
        #expect(v.activeCount(at: 3) == 3)
        #expect(v.request(id: "d", now: 3, duration: 10, maxVoices: 4, cooldown: 0) == .play(voice: 0, stealing: true))
        #expect(v.request(id: "e", now: 4, duration: 10, maxVoices: 4, cooldown: 0) == .play(voice: 1, stealing: true))
        #expect(v.activeCount(at: 4) == 3)
    }

    @Test func finishedVoicesAreReused() {
        var v = VoiceLimiter(voices: 2)
        _ = v.request(id: "a", now: 0, duration: 0.5, maxVoices: 1, cooldown: 0)
        _ = v.request(id: "b", now: 0, duration: 2, maxVoices: 1, cooldown: 0)
        #expect(v.activeCount(at: 1) == 1)
        #expect(v.request(id: "c", now: 1, duration: 1, maxVoices: 1, cooldown: 0) == .play(voice: 0, stealing: false))
        // maxVoices 1 with the voice done: no steal needed.
        #expect(v.request(id: "c", now: 2.5, duration: 1, maxVoices: 1, cooldown: 0) == .play(voice: 0, stealing: false))
    }

    @Test func releaseAllAndEmptyPool() {
        var v = VoiceLimiter(voices: 2)
        _ = v.request(id: "a", now: 0, duration: 9, maxVoices: 2, cooldown: 1)
        _ = v.request(id: "b", now: 0, duration: 9, maxVoices: 2, cooldown: 0)
        v.releaseAll()
        #expect(v.activeCount(at: 0.5) == 0)
        #expect(v.request(id: "a", now: 0.5, duration: 1, maxVoices: 2, cooldown: 1) == .rejectedCooldown)
        var none = VoiceLimiter(voices: 0)
        #expect(none.request(id: "a", now: 0, duration: 1, maxVoices: 1, cooldown: 0) == .rejectedNoVoices)
    }

    /// Hammering one id (rapid blaster at 60 Hz for 2 s) never exceeds its own or the pool limit.
    @Test func stressStaysWithinLimits() {
        var v = VoiceLimiter(voices: 16)
        var plays = 0
        for f in 0..<120 {
            let t = Double(f) / 60
            if case .play = v.request(id: "rapid", now: t, duration: 0.3, maxVoices: 6, cooldown: 0.04) { plays += 1 }
            _ = v.request(id: "hit", now: t, duration: 0.2, maxVoices: 5, cooldown: 0.04)
            #expect(v.activeCount(of: "rapid", at: t) <= 6)
            #expect(v.activeCount(at: t) <= 16)
        }
        #expect(plays == 40) // one start every 3 frames (0.05 s ≥ 0.04 s cooldown)
    }
}

@MainActor
struct SettingsStoreTests {
    static func freshDefaults() -> UserDefaults {
        let name = "SettingsStoreTests.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    @Test func defaultsAreEightyPercentAndUnmuted() {
        let s = SettingsStore(defaults: Self.freshDefaults())
        #expect(s.musicVolume == 0.8 && s.sfxVolume == 0.8 && !s.muteAll)
        #expect(s.effectiveMusic == 0.8 && s.effectiveSFX == 0.8)
    }

    @Test func valuesPersistAcrossInstances() {
        let d = Self.freshDefaults()
        let a = SettingsStore(defaults: d)
        var changes = 0
        a.onChange = { changes += 1 }
        a.setMusicVolume(0.3)
        a.setSFXVolume(0.55)
        a.setMuteAll(true)
        a.setMuteAll(true) // no change, no callback
        #expect(changes == 3)
        let b = SettingsStore(defaults: d)
        #expect(b.musicVolume == 0.3 && b.sfxVolume == 0.55 && b.muteAll)
        #expect(b.effectiveMusic == 0 && b.effectiveSFX == 0)
        b.reset()
        let c = SettingsStore(defaults: d)
        #expect(c.musicVolume == 0.8 && c.sfxVolume == 0.8 && !c.muteAll)
    }

    @Test func valuesAreClamped() {
        let d = Self.freshDefaults()
        let s = SettingsStore(defaults: d)
        s.setMusicVolume(1.7)
        s.setSFXVolume(-0.4)
        #expect(s.musicVolume == 1 && s.sfxVolume == 0)
        s.setMusicVolume(.nan)
        #expect(s.musicVolume == 0.8)
        d.set(5.0, forKey: SettingsStore.Key.music)
        d.set(-2.0, forKey: SettingsStore.Key.sfx)
        let t = SettingsStore(defaults: d)
        #expect(t.musicVolume == 1 && t.sfxVolume == 0)
    }

    @Test func launchFlagParses() {
        #expect(LaunchOptions.parse(["-StrikeResetSettings"]).resetSettings)
        #expect(!LaunchOptions.parse([]).resetSettings)
    }
}

/// Pause/settings state on the model.
@MainActor
struct PauseSettingsModelTests {
    @Test func pauseResumeAndSettings() throws {
        let model = GameModel(data: try TestData.load())
        model.pause()
        #expect(!model.isPaused, "no pause on the title screen")
        model.openSettings()
        #expect(model.isSettingsOpen)
        model.closeSettings()
        model.startGame()
        var commands: [GameCommand] = []
        model.commandHandler = { commands.append($0) }
        model.pause()
        #expect(model.isPaused && commands == [.resetInput])
        model.openSettings()
        model.resume()
        #expect(!model.isPaused && !model.isSettingsOpen)
        model.pause()
        model.returnToTitle()
        #expect(!model.isPaused && model.screen == .title)
    }
}

/// The scene reports gameplay sounds through its `AudioSink`.
@MainActor
struct SceneAudioHookTests {
    final class Recorder: AudioSink {
        var events: [AudioEvent] = []
        var jingles: [String] = []
        func play(_ event: AudioEvent) { events.append(event) }
        func playJingle(_ id: String) { jingles.append(id) }
    }

    @Test func rescueDoorsAndExitEmitSounds() throws {
        let data = try TestData.load()
        let scene = GameScene(data: data, levelId: "l1", seed: 42)
        let rec = Recorder()
        scene.audio = rec
        scene.rescueHero()
        #expect(rec.events == [.rescue])
        scene.handle(.debugSolveAll)
        #expect(rec.events.contains(.doorOpen))
        if !scene.level.gates.isEmpty { #expect(rec.events.contains(.gateUnlocked)) }
        scene.handle(.debugGotoExit)
        for _ in 0..<120 where !scene.isComplete { scene.step(dt: 1.0 / 30) }
        #expect(scene.isComplete)
        #expect(rec.jingles == [MusicID.levelComplete])
    }

    @Test func pickupSoundsByCategory() throws {
        let items = try TestData.load().items
        if let bolt = items[LootRoller.boltItemId] { #expect(GameScene.pickupSound(bolt) == .pickupBolt) }
        for i in items.values {
            let e = GameScene.pickupSound(i)
            switch i.category {
            case .ammo: #expect(e == .pickupAmmo)
            case .heal, .food: #expect(e == .pickupHeal)
            default: #expect([.pickupItem, .pickupBolt].contains(e))
            }
        }
    }
}
