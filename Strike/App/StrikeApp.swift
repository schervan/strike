import SwiftUI

@main
struct StrikeApp: App {
    /// `-StrikeAutoStart` (launch argument) skips the title screen (UI tests, screenshots).
    @State private var model = GameModel(
        screen: ProcessInfo.processInfo.arguments.contains("-StrikeAutoStart") ? .game : .title)

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .statusBarHidden(true)
                .persistentSystemOverlays(.hidden)
        }
    }
}
