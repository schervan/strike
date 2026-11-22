import SpriteKit
import Testing
@testable import Strike

/// M2-7 re-verification of QA-007 (machine focus range) and QA-008 (exit pad offset / trigger).
@MainActor
struct FixVerificationTests {
    static func scene(_ id: String, _ seed: UInt64) throws -> GameScene {
        let data = try TestData.load()
        let s = GameScene(data: data, level: try #require(data.levels[id]), seed: seed)
        let v = SKView(frame: CGRect(origin: .zero, size: GameScene.logicalSize))
        v.presentScene(s)
        s.hero.health.reset(invulnerableFor: 1_000_000)
        return s
    }

    /// QA-007: standing in ANY floor cell orthogonally next to a machine (cell centre, no nudging) focuses it.
    @Test(arguments: [("l2", UInt64(11)), ("l4", UInt64(77)), ("l5", UInt64(5))])
    func machineFocusFromEverySide(levelId: String, seed: UInt64) throws {
        let s = try Self.scene(levelId, seed)
        let machines = s.level.elements.filter { $0.type == .machine }
        #expect(!machines.isEmpty)
        var checked = 0
        for m in machines {
            let own = Set(m.cells)
            var sides = Set<GridPoint>()
            for c in m.cells { for n in c.neighbors4 where !own.contains(n) && s.solidGrid.isWalkable(n) { sides.insert(n) } }
            for cell in sides {
                s.hero.position = s.level.grid.world(cell)
                s.step(dt: 0.05)
                #expect(s.focusedId == m.id, "\(levelId) \(m.id): no focus standing at \(cell) (machine cells \(m.cells))")
                checked += 1
            }
        }
        print("FIX machine focus \(levelId): \(checked) side cells checked")
        #expect(checked >= 4)
    }

    /// QA-008: with everything on, standing on the logical exitPad cell OR on the drawn pad finishes the level.
    @Test(arguments: ["l1", "l2", "l3", "l4", "l5"])
    func exitPadTriggersFromLogicalCellAndDrawnPad(levelId: String) throws {
        for seed: UInt64 in [11, 222, 3333] {
            for useDrawn in [false, true] {
                let s = try Self.scene(levelId, seed)
                s.handle(.debugSolveAll)
                let pos = useDrawn ? s.built.exitPad.position : s.level.grid.world(s.level.exitPad)
                s.hero.position = pos
                for _ in 0..<40 { s.step(dt: 0.05) }
                let off = hypot(s.level.grid.world(s.level.exitPad).x - s.built.exitPad.position.x,
                                s.level.grid.world(s.level.exitPad).y - s.built.exitPad.position.y)
                #expect(s.isComplete, "\(levelId) seed \(seed) \(useDrawn ? "drawn pad" : "logical cell") (offset \(off) pt) did not complete")
                if seed == 11, !useDrawn { print("FIX exit \(levelId): logical-vs-drawn pad offset \(Int(off)) pt, logical cell completes=\(s.isComplete)") }
            }
        }
    }
}
