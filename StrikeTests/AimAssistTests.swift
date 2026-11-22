import CoreGraphics
import Testing
@testable import Strike

struct AimAssistTests {
    let o = CGPoint.zero
    func at(_ deg: CGFloat, _ dist: CGFloat) -> CGPoint {
        CGPoint(x: cos(deg * .pi / 180) * dist, y: sin(deg * .pi / 180) * dist)
    }
    func adjust(_ targets: [CGPoint], los: @escaping (CGPoint) -> Bool = { _ in true }) -> CGFloat {
        AimAssist.adjust(stickAngle: 0, origin: o, targets: targets, coneDeg: 12, range: 520,
                         strength: 0.6, hasLineOfSight: los)
    }

    @Test func pullsTowardTargetInCone() {
        let a = adjust([at(10, 300)])
        #expect(abs(a - 6 * .pi / 180) < 1e-6)
    }

    @Test func outsideConeRangeOrLosIsRaw() {
        #expect(adjust([at(20, 300)]) == 0)
        #expect(adjust([at(5, 600)]) == 0)
        #expect(adjust([at(5, 300)], los: { _ in false }) == 0)
        #expect(adjust([]) == 0)
    }

    @Test func smallestAngleWins() {
        let a = adjust([at(10, 100), at(-4, 400)])
        #expect(abs(a - (-4 * 0.6) * .pi / 180) < 1e-6)
    }

    @Test func nearestWinsTies() {
        // Same angle difference on both sides; the nearer one (−8°) wins.
        let a = adjust([at(8, 400), at(-8, 150)])
        #expect(abs(a - (-8 * 0.6) * .pi / 180) < 1e-6)
    }

    @Test func wrapsAroundPi() {
        let a = AimAssist.adjust(stickAngle: .pi - 0.05, origin: o, targets: [at(-175, 200)],
                                 coneDeg: 12, range: 520, strength: 1, hasLineOfSight: { _ in true })
        let expected = CGFloat.pi - 0.05 + AimAssist.angleDifference(from: .pi - 0.05, to: -175 * .pi / 180)
        #expect(abs(a - expected) < 1e-6)
    }
}
