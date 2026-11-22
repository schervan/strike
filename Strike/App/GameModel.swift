import Observation

/// App-wide observable state shared by SwiftUI (menus, HUD) and the SpriteKit scene.
/// M0 stub: only screen routing. Gameplay state (HP, ammo, inventory) arrives in M1+.
@MainActor
@Observable
final class GameModel {
    enum Screen: Equatable {
        case title
        case game
    }

    private(set) var screen: Screen = .title

    func startGame() {
        screen = .game
    }

    func returnToTitle() {
        screen = .title
    }
}
