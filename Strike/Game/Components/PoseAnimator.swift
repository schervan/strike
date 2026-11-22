import SpriteKit

/// Procedural pose motion values (ART_BIBLE §12). Visual feel, not balance.
nonisolated struct PoseStyle: Sendable, Equatable {
    var idleBobAmplitude: CGFloat = 2
    var idlePeriod: Double = 1.2
    var breathY: CGFloat = 0.03
    var breathX: CGFloat = 0.015
    /// Steps per second = walkCadenceBase + walkCadencePerSpeed × s.
    var walkCadenceBase: Double = 2.2
    var walkCadencePerSpeed: Double = 2.2
    /// Hop amplitude × (0.4 + 0.6 s).
    var hopAmplitude: CGFloat = 3
    var squashY: CGFloat = 0.08
    var squashX: CGFloat = 0.06
    var swayDeg: CGFloat = 4
    var leanDeg: CGFloat = 3
    var maxTiltDeg: CGFloat = 10
    var blendSec: Double = 0.12
    var recoil: CGFloat = 3
    var recoilOutSec: Double = 0.04
    var recoilBackSec: Double = 0.10
    var rapidRecoil: CGFloat = 1.5
    var rapidRecoilOutSec: Double = 0.03
    var rapidRecoilBackSec: Double = 0.06
    var rapidThresholdSec: Double = 0.14
    var muzzlePopScaleY: CGFloat = 0.96
    var muzzlePopSec: Double = 0.05
    var shakeOffsets: [CGFloat] = [4, -4, 2, -2, 0]
    var shakeStepSec: Double = 0.02
    var hitStretchX: CGFloat = 1.1
    var hitStretchY: CGFloat = 0.92
    var hitStretchSec: Double = 0.08
    var blinkStepSec: Double = 0.08
    var blinkAlpha: CGFloat = 0.4
    var powerDownSec: Double = 0.35
    var powerDownFadeSec: Double = 0.15
    /// Facing flips only when |dx| exceeds this fraction of the vector length.
    var flipHysteresis: CGFloat = 0.2

    static let hero = PoseStyle()

    static let boltbot: PoseStyle = {
        var s = PoseStyle()
        s.idlePeriod = 1.4
        s.walkCadenceBase = 3.0
        s.walkCadencePerSpeed = 0
        s.hopAmplitude = 4
        s.swayDeg = 6
        s.recoil = 2
        return s
    }()
}

/// Animates a single key-pose sprite procedurally: idle bob, walk hop/squash/tilt, facing flip,
/// hit flash + shake, recoil and power-down (ART_BIBLE §12). Call `update(dt:)` every frame.
@MainActor
final class PoseAnimator {
    /// Gets the facing flip (`xScale ±1`). Add this to the owner node.
    let root = SKNode()
    /// Gets squash, bob, tilt, recoil and shake.
    let sprite: SKSpriteNode
    let style: PoseStyle
    /// Full frame animations are off in the MVP (lite set: all frames equal `_idle_01`).
    var useFrameAnimations = false

    private(set) var facingEast = true
    private var speed01: CGFloat = 0
    private var walkBlend: CGFloat = 0
    private var idlePhase: Double
    private var stepPhase: Double = 0
    private var moveDX: CGFloat = 0

    private var recoilDir = CGVector.zero
    private var recoilAge: Double = .infinity
    private var recoilAmp: CGFloat = 0
    private var recoilOut: Double = 0
    private var recoilBack: Double = 0
    private var lastShotTime: Double = -.infinity
    private var clock: Double = 0

    private var hitAge: Double = .infinity
    private var hitSign: CGFloat = 1
    private var blinking = false
    private var poweredDown = false

    init(textureName: String, atlas: Textures.Atlas, style: PoseStyle, anchor: CGPoint = CGPoint(x: 0.5, y: 0.1)) {
        let tex = Textures.texture(textureName, in: atlas)
        sprite = SKSpriteNode(texture: tex)
        sprite.anchorPoint = anchor
        sprite.color = .white
        sprite.colorBlendFactor = 0
        self.style = style
        idlePhase = Double.random(in: 0..<1)
        root.addChild(sprite)
    }

    /// 0…1 of the character's max speed, plus the world-space x of the movement (for the lean).
    func setMotion(speed01 s: CGFloat, moveDX dx: CGFloat = 0) {
        speed01 = min(1, max(0, s))
        moveDX = dx
    }

    /// Faces east (`xScale +1`) or west (`-1`); never rotates.
    func face(east: Bool) {
        facingEast = east
        root.xScale = east ? 1 : -1
    }

    /// Faces along a vector with hysteresis (keeps the last facing for near-vertical vectors).
    func face(along v: CGVector) {
        let len = hypot(v.dx, v.dy)
        guard len > 0, abs(v.dx) > style.flipHysteresis * len else { return }
        face(east: v.dx > 0)
    }

    func setBlinking(_ on: Bool) {
        blinking = on
        if !on { sprite.alpha = 1 }
    }

    /// White flash + shake. `from` is the world direction the hit came from (pushes away).
    func playHit(from dir: CGVector = .zero) {
        guard !poweredDown else { return }
        hitAge = 0
        // `dir` points from the attacker to us, so the first nudge goes along it.
        let worldSign: CGFloat = dir.dx < 0 ? -1 : 1
        hitSign = worldSign * (facingEast ? 1 : -1)
        sprite.removeAction(forKey: "flash")
        sprite.colorBlendFactor = 0.85
        sprite.run(.sequence([
            .wait(forDuration: 0.05),
            .colorize(withColorBlendFactor: 0.4, duration: 0),
            .wait(forDuration: 0.05),
            .colorize(withColorBlendFactor: 0, duration: 0),
        ]), withKey: "flash")
    }

