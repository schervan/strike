#if DEBUG
import SwiftUI

/// Debug-only QA overlay (DECISIONS): level id + seed, "turn all on", "go to exit", "reveal map".
/// Compiled out of release builds; texts are developer-only and not localized on purpose.
struct DebugOverlay: View {
    @Environment(GameModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let run = model.run {
                Text(verbatim: "\(run.levelId) · seed \(run.seed)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .accessibilityIdentifier("debug.seed")
            }
            HStack(spacing: 6) {
                button("ALL ON", "debug.solveAll", .debugSolveAll)
                button("EXIT", "debug.gotoExit", .debugGotoExit)
                button("MAP", "debug.revealMap", .debugRevealMap)
                button("CROWD", "debug.spawnCrowd", .debugSpawnCrowd)
                button("DMG", "debug.damageHero", .debugDamageHero)
            }
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 8).fill(.black.opacity(0.35)))
    }

    private func button(_ title: String, _ id: String, _ command: GameCommand) -> some View {
        Button { model.send(command) } label: {
            Text(verbatim: title)
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .frame(minWidth: 64, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .tint(.gray)
        .accessibilityIdentifier(id)
    }
}
#endif
