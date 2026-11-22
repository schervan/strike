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
