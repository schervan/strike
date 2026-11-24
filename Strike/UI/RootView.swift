import SwiftUI

struct RootView: View {
    @Environment(GameModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase

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
            case .seasonComplete(let result):
                SeasonCompleteView(result: result)
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
        .onChange(of: model.run?.stage) { _, _ in updateMusic(model.screen) }
        .onChange(of: model.isPaused) { _, paused in AudioManager.shared.setGamePaused(paused) }
        .onChange(of: scenePhase) { _, phase in
            // Save on app background (GDD §16.10).
            if phase == .background || phase == .inactive { model.saveNow() }
        }
    }

    /// Title loop on the title screen, `levels.json` music in a level (`bossMusic` in the arena);
    /// the Level complete card keeps the level loop under the jingle, the Season complete card the
    /// `music_season_complete` jingle.
    private func updateMusic(_ screen: GameModel.Screen) {
        switch screen {
        case .title:
            AudioManager.shared.playMusic(MusicID.title)
        case .game:
            if let run = model.run, let level = model.data.levels[run.levelId] {
                // Boss arena: `bossMusic` crossfades in (GDD §9).
                AudioManager.shared.playMusic(run.stage == .bossArena ? (level.bossMusic ?? level.music) : level.music)
            }
        case .levelComplete, .seasonComplete:
            break
        }
    }
}

struct TitleView: View {
    @Environment(GameModel.self) private var model
    @State private var confirmNewGame = false

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
                if model.hasSave {
                    Button {
                        AudioManager.shared.play(.uiTap)
                        model.continueGame()
                    } label: {
                        Text("title.continue")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .padding(.horizontal, 64)
                            .padding(.vertical, 20)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .accessibilityIdentifier("title.continue")
                }
                Button {
                    AudioManager.shared.play(.uiTap)
                    if model.hasSave { confirmNewGame = true } else { model.newGame() }
                } label: {
                    Text("title.newGame")
                        .font(.system(size: model.hasSave ? 30 : 40, weight: .bold, design: .rounded))
                        .padding(.horizontal, model.hasSave ? 48 : 64)
                        .padding(.vertical, model.hasSave ? 14 : 20)
                        .frame(minHeight: 64)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .tint(model.hasSave ? HUDColors.panel : .accentColor)
                .accessibilityIdentifier("title.newGame")
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
        .alert(Text("title.newGameConfirm.title"), isPresented: $confirmNewGame) {
            Button(role: .cancel) { } label: { Text("title.newGameConfirm.no") }
            Button(role: .destructive) {
                model.newGame()
            } label: { Text("title.newGameConfirm.yes") }
        } message: {
            Text("title.newGameConfirm.message")
        }
    }
}

#Preview(traits: .landscapeLeft) {
    RootView()
        .environment(GameModel())
}
