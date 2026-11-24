import SpriteKit

/// Gate or exit door across a corridor (ART_BIBLE §13.2): one 64 pt sprite per cell, one wall
/// body over all cells while closed, lights + "on / total" counter above it.
@MainActor
final class DoorNode: SKNode {
    let doorId: String
    let cells: [GridPoint]
    let orientation: DoorOrientation
    private(set) var isOpen = false
    private var sprites: [SKSpriteNode] = []
    private let info = SKNode()
    private let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private var lights: [SKShapeNode] = []
    private var halos: [SKSpriteNode] = []
    private var shownOn = -1
    /// A sealed door with no elements (the boss arena entrance) never shows "on / total".
    var hidesCounter = false {
        didSet { info.removeAllActions(); info.isHidden = hidesCounter }
    }

    enum Style {
        static let infoAbove: CGFloat = 40
        static let light: CGFloat = 10
        static let lightGap: CGFloat = 4
        static let maxLights = 6
        static let halo: CGFloat = 16
        static let pill = CGSize(width: 56, height: 22)
        static let labelAbove: CGFloat = 14
        static let fontSize: CGFloat = 16
        /// Counter shows within this many tiles of a closed door.
        static let showWithinTiles: CGFloat = 6
        static let frameSec = 0.07
        static let staggerSec = 0.04
    }

    init(id: String, cells: [GridPoint], orientation: DoorOrientation, grid: TileGrid, total: Int, maxLights: Int) {
        doorId = id
        self.cells = cells
        self.orientation = orientation
        super.init()
        name = "door_\(id)"
        let pts = cells.map { grid.world($0) }
        let cx = pts.map(\.x).reduce(0, +) / CGFloat(max(1, pts.count))
        let cy = pts.map(\.y).reduce(0, +) / CGFloat(max(1, pts.count))
        position = CGPoint(x: cx, y: cy)
        let t = TileGrid.tileSize
        for p in pts {
            let s = SKSpriteNode(texture: Textures.texture("puzzle_door_closed", in: .puzzle), size: CGSize(width: t, height: t))
            s.position = CGPoint(x: p.x - cx, y: p.y - cy)
            if orientation == .northSouth { s.zRotation = .pi / 2 }
            s.zPosition = InteractableNode.Z.object
            addChild(s)
            sprites.append(s)
        }
        let minX = pts.map(\.x).min()! - t / 2, maxX = pts.map(\.x).max()! + t / 2
        let minY = pts.map(\.y).min()! - t / 2, maxY = pts.map(\.y).max()! + t / 2
        let body = SKPhysicsBody(rectangleOf: CGSize(width: maxX - minX, height: maxY - minY),
                                 center: CGPoint(x: (minX + maxX) / 2 - cx, y: (minY + maxY) / 2 - cy))
        body.isDynamic = false
        body.categoryBitMask = PhysicsCategory.wall
        body.collisionBitMask = PhysicsCategory.none
        body.contactTestBitMask = PhysicsCategory.none
        body.friction = 0
        physicsBody = body

        // Lights + counter.
        info.position = CGPoint(x: 0, y: (maxY - minY) / 2 + Style.infoAbove - t / 2)
        info.zPosition = 31
        info.alpha = 0
        let lightCount = total <= min(maxLights, Style.maxLights) ? total : 0
        let rowW = CGFloat(lightCount) * Style.light + CGFloat(max(0, lightCount - 1)) * Style.lightGap
        for i in 0..<lightCount {
            let x = -rowW / 2 + Style.light / 2 + CGFloat(i) * (Style.light + Style.lightGap)
            let halo = Textures.glow(diameter: Style.halo, color: Palette.stateOn, alpha: 0.35)
            halo.position = CGPoint(x: x, y: 0)
            halo.isHidden = true
            info.addChild(halo)
            halos.append(halo)
            let c = SKShapeNode(circleOfRadius: Style.light / 2)
            c.position = CGPoint(x: x, y: 0)
            c.fillColor = Palette.stateOff
            c.strokeColor = Palette.outline
            c.lineWidth = 1.5
            info.addChild(c)
            lights.append(c)
        }
        let pill = SKShapeNode(rectOf: Style.pill, cornerRadius: Style.pill.height / 2)
        pill.fillColor = Palette.uiPanel.withAlphaComponent(0.85)
        pill.strokeColor = .clear
        pill.position = CGPoint(x: 0, y: lightCount > 0 ? Style.labelAbove + Style.light / 2 : 0)
        info.addChild(pill)
        label.fontSize = Style.fontSize
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.position = pill.position
        info.addChild(label)
        addChild(info)
        setProgress(on: 0, total: total, pop: false)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not supported") }

    func setProgress(on: Int, total: Int, pop: Bool) {
        guard on != shownOn else { return }
        shownOn = on
        label.text = "\(on) / \(total)"
        for (i, l) in lights.enumerated() {
            l.fillColor = i < on ? Palette.stateOn : Palette.stateOff
            halos[i].isHidden = i >= on
        }
        if pop {
            info.run(.sequence([.scale(to: 1.25, duration: 0.1), .scale(to: 1.0, duration: 0.1)]))
        }
    }

    /// Counter fades in near a closed door; after opening it shows at 50 % for 1 s, then fades.
    func updateInfo(heroDistance: CGFloat) {
        guard !isOpen else { return }
        if hidesCounter { return }
        let want: CGFloat = heroDistance <= Style.showWithinTiles * TileGrid.tileSize ? 1 : 0
        if abs(info.alpha - want) > 0.01, info.action(forKey: "fade") == nil {
            info.run(.fadeAlpha(to: want, duration: 0.2), withKey: "fade")
        }
    }

    func open(animated: Bool) {
        guard !isOpen else { return }
        isOpen = true
        physicsBody = nil
        info.removeAllActions()
        info.run(.sequence([.fadeAlpha(to: 0.5, duration: 0.1), .wait(forDuration: 1.0), .fadeOut(withDuration: 0.3)]))
        let frames = (1...4).map { Textures.texture(String(format: "puzzle_door_opening_%02d", $0), in: .puzzle) }
            + [Textures.texture("puzzle_door_open", in: .puzzle)]
        for (i, s) in sprites.enumerated() {
            s.zPosition = InteractableNode.Z.floorProp
            if animated {
                s.run(.sequence([
                    .wait(forDuration: Double(i) * Style.staggerSec),
                    .colorize(with: .white, colorBlendFactor: 0.6, duration: 0),
                    .colorize(withColorBlendFactor: 0, duration: 0.15),
                    .animate(with: frames, timePerFrame: Style.frameSec),
                ]))
            } else {
                s.texture = frames.last
            }
        }
    }
}
