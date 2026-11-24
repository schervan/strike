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
    /// Q1…Q4 (ART_BIBLE §14.1).
    var quickSlots: [QuickSlotState] = []
    /// HP at or below `rules.lowHp.threshold` (heart pulse, ART_BIBLE §14.8).
    var lowHp = false
    /// No free slot left (inventory button "!" badge, §14.3).
    var bagFull = false
    /// Pixel hint target in the bag: the inventory button glows (§14.6).
    var bagHint = false
    /// Blasters in SWAP / wheel order (GDD §5); SWAP shows once 2 or more are owned.
    var weapons: [WeaponSlotState] = []
    /// A swap is running (`rules.weapons.swapSec`): SWAP ignores taps.
    var isSwapping = false
    /// Spore slow on the hero (ART_BIBLE §15.4 badge).
    var slowed = false
    /// Boss bar (arena stage only).
    var boss: BossBarState?

    var ownedWeaponCount: Int { weapons.filter(\.owned).count }
    var swapVisible: Bool { ownedWeaponCount >= 2 }
    /// The blaster a SWAP tap gives (badge on the button).
    var nextWeaponId: String? {
        let owned = weapons.filter(\.owned)
        guard owned.count > 1, let i = owned.firstIndex(where: \.equipped) else { return nil }
        return owned[(i + 1) % owned.count].id
    }
}

/// One weapon-wheel slot (ART_BIBLE §15.7).
nonisolated struct WeaponSlotState: Equatable, Sendable, Identifiable {
    let id: String
    let nameKey: String
    var owned: Bool
    var equipped: Bool
    var magazine: Int
    var reserve: Int
}

/// Boss bar (ART_BIBLE §15.8): no numbers; HP fraction, phase notches, shield and core pips.
nonisolated struct BossBarState: Equatable, Sendable {
    var nameKey: String
    /// 0…1, quantised to 0.5 % so SwiftUI is not invalidated every frame.
    var hpRatio: Double
    var notches: [Double]
    /// 1-based phase and the phase count.
    var phase: Int
    var phases: Int
    var immune: Bool
    var coresIn: Int
    var coresNeeded: Int
    var defeated: Bool
}

/// One quick slot in the HUD: a link to an item id with its total count (GDD §7).
nonisolated struct QuickSlotState: Equatable, Sendable {
    var itemId: String?
    var count = 0
    /// 0…1 of the use cooldown left (quantised to 10 %), 0 when ready.
    var cooldown = 0.0
    /// False when a use would be refused (`alreadyFull`): sprite dimmed.
    var usable = true
}

/// Quick-slot / inventory feedback event (shake on refusal, pop on use). A new `id` replays it.
nonisolated struct UseFeedback: Equatable, Sendable {
    enum Kind: Sendable { case used, refused }
    let id: Int
    /// Quick slot index, nil for a use from the inventory grid.
    let quickSlot: Int?
    let kind: Kind
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
    var rescues = 0
}

/// The part of a level a run plays: the generated level, or the fixed boss arena behind the L5
/// exit pad (DECISIONS 2026-11-24).
nonisolated enum LevelStage: String, Codable, Sendable, Equatable {
    case level, bossArena
}

/// One play of one level; a new `id` rebuilds the scene.
nonisolated struct LevelRun: Equatable, Sendable {
    let id: Int
    let levelId: String
    let seed: UInt64
    var stage: LevelStage = .level
}

/// Commands sent from SwiftUI buttons to the scene.
nonisolated enum GameCommand: Sendable, Equatable {
    case reload
    case interact
    /// Quick slot tap (0…3).
    case useQuick(Int)
    /// Inventory screen actions on a grid slot (0…24).
    case useItem(slot: Int)
    case dropItem(slot: Int, count: Int)
    /// Links quick slot `slot` to `itemId` (nil clears it).
    case assignQuick(itemId: String?, slot: Int)
    case tidy
    /// Tap on the speech bubble.
    case dismissBubble
    /// Debug overlay (DEBUG builds only).
    case debugSolveAll, debugGotoExit, debugRevealMap, debugSpawnCrowd, debugDamageHero
    case debugGiveBlasters, debugBossArena, debugBossNextPhase
    case debugSpawn(String)
    /// SWAP tap (GDD §5.1) and a weapon-wheel pick.
    case swapNext
    case swapTo(String)
    /// Settings changed while playing (Pixel talk, aim assist).
    case settingsChanged
    /// Pause menu / inventory opened: drop held sticks so nothing keeps moving on resume.
    case resetInput
}

