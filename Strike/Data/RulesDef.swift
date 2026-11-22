import Foundation

/// `rules.json → puzzle` (GDD §11).
nonisolated struct PuzzleRulesDef: Codable, Sendable, Equatable {
    /// Lever pull animation; the lever cannot be pulled again during it.
    let leverPullSec: Double
    /// Continuous standing time before a pressure plate latches.
    let plateHoldSec: Double
    /// Camera pan to the door when its last element turns on.
    let doorPanSec: Double
    /// Max lights drawn on a door.
    let doorMaxLights: Int
    /// Optional focus search radius for interactables (default: `hero.interactRadius`).
    let interactFocusRadius: Double?
}

/// `rules.json → leash` (GDD §8): an enemy returns home when the hero is farther than
/// `rangeFactor × detectRange` for `returnAfterSec`.
nonisolated struct LeashRulesDef: Codable, Sendable, Equatable {
    let rangeFactor: Double
    let returnAfterSec: Double
}

/// `rules.json → minimap`.
nonisolated struct MinimapRulesDef: Codable, Sendable, Equatable {
    let revealOnEnter: Bool
    let updateHz: Double
}

/// `rules.json → toast` (HUD toast line).
nonisolated struct ToastRulesDef: Codable, Sendable, Equatable {
    let showSec: Double
    let repeatCooldownSec: Double
}

/// `rules.json → crate` (generator-placed supply boxes).
nonisolated struct CrateRulesDef: Codable, Sendable, Equatable {
    let hp: Int
}

nonisolated struct RulesFile: Codable, Sendable {
    let version: Int
    let puzzle: PuzzleRulesDef
    let leash: LeashRulesDef
    let minimap: MinimapRulesDef
    let toast: ToastRulesDef?
    let crate: CrateRulesDef?
}

/// Global gameplay rules from `rules.json`.
nonisolated struct RulesDef: Sendable, Equatable {
    let puzzle: PuzzleRulesDef
    let leash: LeashRulesDef
    let minimap: MinimapRulesDef
    let toast: ToastRulesDef
    let crate: CrateRulesDef

    init(puzzle: PuzzleRulesDef, leash: LeashRulesDef, minimap: MinimapRulesDef, toast: ToastRulesDef? = nil,
         crate: CrateRulesDef? = nil) {
        self.puzzle = puzzle
        self.leash = leash
        self.minimap = minimap
        self.toast = toast ?? Self.fallback.toast
        self.crate = crate ?? Self.fallback.crate
    }

    init(file: RulesFile) {
        self.init(puzzle: file.puzzle, leash: file.leash, minimap: file.minimap, toast: file.toast, crate: file.crate)
    }

    private init(fallbackPuzzle: PuzzleRulesDef, leash: LeashRulesDef, minimap: MinimapRulesDef, toast: ToastRulesDef,
                 crate: CrateRulesDef) {
        self.puzzle = fallbackPuzzle
        self.leash = leash
        self.minimap = minimap
        self.toast = toast
        self.crate = crate
    }

    /// GDD defaults (§8 leash, §11 puzzle timings), used only while `rules.json` is missing
    /// from the bundle. This is the single place these numbers exist in code.
    static let fallback = RulesDef(
        fallbackPuzzle: PuzzleRulesDef(leverPullSec: 0.4, plateHoldSec: 1.0, doorPanSec: 1.0,
                                       doorMaxLights: 8, interactFocusRadius: nil),
        leash: LeashRulesDef(rangeFactor: 2.0, returnAfterSec: 4.0),
        minimap: MinimapRulesDef(revealOnEnter: true, updateHz: 10),
        toast: ToastRulesDef(showSec: 2.5, repeatCooldownSec: 3.0),
        crate: CrateRulesDef(hp: 20))
}
