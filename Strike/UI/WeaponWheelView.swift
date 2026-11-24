import SwiftUI

/// SWAP button (ART_BIBLE §15.7): visible once 2 or more blasters are owned. Tap = next blaster
/// (GDD §5.1), hold `rules.weapons.wheelLongPressSec` = the weapon wheel. The next blaster's icon
/// sits as a badge; a ring sweeps while a swap runs.
struct SwapButton: View {
    @Environment(GameModel.self) private var model
    let hud: HUDState
    @State private var pressing = false
    @State private var appeared = false

    private static let star = Color(red: 0xFF / 255, green: 0xD9 / 255, blue: 0x3D / 255)
    private static let plate = Color(red: 0x2E / 255, green: 0x2A / 255, blue: 0x55 / 255)
    private static let outline = Color(red: 0x2B / 255, green: 0x21 / 255, blue: 0x40 / 255)
    static let size: CGFloat = 72

    var body: some View {
        let hold = model.data.rules.weapons.wheelLongPressSec
        ZStack(alignment: .topTrailing) {
            AtlasImage("ui_btn_swap")
                .frame(width: Self.size, height: Self.size)
                .opacity(pressing ? 1 : 0.7)
                .scaleEffect(pressing ? 1.15 : 1)
                .animation(.easeOut(duration: hold), value: pressing)
            Circle()
                .trim(from: 0, to: pressing ? 1 : 0)
                .stroke(Self.star, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: Self.size + 8, height: Self.size + 8)
                .offset(x: 4, y: -4)
                .animation(pressing ? .linear(duration: hold) : .easeOut(duration: 0.1), value: pressing)
            if hud.isSwapping {
                Circle()
                    .stroke(.white.opacity(0.6), lineWidth: 3)
                    .frame(width: Self.size, height: Self.size)
            }
            if let next = hud.nextWeaponId {
                AtlasImage("ui_icon_\(next)")
                    .frame(width: 22, height: 22)
                    .padding(3)
                    .background(Circle().fill(Self.plate))
                    .overlay(Circle().stroke(Self.outline, lineWidth: 2))
                    .offset(x: 6, y: -6)
            }
            if !appeared {
                Circle().stroke(Self.star, lineWidth: 2).frame(width: 104, height: 104).offset(x: 16, y: -16)
                    .transition(.opacity)
            }
        }
        .frame(width: Self.size, height: Self.size)
        .contentShape(Circle())
        .onTapGesture {
            guard !hud.isSwapping else { return }
            AudioManager.shared.play(.uiTap)
            model.send(.swapNext)
        }
        .onLongPressGesture(minimumDuration: hold, perform: {
            AudioManager.shared.play(.uiTap)
            model.isWheelOpen = true
        }, onPressingChanged: { pressing = $0 })
        .onAppear { withAnimation(.easeOut(duration: 0.4).delay(0.3)) { appeared = true } }
        .accessibilityElement()
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("hud.swapButton")
        .accessibilityLabel(Text("hud.swap.accessibility"))
        .accessibilityHint(Text("hud.swap.accessibilityHint"))
        .accessibilityValue(Text(verbatim: hud.weapons.first(where: \.equipped)?.id ?? ""))
        .accessibilityAction { model.send(.swapNext) }
        .accessibilityAction(named: Text("hud.weaponWheel.accessibility")) { model.isWheelOpen = true }
    }
}

/// Weapon wheel (ART_BIBLE §15.7): 3 slots fanned around the SWAP button; 80 pt plates. The
/// §15.7 angles (150°/100°/50°) would push the right slot off the screen edge (the button sits
/// 24 pt from it) and the clamp piles the slots up, so the fan opens to the left and up instead
/// (180°/135°/90° at radius 140: 107 pt between centres, 27 pt between plates); owned slots show magazine / reserve, locked ones a silhouette. Tap a
/// slot to pick, tap the dim to close. Game time runs at `wheelTimeScale` while it is open.
struct WeaponWheelView: View {
    @Environment(GameModel.self) private var model

