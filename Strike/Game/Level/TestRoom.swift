import SpriteKit

/// M1 fixed test room: 20 × 14 tiles of 64 pt with a wall ring and two 2 × 2 pillars.
/// Layout constants are geometry, not balance; the M2 generator replaces this room.
@MainActor
enum TestRoom {
    static let tileSize: CGFloat = 64
    static let columns = 20
    static let rows = 14
    static let theme = "l1"

    /// Pillar blocks in tile coordinates (column, row, width, height).
    static let pillars: [(c: Int, r: Int, w: Int, h: Int)] = [(6, 4, 2, 2), (12, 8, 2, 2)]

    struct Layout {
        let node: SKNode
        let geometry: RoomGeometry
        let heroSpawn: CGPoint
        let enemySpawns: [CGPoint]
        var bounds: CGRect { geometry.bounds }
    }

    static func center(_ c: Int, _ r: Int) -> CGPoint {
        CGPoint(x: (CGFloat(c) + 0.5) * tileSize, y: (CGFloat(r) + 0.5) * tileSize)
    }

    static func isWall(_ c: Int, _ r: Int) -> Bool {
        if c == 0 || r == 0 || c == columns - 1 || r == rows - 1 { return true }
        return pillars.contains { c >= $0.c && c < $0.c + $0.w && r >= $0.r && r < $0.r + $0.h }
    }

    /// Side of a wall cell that faces a floor cell.
    enum Side: CaseIterable { case left, right, bottom, top }

    struct WallEdge: Equatable {
        let column: Int
        let row: Int
        let side: Side
    }

    /// Every wall-cell side that touches a floor cell (pure; used for the edge treatment).
    static func wallEdges() -> [WallEdge] {
        var out: [WallEdge] = []
        for r in 0..<rows {
            for c in 0..<columns where isWall(c, r) {
                for side in Side.allCases {
                    let (nc, nr): (Int, Int) = switch side {
                    case .left: (c - 1, r)
                    case .right: (c + 1, r)
                    case .bottom: (c, r - 1)
                    case .top: (c, r + 1)
                    }
                    guard nc >= 0, nr >= 0, nc < columns, nr < rows, !isWall(nc, nr) else { continue }
                    out.append(WallEdge(column: c, row: r, side: side))
                }
            }
        }
        return out
    }

    /// ART_BIBLE §4 code-side wall treatment (visual spec values).
    enum EdgeStyle {
        static let shadowWidth: CGFloat = 10
        static let shadowAlpha: CGFloat = 0.22
        static let outlineWidth: CGFloat = 3
        static let liftWidth: CGFloat = 4
    }

    /// Floor shadow strips, wall outlines and the wall-top lift as three filled shape nodes
    /// (one path each), so the treatment costs 3 static nodes per room.
    static func buildEdgeTreatment() -> SKNode {
        let t = tileSize
        let shadow = CGMutablePath(), outline = CGMutablePath(), lift = CGMutablePath()
        for e in wallEdges() {
            let x = CGFloat(e.column) * t, y = CGFloat(e.row) * t
            let sw = EdgeStyle.shadowWidth, ow = EdgeStyle.outlineWidth
            switch e.side {
            case .left:
                shadow.addRect(CGRect(x: x - sw, y: y, width: sw, height: t))
                outline.addRect(CGRect(x: x, y: y, width: ow, height: t))
            case .right:
                shadow.addRect(CGRect(x: x + t, y: y, width: sw, height: t))
                outline.addRect(CGRect(x: x + t - ow, y: y, width: ow, height: t))
            case .bottom:
                shadow.addRect(CGRect(x: x, y: y - sw, width: t, height: sw))
                outline.addRect(CGRect(x: x, y: y, width: t, height: ow))
                // Optional lift: wall-top colour along the top edge of walls with floor below.
                lift.addRect(CGRect(x: x, y: y + t - EdgeStyle.liftWidth, width: t, height: EdgeStyle.liftWidth))
            case .top:
                shadow.addRect(CGRect(x: x, y: y + t, width: t, height: sw))
                outline.addRect(CGRect(x: x, y: y + t - ow, width: t, height: ow))
            }
        }
        func shape(_ path: CGPath, _ color: SKColor, z: CGFloat, name: String) -> SKShapeNode {
            let n = SKShapeNode(path: path)
            n.fillColor = color
            n.strokeColor = .clear
            n.lineWidth = 0
            n.isAntialiased = false
            n.zPosition = z
            n.name = name
            return n
        }
        let root = SKNode()
        root.name = "wallEdges"
        // Shadow sits just above the floor (z 0) and below walls (z 1); outline and lift on top of walls.
        root.addChild(shape(shadow, Palette.outline.withAlphaComponent(EdgeStyle.shadowAlpha), z: 0.5, name: "floorShadow"))
        root.addChild(shape(lift, Palette.wallTop(theme: theme), z: 1.1, name: "wallLift"))
        root.addChild(shape(outline, Palette.outline, z: 1.2, name: "wallOutline"))
        return root
    }

