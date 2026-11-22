import SwiftUI

@main
struct StrikeApp: App {
    @State private var model = GameModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .statusBarHidden(true)
                .persistentSystemOverlays(.hidden)
        }
    }
}
