import SpriteKit

/// Cached atlas lookups. Textures are always requested by plain name (no `@2x.png`, QA-001).
@MainActor
enum Textures {
    enum Atlas: String {
        case hero, enemies, boss, items, tiles, ui, fx, pixel, puzzle
    }

    private static var atlases: [Atlas: SKTextureAtlas] = [:]
    private static var cache: [String: SKTexture] = [:]
    private static var tileCells: [String: [SKTexture]] = [:]

    /// One tile texture covers `tileRepeat` × `tileRepeat` cells (ART_BIBLE §4 TILE_REPEAT).
    static let tileRepeat = 4

    /// Sub-texture of tile `name` for grid cell (column, row): cell (c, r) shows the
    /// (c mod N, r mod N) part of the texture, so neighbouring cells join seamlessly.
    /// The N × N sub-textures per tile are created once and cached.
    static func tileCell(_ name: String, column: Int, row: Int) -> SKTexture {
        let n = tileRepeat
        let cells: [SKTexture]
        if let cached = tileCells[name] {
            cells = cached
        } else {
            let full = texture(name, in: .tiles)
            // For atlas textures, SKTexture(rect:in:) reads `rect` in the unit space of the whole
            // atlas sheet, so offset by the tile's own textureRect (tiles are packed unrotated).
            // Inset by half a source pixel so linear filtering never samples the atlas neighbour
            // at the tile's outer edges (safeguard; no seam was observed).
            let raw = full.textureRect()
            let pxW = full.size().width * 2, pxH = full.size().height * 2
            let base = raw.insetBy(dx: pxW > 0 ? raw.width / pxW * 0.5 : 0, dy: pxH > 0 ? raw.height / pxH * 0.5 : 0)
            let w = base.width / CGFloat(n), h = base.height / CGFloat(n)
            var built: [SKTexture] = []
            built.reserveCapacity(n * n)
            for y in 0..<n {
                for x in 0..<n {
                    let rect = CGRect(x: base.minX + CGFloat(x) * w, y: base.minY + CGFloat(y) * h, width: w, height: h)
                    let t = SKTexture(rect: rect, in: full)
                    t.filteringMode = .linear
                    built.append(t)
                }
            }
            tileCells[name] = built
            cells = built
        }
        let x = ((column % n) + n) % n, y = ((row % n) + n) % n
        return cells[y * n + x]
    }

    static func atlas(_ atlas: Atlas) -> SKTextureAtlas {
        if let a = atlases[atlas] { return a }
        let a = SKTextureAtlas(named: atlas.rawValue)
        atlases[atlas] = a
        return a
    }

    static func texture(_ name: String, in atlas: Atlas) -> SKTexture {
        if let t = cache[name] { return t }
        let t = self.atlas(atlas).textureNamed(name)
        cache[name] = t
        return t
    }

    /// Soft white dot used for code-built particles (tinted per effect).
    static let particleDot: SKTexture = {
        let size = CGSize(width: 16, height: 16)
        let image = UIGraphicsImageRenderer(size: size).image { ctx in
            let colors = [UIColor.white.cgColor, UIColor.white.withAlphaComponent(0).cgColor] as CFArray
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0.35, 1]) {
                ctx.cgContext.drawRadialGradient(g, startCenter: CGPoint(x: 8, y: 8), startRadius: 0,
                                                 endCenter: CGPoint(x: 8, y: 8), endRadius: 8, options: [])
            }
        }
        return SKTexture(image: image)
    }()

    /// Five-point star used for poof particles.
    static let particleStar: SKTexture = {
        let size = CGSize(width: 24, height: 24)
        let image = UIGraphicsImageRenderer(size: size).image { ctx in
            let path = UIBezierPath()
            let c = CGPoint(x: 12, y: 12)
            for i in 0..<10 {
                let r: CGFloat = i.isMultiple(of: 2) ? 11 : 4.5
                let a = CGFloat(i) * .pi / 5 - .pi / 2
                let p = CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r)
                i == 0 ? path.move(to: p) : path.addLine(to: p)
            }
            path.close()
            UIColor.white.setFill()
            path.fill()
            _ = ctx
        }
        return SKTexture(image: image)
    }()

    /// ART_BIBLE §13.9: shared radial glow (128 px, white centre to transparent, `pow(1 - r, 2)`).
    static let radialGlow: SKTexture = {
        let px = 128
        let image = UIGraphicsImageRenderer(size: CGSize(width: px, height: px),
                                            format: { let f = UIGraphicsImageRendererFormat(); f.scale = 1; return f }()).image { ctx in
            let stops = 8
            var colors: [CGColor] = []
            var locs: [CGFloat] = []
            for i in 0...stops {
                let r = CGFloat(i) / CGFloat(stops)
                colors.append(UIColor.white.withAlphaComponent(pow(1 - r, 2)).cgColor)
                locs.append(r)
            }
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: locs) {
                let c = CGPoint(x: px / 2, y: px / 2)
                ctx.cgContext.drawRadialGradient(g, startCenter: c, startRadius: 0, endCenter: c,
                                                 endRadius: CGFloat(px) / 2, options: [])
            }
        }
        return SKTexture(image: image)
    }()

    /// Additive glow sprite of `diameter` in `color` at `alpha`.
    static func glow(diameter: CGFloat, color: SKColor, alpha: CGFloat) -> SKSpriteNode {
        let s = SKSpriteNode(texture: radialGlow, size: CGSize(width: diameter, height: diameter))
        s.color = color
        s.colorBlendFactor = 1
        s.blendMode = .add
        s.alpha = alpha
        return s
    }
}
