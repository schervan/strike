import SpriteKit

/// Pressure plate: latches after the hero stands on it for `plateHoldSec`. Draws the hold ring
/// (ART_BIBLE §13.4).
@MainActor
final class PressurePlateNode: InteractableNode {
    enum Ring {
        static let radius: CGFloat = 26
        static let width: CGFloat = 6
        static let idleWidth: CGFloat = 2
        static let lowFraction = 0.25
    }

    private let track = SKShapeNode(circleOfRadius: Ring.radius)
    private let arc = SKShapeNode()
    private let idle = SKShapeNode(circleOfRadius: Ring.radius)
    private var shownProgress = -1.0

    override init(element: PlacedElement) {
        super.init(element: element)
        track.strokeColor = Palette.outline.withAlphaComponent(0.35)
        track.lineWidth = Ring.width
        track.fillColor = .clear
        track.zPosition = 2.6
        track.alpha = 0
        arc.strokeColor = Palette.star
        arc.lineWidth = Ring.width
        arc.lineCap = .round
        arc.fillColor = .clear
        arc.zPosition = 2.7
        let dashed = CGPath(ellipseIn: CGRect(x: -Ring.radius, y: -Ring.radius, width: 2 * Ring.radius, height: 2 * Ring.radius),
                            transform: nil).copy(dashingWithPhase: 0, lengths: [6, 5])
        idle.path = dashed
        idle.strokeColor = SKColor(white: 1, alpha: 0.3)
        idle.lineWidth = Ring.idleWidth
        idle.fillColor = .clear
        idle.zPosition = 2.5
        addChild(track)
        addChild(arc)
        addChild(idle)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// `progress` 0…1 of the hold timer; `held` while the hero stands on it.
    func setProgress(_ progress: Double, held: Bool) {
        let p = isOn ? 1 : max(0, min(1, progress))
        let q = (p * 40).rounded() / 40
        guard q != shownProgress else { return }
        shownProgress = q
        idle.isHidden = isOn || q > 0
        track.alpha = q > 0 && !isOn ? 1 : 0
        if q <= 0 || isOn {
            arc.path = nil
            return
        }
        let start = CGFloat.pi / 2
        let path = CGMutablePath()
        path.addArc(center: .zero, radius: Ring.radius, startAngle: start, endAngle: start - CGFloat(q) * 2 * .pi, clockwise: true)
        arc.path = path
        arc.strokeColor = !held && q < Ring.lowFraction ? Palette.stateOff : Palette.star
    }

    override func setOn(_ on: Bool, animated: Bool) {
        super.setOn(on, animated: animated)
        setProgress(on ? 1 : 0, held: false)
    }
}
