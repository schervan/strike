import SwiftUI

/// Level intro card over the frozen level (TASKS M3-6): level number, name and subtitle, then
/// the `story.intro` lines with Pixel's avatar. Tap anywhere to start.
struct LevelIntroView: View {
    @Environment(GameModel.self) private var model
    let level: LevelDef

    var body: some View {
        ZStack {
            HUDColors.dim.opacity(0.82).ignoresSafeArea()
            VStack(spacing: 18) {
                Text(String(format: String(localized: "levelIntro.level"), level.index))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(HUDColors.cyanLight)
                Text(LocalizedStringKey(level.nameKey))
                    .font(.system(size: 56, weight: .heavy, design: .rounded))
                    .foregroundStyle(HUDColors.star)
                    .shadow(color: HUDColors.outline, radius: 0, x: 3, y: 3)
                Text(LocalizedStringKey(level.subtitleKey))
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                StoryLinesView(keys: level.effectiveStory.intro)
                    .padding(.top, 8)
                Text("levelIntro.tapToStart")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 32)
                    .frame(minHeight: 64)
                    .background(Capsule().fill(HUDColors.blue))
                    .overlay(Capsule().stroke(HUDColors.outline, lineWidth: 2))
                    .padding(.top, 8)
            }
            .padding(40)
            .frame(maxWidth: 760)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            AudioManager.shared.play(.uiTap)
            model.dismissIntro()
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("levelIntro.view")
    }
}

/// Story lines (`story.*` keys) with Pixel's avatar, on a panel.
struct StoryLinesView: View {
    let keys: [String]

    var body: some View {
        if !keys.isEmpty {
            HStack(alignment: .top, spacing: 16) {
                ZStack {
                    Circle().fill(HUDColors.star)
                    Circle().stroke(HUDColors.outline, lineWidth: 2)
                    AtlasImage("ui_icon_pixel").frame(width: 48, height: 48)
                }
                .frame(width: 60, height: 60)
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
                        Text(LocalizedStringKey(key))
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .foregroundStyle(HUDColors.outline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(20)
            .background(RoundedRectangle(cornerRadius: 20).fill(.white.opacity(0.95)))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(HUDColors.star, lineWidth: 3))
        }
    }
}
