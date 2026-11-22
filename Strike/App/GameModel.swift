import Observation

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
}

/// Commands sent from SwiftUI buttons to the scene.
nonisolated enum GameCommand: Sendable, Equatable {
    case reload
}

/// App-wide observable state shared by SwiftUI (menus, HUD) and the SpriteKit scene.
@MainActor
@Observable
final class GameModel {
    enum Screen: Equatable {
        case title
        case game
    }

    private(set) var screen: Screen = .title
    var hud = HUDState()

    /// Set by the running `GameScene`.
    @ObservationIgnored var commandHandler: (@MainActor (GameCommand) -> Void)?

    init(screen: Screen = .title) {
        self.screen = screen
    }

    func startGame() {
        screen = .game
    }

    func returnToTitle() {
        screen = .title
    }

    func requestReload() {
        commandHandler?(.reload)
    }
}
