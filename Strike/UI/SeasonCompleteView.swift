import SwiftUI

/// "Season complete" card after the boss (ART_BIBLE §15.14): ribbon header, hero and Pixel, the
/// L5 outro lines, total score and datachips (best per level, summed), the L5 time, and one Title
/// button that appears after 0.8 s. No red, no "game over" words; text through Localizable.
struct SeasonCompleteView: View {
    @Environment(GameModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let result: LevelResult

    @State private var shown = false
    @State private var buttonShown = false
    @State private var hop = false

    private static let dim = Color(red: 0x1E / 255, green: 0x1B / 255, blue: 0x3D / 255)
    private static let panel = Color(red: 0x2E / 255, green: 0x2A / 255, blue: 0x55 / 255)
    private static let line = Color(red: 0x4A / 255, green: 0x45 / 255, blue: 0x85 / 255)
    private static let outline = Color(red: 0x2B / 255, green: 0x21 / 255, blue: 0x40 / 255)
    private static let star = Color(red: 0xFF / 255, green: 0xD9 / 255, blue: 0x3D / 255)
    private static let green = Color(red: 0x5F / 255, green: 0xE0 / 255, blue: 0x8A / 255)
    private static let cyan = Color(red: 0x3D / 255, green: 0xE3 / 255, blue: 0xD0 / 255)

    var body: some View {
        let totals = model.seasonTotals
        ZStack {
            Self.dim.opacity(0.92).ignoresSafeArea()
            if !reduceMotion { ConfettiView().allowsHitTesting(false) }
            VStack(spacing: 18) {
                HStack(spacing: 28) {
                    AtlasImage("hero_idle_01", atlas: "hero")
                        .frame(width: 120, height: 120)
                        .offset(y: hop ? -12 : 0)
                    AtlasImage("pixel_idle_01", atlas: "pixel")
                        .frame(width: 72, height: 72)
                        .background(Circle().fill(Self.cyan.opacity(0.35)).blur(radius: 10))
                        .offset(y: hop ? 4 : -4)
                }
                .padding(.top, 36)
                Text("seasonComplete.subtitle")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                if let level = model.data.levels[result.levelId] {
                    StoryLinesView(keys: level.effectiveStory.outro)
                        .frame(maxWidth: 560)
                        .accessibilityIdentifier("seasonComplete.outro")
                }
                HStack(spacing: 16) {
                    chip(icon: "ui_icon_star", atlas: "ui",
                         text: String(format: String(localized: "seasonComplete.score"), totals.score))
                    chip(icon: "pickup_datachip", atlas: "items",
                         text: String(format: String(localized: "seasonComplete.datachips"), totals.datachips, totals.datachipsTotal))
                    chip(system: "clock.fill",
                         text: String(format: String(localized: "seasonComplete.time"), result.timeSec / 60, result.timeSec % 60))
                }
                Text("seasonComplete.thanks")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(Self.star)
                Button {
                    AudioManager.shared.play(.uiTap)
                    model.returnToTitle()
                } label: {
                    Text("seasonComplete.toTitle")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 220, height: 72)
                        .background(Capsule().fill(Self.green))
                        .overlay(Capsule().stroke(Self.outline, lineWidth: 3))
                        .contentShape(Capsule())
                }
                .buttonStyle(HUDButtonStyle())
                .opacity(buttonShown ? 1 : 0)
                .disabled(!buttonShown)
                .accessibilityIdentifier("seasonComplete.toTitle")
                .padding(.bottom, 24)
            }
            .frame(width: 760)
            .background(RoundedRectangle(cornerRadius: 28).fill(Self.panel.opacity(0.97)))
            .overlay(RoundedRectangle(cornerRadius: 28).stroke(Self.star, lineWidth: 4))
            .background(RoundedRectangle(cornerRadius: 28).fill(Self.outline).offset(x: 3, y: 3))
            .overlay(alignment: .top) { ribbon.offset(y: -40) }
            .scaleEffect(shown || reduceMotion ? 1 : 0.8)
            .opacity(shown ? 1 : 0)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("seasonComplete.view")
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { shown = true }
            withAnimation(.easeOut(duration: 0.2).delay(0.8)) { buttonShown = true }
            if !reduceMotion {
                withAnimation(.easeInOut(duration: 0.3).delay(0.4).repeatForever(autoreverses: true)) { hop = true }
            }
        }
    }

    private var ribbon: some View {
        HStack(spacing: 14) {
            AtlasImage("ui_icon_star").frame(width: 36, height: 36)
            Text("seasonComplete.title")
                .font(.system(size: 36, weight: .heavy, design: .rounded))
                .foregroundStyle(Self.outline)
            AtlasImage("ui_icon_star").frame(width: 36, height: 36)
        }
        .frame(width: 560, height: 80)
        .background(RoundedRectangle(cornerRadius: 16).fill(Self.star))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Self.outline, lineWidth: 3))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private func chip(icon: String? = nil, atlas: String = "ui", system: String? = nil, text: String) -> some View {
        HStack(spacing: 8) {
            if let icon { AtlasImage(icon, atlas: atlas).frame(width: 28, height: 28) }
            if let system { Image(systemName: system).font(.system(size: 24, weight: .bold)).foregroundStyle(Self.star) }
            Text(verbatim: text)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 12)
        .frame(width: 220, height: 72)
        .background(RoundedRectangle(cornerRadius: 16).fill(Self.dim))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Self.line, lineWidth: 2))
    }
}

/// A few falling ribbons and stars behind the card (§15.14: 8 at a time).
private struct ConfettiView: View {
    private static let colors: [Color] = [
        Color(red: 1, green: 0.85, blue: 0.24), Color(red: 0.24, green: 0.89, blue: 0.82),
        Color(red: 0.84, green: 0.12, blue: 0.56), Color(red: 0.37, green: 0.88, blue: 0.54),
        Color(red: 0.69, green: 0.36, blue: 1),
    ]

    var body: some View {
        TimelineView(.animation) { t in
            Canvas { ctx, size in
                let time = t.date.timeIntervalSinceReferenceDate
                for i in 0..<8 {
                    let speed = 70.0 + Double(i * 13 % 40)
                    let y = (time * speed + Double(i) * 97).truncatingRemainder(dividingBy: Double(size.height + 40)) - 20
                    let x = (Double(i) * 151 + sin(time + Double(i)) * 30).truncatingRemainder(dividingBy: Double(size.width))
                    var c = ctx
                    c.translateBy(x: x, y: y)
                    c.rotate(by: .radians(time * 2 + Double(i)))
                    c.fill(Path(roundedRect: CGRect(x: -6, y: -3, width: 12, height: 6), cornerRadius: 2),
                           with: .color(Self.colors[i % Self.colors.count]))
                }
            }
        }
    }
}
