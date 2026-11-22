import CoreGraphics
import Testing
@testable import Strike

struct StickInputTests {
    func stick(_ dx: CGFloat, dead: CGFloat) -> StickInput {
        StickInput(origin: .zero, touch: CGPoint(x: dx, y: 0), radius: 70, deadZone: dead, fullAt: 0.85)
    }

    @Test func moveBelowDeadZoneInactive() {
        let s = stick(70 * 0.1, dead: 0.15)
        #expect(!s.isActive)
        #expect(s.magnitude == 0)
        #expect(stick(70 * 0.2, dead: 0.15).isActive)
    }

    @Test func aimBelowDeadZoneAimsButDoesNotFire() {
        let s = stick(70 * 0.2, dead: 0.30)
        #expect(!s.isActive) // no fire
        #expect(s.rawMagnitude > 0)
        #expect(s.direction.dx == 1) // still aims
        #expect(stick(70 * 0.35, dead: 0.30).isActive)
    }

    @Test func fullMagnitudeAtThreshold() {
        #expect(stick(70 * 0.85, dead: 0.15).magnitude == 1)
        #expect(stick(70 * 0.9, dead: 0.15).magnitude == 1)
        let mid = stick(70 * 0.5, dead: 0.15).magnitude
        #expect(abs(mid - 0.5) < 1e-6)
        #expect(stick(500, dead: 0.15).magnitude == 1)
    }

    @Test func baseFollowsFarDrag() {
        var s = stick(10, dead: 0.15)
        s.move(touch: CGPoint(x: 200, y: 0), followFactor: 1.4)
        #expect(abs(s.origin.x - (200 - 98)) < 1e-6)
        #expect(abs(s.distance - 98) < 1e-6)
        var near = stick(10, dead: 0.15)
        near.move(touch: CGPoint(x: 90, y: 0), followFactor: 1.4)
        #expect(near.origin == .zero)
        #expect(near.knob.x == 70) // knob clamped to the radius
    }
}
