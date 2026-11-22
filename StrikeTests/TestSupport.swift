import Foundation
@testable import Strike

enum TestData {
    static func load() throws -> GameData {
        try GameData.load(bundle: Bundle(for: GameModel.self))
    }

    static func starter() throws -> WeaponDef {
        let d = try load()
        guard let w = d.weapons["blaster_starter"] else { throw GameDataError.missingFile("blaster_starter") }
        return w
    }
}
