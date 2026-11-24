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
                    // The scene freezes itself while `model.isGameFrozen` (SpriteView's `isPaused`
                    // does not reliably resume a scene that started paused behind the intro card).
                    isPaused: false,
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

            PixelBubbleView()

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
                .padding(.leading, 16)
                .padding(.bottom, 104)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            #endif

            if model.isIntroShowing, let level = model.data.levels[run.levelId] {
                LevelIntroView(level: level)
                    .transition(.opacity)
                    .zIndex(5)
            }

            if model.isInventoryOpen {
                InventoryView()
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
                    .zIndex(6)
            }

            if model.isPaused {
                PauseMenuView()
                    .transition(.opacity)
                    .zIndex(7)
            }
        }
        .animation(.easeOut(duration: 0.18), value: model.isInventoryOpen)
        .animation(.easeOut(duration: 0.2), value: model.isIntroShowing)
        .onAppear {
            guard scene == nil else { return }
            let s = GameScene(data: model.data, levelId: run.levelId, seed: run.seed, run: model.progress)
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
