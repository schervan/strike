import SpriteKit
import SwiftUI

/// Hosts the SpriteKit scene for one `LevelRun` with the SwiftUI HUD, minimap and (DEBUG) debug
/// overlay on top. Sticks are handled by the scene; HUD buttons sit above it and swallow their
/// own touches. A new run id gives a new view identity and therefore a new scene.
struct GameContainerView: View {
    @Environment(GameModel.self) private var model
    let run: LevelRun
    @State private var scene: GameScene?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let scene {
                SpriteView(
                    scene: scene,
                    isPaused: model.isPaused,
                    preferredFramesPerSecond: 60,
                    options: [.ignoresSiblingOrder],
                    debugOptions: debugOptions
                )
                .ignoresSafeArea()
                .accessibilityElement()
                .accessibilityIdentifier("gameView")
                .accessibilityLabel(Text("game.accessibilityLabel"))
            } else {
                Color(red: 0x1E / 255, green: 0x1B / 255, blue: 0x3D / 255).ignoresSafeArea()
            }

            HUDView()

            MinimapView()
                .padding(.trailing, MinimapView.Layout.right)
                .padding(.top, MinimapView.Layout.top)

            Button {
                AudioManager.shared.play(.uiTap)
                model.pause()
            } label: {
                AtlasImage("ui_btn_pause")
                    .frame(width: 64, height: 64)
            }
            .buttonStyle(HUDButtonStyle())
            .padding(16)
            .accessibilityIdentifier("menuButton")
            .accessibilityLabel(Text("game.menu"))

            #if DEBUG
            DebugOverlay()
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            #endif

            if model.isPaused {
                PauseMenuView()
                    .transition(.opacity)
            }
        }
        .onAppear {
            guard scene == nil else { return }
            let s = GameScene(data: model.data, levelId: run.levelId, seed: run.seed)
            s.model = model
            scene = s
        }
        .onDisappear { scene?.isPaused = true }
    }

    private var debugOptions: SpriteView.DebugOptions {
        #if DEBUG
        [.showsFPS, .showsNodeCount]
        #else
        []
        #endif
    }
}
