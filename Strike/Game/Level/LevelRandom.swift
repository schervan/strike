import Foundation
import GameplayKit

/// Seeded random helper for the generator. The only randomness source is the wrapped
/// `GKMersenneTwisterRandomSource` (TASKS M2 module map), so a seed fully determines a level.
nonisolated final class LevelRandom {
    let source: GKMersenneTwisterRandomSource

    init(seed: UInt64) {
        source = GKMersenneTwisterRandomSource(seed: seed)
    }

    /// Uniform integer in `lo...hi` (returns `lo` when the range is empty).
    func int(_ lo: Int, _ hi: Int) -> Int {
        guard hi > lo else { return lo }
        return lo + source.nextInt(upperBound: hi - lo + 1)
    }

    /// Uniform double in [0, 1).
    func unit() -> Double { Double(source.nextUniform()) }

    func chance(_ p: Double) -> Bool { p > 0 && unit() < p }

    func shuffled<T>(_ a: [T]) -> [T] {
        var a = a
        guard a.count > 1 else { return a }
        for i in stride(from: a.count - 1, to: 0, by: -1) {
            a.swapAt(i, int(0, i))
        }
        return a
    }

    func pick<T>(_ a: [T]) -> T? { a.isEmpty ? nil : a[int(0, a.count - 1)] }

    /// Index picked by weight (weights ≤ 0 never win). Nil if no positive weight.
    func weightedIndex(_ weights: [Double]) -> Int? {
        let total = weights.reduce(0) { $0 + max(0, $1) }
        guard total > 0 else { return nil }
        var r = unit() * total
        var last: Int?
        for (i, w) in weights.enumerated() where w > 0 {
            if r < w { return i }
            r -= w
            last = i
        }
        return last
    }
}
