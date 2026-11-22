import SwiftUI

/// Simple M2 "Level complete" card (DECISIONS: stars screen and level map are M5).
struct LevelCompleteView: View {
    @Environment(GameModel.self) private var model
    let result: LevelResult

    private static let panel = Color(red: 0x2E / 255, green: 0x2A / 255, blue: 0x55 / 255)
    private static let star = Color(red: 0xFF / 255, green: 0xD9 / 255, blue: 0x3D / 255)

    var body: some View {
        ZStack {
            Color(red: 0x1E / 255, green: 0x1B / 255, blue: 0x3D / 255).ignoresSafeArea()
            VStack(spacing: 20) {
                Text("levelComplete.title")
                    .font(.system(size: 64, weight: .heavy, design: .rounded))
                    .foregroundStyle(Self.star)
                Text(LocalizedStringKey(result.nameKey))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                VStack(spacing: 10) {
                    Text(String(format: String(localized: "levelComplete.time"), result.timeSec / 60, result.timeSec % 60))
                    Text(String(format: String(localized: "levelComplete.score"), result.score))
                    Text(String(format: String(localized: "levelComplete.datachips"), result.datachips, result.datachipsTotal))
                }
                .font(.system(size: 26, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
                .padding(24)
                .background(RoundedRectangle(cornerRadius: 20).fill(Self.panel.opacity(0.85)))
                HStack(spacing: 24) {
                    Button { model.returnToTitle() } label: {
                        Text("levelComplete.toTitle")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .padding(.horizontal, 32).padding(.vertical, 16)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .tint(.white)
                    .accessibilityIdentifier("levelComplete.toTitle")
                    Button { model.nextLevel() } label: {
                        Text("levelComplete.continue")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .padding(.horizontal, 48).padding(.vertical, 16)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .accessibilityIdentifier("levelComplete.continue")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("levelComplete.view")
    }
}