    /// Small kick opposite to the aim angle (radians, world space).
    func playRecoil(angle: CGFloat) {
        let rapid = clock - lastShotTime < style.rapidThresholdSec
        lastShotTime = clock
        recoilDir = CGVector(dx: -cos(angle), dy: -sin(angle))
        recoilAmp = rapid ? style.rapidRecoil : style.recoil
        recoilOut = rapid ? style.rapidRecoilOutSec : style.recoilOutSec
        recoilBack = rapid ? style.rapidRecoilBackSec : style.recoilBackSec
        recoilAge = 0
    }

    /// Flash, shrink + spin + fade, then `completion` (ART_BIBLE §12 power-down).
    func playPowerDown(completion: @escaping @MainActor () -> Void) {
        guard !poweredDown else { return }
        poweredDown = true
        sprite.removeAllActions()
        sprite.alpha = 1
        // Scale around the sprite centre for this step.
        let h = sprite.size.height
        sprite.position.y += (0.5 - sprite.anchorPoint.y) * h * sprite.yScale
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        sprite.colorBlendFactor = 0.85
        let total = style.powerDownSec
        let shrink = SKAction.group([
            .scale(to: 0, duration: total),
            .rotate(byAngle: .pi * (Bool.random() ? 1 : -1), duration: total),
            .sequence([.wait(forDuration: max(0, total - style.powerDownFadeSec)),
                       .fadeOut(withDuration: style.powerDownFadeSec)]),
        ])
        shrink.timingMode = .easeIn
        sprite.run(.sequence([
            .wait(forDuration: 0.08),
            .colorize(withColorBlendFactor: 0, duration: 0),
            shrink,
            .run { completion() },
        ]))
    }

    /// Restores the sprite after a power-down (used by the hero respawn).
    func reset() {
        poweredDown = false
        sprite.removeAllActions()
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0.1)
        sprite.position = .zero
        sprite.setScale(1)
        sprite.zRotation = 0
        sprite.alpha = 1
        sprite.colorBlendFactor = 0
        hitAge = .infinity
        recoilAge = .infinity
    }

    func update(dt: Double) {
        clock += dt
        guard !poweredDown else { return }
        let s = style

        // Blend idle ↔ walk.
        let target: CGFloat = speed01 >= 0.05 ? 1 : 0
        let step = CGFloat(dt / max(0.001, s.blendSec))
        walkBlend += max(-step, min(step, target - walkBlend))

        // Idle bob + breathing (in phase).
        idlePhase += dt / s.idlePeriod
        let idleWave = CGFloat(0.5 * (1 + sin(idlePhase * 2 * .pi)))
        let idleY = s.idleBobAmplitude * idleWave
        let idleSX = 1 - s.breathX * idleWave
        let idleSY = 1 + s.breathY * idleWave

        // Walk hop + squash + sway.
        let cadence = s.walkCadenceBase + s.walkCadencePerSpeed * Double(speed01)
        stepPhase += dt * cadence * .pi
        let hop = CGFloat(abs(sin(stepPhase)))
        let walkY = s.hopAmplitude * (0.4 + 0.6 * speed01) * hop
        let squash = 2 * hop - 1
        let walkSY = 1 + s.squashY * squash
        let walkSX = 1 - s.squashX * squash
        let sway = s.swayDeg * CGFloat(sin(stepPhase))
        let lean = -s.leanDeg * speed01 * (moveDX > 0 ? 1 : (moveDX < 0 ? -1 : 0))
        // World-space tilt; the parent's flip mirrors rotation, so compensate.
        var tilt = (sway + lean) * walkBlend
        tilt = max(-s.maxTiltDeg, min(s.maxTiltDeg, tilt))
        let facing: CGFloat = facingEast ? 1 : -1

        var x: CGFloat = 0
        var y = idleY * (1 - walkBlend) + walkY * walkBlend
        var sx = idleSX * (1 - walkBlend) + walkSX * walkBlend
        var sy = idleSY * (1 - walkBlend) + walkSY * walkBlend

        // Recoil.
        if recoilAge.isFinite {
            recoilAge += dt
            let out = recoilOut, back = recoilBack
            var k: CGFloat = 0
            if recoilAge < out { k = CGFloat(recoilAge / out) }
            else if recoilAge < out + back {
                let u = CGFloat((recoilAge - out) / back)
                k = 1 - (1 - (1 - u) * (1 - u)) // ease out back to 0
            } else { recoilAge = .infinity }
            x += recoilDir.dx * recoilAmp * k * facing
            y += recoilDir.dy * recoilAmp * k
            if recoilAge < s.muzzlePopSec { sy *= s.muzzlePopScaleY }
        }

        // Hit shake + stretch.
        if hitAge.isFinite {
            hitAge += dt
            let idx = Int(hitAge / s.shakeStepSec)
            if idx < s.shakeOffsets.count {
                x += s.shakeOffsets[idx] * hitSign
            } else { hitAge = .infinity }
            if hitAge < s.hitStretchSec { sx *= s.hitStretchX; sy *= s.hitStretchY }
        }

        sprite.position = CGPoint(x: x, y: y)
        sprite.xScale = sx
        sprite.yScale = sy
        sprite.zRotation = tilt * .pi / 180 * facing

        if blinking {
            let phase = Int(clock / s.blinkStepSec)
            sprite.alpha = phase.isMultiple(of: 2) ? 1 : s.blinkAlpha
        }
    }
}
