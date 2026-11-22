import SpriteKit

/// Supply crate: solid, takes hero shots (`rules.json → crate.hp`), breaks and drops its loot
/// table (`levels.json → pickups.crates.lootTableId`).
@MainActor
final class CrateNode: SKSpriteNode {
    let crateId: String
    let lootTableId: String
    private(set) var health: Health
    var isBroken: Bool { health.isDepleted }

    init(crate: CratePlacement, grid: TileGrid, hp: Int) {
        crateId = crate.id
        lootTableId = crate.lootTableId
        health = Health(max: hp)
        let t = TileGrid.tileSize
        let tex = Textures.texture("puzzle_crate_whole", in: .puzzle)
        super.init(texture: tex, color: .white, size: CGSize(width: t, height: t))
        name = "crate_\(crate.id)"
        position = grid.world(crate.cell)
        zPosition = InteractableNode.Z.object
        let body = SKPhysicsBody(rectangleOf: CGSize(width: t * 0.8, height: t * 0.8))
        body.isDynamic = false
        body.categoryBitMask = PhysicsCategory.crate
        body.collisionBitMask = PhysicsCategory.none
        body.contactTestBitMask = PhysicsCategory.none
        physicsBody = body
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// Returns true when this hit broke the crate.
    func hit(damage: Int) -> Bool {
        guard !isBroken else { return false }
        let r = health.applyDamage(damage)
        run(.sequence([.colorize(with: .white, colorBlendFactor: 0.6, duration: 0), .colorize(withColorBlendFactor: 0, duration: 0.1)]))
        guard r == .depleted else {
            run(.sequence([.moveBy(x: 3, y: 0, duration: 0.03), .moveBy(x: -3, y: 0, duration: 0.03)]))
            return false
        }
        physicsBody = nil
        texture = Textures.texture("puzzle_crate_broken", in: .puzzle)
        zPosition = InteractableNode.Z.floorProp
        run(.sequence([.wait(forDuration: 1.2), .fadeOut(withDuration: 0.4), .removeFromParent()]))
        return true
    }
}
