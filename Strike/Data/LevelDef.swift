import Foundation

/// `{ "min": a, "max": b }` (inclusive).
nonisolated struct IntRange: Codable, Sendable, Equatable, Hashable {
    let min: Int
    let max: Int

    func contains(_ v: Int) -> Bool { v >= min && v <= max }
}

/// Generator numbers of one level (`levels.json → generator`, GDD §14.2).
nonisolated struct GeneratorParams: Codable, Sendable, Equatable {
    let gridWidth: Int
    let gridHeight: Int
    let roomCount: IntRange
    let minRoomSize: Int
    let maxRoomSize: Int
    let bspMaxDepth: Int
    let corridorWidth: Int
    let loopChance: Double
    let zones: Int
    let enemyDensity: Double
    let maxThreatPerRoom: Int
    let minElementSpacing: Int
    /// Decor props are Later (DECISIONS); decoded so the field is documented, unused in M2.
    let decorDensity: Double?
    let maxAttempts: Int
}

/// One `enemyMix` entry (GDD §16.5).
nonisolated struct EnemyMixEntry: Codable, Sendable, Equatable {
    let enemyId: String
    let weight: Double
    /// Earliest zone (1-based) the enemy may appear in.
    let zoneMin: Int?
    /// Only in rooms past this fraction (0…1) of the critical path.
    let minPathFraction: Double?
    /// Cap per room.
    let maxPerRoom: Int?
}

/// `zone` of a puzzle element: a 1-based zone or `"any"`.
nonisolated enum ZoneSpec: Codable, Sendable, Equatable, Hashable {
    case index(Int)
    case any

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let i = try? c.decode(Int.self) {
            self = .index(i)
        } else if let s = try? c.decode(String.self), s == "any" {
            self = .any
        } else {
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "zone must be an Int or \"any\"")
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .index(let i): try c.encode(i)
        case .any: try c.encode("any")
        }
    }

    func allows(_ zone: Int) -> Bool {
        switch self {
        case .any: true
        case .index(let i): i == zone
        }
    }
}

/// Puzzle element kinds (GDD §11). Doors are not elements.
nonisolated enum ElementType: String, Codable, Sendable, CaseIterable {
    case button, lever, pressureplate, machine

    /// Side length in tiles (ART_BIBLE §4: the machine is 2 × 2).
    var footprint: Int { self == .machine ? 2 : 1 }
}

/// Where a machine's item goes (GDD §14.1 step 5).
nonisolated enum ItemPlacementRule: String, Codable, Sendable {
    case sameZone, earlierZone
}

/// One `puzzle.elements` entry.
nonisolated struct PuzzleElementDef: Codable, Sendable, Equatable {
    let type: ElementType
    let count: Int
    let required: Bool
    let zone: ZoneSpec
    let requiresItem: String?
    let itemPlacement: ItemPlacementRule?
}

/// One `opensWith` entry of a gate.
nonisolated struct GateElementDef: Codable, Sendable, Equatable {
    let type: ElementType
    let count: Int
    let requiresItem: String?
    let itemPlacement: ItemPlacementRule?
}

/// Gate door before `zone`; its elements are placed in `zone − 1`.
nonisolated struct GateDef: Codable, Sendable, Equatable {
    let zone: Int
    let opensWith: [GateElementDef]
}

nonisolated struct PuzzleDef: Codable, Sendable, Equatable {
    let itemPlacement: ItemPlacementRule
    let gates: [GateDef]
    let elements: [PuzzleElementDef]
}

nonisolated struct PerRoomPickupDef: Codable, Sendable, Equatable {
    let itemId: String
    let chance: Double
}

nonisolated struct CratesDef: Codable, Sendable, Equatable {
    let min: Int
    let max: Int
    let lootTableId: String
}

nonisolated struct ItemCountDef: Codable, Sendable, Equatable {
    let itemId: String
    let count: Int
}

/// `pickups` block. `fixed` (boss arena) is M4 and not decoded.
nonisolated struct PickupsDef: Codable, Sendable, Equatable {
    let perRoom: [PerRoomPickupDef]
    let crates: CratesDef
    let datachips: Int
    let weaponPickup: String?
    let startGift: [ItemCountDef]?
}

/// One `story.beats` entry: Pixel says `key` the first time `trigger` happens in the level.
nonisolated struct StoryBeatDef: Codable, Sendable, Equatable {
    let trigger: String
    let key: String
}

/// `story` block (GDD §16.5): `intro`/`outro` lines for the level cards, `beats` during play.
nonisolated struct StoryDef: Codable, Sendable, Equatable {
    let intro: [String]
    let outro: [String]
    let beats: [StoryBeatDef]

    static let empty = StoryDef(intro: [], outro: [], beats: [])
}

/// One level from `levels.json` (GDD §16.5). `bossArena` is M4 and not decoded.
nonisolated struct LevelDef: Codable, Sendable, Equatable, Identifiable {
    let id: String
    let index: Int
    let nameKey: String
    let subtitleKey: String
    let theme: String
    let music: String
    let bossMusic: String?
    let parTimeSec: Int
    let starRescueMax: Int
    let fallbackSeed: UInt64
    let hintIdleSec: Int?
    let generator: GeneratorParams
    let enemyMix: [EnemyMixEntry]
    let firstEncounterRoom: String?
    let puzzle: PuzzleDef
    let pickups: PickupsDef
    let bossId: String?
    let story: StoryDef?

    /// GDD §16.5 default for `hintIdleSec`.
    static let defaultHintIdleSec = 30
    var effectiveHintIdleSec: Int { hintIdleSec ?? Self.defaultHintIdleSec }
    var effectiveStory: StoryDef { story ?? .empty }

    /// Tile-texture prefix of this level's theme (`tile_l3_floor_01`, ART_BIBLE §4).
    var tilePrefix: String { "l\(index)" }
}

nonisolated struct LevelsFile: Codable, Sendable {
    let version: Int
    let levels: [LevelDef]
}
