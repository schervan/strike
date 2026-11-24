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
    /// M3 (GDD §16.9): plate hold ring fade-in.
    let plateRingFadeSec: Double?
    /// M3: door frame start offset per cell, outer cell first.
    let doorStaggerSec: Double?
    /// M3: time per door opening frame.
    let doorFrameSec: Double?

    init(leverPullSec: Double, plateHoldSec: Double, doorPanSec: Double, doorMaxLights: Int,
         interactFocusRadius: Double?, plateRingFadeSec: Double? = nil, doorStaggerSec: Double? = nil,
         doorFrameSec: Double? = nil) {
        self.leverPullSec = leverPullSec
        self.plateHoldSec = plateHoldSec
        self.doorPanSec = doorPanSec
        self.doorMaxLights = doorMaxLights
        self.interactFocusRadius = interactFocusRadius
        self.plateRingFadeSec = plateRingFadeSec
        self.doorStaggerSec = doorStaggerSec
        self.doorFrameSec = doorFrameSec
    }

    /// Missing M3 fields filled from `other` (the fallback).
    func filling(from other: PuzzleRulesDef) -> PuzzleRulesDef {
        PuzzleRulesDef(leverPullSec: leverPullSec, plateHoldSec: plateHoldSec, doorPanSec: doorPanSec,
                       doorMaxLights: doorMaxLights, interactFocusRadius: interactFocusRadius,
                       plateRingFadeSec: plateRingFadeSec ?? other.plateRingFadeSec,
                       doorStaggerSec: doorStaggerSec ?? other.doorStaggerSec,
                       doorFrameSec: doorFrameSec ?? other.doorFrameSec)
    }
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
    /// M3: corridor cells within this Chebyshev distance of the hero's cell are revealed.
    let corridorRevealRadius: Int?
    /// M3: hero dot pulse period.
    let heroPulseSec: Double?
    /// M3: exit star alpha pulse period.
    let exitPulseSec: Double?

    init(revealOnEnter: Bool, updateHz: Double, corridorRevealRadius: Int? = nil, heroPulseSec: Double? = nil,
         exitPulseSec: Double? = nil) {
        self.revealOnEnter = revealOnEnter
        self.updateHz = updateHz
        self.corridorRevealRadius = corridorRevealRadius
        self.heroPulseSec = heroPulseSec
        self.exitPulseSec = exitPulseSec
    }

    /// Missing M3 fields filled from `other` (the fallback).
    func filling(from other: MinimapRulesDef) -> MinimapRulesDef {
        MinimapRulesDef(revealOnEnter: revealOnEnter, updateHz: updateHz,
                        corridorRevealRadius: corridorRevealRadius ?? other.corridorRevealRadius,
                        heroPulseSec: heroPulseSec ?? other.heroPulseSec,
                        exitPulseSec: exitPulseSec ?? other.exitPulseSec)
    }
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

/// `rules.json → inventory` (GDD §7).
nonisolated struct InventoryRulesDef: Codable, Sendable, Equatable {
    let slots: Int
    let quickSlots: Int
    /// Per item id: a second use inside this time is refused (GDD §6).
    let useCooldownSec: Double
    /// Max distance (pt) a dropped item lands from the hero's feet.
    let dropScatter: Double
}

/// `rules.json → rescue` (GDD §12). The invulnerability time is `hero.respawnInvulnerableSec`.
nonisolated struct RescueRulesDef: Codable, Sendable, Equatable {
    let slowMoScale: Double
    let slowMoSec: Double
    let beamSec: Double
    /// Starter blaster mag + reserve after a rescue is at least this.
    let starterMinMagazine: Int
}

/// 2D offset in points.
nonisolated struct OffsetDef: Codable, Sendable, Equatable {
    let x: Double
    let y: Double
}

/// `rules.json → pixel` (GDD §13).
nonisolated struct PixelRulesDef: Codable, Sendable, Equatable {
    /// Follow position relative to the hero (behind-left).
    let followOffset: OffsetDef
    let bobAmplitude: Double
    let bobHz: Double
    let followLerpSec: Double
    /// Pt on screen around Pixel's centre that counts as a tap on Pixel.
    let tapRadius: Double
    /// A Pixel tap must end within this time …
    let tapMaxSec: Double
    /// … and move less than this (pt).
    let tapMaxMovePt: Double
    let bubbleBaseSec: Double
    let bubblePerCharSec: Double
    let maxChars: Int
    /// Lines waiting behind the one on screen; older ones are dropped.
    let queueMax: Int
    /// The same `pixel.*` key is not queued again inside this time (story lines exempt).
    let repeatCooldownSec: Double
}

/// `rules.json → hints` (GDD §13).
nonisolated struct HintRulesDef: Codable, Sendable, Equatable {
    let flySec: Double
    let arrowSec: Double
    let cooldownSec: Double
    /// Minimap pings start after this much level time.
    let pointerAfterSec: Double
}

/// `rules.json → lowHp` (GDD §4).
nonisolated struct LowHpRulesDef: Codable, Sendable, Equatable {
    /// HP at or below this is "low".
    let threshold: Int
    let lineCooldownSec: Double
}

/// `rules.json → weapons` (GDD §5.1): swap time (no fire while swapping) and the weapon-wheel
/// long press.
nonisolated struct WeaponRulesDef: Codable, Sendable, Equatable {
    let swapSec: Double
    let wheelLongPressSec: Double
    /// Game speed while the weapon wheel is open (M4-5).
    let wheelTimeScale: Double?
}