    private static let plate = Color(red: 0x2E / 255, green: 0x2A / 255, blue: 0x55 / 255)
    private static let rim = Color(red: 0x4A / 255, green: 0x45 / 255, blue: 0x85 / 255)
    private static let pill = Color(red: 0x1E / 255, green: 0x1B / 255, blue: 0x3D / 255)
    private static let outline = Color(red: 0x2B / 255, green: 0x21 / 255, blue: 0x40 / 255)
    private static let star = Color(red: 0xFF / 255, green: 0xD9 / 255, blue: 0x3D / 255)
    private static let green = Color(red: 0x5F / 255, green: 0xE0 / 255, blue: 0x8A / 255)
    private static let angles: [Double] = [180, 135, 90]
    private static let radius: CGFloat = 140
    private static let slot: CGFloat = 80

    var body: some View {
        GeometryReader { geo in
            let centre = CGPoint(x: geo.size.width - 24 - SwapButton.size / 2,
                                 y: geo.size.height - 340 - SwapButton.size / 2)
            ZStack {
                Self.pill.opacity(0.35)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { model.isWheelOpen = false }
                    .accessibilityIdentifier("hud.weaponWheel.dim")
                ForEach(Array(model.hud.weapons.prefix(3).enumerated()), id: \.element.id) { i, w in
                    let a = Self.angles[i] * .pi / 180
                    let p = CGPoint(x: centre.x + cos(a) * Self.radius, y: centre.y - sin(a) * Self.radius)
                    slotView(w, index: i)
                        .position(x: min(max(p.x, Self.slot / 2 + 16), geo.size.width - Self.slot / 2 - 16), y: max(p.y, Self.slot / 2 + 16))
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("hud.weaponWheel")
            .accessibilityLabel(Text("hud.weaponWheel.accessibility"))
        }
    }

    private func slotView(_ w: WeaponSlotState, index i: Int) -> some View {
        let color = Self.color(w.id)
        let name = String(localized: String.LocalizationValue(w.nameKey))
        return VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                Circle().fill(Self.plate.opacity(0.95))
                    .overlay(Circle().stroke(w.equipped ? Self.star : Self.rim, lineWidth: 3))
                    .overlay(Circle().inset(by: 2).stroke(color, lineWidth: 4).opacity(w.owned ? 1 : 0.3))
                AtlasImage("ui_icon_\(w.id)")
                    .frame(width: 48, height: 48)
                    .saturation(w.owned ? 1 : 0)
                    .opacity(w.owned ? 1 : 0.5)
                    .frame(width: Self.slot, height: Self.slot)
                if w.equipped {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Self.green))
                        .overlay(Circle().stroke(Self.outline, lineWidth: 2))
                } else if !w.owned {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Self.rim))
                        .overlay(Circle().stroke(Self.outline, lineWidth: 2))
                }
            }
            .frame(width: Self.slot, height: Self.slot)
            .scaleEffect(w.equipped ? 1.1 : 1)
            if w.owned {
                Text(String(format: String(localized: "hud.weaponWheel.ammo"), w.magazine, w.reserve))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(w.reserve == 0 ? Self.star : .white)
                    .shadow(color: Self.outline, radius: 0, x: 1, y: 1)
                    .frame(minWidth: 56, minHeight: 20)
                    .background(Capsule().fill(Self.pill.opacity(0.85)))
            }
        }
        .contentShape(Circle())
        .onTapGesture {
            guard w.owned else { return }
            AudioManager.shared.play(.uiTap)
            if !w.equipped { model.send(.swapTo(w.id)) }
            model.isWheelOpen = false
        }
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("hud.weaponWheel.slot.\(i)")
        .accessibilityLabel(Text(verbatim: w.owned
            ? String(format: String(localized: "hud.weaponWheel.slot.accessibility"), name, w.magazine, w.reserve)
            : String(localized: "hud.weaponWheel.locked.accessibility")))
        .accessibilityValue(Text(w.equipped ? "hud.weaponWheel.equipped.accessibility" : ""))
    }

    /// Weapon colours (ART_BIBLE §2): starter orange, spread purple, rapid yellow.
    static func color(_ id: String) -> Color {
        switch id {
        case "blaster_spread": Color(red: 0xB0 / 255, green: 0x5C / 255, blue: 1)
        case "blaster_rapid": Color(red: 1, green: 0xD9 / 255, blue: 0x3D / 255)
        default: Color(red: 1, green: 0x8A / 255, blue: 0x3D / 255)
        }
    }
}

/// Boss bar (ART_BIBLE §15.8): no numbers; pink HP fill, white phase notches that turn gold when
/// passed, a cyan hatch while the shield is up and core pips (filled / hollow) next to it.
struct BossBarView: View {
    let state: BossBarState

