import SwiftUI

@main
struct StrikeApp: App {
    /// Launch arguments: `-StrikeAutoStart` skips the title screen; `-StrikeLevel l3` and
    /// `-StrikeSeed 1234` pick the first level and its seed (QA, UI tests, screenshots).
    @State private var model: GameModel = {
        let launch = LaunchOptions.current
        return GameModel(screen: launch.autoStart ? .game : .title, launch: launch)
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .statusBarHidden(true)
                .persistentSystemOverlays(.hidden)
        }
    }
}
