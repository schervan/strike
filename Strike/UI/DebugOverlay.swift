#if DEBUG
import SwiftUI

/// Debug-only QA overlay (DECISIONS): level id + seed, "turn all on", "go to exit", "reveal map",
/// M4: give blasters, boss arena, next boss phase, spawn one enemy of each type.
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
                Text(verbatim: model.debugStats)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .accessibilityIdentifier("debug.stats")
            }
            HStack(spacing: 6) {
                button("ALL ON", "debug.solveAll", .debugSolveAll)
                button("EXIT", "debug.gotoExit", .debugGotoExit)
                button("MAP", "debug.revealMap", .debugRevealMap)
                button("CROWD", "debug.spawnCrowd", .debugSpawnCrowd)
                button("DMG", "debug.damageHero", .debugDamageHero)
            }
            HStack(spacing: 6) {
                button("BLAST", "debug.giveBlasters", .debugGiveBlasters)
                button("ARENA", "debug.bossArena", .debugBossArena)
                button("PHASE", "debug.bossNextPhase", .debugBossNextPhase)
            }
            HStack(spacing: 6) {
                ForEach(Self.spawnable, id: \.0) { id, title in
                    button(title, "debug.spawn.\(id)", .debugSpawn(id))
                }
            }
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 8).fill(.black.opacity(0.35)))
    }

    private static let spawnable: [(String, String)] = [
        ("boltbot", "BOT"), ("laserdrone", "DRONE"), ("slimemutant", "SLIME"), ("shieldandroid", "SHIELD"), ("sporeplant", "SPORE"),
    ]

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
