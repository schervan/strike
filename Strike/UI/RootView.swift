import SwiftUI

struct RootView: View {
    @Environment(GameModel.self) private var model

    var body: some View {
        ZStack {
            switch model.screen {
            case .title:
                TitleView()
                    .transition(.opacity)
            case .game:
                if let run = model.run {
                    GameContainerView(run: run)
                        .id(run.id)
                        .transition(.opacity)
                }
            case .levelComplete(let result):
                LevelCompleteView(result: result)
                    .transition(.opacity)
            }
            if model.isSettingsOpen {
                SettingsView()
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: model.screen)
        .animation(.easeOut(duration: 0.15), value: model.isSettingsOpen)
        .ignoresSafeArea()
        .onChange(of: model.screen, initial: true) { _, screen in updateMusic(screen) }
        .onChange(of: model.isPaused) { _, paused in AudioManager.shared.setGamePaused(paused) }
    }

    /// Title loop on the title screen, `levels.json` music in a level; the Level complete card
    /// keeps the level loop under the jingle.
    private func updateMusic(_ screen: GameModel.Screen) {
        switch screen {
        case .title:
            AudioManager.shared.playMusic(MusicID.title)
        case .game:
            if let id = model.run?.levelId, let level = model.data.levels[id] {
                AudioManager.shared.playMusic(level.music)
            }
        case .levelComplete:
            break
        }
    }
}

struct TitleView: View {
    @Environment(GameModel.self) private var model

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color(red: 0.06, green: 0.07, blue: 0.14)
                .ignoresSafeArea()
            VStack(spacing: 32) {
                Text("title.gameName")
                    .font(.system(size: 96, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .accessibilityIdentifier("titleLabel")
                Text("title.tagline")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.7))
                Button {
                    AudioManager.shared.play(.uiTap)
                    model.startGame()
                } label: {
                    Text("title.start")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .padding(.horizontal, 64)
                        .padding(.vertical, 20)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .accessibilityIdentifier("startButton")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Button {
                AudioManager.shared.play(.uiTap)
                model.openSettings()
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 80, height: 80)
                    .background(Circle().fill(.white.opacity(0.15)))
                    .contentShape(Circle())
            }
            .buttonStyle(HUDButtonStyle())
            .padding(24)
            .accessibilityIdentifier("title.settingsButton")
            .accessibilityLabel(Text("settings.open"))
        }
    }
}

#Preview(traits: .landscapeLeft) {
    RootView()
        .environment(GameModel())
}