    static func build() -> Layout {
        let t = tileSize
        let root = SKNode()
        root.name = "room"

        let floorLayer = SKNode()
        floorLayer.zPosition = 0
        let wallLayer = SKNode()
        wallLayer.zPosition = 1
        root.addChild(floorLayer)
        root.addChild(wallLayer)

        for r in 0..<rows {
            for c in 0..<columns {
                let wall = isWall(c, r)
                // Variant is picked per tileRepeat × tileRepeat block (not per cell) so the cells
                // of one texture line up; deterministic so the room looks the same every run.
                let bc = c / Textures.tileRepeat, br = r / Textures.tileRepeat
                let hash = (bc * 7 + br * 13 + bc * br) & 0xFFFF
                let name = wall
                    ? String(format: "tile_%@_wall_%02d", theme, hash % 2 + 1)
                    : String(format: "tile_%@_floor_%02d", theme, hash % 3 + 1)
                let sprite = SKSpriteNode(texture: Textures.tileCell(name, column: c, row: r), size: CGSize(width: t, height: t))
                sprite.position = center(c, r)
                (wall ? wallLayer : floorLayer).addChild(sprite)
            }
        }

        root.addChild(buildEdgeTreatment())

        let bounds = CGRect(x: 0, y: 0, width: CGFloat(columns) * t, height: CGFloat(rows) * t)
        let interior = bounds.insetBy(dx: t, dy: t)
        var solids = [
            CGRect(x: 0, y: 0, width: bounds.width, height: t),
            CGRect(x: 0, y: bounds.maxY - t, width: bounds.width, height: t),
            CGRect(x: 0, y: t, width: t, height: bounds.height - 2 * t),
            CGRect(x: bounds.maxX - t, y: t, width: t, height: bounds.height - 2 * t),
        ]
        for p in pillars {
            solids.append(CGRect(x: CGFloat(p.c) * t, y: CGFloat(p.r) * t, width: CGFloat(p.w) * t, height: CGFloat(p.h) * t))
        }
        for rect in solids {
            let body = SKNode()
            body.name = "wallBody"
            body.position = CGPoint(x: rect.midX, y: rect.midY)
            let pb = SKPhysicsBody(rectangleOf: rect.size)
            pb.isDynamic = false
            pb.categoryBitMask = PhysicsCategory.wall
            pb.collisionBitMask = PhysicsCategory.none
            pb.contactTestBitMask = PhysicsCategory.none
            pb.friction = 0
            pb.restitution = 0
            body.physicsBody = pb
            root.addChild(body)
        }

        return Layout(
            node: root,
            geometry: RoomGeometry(bounds: bounds, interior: interior, solids: solids),
            heroSpawn: center(4, 7),
            enemySpawns: [center(15, 3), center(16, 10), center(10, 11)]
        )
    }
}
