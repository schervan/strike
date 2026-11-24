import Foundation
import Testing
@testable import Strike

/// M3-7: 10,000 seeded random action sequences against `Inventory` (+ `ItemUse`), checked after EVERY
/// action against a ledger of what was added, used and dropped (no duplication, no loss).
struct InventoryFuzzTests {
    struct SplitMix: RandomNumberGenerator {
        var s: UInt64
        mutating func next() -> UInt64 {
            s &+= 0x9E37_79B9_7F4A_7C15
            var z = s
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
    }

    static let data: GameData = try! TestData.load()
    static let allIds: [String] = Array(data.items.keys).sorted() + ["unknown_item"]

    /// Returns nil when all invariants hold, otherwise a description of the first violation.
    static func run(seed: UInt64, actions: Int) -> String? {
        var rng = SplitMix(s: seed)
        let rules = data.rules.inventory
        var inv = Inventory(items: data.items, rules: rules)
        var ledger: [String: Int] = [:]
        var health = Health(max: 100, invulnerableSec: 0)
        health = { var h = health; _ = h.applyDamage(60); return h }()
        let weapons = data.weapons
        var loadout = Loadout(start: data.hero.startLoadout, weapons: weapons)
        var cooldowns = UseCooldowns(cooldownSec: rules.useCooldownSec)
        var now = 0.0
        var log: [String] = []

        func fail(_ why: String) -> String { "seed \(seed): \(why) after [\(log.suffix(6).joined(separator: ", "))]" }

        func check() -> String? {
            if inv.slotCount != rules.slots { return "slot count \(inv.slotCount)" }
            if inv.usedSlots > 25 { return "more than 25 slots used" }
            if inv.quickCount != rules.quickSlots { return "quick count \(inv.quickCount)" }
            for (i, s) in inv.slots.enumerated() {
                guard let s else { continue }
                guard let d = inv.catalog[s.itemId] else { return "slot \(i) unknown id \(s.itemId)" }
                if !d.storesInInventory { return "slot \(i) holds non-bag item \(s.itemId)" }
                if s.count < 1 { return "slot \(i) empty stack (\(s.count))" }
                if s.count > d.stackSize { return "slot \(i) \(s.itemId) x\(s.count) > stackSize \(d.stackSize)" }
            }
            var seen = Set<String>()
            for (i, q) in inv.quick.enumerated() {
                guard let q else { continue }
                if !inv.canStore(q) { return "quick \(i) links invalid item \(q)" }
                if !seen.insert(q).inserted { return "quick links \(q) twice" }
            }
            let totals = inv.totals.filter { $0.value > 0 }
            let expected = ledger.filter { $0.value > 0 }
            if totals != expected { return "totals \(totals) != ledger \(expected)" }
            if health.current > health.max || health.current < 0 { return "hp \(health.current)" }
            for (id, cap) in loadout.ammo.caps where loadout.ammo.reserve(id) > cap || loadout.ammo.reserve(id) < 0 {
                return "reserve \(id) \(loadout.ammo.reserve(id)) vs cap \(cap)"
            }
            return nil
        }

        for _ in 0..<actions {
            let id = allIds.randomElement(using: &rng)!
            switch Int.random(in: 0..<12, using: &rng) {
            case 0, 1, 2:
                let n = [1, 1, 2, 3, 5, 12, 40, 130].randomElement(using: &rng)!
                let left = inv.add(id, count: n)
                if left < 0 || left > n { return fail("add returned \(left) for \(n)") }
                ledger[id, default: 0] += n - left
                if !inv.canStore(id), left != n { return fail("non-bag item \(id) partly stored") }
                log.append("add \(id)x\(n)->\(left)")
            case 3:
                let n = Int.random(in: 1...8, using: &rng)
                let before = inv.count(of: id)
                let ok = inv.addAll(id, count: n)
                if ok { ledger[id, default: 0] += n } else if inv.count(of: id) != before { return fail("addAll changed bag on failure") }
                log.append("addAll \(id)x\(n)=\(ok)")
            case 4:
                let n = Int.random(in: 1...6, using: &rng)
                if inv.remove(id, count: n) { ledger[id, default: 0] -= n }
                log.append("remove \(id)x\(n)")
            case 5:
                let slot = Int.random(in: -1...26, using: &rng)
                let n = Int.random(in: 1...12, using: &rng)
                if let s = inv.drop(slot: slot, count: n) {
                    if s.count < 1 || s.count > n { return fail("drop returned \(s)") }
                    ledger[s.itemId, default: 0] -= s.count
                }
                log.append("drop slot\(slot)x\(n)")
            case 6:
                let q = Int.random(in: -1...4, using: &rng)
                let linkNil = Bool.random(using: &rng)
                _ = inv.assignQuick(itemId: linkNil ? nil : id, to: q)
                log.append("assign \(linkNil ? "nil" : id)->Q\(q)")
            case 7:
                let before = inv.totals
                inv.tidy()
                if inv.totals != before { return fail("tidy changed totals") }
                // tidy leaves at most one partial stack per id and no gaps
                var partial: [String: Int] = [:]
                var gap = false
                for s in inv.slots {
                    guard let s else { gap = true; continue }
                    if gap { return fail("tidy left a gap before \(s.itemId)") }
                    if s.count < inv.stackSize(of: s.itemId) { partial[s.itemId, default: 0] += 1 }
                }
                if partial.values.contains(where: { $0 > 1 }) { return fail("tidy left two partial stacks of one id") }
                log.append("tidy")
            case 8, 9:
                now += Double.random(in: 0...0.9, using: &rng)
                let useQuick = Bool.random(using: &rng)
                let slot = Int.random(in: 0..<25, using: &rng), q = Int.random(in: 0..<4, using: &rng)
                let usedId = useQuick ? inv.quickItem(q) : inv.slots[slot]?.itemId
                let hpBefore = health.current
                let r: UseResult = useQuick
                    ? ItemUse.useQuick(q, inventory: &inv, health: &health, loadout: &loadout, cooldowns: &cooldowns, now: now)
                    : ItemUse.useSlot(slot, inventory: &inv, health: &health, loadout: &loadout, cooldowns: &cooldowns, now: now)
                if case .used(let heal, _) = r {
                    guard let usedId else { return fail("used something from nothing") }
                    ledger[usedId, default: 0] -= 1
                    if heal < 0 || health.current != hpBefore + heal { return fail("heal \(heal) vs hp \(hpBefore)->\(health.current)") }
                } else if health.current != hpBefore {
                    return fail("HP changed without a use (\(r))")
                }
                log.append("use \(useQuick ? "Q\(q)" : "slot\(slot)") \(usedId ?? "-") -> \(r)")
            case 10:
                // Hurt the hero so heals stay possible.
                _ = health.applyDamage(Int.random(in: 1...40, using: &rng))
                health.tick(dt: 10)
                log.append("hurt")
            default:
                // Save/load round trip must change nothing.
                guard let data = try? JSONEncoder().encode(inv), var back = try? JSONDecoder().decode(Inventory.self, from: data) else {
                    return fail("inventory failed to encode/decode")
                }
                back.bind(items: Self.data.items, rules: rules)
                // QA-010 fixed: the exact slot layout (gaps, partial stacks) must survive save/load.
                if back != inv { return fail("round trip changed the bag layout") }
                if back.totals != inv.totals { return fail("round trip changed totals") }
                if back.quick != inv.quick { return fail("round trip changed quick links") }
                inv = back
                log.append("roundtrip")
            }
            if let why = check() { return fail(why) }
        }
        // Finally remove category puzzle (level start/end rule) and re-check totals.
        let puzzleTotal = inv.totals(in: .puzzle).values.reduce(0, +)
        inv.removeAll(category: .puzzle)
        for (id, d) in inv.catalog where d.category == .puzzle { ledger[id] = 0 }
        if puzzleTotal > 0, !inv.totals(in: .puzzle).isEmpty { return fail("removeAll left puzzle items") }
        return check().map(fail)
    }

