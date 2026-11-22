import CoreGraphics
import Foundation

/// Integer tile coordinate. `x` grows to the right, `y` grows upwards (SpriteKit world).
nonisolated struct GridPoint: Hashable, Sendable, Codable, Comparable, CustomStringConvertible {
    var x: Int
    var y: Int

    init(_ x: Int, _ y: Int) {
        self.x = x
        self.y = y
    }

    init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }

    static func < (a: GridPoint, b: GridPoint) -> Bool { a.y != b.y ? a.y < b.y : a.x < b.x }

    var description: String { "(\(x),\(y))" }

    /// The four orthogonal neighbours (right, left, up, down).
    var neighbors4: [GridPoint] { [GridPoint(x + 1, y), GridPoint(x - 1, y), GridPoint(x, y + 1), GridPoint(x, y - 1)] }

    /// Chebyshev (king-move) distance.
    func chebyshev(_ o: GridPoint) -> Int { max(abs(x - o.x), abs(y - o.y)) }

    func distance(_ o: GridPoint) -> Double { hypot(Double(x - o.x), Double(y - o.y)) }
}

nonisolated enum Tile: UInt8, Sendable, Codable {
    case wall, floor
}

/// Rectangular tile map (GDD §2: 64 pt tiles). Replaces `RoomGeometry` for generated levels.
/// Pure value type; closed doors are written in as `.wall` by the caller (see `settingWalls`).
nonisolated struct TileGrid: Sendable, Equatable {
    /// Tile edge in points (DECISIONS: 64 pt).
    static let tileSize: CGFloat = 64

    let width: Int
    let height: Int
    private(set) var tiles: [Tile]

    init(width: Int, height: Int, fill: Tile = .wall) {
        self.width = max(0, width)
        self.height = max(0, height)
        tiles = Array(repeating: fill, count: self.width * self.height)
    }

    @inline(__always) func contains(_ p: GridPoint) -> Bool { p.x >= 0 && p.y >= 0 && p.x < width && p.y < height }
    @inline(__always) func index(_ p: GridPoint) -> Int { p.y * width + p.x }
    @inline(__always) func point(_ index: Int) -> GridPoint { GridPoint(index % width, index / width) }

    /// Out-of-bounds cells read as `.wall`.
    subscript(_ p: GridPoint) -> Tile {
        get { contains(p) ? tiles[index(p)] : .wall }
        set { if contains(p) { tiles[index(p)] = newValue } }
    }

    subscript(_ x: Int, _ y: Int) -> Tile {
        get { self[GridPoint(x, y)] }
        set { self[GridPoint(x, y)] = newValue }
    }

    @inline(__always) func isWalkable(_ p: GridPoint) -> Bool { contains(p) && tiles[index(p)] == .floor }

    var floorCount: Int { tiles.reduce(0) { $0 + ($1 == .floor ? 1 : 0) } }

    /// Copy with the given cells turned into walls (closed doors).
    func settingWalls(_ cells: some Sequence<GridPoint>) -> TileGrid {
        var g = self
        for c in cells { g[c] = .wall }
        return g
    }

    // MARK: World ↔ grid

    /// Centre of a cell in world points.
    func world(_ p: GridPoint) -> CGPoint {
        CGPoint(x: (CGFloat(p.x) + 0.5) * Self.tileSize, y: (CGFloat(p.y) + 0.5) * Self.tileSize)
    }

    /// Cell that contains a world point (may be outside the grid).
    func cell(at p: CGPoint) -> GridPoint {
        GridPoint(Int((p.x / Self.tileSize).rounded(.down)), Int((p.y / Self.tileSize).rounded(.down)))
    }

    /// World rectangle of the whole map.
    var bounds: CGRect { CGRect(x: 0, y: 0, width: CGFloat(width) * Self.tileSize, height: CGFloat(height) * Self.tileSize) }

    // MARK: Queries

    /// True when the segment from `a` to `b` (world points) crosses only walkable cells
    /// (grid DDA, Amanatides–Woo). A segment through the exact corner of two cells is blocked
    /// if either side cell is a wall, so sight never slips through diagonal gaps.
    func hasLineOfSight(from a: CGPoint, to b: CGPoint) -> Bool {
        let t = Self.tileSize
        var c = cell(at: a)
        let end = cell(at: b)
        guard isWalkable(c), isWalkable(end) else { return false }
        if c == end { return true }
        let dx = b.x - a.x, dy = b.y - a.y
        let stepX = dx > 0 ? 1 : (dx < 0 ? -1 : 0)
        let stepY = dy > 0 ? 1 : (dy < 0 ? -1 : 0)
        let inf = CGFloat.infinity
        let tDeltaX = stepX != 0 ? t / abs(dx) : inf
        let tDeltaY = stepY != 0 ? t / abs(dy) : inf
        let nextX = stepX > 0 ? CGFloat(c.x + 1) * t : CGFloat(c.x) * t
        let nextY = stepY > 0 ? CGFloat(c.y + 1) * t : CGFloat(c.y) * t
        var tMaxX = stepX != 0 ? (nextX - a.x) / dx : inf
        var tMaxY = stepY != 0 ? (nextY - a.y) / dy : inf
        let maxSteps = abs(end.x - c.x) + abs(end.y - c.y) + 2
        for _ in 0..<maxSteps {
            if abs(tMaxX - tMaxY) < 1e-9 {
                // Exact corner: both side cells must be open.
                if !isWalkable(GridPoint(c.x + stepX, c.y)) || !isWalkable(GridPoint(c.x, c.y + stepY)) { return false }
                c = GridPoint(c.x + stepX, c.y + stepY)
                tMaxX += tDeltaX
                tMaxY += tDeltaY
            } else if tMaxX < tMaxY {
                c.x += stepX
                tMaxX += tDeltaX
            } else {
                c.y += stepY
                tMaxY += tDeltaY
            }
            if !isWalkable(c) { return false }
            if c == end { return true }
        }
        return c == end
    }

    /// True if a circle at `p` (world points) overlaps a non-walkable cell or leaves the grid.
    func isBlocked(_ p: CGPoint, radius: CGFloat) -> Bool {
        let t = Self.tileSize
        let r = max(0, radius)
        let minC = cell(at: CGPoint(x: p.x - r, y: p.y - r))
        let maxC = cell(at: CGPoint(x: p.x + r, y: p.y + r))
        for y in minC.y...maxC.y {
            for x in minC.x...maxC.x where !isWalkable(GridPoint(x, y)) {
                // Closest point of the cell rect to the circle centre.
                let cx = min(max(p.x, CGFloat(x) * t), CGFloat(x + 1) * t)
                let cy = min(max(p.y, CGFloat(y) * t), CGFloat(y + 1) * t)
                let ddx = p.x - cx, ddy = p.y - cy
                if ddx * ddx + ddy * ddy < r * r { return true }
                if r == 0, cx == p.x, cy == p.y { return true }
            }
        }
        return false
    }

    /// True if a circle of `radius` can slide from `a` to `b` without touching a wall
    /// (sampled every quarter of the radius, at most every 16 pt). Used for string pulling.
    func isSweepClear(from a: CGPoint, to b: CGPoint, radius: CGFloat) -> Bool {
        let d = hypot(b.x - a.x, b.y - a.y)
        let step = max(4, min(Self.tileSize / 4, radius / 2))
        let n = max(1, Int((d / step).rounded(.up)))
        for i in 0...n {
            let f = CGFloat(i) / CGFloat(n)
            if isBlocked(CGPoint(x: a.x + (b.x - a.x) * f, y: a.y + (b.y - a.y) * f), radius: radius) { return false }
        }
        return true
    }

    /// 4-connected flood fill over walkable cells. Returns a visited mask (index → reached).
    func floodFill(from starts: [GridPoint], blocked: Set<GridPoint> = []) -> [Bool] {
        var seen = Array(repeating: false, count: tiles.count)
        var queue: [Int] = []
        queue.reserveCapacity(tiles.count)
        for s in starts where isWalkable(s) && !blocked.contains(s) {
            let i = index(s)
            if !seen[i] { seen[i] = true; queue.append(i) }
        }
        var head = 0
        while head < queue.count {
            let i = queue[head]; head += 1
            let x = i % width, y = i / width
            for (nx, ny) in [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)] {
                guard nx >= 0, ny >= 0, nx < width, ny < height else { continue }
                let j = ny * width + nx
                guard !seen[j], tiles[j] == .floor else { continue }
                if !blocked.isEmpty, blocked.contains(GridPoint(nx, ny)) { continue }
                seen[j] = true
                queue.append(j)
            }
        }
        return seen
    }
}
