import SpriteKit
import SwiftUI

/// Hosts the SpriteKit scene with the SwiftUI HUD layered on top. Sticks are handled by the
/// scene; HUD buttons sit above it and swallow their own touches.
struct GameContainerView: View {
    @Environment(GameModel.self) private var model
    @State private var scene = GameScene.makeDefault()

    var body: some View {
        ZStack(alignment: .topTrailing) {
            SpriteView(
                scene: scene,
                preferredFramesPerSecond: 60,
                options: [.ignoresSiblingOrder],
                debugOptions: debugOptions
            )
            .ignoresSafeArea()
            .accessibilityElement()
            .accessibilityIdentifier("gameView")
            .accessibilityLabel(Text("game.accessibilityLabel"))

            HUDView()

            Button {
                model.returnToTitle()
            } label: {
                AtlasImage("ui_btn_pause")
                    .frame(width: 64, height: 64)
            }
            .buttonStyle(HUDButtonStyle())
            .padding(16)
            .accessibilityIdentifier("menuButton")
            .accessibilityLabel(Text("game.menu"))
        }
        .onAppear { scene.model = model }
        .onDisappear { model.commandHandler = nil }
    }

    private var debugOptions: SpriteView.DebugOptions {
        #if DEBUG
        [.showsFPS, .showsNodeCount]
        #else
        []
        #endif
    }
}
