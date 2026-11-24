import CoreGraphics
import Foundation

/// A pickup lying on the floor right now (generator-placed or dropped from the bag).
nonisolated struct FloorItem: Sendable, Equatable {
    let id: String
    let itemId: String
    let position: CGPoint
}

nonisolated enum HintTarget: Sendable, Equatable {
    /// An element that is off (a machine counts once its item is in the bag).
    case element(id: String)
    /// The floor item a machine needs (not in the bag).
    case item(floorId: String, itemId: String, elementId: String)
    /// A machine whose item is neither in the bag nor reachable on the floor: no fly.
    case missingItem(itemId: String, elementId: String)
    /// Everything is on and the exit door is open.
    case exitPad
    /// Nothing reachable to point at.
    case none
}

/// Tap on Pixel or the idle timer.
nonisolated enum HintTrigger: Sendable, Equatable {
    case tap, idle
}

/// Pixel's hint: what, where to fly (nil = no fly) and the line to say.
nonisolated struct HintPlan: Sendable, Equatable {
    let target: HintTarget
    let flyTo: CGPoint?
    let lineKey: String?

    static let none = HintPlan(target: .none, flyTo: nil, lineKey: nil)
}

/// Minimap pings (GDD §13 "Pointer").
nonisolated struct HintPings: Sendable, Equatable {
    var elementIds: [String] = []
    var exitPad = false

    var isEmpty: Bool { elementIds.isEmpty && !exitPad }
}

/// Picks Pixel's hint target (GDD §13 "Hints"), never behind a closed door:
/// 1. the nearest (path distance) reachable required element that is off; elements of closed
///    gates count as required;
/// 2. a machine whose item is not in the bag → the nearest reachable floor copy (`hint_item`);
///    none → no fly, `need_<item>`;
/// 3. a machine whose item is in the bag → fly to the machine (`hint_machine`);
/// 4. else, once the exit door is open → the exit pad (`hint_exit`).
/// Flying to any other element says `hint_here` (tap) or `idle` (idle trigger).
nonisolated enum HintPlanner {
    static func plan(level: GeneratedLevel, puzzle: PuzzleState, heroAt hero: CGPoint, carrier: some ItemCarrier,
                     floorItems: [FloorItem], trigger: HintTrigger = .tap) -> HintPlan {
        let grid = currentGrid(level: level, puzzle: puzzle)
        let dist = distances(grid: grid, from: hero)
        var nearest: (element: PlacedElement, steps: Int)?
        for e in candidates(level: level, puzzle: puzzle) {
            guard let d = elementDistance(e, grid: grid, dist: dist) else { continue }
            if let n = nearest, d > n.steps || (d == n.steps && e.id >= n.element.id) { continue }
            nearest = (e, d)
        }
        if let e = nearest?.element {
            guard let item = e.requiresItem else {
                return HintPlan(target: .element(id: e.id), flyTo: e.position,
                                lineKey: trigger == .tap ? StoryDirector.Key.hintHere : StoryDirector.Key.idle)
            }
            if carrier.count(of: item) > 0 {
                return HintPlan(target: .element(id: e.id), flyTo: e.position, lineKey: StoryDirector.Key.hintMachine)
            }
            if let f = nearestFloorItem(item, floorItems, grid: grid, dist: dist) {
                return HintPlan(target: .item(floorId: f.id, itemId: item, elementId: e.id), flyTo: f.position,
                                lineKey: StoryDirector.Key.hintItem)
            }
            return HintPlan(target: .missingItem(itemId: item, elementId: e.id), flyTo: nil,
                            lineKey: StoryDirector.Key.need(item))
        }
        if puzzle.isExitOpen, isReachable(level.exitPad, grid: grid, dist: dist) {
            return HintPlan(target: .exitPad, flyTo: level.exitPadPosition, lineKey: StoryDirector.Key.hintExit)
        }
        return .none
    }

    /// After `pointerAfterSec` in the level: every reachable required (or closed-gate) element
    /// that is off, plus the exit pad once the exit door is open and reachable. Sorted ids.
    static func pings(afterSec elapsed: Double, rules: HintRulesDef, level: GeneratedLevel, puzzle: PuzzleState,
                      heroAt hero: CGPoint) -> HintPings {
        guard elapsed >= rules.pointerAfterSec else { return HintPings() }
        let grid = currentGrid(level: level, puzzle: puzzle)
        let dist = distances(grid: grid, from: hero)
        let ids = candidates(level: level, puzzle: puzzle)
            .filter { elementDistance($0, grid: grid, dist: dist) != nil }
            .map(\.id).sorted()
        return HintPings(elementIds: ids,
                         exitPad: puzzle.isExitOpen && isReachable(level.exitPad, grid: grid, dist: dist))
    }

    // MARK: Helpers

    /// Solid grid for the current doors (closed gates and a closed exit are walls).
    static func currentGrid(level: GeneratedLevel, puzzle: PuzzleState) -> TileGrid {
        level.grid(closedGates: Set(level.gates.map(\.id).filter { !puzzle.isGateOpen($0) }),
                   exitClosed: !puzzle.isExitOpen)
    }

    /// Elements that are off and still needed: exit elements and elements of closed gates.
    static func candidates(level: GeneratedLevel, puzzle: PuzzleState) -> [PlacedElement] {
        let exit = Set(level.exitDoor.elementIds)
        return level.elements.filter { e in
            guard !puzzle.isOn(e.id) else { return false }
            if exit.contains(e.id) { return true }
            return e.gateId.map { !puzzle.isGateOpen($0) } ?? false
        }
    }

    /// BFS step counts on walkable cells from the hero's cell (-1 = unreachable).
    static func distances(grid: TileGrid, from p: CGPoint) -> [Int] {
        var dist = Array(repeating: -1, count: grid.width * grid.height)
        var start = grid.cell(at: p)
        if !grid.isWalkable(start), let n = start.neighbors4.first(where: grid.isWalkable) { start = n }
        guard grid.isWalkable(start) else { return dist }
        var queue = [start]
        dist[grid.index(start)] = 0
        var head = 0
        while head < queue.count {
            let c = queue[head]
            head += 1
            let d = dist[grid.index(c)] + 1
            for n in c.neighbors4 where grid.isWalkable(n) && dist[grid.index(n)] < 0 {
                dist[grid.index(n)] = d
                queue.append(n)
            }
        }
        return dist
    }

    /// Steps to stand on or next to the element (same rule as `SolvabilityChecker`); nil if unreachable.
    static func elementDistance(_ e: PlacedElement, grid: TileGrid, dist: [Int]) -> Int? {
        var best: Int?
        for c in e.cells {
            for x in [c] + c.neighbors4 where grid.contains(x) {
                let d = dist[grid.index(x)]
                if d >= 0, best == nil || d < best! { best = d }
            }
        }
        return best
    }

    static func isReachable(_ c: GridPoint, grid: TileGrid, dist: [Int]) -> Bool {
        grid.contains(c) && dist[grid.index(c)] >= 0
    }

    private static func nearestFloorItem(_ itemId: String, _ items: [FloorItem], grid: TileGrid,
                                         dist: [Int]) -> FloorItem? {
        var best: (item: FloorItem, steps: Int)?
        for f in items where f.itemId == itemId {
            let c = grid.cell(at: f.position)
            guard grid.contains(c) else { continue }
            let d = dist[grid.index(c)]
            guard d >= 0 else { continue }
            if let b = best, d > b.steps || (d == b.steps && f.id >= b.item.id) { continue }
            best = (f, d)
        }
        return best?.item
    }
}
