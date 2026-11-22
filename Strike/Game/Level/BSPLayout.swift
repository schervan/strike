import CoreGraphics
import Foundation

/// Axis-aligned room in tile coordinates. `x`/`y` is the bottom-left floor cell; the room is
/// `width × height` floor cells (walls are the cells around it).
nonisolated struct RoomRect: Sendable, Equatable, Hashable, Codable {
    let x: Int
    let y: Int
    let width: Int
    let height: Int

    var maxX: Int { x + width }    // exclusive
    var maxY: Int { y + height }   // exclusive
    var area: Int { width * height }
    /// Centre in tile units (continuous).
    var center: (x: Double, y: Double) { (Double(x) + Double(width) / 2, Double(y) + Double(height) / 2) }
    var centerCell: GridPoint { GridPoint(x + width / 2, y + height / 2) }

    func contains(_ p: GridPoint) -> Bool { p.x >= x && p.x < maxX && p.y >= y && p.y < maxY }

    /// Distance of a room cell to the room edge: 0 on the outer ring, 1 one cell further in, …
    func ring(_ p: GridPoint) -> Int { min(p.x - x, maxX - 1 - p.x, p.y - y, maxY - 1 - p.y) }

    var cells: [GridPoint] {
        var out: [GridPoint] = []
        out.reserveCapacity(area)
        for yy in y..<maxY { for xx in x..<maxX { out.append(GridPoint(xx, yy)) } }
        return out
    }

    /// Empty tiles between the two rects along x and y (0 when the projections overlap).
    func gap(to o: RoomRect) -> (x: Int, y: Int) {
        (max(0, max(o.x - maxX, x - o.maxX)), max(0, max(o.y - maxY, y - o.maxY)))
    }

    /// Overlap of the x / y projections in tiles (≤ 0 when disjoint).
    func overlapX(_ o: RoomRect) -> Int { min(maxX, o.maxX) - max(x, o.x) }
    func overlapY(_ o: RoomRect) -> Int { min(maxY, o.maxY) - max(y, o.y) }
}

/// Connected run of non-room floor cells (a corridor, a junction of corridors, or the exit
/// niche) and the rooms it touches. Derived from the carved grid by `LevelGraph`.
nonisolated struct Corridor: Sendable, Equatable, Identifiable {
    let id: Int
    let cells: [GridPoint]
    /// Rooms with a floor cell orthogonally next to one of `cells`, ascending.
    let roomIds: [Int]
}

