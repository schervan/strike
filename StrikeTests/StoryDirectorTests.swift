import CoreGraphics
import Testing
@testable import Strike

struct StoryDirectorTests {
    static var data: GameData { GeneratedCorpus.data }

    static func director(_ levelId: String) -> StoryDirector {
        StoryDirector(story: data.levels[levelId]!.effectiveStory)
    }

    @Test func storyDecodesFromLevelsJSON() {
        for l in Self.data.levelOrder {
            let s = l.effectiveStory
            #expect(!s.intro.isEmpty && !s.outro.isEmpty && !s.beats.isEmpty, "\(l.id)")
        }
    }

    @Test func eachBeatFiresOncePerLevel() {
        for l in Self.data.levelOrder {
            var d = StoryDirector(story: l.effectiveStory)
            var keys: [String] = []
            let events: [StoryEvent] = [
                .levelStart, .enemySeen("boltbot"), .pickup(itemId: "bolt", stored: false),
                .pickup(itemId: "blaster_spread", stored: false), .pickup(itemId: "blaster_rapid", stored: false),
                .pickup(itemId: "fuse", stored: true), .pickup(itemId: "battery", stored: true),
                .pickup(itemId: "keycard", stored: true), .pickup(itemId: "energycore", stored: true),
                .elementSeen(.button), .elementSeen(.lever), .elementSeen(.machine), .elementSeen(.pressureplate),
                .gateSeen, .lowHp, .zoneEntered(2), .zoneEntered(3), .allElementsOn, .doorOpen, .swapVisible,
            ]
            for _ in 0..<3 {
                for e in events { keys += d.handle(e).cues.filter { $0.kind == .story }.map(\.key) }
            }
            let beatKeys = l.effectiveStory.beats.filter { !$0.trigger.hasPrefix("boss") }.map(\.key)
            #expect(keys.sorted() == beatKeys.sorted(), "\(l.id)")       // all of them, each once
        }
    }

    /// QA-012: the swap line plays once, the first time SWAP appears; the generic line when the level has no beat.
    @Test func swapLinePlaysOnceWhenSwapAppears() {
        var l2 = Self.director("l2")
        #expect(l2.handle(.swapVisible).cues.map(\.key) == ["pixel.l2.swap"])
        #expect(l2.handle(.swapVisible).cues.isEmpty)
        #expect(l2.handle(.pickup(itemId: "blaster_spread", stored: false)).cues.allSatisfy { $0.key != "pixel.l2.swap" })
        var l3 = Self.director("l3")
        #expect(l3.handle(.swapVisible).cues.map(\.key) == [StoryDirector.Key.swap])
        #expect(l3.handle(.swapVisible).cues.isEmpty, "once per level")
    }

