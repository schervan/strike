import Testing
@testable import Strike

struct PuzzleStateTests {
    static let rules = PuzzleRulesDef(leverPullSec: 0.4, plateHoldSec: 1.0, doorPanSec: 1.0, doorMaxLights: 8,
                                      interactFocusRadius: nil)

    typealias E = PuzzleState.Element

    /// gate_2 opens with button_g; exit needs button_0, lever_0, lever_1, plate_0, machine_0 (fuse).
    static func state() -> PuzzleState {
        PuzzleState(
            elements: [
                E(id: "button_g", type: .button, required: false, requiresItem: nil, gateId: "gate_2"),
                E(id: "button_0", type: .button, required: true, requiresItem: nil, gateId: nil),
                E(id: "lever_0", type: .lever, required: true, requiresItem: nil, gateId: nil),
                E(id: "lever_1", type: .lever, required: true, requiresItem: nil, gateId: nil),
                E(id: "plate_0", type: .pressureplate, required: true, requiresItem: nil, gateId: nil),
                E(id: "machine_0", type: .machine, required: true, requiresItem: "fuse", gateId: nil),
            ],
            gates: ["gate_2": ["button_g"]],
            exitElements: ["button_0", "lever_0", "lever_1", "plate_0", "machine_0"],
            rules: rules)
    }

    /// M3: the `Inventory` is the puzzle's `ItemCarrier` (it replaced the M2 `PuzzleBag`).
    static func bag(fuses: Int = 0) -> Inventory {
        var b = Inventory(items: GeneratedCorpus.data.items, rules: GeneratedCorpus.data.rules.inventory)
        _ = b.add("fuse", count: fuses)
        return b
    }