/// GDD §14.1 steps 1–2: BSP split, one room per leaf, corridors between BSP siblings, loop
/// corridors. Pure; randomness only through `LevelRandom`.
nonisolated enum BSPLayout {
    struct Node: Sendable {
        let rect: RoomRect          // leaf area (not the room)
        var children: (Int, Int)?
        var roomId: Int?
    }

    struct Result: Sendable {
        /// Kept rooms; `rooms[i]` has id `i` (ids follow BSP leaf order).
        let rooms: [RoomRect]
        /// BSP tree, root at index 0.
        let nodes: [Node]
    }

    /// Splits the map and places rooms. Nil when fewer than `roomCount.min` rooms fit.
    static func makeRooms(_ p: GeneratorParams, _ random: LevelRandom) -> Result? {
        let minLeaf = p.minRoomSize + 2  // 1-tile margin on each side
        var nodes = [Node(rect: RoomRect(x: 0, y: 0, width: p.gridWidth, height: p.gridHeight), children: nil, roomId: nil)]

        func split(_ i: Int, depth: Int) {
            let r = nodes[i].rect
            guard depth < p.bspMaxDepth else { return }
            let canV = r.width >= 2 * minLeaf   // vertical cut line → left / right
            let canH = r.height >= 2 * minLeaf  // horizontal cut line → bottom / top
            guard canV || canH else { return }
            let vertical: Bool
            if canV && canH {
                if Double(r.width) > Double(r.height) * 1.25 { vertical = true }
                else if Double(r.height) > Double(r.width) * 1.25 { vertical = false }
                else { vertical = random.chance(0.5) }
            } else {
                vertical = canV
            }
            let size = vertical ? r.width : r.height
            let lo = max(minLeaf, Int((Double(size) * 0.35).rounded()))
            let hi = min(size - minLeaf, Int((Double(size) * 0.65).rounded()))
            let cut = lo <= hi ? random.int(lo, hi) : size / 2
            let a: RoomRect, b: RoomRect
            if vertical {
                a = RoomRect(x: r.x, y: r.y, width: cut, height: r.height)
                b = RoomRect(x: r.x + cut, y: r.y, width: r.width - cut, height: r.height)
            } else {
                a = RoomRect(x: r.x, y: r.y, width: r.width, height: cut)
                b = RoomRect(x: r.x, y: r.y + cut, width: r.width, height: r.height - cut)
            }
            nodes.append(Node(rect: a, children: nil, roomId: nil))
            nodes.append(Node(rect: b, children: nil, roomId: nil))
            let ia = nodes.count - 2, ib = nodes.count - 1
            nodes[i].children = (ia, ib)
            split(ia, depth: depth + 1)
            split(ib, depth: depth + 1)
        }
        split(0, depth: 0)

        // One room per leaf (DFS order), inside a 1-tile margin.
        var candidates: [(node: Int, room: RoomRect)] = []
        func visit(_ i: Int) {
            if let (a, b) = nodes[i].children { visit(a); visit(b); return }
            let leaf = nodes[i].rect
            let maxW = min(p.maxRoomSize, leaf.width - 2), maxH = min(p.maxRoomSize, leaf.height - 2)
            guard maxW >= p.minRoomSize, maxH >= p.minRoomSize else { return }
            let w = random.int(p.minRoomSize, maxW), h = random.int(p.minRoomSize, maxH)
            let x = random.int(leaf.x + 1, leaf.maxX - 1 - w)
            let y = random.int(leaf.y + 1, leaf.maxY - 1 - h)
            candidates.append((i, RoomRect(x: x, y: y, width: w, height: h)))
        }
        visit(0)

        guard candidates.count >= p.roomCount.min else { return nil }
        let target = random.int(p.roomCount.min, p.roomCount.max)
        if candidates.count > target {
            // Discard the smallest extras (ties: later leaves first, deterministic).
            let order = candidates.indices.sorted {
                candidates[$0].room.area != candidates[$1].room.area
                    ? candidates[$0].room.area > candidates[$1].room.area : $0 < $1
            }
            let keep = Set(order.prefix(target))
            candidates = candidates.indices.filter { keep.contains($0) }.map { candidates[$0] }
        }
        var rooms: [RoomRect] = []
        for c in candidates {
            nodes[c.node].roomId = rooms.count
            rooms.append(c.room)
        }
        return Result(rooms: rooms, nodes: nodes)
    }

    static func carveRooms(_ rooms: [RoomRect], into grid: inout TileGrid) {
        for r in rooms { for c in r.cells { grid[c] = .floor } }
    }

    /// Connects BSP siblings bottom-up: for every inner node, the closest room pair across its two
    /// subtrees gets a corridor. Returns the carved `(roomA, roomB)` pairs.
    @discardableResult
    static func connectTree(_ layout: Result, width w: Int, grid: inout TileGrid, random: LevelRandom) -> [(Int, Int)] {
        var links: [(Int, Int)] = []
        func rooms(_ i: Int) -> [Int] {
            let n = layout.nodes[i]
            guard let (a, b) = n.children else { return n.roomId.map { [$0] } ?? [] }
            let ra = rooms(a), rb = rooms(b)
            if !ra.isEmpty, !rb.isEmpty {
                var best: (Int, Int, Double)?
                for x in ra {
                    for y in rb {
                        let g = layout.rooms[x].gap(to: layout.rooms[y])
                        let d = Double(g.x * g.x + g.y * g.y)
                        if best == nil || d < best!.2 { best = (x, y, d) }
                    }
                }
                if let (x, y, _) = best {
                    carve(corridorCells(layout.rooms[x], layout.rooms[y], width: w, random: random), into: &grid)
                    links.append((x, y))
                }
            }
            return ra + rb
        }
        _ = rooms(0)
        return links
    }

    static func carve(_ cells: [GridPoint], into grid: inout TileGrid) {
        for c in cells where c.x > 0 && c.y > 0 && c.x < grid.width - 1 && c.y < grid.height - 1 { grid[c] = .floor }
    }

    /// Straight corridor when the rooms' projections overlap by ≥ `width`, else L-shaped.
    /// Cells run from inside `a` to inside `b` (room cells included).
    static func corridorCells(_ a: RoomRect, _ b: RoomRect, width w: Int, random: LevelRandom) -> [GridPoint] {
        if let s = straightCorridor(a, b, width: w, random: random) { return s }
        // L-shape: pick a w-wide lane inside each room.
        let ax = random.int(a.x, a.maxX - w), ay = random.int(a.y, a.maxY - w)
        let bx = random.int(b.x, b.maxX - w), by = random.int(b.y, b.maxY - w)
        var cells: [GridPoint] = []
        func band(x0: Int, x1: Int, y0: Int, y1: Int) {
            for y in min(y0, y1)...max(y0, y1) { for x in min(x0, x1)...max(x0, x1) { cells.append(GridPoint(x, y)) } }
        }
        if random.chance(0.5) {
            // Horizontal leg at a's lane, then vertical leg at b's lane.
            band(x0: ax, x1: bx + w - 1, y0: ay, y1: ay + w - 1)
            band(x0: bx, x1: bx + w - 1, y0: ay, y1: by)
            band(x0: bx, x1: bx + w - 1, y0: by, y1: by + w - 1)
        } else {
            band(x0: ax, x1: ax + w - 1, y0: ay, y1: by + w - 1)
            band(x0: ax, x1: bx, y0: by, y1: by + w - 1)
            band(x0: bx, x1: bx + w - 1, y0: by, y1: by + w - 1)
        }
        return cells
    }

    /// Straight `w`-wide corridor between rooms whose x or y projections overlap by ≥ `w`
    /// (the lane keeps one cell away from room corners when possible). Nil otherwise.
    static func straightCorridor(_ a: RoomRect, _ b: RoomRect, width w: Int, random: LevelRandom) -> [GridPoint]? {
        var cells: [GridPoint] = []
        if a.overlapX(b) >= w, a.gap(to: b).y > 0 {
            let lo = max(a.x, b.x), hi = min(a.maxX, b.maxX) - w
            let x0 = hi - lo >= 2 ? random.int(lo + 1, hi - 1) : random.int(lo, hi)
            let (low, high) = a.y < b.y ? (a, b) : (b, a)
            for y in (low.maxY - 1)...high.y { for x in x0..<(x0 + w) { cells.append(GridPoint(x, y)) } }
            return cells
        }
        if a.overlapY(b) >= w, a.gap(to: b).x > 0 {
            let lo = max(a.y, b.y), hi = min(a.maxY, b.maxY) - w
            let y0 = hi - lo >= 2 ? random.int(lo + 1, hi - 1) : random.int(lo, hi)
            let (left, right) = a.x < b.x ? (a, b) : (b, a)
            for x in (left.maxX - 1)...right.x { for y in y0..<(y0 + w) { cells.append(GridPoint(x, y)) } }
            return cells
        }
        return nil
    }

    /// Room pairs that could get a straight loop corridor: overlapping projections and a gap of
    /// at most `maxGap` tiles. Ascending pairs, deterministic order.
    static func loopCandidates(_ rooms: [RoomRect], width w: Int, maxGap: Int) -> [(Int, Int)] {
        var out: [(Int, Int)] = []
        for i in rooms.indices {
            for j in rooms.indices where j > i {
                let a = rooms[i], b = rooms[j], g = a.gap(to: b)
                let vertical = a.overlapX(b) >= w && g.y > 0 && g.y <= maxGap
                let horizontal = a.overlapY(b) >= w && g.x > 0 && g.x <= maxGap
                if vertical || horizontal { out.append((i, j)) }
            }
        }
        return out
    }
}
