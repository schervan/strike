import SwiftUI

nonisolated struct MinimapRect: Equatable, Sendable {
    let x: Int, y: Int, w: Int, h: Int
}

nonisolated struct MinimapDoor: Equatable, Sendable {
    let cells: [GridPoint]
    let open: Bool
}

nonisolated struct MinimapMark: Equatable, Sendable {
    /// Centre in cell units (continuous).
    let x: Double
    let y: Double
    let on: Bool
}

/// What the minimap draws (ART_BIBLE §13.1). Only revealed things are included. Pushed by the
/// scene at `rules.minimap.updateHz`.
nonisolated struct MinimapSnapshot: Equatable, Sendable {
    var gridWidth = 0
    var gridHeight = 0
    var rooms: [MinimapRect] = []
    var corridorCells: [GridPoint] = []
    var doors: [MinimapDoor] = []
    var elements: [MinimapMark] = []
    var checkpoints: [MinimapMark] = []
    /// Exit pad once its room is revealed; `on` = exit door open.
    var exit: MinimapMark?
    /// Hero centre in cell units.
    var heroX = 0.0
    var heroY = 0.0
}

/// SwiftUI `Canvas` minimap, top-right below the pause button (ART_BIBLE §13.1). Display only.
struct MinimapView: View {
    @Environment(GameModel.self) private var model

    enum Layout {
        static let size = CGSize(width: 160, height: 120)
        static let corner: CGFloat = 12
        static let inset: CGFloat = 6
        static let right: CGFloat = 16
        static let top: CGFloat = 96
        static let minCell: CGFloat = 2
        static let hero: CGFloat = 7
        static let element: CGFloat = 4
        static let checkpoint: CGFloat = 5
        static let exitStar: CGFloat = 8
        static let doorThickness: CGFloat = 3
        /// Hero pulse 1.0 → 1.3 → 1.0 over this period, redrawn every `pulseStep`.
        static let pulsePeriod = 1.0
        static let pulseStep = 0.1
        static let pulseScale = 0.3
    }

    private static func color(_ hex: UInt32, _ a: Double = 1) -> Color {
        Color(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
              blue: Double(hex & 0xFF) / 255, opacity: a)
    }

    var body: some View {
        let snap = model.minimap
        ZStack {
            RoundedRectangle(cornerRadius: Layout.corner)
                .fill(Self.color(0x1E1B3D, 0.8))
                .overlay(RoundedRectangle(cornerRadius: Layout.corner).stroke(Self.color(0x4A4585), lineWidth: 2))
            // The hero pulse needs a clock; 10 Hz redraws of a few rects are cheap and keep the
            // hero dot in the same coordinate space as the map (no SwiftUI position animation).
            TimelineView(.periodic(from: .now, by: Layout.pulseStep)) { timeline in
                Canvas { ctx, size in
                    draw(snap, in: &ctx, size: size)
                    drawHero(snap, in: &ctx, size: size, time: timeline.date.timeIntervalSinceReferenceDate)
                }
            }
            .padding(Layout.inset)
        }
        .frame(width: Layout.size.width, height: Layout.size.height)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("hud.minimap")
        .accessibilityLabel(Text("hud.minimap.accessibility"))
    }

    private func geometry(_ s: MinimapSnapshot, _ size: CGSize) -> (cell: CGFloat, origin: CGPoint) {
        guard s.gridWidth > 0, s.gridHeight > 0 else { return (Layout.minCell, .zero) }
        let raw = min(size.width / CGFloat(s.gridWidth), size.height / CGFloat(s.gridHeight))
        let cell = max(Layout.minCell, (raw * 2).rounded(.down) / 2)
        let w = cell * CGFloat(s.gridWidth), h = cell * CGFloat(s.gridHeight)
        return (cell, CGPoint(x: (size.width - w) / 2, y: (size.height - h) / 2))
    }

    /// Cell (x, y up) → canvas point (y down).
    private func point(_ x: Double, _ y: Double, _ s: MinimapSnapshot, _ g: (cell: CGFloat, origin: CGPoint)) -> CGPoint {
        CGPoint(x: g.origin.x + CGFloat(x) * g.cell, y: g.origin.y + (CGFloat(s.gridHeight) - CGFloat(y)) * g.cell)
    }

