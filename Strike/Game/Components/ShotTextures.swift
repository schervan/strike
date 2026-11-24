import SpriteKit
import UIKit

/// Code-drawn enemy shot looks (ART_BIBLE §15.16, QA-018: no glossy red discs). Rendered once and
/// cached; every shot has a 2 pt #2B2140 outline. Hit radii come from JSON and are unchanged.
@MainActor
enum ShotTextures {
    static let lilac = Palette.hex(0xD9C2FF)
    static let mint = Palette.hex(0xB8F5DC)
    static let sporeRim = Palette.hex(0x4A3A70)
    static let pink = Palette.hex(0xFF7AD9)
    static let pinkLight = Palette.hex(0xFFC2EF)
    static let paleYellow = Palette.hex(0xFFF3A0)

    private static func render(_ size: CGSize, _ draw: (CGContext) -> Void) -> SKTexture {
        let f = UIGraphicsImageRendererFormat()
        f.scale = 2
        let img = UIGraphicsImageRenderer(size: size, format: f).image { draw($0.cgContext) }
        return SKTexture(image: img)
    }

    private static func circle(_ c: CGContext, _ center: CGPoint, _ r: CGFloat, fill: UIColor, stroke: UIColor? = nil, width: CGFloat = 2) {
        let rect = CGRect(x: center.x - r, y: center.y - r, width: 2 * r, height: 2 * r)
        c.setFillColor(fill.cgColor)
        c.fillEllipse(in: rect)
        if let stroke {
            c.setStrokeColor(stroke.cgColor)
            c.setLineWidth(width)
            c.strokeEllipse(in: rect)
        }
    }

    /// Spore puff: 28 pt incl. fuzz; lilac body, mint inner disc, 12 alternating fuzz bumps over a
    /// dark-violet rim, white highlight top-left, matte.
    static let spore: SKTexture = render(CGSize(width: 32, height: 32)) { c in
        let o = CGPoint(x: 16, y: 16), outline = Palette.outline
        for i in 0..<12 {                               // outlines of the bumps first
            let a = CGFloat(i) / 12 * 2 * .pi
            circle(c, CGPoint(x: o.x + cos(a) * 10.5, y: o.y + sin(a) * 10.5), 4.5, fill: outline)
        }
        circle(c, o, 12, fill: outline)
        circle(c, o, 11, fill: sporeRim)
        for i in 0..<12 {
            let a = CGFloat(i) / 12 * 2 * .pi
            circle(c, CGPoint(x: o.x + cos(a) * 10.5, y: o.y + sin(a) * 10.5), 3.5, fill: i % 2 == 0 ? lilac : mint)
        }
        circle(c, o, 9.5, fill: lilac)
        circle(c, o, 5, fill: mint)
        circle(c, CGPoint(x: o.x - 4.5, y: o.y - 4.5), 3, fill: .white)
    }

    /// Boss firework rocket: 52 × 24 pt, pointing +x; cyan capsule, yellow nose and fins, porthole.
    static let rocket: SKTexture = render(CGSize(width: 52, height: 24)) { c in
        let outline = Palette.outline.cgColor
        // Fins (back, top and bottom).
        let fins = CGMutablePath()
        fins.move(to: CGPoint(x: 6, y: 12)); fins.addLine(to: CGPoint(x: 2, y: 2)); fins.addLine(to: CGPoint(x: 16, y: 8))
        fins.move(to: CGPoint(x: 6, y: 12)); fins.addLine(to: CGPoint(x: 2, y: 22)); fins.addLine(to: CGPoint(x: 16, y: 16))
        c.addPath(fins); c.setFillColor(Palette.star.cgColor); c.setStrokeColor(outline); c.setLineWidth(2)
        c.drawPath(using: .fillStroke)
        // Body capsule.
        let body = UIBezierPath(roundedRect: CGRect(x: 6, y: 5, width: 34, height: 14), cornerRadius: 7)
        c.addPath(body.cgPath); c.setFillColor(Palette.pixelCyan.cgColor); c.drawPath(using: .fillStroke)
        // Nose cone.
        let nose = CGMutablePath()
        nose.move(to: CGPoint(x: 36, y: 5)); nose.addQuadCurve(to: CGPoint(x: 50, y: 12), control: CGPoint(x: 47, y: 5))
        nose.addQuadCurve(to: CGPoint(x: 36, y: 19), control: CGPoint(x: 47, y: 19)); nose.closeSubpath()
        c.addPath(nose); c.setFillColor(Palette.star.cgColor); c.drawPath(using: .fillStroke)
        circle(c, CGPoint(x: 27, y: 12), 3, fill: Palette.pixelLight, stroke: Palette.outline, width: 1.5)
        c.setFillColor(UIColor.white.withAlphaComponent(0.8).cgColor)
        c.fill(CGRect(x: 12, y: 7, width: 12, height: 2))
    }

    /// Laser ball: 20 pt orb, pink ring, light-pink inside, white core.
    static let laser: SKTexture = render(CGSize(width: 24, height: 24)) { c in
        let o = CGPoint(x: 12, y: 12)
        circle(c, o, 10, fill: pink, stroke: Palette.outline)
        circle(c, o, 6.5, fill: pinkLight)
        circle(c, o, 3, fill: .white)
    }

    /// Trail emitter (spore mint puffs, laser pink sparkles); `targetNode` is set by the shot.
    static func trail(color: SKColor, size: CGFloat, star: Bool) -> SKEmitterNode {
        let e = SKEmitterNode()
        e.particleTexture = star ? Textures.particleStar : Textures.particleDot
        e.particleBirthRate = 10
        e.particleLifetime = 0.3
        e.particleScale = size / max(1, (e.particleTexture?.size().width ?? 8))
        e.particleScaleSpeed = -e.particleScale / 0.3
        e.particleAlpha = 0.5
        e.particleAlphaSpeed = -1.6
        e.particleColor = color
        e.particleColorBlendFactor = 1
        e.particleBlendMode = star ? .add : .alpha
        e.particlePositionRange = CGVector(dx: 4, dy: 4)
        e.zPosition = -1
        return e
    }
}
