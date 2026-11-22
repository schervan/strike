import SpriteKit

/// Smoothed follow camera with aim look-ahead (`hero.json → camera`), clamped to room bounds.
/// The top `hudBand` fraction of the screen is covered by the HUD (`controls.hudBandHeight`):
/// the camera frames the hero in the area below it and may scroll past the room top by that
/// band, so the top wall row is never hidden under the HUD (QA-005).
@MainActor
final class CameraController {
    let camera: SKCameraNode
    let def: CameraDef
    var bounds: CGRect
    /// Fraction of the visible height covered by the HUD at the top.
    let hudBand: CGFloat

    init(camera: SKCameraNode, def: CameraDef, bounds: CGRect, hudBand: CGFloat = 0) {
        self.camera = camera
        self.def = def
        self.bounds = bounds
        self.hudBand = max(0, min(0.5, hudBand))
    }

    /// Room rect extended upward by the HUD band (that strip may show background).
    func framedBounds(visibleSize: CGSize) -> CGRect {
        let band = visibleSize.height * hudBand
        return CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: bounds.height + band)
    }

    /// Camera position for `p`, clamped so the visible rect stays inside the framed bounds
    /// (centred when the room is smaller than the view).
    func clamped(_ p: CGPoint, visibleSize: CGSize) -> CGPoint {
        let b = framedBounds(visibleSize: visibleSize)
        let hw = visibleSize.width / 2, hh = visibleSize.height / 2
        let x = b.width <= visibleSize.width ? b.midX : min(max(p.x, b.minX + hw), b.maxX - hw)
        let y = b.height <= visibleSize.height ? b.midY : min(max(p.y, b.minY + hh), b.maxY - hh)
        return CGPoint(x: x, y: y)
    }

    /// Camera centre that puts `target` in the middle of the HUD-free area.
    func framing(_ target: CGPoint, visibleSize: CGSize) -> CGPoint {
        CGPoint(x: target.x, y: target.y + visibleSize.height * hudBand / 2)
    }

    func snap(to target: CGPoint, visibleSize: CGSize) {
        camera.position = clamped(framing(target, visibleSize: visibleSize), visibleSize: visibleSize)
    }

    /// `aim` is a unit vector (or nil when not aiming).
    func update(dt: Double, target: CGPoint, aim: CGVector?, visibleSize: CGSize) {
        var goal = framing(target, visibleSize: visibleSize)
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
