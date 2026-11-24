import SpriteKit

/// `GeneratedLevel` + theme → SpriteKit nodes. Floors and walls are one `SKTileMapNode` (themed
/// `tile_lN_*`, each texture spread over 4 × 4 cells as in M1), the M1 wall edge treatment is three
/// shape nodes, and all wall physics is one compound body of merged rectangles. Dynamic things
/// (hero, enemies, pickups) are spawned by `GameScene`.
@MainActor
enum LevelBuilder {
    struct Built {
        let root: SKNode
        let interactables: [String: InteractableNode]
        let gates: [String: DoorNode]
        let exitDoor: DoorNode
        let checkpoints: [String: CheckpointNode]
        let exitPad: ExitPadNode
        let crates: [CrateNode]
    }

    static func build(_ level: GeneratedLevel, def: LevelDef, data: GameData) -> Built {
        let theme = def.tilePrefix
        let grid = level.grid
        let root = SKNode()
        root.name = "level"

        let map = tileMap(grid: grid, theme: theme)
        map.zPosition = 0
        root.addChild(map)
        root.addChild(buildEdgeTreatment(grid: grid, theme: theme))
        root.addChild(wallBody(grid: grid))

        var interactables: [String: InteractableNode] = [:]
        for e in level.elements {
            let node: InteractableNode = switch e.type {
            case .button: ButtonNode(element: e)
            case .lever: LeverNode(element: e)
            case .pressureplate: PressurePlateNode(element: e)
            case .machine: MachineNode(element: e, requiresItem: e.requiresItem)
            }
            interactables[e.id] = node
            root.addChild(node)
        }

        let maxLights = data.rules.puzzle.doorMaxLights
        var gates: [String: DoorNode] = [:]
        for g in level.gates {
            let d = DoorNode(id: g.id, cells: g.cells, orientation: g.orientation, grid: grid,
                             total: g.elementIds.count, maxLights: maxLights)
            gates[g.id] = d
            root.addChild(d)
        }
        let exitDoor = DoorNode(id: "exit", cells: level.exitDoor.cells, orientation: level.exitDoor.orientation,
                                grid: grid, total: level.exitDoor.elementIds.count, maxLights: maxLights)
        root.addChild(exitDoor)

        var checkpoints: [String: CheckpointNode] = [:]
        for c in level.checkpoints {
            let n = CheckpointNode(checkpoint: c, grid: grid)
            checkpoints[c.id] = n
            root.addChild(n)
        }
        let exitPad = ExitPadNode(position: exitPadCenter(level))
        root.addChild(exitPad)

        let crates = level.crates.map { CrateNode(crate: $0, grid: grid, hp: data.rules.crate.hp) }
        crates.forEach(root.addChild)

        return Built(root: root, interactables: interactables, gates: gates, exitDoor: exitDoor,
                     checkpoints: checkpoints, exitPad: exitPad, crates: crates)
    }

    /// Centre of the niche's far row; same point as `GeneratedLevel.exitPadPosition` (QA-008).
    static func exitPadCenter(_ level: GeneratedLevel) -> CGPoint { level.exitPadPosition }

    // MARK: Tiles

    static func tileName(_ grid: TileGrid, theme: String, _ c: Int, _ r: Int) -> String {
        // Variant per tileRepeat × tileRepeat block (not per cell) so a texture's cells line up;
        // deterministic so a level looks the same on every load.
        let bc = c / Textures.tileRepeat, br = r / Textures.tileRepeat
        let hash = (bc * 7 + br * 13 + bc * br) & 0xFFFF
        return grid[c, r] == .wall
            ? String(format: "tile_%@_wall_%02d", theme, hash % 2 + 1)
            : String(format: "tile_%@_floor_%02d", theme, hash % 3 + 1)
    }

