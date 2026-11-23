import AVFoundation
import os
import UIKit

/// Music and sound effects (docs/AUDIO_BIBLE.md, numbers from `audio.json`).
///
/// Graph: two music players (crossfade) → `musicMixer` (master × slider × duck) → main mixer;
/// a jingle player → main mixer; `maxTotalVoices` SFX voices (player → varispeed for pitch
/// variance) → `sfxMixer` (master × slider) → main mixer.
///
/// Missing files are logged once and play nothing, so the game runs before the audio lands.
@MainActor
final class AudioManager: AudioSink {
    static let shared = AudioManager()

    private static let log = Logger(subsystem: "io.schervan.strike", category: "audio")
    /// SFX are converted to this on load so every voice can play every buffer.
    nonisolated private static let sfxFormat = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1)!
    nonisolated private static let musicFormat = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2)!

    private(set) var def: AudioDef = .empty
    private var settings: SettingsStore?
    private var bundle: Bundle = .main
    private var started = false

    private let engine = AVAudioEngine()
    private let musicMixer = AVAudioMixerNode()
    private let sfxMixer = AVAudioMixerNode()
    private let jinglePlayer = AVAudioPlayerNode()

    // MARK: Music state

    private final class MusicSlot {
        let player = AVAudioPlayerNode()
        var trackId: String?
        var buffer: AVAudioPCMBuffer?
        var loops = true
    }
    private let slots = [MusicSlot(), MusicSlot()]
    private var activeSlot = 0
    /// Last requested music id (also while its file is still decoding).
    private(set) var requestedMusic: String?
    private var musicToken = 0
    private var musicCache: [String: AVAudioPCMBuffer] = [:]
    private var duck: Float = 1
    private var jingleTrackVolume: Float = 0
    private var jingleActive = false
    private var jingleToken = 0

    // MARK: SFX state

    private struct Voice {
        let player: AVAudioPlayerNode
        let varispeed: AVAudioUnitVarispeed
    }
    private var voices: [Voice] = []
    private var limiter = VoiceLimiter(voices: 0)
    private var sfxBuffers: [String: AVAudioPCMBuffer] = [:]

    private(set) var isGamePaused = false
    private var loggedMissing = Set<String>()
    private var observers: [NSObjectProtocol] = []

    // MARK: Fades

    private struct Ramp {
        let from: Float
        let to: Float
        let start: Double
        let duration: Double
        let apply: @MainActor (Float) -> Void
        let done: (@MainActor () -> Void)?
    }
    private var ramps: [String: Ramp] = [:]
    private var rampTask: Task<Void, Never>?

    private init() {}

    private var now: Double { ProcessInfo.processInfo.systemUptime }

    // MARK: Setup

    /// Sets up the session and graph and preloads every SFX buffer. Safe to call more than once.
    func start(audio: AudioDef, settings: SettingsStore, bundle: Bundle = .main) {
        guard !started else { return }
        started = true
        def = audio
        self.settings = settings
        self.bundle = bundle
        settings.onChange = { [weak self] in self?.applyMix() }

        let session = AVAudioSession.sharedInstance()
        do {
            // Respects the silent switch and mixes with other apps (parent-friendly).
            try session.setCategory(.ambient, mode: .default)
            try session.setActive(true)
        } catch {
            Self.log.error("audio session: \(error.localizedDescription, privacy: .public)")
        }

        engine.attach(musicMixer)
        engine.attach(sfxMixer)
        engine.attach(jinglePlayer)
        engine.connect(musicMixer, to: engine.mainMixerNode, format: nil)
        engine.connect(sfxMixer, to: engine.mainMixerNode, format: nil)
        engine.connect(jinglePlayer, to: engine.mainMixerNode, format: Self.musicFormat)
        for s in slots {
            engine.attach(s.player)
            engine.connect(s.player, to: musicMixer, format: Self.musicFormat)
        }
        for _ in 0..<max(0, audio.sfx.maxTotalVoices) {
            let v = Voice(player: AVAudioPlayerNode(), varispeed: AVAudioUnitVarispeed())
            engine.attach(v.player)
            engine.attach(v.varispeed)
            engine.connect(v.player, to: v.varispeed, format: Self.sfxFormat)
            engine.connect(v.varispeed, to: sfxMixer, format: Self.sfxFormat)
            voices.append(v)
        }
        limiter = VoiceLimiter(voices: voices.count)
        preloadSFX()
        applyMix()
        engine.prepare()
        startEngine()
        observe()
    }

    private func preloadSFX() {
        var missing: [String] = []
        for (id, s) in def.sfx.sounds {
            guard let url = Self.url(for: s.file, in: bundle) else { missing.append(id); continue }
            do {
                sfxBuffers[id] = try AudioFileLoader.load(url: url, format: Self.sfxFormat)
            } catch {
                Self.log.error("sfx \(id, privacy: .public) failed to load: \(error.localizedDescription, privacy: .public)")
            }
        }
        if !missing.isEmpty {
            Self.log.warning("\(missing.count) sfx files missing (silent until bundled)")
        }
    }

    /// `<bundle>/Audio/<file>` (folder reference), or the bundle root.
    nonisolated static func url(for file: String, in bundle: Bundle) -> URL? {
        let name = (file as NSString).deletingPathExtension
        let ext = (file as NSString).pathExtension
        return bundle.url(forResource: name, withExtension: ext, subdirectory: "Audio")
            ?? bundle.url(forResource: name, withExtension: ext)
    }

    private func startEngine() {
        guard !engine.isRunning else { return }
        do {
            try engine.start()
        } catch {
            Self.log.error("audio engine failed to start: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func observe() {
        let nc = NotificationCenter.default
        func on(_ name: Notification.Name, _ object: AnyObject? = nil, _ body: @escaping @MainActor (Notification) -> Void) {
            observers.append(nc.addObserver(forName: name, object: object, queue: .main) { n in
                nonisolated(unsafe) let n = n
                MainActor.assumeIsolated { body(n) }
            })
        }
        on(UIApplication.didEnterBackgroundNotification) { [weak self] _ in self?.engine.pause() }
        on(UIApplication.willEnterForegroundNotification) { [weak self] _ in self?.startEngine() }
        on(AVAudioSession.interruptionNotification) { [weak self] n in
            let raw = n.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            if raw.flatMap(AVAudioSession.InterruptionType.init) == .ended { self?.restartAfterStop() }
        }
        on(.AVAudioEngineConfigurationChange, engine) { [weak self] _ in self?.restartAfterStop() }
    }

    /// The engine stopped (route change, interruption): start it again and re-schedule music.
    private func restartAfterStop() {
        startEngine()
        guard engine.isRunning else { return }
        for s in slots {
            guard let b = s.buffer, s.trackId != nil else { continue }
            s.player.stop()
            s.player.scheduleBuffer(b, at: nil, options: s.loops ? .loops : [])
            if !isGamePaused { s.player.play() }
        }
        limiter.releaseAll()
    }

    // MARK: Mix

    /// Applies settings, master volumes and the duck level.
    private func applyMix() {
        let music = Float(settings?.effectiveMusic ?? SettingsStore.defaultVolume)
        let sfx = Float(settings?.effectiveSFX ?? SettingsStore.defaultVolume)
        let musicMaster = Float(def.music.effectiveMasterVolume)
        musicMixer.outputVolume = musicMaster * music * duck
        sfxMixer.outputVolume = Float(def.sfx.masterVolume) * sfx
        jinglePlayer.volume = jingleTrackVolume * musicMaster * music
    }

    // MARK: Pause

    /// Pause menu: music and jingle pause, sounding effects stop. UI sounds still play.
    func setGamePaused(_ paused: Bool) {
        guard paused != isGamePaused else { return }
        isGamePaused = paused
        if paused {
            for s in slots where s.trackId != nil { s.player.pause() }
            if jingleActive { jinglePlayer.pause() }
            stopAllSFX()
        } else {
            startEngine()
            for s in slots where s.trackId != nil { s.player.play() }
            if jingleActive { jinglePlayer.play() }
        }
    }

    private func stopAllSFX() {
        for v in voices { v.player.stop() }
        limiter.releaseAll()
    }

    // MARK: SFX

    func play(_ event: AudioEvent) { play(sfx: event.id) }

    /// Pixel's speech-bubble beep (M3): a random one of the three, or `index` 0…2.
    func playPixelBeep(index: Int? = nil) {
        let beeps = AudioEvent.pixelBeeps
        let i = index.map { min(max(0, $0), beeps.count - 1) } ?? Int.random(in: 0..<beeps.count)
        play(beeps[i])
    }

    func play(sfx id: String) {
        guard started, engine.isRunning else { return }
        guard let s = def.sfx.sounds[id] else { logMissing(id, "not in audio.json"); return }
        guard let buffer = sfxBuffers[id] else { logMissing(id, "file \(s.file) not bundled"); return }
        guard sfxMixer.outputVolume > 0 else { return }
        let v = max(0, s.pitchVariance)
        let rate = Float(v > 0 ? 1 + Double.random(in: -v...v) : 1)
        let duration = Double(buffer.frameLength) / buffer.format.sampleRate / Double(rate)
        guard case .play(let index, let stealing) = limiter.request(
            id: id, now: now, duration: duration, maxVoices: s.maxVoices, cooldown: s.cooldownSec) else { return }
        let voice = voices[index]
        if stealing { voice.player.stop() }
        voice.varispeed.rate = rate
        voice.player.volume = Float(s.volume)
        voice.player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        voice.player.play()
    }

    private func logMissing(_ id: String, _ why: String) {
        guard loggedMissing.insert(id).inserted else { return }
        Self.log.warning("audio \(id, privacy: .public): \(why, privacy: .public), playing nothing")
    }

    // MARK: Music

    /// Crossfades to a looping track (`levels.json` `music` / `bossMusic`, `MusicID.title`).
    /// Requesting the current track again does nothing.
    func playMusic(_ id: String) {
        guard started, id != requestedMusic else { return }
        requestedMusic = id
        musicToken += 1
        let token = musicToken
        guard let track = def.music.tracks[id] else { logMissing(id, "not in audio.json"); fadeOutMusic(); return }
        loadMusic(id, track) { [weak self] buffer in
            guard let self, token == self.musicToken else { return }
            guard let buffer else { self.fadeOutMusic(); return }
            self.startTrack(id, track, buffer)
        }
    }

    /// Fades all music out (`fadeOutSec`).
    func stopMusic() {
        requestedMusic = nil
        musicToken += 1
        fadeOutMusic()
    }

    private func startTrack(_ id: String, _ track: MusicTrackDef, _ buffer: AVAudioPCMBuffer) {
        let old = slots[activeSlot]
        let hadMusic = old.trackId != nil
        if hadMusic { fade(slot: activeSlot, over: def.music.crossfadeSec) }
        activeSlot = 1 - activeSlot
        let key = "music\(activeSlot)"
        ramps[key] = nil
        let s = slots[activeSlot]
        s.player.stop()
        s.trackId = id
        s.buffer = buffer
        s.loops = track.loop
        s.player.volume = 0
        s.player.scheduleBuffer(buffer, at: nil, options: track.loop ? .loops : [])
        if engine.isRunning, !isGamePaused { s.player.play() }
        let player = s.player
        ramp(key, from: 0, to: Float(track.volume), over: hadMusic ? def.music.crossfadeSec : def.music.fadeInSec,
             apply: { player.volume = $0 })
        trimMusicCache()
    }

    private func fadeOutMusic() {
        for i in slots.indices where slots[i].trackId != nil { fade(slot: i, over: def.music.fadeOutSec) }
    }

    private func fade(slot i: Int, over sec: Double) {
        let s = slots[i]
        let player = s.player
        ramp("music\(i)", from: player.volume, to: 0, over: sec, apply: { player.volume = $0 }) { [weak self] in
            player.stop()
            s.trackId = nil
            s.buffer = nil
            self?.trimMusicCache()
        }
    }

    /// Keeps decoded loops only while a slot uses them (a level loop is about 30 MB as PCM).
    private func trimMusicCache() {
        let inUse = Set(slots.compactMap(\.trackId))
        for id in musicCache.keys where !inUse.contains(id) && def.music.tracks[id]?.loop != false {
            musicCache[id] = nil
        }
    }

    /// Plays a one-shot (Level complete) over the music, which ducks to `jingleDuckLevel`.
    func playJingle(_ id: String) {
        guard started else { return }
        guard let track = def.music.tracks[id] else { logMissing(id, "not in audio.json"); return }
        jingleToken += 1
        let token = jingleToken
        loadMusic(id, track) { [weak self] buffer in
            guard let self, let buffer, token == self.jingleToken else { return }
            self.jinglePlayer.stop()
            self.jingleTrackVolume = Float(track.volume)
            self.applyMix()
            self.jinglePlayer.scheduleBuffer(buffer, at: nil, options: [])
            self.jingleActive = true
            if self.engine.isRunning, !self.isGamePaused { self.jinglePlayer.play() }
            let m = self.def.music
            self.ramp("duck", from: self.duck, to: Float(m.jingleDuckLevel), over: m.duckAttackSec,
                      apply: { [weak self] in self?.duck = $0; self?.applyMix() })
            let length = Double(buffer.frameLength) / buffer.format.sampleRate
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(length))
                guard let self, token == self.jingleToken else { return }
                self.jingleActive = false
                self.ramp("duck", from: self.duck, to: 1, over: m.duckReleaseSec,
                          apply: { [weak self] in self?.duck = $0; self?.applyMix() })
            }
        }
    }

    /// Decodes off the main actor; `nil` when the file is missing or broken (logged once).
    private func loadMusic(_ id: String, _ track: MusicTrackDef, completion: @escaping @MainActor (AVAudioPCMBuffer?) -> Void) {
        if let b = musicCache[id] { completion(b); return }
        guard let url = Self.url(for: track.file, in: bundle) else {
            logMissing(id, "file \(track.file) not bundled")
            completion(nil)
            return
        }
        Task { @MainActor [weak self] in
            let result = await Task.detached(priority: .userInitiated) { () -> BufferBox in
                do { return BufferBox(buffer: try AudioFileLoader.load(url: url, format: Self.musicFormat)) }
                catch { return BufferBox(buffer: nil, error: error.localizedDescription) }
            }.value
            guard let self else { return }
            if let e = result.error { self.logMissing(id, "failed to load: \(e)") }
            if let b = result.buffer { self.musicCache[id] = b }
            completion(result.buffer)
        }
    }

    // MARK: Ramps

    private func ramp(_ key: String, from: Float, to: Float, over duration: Double,
                      apply: @escaping @MainActor (Float) -> Void, done: (@MainActor () -> Void)? = nil) {
        guard duration > 0 else {
            ramps[key] = nil
            apply(to)
            done?()
            return
        }
        ramps[key] = Ramp(from: from, to: to, start: now, duration: duration, apply: apply, done: done)
        guard rampTask == nil else { return }
        rampTask = Task { @MainActor [weak self] in
            while let self, !self.ramps.isEmpty {
                self.stepRamps()
                try? await Task.sleep(for: .milliseconds(16))
            }
            self?.rampTask = nil
        }
    }

    private func stepRamps() {
        let t = now
        for (key, r) in ramps {
            let k = Float(min(1, max(0, (t - r.start) / r.duration)))
            r.apply(r.from + (r.to - r.from) * k)
            if k >= 1 {
                ramps[key] = nil
                r.done?()
            }
        }
    }
}

