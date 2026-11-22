import SwiftUI

/// In-game SwiftUI overlay (ART_BIBLE §7 positions, minus the Fire button): HP bar, ammo readout
/// and key chips top-left, RELOAD and INTERACT on the right column, toast line top-centre.
/// Reads `GameModel.hud`, sends `GameCommand`s.
struct HUDView: View {
    @Environment(GameModel.self) private var model

    /// ART_BIBLE §7 geometry (layout, not balance).
    private enum Layout {
        static let margin: CGFloat = 16
        static let hpBar = CGSize(width: 240, height: 28)
        static let hpInset: CGFloat = 4
        static let icon: CGFloat = 32
        static let button: CGFloat = 72
        static let reloadRight: CGFloat = 24
        static let reloadBottom: CGFloat = 252
        static let interactBottom: CGFloat = 164
        static let interactGlow: CGFloat = 88
        static let chip: CGFloat = 40
        static let chipGap: CGFloat = 8
        static let chipsTop: CGFloat = 92
        static let toastTop: CGFloat = 124
    }

    private static let panel = Color(red: 0x2E / 255, green: 0x2A / 255, blue: 0x55 / 255)
    private static let outline = Color(red: 0x2B / 255, green: 0x21 / 255, blue: 0x40 / 255)
    private static let heal = Color(red: 0x5F / 255, green: 0xE0 / 255, blue: 0x8A / 255)
    private static let star = Color(red: 0xFF / 255, green: 0xD9 / 255, blue: 0x3D / 255)

    var body: some View {
        let hud = model.hud
        ZStack {
            VStack(alignment: .leading, spacing: 8) {
                hpBar(hud)
                ammoReadout(hud)
                Spacer()
            }
            .padding(.leading, Layout.margin)
            .padding(.top, Layout.margin)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            keyChips(hud)
                .padding(.leading, Layout.margin)
                .padding(.top, Layout.chipsTop)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            reloadButton(hud)
                .padding(.trailing, Layout.reloadRight)
                .padding(.bottom, Layout.reloadBottom)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)

            interactButton(hud)
                .padding(.trailing, Layout.reloadRight - (Layout.interactGlow - Layout.button) / 2)
                .padding(.bottom, Layout.interactBottom - (Layout.interactGlow - Layout.button) / 2)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)

