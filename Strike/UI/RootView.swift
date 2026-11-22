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
        }
        .animation(.easeInOut(duration: 0.25), value: model.screen)
        .ignoresSafeArea()
    }
}

struct TitleView: View {
    @Environment(GameModel.self) private var model

    var body: some View {
        ZStack {
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
        }
    }
}

#Preview(traits: .landscapeLeft) {
    RootView()
        .environment(GameModel())
}
