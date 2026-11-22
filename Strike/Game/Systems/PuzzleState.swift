import Foundation

nonisolated enum ActivationResult: Sendable, Equatable {
    /// Button or machine latched on (machine consumed its item); plate latched.
    case activated
    /// Lever flipped (on ↔ off); the pull lock runs for `leverPullSec`.
    case toggled
    /// Machine without its item in the carrier: nothing consumed.
    case needsItem(String)
    /// Latching element that is already on.
    case alreadyOn
    /// Not usable right now (lever mid-pull, plates via INTERACT, unknown id).
    case notReady
}

/// On/off state of every puzzle element and door of a level (GDD §11). Pure value type.
/// Doors latch: once a gate or the exit opened it stays open, even if a lever is flipped back
/// (no kid is ever locked out behind a gate).
nonisolated struct PuzzleState: Sendable, Equatable {
    struct Element: Sendable, Equatable {
        let id: String
        let type: ElementType
        let required: Bool
        let requiresItem: String?
        let gateId: String?
        var isOn = false
        /// Plates: continuous standing time so far.
        var holdTime: Double = 0
        /// Levers: remaining pull lock.
        var pullRemaining: Double = 0
    }

    let rules: PuzzleRulesDef
    private(set) var elements: [String: Element]
    /// Gate id → element ids.
    let gateElements: [String: [String]]
    let exitElements: [String]
    private(set) var openGates: Set<String> = []
    private(set) var isExitOpen = false

    init(elements: [Element], gates: [String: [String]], exitElements: [String], rules: PuzzleRulesDef) {
        self.rules = rules
        self.elements = Dictionary(elements.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        self.gateElements = gates
        self.exitElements = exitElements
        refreshDoors()
    }

    init(level: GeneratedLevel, rules: PuzzleRulesDef) {
        self.init(
            elements: level.elements.map {
                Element(id: $0.id, type: $0.type, required: $0.required, requiresItem: $0.requiresItem, gateId: $0.gateId)
            },
            gates: Dictionary(level.gates.map { ($0.id, $0.elementIds) }, uniquingKeysWith: { a, _ in a }),
            exitElements: level.exitDoor.elementIds,
            rules: rules)
    }

    func isOn(_ id: String) -> Bool { elements[id]?.isOn ?? false }
    func isGateOpen(_ gateId: String) -> Bool { openGates.contains(gateId) }

    /// Required elements that are on / all required elements (door counter "3 / 5").
    var requiredProgress: (on: Int, total: Int) {
        let req = exitElements.compactMap { elements[$0] }
        return (req.filter(\.isOn).count, req.count)
    }

    /// Elements of a gate that are on / total.
    func gateProgress(_ gateId: String) -> (on: Int, total: Int) {
        let ids = gateElements[gateId] ?? []
        return (ids.filter(isOn).count, ids.count)
    }

    /// Plate fill 0…1 (ring), 1 once latched.
    func plateProgress(_ id: String) -> Double {
        guard let e = elements[id], e.type == .pressureplate else { return 0 }
        if e.isOn { return 1 }
        return rules.plateHoldSec > 0 ? min(1, e.holdTime / rules.plateHoldSec) : 0
    }

    /// INTERACT on an element. Machines take their item from `carrier`.
    mutating func interact<C: ItemCarrier>(_ id: String, carrier: inout C) -> ActivationResult {
        guard var e = elements[id] else { return .notReady }
        let result: ActivationResult
        switch e.type {
        case .button:
            if e.isOn { return .alreadyOn }
            e.isOn = true
            result = .activated
        case .lever:
            if e.pullRemaining > 0 { return .notReady }
            e.isOn.toggle()
            e.pullRemaining = rules.leverPullSec
            result = .toggled
        case .machine:
            if e.isOn { return .alreadyOn }
            if let item = e.requiresItem {
                guard carrier.count(of: item) > 0, carrier.remove(item, count: 1) else { return .needsItem(item) }
            }
            e.isOn = true
            result = .activated
        case .pressureplate:
            return e.isOn ? .alreadyOn : .notReady
        }
        elements[id] = e
        refreshDoors()
        return result
    }

    /// Plate update for one frame. Returns `.activated` on the frame it latches, else nil.
    /// Stepping off resets the timer (continuous standing, GDD §11).
    mutating func updatePlate(_ id: String, occupied: Bool, dt: Double) -> ActivationResult? {
        guard var e = elements[id], e.type == .pressureplate, !e.isOn else { return nil }
        if occupied {
            e.holdTime += max(0, dt)
            if e.holdTime + 1e-9 >= rules.plateHoldSec {
                e.isOn = true
                e.holdTime = rules.plateHoldSec
                elements[id] = e
                refreshDoors()
                return .activated
            }
        } else {
            e.holdTime = 0
        }
        elements[id] = e
        return nil
    }

    /// Advances lever pull locks.
    mutating func tick(dt: Double) {
        for (id, e) in elements where e.pullRemaining > 0 {
            elements[id]?.pullRemaining = max(0, e.pullRemaining - dt)
        }
    }

    /// Debug "turn all on" (DebugOverlay).
    mutating func forceAllOn() {
        for id in elements.keys { elements[id]?.isOn = true }
        refreshDoors()
    }

    private mutating func refreshDoors() {
        for (gate, ids) in gateElements where !openGates.contains(gate) {
            if ids.allSatisfy({ elements[$0]?.isOn == true }) { openGates.insert(gate) }
        }
        if !isExitOpen, exitElements.allSatisfy({ elements[$0]?.isOn == true }) { isExitOpen = true }
    }
}
