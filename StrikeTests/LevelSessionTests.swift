import Foundation
import Testing
@testable import Strike

struct LevelSessionTests {
    @Test func tracksProgress() throws {
        let l = LevelGenerator.generate(GeneratedCorpus.def("l1"), seed: 1, catalog: GeneratedCorpus.catalog)
        var s = LevelSession(level: l)
        #expect(s.levelId == "l1" && s.seed == l.seedUsed)
        #expect(s.lastCheckpointId == "checkpoint_start")
        #expect(s.revealedRoomIds == [l.startRoomId])
        s.tick(dt: 1.5)
        s.addBolts(3, scoreEach: 10)
        do { let v = s.collectDatachip("datachip_0", score: 250); #expect(v) }
        do { let v = s.collectDatachip("datachip_0", score: 250); #expect(!v) }
        #expect(s.score == 280 && s.bolts == 3 && s.datachipsFound.count == 1)
        do { let v = s.touchCheckpoint("checkpoint_start"); #expect(!v) }
        do { let v = s.touchCheckpoint("checkpoint_gate_2"); #expect(v) }
        do { let v = s.reveal(room: 3); let w = s.reveal(room: 3); #expect(v && !w) }
        s.recordRescue()
        s.complete()
        s.tick(dt: 10)
        #expect(s.elapsed == 1.5 && s.rescues == 1 && s.isComplete)
        let round = try JSONDecoder().decode(LevelSession.self, from: JSONEncoder().encode(s))
        #expect(round == s)
    }
}
