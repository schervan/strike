import SpriteKit

/// The hero: container at the collision centre (circle `hero.radius`), key-pose sprite child
/// with its feet at y = −radius.
@MainActor
final class HeroNode: SKNode {
    let def: HeroDef
    let animator: PoseAnimator
    var health: Health
    /// Owned blasters, magazines and ammo reserves (carries over; M3 pass B feeds it from `RunState`).
    var loadout: Loadout
    /// Timers of the equipped blaster.
    var weapon: WeaponState
    /// Spore slow (GDD §4).
    var status = StatusEffects()
    private var slowAura: SKShapeNode?

    private var knockbackVelocity = CGVector.zero
    private var knockbackRemaining: Double = 0

    init(def: HeroDef, weapons: [String: WeaponDef], loadout: Loadout? = nil) {
        self.def = def
        animator = PoseAnimator(textureName: "hero_idle_01", atlas: .hero, style: .hero)
        health = Health(max: def.maxHp, invulnerableSec: def.invulnerableSec)
        let loadout = loadout ?? Loadout(start: def.startLoadout, weapons: weapons)
        guard let equipped = weapons[loadout.equipped] ?? weapons[def.startLoadout.weaponId] else {
            fatalError("hero.json startLoadout.weaponId \(def.startLoadout.weaponId) not in weapons.json")
        }
        self.loadout = loadout
        self.weapon = WeaponState(def: equipped, safetyNet: def.starterSafetyNet,
                                  safetyNetWeapon: weapons[def.startLoadout.weaponId])
        super.init()
        name = "hero"
        animator.root.position = CGPoint(x: 0, y: -CGFloat(def.radius))
        addChild(animator.root)

        let body = SKPhysicsBody(circleOfRadius: CGFloat(def.radius))
        body.affectedByGravity = false
        body.allowsRotation = false
        body.linearDamping = 0
        body.friction = 0
        body.restitution = 0
        body.categoryBitMask = PhysicsCategory.hero
        body.collisionBitMask = PhysicsCategory.wall | PhysicsCategory.crate
        body.contactTestBitMask = PhysicsCategory.none
        physicsBody = body
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not supported") }

    var radius: CGFloat { CGFloat(def.radius) }

    // MARK: Equipped blaster (magazine/reserve through the loadout)

    var magazine: Int { weapon.magazine(in: loadout) }
    var reserve: Int { weapon.reserve(in: loadout) }
    var totalAmmo: Int { weapon.totalAmmo(in: loadout) }
    var canReload: Bool { weapon.canReload(in: loadout) }

    func tryFire(triggerHeld: Bool) -> Bool { weapon.tryFire(triggerHeld: triggerHeld, loadout: &loadout) }

    @discardableResult
    func startReload() -> Bool { weapon.startReload(loadout: loadout) }

    /// SWAP / wheel (GDD §5.1): equips `weaponId` in the loadout and starts the swap time.
    @discardableResult
    func swap(to w: WeaponDef, swapSec: Double) -> Bool {
        guard loadout.swap(to: w.id) else { return false }
        weapon.beginSwap(to: w, swapSec: swapSec)
        return true
    }

    /// A spore hit (ART_BIBLE §15.4): slow + pink tint + aura; a re-hit refreshes.
    func applySlow(multiplier: Double, sec: Double) {
        status.applySlow(multiplier: multiplier, sec: sec)
        if slowAura == nil {
            let a = SKShapeNode(ellipseOf: CGSize(width: 56, height: 20))
            a.fillColor = EnemyFX.sporePink.withAlphaComponent(0.35)
            a.strokeColor = EnemyFX.sporeLight
            a.lineWidth = 1.5
            a.position = CGPoint(x: 0, y: -radius)
            a.zPosition = -1
            a.name = "slow_aura"
            a.run(.repeatForever(.sequence([.fadeAlpha(to: 0.45 / 0.35, duration: 0.4), .fadeAlpha(to: 0.25 / 0.35, duration: 0.4)])))
            addChild(a)
            slowAura = a
        }
    }

    /// Rescue: no leftover slow.
    func clearStatus() {
        status.clear()
        updateSlowLook()
    }

    private func updateSlowLook() {
        let sprite = animator.sprite
        if status.isSlowed {
            if sprite.action(forKey: "flash") != nil {
                sprite.color = .white                    // the hit flash stays white
            } else {
                sprite.color = EnemyFX.sporePink
                sprite.colorBlendFactor = 0.3 * CGFloat(min(1, status.slowRemaining / 0.4))
            }
        } else if slowAura != nil {
            sprite.color = .white
            sprite.colorBlendFactor = 0
            slowAura?.removeFromParent()
            slowAura = nil
        }
    }

    /// Where shots leave the blaster (in the parent's coordinates).
    func muzzlePoint(angle: CGFloat) -> CGPoint {
        let reach = radius + 10
        return CGPoint(x: position.x + cos(angle) * reach, y: position.y + sin(angle) * reach)
    }

    /// Sets the physics velocity from the move stick (unit direction × 0…1) plus knockback.
    func drive(direction: CGVector, magnitude: CGFloat, dt: Double) {
        let speed = CGFloat(def.moveSpeed * status.speedMultiplier) * magnitude
        var v = CGVector(dx: direction.dx * speed, dy: direction.dy * speed)
        if knockbackRemaining > 0 {
            knockbackRemaining -= dt
            v.dx += knockbackVelocity.dx
            v.dy += knockbackVelocity.dy
        }
        physicsBody?.velocity = v
        animator.setMotion(speed01: magnitude, moveDX: direction.dx)
    }

    /// Pushes the hero `hero.knockbackDistance` along `direction` over `hero.knockbackSec`.
    func knockBack(along direction: CGVector) {
        let len = hypot(direction.dx, direction.dy)
        guard len > 0, def.knockbackSec > 0 else { return }
        let speed = CGFloat(def.knockbackDistance / def.knockbackSec)
        knockbackVelocity = CGVector(dx: direction.dx / len * speed, dy: direction.dy / len * speed)
        knockbackRemaining = def.knockbackSec
    }

    func clearKnockback() {
        knockbackRemaining = 0
        knockbackVelocity = .zero
        physicsBody?.velocity = .zero
    }

    func tick(dt: Double) {
        health.tick(dt: dt)
        weapon.tick(dt: dt, loadout: &loadout)
        status.tick(dt: dt)
        updateSlowLook()
        animator.setBlinking(health.isInvulnerable)
        animator.update(dt: dt)
    }
}
