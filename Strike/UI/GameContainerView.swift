import SpriteKit
import SwiftUI

/// Hosts the SpriteKit scene. The HUD will be layered on top as a SwiftUI overlay.
struct GameContainerView: View {
    @Environment(GameModel.self) private var model
    @State private var scene = GameScene.makeDefault()

    var body: some View {
        ZStack(alignment: .topLeading) {
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

            Button {
                model.returnToTitle()
            } label: {
                Image(systemName: "pause.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(24)
            }
            .accessibilityIdentifier("menuButton")
            .accessibilityLabel(Text("game.menu"))
        }
        .onAppear { scene.model = model }
    }

    private var debugOptions: SpriteView.DebugOptions {
        #if DEBUG
        [.showsFPS, .showsNodeCount]
        #else
        []
        #endif
    }
}
