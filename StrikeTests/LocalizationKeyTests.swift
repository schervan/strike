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
        // Per language: the German article "die" is not the English verb.
        let banned = [
            "en": try Regex(#"\b(blood|bloody|kill|kills|killed|die|dies|dead|death|gore|gun|guns|murder)\b"#).ignoresCase(),
            "de": try Regex(#"\b(blood|kill|gore|tot|tod|töten|tötet|sterben|stirbt|blut|blutig|waffe|waffen|mord)\b"#).ignoresCase(),
        ]
        for lang in ["de", "en"] {
            let rx = banned[lang]!
            for (k, v) in try Self.table(lang) {
                #expect(v.firstMatch(of: rx) == nil, "\(lang) \(k): '\(v)' has violent wording")
            }
        }
    }

    // MARK: M3-7 story / pixel / boss keys

    /// Every string in `levels.json -> story` (intro/outro arrays and beat keys).
    static func storyKeys() throws -> Set<String> {
        let url = try #require(bundle.url(forResource: "levels", withExtension: "json", subdirectory: "Data"))
        let root = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        var out = Set<String>()
        for l in root["levels"] as? [[String: Any]] ?? [] {
            guard let story = l["story"] as? [String: Any] else { continue }
            for k in ["intro", "outro"] { out.formUnion(story[k] as? [String] ?? []) }
            for b in story["beats"] as? [[String: Any]] ?? [] { if let k = b["key"] as? String { out.insert(k) } }
        }
        return out
    }

    /// Generic Pixel lines the code can say, derived from the data where possible.
    static func genericPixelKeys() throws -> Set<String> {
        let data = try TestData.load()
        var out: Set<String> = [
            "pixel.generic.start", "pixel.generic.first_item", "pixel.generic.bag_full", "pixel.generic.low_hp",
            "pixel.generic.reload", "pixel.generic.element_on", "pixel.generic.all_on", "pixel.generic.gate_open",
            "pixel.generic.door_open", "pixel.generic.checkpoint", "pixel.generic.rescue", "pixel.generic.idle",
            "pixel.generic.hint_here", "pixel.generic.hint_item", "pixel.generic.hint_machine",
            "pixel.generic.hint_exit", "pixel.generic.hint_wait",
        ]
        for i in data.items.values where i.category == .puzzle { out.insert("pixel.generic.need_\(i.id)") }
        // The boss has its own boss.* lines instead of a tip.
        for e in data.enemies.keys where e != "megamech" { out.insert("pixel.tip.\(e)") }
        return out
    }

    @Test(arguments: ["de", "en"])
    func storyPixelAndBossKeysExist(lang: String) throws {
        let t = try Self.table(lang)
        let story = try Self.storyKeys()
        #expect(story.count >= 50, "levels.json story keys found: \(story.count)")
        for l in 1...5 { #expect(story.contains("pixel.l\(l).door") || story.contains("story.l\(l).intro.1"), "level \(l) has no story") }
        for k in story.sorted() { #expect(!(t[k] ?? "").isEmpty, "\(lang): missing story/pixel key \(k)") }
        for k in try Self.genericPixelKeys().sorted() { #expect(!(t[k] ?? "").isEmpty, "\(lang): missing generic pixel key \(k)") }
        let boss = t.keys.filter { $0.hasPrefix("boss.") }
        #expect(boss.count >= 7, "boss keys present: \(boss.count)")
    }

    /// Pixel speech bubbles hold `rules.pixel.maxChars` characters; story and boss lines stay short too.
    @Test(arguments: ["de", "en"])
    func pixelLinesFitTheBubble(lang: String) throws {
        let t = try Self.table(lang)
        let maxChars = try TestData.load().rules.pixel.maxChars
        for (k, v) in t where k.hasPrefix("pixel.") || k.hasPrefix("story.") || k.hasPrefix("boss.") {
            #expect(v.count <= maxChars, "\(lang) \(k) is \(v.count) chars (max \(maxChars)): \(v)")
            #expect(!v.contains("\n") || k.hasPrefix("story."), "\(lang) \(k) has a line break")
        }
    }

    /// Every localization-key-looking string literal in the Swift sources exists in the catalog (de + en).
    @Test func everyKeyLiteralInSourcesExists() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Strike")
        let fm = FileManager.default
        guard let walker = fm.enumerator(at: root, includingPropertiesForKeys: nil) else { Issue.record("cannot read \(root.path)"); return }
        let rx = try Regex(#""((?:hud|ui|pixel|story|boss|item|weapon|enemy|level|title|game|inventory|settings|pause|levelComplete|intro|quick|bag|tip)\.[A-Za-z0-9_.]*[A-Za-z0-9_])""#)
        // UserDefaults keys and SF Symbol names that merely look like keys.
        let ignore: Set<String> = ["settings.musicVolume", "settings.sfxVolume", "settings.muteAll", "bag.fill",
                                   // accessibility identifiers passed as `id:` arguments
                                   "settings.musicSlider", "settings.sfxSlider", "pause.settings"]
        let de = try Self.table("de"), en = try Self.table("en")
        var scanned = 0, literals = 0
        for case let url as URL in walker where url.pathExtension == "swift" {
            scanned += 1
            let text = try String(contentsOf: url, encoding: .utf8)
            for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
                let l = line.trimmingCharacters(in: .whitespaces)
                if l.hasPrefix("//") || l.contains("accessibilityIdentifier") { continue }
                for m in line.matches(of: rx) {
                    let key = String(line[m.range]).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                    if ignore.contains(key) || key.hasSuffix("Button") { continue }
                    literals += 1
                    #expect(!(en[key] ?? "").isEmpty && !(de[key] ?? "").isEmpty, "\(url.lastPathComponent): key literal \(key) missing in de/en")
                }
            }
        }
        #expect(scanned > 20 && literals > 20, "scanned \(scanned) files, \(literals) literals")
    }
}
