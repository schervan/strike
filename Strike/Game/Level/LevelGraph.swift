import Foundation

/// Room adjacency derived from the carved grid (GDD §14.1 steps 3–4). Corridors are the
/// connected runs of non-room floor cells, so accidental crossings and corridors that pass
/// through a third room are represented exactly as the player experiences them.
nonisolated struct LevelGraph: Sendable {
    let rooms: [RoomRect]
    let corridors: [Corridor]
    /// Per room: `(neighbour room, corridor id)` pairs, sorted.
    let adjacency: [[Link]]
    /// Per grid cell: room id or -1.
    let roomMap: [Int]
    /// Per grid cell: corridor id or -1.
    let corridorMap: [Int]
    let width: Int

    struct Link: Sendable, Equatable, Comparable {
        let room: Int
        let corridor: Int
        static func < (a: Link, b: Link) -> Bool { a.room != b.room ? a.room < b.room : a.corridor < b.corridor }
    }

    static func build(grid: TileGrid, rooms: [RoomRect]) -> LevelGraph {
        let w = grid.width, n = grid.width * grid.height
        var roomMap = Array(repeating: -1, count: n)
        for (id, r) in rooms.enumerated() { for c in r.cells where grid.contains(c) { roomMap[grid.index(c)] = id } }

        var corridorMap = Array(repeating: -1, count: n)
        var corridors: [Corridor] = []
        for start in 0..<n where grid.tiles[start] == .floor && roomMap[start] < 0 && corridorMap[start] < 0 {
            let id = corridors.count
            var cells: [GridPoint] = []
            var touching = Set<Int>()
            var queue = [start]
            corridorMap[start] = id
            var head = 0
            while head < queue.count {
                let i = queue[head]; head += 1
                let p = grid.point(i)
                cells.append(p)
                for q in p.neighbors4 where grid.isWalkable(q) {
                    let j = grid.index(q)
                    if roomMap[j] >= 0 { touching.insert(roomMap[j]); continue }
                    if corridorMap[j] < 0 { corridorMap[j] = id; queue.append(j) }
                }
            }
            corridors.append(Corridor(id: id, cells: cells.sorted(), roomIds: touching.sorted()))
        }

        var adjacency = Array(repeating: [Link](), count: rooms.count)
        for c in corridors {
            for a in c.roomIds { for b in c.roomIds where b != a { adjacency[a].append(Link(room: b, corridor: c.id)) } }
        }
        return LevelGraph(rooms: rooms, corridors: corridors, adjacency: adjacency.map { $0.sorted() },
                          roomMap: roomMap, corridorMap: corridorMap, width: w)
    }

    func roomId(at p: GridPoint) -> Int? {
        guard p.x >= 0, p.y >= 0, p.x < width, p.y * width + p.x < roomMap.count else { return nil }
        let r = roomMap[p.y * width + p.x]
        return r >= 0 ? r : nil
    }

    func corridorId(at p: GridPoint) -> Int? {
        guard p.x >= 0, p.y >= 0, p.x < width, p.y * width + p.x < corridorMap.count else { return nil }
        let c = corridorMap[p.y * width + p.x]
        return c >= 0 ? c : nil
    }

    func degree(_ room: Int) -> Int { Set(adjacency[room].map(\.room)).count }

    /// BFS hop distances from `start` (-1 = unreachable), not crossing `excluded` corridors.
    func distances(from start: Int, excluding excluded: Set<Int> = []) -> [Int] {
        var dist = Array(repeating: -1, count: rooms.count)
        guard rooms.indices.contains(start) else { return dist }
        dist[start] = 0
        var queue = [start], head = 0
        while head < queue.count {
            let r = queue[head]; head += 1
            for l in adjacency[r] where dist[l.room] < 0 && !excluded.contains(l.corridor) {
                dist[l.room] = dist[r] + 1
                queue.append(l.room)
            }
        }
        return dist
    }

    /// Shortest room path (ties broken by lower room id), empty if unreachable.
    func shortestPath(from a: Int, to b: Int, excluding excluded: Set<Int> = []) -> [Int] {
        var prev = Array(repeating: -1, count: rooms.count)
        var seen = Array(repeating: false, count: rooms.count)
        guard rooms.indices.contains(a), rooms.indices.contains(b) else { return [] }
        seen[a] = true
        var queue = [a], head = 0
        while head < queue.count {
            let r = queue[head]; head += 1
            if r == b { break }
            for l in adjacency[r] where !seen[l.room] && !excluded.contains(l.corridor) {
                seen[l.room] = true
                prev[l.room] = r
                queue.append(l.room)
            }
        }
        guard seen[b] else { return [] }
        var path = [b]
        while let last = path.last, last != a { path.append(prev[last]) }
        return path.reversed()
    }

    /// Corridors linking exactly the rooms `a` and `b`.
    func corridors(between a: Int, _ b: Int) -> [Int] {
        Set(adjacency[a].filter { $0.room == b }.map(\.corridor)).sorted()
    }

    /// Component label per room after removing `excluded` corridors (labels in discovery order).
    func components(excluding excluded: Set<Int>) -> [Int] {
        var label = Array(repeating: -1, count: rooms.count)
        var next = 0
        for s in rooms.indices where label[s] < 0 {
            let d = distances(from: s, excluding: excluded)
            for (i, v) in d.enumerated() where v >= 0 { label[i] = next }
            next += 1
        }
        return label
    }

    /// Start room (GDD §14.1 step 3): smallest id whose centre lies in the left third of the
    /// map; the leftmost room if none does.
    func startRoom(mapWidth: Int) -> Int {
        if let r = rooms.indices.first(where: { rooms[$0].center.x < Double(mapWidth) / 3 }) { return r }
        return rooms.indices.min { rooms[$0].center.x < rooms[$1].center.x } ?? 0
    }

    /// Rooms by BFS distance from `start`, farthest first (ties: lower id first).
    func roomsByDistance(from start: Int) -> [Int] {
        let d = distances(from: start)
        return rooms.indices.filter { d[$0] > 0 }.sorted { d[$0] != d[$1] ? d[$0] > d[$1] : $0 < $1 }
    }

    /// Room cells within Chebyshev `depth` of a corridor mouth (a corridor cell orthogonally next
    /// to a room). Nothing solid or interactable is placed there (GDD §14.1 "not blocking a doorway").
    static func doorwayReserve(grid: TileGrid, graph: LevelGraph, depth: Int) -> Set<GridPoint> {
        var out = Set<GridPoint>()
        for c in graph.corridors {
            for cell in c.cells {
                guard cell.neighbors4.contains(where: { graph.roomId(at: $0) != nil }) else { continue }
                for dy in -depth...depth {
                    for dx in -depth...depth {
                        let q = GridPoint(cell.x + dx, cell.y + dy)
                        if graph.roomId(at: q) != nil { out.insert(q) }
                    }
                }
            }
        }
        return out
    }
}
