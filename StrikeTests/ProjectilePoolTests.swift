import SpriteKit
import Testing
@testable import Strike

@MainActor
struct ProjectilePoolTests {
    @Test func twoHundredShotsNeverExceedCapacityAndReuseNodes() throws {
        let w = try TestData.starter()
        let pool = ProjectilePool(capacity: 64, bodyRadius: CGFloat(w.projectileRadius))
        let owned = Set(pool.allNodes.map(ObjectIdentifier.init))
        let parent = SKNode()
        let tex = Textures.texture(w.projectileTextureName, in: .items)
        var inFlight: [ProjectileNode] = []
        var seen = Set<ObjectIdentifier>()
        var refused = 0
        for _ in 0..<200 {
            if let p = pool.spawn(weapon: w, texture: tex, at: .zero, angle: 0, in: parent) {
                seen.insert(ObjectIdentifier(p))
                inFlight.append(p)
            } else {
                refused += 1
                // Pool full: oldest shot hits a wall.
                pool.recycle(inFlight.removeFirst())
            }
            #expect(pool.activeCount <= 64)
            #expect(parent.children.count == pool.activeCount)
        }
        #expect(refused > 0)
        #expect(seen.isSubset(of: owned))
        #expect(pool.allNodes.count == 64)
    }

    @Test func recycledNodeIsReused() throws {
        let w = try TestData.starter()
        let pool = ProjectilePool(capacity: 2, bodyRadius: CGFloat(w.projectileRadius))
        let parent = SKNode()
        let tex = Textures.texture(w.projectileTextureName, in: .items)
        let a = try #require(pool.spawn(weapon: w, texture: tex, at: .zero, angle: 0, in: parent))
        _ = pool.spawn(weapon: w, texture: tex, at: .zero, angle: 0, in: parent)
        #expect(pool.spawn(weapon: w, texture: tex, at: .zero, angle: 0, in: parent) == nil)
        pool.recycle(a)
        let c = pool.spawn(weapon: w, texture: tex, at: .zero, angle: 0, in: parent)
        #expect(c === a)
    }

    @Test func shotExpiresAtRange() throws {
        let w = try TestData.starter()
        let pool = ProjectilePool(capacity: 1, bodyRadius: CGFloat(w.projectileRadius))
        let p = try #require(pool.spawn(weapon: w, texture: Textures.texture(w.projectileTextureName, in: .items),
                                        at: .zero, angle: 0, in: SKNode()))
        let flight = w.range / w.projectileSpeed
        #expect(p.step(dt: flight * 0.9))
        #expect(!p.step(dt: flight * 0.2))
    }
}

@MainActor
struct TileCellTests {
    @Test func cellsMapToQuartersAndAreCached() {
        let n = Textures.tileRepeat
        let a = Textures.tileCell("tile_l1_floor_01", column: 1, row: 2)
        let b = Textures.tileCell("tile_l1_floor_01", column: 1 + n, row: 2 + n)
        #expect(a === b) // same sub-texture, cached
        let full = Textures.texture("tile_l1_floor_01", in: .tiles).size()
        #expect(abs(a.size().width - full.width / CGFloat(n)) < 0.5)
        #expect(abs(a.size().height - full.height / CGFloat(n)) < 0.5)
        #expect(Textures.tileCell("tile_l1_floor_01", column: 0, row: 0) !== a)
    }
}
