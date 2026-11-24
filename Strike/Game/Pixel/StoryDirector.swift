import CoreGraphics
import Foundation

/// Things that happen in a level that Pixel may comment on (GDD §13 "Generic triggers").
nonisolated enum StoryEvent: Sendable, Hashable {
    case levelStart
    /// An enemy type came into view (on screen with line of sight), see `StoryDirector.isSighted`.
    case enemySeen(String)
    /// The hero picked something up; `stored` = it went into the bag (PickupResolver `stored`).
    case pickup(itemId: String, stored: Bool)
    /// A puzzle element type came into view.
    case elementSeen(ElementType)
    case gateSeen
    /// HP at or below `lowHp.threshold`.
    case lowHp
    case zoneEntered(Int)
    /// A required element turned on and it was not the last one.
    case elementOn
    /// The last required element turned on.
    case allElementsOn
    case gateOpen
    case doorOpen
    /// A pickup stayed on the floor (`staysBagFull`).
    case bagFull
    /// The magazine ran empty (the tip plays the first time per level).
    case magazineEmpty
    case checkpoint
    /// After the rescue beam.
    case rescue
    /// The SWAP button became visible (2 or more blasters owned; QA-012). The scene sends it in M4-5.
    case swapVisible
    /// Boss phase `n` (1-based) began; `bossDefeated` after its power-down.
    case bossPhase(Int)
    case bossDefeated
}

/// A line to say: localization key plus its filter class.
nonisolated struct StoryCue: Sendable, Equatable {
    let key: String
    let kind: LineKind
}

nonisolated struct StoryResponse: Sendable, Equatable {
    var cues: [StoryCue] = []
    /// First sight of this enemy type: play the scan beam.
    var scanEnemyId: String?

    static let silent = StoryResponse()
}