    @Test func firstEnemyFiresOnFirstSightWithTipAndScan() {
        var d = Self.director("l1")
        let r = d.handle(.enemySeen("boltbot"))
        #expect(r.cues.map(\.key) == ["pixel.l1.aim", "pixel.tip.boltbot"])
        #expect(r.scanEnemyId == "boltbot")
        do { let v = d.handle(.enemySeen("boltbot")); #expect(v == .silent) }
        let drone = d.handle(.enemySeen("laserdrone"))
        #expect(drone.cues == [StoryCue(key: "pixel.tip.laserdrone", kind: .chatter)])
    }

    /// "Sight", not contact: an enemy on screen with line of sight counts even far away; one
    /// behind a wall or off screen does not, however close.
    @Test func sightNeedsViewAndLineOfSight() {
        let l = LevelGenerator.generate(GeneratedCorpus.def("l1"), seed: 3, catalog: GeneratedCorpus.catalog)
        let grid = l.gridAllDoorsClosed
        let room = l.rooms.first { $0.id == l.startRoomId }!
        let a = grid.world(l.heroStart)
        // The farthest cell of the start room that the hero can see.
        var b = a
        for y in room.rect.y..<room.rect.maxY {
            for x in room.rect.x..<room.rect.maxX {
                let p = grid.world(GridPoint(x, y))
                if grid.isWalkable(GridPoint(x, y)), grid.hasLineOfSight(from: a, to: p),
                   hypot(p.x - a.x, p.y - a.y) > hypot(b.x - a.x, b.y - a.y) { b = p }
            }
        }
        #expect(hypot(b.x - a.x, b.y - a.y) >= 3 * TileGrid.tileSize)   // far away, no contact
        let view = CGRect(x: a.x - 600, y: a.y - 400, width: 1200, height: 800)
        #expect(StoryDirector.isSighted(b, from: a, visibleRect: view, grid: grid))
        #expect(!StoryDirector.isSighted(b, from: a, visibleRect: CGRect(x: 0, y: 0, width: 1, height: 1), grid: grid))
        // A floor point in another room that walls hide, inside a view rect that covers the map.
        let everything = grid.bounds
        let hidden = l.rooms.map { grid.world($0.rect.centerCell) }
            .first { grid.isWalkable(grid.cell(at: $0)) && !grid.hasLineOfSight(from: a, to: $0) }
        #expect(hidden != nil)
        if let hidden {
            #expect(!StoryDirector.isSighted(hidden, from: a, visibleRect: everything, grid: grid))
        }
    }

    @Test func levelBeatReplacesGenericLine() {
        var l1 = Self.director("l1")
        do { let v = l1.handle(.levelStart).cues; #expect(v == [StoryCue(key: "pixel.l1.move", kind: .story)]) }
        do { let v = l1.handle(.lowHp).cues; #expect(v == [StoryCue(key: "pixel.l1.heal", kind: .story)]) }
        do { let v = l1.handle(.lowHp).cues; #expect(v == [StoryCue(key: StoryDirector.Key.lowHp, kind: .chatter)]) }
        do { let v = l1.handle(.doorOpen).cues.map(\.key); #expect(v == ["pixel.l1.door"]) }

        var l3 = Self.director("l3")                                   // no start beat
        do { let v = l3.handle(.levelStart).cues; #expect(v == [StoryCue(key: StoryDirector.Key.start, kind: .chatter)]) }
    }

    @Test func genericLinesAndFirsts() {
        var d = Self.director("l3")
        do { let v = d.handle(.pickup(itemId: "healpack", stored: true)).cues.map(\.key); #expect(v == [StoryDirector.Key.firstItem]) }
        do { let ok = d.handle(.pickup(itemId: "food_apple", stored: true)).cues.isEmpty; #expect(ok) }
        do { let v = d.handle(.magazineEmpty).cues; #expect(v == [StoryCue(key: StoryDirector.Key.reload, kind: .chatter)]) }
        do { let ok = d.handle(.magazineEmpty).cues.isEmpty; #expect(ok) }
        do { let v = d.handle(.elementOn).cues.map(\.key); #expect(v == [StoryDirector.Key.elementOn]) }
        do { let v = d.handle(.gateOpen).cues.map(\.key); #expect(v == [StoryDirector.Key.gateOpen]) }
        do { let v = d.handle(.bagFull).cues.map(\.key); #expect(v == [StoryDirector.Key.bagFull]) }
        do { let v = d.handle(.checkpoint).cues.map(\.key); #expect(v == [StoryDirector.Key.checkpoint]) }
        do { let v = d.handle(.rescue).cues; #expect(v == [StoryCue(key: StoryDirector.Key.rescue, kind: .story)]) }
        do { let v = d.handle(.rescue).cues.count; #expect(v == 1) }                     // every rescue
    }

    @Test func bossTriggersAreIgnoredUntilM4() {
        var d = Self.director("l5")
        do { let v = d.handle(.bossPhase(1)); #expect(v == .silent) }
        do { let v = d.handle(.bossDefeated); #expect(v == .silent) }
    }
}
