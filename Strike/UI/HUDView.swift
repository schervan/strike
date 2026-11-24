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
        static let inventoryRight: CGFloat = 96
        static let badge: CGFloat = 24
        static let swapBottom: CGFloat = 340
        static let bossBarTop: CGFloat = 64
        /// The boss bar slides down this much while Pixel's bubble shows (ART_BIBLE §15.8).
        static let bossBarBubbleShift: CGFloat = 36
    }

    // MARK: Inventory button (ART_BIBLE §7, §14.3 "!" badge, §14.6 hint glow)

    @State private var badgeBounce = false
    @State private var hintGlow = false

    private func inventoryButton(_ hud: HUDState) -> some View {
        Button {
            AudioManager.shared.play(.uiTap)
            model.openInventory()
        } label: {
            ZStack(alignment: .topTrailing) {
                AtlasImage("ui_btn_inventory")
                    .frame(width: Layout.button, height: Layout.button)
                if hud.bagHint {
                    Circle()
                        .stroke(Self.star, lineWidth: 2)
                        .frame(width: Layout.button + 6, height: Layout.button + 6)
                        .opacity(hintGlow ? 1 : 0.4)
                        .offset(x: 3, y: -3)
                        .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: hintGlow)
                        .onAppear { hintGlow = true }
                        .onDisappear { hintGlow = false }
                }
                if hud.bagFull {
                    BangBadge(size: Layout.badge)
                        .scaleEffect(badgeBounce ? 1.2 : 1)
                        .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: badgeBounce)
                        .onAppear { badgeBounce = true }
                        .onDisappear { badgeBounce = false }
                        .offset(x: 4, y: -4)
                }
            }
            .frame(width: Layout.button, height: Layout.button)
            .contentShape(Rectangle())
        }
        .buttonStyle(HUDButtonStyle())
        .accessibilityIdentifier("hud.inventoryButton")
        .accessibilityLabel(Text("hud.inventory.accessibility"))
        .accessibilityValue(Text(verbatim: hud.bagFull ? "full" : ""))
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

            if hud.swapVisible {
                SwapButton(hud: hud)
                    .padding(.trailing, Layout.reloadRight)
                    .padding(.bottom, Layout.swapBottom)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .transition(.scale(scale: 0.1).combined(with: .opacity))
            }

            if let boss = hud.boss {
                BossBarView(state: boss)
                    .padding(.top, Layout.bossBarTop + (model.bubble != nil ? Layout.bossBarBubbleShift : 0))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .animation(.easeOut(duration: 0.25), value: model.bubble != nil)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .allowsHitTesting(false)
            }

            interactButton(hud)
                .padding(.trailing, Layout.reloadRight - (Layout.interactGlow - Layout.button) / 2)
                .padding(.bottom, Layout.interactBottom - (Layout.interactGlow - Layout.button) / 2)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)

            inventoryButton(hud)
                .padding(.trailing, Layout.inventoryRight)
                .padding(.top, Layout.margin)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

            QuickSlotBar()
                .padding(.bottom, QuickSlotBar.Layout.bottom)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)

            toastLine
                .padding(.top, Layout.toastTop)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .allowsHitTesting(false)
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.55), value: hud.swapVisible)
        .animation(.easeOut(duration: 0.3), value: hud.boss != nil)
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
            LowHpHeart(active: hud.lowHp, fast: hud.maxHp > 0 && Double(hud.hp) / Double(hud.maxHp) < 0.15)
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
            .overlay(alignment: .trailing) {
                if hud.slowed {
                    // ART_BIBLE §15.4: spore slow badge right of the bar.
                    ZStack {
                        Circle().fill(Color(red: 0xE3 / 255, green: 0x6B / 255, blue: 0xD8 / 255))
                        Circle().stroke(Self.outline, lineWidth: 2)
                        Image(systemName: "arrow.down").font(.system(size: 13, weight: .heavy)).foregroundStyle(.white)
                    }
                    .frame(width: 24, height: 24)
                    .offset(x: 32)
                    .accessibilityIdentifier("hud.slowBadge")
                }
            }
            .overlay {
                if hud.lowHp {
                    RoundedRectangle(cornerRadius: Layout.hpBar.height / 2)
                        .stroke(Self.star, lineWidth: 3)
                        .phaseAnimator([0.0, 0.8]) { v, a in v.opacity(a) } animation: { _ in .easeInOut(duration: 0.45) }
                }
            }
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

/// Heart icon with the low-HP "lub-dub" (ART_BIBLE §14.8): 1.0 → 1.25 → 1.0 → 1.15 → 1.0, about
/// 1.1 Hz (0.7 s period below 15 %), white glow behind it. Holds at 1.1 with Reduce Motion.
struct LowHpHeart: View {
    let active: Bool
    let fast: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if active {
                if reduceMotion {
                    glow(0.3)
                    heart.scaleEffect(1.1)
                } else {
                    TimelineView(.animation) { t in
                        let s = scale(at: t.date.timeIntervalSinceReferenceDate)
                        ZStack {
                            glow((s - 1) / 0.25 * 0.4)
                            heart.scaleEffect(s)
                        }
                    }
                }
            } else {
                heart
            }
        }
        .accessibilityIdentifier("hud.heart")
        .accessibilityValue(Text(verbatim: active ? "low" : ""))
    }

    private var heart: some View { AtlasImage("ui_icon_heart") }

    private func glow(_ alpha: Double) -> some View {
        Circle().fill(.white.opacity(max(0, alpha))).frame(width: 44, height: 44).blur(radius: 6)
    }

    private func scale(at time: Double) -> CGFloat {
        let period = fast ? 0.7 : 0.9
        let k = 0.9 / period
        let t = time.truncatingRemainder(dividingBy: period) * k
        switch t {
        case ..<0.12: return 1 + 0.25 * t / 0.12
        case ..<0.22: return 1.25 - 0.25 * (t - 0.12) / 0.10
        case ..<0.32: return 1 + 0.15 * (t - 0.22) / 0.10
        case ..<0.50: return 1.15 - 0.15 * (t - 0.32) / 0.18
        default: return 1
        }
    }
}