/// Maps level events to the level's `story.beats` (each beat once per level) plus the GDD §13
/// generic lines and `pixel.tip.<enemyId>` on first sight. When a level beat answers an event, it
/// plays **instead of** the generic line. "First" triggers are once per level (one director per
/// level play). Boss triggers are ignored until M4. Hint lines come from `HintPlanner`.
nonisolated struct StoryDirector: Sendable, Equatable {
    let beats: [StoryBeatDef]
    private(set) var firedBeats: Set<Int> = []
    /// Triggers that happened at least once (`firstEnemy:boltbot`, `start`, `firstItem`, …).
    private(set) var seenTriggers: Set<String> = []

    init(story: StoryDef) {
        beats = story.beats
    }

    enum Key {
        static let start = "pixel.generic.start"
        static let firstItem = "pixel.generic.first_item"
        static let bagFull = "pixel.generic.bag_full"
        static let lowHp = "pixel.generic.low_hp"
        static let reload = "pixel.generic.reload"
        static let elementOn = "pixel.generic.element_on"
        static let allOn = "pixel.generic.all_on"
        static let gateOpen = "pixel.generic.gate_open"
        static let doorOpen = "pixel.generic.door_open"
        static let checkpoint = "pixel.generic.checkpoint"
        static let rescue = "pixel.generic.rescue"
        /// `firstSwapVisible` when the level has no beat for it (QA-012).
        static let swap = "pixel.generic.swap"
        /// First spore slow of the level (ART_BIBLE §15.4).
        static let slow = "pixel.generic.slow"
        /// First shot on the boss's bubble shield (§15.9).
        static let bossShield = "pixel.boss.shield"
        /// A core machine used without a core (§15.10).
        static let coreNeeded = "pixel.boss.core_needed"
        static let idle = "pixel.generic.idle"
        static let hintHere = "pixel.generic.hint_here"
        static let hintItem = "pixel.generic.hint_item"
        static let hintMachine = "pixel.generic.hint_machine"
        static let hintExit = "pixel.generic.hint_exit"
        static let hintWait = "pixel.generic.hint_wait"
        static func need(_ itemId: String) -> String { "pixel.generic.need_\(itemId)" }
        static func tip(_ enemyId: String) -> String { "pixel.tip.\(enemyId)" }
    }

    /// Per-key overrides of the repeat guard for `SpeechQueue` (GDD §4: low HP once per
    /// `lowHp.lineCooldownSec`).
    static func keyCooldowns(_ rules: RulesDef) -> [String: Double] {
        [Key.lowHp: rules.lowHp.lineCooldownSec]
    }

    /// Beat trigger of an event (`levels.json → story.beats[].trigger`), nil for events without one.
    static func trigger(for event: StoryEvent) -> String? {
        switch event {
        case .levelStart: "start"
        case .enemySeen(let id): "firstEnemy:\(id)"
        case .pickup(let id, _): "firstPickup:\(id)"
        case .elementSeen(let t): "firstSeen:\(t.rawValue)"
        case .gateSeen: "firstSeen:gate"
        case .lowHp: "firstLowHp"
        case .zoneEntered(let n): "zone:\(n)"
        case .allElementsOn: "allElementsOn"
        case .doorOpen: "doorOpen"
        case .swapVisible: "firstSwapVisible"
        case .bossPhase(let n): "bossPhase:\(n)"
        case .bossDefeated: "bossDefeated"
        case .elementOn, .gateOpen, .bagFull, .magazineEmpty, .checkpoint, .rescue: nil
        }
    }

    mutating func handle(_ event: StoryEvent) -> StoryResponse {
        var r = StoryResponse()
        var isFirst = false
        if let t = Self.trigger(for: event) {
            isFirst = seenTriggers.insert(t).inserted
            for (i, b) in beats.enumerated() where b.trigger == t && !firedBeats.contains(i) {
                firedBeats.insert(i)
                r.cues.append(StoryCue(key: b.key, kind: .story))
            }
        }
        if case .enemySeen(let id) = event {
            if isFirst {
                r.scanEnemyId = id
                r.cues.append(StoryCue(key: Key.tip(id), kind: .chatter))
            }
            return r
        }
        // The swap line plays only the first time SWAP appears (beat or generic, never both).
        if case .swapVisible = event, !isFirst { return r }
        guard r.cues.isEmpty, let g = generic(event) else { return r }
        r.cues.append(g)
        return r
    }

    private mutating func generic(_ event: StoryEvent) -> StoryCue? {
        func once(_ trigger: String, _ key: String) -> StoryCue? {
            seenTriggers.insert(trigger).inserted ? StoryCue(key: key, kind: .chatter) : nil
        }
        switch event {
        case .levelStart: return StoryCue(key: Key.start, kind: .chatter)
        case .pickup(_, let stored): return stored ? once("firstItem", Key.firstItem) : nil
        case .lowHp: return StoryCue(key: Key.lowHp, kind: .chatter)
        case .elementOn: return StoryCue(key: Key.elementOn, kind: .chatter)
        case .allElementsOn: return StoryCue(key: Key.allOn, kind: .chatter)
        case .gateOpen: return StoryCue(key: Key.gateOpen, kind: .chatter)
        case .doorOpen: return StoryCue(key: Key.doorOpen, kind: .chatter)
        case .bagFull: return StoryCue(key: Key.bagFull, kind: .chatter)
        case .magazineEmpty: return once("firstReload", Key.reload)
        case .checkpoint: return StoryCue(key: Key.checkpoint, kind: .chatter)
        case .rescue: return StoryCue(key: Key.rescue, kind: .story)
        case .swapVisible: return StoryCue(key: Key.swap, kind: .chatter)
        case .enemySeen, .elementSeen, .gateSeen, .zoneEntered, .bossPhase, .bossDefeated: return nil
        }
    }

    /// "First sight" (not first contact): the enemy is inside the camera's visible rect and the
    /// hero has line of sight to it on the current solid grid.
    static func isSighted(_ target: CGPoint, from hero: CGPoint, visibleRect: CGRect, grid: TileGrid) -> Bool {
        visibleRect.contains(target) && grid.hasLineOfSight(from: hero, to: target)
    }
}
