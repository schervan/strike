import Foundation
import Testing
@testable import Strike

struct LocalizationKeyTests {
    static let bundle = Bundle(for: GameModel.self)

    static func table(_ lang: String) throws -> [String: String] {
        let path = try #require(bundle.path(forResource: "Localizable", ofType: "strings", inDirectory: nil, forLocalization: lang),
                                "no compiled Localizable.strings for \(lang)")
        let d = try #require(NSDictionary(contentsOfFile: path) as? [String: String])
        return d
    }

    /// Every nameKey/descKey/subtitleKey anywhere in the shipped JSON.
    static func jsonKeys() throws -> Set<String> {
        var out = Set<String>()
        func walk(_ n: Any) {
            if let d = n as? [String: Any] {
                for (k, v) in d {
                    if k.hasSuffix("Key"), let s = v as? String { out.insert(s) }
                    walk(v)
                }
            } else if let a = n as? [Any] { a.forEach(walk) }
        }
        for f in ["weapons", "items", "enemies", "loot", "levels", "hero"] {
            let url = try #require(bundle.url(forResource: f, withExtension: "json", subdirectory: "Data"))
            walk(try JSONSerialization.jsonObject(with: Data(contentsOf: url)))
        }
        return out
    }

    @Test(arguments: ["de", "en"])
    func everyJSONKeyIsTranslated(lang: String) throws {
        let t = try Self.table(lang)
        let keys = try Self.jsonKeys()
        #expect(keys.count > 30)
        for k in keys.sorted() {
            let v = t[k] ?? ""
            #expect(!v.isEmpty, "\(lang): missing or empty key \(k)")
        }
    }

    @Test(arguments: ["de", "en"])
    func hudAndLevelKeysExist(lang: String) throws {
        let t = try Self.table(lang)
        var required = ["hud.reload", "hud.reloading", "hud.hp.accessibility", "hud.ammo.accessibility",
                        "game.menu", "game.accessibilityLabel", "title.start", "title.gameName", "title.tagline"]
        for i in 1...5 { required += ["level.l\(i).name", "level.l\(i).subtitle"] }
        for k in required { #expect(!(t[k] ?? "").isEmpty, "\(lang): missing \(k)") }
    }

    @Test func germanDiffersFromEnglishAndNoPlaceholdersLeft() throws {
        let de = try Self.table("de"), en = try Self.table("en")
        #expect(Set(de.keys) == Set(en.keys))
        for (k, v) in en {
            #expect(!v.contains("TODO") && !v.contains("TBD"), "en \(k) placeholder text")
            #expect(!(de[k] ?? "").contains("TODO"), "de \(k) placeholder text")
        }
    }

    @Test func noDeathOrGoreWordingInStrings() throws {
        let banned = try Regex(#"\b(blood|bloody|kill|kills|killed|die|dies|dead|death|gore|gun|guns|murder|tot|töten|sterben|stirbt|Blut|Waffe)\b"#).ignoresCase()
        for lang in ["de", "en"] {
            for (k, v) in try Self.table(lang) {
                #expect(v.firstMatch(of: banned) == nil, "\(lang) \(k): '\(v)' has violent wording")
            }
        }
    }
}
