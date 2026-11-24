import Foundation

/// Every sound effect the game triggers. Raw values are the `audio.json` `sfx.sounds` ids
/// (docs/AUDIO_BIBLE.md); `AudioTests` checks that each one exists.
nonisolated enum AudioEvent: String, CaseIterable, Sendable {
    // Blasters
    case shotStarter = "sfx_shot_starter"
    case shotSpread = "sfx_shot_spread"
    case shotRapid = "sfx_shot_rapid"
    case emptyClick = "sfx_empty_click"
    case reload = "sfx_reload"
    // Enemies
    case enemyShot = "sfx_shot_enemy"
    case enemyAlert = "sfx_alert"
    case enemyHit = "sfx_hit_enemy"
    case enemyPowerDown = "sfx_powerdown_poof"
    // Hero
    case heroHurt = "sfx_hero_hurt"
    case rescue = "sfx_rescue_teleport"
    // Pickups
    case pickupAmmo = "sfx_pickup_ammo"
    case pickupHeal = "sfx_pickup_heal"
    case pickupItem = "sfx_pickup_item"
    case pickupBolt = "sfx_pickup_bolt"
    // Puzzle
    case buttonPress = "sfx_button_press"
    case leverPull = "sfx_lever_pull"
    case plateOn = "sfx_plate_on"
    case machineOn = "sfx_machine_on"
    case doorOpen = "sfx_door_open"
    case gateUnlocked = "sfx_gate_unlocked"
    case checkpoint = "sfx_checkpoint"
    case crateBreak = "sfx_crate_break"
    // UI, flow
    case uiTap = "sfx_ui_tap"
    case uiBack = "sfx_ui_back"
    case levelStart = "sfx_level_start"
    // Pixel (M3 speech bubble)
    case pixelBeep1 = "sfx_pixel_beep_1"
    case pixelBeep2 = "sfx_pixel_beep_2"
    case pixelBeep3 = "sfx_pixel_beep_3"

    var id: String { rawValue }

    static let pixelBeeps: [AudioEvent] = [.pixelBeep1, .pixelBeep2, .pixelBeep3]

    /// Shot sound of a blaster by convention `blaster_<name>` → `sfx_shot_<name>`; unknown
    /// blasters use the starter sound.
    static func shot(weaponId: String) -> AudioEvent {
        let name = weaponId.hasPrefix("blaster_") ? String(weaponId.dropFirst("blaster_".count)) : weaponId
        return AudioEvent(rawValue: "sfx_shot_\(name)") ?? .shotStarter
    }
}

/// Music ids not named in `levels.json` (level tracks come from `LevelDef.music` / `bossMusic`).
nonisolated enum MusicID {
    static let title = "music_title"
    static let levelComplete = "music_level_complete"
    static let seasonComplete = "music_season_complete"

    static let all = [title, levelComplete, seasonComplete]
}

/// What the scene and UI need from the audio system (lets tests record events).
@MainActor
protocol AudioSink: AnyObject {
    func play(_ event: AudioEvent)
    func playJingle(_ id: String)
    /// Pixel's speech beep (a random one of three when `index` is nil).
    func playPixelBeep(index: Int?)
}

extension AudioSink {
    func playPixelBeep(index: Int?) { play(AudioEvent.pixelBeeps[min(max(0, index ?? 0), AudioEvent.pixelBeeps.count - 1)]) }
}
