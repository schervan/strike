import Foundation

/// One blaster from `weapons.json` (GDD §16.1).
nonisolated struct WeaponDef: Codable, Sendable, Equatable, Identifiable {
    let id: String
    let nameKey: String
    let ammoId: String
    let damage: Int
    let pellets: Int
    let spreadDeg: Double
    let jitterDeg: Double
    let fireRate: Double
    let projectileSpeed: Double
    let range: Double
    let projectileRadius: Double
    let projectileStyle: String
    let knockback: Double
    let magazineSize: Int
    let reserveMax: Int
    let reloadSec: Double
    let aimAssistConeDeg: Double
    let unlockLevel: Int

    /// Atlas texture for the projectile (`items` atlas), derived from the weapon id suffix
    /// (`blaster_starter` → `proj_starter`), matching ART_BIBLE §6.
    var projectileTextureName: String {
        let suffix = id.split(separator: "_").last.map(String.init) ?? id
        return "proj_\(suffix)"
    }

    /// HUD icon in the `ui` atlas (`ui_icon_blaster_starter`).
    var iconTextureName: String { "ui_icon_\(id)" }
}

nonisolated struct WeaponsFile: Codable, Sendable {
    let version: Int
    let weapons: [WeaponDef]
}
