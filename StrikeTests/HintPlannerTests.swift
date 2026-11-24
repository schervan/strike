import CoreGraphics
import Testing
@testable import Strike

struct HintPlannerTests {
    static var data: GameData { GeneratedCorpus.data }

    static func level(_ id: String, _ seed: UInt64) -> GeneratedLevel {
        LevelGenerator.generate(GeneratedCorpus.def(id), seed: seed, catalog: GeneratedCorpus.catalog)
    }

    static func emptyBag() -> Inventory { Inventory(items: data.items, rules: data.rules.inventory) }

    static func floorItems(_ l: GeneratedLevel) -> [FloorItem] {
        l.itemPlacements.map { FloorItem(id: $0.id, itemId: $0.itemId, position: l.grid.world($0.cell)) }
    }

    /// Reachability computed independently of the planner (same rule as `SolvabilityChecker`).
    static func reach(_ l: GeneratedLevel, _ puzzle: PuzzleState, from hero: CGPoint) -> [Bool] {
        var closed = Set(l.gates.filter { !puzzle.isGateOpen($0.id) }.flatMap(\.cells))
        if !puzzle.isExitOpen { closed.formUnion(l.exitDoor.cells) }
        return l.grid.floodFill(from: [l.grid.cell(at: hero)], blocked: closed)
    }

    static func reachable(_ e: PlacedElement, _ reach: [Bool], _ grid: TileGrid) -> GridPoint? {
        for c in e.cells { for x in [c] + c.neighbors4 where grid.contains(x) && reach[grid.index(x)] { return x } }
        return nil
    }

    /// Turns an element on the way the hero would.
    static func activate(_ e: PlacedElement, _ puzzle: inout PuzzleState, _ bag: inout Inventory) {
        if e.type == .pressureplate { _ = puzzle.updatePlate(e.id, occupied: true, dt: 5) } else { _ = puzzle.interact(e.id, carrier: &bag) }
    }

