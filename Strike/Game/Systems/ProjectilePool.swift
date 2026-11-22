import SpriteKit

/// Fixed-size pool of hero projectiles. All nodes are created in `init`; `spawn` returns nil
/// when every node is in flight.
@MainActor
final class ProjectilePool {
    let capacity: Int
    private let nodes: [ProjectileNode]
    private var free: [ProjectileNode]

    init(capacity: Int, bodyRadius: CGFloat) {
        self.capacity = capacity
        nodes = (0..<capacity).map { _ in ProjectileNode(bodyRadius: bodyRadius) }
        free = nodes.reversed()
        free.reserveCapacity(capacity)
    }

    var activeCount: Int { capacity - free.count }

    /// Every node owned by the pool (for tests / iteration).
    var allNodes: [ProjectileNode] { nodes }

    func spawn(weapon: WeaponDef, texture: SKTexture, at point: CGPoint, angle: CGFloat, in parent: SKNode) -> ProjectileNode? {
        guard let node = free.popLast() else { return nil }
        node.activate(weapon: weapon, texture: texture, at: point, angle: angle)
        parent.addChild(node)
        return node
    }

    func recycle(_ node: ProjectileNode) {
        guard node.isActive else { return }
        node.deactivate()
        free.append(node)
    }

    func forEachActive(_ body: (ProjectileNode) -> Void) {
        for n in nodes where n.isActive { body(n) }
    }

    func recycleAll() {
        for n in nodes where n.isActive { recycle(n) }
    }
}