    private static let frame = Color(red: 0x1E / 255, green: 0x1B / 255, blue: 0x3D / 255)
    private static let line = Color(red: 0x4A / 255, green: 0x45 / 255, blue: 0x85 / 255)
    private static let outline = Color(red: 0x2B / 255, green: 0x21 / 255, blue: 0x40 / 255)
    private static let magenta = Color(red: 0xD6 / 255, green: 0x1F / 255, blue: 0x8F / 255)
    private static let pinkL = Color(red: 1, green: 0x8A / 255, blue: 0xB8 / 255)
    private static let pinkR = Color(red: 1, green: 0x3B / 255, blue: 0x5C / 255)
    private static let cyan = Color(red: 0x3D / 255, green: 0xE3 / 255, blue: 0xD0 / 255)
    private static let star = Color(red: 0xFF / 255, green: 0xD9 / 255, blue: 0x3D / 255)
    private static let green = Color(red: 0x5F / 255, green: 0xE0 / 255, blue: 0x8A / 255)
    private static let width: CGFloat = 420, height: CGFloat = 28, fillWidth: CGFloat = 400

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(Self.magenta).frame(width: 44, height: 44)
                    .overlay(Circle().stroke(Self.outline, lineWidth: 2))
                AtlasImage("boss_megamech_idle_01", atlas: "boss").frame(width: 34, height: 34)
            }
            ZStack(alignment: .leading) {
                Capsule().fill(Self.frame.opacity(0.9))
                    .overlay(Capsule().stroke(Self.outline, lineWidth: 3))
                    .overlay(Capsule().inset(by: 3).stroke(Self.line, lineWidth: 2))
                Group {
                    if state.immune {
                        Capsule().fill(Self.cyan.opacity(0.8))
                            .overlay(Hatch().stroke(.white.opacity(0.5), lineWidth: 3).clipShape(Capsule()))
                    } else {
                        Capsule().fill(LinearGradient(colors: [Self.pinkL, Self.pinkR], startPoint: .leading, endPoint: .trailing))
                            .overlay(alignment: .top) { Capsule().fill(.white.opacity(0.25)).frame(height: 6).padding(.horizontal, 6).padding(.top, 2) }
                    }
                }
                .frame(width: max(Self.height - 8, Self.fillWidth * state.hpRatio), height: Self.height - 8)
                .padding(.leading, (Self.width - Self.fillWidth) / 2)
                .animation(.easeOut(duration: 0.4), value: state.hpRatio)
                ForEach(Array(state.notches.enumerated()), id: \.offset) { _, n in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(state.hpRatio <= n + 0.0001 ? Self.star : .white)
                        .overlay(RoundedRectangle(cornerRadius: 2).stroke(Self.outline, lineWidth: 1))
                        .frame(width: 4, height: Self.height + 12)
                        .offset(x: (Self.width - Self.fillWidth) / 2 + Self.fillWidth * n - 2)
                }
            }
            .frame(width: Self.width, height: Self.height)
            .shadow(color: state.immune ? Self.cyan : .clear, radius: 3)
            if state.coresNeeded > 0 {
                HStack(spacing: 4) {
                    ForEach(0..<state.coresNeeded, id: \.self) { i in
                        Circle().fill(i < state.coresIn ? Self.green : .clear)
                            .overlay(Circle().stroke(i < state.coresIn ? Self.outline : Color(red: 0.56, green: 0.64, blue: 0.78), lineWidth: 2))
                            .frame(width: 14, height: 14)
                    }
                }
            }
        }
        .opacity(state.defeated ? 0 : 1)
        .animation(.easeOut(duration: 0.4), value: state.defeated)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("hud.bossBar")
        .accessibilityLabel(Text(verbatim: String(format: String(localized: "hud.bossBar.accessibility"),
                                                  String(localized: String.LocalizationValue(state.nameKey)), state.phase, state.phases)))
        .accessibilityValue(Text(state.immune ? "hud.bossBar.shield.accessibility" : ""))
    }

    private struct Hatch: Shape {
        func path(in r: CGRect) -> Path {
            var p = Path()
            var x = r.minX - r.height
            while x < r.maxX { p.move(to: CGPoint(x: x, y: r.maxY)); p.addLine(to: CGPoint(x: x + r.height, y: r.minY)); x += 8 }
            return p
        }
    }
}