    @Test func tenThousandRandomSequencesKeepEveryInvariant() {
        var failures: [String] = []
        for seed in 1...10_000 {
            if let why = Self.run(seed: UInt64(seed), actions: 60) {
                if failures.count < 5 { failures.append(why) }
                else { failures.append("") }
            }
        }
        for f in failures.prefix(5) where !f.isEmpty { print("INVFAIL \(f)") }
        print("INVFUZZ 10000 sequences x 60 actions, failing: \(failures.count)")
        #expect(failures.isEmpty, "\(failures.count) failing sequences, first: \(failures.first ?? "")")
    }

    @Test func fullBagStress() {
        // Long sequences hammering a nearly full bag.
        var failures = 0
        for seed in 20_001...20_200 { if Self.run(seed: UInt64(seed), actions: 400) != nil { failures += 1 } }
        #expect(failures == 0)
    }

    /// QA-010 (fixed by coder-m3): save/load keeps every stack in its own slot, gaps included.
    @Test func roundTripKeepsSlotLayout() throws {
        let rules = Self.data.rules.inventory
        var inv = Inventory(items: Self.data.items, rules: rules)
        _ = inv.add("healpack", count: 3)
        _ = inv.add("fuse", count: 2)
        _ = inv.add("food_apple", count: 4)
        _ = inv.drop(slot: 1, count: 2)            // leaves a gap at slot 1
        let before = inv.slots
        var back = try JSONDecoder().decode(Inventory.self, from: try JSONEncoder().encode(inv))
        back.bind(items: Self.data.items, rules: rules)
        #expect(back.slots == before, "slot layout changed by save/load")
        #expect(back.totals == inv.totals)
    }
}