    static func tileMap(grid: TileGrid, theme: String) -> SKTileMapNode {
        let n = Textures.tileRepeat
        let t = TileGrid.tileSize
        var groups: [String: SKTileGroup] = [:]
        var names: [String] = []
        for v in 1...3 { names.append(String(format: "tile_%@_floor_%02d", theme, v)) }
        for v in 1...2 { names.append(String(format: "tile_%@_wall_%02d", theme, v)) }
        for name in names {
            for y in 0..<n {
                for x in 0..<n {
                    let def = SKTileDefinition(texture: Textures.tileCell(name, column: x, row: y), size: CGSize(width: t, height: t))
                    groups["\(name)#\(x)_\(y)"] = SKTileGroup(tileDefinition: def)
                }
            }
        }
        let set = SKTileSet(tileGroups: Array(groups.values))
        let map = SKTileMapNode(tileSet: set, columns: grid.width, rows: grid.height, tileSize: CGSize(width: t, height: t))
        map.anchorPoint = .zero
        map.position = .zero
        map.name = "tiles"
        for r in 0..<grid.height {
            for c in 0..<grid.width {
                let key = "\(tileName(grid, theme: theme, c, r))#\(((c % n) + n) % n)_\(((r % n) + n) % n)"
                map.setTileGroup(groups[key], forColumn: c, row: r)
            }
        }
        return map
    }

    // MARK: Wall edges (M1 treatment, ART_BIBLE §4 / §13.7)

    enum Side: CaseIterable { case left, right, bottom, top }

    struct WallEdge: Equatable {
        let column: Int
        let row: Int
        let side: Side
    }

    /// ART_BIBLE §4 code-side wall treatment (visual spec values).
    enum EdgeStyle {
        static let shadowWidth: CGFloat = 10
        static let shadowAlpha: CGFloat = 0.22
        static let outlineWidth: CGFloat = 3
        /// ART_BIBLE §4 item 3 rim lift: 3 pt strip inside the wall cell, flush against the outline
        /// (3–6 pt from the cell edge), only on sides that face floor.
        static let liftWidth: CGFloat = 3
        static let liftAlpha: CGFloat = 0.45
        static let liftAlphaL3: CGFloat = 0.30
    }

    /// Every wall-cell side that touches a floor cell.
    static func wallEdges(_ grid: TileGrid) -> [WallEdge] {
        var out: [WallEdge] = []
        for r in 0..<grid.height {
            for c in 0..<grid.width where grid[c, r] == .wall {
                for side in Side.allCases {
                    let (nc, nr): (Int, Int) = switch side {
                    case .left: (c - 1, r)
                    case .right: (c + 1, r)
                    case .bottom: (c, r - 1)
                    case .top: (c, r + 1)
                    }
                    if grid.isWalkable(GridPoint(nc, nr)) { out.append(WallEdge(column: c, row: r, side: side)) }
                }
            }
        }
        return out
    }

