import SwiftUI

/// Q1…Q4 at the bottom centre (ART_BIBLE §7 / §14.1): 72 pt slots, gap 12. A slot is a link to an
/// item id and shows its total count; greyed silhouette at 0, dashed when empty (tap opens the
/// bag), cooldown sweep, shake + toast when the use is refused.
struct QuickSlotBar: View {
    @Environment(GameModel.self) private var model

    enum Layout {
        static let slot: CGFloat = 72
        static let gap: CGFloat = 12
        static let item: CGFloat = 48
        static let badge: CGFloat = 24
        static let bottom: CGFloat = 16
    }

    @State private var shake: [Int: CGFloat] = [:]
    @State private var pop: [Int: Bool] = [:]

    var body: some View {
        let slots = model.hud.quickSlots
        HStack(spacing: Layout.gap) {
            ForEach(0..<max(4, slots.count), id: \.self) { i in
                slot(i, i < slots.count ? slots[i] : QuickSlotState())
            }
        }
        .onChange(of: model.useFeedback) { _, f in
            guard let f, let q = f.quickSlot else { return }
            switch f.kind {
            case .refused:
                withAnimation(.linear(duration: 0.2)) { shake[q, default: 0] += 1 }
            case .used:
                withAnimation(.easeOut(duration: 0.08)) { pop[q] = true }
                withAnimation(.easeIn(duration: 0.08).delay(0.08)) { pop[q] = false }
            }
        }
    }

    private func slot(_ i: Int, _ s: QuickSlotState) -> some View {
        let name = s.itemId.flatMap { model.data.items[$0]?.nameKey }.map { String(localized: String.LocalizationValue($0)) }
        let label: String = {
            if let name { return String(format: String(localized: "hud.quickSlot.accessibility"), i + 1, name, s.count) }
            return String(format: String(localized: "hud.quickSlot.empty.accessibility"), i + 1)
        }()
        return Button {
            model.send(.useQuick(i))
        } label: {
            ZStack {
                AtlasImage("ui_quickslot")
                    .frame(width: Layout.slot, height: Layout.slot)
                    .opacity(s.itemId == nil ? 0.45 : (s.count == 0 ? 0.7 : 1))
                if let id = s.itemId {
                    AtlasImage("pickup_\(id)", atlas: "items")
                        .frame(width: Layout.item, height: Layout.item)
                        .offset(y: -2)
                        .saturation(s.count == 0 ? 0 : (s.usable ? 1 : 0.35))
                        .brightness(s.count > 0 && !s.usable ? 0.12 : 0)
                        .opacity(s.count == 0 ? 0.35 : (s.usable && s.cooldown == 0 ? 1 : 0.6))
                        .scaleEffect(pop[i] == true ? 1.2 : 1)
                    if s.cooldown > 0 {
                        CooldownSweep(fraction: s.cooldown)
                            .fill(Color(red: 0x1E / 255, green: 0x1B / 255, blue: 0x3D / 255).opacity(0.6))
                            .frame(width: Layout.slot - 8, height: Layout.slot - 8)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    if s.count > 1 {
                        CountBadge(count: s.count, size: Layout.badge, font: 15)
                            .offset(x: Layout.slot / 2 - 4, y: Layout.slot / 2 - 4)
                    }
                } else {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(HUDColors.dash, style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
                        .frame(width: Layout.slot - 12, height: Layout.slot - 12)
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(HUDColors.dash.opacity(0.6))
                }
            }
            .frame(width: Layout.slot, height: Layout.slot)
            .contentShape(Rectangle())
            .modifier(ShakeEffect(shakes: shake[i] ?? 0))
        }
        .buttonStyle(QuickSlotButtonStyle())
        .accessibilityIdentifier("hud.quickSlot.\(i)")
        .accessibilityLabel(Text(verbatim: label))
        .accessibilityValue(Text(verbatim: "\(s.count)"))
    }
}

/// ART_BIBLE §14.1: slots read as content: 85 % idle, 100 % and 0.92 while pressed.
struct QuickSlotButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 1 : 0.85)
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.06), value: configuration.isPressed)
    }
}

/// Pie from 12 o'clock that shrinks clockwise as the cooldown runs out.
struct CooldownSweep: Shape {
    var fraction: Double

    var animatableData: Double {
        get { fraction }
        set { fraction = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = max(rect.width, rect.height)
        p.move(to: c)
        p.addArc(center: c, radius: r, startAngle: .degrees(-90), endAngle: .degrees(-90 + 360 * max(0, min(1, fraction))),
                 clockwise: false)
        p.closeSubpath()
        return p
    }
}

/// "No" shake: x +6, −6, +4, −4, 0 (ART_BIBLE §14.1). Each increment of `shakes` plays it once.
struct ShakeEffect: GeometryEffect {
    var shakes: CGFloat

    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let t = shakes - shakes.rounded(.down)
        let amp: CGFloat = t < 0.5 ? 6 : 4
        return ProjectionTransform(CGAffineTransform(translationX: amp * sin(t * .pi * 4), y: 0))
    }
}

/// Round count badge (ART_BIBLE §14.1): #2E2A55 fill, plum outline, white hairline, white number.
struct CountBadge: View {
    let count: Int
    let size: CGFloat
    let font: CGFloat

    var body: some View {
        Text(verbatim: "\(min(99, count))")
            .font(.system(size: font, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Circle().fill(HUDColors.panel))
            .overlay(Circle().stroke(HUDColors.outline, lineWidth: 2))
            .overlay(Circle().inset(by: 2).stroke(.white.opacity(0.4), lineWidth: 1))
            .accessibilityHidden(true)
    }
}

/// Shared HUD colours (ART_BIBLE §2 / §14).
enum HUDColors {
    static func hex(_ v: UInt32, _ a: Double = 1) -> Color {
        Color(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255,
              opacity: a)
    }

    static let panel = hex(0x2E2A55)
    static let outline = hex(0x2B2140)
    static let line = hex(0x4A4585)
    static let dim = hex(0x1E1B3D)
    static let dash = hex(0x8FA3C8)
    static let star = hex(0xFFD93D)
    static let heal = hex(0x5FE08A)
    static let accent = hex(0xFFB347)
    static let blue = hex(0x3D8BFF)
    static let cyan = hex(0x3DE3D0)
    static let cyanLight = hex(0xBFFFF7)
    static let desc = hex(0xC9D2EA)
}
