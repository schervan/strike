import SwiftUI

/// Pixel's speech bubble, HUD top centre (ART_BIBLE §7 / §14.5): white panel, max 420 × 90,
/// `ui_icon_pixel` avatar in a cyan plate overlapping the left edge, 2 lines max. Story beats get
/// a gold outline, hint lines a small arrow badge. Tap dismisses (the next queued line comes up).
struct PixelBubbleView: View {
    @Environment(GameModel.self) private var model

    enum Layout {
        static let maxWidth: CGFloat = 420
        static let minWidth: CGFloat = 200
        static let avatarPlate: CGFloat = 48
        static let avatar: CGFloat = 40
        static let overlap: CGFloat = 16
        static let top: CGFloat = 16
    }

    var body: some View {
        ZStack {
            if let line = model.bubble {
                bubble(line)
                    .id(line.id)
                    .transition(.asymmetric(insertion: .scale(scale: 0.85).combined(with: .opacity).combined(with: .offset(y: -12)),
                                            // QA-020: the old line goes at once, so two lines never overlap.
                                            removal: .identity))
            }
        }
        .animation(.easeOut(duration: 0.18), value: model.bubble?.id)
        .padding(.top, Layout.top)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func bubble(_ line: PixelLine) -> some View {
        let story = line.kind == .story
        let edge = story ? HUDColors.star : HUDColors.outline
        return Button {
            model.send(.dismissBubble)
        } label: {
            HStack(spacing: 8) {
                Text(verbatim: line.text)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(HUDColors.outline)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if line.kind == .hint {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(width: 16, height: 16)
                        .background(Circle().fill(HUDColors.heal))
                }
            }
            .padding(.leading, Layout.avatarPlate - Layout.overlap + 10)
            .padding(.trailing, 14)
            .padding(.vertical, 10)
            .frame(minWidth: Layout.minWidth, maxWidth: Layout.maxWidth, minHeight: 64, maxHeight: 90)
            .fixedSize(horizontal: false, vertical: true)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.white.opacity(0.95))
                    .shadow(color: HUDColors.outline.opacity(0.25), radius: 0, x: 3, y: 3))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(edge, lineWidth: 3))
            .overlay(alignment: .leading) {
                ZStack {
                    Circle().fill(story ? HUDColors.star : HUDColors.cyan)
                    Circle().stroke(HUDColors.outline, lineWidth: 2)
                    AtlasImage("ui_icon_pixel")
                        .frame(width: Layout.avatar, height: Layout.avatar)
                }
                .frame(width: Layout.avatarPlate, height: Layout.avatarPlate)
                .offset(x: -Layout.overlap)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: Layout.maxWidth + Layout.overlap)
        .accessibilityIdentifier("pixel.bubble")
        .accessibilityLabel(Text(String(format: String(localized: "hud.pixelBubble.accessibility"), line.text)))
        .accessibilityValue(Text(verbatim: line.key))
    }
}