    /// Floor shadow strips, wall outlines and the wall-top lift as three filled shape nodes.
    static func buildEdgeTreatment(grid: TileGrid, theme: String) -> SKNode {
        let t = TileGrid.tileSize
        let shadow = CGMutablePath(), outline = CGMutablePath(), lift = CGMutablePath()
        let sw = EdgeStyle.shadowWidth, ow = EdgeStyle.outlineWidth
        for e in wallEdges(grid) {
            let x = CGFloat(e.column) * t, y = CGFloat(e.row) * t
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
            case .top:
                shadow.addRect(CGRect(x: x, y: y + t, width: t, height: sw))
                outline.addRect(CGRect(x: x, y: y + t - ow, width: t, height: ow))
            }
        }
        for r in rimLiftRects(grid) { lift.addRect(r) }
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
        root.addChild(shape(shadow, Palette.outline.withAlphaComponent(EdgeStyle.shadowAlpha), z: 0.5, name: "floorShadow"))
        let liftAlpha = theme == "l3" ? EdgeStyle.liftAlphaL3 : EdgeStyle.liftAlpha
        root.addChild(shape(lift, Palette.wallTop(theme: theme).withAlphaComponent(liftAlpha), z: 1.1, name: "wallLift"))
        root.addChild(shape(outline, Palette.outline, z: 1.2, name: "wallOutline"))
        return root
    }

    /// Rim-lift strips (world points), one per run of consecutive floor-facing sides: never on a
    /// side that touches another wall cell, so nothing is drawn inside thick walls.
    static func rimLiftRects(_ grid: TileGrid) -> [CGRect] {
        let t = TileGrid.tileSize
        let o = EdgeStyle.outlineWidth, w = EdgeStyle.liftWidth
        var out: [CGRect] = []
        let edges = Set(wallEdges(grid).map { "\($0.column),\($0.row),\($0.side)" })
        func has(_ c: Int, _ r: Int, _ side: Side) -> Bool { edges.contains("\(c),\(r),\(side)") }
        // Horizontal runs (bottom / top sides) along x; vertical runs (left / right) along y.
        for side in [Side.bottom, .top] {
            for r in 0..<grid.height {
                var c = 0
                while c < grid.width {
                    guard has(c, r, side) else { c += 1; continue }
                    let start = c
                    while c < grid.width, has(c, r, side) { c += 1 }
                    let x = CGFloat(start) * t, len = CGFloat(c - start) * t
                    let y = side == .bottom ? CGFloat(r) * t + o : CGFloat(r + 1) * t - o - w
                    out.append(CGRect(x: x, y: y, width: len, height: w))
                }
            }
        }
        for side in [Side.left, .right] {
            for c in 0..<grid.width {
                var r = 0
                while r < grid.height {
                    guard has(c, r, side) else { r += 1; continue }
                    let start = r
                    while r < grid.height, has(c, r, side) { r += 1 }
                    let y = CGFloat(start) * t, len = CGFloat(r - start) * t
                    let x = side == .left ? CGFloat(c) * t + o : CGFloat(c + 1) * t - o - w
                    out.append(CGRect(x: x, y: y, width: w, height: len))
                }
            }
        }
        return out
    }

    // MARK: Physics

    /// Wall cells merged greedily into rectangles (row runs, extended upwards while identical).
    static func wallRects(_ grid: TileGrid) -> [(x: Int, y: Int, w: Int, h: Int)] {
        var used = Array(repeating: false, count: grid.width * grid.height)
        var out: [(Int, Int, Int, Int)] = []
        for y in 0..<grid.height {
            var x = 0
            while x < grid.width {
                guard grid[x, y] == .wall, !used[y * grid.width + x] else { x += 1; continue }
                var w = 0
                while x + w < grid.width, grid[x + w, y] == .wall, !used[y * grid.width + x + w] { w += 1 }
                var h = 1
                grow: while y + h < grid.height {
                    for i in x..<(x + w) where grid[i, y + h] != .wall || used[(y + h) * grid.width + i] { break grow }
                    h += 1
                }
                for yy in y..<(y + h) { for xx in x..<(x + w) { used[yy * grid.width + xx] = true } }
                out.append((x, y, w, h))
                x += w
            }
        }
        return out
    }

    /// One static node with a compound body of all wall rectangles.
    static func wallBody(grid: TileGrid) -> SKNode {
        let t = TileGrid.tileSize
        let bodies = wallRects(grid).map { r in
            SKPhysicsBody(rectangleOf: CGSize(width: CGFloat(r.w) * t, height: CGFloat(r.h) * t),
                          center: CGPoint(x: (CGFloat(r.x) + CGFloat(r.w) / 2) * t, y: (CGFloat(r.y) + CGFloat(r.h) / 2) * t))
        }
        let node = SKNode()
        node.name = "wallBody"
        let body = SKPhysicsBody(bodies: bodies)
        body.isDynamic = false
        body.categoryBitMask = PhysicsCategory.wall
        body.collisionBitMask = PhysicsCategory.none
        body.contactTestBitMask = PhysicsCategory.none
        body.friction = 0
        body.restitution = 0
        node.physicsBody = body
        return node
    }
}
