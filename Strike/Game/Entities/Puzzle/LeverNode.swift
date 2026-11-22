import SpriteKit

/// Lever: INTERACT toggles it; the pull animation lasts `rules.puzzle.leverPullSec` and the
/// sprite swaps at its end.
@MainActor
final class LeverNode: InteractableNode {
    func playPull(to on: Bool, duration: Double) {
        let half = max(0.01, duration / 2)
        sprite.removeAction(forKey: "pull")
        sprite.run(.sequence([
            .scaleX(to: 0.2, duration: half),
            .run { [weak self] in self?.setOn(on, animated: false) },
            .scaleX(to: 1.0, duration: half),
            .run { [weak self] in
                guard let self, on, let parent = self.parent else { return }
                parent.addChild(Particles.stateOn(at: self.position, count: 6))
            },
        ]), withKey: "pull")
    }
}
