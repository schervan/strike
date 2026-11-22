import SpriteKit
import Testing
@testable import Strike

@MainActor
struct CameraControllerTests {
    let visible = CGSize(width: 1194, height: 823)
    let room = CGRect(x: 0, y: 0, width: 1280, height: 896)

    func controller() throws -> CameraController {
        let d = try TestData.load()
        return CameraController(camera: SKCameraNode(), def: d.camera, bounds: room,
                                hudBand: CGFloat(d.controls.hudBandHeight))
    }

    /// QA-005: anywhere in the room interior the hero is drawn below the HUD band.
    @Test func heroNeverUnderHUDBand() throws {
        let cam = try controller()
        let band = visible.height * cam.hudBand
        for x in stride(from: 64 + 18, through: room.maxX - 64 - 18, by: 32) {
            for y in stride(from: 64 + 18, through: room.maxY - 64 - 18, by: 32) {
                let hero = CGPoint(x: x, y: y)
                cam.snap(to: hero, visibleSize: visible)
                let screenTop = cam.camera.position.y + visible.height / 2
                // Hero sprite reaches about 64 pt above its feet / 46 pt above its centre.
                #expect(screenTop - (hero.y + 46) >= band, "hero at \(hero) under HUD")
            }
        }
    }

    @Test func staysInsideRoomSidesAndBottom() throws {
        let cam = try controller()
        cam.snap(to: CGPoint(x: -500, y: -500), visibleSize: visible)
        #expect(cam.camera.position.x - visible.width / 2 >= room.minX - 0.001)
        #expect(cam.camera.position.y - visible.height / 2 >= room.minY - 0.001)
        cam.snap(to: CGPoint(x: 5000, y: 5000), visibleSize: visible)
        #expect(cam.camera.position.x + visible.width / 2 <= room.maxX + 0.001)
        #expect(cam.camera.position.y + visible.height / 2 <= room.maxY + visible.height * cam.hudBand + 0.001)
    }
}

@MainActor
struct WallEdgeTests {
    /// The M1 test room as a grid: 20 × 14, wall ring, two 2 × 2 pillars.
    static func room() -> TileGrid {
        var g = TileGrid(width: 20, height: 14)
        for y in 1..<13 { for x in 1..<19 { g[x, y] = .floor } }
        for (c, r) in [(6, 4), (12, 8)] { for y in r..<(r + 2) { for x in c..<(c + 2) { g[x, y] = .wall } } }
        return g
    }

    @Test func edgesOnlyBetweenWallAndFloor() {
        let g = Self.room()
        let edges = LevelBuilder.wallEdges(g)
        // Border ring: interior is 18 × 12 → 2·18 + 2·12 floor-facing sides. Pillars: 8 sides each.
        #expect(edges.count == 2 * 18 + 2 * 12 + 2 * 8)
        for e in edges { #expect(g[e.column, e.row] == .wall) }
    }

    @Test func treatmentIsThreeNodes() {
        let edges = LevelBuilder.buildEdgeTreatment(grid: Self.room(), theme: "l1")
        #expect(edges.children.count == 3)
        #expect(edges.childNode(withName: "floorShadow") is SKShapeNode)
        #expect(edges.childNode(withName: "wallOutline") is SKShapeNode)
    }

    @Test func mergedWallRectsCoverEveryWallCellOnce() {
        let def = GeneratedCorpus.def("l4")
        let l = LevelGenerator.generate(def, seed: 3, catalog: GeneratedCorpus.catalog)
        var covered = Array(repeating: 0, count: l.grid.width * l.grid.height)
        let rects = LevelBuilder.wallRects(l.grid)
        for r in rects { for y in r.y..<(r.y + r.h) { for x in r.x..<(r.x + r.w) { covered[y * l.grid.width + x] += 1 } } }
        for (i, t) in l.grid.tiles.enumerated() { #expect(covered[i] == (t == .wall ? 1 : 0)) }
        #expect(rects.count < l.grid.tiles.count / 8)
    }
}
