import Foundation
import Observation

/// INTERACT button state: shown for the focused interactable.
nonisolated struct InteractPrompt: Equatable, Sendable {
    let elementId: String
    /// Element type id (`button`, `lever`, `machine`).
    let kind: String
    /// False for "nothing to do" (machine without its item, already on): button at 45 %.
    let usable: Bool
}

/// Snapshot of what the SwiftUI HUD shows. The scene pushes a new value only when it changed.
nonisolated struct HUDState: Equatable, Sendable {
    var hp = 0
    var maxHp = 1
    var magazine = 0
    var reserve = 0
    var magazineSize = 0
    var isReloading = false
    /// 0…1, quantised to 5 % steps so SwiftUI is not invalidated every frame.
    var reloadProgress = 0.0
    var canReload = false
    var score = 0
    var weaponId = ""
    var interact: InteractPrompt?
    /// Carried puzzle items (key chips): item id → count.
    var carried: [String: Int] = [:]
}

/// One HUD toast line (`ui.toast.*`, already localized).
nonisolated struct ToastMessage: Equatable, Sendable {
    let id: Int
    let text: String
}

/// Result shown on the Level complete card.
nonisolated struct LevelResult: Equatable, Sendable {
    let levelId: String
    let nameKey: String
    let timeSec: Int
    let score: Int
    let datachips: Int
    let datachipsTotal: Int
    /// No level follows (Continue returns to the title).
    let isLast: Bool
}

/// One play of one level; a new `id` rebuilds the scene.
nonisolated struct LevelRun: Equatable, Sendable {
    let id: Int
    let levelId: String
    let seed: UInt64
}

/// Commands sent from SwiftUI buttons to the scene.
nonisolated enum GameCommand: Sendable, Equatable {
    case reload
    case interact
    /// Debug overlay (DEBUG builds only).
    case debugSolveAll, debugGotoExit, debugRevealMap
    /// Pause menu opened: drop held sticks so nothing keeps moving on resume.
    case resetInput
}

/// Launch arguments (DECISIONS: debug launch args for QA and UI tests).
nonisolated struct LaunchOptions: Sendable, Equatable {
    var autoStart = false
    var levelId: String?
    var seed: UInt64?
    /// `-StrikeResetSettings`: audio settings back to defaults on launch (UI tests).
    var resetSettings = false

    static func parse(_ args: [String]) -> LaunchOptions {
        var o = LaunchOptions()
        o.autoStart = args.contains("-StrikeAutoStart")
        o.resetSettings = args.contains("-StrikeResetSettings")
        func value(_ key: String) -> String? {
            guard let i = args.firstIndex(of: key), i + 1 < args.count else { return nil }
            return args[i + 1]
        }
        o.levelId = value("-StrikeLevel")
        o.seed = value("-StrikeSeed").flatMap { UInt64($0) }
        return o
    }

    static var current: LaunchOptions { parse(ProcessInfo.processInfo.arguments) }
}

/// App-wide observable state shared by SwiftUI (menus, HUD) and the SpriteKit scene.
@MainActor
@Observable
final class GameModel {
    enum Screen: Equatable {
        case title
        case game
        case levelComplete(LevelResult)
    }

    private(set) var screen: Screen = .title
    private(set) var run: LevelRun?
    var hud = HUDState()
    var minimap = MinimapSnapshot()
    var toast: ToastMessage?
    /// Pause menu is open (the scene is frozen, music paused).
    private(set) var isPaused = false
    /// Settings panel on top of the title screen or the pause menu.
    private(set) var isSettingsOpen = false

    @ObservationIgnored let data: GameData
    @ObservationIgnored let launch: LaunchOptions
    @ObservationIgnored private var runCounter = 0
    /// Launch-arg level/seed apply to the first start only; later levels get fresh seeds.
    @ObservationIgnored private var usedLaunchLevel = false

    /// Set by the running `GameScene`.
    @ObservationIgnored var commandHandler: (@MainActor (GameCommand) -> Void)?

    init(screen: Screen = .title, data: GameData = .bundled, launch: LaunchOptions = LaunchOptions()) {
        self.data = data
        self.launch = launch
        if screen == .game {
            startGame()
        } else {
            self.screen = screen
        }
    }

    /// Title "Start": L1 (or `-StrikeLevel` / `-StrikeSeed` once).
    func startGame() {
        var id = data.levelOrder.first?.id ?? "l1"
        var seed = Self.randomSeed()
        if !usedLaunchLevel {
            usedLaunchLevel = true
            if let l = launch.levelId, data.levels[l] != nil { id = l }
            if let s = launch.seed { seed = s }
        }
        startLevel(id: id, seed: seed)
    }

    func startLevel(id: String, seed: UInt64) {
        runCounter += 1
        run = LevelRun(id: runCounter, levelId: id, seed: seed)
        hud = HUDState()
        toast = nil
        minimap = MinimapSnapshot()
        isPaused = false
        isSettingsOpen = false
        screen = .game
    }

    /// In-game pause button.
    func pause() {
        guard screen == .game, !isPaused else { return }
        commandHandler?(.resetInput)
        isPaused = true
    }

    func resume() {
        isSettingsOpen = false
        isPaused = false
    }

    func openSettings() { isSettingsOpen = true }
    func closeSettings() { isSettingsOpen = false }

    func completeLevel(_ result: LevelResult) {
        commandHandler = nil
        screen = .levelComplete(result)
    }

    /// Continue on the Level complete card: next level with a new seed, after the last → title.
    func nextLevel() {
        guard case .levelComplete(let r) = screen else { return }
        if let next = data.level(after: r.levelId) {
            startLevel(id: next.id, seed: Self.randomSeed())
        } else {
            returnToTitle()
        }
    }

    func returnToTitle() {
        commandHandler = nil
        run = nil
        isPaused = false
        isSettingsOpen = false
        screen = .title
    }

    func requestReload() { commandHandler?(.reload) }
    func requestInteract() { commandHandler?(.interact) }
    func send(_ command: GameCommand) { commandHandler?(command) }

    static func randomSeed() -> UInt64 { UInt64.random(in: 1...UInt64(UInt32.max)) }
}

extension GameData {
    /// The app bundle's data, decoded once.
    nonisolated static let bundled: GameData = {
        do {
            return try GameData.load()
        } catch {
            fatalError("Bundled game data failed to load: \(error)")
        }
    }()
}