/// Launch arguments (DECISIONS: debug launch args for QA and UI tests).
nonisolated struct LaunchOptions: Sendable, Equatable {
    /// `-StrikeAutoStart`: straight into the level, no title and no intro card (QA, screenshots).
    var autoStart = false
    var levelId: String?
    var seed: UInt64?
    /// `-StrikeResetSettings`: audio settings back to defaults on launch (UI tests).
    var resetSettings = false
    /// `-StrikeFreshSave`: delete `save.json` on launch (UI tests).
    var freshSave = false
    /// `-StrikeBossArena`: the first start goes straight into the L5 boss arena (QA, UI tests).
    var bossArena = false

    static func parse(_ args: [String]) -> LaunchOptions {
        var o = LaunchOptions()
        o.autoStart = args.contains("-StrikeAutoStart")
        o.resetSettings = args.contains("-StrikeResetSettings")
        o.freshSave = args.contains("-StrikeFreshSave")
        o.bossArena = args.contains("-StrikeBossArena")
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
        /// After the boss (ART_BIBLE §15.14).
        case seasonComplete(LevelResult)
    }

    private(set) var screen: Screen = .title
    /// The level play in progress (a new id rebuilds the scene).
    private(set) var run: LevelRun?
    /// Everything that carries over between levels and is saved (`RunState`, GDD §16.10). The
    /// TASKS module map calls this `GameModel.run`; `run` already names the level play.
    private(set) var progress: RunState
    var hud = HUDState()
    var minimap = MinimapSnapshot()
    var toast: ToastMessage?
    /// Pixel's line in the top-centre bubble.
    var bubble: PixelLine?
    /// The bag as the scene holds it (inventory screen).
    var bag: Inventory
    var useFeedback: UseFeedback?
    /// Pause menu is open (the scene is frozen, music paused).
    private(set) var isPaused = false
    /// Settings panel on top of the title screen or the pause menu.
    private(set) var isSettingsOpen = false
    /// Inventory screen is open (game time stops).
    private(set) var isInventoryOpen = false
    /// Level intro card over the (frozen) level.
    private(set) var isIntroShowing = false
    /// Weapon wheel open: game time runs at `rules.weapons.wheelTimeScale` (ART_BIBLE §15.7).
    var isWheelOpen = false
    /// DEBUG overlay: measured frame rate and node count (M4-5 performance log).
    var debugStats = ""
    /// A save exists ("Continue" on the title).
    private(set) var hasSave = false

    /// Season totals for the Season complete card: best score and datachips summed over the levels.
    var seasonTotals: (score: Int, datachips: Int, datachipsTotal: Int) {
        let levels = data.levelOrder
        let score = levels.reduce(0) { $0 + (progress.bestResults[$1.id]?.bestScore ?? 0) }
        let chips = levels.reduce(0) { $0 + (progress.bestResults[$1.id]?.datachips ?? 0) }
        return (score, chips, levels.reduce(0) { $0 + $1.pickups.datachips })
    }

    /// The scene is frozen (pause menu, inventory, intro card).
    var isGameFrozen: Bool { isPaused || isInventoryOpen || isIntroShowing }

    @ObservationIgnored let data: GameData
    @ObservationIgnored let launch: LaunchOptions
    @ObservationIgnored let saveStore: SaveStore?
    @ObservationIgnored private var runCounter = 0
    /// Launch-arg level/seed apply to the first start only; later levels get fresh seeds.
    @ObservationIgnored private var usedLaunchLevel = false

    /// Set by the running `GameScene`.
    @ObservationIgnored var commandHandler: (@MainActor (GameCommand) -> Void)?
    /// Set by the running `GameScene`: its current loadout and bag (mid-level saves).
    @ObservationIgnored var carriedProvider: (@MainActor () -> (Loadout, Inventory))?

    /// `saveStore` nil = no persistence (unit tests).
    init(screen: Screen = .title, data: GameData = .bundled, launch: LaunchOptions = LaunchOptions(),
         saveStore: SaveStore? = nil) {
        self.data = data
        self.launch = launch
        self.saveStore = saveStore
        if launch.freshSave { saveStore?.delete() }
        // `-StrikeAutoStart` (QA) always plays a fresh run; the save is not read.
        var loaded = launch.autoStart ? nil : saveStore?.load()?.run
        loaded?.bind(to: data)
        let start = loaded ?? RunState.newGame(data: data)
        progress = start
        bag = start.inventory
        hasSave = loaded != nil
        if screen == .game {
            startGame()
        } else {
            self.screen = screen
        }
    }

    // MARK: Title

    /// Title "New game" (after the confirmation when a save exists): a fresh run, settings kept.
    func newGame() {
        progress = RunState.newGame(data: data, keeping: progress.settings)
        saveStore?.delete()
        hasSave = false
        startGame()
    }

    /// Title "Continue": the saved current level with the saved loadout and bag.
    func continueGame() {
        let id = progress.currentLevelId.flatMap { data.levels[$0] != nil ? $0 : nil } ?? data.levelOrder.first?.id ?? "l1"
        // DECISIONS 2026-11-24: Continue resumes at the boss arena checkpoint once it was reached.
        if progress.arena?.levelId == id {
            startArena(id: id)
            return
        }
        startLevel(id: id, seed: Self.randomSeed())
    }

    /// Starts L1 (or `-StrikeLevel` / `-StrikeSeed` once) with the current run state.
    func startGame() {
        var id = data.levelOrder.first?.id ?? "l1"
        var seed = Self.randomSeed()
        if !usedLaunchLevel {
            usedLaunchLevel = true
            if let l = launch.levelId, data.levels[l] != nil { id = l }
            if let s = launch.seed { seed = s }
            if launch.bossArena, let def = data.levels[id], def.bossArena != nil {
                progress.startLevel(def, data: data)
                progress.arena = ArenaProgress(levelId: id)
                startArena(id: id, seed: seed)
                return
            }
        }
        startLevel(id: id, seed: seed)
    }

    /// The L5 exit pad was reached (or Continue / debug): the boss arena with the level's session
    /// values carried over (GDD §15: one session for both stages).
    func enterBossArena(levelId: String, carry: ArenaProgress, loadout: Loadout, inventory: Inventory) {
        progress.loadout = loadout
        progress.inventory = inventory
        progress.arena = carry
        startArena(id: levelId, seed: run?.seed ?? Self.randomSeed())
    }

    private func startArena(id: String, seed: UInt64 = GameModel.randomSeed()) {
        bag = progress.inventory
        runCounter += 1
        run = LevelRun(id: runCounter, levelId: id, seed: seed, stage: .bossArena)
        hud = HUDState()
        toast = nil
        bubble = nil
        useFeedback = nil
        minimap = MinimapSnapshot()
        isPaused = false
        isSettingsOpen = false
        isInventoryOpen = false
        isWheelOpen = false
        isIntroShowing = false
        screen = .game
        save()
    }

    // MARK: Settings (Pixel talk, aim assist; saved in the run)

    func setPixelTalk(_ t: PixelTalk) {
        progress.settings.pixelTalk = t
        commandHandler?(.settingsChanged)
        save()
    }

    func setAimAssist(_ on: Bool) {
        progress.settings.aimAssist = on
        commandHandler?(.settingsChanged)
        save()
    }

    /// Level start (GDD §16.10): start gift, starter top-up, puzzle items cleared, saved. The intro
    /// card shows first unless `-StrikeAutoStart`.
    func startLevel(id: String, seed: UInt64) {
        if let def = data.levels[id] { progress.startLevel(def, data: data) }
        bag = progress.inventory
        runCounter += 1
        run = LevelRun(id: runCounter, levelId: id, seed: seed)
        hud = HUDState()
        toast = nil
        bubble = nil
        useFeedback = nil
        minimap = MinimapSnapshot()
        isPaused = false
        isSettingsOpen = false
        isInventoryOpen = false
        isWheelOpen = false
        isIntroShowing = !launch.autoStart
        screen = .game
        save()
    }

    /// Tap on the intro card.
    func dismissIntro() {
        isIntroShowing = false
    }

    // MARK: Pause, inventory

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

    /// HUD bag button, empty quick slot, or the pause menu.
    func openInventory() {
        guard screen == .game, !isIntroShowing else { return }
        commandHandler?(.resetInput)
        isPaused = false
        isSettingsOpen = false
        isInventoryOpen = true
    }

    func closeInventory() { isInventoryOpen = false }

    // MARK: Progress and saving

    /// Checkpoint touched (GDD §16.10 mid-level save).
    func checkpointReached(loadout: Loadout, inventory: Inventory) {
        progress.loadout = loadout
        progress.inventory = inventory
        save()
    }

    func completeLevel(_ result: LevelResult, loadout: Loadout? = nil, inventory: Inventory? = nil) {
        if let loadout { progress.loadout = loadout }
        if let inventory { progress.inventory = inventory }
        if let def = data.levels[result.levelId] {
            progress.completeLevel(def, result: LevelBest(bestScore: result.score, bestTimeSec: result.timeSec,
                                                          datachips: result.datachips, fewestRescues: result.rescues),
                                   data: data)
        }
        bag = progress.inventory
        commandHandler = nil
        carriedProvider = nil
        isInventoryOpen = false
        isWheelOpen = false
        isIntroShowing = false
        screen = result.isLast ? .seasonComplete(result) : .levelComplete(result)
        save()
    }

    /// Continue on the Level complete card: next level with a new seed, after the last → title.
    func nextLevel() {
        let r: LevelResult
        switch screen {
        case .levelComplete(let x), .seasonComplete(let x): r = x
        default: return
        }
        if let next = data.level(after: r.levelId) {
            startLevel(id: next.id, seed: Self.randomSeed())
        } else {
            returnToTitle()
        }
    }

    /// Main menu / title. A level in progress keeps what the hero carries (GDD §16.10).
    func returnToTitle() {
        captureCarried()
        save()
        commandHandler = nil
        carriedProvider = nil
        run = nil
        isPaused = false
        isSettingsOpen = false
        isInventoryOpen = false
        isIntroShowing = false
        bubble = nil
        screen = .title
    }

    /// App went to the background.
    func saveNow() {
        captureCarried()
        save()
    }

    private func captureCarried() {
        guard screen == .game, let (loadout, inventory) = carriedProvider?() else { return }
        progress.loadout = loadout
        progress.inventory = inventory
    }

    private func save() {
        guard let saveStore, progress.currentLevelId != nil else { return }
        do {
            try saveStore.save(SaveGame(run: progress))
            hasSave = true
        } catch {
            hasSave = saveStore.hasSave
        }
    }

    // MARK: Commands

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
