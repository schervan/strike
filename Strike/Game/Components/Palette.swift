import SpriteKit

/// ART_BIBLE §2 palette colors used by code-drawn visuals.
@MainActor
enum Palette {
    static func hex(_ v: UInt32, alpha: CGFloat = 1) -> SKColor {
        SKColor(red: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255,
                blue: CGFloat(v & 0xFF) / 255, alpha: alpha)
    }

    static let outline = hex(0x2B2140)
    static let white = SKColor.white
    static let star = hex(0xFFD93D)
    static let pixelCyan = hex(0x3DE3D0)
    static let pixelLight = hex(0xBFFFF7)
    static let heal = hex(0x5FE08A)
    static let robotMetal = hex(0xA9BCE0)
    static let robotMetalLight = hex(0xC9D2EA)
    static let uiPanel = hex(0x2E2A55)
    static let l1Sky = hex(0x8FD3FF)
    /// ART_BIBLE §13 state colours.
    static let stateOff = hex(0xFF3B5C)
    static let stateOn = hex(0x5FE08A)
    static let panelLine = hex(0x4A4585)
    static let background = hex(0x1E1B3D)

    /// Level "wall top" colour (ART_BIBLE §2 per-level theme table).
    static func wallTop(theme: String) -> SKColor {
        switch theme {
        case "l2": hex(0x6B7080)
        case "l3": hex(0x5FBF7A)
        case "l4": hex(0x3A4CA0)
        case "l5": hex(0x6B1E5E)
        default: hex(0x7E90B5)
        }
    }

    /// Projectile color per `projectileStyle` (ART_BIBLE §2 weapon colors).
    static func projectile(style: String) -> SKColor {
        switch style {
        case "bubble": hex(0xB05CFF)
        case "foam": hex(0xFFD93D)
        default: hex(0xFF8A3D)
        }
    }
}
