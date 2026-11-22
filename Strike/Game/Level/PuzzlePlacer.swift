import Foundation

/// GDD §14.1 step 5: puzzle elements (exit and gate elements) and machine items.
/// Rules: never in the start room or in corridors, never in the doorway reserve, one cell off
/// the walls, at least `minElementSpacing` tiles apart (centre to centre); gate elements in
/// `zone − 1`; machine items in a different room of the same zone (`sameZone`) or an earlier
/// zone (`earlierZone`), which also keeps them in front of the gate they open.
nonisolated enum PuzzlePlacer {
    struct Result: Sendable {
        let elements: [PlacedElement]
        let items: [ItemPlacement]
    }

    /// Minimum Chebyshev distance between an item and any element footprint cell.
    static let itemElementClearance = 2

    private struct Request {
        let type: ElementType
        let required: Bool
        let zones: [Int]
        let requiresItem: String?
        let itemPlacement: ItemPlacementRule
        let gateZone: Int?
    }

    static func place(_ level: LevelDef, rooms: [LevelRoom], startRoom: Int, doorwayReserve: Set<GridPoint>,
                      blocked: Set<GridPoint>, random: LevelRandom) -> Result? {
        let z = level.generator.zones
        let spacing = Double(level.generator.minElementSpacing)
        var requests: [Request] = []
        for g in level.puzzle.gates.sorted(by: { $0.zone < $1.zone }) {
            for e in g.opensWith {
                for _ in 0..<max(0, e.count) {
                    requests.append(Request(type: e.type, required: false, zones: [g.zone - 1], requiresItem: e.requiresItem,
                                            itemPlacement: e.itemPlacement ?? level.puzzle.itemPlacement, gateZone: g.zone))
                }
            }
        }
        for e in level.puzzle.elements {
            let zones: [Int] = switch e.zone {
            case .any: Array(1...max(1, z))
            case .index(let i): [i]
            }
            for _ in 0..<max(0, e.count) {
                requests.append(Request(type: e.type, required: e.required, zones: zones, requiresItem: e.requiresItem,
                                        itemPlacement: e.itemPlacement ?? level.puzzle.itemPlacement, gateZone: nil))
            }
        }
        // Most constrained first: machines (2 × 2), then fixed zones, then "any". Stable otherwise.
        let order = requests.indices.sorted { i, j in
            let a = requests[i], b = requests[j]
            let ka = (a.type == .machine ? 0 : 1, a.zones.count), kb = (b.type == .machine ? 0 : 1, b.zones.count)
            return ka != kb ? ka < kb : i < j
        }

        var elements: [PlacedElement] = []
        var perType: [ElementType: Int] = [:]
        var perRoom: [Int: Int] = [:]
        for i in order {
            let r = requests[i]
            let candidates = rooms.filter { $0.id != startRoom && r.zones.contains($0.zone) }
            let shuffled = random.shuffled(candidates).enumerated()
                .sorted { a, b in
                    let ca = perRoom[a.element.id, default: 0], cb = perRoom[b.element.id, default: 0]
                    return ca != cb ? ca < cb : a.offset < b.offset
                }
                .map(\.element)
            var placed: PlacedElement?
            for room in shuffled {
                let n = r.type.footprint
                let cells = room.rect.cells.filter { anchor in
                    for dy in 0..<n {
                        for dx in 0..<n {
                            let c = GridPoint(anchor.x + dx, anchor.y + dy)
                            guard room.rect.contains(c), room.rect.ring(c) >= 1,
                                  !doorwayReserve.contains(c), !blocked.contains(c) else { return false }
                            if blocked.contains(where: { $0.chebyshev(c) <= 1 }) { return false }
                        }
                    }
                    let h = Double(n) / 2
                    let cx = Double(anchor.x) + h, cy = Double(anchor.y) + h
                    return elements.allSatisfy { hypot($0.center.x - cx, $0.center.y - cy) >= spacing }
                }
                guard let cell = random.pick(cells) else { continue }
                let k = perType[r.type, default: 0]
                perType[r.type] = k + 1
                placed = PlacedElement(id: "\(r.type.rawValue)_\(k)", type: r.type, cell: cell, roomId: room.id,
                                       zone: room.zone, required: r.required, requiresItem: r.requiresItem,
                                       gateId: r.gateZone.map { "gate_\($0)" },
                                       itemPlacement: r.type == .machine ? r.itemPlacement : nil)
                break
            }
            guard let e = placed else { return nil }
            elements.append(e)
            perRoom[e.roomId, default: 0] += 1
        }
        // Readable order: gate elements by gate, then exit elements, by id.
        elements.sort { a, b in
            let ga = a.gateId ?? "~", gb = b.gateId ?? "~"
            return ga != gb ? ga < gb : a.id < b.id
        }

        // Machine items.
        var items: [ItemPlacement] = []
        let footprints = elements.flatMap(\.cells)
        for m in elements where m.type == .machine {
            guard let itemId = m.requiresItem else { continue }
            let rule = m.itemPlacement ?? level.puzzle.itemPlacement
            var candidates: [LevelRoom]
            switch rule {
            case .sameZone: candidates = rooms.filter { $0.zone == m.zone && $0.id != m.roomId }
            case .earlierZone:
                candidates = m.zone > 1 ? rooms.filter { $0.zone < m.zone } : rooms.filter { $0.zone == m.zone && $0.id != m.roomId }
            }
            // Prefer rooms other than the start room and rooms without another item.
            let used = Set(items.map(\.roomId))
            let shuffled = random.shuffled(candidates).enumerated().sorted { a, b in
                func key(_ r: LevelRoom) -> Int { (r.id == startRoom ? 2 : 0) + (used.contains(r.id) ? 1 : 0) }
                return key(a.element) != key(b.element) ? key(a.element) < key(b.element) : a.offset < b.offset
            }.map(\.element)
            var placed: ItemPlacement?
            for room in shuffled {
                let taken = Set(items.map(\.cell))
                let cells = room.rect.cells.filter { c in
                    room.rect.ring(c) >= 1 && !doorwayReserve.contains(c) && !blocked.contains(c) && !taken.contains(c)
                        && footprints.allSatisfy { $0.chebyshev(c) >= itemElementClearance }
                }
                guard let cell = random.pick(cells) else { continue }
                placed = ItemPlacement(id: "item_\(items.count)", itemId: itemId, cell: cell, roomId: room.id,
                                       zone: room.zone, elementId: m.id)
                break
            }
            guard let item = placed else { return nil }
            items.append(item)
        }
        return Result(elements: elements, items: items)
    }
}