/// Decoded audio crossing from the decode task to the main actor (the buffer is not touched
/// again off the main actor after the hand-over).
private struct BufferBox: @unchecked Sendable {
    let buffer: AVAudioPCMBuffer?
    var error: String?
}

/// Reads an audio file into a PCM buffer in `format` (sample rate / channel conversion).
nonisolated enum AudioFileLoader {
    enum LoadError: Error { case buffer, convert(String) }

    static func load(url: URL, format: AVAudioFormat) throws -> AVAudioPCMBuffer {
        let file = try AVAudioFile(forReading: url)
        let src = file.processingFormat
        guard let raw = AVAudioPCMBuffer(pcmFormat: src, frameCapacity: AVAudioFrameCount(file.length)) else {
            throw LoadError.buffer
        }
        try file.read(into: raw)
        if src.sampleRate == format.sampleRate, src.channelCount == format.channelCount,
           src.commonFormat == format.commonFormat, src.isInterleaved == format.isInterleaved {
            return raw
        }
        guard let converter = AVAudioConverter(from: src, to: format) else { throw LoadError.convert("no converter") }
        converter.downmix = true
        let capacity = AVAudioFrameCount(Double(raw.frameLength) * format.sampleRate / src.sampleRate) + 4096
        guard let out = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { throw LoadError.buffer }
        final class Feed: @unchecked Sendable { var done = false }
        let feed = Feed()
        nonisolated(unsafe) let input = raw
        var error: NSError?
        let status = converter.convert(to: out, error: &error) { _, outStatus in
            if feed.done {
                outStatus.pointee = .endOfStream
                return nil
            }
            feed.done = true
            outStatus.pointee = .haveData
            return input
        }
        if status == .error { throw LoadError.convert(error?.localizedDescription ?? "unknown") }
        return out
    }
}