            toastLine
                .padding(.top, Layout.toastTop)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .allowsHitTesting(false)
        }
    }

    // MARK: Interact

    @State private var glowPulse = false

    private func interactButton(_ hud: HUDState) -> some View {
        let focused = hud.interact != nil
        let usable = hud.interact?.usable ?? false
        return Button {
            model.requestInteract()
        } label: {
            ZStack {
                if focused && usable {
                    Circle()
                        .fill(Self.star.opacity(0.5))
                        .frame(width: Layout.interactGlow, height: Layout.interactGlow)
                        .scaleEffect(glowPulse ? 1.12 : 1.0)
                        .animation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true), value: glowPulse)
                        .onAppear { glowPulse = true }
                        .onDisappear { glowPulse = false }
                }
                AtlasImage("ui_btn_interact")
                    .frame(width: Layout.button, height: Layout.button)
            }
            .frame(width: Layout.interactGlow, height: Layout.interactGlow)
            .contentShape(Circle())
        }
        .buttonStyle(HUDButtonStyle())
        .opacity(focused && usable ? 1 : 0.45)
        .saturation(focused ? 1 : 0)
        .animation(.easeOut(duration: 0.15), value: focused)
        .accessibilityIdentifier("hud.interactButton")
        .accessibilityLabel(Text("hud.interact"))
        .accessibilityHint(Text("hud.interact.accessibility"))
        .accessibilityValue(Text(verbatim: hud.interact?.kind ?? ""))
    }

    // MARK: Key chips

    private func keyChips(_ hud: HUDState) -> some View {
        VStack(alignment: .leading, spacing: Layout.chipGap) {
            ForEach(hud.carried.keys.sorted(), id: \.self) { id in
                ZStack(alignment: .bottomTrailing) {
                    Circle()
                        .fill(Self.panel.opacity(0.85))
                        .overlay(Circle().stroke(Self.outline, lineWidth: 2))
                    AtlasImage("pickup_\(id)", atlas: "items")
                        .padding(4)
                    if let n = hud.carried[id], n > 1 {
                        Text(verbatim: "\(n)")
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .shadow(color: Self.outline, radius: 0, x: 1, y: 1)
                    }
                }
                .frame(width: Layout.chip, height: Layout.chip)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("hud.keyChips")
        .accessibilityLabel(Text("hud.keyChips.accessibility"))
        .accessibilityValue(Text(verbatim: hud.carried.keys.sorted().map { "\($0) \(hud.carried[$0]!)" }.joined(separator: ", ")))
    }

    // MARK: Toast

    @ViewBuilder private var toastLine: some View {
        if let t = model.toast {
            Text(verbatim: t.text)
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: Self.outline, radius: 0, x: 2, y: 2)
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(Capsule().fill(Self.panel.opacity(0.85)))
                .id(t.id)
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                .accessibilityIdentifier("hud.toast")
        }
    }

    // MARK: HP

    private func hpBar(_ hud: HUDState) -> some View {
        let ratio = hud.maxHp > 0 ? CGFloat(hud.hp) / CGFloat(hud.maxHp) : 0
        let fillWidth = (Layout.hpBar.width - 2 * Layout.hpInset) * max(0, min(1, ratio))
        return HStack(spacing: 6) {
            AtlasImage("ui_icon_heart")
                .frame(width: Layout.icon, height: Layout.icon)
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: Layout.hpBar.height / 2)
                    .fill(Self.panel.opacity(0.85))
                    .overlay(RoundedRectangle(cornerRadius: Layout.hpBar.height / 2).stroke(Self.outline, lineWidth: 2))
                RoundedRectangle(cornerRadius: (Layout.hpBar.height - 2 * Layout.hpInset) / 2)
                    .fill(Self.heal)
                    .frame(width: fillWidth, height: Layout.hpBar.height - 2 * Layout.hpInset)
                    .padding(.leading, Layout.hpInset)
                    .animation(.easeOut(duration: 0.2), value: hud.hp)
            }
            .frame(width: Layout.hpBar.width, height: Layout.hpBar.height)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("hud.hpBar")
        .accessibilityLabel(Text(String(format: String(localized: "hud.hp.accessibility"), hud.hp, hud.maxHp)))
        .accessibilityValue(Text(verbatim: "\(hud.hp) / \(hud.maxHp)"))
    }

    // MARK: Ammo

    private func ammoReadout(_ hud: HUDState) -> some View {
        HStack(spacing: 6) {
            AtlasImage(hud.weaponId.isEmpty ? "ui_icon_blaster_starter" : "ui_icon_\(hud.weaponId)")
                .frame(width: Layout.icon, height: Layout.icon)
            AtlasImage("ui_icon_ammo")
                .frame(width: Layout.icon, height: Layout.icon)
            Text(verbatim: "\(hud.magazine) / \(hud.reserve)")
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .shadow(color: Self.outline, radius: 0, x: 2, y: 2)
            if hud.isReloading {
                Text("hud.reloading")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Self.star)
                    .shadow(color: Self.outline, radius: 0, x: 1.5, y: 1.5)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 2)
        .background(Capsule().fill(Self.panel.opacity(0.85)))
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("hud.ammoLabel")
        .accessibilityLabel(Text(String(format: String(localized: "hud.ammo.accessibility"), hud.magazine, hud.reserve)))
        .accessibilityValue(Text(verbatim: "\(hud.magazine) / \(hud.reserve)"))
    }

    // MARK: Reload

    private func reloadButton(_ hud: HUDState) -> some View {
        let label: LocalizedStringKey = hud.isReloading ? "hud.reloading" : "hud.reload"
        let enabled = hud.canReload
        return Button {
            model.requestReload()
        } label: {
            ZStack {
                AtlasImage("ui_btn_reload")
                    .frame(width: Layout.button, height: Layout.button)
                if hud.isReloading {
                    Circle()
                        .trim(from: 0, to: hud.reloadProgress)
                        .stroke(Self.star, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: Layout.button - 6, height: Layout.button - 6)
                }
            }
            .frame(width: Layout.button, height: Layout.button)
            .contentShape(Circle())
        }
        .buttonStyle(HUDButtonStyle())
        .opacity(enabled || hud.isReloading ? 1 : 0.45)
        .saturation(enabled || hud.isReloading ? 1 : 0)
        .accessibilityIdentifier("hud.reloadButton")
        .accessibilityLabel(Text(label))
    }
}

/// ART_BIBLE §7: 70 % alpha idle, 100 % and scale 0.92 while pressed.
struct HUDButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 1 : 0.7)
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
    }
}
