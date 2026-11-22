import SpriteKit

/// Smoothed follow camera with aim look-ahead (`hero.json → camera`), clamped to room bounds.
@MainActor
final class CameraController {
    let camera: SKCameraNode
    let def: CameraDef
    var bounds: CGRect

    init(camera: SKCameraNode, def: CameraDef, bounds: CGRect) {
        self.camera = camera
        self.def = def
        self.bounds = bounds
    }

    /// Camera position for `target`, clamped so the visible rect stays inside `bounds`
    /// (centred when the room is smaller than the view).
    func clamped(_ p: CGPoint, visibleSize: CGSize) -> CGPoint {
        let hw = visibleSize.width / 2, hh = visibleSize.height / 2
        let x = bounds.width <= visibleSize.width ? bounds.midX : min(max(p.x, bounds.minX + hw), bounds.maxX - hw)
        let y = bounds.height <= visibleSize.height ? bounds.midY : min(max(p.y, bounds.minY + hh), bounds.maxY - hh)
        return CGPoint(x: x, y: y)
    }

    func snap(to target: CGPoint, visibleSize: CGSize) {
        camera.position = clamped(target, visibleSize: visibleSize)
    }

    /// `aim` is a unit vector (or nil when not aiming).
    func update(dt: Double, target: CGPoint, aim: CGVector?, visibleSize: CGSize) {
        var goal = target
        if let a = aim {
            goal.x += a.dx * CGFloat(def.lookAhead)
            goal.y += a.dy * CGFloat(def.lookAhead)
        }
        goal = clamped(goal, visibleSize: visibleSize)
        let k = def.smoothingSec > 0 ? CGFloat(1 - exp(-dt / def.smoothingSec)) : 1
        let p = camera.position
        camera.position = clamped(CGPoint(x: p.x + (goal.x - p.x) * k, y: p.y + (goal.y - p.y) * k),
                                  visibleSize: visibleSize)
    }
}
