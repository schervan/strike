import Foundation

/// Anything that holds items the puzzle can ask for (DECISIONS: the M2 `PuzzleBag` was replaced
/// by the M3 `Inventory`, which conforms to this protocol).
nonisolated protocol ItemCarrier {
    func count(of itemId: String) -> Int
    /// Adds up to `count` items; returns how many did not fit (overflow).
    mutating func add(_ itemId: String, count: Int) -> Int
    /// Removes `count` items if that many are held; otherwise removes nothing and returns false.
    mutating func remove(_ itemId: String, count: Int) -> Bool
}