    /// Follows Pixel's hints from the start pad to the exit pad. Every target must be reachable
    /// through the doors that are open at that moment.
    @Test(arguments: ["l2", "l4"])
    func neverPointsBehindAClosedDoorOnGeneratedLevels(_ levelId: String) {
        for seed: UInt64 in 0..<40 {
            let l = Self.level(levelId, seed)
            var puzzle = PuzzleState(level: l, rules: Self.data.rules.puzzle)
            var bag = Self.emptyBag()
            var floor = Self.floorItems(l)
            var hero = l.grid.world(l.heroStart)
            var reachedExit = false
            for _ in 0..<100 {
                let plan = HintPlanner.plan(level: l, puzzle: puzzle, heroAt: hero, carrier: bag, floorItems: floor)
                let reach = Self.reach(l, puzzle, from: hero)
                switch plan.target {
                case .element(let id):
                    let e = l.element(id)!
                    guard let stand = Self.reachable(e, reach, l.grid) else {
                        Issue.record("\(levelId) seed \(seed): \(id) behind a closed door"); return
                    }
                    if let item = e.requiresItem { #expect(bag.count(of: item) > 0) }
                    hero = l.grid.world(stand)
                    Self.activate(e, &puzzle, &bag)
                    #expect(puzzle.isOn(id), "\(levelId) seed \(seed): \(id) did not turn on")
                case .item(let floorId, let itemId, let elementId):
                    let f = floor.first { $0.id == floorId }!
                    #expect(reach[l.grid.index(l.grid.cell(at: f.position))], "\(levelId) seed \(seed): item behind door")
                    #expect(l.element(elementId)?.requiresItem == itemId)
                    #expect(bag.count(of: itemId) == 0)
                    hero = f.position
                    _ = bag.add(itemId, count: 1)
                    floor.removeAll { $0.id == floorId }
                case .exitPad:
                    #expect(reach[l.grid.index(l.exitPad)], "\(levelId) seed \(seed): exit pad behind door")
                    #expect(plan.flyTo == l.exitPadPosition)
                    reachedExit = true
                case .missingItem, .none:
                    Issue.record("\(levelId) seed \(seed): stuck with \(plan.target)"); return
                }
                if reachedExit { break }
            }
            #expect(reachedExit, "\(levelId) seed \(seed): hints never led to the exit")
        }
    }

    /// L2: levers and the gate button on, the fuse machine off.
    static func l2MachineOnly(seed: UInt64 = 1) -> (GeneratedLevel, PuzzleState, PlacedElement) {
        let l = level("l2", seed)
        var puzzle = PuzzleState(level: l, rules: data.rules.puzzle)
        var bag = emptyBag()
        for e in l.elements where e.type != .machine { activate(e, &puzzle, &bag) }
        let machine = l.elements.first { $0.type == .machine }!
        return (l, puzzle, machine)
    }

    @Test func pointsAtTheFloorItemWhenTheMachineNeedsOneAndTheBagLacksIt() throws {
        let (l, puzzle, machine) = Self.l2MachineOnly()
        #expect(l.gates.allSatisfy { puzzle.isGateOpen($0.id) })
        let fuse = try #require(l.itemPlacements.first { $0.elementId == machine.id })
        let plan = HintPlanner.plan(level: l, puzzle: puzzle, heroAt: l.grid.world(l.heroStart), carrier: Self.emptyBag(),
                                    floorItems: Self.floorItems(l))
        #expect(plan.target == .item(floorId: fuse.id, itemId: "fuse", elementId: machine.id))
        #expect(plan.flyTo == l.grid.world(fuse.cell))
        #expect(plan.lineKey == StoryDirector.Key.hintItem)
    }

    /// GDD §13 Hints step 3 (M3-1): with the item in the bag Pixel flies to the machine and says
    /// `hint_machine`; `need_*` is for an item that is neither in the bag nor on the floor.
    @Test func itemInTheBagFliesToTheMachineAndMissingItemSaysNeed() {
        let (l, puzzle, machine) = Self.l2MachineOnly()
        var bag = Self.emptyBag()
        _ = bag.add("fuse", count: 1)
        let hero = l.grid.world(l.heroStart)
        let withItem = HintPlanner.plan(level: l, puzzle: puzzle, heroAt: hero, carrier: bag, floorItems: [])
        #expect(withItem.target == .element(id: machine.id))
        #expect(withItem.flyTo == machine.position)
        #expect(withItem.lineKey == StoryDirector.Key.hintMachine)

        let missing = HintPlanner.plan(level: l, puzzle: puzzle, heroAt: hero, carrier: Self.emptyBag(), floorItems: [])
        #expect(missing.target == .missingItem(itemId: "fuse", elementId: machine.id))
        #expect(missing.flyTo == nil)
        #expect(missing.lineKey == "pixel.generic.need_fuse")
    }

    @Test func pointsAtTheExitPadOnceAllElementsAreOn() {
        let l = Self.level("l4", 2)
        var puzzle = PuzzleState(level: l, rules: Self.data.rules.puzzle)
        puzzle.forceAllOn()
        #expect(puzzle.isExitOpen)
        let plan = HintPlanner.plan(level: l, puzzle: puzzle, heroAt: l.grid.world(l.heroStart), carrier: Self.emptyBag(),
                                    floorItems: [])
        #expect(plan.target == .exitPad)
        #expect(plan.flyTo == l.exitPadPosition)
        #expect(plan.lineKey == StoryDirector.Key.hintExit)
    }

    @Test func tapAndIdleLines() {
        let l = Self.level("l1", 4)
        let puzzle = PuzzleState(level: l, rules: Self.data.rules.puzzle)
        let hero = l.grid.world(l.heroStart)
        let tap = HintPlanner.plan(level: l, puzzle: puzzle, heroAt: hero, carrier: Self.emptyBag(), floorItems: [])
        let idle = HintPlanner.plan(level: l, puzzle: puzzle, heroAt: hero, carrier: Self.emptyBag(), floorItems: [],
                                    trigger: .idle)
        #expect(tap.lineKey == StoryDirector.Key.hintHere)
        #expect(idle.lineKey == StoryDirector.Key.idle)
        #expect(tap.target == idle.target)
    }

    @Test func pingsStartOnlyAfterPointerAfterSec() {
        let rules = Self.data.rules.hints
        let l = Self.level("l4", 6)
        var puzzle = PuzzleState(level: l, rules: Self.data.rules.puzzle)
        let hero = l.grid.world(l.heroStart)
        #expect(HintPlanner.pings(afterSec: rules.pointerAfterSec - 0.1, rules: rules, level: l, puzzle: puzzle, heroAt: hero).isEmpty)
        let p = HintPlanner.pings(afterSec: rules.pointerAfterSec, rules: rules, level: l, puzzle: puzzle, heroAt: hero)
        #expect(!p.elementIds.isEmpty && !p.exitPad)
        let reach = Self.reach(l, puzzle, from: hero)
        for id in p.elementIds { #expect(Self.reachable(l.element(id)!, reach, l.grid) != nil, "\(id)") }
        puzzle.forceAllOn()
        let done = HintPlanner.pings(afterSec: 999, rules: rules, level: l, puzzle: puzzle, heroAt: hero)
        #expect(done.elementIds.isEmpty && done.exitPad)
    }
}
