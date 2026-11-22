import Foundation

/// Progress of one level play (M5 persists it). Pure value type.
nonisolated struct LevelSession: Sendable, Equatable, Codable {
    let levelId: String
    let seed: UInt64
    private(set) var elapsed: Double = 0
    private(set) var score = 0
    private(set) var bolts = 0
    /// Pickup ids of collected datachips.
    private(set) var datachipsFound: Set<String> = []
    private(set) var rescues = 0
    private(set) var lastCheckpointId: String?
    private(set) var revealedRoomIds: Set<Int> = []
    private(set) var isComplete = false

    init(levelId: String, seed: UInt64, startCheckpointId: String? = nil, startRoomId: Int? = nil) {
        self.levelId = levelId
        self.seed = seed
        lastCheckpointId = startCheckpointId
        if let r = startRoomId { revealedRoomIds.insert(r) }
    }

    init(level: GeneratedLevel) {
        self.init(levelId: level.levelId, seed: level.seedUsed, startCheckpointId: level.checkpoints.first?.id,
                  startRoomId: level.startRoomId)
    }

    mutating func tick(dt: Double) {
        guard !isComplete else { return }
        elapsed += max(0, dt)
    }

    mutating func addScore(_ points: Int) {
        score += max(0, points)
    }

    mutating func addBolts(_ n: Int, scoreEach: Int) {
        guard n > 0 else { return }
        bolts += n
        addScore(n * scoreEach)
    }

    /// Returns true the first time this datachip is collected.
    @discardableResult
    mutating func collectDatachip(_ pickupId: String, score points: Int) -> Bool {
        guard datachipsFound.insert(pickupId).inserted else { return false }
        addScore(points)
        return true
    }

    /// Returns true when this is a different checkpoint than the last one (show the toast).
    @discardableResult
    mutating func touchCheckpoint(_ id: String) -> Bool {
        guard lastCheckpointId != id else { return false }
        lastCheckpointId = id
        return true
    }

    /// Returns true the first time the room is revealed.
    @discardableResult
    mutating func reveal(room id: Int) -> Bool {
        revealedRoomIds.insert(id).inserted
    }

    mutating func recordRescue() {
        rescues += 1
    }

    mutating func complete() {
        isComplete = true
    }
}
