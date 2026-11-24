import SpriteKit
import UIKit

/// Tracks up to two touches (left zone = move, right zone = aim/auto-fire, GDD §3.2) and draws
/// floating sticks on `layer` (the camera node). Stick math is in `StickInput`.
@MainActor
final class TwinStickController {
    let controls: ControlsDef
    private weak var layer: SKNode?
    private var moveTouch: UITouch?
    private var aimTouch: UITouch?
    private(set) var move: StickInput?
    private(set) var aim: StickInput?
    private let moveVisual: StickNode
    private let aimVisual: StickNode

    /// Visual sizes (ART_BIBLE §7): base 140 pt is drawn at `stickRadius`, knob 64 pt.
    static let knobRadius: CGFloat = 32
    static let idleAlpha: CGFloat = 0.7

    init(controls: ControlsDef, layer: SKNode) {
        self.controls = controls
        self.layer = layer
        moveVisual = StickNode(radius: CGFloat(controls.stickRadius), knobRadius: Self.knobRadius)
        aimVisual = StickNode(radius: CGFloat(controls.stickRadius), knobRadius: Self.knobRadius)
        moveVisual.name = "moveStick"
        aimVisual.name = "aimStick"
        layer.addChild(moveVisual)
        layer.addChild(aimVisual)
    }

    /// Aim stick held beyond its dead zone.
    var fireHeld: Bool { aim?.isActive ?? false }

    enum Zone { case move, aim, none }

    /// Zone of a point in view coordinates (UIKit, origin top-left).
    func zone(of p: CGPoint, viewSize: CGSize) -> Zone {
        guard viewSize.width > 0, viewSize.height > 0 else { return .none }
        let fx = p.x / viewSize.width, fy = p.y / viewSize.height
        if fy < controls.hudBandHeight { return .none }
        if fx < controls.moveZoneWidth { return .move }
        if fx > 1 - controls.aimZoneWidth { return .aim }
        return .none
    }

    func touchesBegan(_ touches: Set<UITouch>, view: UIView) {
        guard let layer else { return }
        for t in touches {
            begin(t, viewPoint: t.location(in: view), layerPoint: t.location(in: layer), viewSize: view.bounds.size)
        }
    }

    /// Starts a stick for `touch` at a given start point (a held-back Pixel-tap candidate starts
    /// from where it first touched down, GDD §13).
    func begin(_ t: UITouch, viewPoint: CGPoint, layerPoint p: CGPoint, viewSize: CGSize) {
        switch zone(of: viewPoint, viewSize: viewSize) {
        case .move where moveTouch == nil:
            moveTouch = t
            move = makeStick(at: p, deadZone: controls.moveDeadZone)
            moveVisual.show(move!, fadeSec: controls.fadeSec)
        case .aim where aimTouch == nil:
            aimTouch = t
            aim = makeStick(at: p, deadZone: controls.aimDeadZone)
            aimVisual.show(aim!, fadeSec: controls.fadeSec)
        default:
            break
        }
    }

    func touchesMoved(_ touches: Set<UITouch>) {
        guard let layer else { return }
        for t in touches {
            if t === moveTouch, var s = move {
                s.move(touch: t.location(in: layer), followFactor: CGFloat(controls.followFactor))
                move = s
                moveVisual.update(s)
            } else if t === aimTouch, var s = aim {
                s.move(touch: t.location(in: layer), followFactor: CGFloat(controls.followFactor))
                aim = s
                aimVisual.update(s)
            }
        }
    }

    func touchesEnded(_ touches: Set<UITouch>) {
        for t in touches {
            if t === moveTouch {
                moveTouch = nil
                move = nil
                moveVisual.hide(fadeSec: controls.fadeSec)
            } else if t === aimTouch {
                aimTouch = nil
                aim = nil
                aimVisual.hide(fadeSec: controls.fadeSec)
            }
        }
    }

    func reset() {
        moveTouch = nil; aimTouch = nil; move = nil; aim = nil
        moveVisual.hide(fadeSec: 0)
        aimVisual.hide(fadeSec: 0)
    }

    private func makeStick(at p: CGPoint, deadZone: Double) -> StickInput {
        StickInput(origin: p, touch: p, radius: CGFloat(controls.stickRadius),
                   deadZone: CGFloat(deadZone), fullAt: CGFloat(controls.fullMagnitudeAt))
    }

    /// Code-drawn floating stick (base ring + knob).
    final class StickNode: SKNode {
        private let base: SKShapeNode
        private let knob: SKShapeNode

        init(radius: CGFloat, knobRadius: CGFloat) {
            base = SKShapeNode(circleOfRadius: radius)
            base.fillColor = Palette.uiPanel.withAlphaComponent(0.45)
            base.strokeColor = SKColor(white: 1, alpha: 0.8)
            base.lineWidth = 3
            knob = SKShapeNode(circleOfRadius: knobRadius)
            knob.fillColor = SKColor(white: 1, alpha: 0.85)
            knob.strokeColor = Palette.outline
            knob.lineWidth = 3
            super.init()
            zPosition = 100
            alpha = 0
            addChild(base)
            addChild(knob)
        }

        @available(*, unavailable)
        required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not supported") }

        func show(_ s: StickInput, fadeSec: Double) {
            removeAllActions()
            update(s)
            run(.fadeAlpha(to: TwinStickController.idleAlpha, duration: fadeSec / 2))
        }

        func update(_ s: StickInput) {
            position = s.origin
            knob.position = CGPoint(x: s.knob.x - s.origin.x, y: s.knob.y - s.origin.y)
        }

        func hide(fadeSec: Double) {
            removeAllActions()
            if fadeSec <= 0 { alpha = 0 } else { run(.fadeOut(withDuration: fadeSec)) }
        }
    }
}