nonisolated struct RulesFile: Codable, Sendable {
    let version: Int
    let puzzle: PuzzleRulesDef
    let leash: LeashRulesDef
    let minimap: MinimapRulesDef
    let toast: ToastRulesDef?
    let crate: CrateRulesDef?
    let inventory: InventoryRulesDef?
    let rescue: RescueRulesDef?
    let pixel: PixelRulesDef?
    let hints: HintRulesDef?
    let lowHp: LowHpRulesDef?
    let weapons: WeaponRulesDef?
}

/// Global gameplay rules from `rules.json`. Optional blocks missing from the file use
/// `RulesDef.fallback`.
nonisolated struct RulesDef: Sendable, Equatable {
    let puzzle: PuzzleRulesDef
    let leash: LeashRulesDef
    let minimap: MinimapRulesDef
    let toast: ToastRulesDef
    let crate: CrateRulesDef
    let inventory: InventoryRulesDef
    let rescue: RescueRulesDef
    let pixel: PixelRulesDef
    let hints: HintRulesDef
    let lowHp: LowHpRulesDef
    let weapons: WeaponRulesDef

    init(puzzle: PuzzleRulesDef, leash: LeashRulesDef, minimap: MinimapRulesDef, toast: ToastRulesDef? = nil,
         crate: CrateRulesDef? = nil, inventory: InventoryRulesDef? = nil, rescue: RescueRulesDef? = nil,
         pixel: PixelRulesDef? = nil, hints: HintRulesDef? = nil, lowHp: LowHpRulesDef? = nil,
         weapons: WeaponRulesDef? = nil) {
        let f = Self.fallback
        self.init(fallbackPuzzle: puzzle.filling(from: f.puzzle), leash: leash,
                  minimap: minimap.filling(from: f.minimap),
                  toast: toast ?? f.toast, crate: crate ?? f.crate, inventory: inventory ?? f.inventory,
                  rescue: rescue ?? f.rescue, pixel: pixel ?? f.pixel, hints: hints ?? f.hints, lowHp: lowHp ?? f.lowHp,
                  weapons: weapons ?? f.weapons)
    }

    init(file: RulesFile) {
        self.init(puzzle: file.puzzle, leash: file.leash, minimap: file.minimap, toast: file.toast, crate: file.crate,
                  inventory: file.inventory, rescue: file.rescue, pixel: file.pixel, hints: file.hints,
                  lowHp: file.lowHp, weapons: file.weapons)
    }

    private init(fallbackPuzzle: PuzzleRulesDef, leash: LeashRulesDef, minimap: MinimapRulesDef, toast: ToastRulesDef,
                 crate: CrateRulesDef, inventory: InventoryRulesDef, rescue: RescueRulesDef, pixel: PixelRulesDef,
                 hints: HintRulesDef, lowHp: LowHpRulesDef, weapons: WeaponRulesDef) {
        self.puzzle = fallbackPuzzle
        self.leash = leash
        self.minimap = minimap
        self.toast = toast
        self.crate = crate
        self.inventory = inventory
        self.rescue = rescue
        self.pixel = pixel
        self.hints = hints
        self.lowHp = lowHp
        self.weapons = weapons
    }

    /// GDD defaults (§4 low HP, §5.1 swap, §7 inventory, §8 leash, §11 puzzle timings, §12 rescue, §13 Pixel),
    /// used only while `rules.json` (or one of its blocks) is missing. This is the single place
    /// these numbers exist in code.
    static let fallback = RulesDef(
        fallbackPuzzle: PuzzleRulesDef(leverPullSec: 0.4, plateHoldSec: 1.0, doorPanSec: 1.0,
                                       doorMaxLights: 8, interactFocusRadius: nil, plateRingFadeSec: 0.1,
                                       doorStaggerSec: 0.04, doorFrameSec: 0.07),
        leash: LeashRulesDef(rangeFactor: 2.0, returnAfterSec: 4.0),
        minimap: MinimapRulesDef(revealOnEnter: true, updateHz: 10, corridorRevealRadius: 3, heroPulseSec: 1.0,
                                 exitPulseSec: 1.2),
        toast: ToastRulesDef(showSec: 2.5, repeatCooldownSec: 3.0),
        crate: CrateRulesDef(hp: 20),
        inventory: InventoryRulesDef(slots: 25, quickSlots: 4, useCooldownSec: 0.5, dropScatter: 24),
        rescue: RescueRulesDef(slowMoScale: 0.3, slowMoSec: 0.6, beamSec: 0.8, starterMinMagazine: 12),
        pixel: PixelRulesDef(followOffset: OffsetDef(x: -40, y: 40), bobAmplitude: 4, bobHz: 1.5, followLerpSec: 0.15,
                             tapRadius: 80, tapMaxSec: 0.25, tapMaxMovePt: 12, bubbleBaseSec: 3.0,
                             bubblePerCharSec: 0.04, maxChars: 60, queueMax: 2, repeatCooldownSec: 10),
        hints: HintRulesDef(flySec: 2, arrowSec: 6, cooldownSec: 10, pointerAfterSec: 60),
        lowHp: LowHpRulesDef(threshold: 25, lineCooldownSec: 60),
        weapons: WeaponRulesDef(swapSec: 0.25, wheelLongPressSec: 0.4, wheelTimeScale: 0.3))
}
