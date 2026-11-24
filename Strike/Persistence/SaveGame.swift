import Foundation

/// `save.json` (DECISIONS: one save, run state only, no mid-level state). Bump `currentVersion`
/// for incompatible changes; an unknown version is moved aside by `SaveStore`.
nonisolated struct SaveGame: Codable, Sendable, Equatable {
    static let currentVersion = 1

    var version: Int
    var run: RunState
    var savedAt: Date

    init(run: RunState, savedAt: Date = Date(), version: Int = SaveGame.currentVersion) {
        self.version = version
        self.run = run
        self.savedAt = savedAt
    }
}
