import CoreGraphics

/// QA-015 (ART_BIBLE §7 right column): when the focused interactable sits under a right-column HUD
/// button, the camera shifts it out (max `maxShift`, eased by the camera smoothing). Pure; all
/// rects are relative to the camera centre in scene points.
nonisolated enum HUDAvoidance {
    static let maxShift: CGFloat = 120
    /// ART_BIBLE §7 right column: SWAP (bottom 340), RELOAD (252), INTERACT (164, 88 pt glow);
    /// 72 pt buttons, 24 pt from the right edge, plus a small margin.
    static let buttonBottoms: [CGFloat] = [340, 252, 164]
    static let button: CGFloat = 88
    static let right: CGFloat = 16
    static let margin: CGFloat = 8

    static func rightColumn(visibleSize v: CGSize) -> [CGRect] {
        buttonBottoms.map { b in
            CGRect(x: v.width / 2 - right - button - margin, y: -v.height / 2 + b - margin,
                   width: button + 2 * margin, height: button + 2 * margin)
        }
    }

    /// Camera offset that moves `object` out of every button rect: left (camera +x) if that fits in
    /// `maxShift`, else up (camera −y). Zero when nothing overlaps.
    static func nudge(object: CGRect, buttons: [CGRect], maxShift: CGFloat) -> CGVector {
        let hits = buttons.filter { $0.intersects(object) }
        guard !hits.isEmpty else { return .zero }
        let union = hits.dropFirst().reduce(hits[0]) { $0.union($1) }
        let dx = object.maxX - union.minX            // move the object left by this much
        if dx <= maxShift { return CGVector(dx: dx, dy: 0) }
        let dy = union.maxY - object.minY            // or up above the column
        return CGVector(dx: 0, dy: -min(maxShift, dy))
    }
}
