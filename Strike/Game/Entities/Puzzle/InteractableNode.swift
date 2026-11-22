import SpriteKit

/// How the focused interactable is drawn (ART_BIBLE §13.3).
enum FocusStyle: Equatable {
    case none
    /// Yellow pulsing ring and glow.
    case usable
    /// White ring at 50 %, no pulse (machine without item, plate already on).
    case unusable
}

/// Base for puzzle elements: sprite `puzzle_<type>_off/on`, focus ring + glow, on/off state.
/// Positioned at the element centre; the scene owns the puzzle logic (`PuzzleState`).
@MainActor
class InteractableNode: SKNode {
    let elementId: String
    let type: ElementType
    let sprite: SKSpriteNode
    /// Sprite edge (64 for 1-tile elements, 128 for the 2 × 2 machine).
    let spriteSize: CGFloat
    private(set) var isOn = false
    private(set) var focus: FocusStyle = .none

    private let ring = SKNode()
    private let ringStroke: SKShapeNode
    private let glow: SKSpriteNode

    /// ART_BIBLE §13 layers (relative z inside the world).
    enum Z {
        static let floorProp: CGFloat = 2
        static let object: CGFloat = 4
        static let ring: CGFloat = 3.5
    }
    /// ART_BIBLE §13.3 focus geometry.
    enum Focus {
        static let ringExtra: CGFloat = 12
        static let glowExtra: CGFloat = 28
        static let line: CGFloat = 3
        static let underlay: CGFloat = 6
        static let pulseSec = 0.9
        static let fadeSec = 0.12
        static let glowAlpha: CGFloat = 0.3
    }

    init(element: PlacedElement) {
        elementId = element.id
        type = element.type
        spriteSize = TileGrid.tileSize * CGFloat(element.type.footprint)
        sprite = SKSpriteNode(texture: Textures.texture(Self.textureName(element.type, on: false), in: .puzzle),
                              size: CGSize(width: spriteSize, height: spriteSize))
        let r = (spriteSize + Focus.ringExtra) / 2
        ringStroke = SKShapeNode(circleOfRadius: r)
        glow = Textures.glow(diameter: spriteSize + Focus.glowExtra, color: Palette.star, alpha: Focus.glowAlpha)
        super.init()
        name = "element_\(element.id)"
        position = element.position
        sprite.zPosition = element.type == .pressureplate ? Z.floorProp : Z.object
        addChild(sprite)

        let under = SKShapeNode(circleOfRadius: r)
        under.strokeColor = Palette.outline
        under.lineWidth = Focus.underlay
        under.fillColor = .clear
        ringStroke.strokeColor = Palette.star
        ringStroke.lineWidth = Focus.line
        ringStroke.fillColor = .clear
        ring.addChild(glow)
        ring.addChild(under)
        ring.addChild(ringStroke)
        ring.zPosition = Z.ring
        ring.alpha = 0
        ring.isHidden = true
        addChild(ring)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not supported") }

    static func textureName(_ type: ElementType, on: Bool) -> String { "puzzle_\(type.rawValue)_\(on ? "on" : "off")" }

    /// Distance from the element centre that still counts as "next to it" for INTERACT.
    var reachPadding: CGFloat { (spriteSize - TileGrid.tileSize) / 2 }

    /// INTERACT distance, comparable to `interactRadius`: the distance from `p` to the element's
    /// footprint square plus half a tile. For a 1-tile element this is roughly the centre distance;
    /// for the 2 × 2 machine a hero on any side-adjacent cell is in range (QA-009).
    func interactDistance(from p: CGPoint) -> CGFloat {
        let h = spriteSize / 2
        let dx = max(0, abs(p.x - position.x) - h), dy = max(0, abs(p.y - position.y) - h)
        return hypot(dx, dy) + TileGrid.tileSize / 2
    }

    func setFocus(_ style: FocusStyle) {
        guard style != focus else { return }
        focus = style
        ring.removeAllActions()
        ring.setScale(1)
        switch style {
        case .none:
            ring.run(.sequence([.fadeOut(withDuration: Focus.fadeSec), .hide()]))
        case .usable, .unusable:
            ring.isHidden = false
            let usable = style == .usable
            ringStroke.strokeColor = usable ? Palette.star : SKColor(white: 1, alpha: 0.5)
            glow.isHidden = !usable
            ring.run(.fadeIn(withDuration: Focus.fadeSec))
            if usable {
                let half = Focus.pulseSec / 2
                let up = SKAction.group([.scale(to: 1.05, duration: half), .fadeAlpha(to: 1.0, duration: half)])
                let down = SKAction.group([.scale(to: 0.95, duration: half), .fadeAlpha(to: 0.7, duration: half)])
                up.timingMode = .easeInEaseOut
                down.timingMode = .easeInEaseOut
                ring.run(.repeatForever(.sequence([up, down])), withKey: "pulse")
            }
        }
    }

    /// Swaps the sprite; `animated` adds the "on" pulse and particles.
    func setOn(_ on: Bool, animated: Bool) {
        guard on != isOn else { return }
        isOn = on
        sprite.texture = Textures.texture(Self.textureName(type, on: on), in: .puzzle)
        guard animated else { return }
        sprite.run(.sequence([.scale(to: 1.12, duration: 0.1), .scale(to: 1.0, duration: 0.1)]))
        if on, let parent { parent.addChild(Particles.stateOn(at: position)) }
    }
}
