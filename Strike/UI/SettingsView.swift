import SwiftUI

/// Settings panel (owner request): Music and Sound effects volume (0–100 %) plus "Mute all".
/// Opens over the title screen (gear) or the pause menu. Values apply live and persist through
/// `SettingsStore`. Kid-friendly: every control is at least 64 pt, icons plus text.
struct SettingsView: View {
    @Environment(GameModel.self) private var model
    var settings: SettingsStore = .shared
    var audio: AudioManager = .shared

    private enum Layout {
        static let target: CGFloat = 64
        static let panelWidth: CGFloat = 720
        static let step = 0.1
    }

    private static let panel = Color(red: 0x2E / 255, green: 0x2A / 255, blue: 0x55 / 255)
    private static let outline = Color(red: 0x2B / 255, green: 0x21 / 255, blue: 0x40 / 255)
    private static let star = Color(red: 0xFF / 255, green: 0xD9 / 255, blue: 0x3D / 255)

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture {} // swallow taps behind the panel
            VStack(spacing: 24) {
                Label {
                    Text("settings.title")
                } icon: {
                    Image(systemName: "gearshape.fill")
                }
                .font(.system(size: 48, weight: .heavy, design: .rounded))
                .foregroundStyle(Self.star)
                .accessibilityAddTraits(.isHeader)

                volumeRow(title: "settings.music", icon: "music.note", id: "settings.musicSlider",
                          value: settings.musicVolume, set: settings.setMusicVolume, sample: false)
                volumeRow(title: "settings.sfx", icon: "speaker.wave.2.fill", id: "settings.sfxSlider",
                          value: settings.sfxVolume, set: settings.setSFXVolume, sample: true)

                Toggle(isOn: Binding(get: { settings.muteAll }, set: { settings.setMuteAll($0) })) {
                    Label {
                        Text("settings.muteAll")
                    } icon: {
                        Image(systemName: settings.muteAll ? "speaker.slash.fill" : "speaker.fill")
                    }
                }
                .toggleStyle(BigToggleStyle(height: Layout.target, accent: Self.star))
                .accessibilityIdentifier("settings.muteToggle")

                Button {
                    audio.play(.uiBack)
                    model.closeSettings()
                } label: {
                    Label { Text("settings.done") } icon: { Image(systemName: "checkmark") }
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .padding(.horizontal, 48)
                        .frame(minHeight: Layout.target)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .accessibilityIdentifier("settings.done")
            }
            .padding(36)
            .frame(width: Layout.panelWidth)
            .background(RoundedRectangle(cornerRadius: 32).fill(Self.panel))
            .overlay(RoundedRectangle(cornerRadius: 32).stroke(Self.outline, lineWidth: 4))
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings.view")
    }

    private func volumeRow(title: LocalizedStringKey, icon: String, id: String, value: Double,
                           set: @escaping (Double) -> Void, sample: Bool) -> some View {
        let changed = { if sample { audio.play(.uiTap) } }
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label { Text(title) } icon: { Image(systemName: icon) }
                Spacer()
                Text(verbatim: "\(Int((value * 100).rounded())) %")
                    .monospacedDigit()
                    .accessibilityHidden(true)
            }
            .font(.system(size: 28, weight: .bold, design: .rounded))
            .foregroundStyle(.white)

            HStack(spacing: 16) {
                stepButton("minus", label: "settings.quieter", id: "\(id).minus") {
                    set(((value - Layout.step) * 10).rounded() / 10)
                    changed()
                }
                Slider(value: Binding(get: { value }, set: { set($0) }), in: 0...1, step: 0.05) { editing in
                    if !editing { changed() }
                } label: {
                    Text(title)
                }
                .tint(Self.star)
                .frame(minHeight: Layout.target)
                .accessibilityIdentifier(id)
                stepButton("plus", label: "settings.louder", id: "\(id).plus") {
                    set(((value + Layout.step) * 10).rounded() / 10)
                    changed()
                }
            }
        }
        .opacity(settings.muteAll ? 0.5 : 1)
    }

    private func stepButton(_ symbol: String, label: LocalizedStringKey, id: String,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 28, weight: .heavy))
                .frame(width: Layout.target, height: Layout.target)
                .background(Circle().fill(.white.opacity(0.15)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .accessibilityLabel(Text(label))
        .accessibilityIdentifier(id)
    }
}

/// Whole row is the tap target (≥ 64 pt); shows a big on/off pill.
struct BigToggleStyle: ToggleStyle {
    let height: CGFloat
    let accent: Color

    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack {
                configuration.label
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                Capsule()
                    .fill(configuration.isOn ? accent : .white.opacity(0.25))
                    .frame(width: 96, height: 52)
                    .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                        Circle().fill(.white).padding(5)
                    }
                    .animation(.easeOut(duration: 0.15), value: configuration.isOn)
            }
            .frame(minHeight: height)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityRepresentation {
            Toggle(isOn: configuration.$isOn) { configuration.label }
        }
    }
}
