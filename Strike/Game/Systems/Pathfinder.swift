import CoreGraphics
import Foundation

/// Pure grid search used by `Pathfinder`: 4-connected BFS distance fields over walkable cells
/// (diagonals off, so paths never cut wall corners).
nonisolated enum GridSearch {
    /// Steps from every cell to `target` (-1 = unreachable or wall).
    static func distanceField(_ grid: TileGrid, to target: GridPoint) -> [Int32] {
        var dist = Array(repeating: Int32(-1), count: grid.width * grid.height)
        guard grid.isWalkable(target) else { return dist }
        let w = grid.width, h = grid.height
        var queue = [grid.index(target)]
        queue.reserveCapacity(dist.count)
        dist[queue[0]] = 0
        var head = 0
        while head < queue.count {
            let i = queue[head]; head += 1
            let x = i % w, y = i / w, d = dist[i] + 1
            for j in [x + 1 < w ? i + 1 : -1, x > 0 ? i - 1 : -1, y + 1 < h ? i + w : -1, y > 0 ? i - w : -1]
            where j >= 0 && dist[j] < 0 && grid.tiles[j] == .floor {
                dist[j] = d
                queue.append(j)
            }
        }
        return dist
    }

    /// Cell path from `start` to the field's target (both included), empty if unreachable.
    static func cellPath(_ grid: TileGrid, field: [Int32], from start: GridPoint) -> [GridPoint] {
        guard grid.contains(start), field[grid.index(start)] >= 0 else { return [] }
        var path = [start]
        var c = start
        while field[grid.index(c)] > 0 {
            let d = field[grid.index(c)]
            guard let next = c.neighbors4.first(where: { grid.contains($0) && field[grid.index($0)] == d - 1 }) else { return [] }
            path.append(next)
            c = next
        }
        return path
    }

    /// Nearest walkable cell within `maxRing` rings of `p` (itself if walkable).
    static func nearestWalkable(_ grid: TileGrid, _ p: GridPoint, maxRing: Int = 2) -> GridPoint? {
        if grid.isWalkable(p) { return p }
        for r in 1...max(1, maxRing) {
            var best: GridPoint?
            for dy in -r...r {
                for dx in -r...r where max(abs(dx), abs(dy)) == r {
                    let q = GridPoint(p.x + dx, p.y + dy)
                    if grid.isWalkable(q), best == nil || q.distance(p) < best!.distance(p) { best = q }
                }
            }
            if let best { return best }
        }
        return nil
    }

    /// Waypoints checked ahead of each anchor while string pulling (bounds the cost per path).
    static let pullLookahead = 12

    /// Forward greedy string pulling: from each anchor, advance while a circle of `radius` can
    /// slide straight to the next waypoint (at most `pullLookahead` ahead).
    static func stringPull(_ grid: TileGrid, from start: CGPoint, waypoints: [CGPoint], radius: CGFloat) -> [CGPoint] {
        guard !waypoints.isEmpty else { return [] }
        var out: [CGPoint] = []
        var anchor = start
        var i = 0
        while i < waypoints.count {
            var j = i
            while j + 1 < waypoints.count, j + 1 - i <= pullLookahead,
                  grid.isSweepClear(from: anchor, to: waypoints[j + 1], radius: radius) {
                j += 1
            }
            out.append(waypoints[j])
            anchor = waypoints[j]
            i = j + 1
        }
        return out
    }
}

/// Chaser pathfinding on the level's tile grid (DECISIONS: grid pathfinding when there is no
/// direct line of sight). Distance fields are cached per target cell, so many enemies chasing
/// the same hero cell share one BFS; any door change clears the cache.
@MainActor
final class Pathfinder {
    private(set) var grid: TileGrid
    private var cache: [GridPoint: [Int32]] = [:]
    private var cacheOrder: [GridPoint] = []
    /// Distinct target cells kept (hero cell, home spawn cells of returning enemies).
    static let cacheLimit = 16

    init(grid: TileGrid) {
        self.grid = grid
    }

    /// Replaces the grid (e.g. a level with different closed doors).
    func rebuild(grid: TileGrid) {
        self.grid = grid
        cache.removeAll()
        cacheOrder.removeAll()
    }

    /// Opens (`walkable = true`) or closes door cells and rebuilds.
    func setCells(_ cells: [GridPoint], walkable: Bool) {
        var g = grid
        for c in cells { g[c] = walkable ? .floor : .wall }
        rebuild(grid: g)
    }

    private func field(to target: GridPoint) -> [Int32] {
        if let f = cache[target] { return f }
        let f = GridSearch.distanceField(grid, to: target)
        cache[target] = f
        cacheOrder.append(target)
        if cacheOrder.count > Self.cacheLimit { cache[cacheOrder.removeFirst()] = nil }
        return f
    }

    /// Cell path (start and target included), empty if unreachable.
    func cellPath(from a: GridPoint, to b: GridPoint) -> [GridPoint] {
        guard let s = GridSearch.nearestWalkable(grid, a), let t = GridSearch.nearestWalkable(grid, b) else { return [] }
        return GridSearch.cellPath(grid, field: field(to: t), from: s)
    }

    /// Steps between two cells, nil if unreachable.
    func steps(from a: GridPoint, to b: GridPoint) -> Int? {
        let p = cellPath(from: a, to: b)
        return p.isEmpty ? nil : p.count - 1
    }

    /// World waypoints from `a` to `b` for a body of `radius` (string-pulled, `b` last when its
    /// cell is walkable). Empty when unreachable or already in the target cell.
    func path(from a: CGPoint, to b: CGPoint, radius: CGFloat = 0) -> [CGPoint] {
        let cells = cellPath(from: grid.cell(at: a), to: grid.cell(at: b))
        guard cells.count > 1 else { return [] }
        var points = cells.dropFirst().map { grid.world($0) }
        if grid.isWalkable(grid.cell(at: b)), !grid.isBlocked(b, radius: radius) { points[points.count - 1] = b }
        return GridSearch.stringPull(grid, from: a, waypoints: Array(points), radius: radius)
    }

    /// First string-pulled waypoint only (cheap per-frame steering). Nil when unreachable or
    /// already in the target cell.
    func nextWaypoint(from a: CGPoint, to b: CGPoint, radius: CGFloat) -> CGPoint? {
        let cells = cellPath(from: grid.cell(at: a), to: grid.cell(at: b))
        guard cells.count > 1 else { return nil }
        let n = min(cells.count - 1, GridSearch.pullLookahead)
        var best = grid.world(cells[1])
        for k in stride(from: n, through: 2, by: -1) {
            let p = k == cells.count - 1 && !grid.isBlocked(b, radius: radius) ? b : grid.world(cells[k])
            if grid.isSweepClear(from: a, to: p, radius: radius) { best = p; break }
        }
        return best
    }
}
