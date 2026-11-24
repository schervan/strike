import SwiftUI

/// In-game pause menu (pause button): Resume, Settings, Main menu. The scene is frozen and the
/// music paused while it is open.
struct PauseMenuView: View {
    @Environment(GameModel.self) private var model
    var audio: AudioManager = .shared

    private static let panel = Color(red: 0x2E / 255, green: 0x2A / 255, blue: 0x55 / 255)
    private static let outline = Color(red: 0x2B / 255, green: 0x21 / 255, blue: 0x40 / 255)
    private static let star = Color(red: 0xFF / 255, green: 0xD9 / 255, blue: 0x3D / 255)

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {}
            VStack(spacing: 20) {
                Text("pause.title")
                    .font(.system(size: 56, weight: .heavy, design: .rounded))
                    .foregroundStyle(Self.star)
                    .accessibilityAddTraits(.isHeader)
                menuButton("pause.resume", icon: "play.fill", id: "pause.resume", prominent: true) {
                    audio.play(.uiBack)
                    model.resume()
                }
                menuButton("settings.title", icon: "gearshape.fill", id: "pause.settings", prominent: false) {
                    audio.play(.uiTap)
                    model.openSettings()
                }
                menuButton("pause.toTitle", icon: "house.fill", id: "pause.toTitle", prominent: false) {
                    audio.play(.uiBack)
                    model.returnToTitle()
                }
            }
            .padding(40)
            .frame(width: 520)
            .background(RoundedRectangle(cornerRadius: 32).fill(Self.panel))
            .overlay(RoundedRectangle(cornerRadius: 32).stroke(Self.outline, lineWidth: 4))
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pause.view")
    }

    @ViewBuilder
    private func menuButton(_ title: LocalizedStringKey, icon: String, id: String, prominent: Bool,
                            action: @escaping () -> Void) -> some View {
        let label = Label { Text(title) } icon: { Image(systemName: icon) }
            .font(.system(size: 30, weight: .bold, design: .rounded))
            .frame(maxWidth: .infinity, minHeight: 64)
        if prominent {
            Button(action: action) { label }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .accessibilityIdentifier(id)
        } else {
            Button(action: action) { label }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .tint(.white)
                .accessibilityIdentifier(id)
        }
    }
}