    @Test func buttonLatches() {
        var s = Self.state()
        var bag = Self.bag()
        do { let v = s.interact("button_0", carrier: &bag); #expect(v == .activated) }
        #expect(s.isOn("button_0"))
        do { let v = s.interact("button_0", carrier: &bag); #expect(v == .alreadyOn) }
        #expect(s.isOn("button_0"))
    }

    @Test func leverTogglesAndExitNeedsEveryLeverOn() {
        var s = Self.state()
        var bag = Self.bag(fuses: 1)
        _ = s.interact("button_0", carrier: &bag)
        _ = s.interact("machine_0", carrier: &bag)
        _ = s.updatePlate("plate_0", occupied: true, dt: 1.0)
        do { let v = s.interact("lever_0", carrier: &bag); #expect(v == .toggled) }
        #expect(s.isOn("lever_0"))
        do { let v = s.interact("lever_0", carrier: &bag); #expect(v == .notReady) }  // still pulling
        s.tick(dt: 0.4)
        do { let v = s.interact("lever_0", carrier: &bag); #expect(v == .toggled) }
        #expect(!s.isOn("lever_0"))
        _ = s.interact("lever_1", carrier: &bag)
        #expect(!s.isExitOpen)                                     // lever_0 is off again
        s.tick(dt: 0.4)
        _ = s.interact("lever_0", carrier: &bag)
        #expect(s.isExitOpen)
        // Doors latch: flipping a lever back does not close the exit.
        s.tick(dt: 0.4)
        _ = s.interact("lever_0", carrier: &bag)
        #expect(s.isExitOpen)
    }

    @Test func plateNeedsContinuousStanding() {
        var s = Self.state()
        do { let v = s.updatePlate("plate_0", occupied: true, dt: 0.6); #expect(v == nil) }
        #expect(abs(s.plateProgress("plate_0") - 0.6) < 1e-9)
        do { let v = s.updatePlate("plate_0", occupied: false, dt: 0.1); #expect(v == nil) }  // stepped off: reset
        #expect(s.plateProgress("plate_0") == 0)
        do { let v = s.updatePlate("plate_0", occupied: true, dt: 0.6); #expect(v == nil) }
        #expect(!s.isOn("plate_0"))
        do { let v = s.updatePlate("plate_0", occupied: true, dt: 0.4); #expect(v == .activated) }
        #expect(s.isOn("plate_0"))
        do { let v = s.updatePlate("plate_0", occupied: false, dt: 1); #expect(v == nil) }  // latched
        #expect(s.isOn("plate_0"))
        var bag = Self.bag()
        do { let v = s.interact("plate_0", carrier: &bag); #expect(v == .alreadyOn) }
    }

    @Test func machineNeedsItsItem() {
        var s = Self.state()
        var bag = Self.bag()
        _ = bag.add("battery", count: 1)
        do { let v = s.interact("machine_0", carrier: &bag); #expect(v == .needsItem("fuse")) }
        #expect(!s.isOn("machine_0"))
        #expect(bag.count(of: "battery") == 1)                               // nothing consumed
        _ = bag.add("fuse", count: 2)
        do { let v = s.interact("machine_0", carrier: &bag); #expect(v == .activated) }
        #expect(bag.count(of: "fuse") == 1)
        do { let v = s.interact("machine_0", carrier: &bag); #expect(v == .alreadyOn) }
        #expect(bag.count(of: "fuse") == 1)
    }

    @Test func gateAndExitAndProgress() {
        var s = Self.state()
        var bag = Self.bag(fuses: 1)
        #expect(!s.isGateOpen("gate_2"))
        #expect(s.gateProgress("gate_2") == (0, 1))
        _ = s.interact("button_g", carrier: &bag)
        #expect(s.isGateOpen("gate_2"))
        // Gate elements never count for the exit.
        #expect(s.requiredProgress == (0, 5))
        _ = s.interact("button_0", carrier: &bag)
        _ = s.interact("lever_0", carrier: &bag)
        #expect(s.requiredProgress == (2, 5))
        _ = s.interact("lever_1", carrier: &bag)
        _ = s.interact("machine_0", carrier: &bag)
        #expect(s.requiredProgress == (4, 5))
        #expect(!s.isExitOpen)
        _ = s.updatePlate("plate_0", occupied: true, dt: 2)
        #expect(s.requiredProgress == (5, 5))
        #expect(s.isExitOpen)
    }

    @Test func unknownIdAndForceAllOn() {
        var s = Self.state()
        var bag = Self.bag()
        do { let v = s.interact("nope", carrier: &bag); #expect(v == .notReady) }
        s.forceAllOn()
        #expect(s.isExitOpen && s.isGateOpen("gate_2"))
    }

    @Test func builtFromAGeneratedLevel() {
        let def = GeneratedCorpus.def("l4")
        let l = LevelGenerator.generate(def, seed: 5, catalog: GeneratedCorpus.catalog)
        var s = PuzzleState(level: l, rules: GeneratedCorpus.data.rules.puzzle)
        #expect(s.requiredProgress.total == def.puzzle.elements.filter(\.required).reduce(0) { $0 + $1.count })
        var bag = Inventory(items: GeneratedCorpus.data.items, rules: GeneratedCorpus.data.rules.inventory)
        for i in l.itemPlacements { let v = bag.add(i.itemId, count: 1); #expect(v == 0) }
        for e in l.elements where e.type != .pressureplate { _ = s.interact(e.id, carrier: &bag) }
        for e in l.elements where e.type == .pressureplate { _ = s.updatePlate(e.id, occupied: true, dt: 5) }
        #expect(l.gates.allSatisfy { s.isGateOpen($0.id) })
        #expect(s.isExitOpen)
        #expect(bag.isEmpty)
    }

    /// Former `puzzleBagOverflowAndRemove`, on the `Inventory`: remove is all or nothing, and
    /// every puzzle item from items.json can be carried.
    @Test func carrierRemoveIsAllOrNothing() {
        var b = Self.bag(fuses: 2)
        do { let v = b.remove("fuse", count: 3); #expect(!v) }
        #expect(b.count(of: "fuse") == 2)
        do { let v = b.remove("fuse", count: 2); #expect(v) }
        #expect(b.isEmpty)
        for id in ["fuse", "battery", "keycard", "energycore"] { #expect(b.canStore(id)) }
    }
}