    private func draw(_ s: MinimapSnapshot, in ctx: inout GraphicsContext, size: CGSize) {
        let g = geometry(s, size)
        func rect(_ x: Int, _ y: Int, _ w: Int, _ h: Int) -> CGRect {
            let p = point(Double(x), Double(y + h), s, g)
            return CGRect(x: p.x, y: p.y, width: CGFloat(w) * g.cell, height: CGFloat(h) * g.cell)
        }
        var corridors = Path()
        for c in s.corridorCells { corridors.addRect(rect(c.x, c.y, 1, 1)) }
        ctx.fill(corridors, with: .color(Self.color(0x8FA3C8, 0.9)))
        var rooms = Path()
        for r in s.rooms { rooms.addRect(rect(r.x, r.y, r.w, r.h)) }
        ctx.fill(rooms, with: .color(Self.color(0xC9D2EA, 0.9)))
        ctx.stroke(rooms, with: .color(Self.color(0x4A4585)), lineWidth: 1)

        for d in s.doors where !d.cells.isEmpty {
            let xs = d.cells.map(\.x), ys = d.cells.map(\.y)
            let r = rect(xs.min()!, ys.min()!, xs.max()! - xs.min()! + 1, ys.max()! - ys.min()! + 1)
            let horizontalLine = ys.min() == ys.max()
            let bar = horizontalLine
                ? CGRect(x: r.minX, y: r.midY - Layout.doorThickness / 2, width: r.width, height: Layout.doorThickness)
                : CGRect(x: r.midX - Layout.doorThickness / 2, y: r.minY, width: Layout.doorThickness, height: r.height)
            if d.open {
                // Open: bar at 70 % with a 1-cell gap in the middle (colour-blind safety).
                var p = Path()
                if horizontalLine {
                    let gapL = bar.midX - g.cell / 2, gapR = bar.midX + g.cell / 2
                    p.addRect(CGRect(x: bar.minX, y: bar.minY, width: max(0, gapL - bar.minX), height: bar.height))
                    p.addRect(CGRect(x: gapR, y: bar.minY, width: max(0, bar.maxX - gapR), height: bar.height))
                } else {
                    let gapB = bar.midY - g.cell / 2, gapT = bar.midY + g.cell / 2
                    p.addRect(CGRect(x: bar.minX, y: bar.minY, width: bar.width, height: max(0, gapB - bar.minY)))
                    p.addRect(CGRect(x: bar.minX, y: gapT, width: bar.width, height: max(0, bar.maxY - gapT)))
                }
                ctx.fill(p, with: .color(Self.color(0x5FE08A, 0.7)))
            } else {
                ctx.fill(Path(bar), with: .color(Self.color(0xFF3B5C)))
            }
        }
        let outline = Self.color(0x2B2140)
        for e in s.elements {
            let c = point(e.x, e.y, s, g)
            let r = CGRect(x: c.x - Layout.element / 2, y: c.y - Layout.element / 2, width: Layout.element, height: Layout.element)
            ctx.fill(Path(ellipseIn: r), with: .color(Self.color(e.on ? 0x5FE08A : 0xFF3B5C)))
            ctx.stroke(Path(ellipseIn: r), with: .color(outline), lineWidth: 1)
            if e.on { ctx.fill(Path(ellipseIn: r.insetBy(dx: 1, dy: 1)), with: .color(.white)) }
        }
        for cp in s.checkpoints {
            let c = point(cp.x, cp.y, s, g)
            var d = Path()
            let h = Layout.checkpoint / 2 * 1.2
            d.move(to: CGPoint(x: c.x, y: c.y - h)); d.addLine(to: CGPoint(x: c.x + h, y: c.y))
            d.addLine(to: CGPoint(x: c.x, y: c.y + h)); d.addLine(to: CGPoint(x: c.x - h, y: c.y)); d.closeSubpath()
            ctx.fill(d, with: .color(Self.color(0x3DE3D0, cp.on ? 1 : 0.25)))
            ctx.stroke(d, with: .color(outline), lineWidth: 1)
        }
        if let e = s.exit {
            let c = point(e.x, e.y, s, g)
            var star = Path()
            for i in 0..<10 {
                let r = i.isMultiple(of: 2) ? Layout.exitStar / 2 : Layout.exitStar / 4.4
                let a = CGFloat(i) * .pi / 5 - .pi / 2
                let p = CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r)
                i == 0 ? star.move(to: p) : star.addLine(to: p)
            }
            star.closeSubpath()
            ctx.fill(star, with: .color(Self.color(0xFFD93D, e.on ? 1 : 0.7)))
            ctx.stroke(star, with: .color(outline), lineWidth: 1)
        }
    }

    private func drawHero(_ s: MinimapSnapshot, in ctx: inout GraphicsContext, size: CGSize, time: Double) {
        guard s.gridWidth > 0 else { return }
        let g = geometry(s, size)
        var p = point(s.heroX, s.heroY, s, g)
        p.x = min(max(p.x, 0), size.width)
        p.y = min(max(p.y, 0), size.height)
        let phase = (time / Layout.pulsePeriod).truncatingRemainder(dividingBy: 1)
        let scale = 1 + Layout.pulseScale * (0.5 - 0.5 * cos(phase * 2 * .pi))
        let d = Layout.hero * CGFloat(scale)
        let r = CGRect(x: p.x - d / 2, y: p.y - d / 2, width: d, height: d)
        ctx.fill(Path(ellipseIn: r), with: .color(Self.color(0x3D8BFF)))
        ctx.stroke(Path(ellipseIn: r), with: .color(.white), lineWidth: 1.5)
    }
}
