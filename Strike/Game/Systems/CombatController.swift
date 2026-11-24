import SpriteKit
import UIKit

/// Shots and damage in the running scene: the hero's trigger and blaster fire (aim assist,
/// jitter, pellets), projectile flight, physics contacts, enemy hits and power-down with loot,
/// crates, enemy shots (laser balls, spores, boss stars) and every hit on the hero (0 HP hands
/// over to `RescueController`). Boss hits go to `BossDirector`.
/// Split out of `GameScene` in M4-3 with no behaviour change.
@MainActor
final class CombatController {
    unowned let scene: GameScene

    private var pendingHits: [(ProjectileNode, SKNode?)] = []
    private var wasReloading = false
    private var wasTriggerHeld = false

    /// Safety cap on pickup nodes per drop entry.
    private static let maxNodesPerDrop = 12

    init(scene: GameScene) {
        self.scene = scene
    }

    // MARK: Hero fire

    /// After the hero moved: trigger, auto-fire, empty click and the reload sound.
    func updateTrigger(fireHeld held: Bool) {
        let hero = scene.hero
        let pressed = held && !wasTriggerHeld
        wasTriggerHeld = held
        if hero.tryFire(triggerHeld: held) {
            fire()
            if hero.magazine == 0 { scene.pixelBrain.handle(.magazineEmpty) }
        } else if pressed, hero.magazine == 0, !hero.weapon.isReloading {
            // Trigger pulled with nothing to fire and nothing to reload.
            scene.audio?.play(.emptyClick)
        }
        let reloading = hero.weapon.isReloading
        if reloading, !wasReloading { scene.audio?.play(.reload) }
        wasReloading = reloading
    }

    private func fire() {
        let hero = scene.hero, data = scene.data
        let w = hero.weapon.def
        var angle = scene.aimAngle
        if scene.aimAssistEnabled {
            let origin = hero.position
            let grid = scene.solidGrid
            angle = AimAssist.adjust(
                stickAngle: scene.aimAngle, origin: origin,
                targets: scene.enemyDirector.activeEnemies.map(\.position),
                coneDeg: CGFloat(w.aimAssistConeDeg), range: CGFloat(w.range),
                strength: CGFloat(data.controls.aimAssistStrength),
                hasLineOfSight: { grid.hasLineOfSight(from: origin, to: $0) })
        }
        let shot = WeaponFire.shot(def: w, aimAngle: angle, rng: scene.random)
        angle = shot.center
        let texture = Textures.texture(w.projectileTextureName, in: .items)
        let muzzle = hero.muzzlePoint(angle: angle)
        for a in shot.angles {
            _ = scene.pool.spawn(weapon: w, texture: texture, at: muzzle, angle: a, in: scene.worldNode)
        }
        hero.animator.playRecoil(angle: angle)
        scene.audio?.play(.shot(weaponId: w.id))
        scene.worldNode.addChild(Particles.muzzle(color: Palette.projectile(style: w.projectileStyle), at: muzzle, angle: angle))
    }

    func updateProjectiles(dt: Double) {
        var expired: [ProjectileNode] = []
        scene.pool.forEachActive { p in
            if !p.step(dt: dt) { expired.append(p) }
        }
        expired.forEach(scene.pool.recycle)
    }

    // MARK: Contacts (shots)

    func didBegin(_ contact: SKPhysicsContact) {
        let a = contact.bodyA.node, b = contact.bodyB.node
        if let p = a as? ProjectileNode { pendingHits.append((p, b)) }
        else if let p = b as? ProjectileNode { pendingHits.append((p, a)) }
    }

    /// Resolves the contacts collected during the physics step.
    func resolveHits() {
        guard !pendingHits.isEmpty else { return }
        let hits = pendingHits
        pendingHits.removeAll(keepingCapacity: true)
        for (shot, target) in hits where shot.isActive { resolve(shot, target: target) }
    }

    /// One shot touching `target` (an enemy, crate or wall). Shots pass through powered-down
    /// enemies and popping slime children; everything else ends the shot.
    func resolve(_ shot: ProjectileNode, target: SKNode?) {
        let world = scene.worldNode
        let color = Palette.projectile(style: shot.style)
        if let enemy = target as? EnemyNode {
            guard !enemy.isPoweredDown, enemy.isDamageable else { return }
            if enemy.isBoss, let boss = scene.bossDirector {
                boss.hit(with: shot)
            } else {
                hitEnemy(enemy, with: shot)
            }
        } else if let crate = target as? CrateNode {
            guard !crate.isBroken else { return }
            world.addChild(Particles.hitSparkle(color: color, at: shot.position, shotAngle: shot.angle, small: true))
            if crate.hit(damage: shot.damage) { breakCrate(crate) }
        } else {
            world.addChild(Particles.hitSparkle(color: color, at: shot.position, shotAngle: shot.angle, small: true))
        }
        scene.pool.recycle(shot)
    }

    private func hitEnemy(_ enemy: EnemyNode, with shot: ProjectileNode) {
        let dir = CGVector(dx: cos(shot.angle), dy: sin(shot.angle))
        if enemy.blocksShot(angle: shot.angle) {
            // ART_BIBLE §15.2: the shot bounces off as sparkles, no damage, no flinch.
            scene.worldNode.addChild(EnemyFX.shieldBounce(at: shot.position, shotAngle: shot.angle))
            return
        }
        scene.worldNode.addChild(Particles.hitSparkle(color: Palette.projectile(style: shot.style),
                                                      at: shot.position, shotAngle: shot.angle,
                                                      small: shot.style == "foam"))
        let bonus = enemy.damageMultiplier > 1
        if bonus { scene.worldNode.addChild(Particles.stateOn(at: shot.position, color: .white, count: 5)) }
        let damage = DamageModel.finalDamage(base: shot.damage, dizzyMultiplier: enemy.damageMultiplier)
        switch enemy.health.applyDamage(damage) {
        case .ignored:
            return
        case .hit:
            enemy.knockBack(along: dir, distance: shot.knockback)
            enemy.animator.playHit(from: dir)
            scene.audio?.play(.enemyHit)
            if enemy.brain.currentState is IdleState { enemy.brain.enter(AlertState.self) }
        case .depleted:
            powerDown(enemy)
        }
    }

    private func powerDown(_ enemy: EnemyNode) {
        scene.session.addScore(enemy.def.scoreValue)
        scene.mediumHaptic.impactOccurred()
        scene.audio?.play(.enemyPowerDown)
        let origin = enemy.position
        scene.worldNode.addChild(Particles.poof(at: origin, bodyColors: Self.poofColors(enemy.def.id), darkFloor: scene.darkFloor))
        var drops = LootRoller.roll(tableId: enemy.def.lootTableId, data: scene.data, context: lootContext, random: scene.random)
        // A core carrier drops its core for sure (GDD §9); the boss counts it as in flight meanwhile.
        let carried = enemy.carriesItem
        if let item = carried { drops.append(LootDrop(itemId: item, count: 1)) }
        scene.bossDirector?.spawnPoweredDown(enemy)
        // Slime split (GDD §8.1): the children pop out of the body.
        scene.enemyDirector.split(enemy)
        enemy.powerDown { [weak self, weak enemy] in
            guard let self, let enemy else { return }
            self.spawnLoot(drops, at: origin)
            if carried != nil { self.scene.bossDirector?.coreLanded() }
            self.scene.enemyDirector.remove(enemy)
        }
    }

    /// Poof v2 chip colours per enemy family (ART_BIBLE §14.9): robots silver, slimes green, spores pink.
    static func poofColors(_ enemyId: String) -> [SKColor] {
        if enemyId.hasPrefix("slime") { return [Palette.hex(0x6FE06A), Palette.hex(0x8CF07F)] }
        if enemyId.hasPrefix("spore") { return [Palette.hex(0xE36BD8), Palette.hex(0xFFB3F2)] }
        return [Palette.robotMetal, Palette.robotMetalLight]
    }

    private func breakCrate(_ crate: CrateNode) {
        scene.audio?.play(.crateBreak)
        scene.worldNode.addChild(Particles.poof(at: crate.position, bodyColors: [Palette.star, Palette.robotMetalLight],
                                                darkFloor: scene.darkFloor))
        let drops = LootRoller.roll(tableId: crate.lootTableId, data: scene.data, context: lootContext, random: scene.random)
        spawnLoot(drops, at: crate.position)
    }

    var lootContext: LootContext {
        let hero = scene.hero
        let w = hero.weapon
        let cap = max(1, w.def.magazineSize + w.def.reserveMax)
        return LootContext(level: scene.levelDef.index, heroHpRatio: hero.health.ratio,
                           equippedWeaponId: w.def.id,
                           equippedAmmoRatio: Double(hero.totalAmmo) / Double(cap),
                           equippedAmmoTotal: hero.totalAmmo,
                           ownedWeaponIds: Set(hero.loadout.owned))
    }

    // MARK: Loot

    func spawnLoot(_ drops: [LootDrop], at origin: CGPoint) {
        for drop in drops {
            guard let item = scene.data.items[drop.itemId] else { continue }
            for _ in 0..<min(drop.count, Self.maxNodesPerDrop) {
                scene.interaction.addPickup(PickupNode(item: item, from: origin, to: popTarget(from: origin)))
            }
        }
    }

    private func popTarget(from origin: CGPoint) -> CGPoint {
        let clearance: CGFloat = 12
        for _ in 0..<8 {
            let a = CGFloat(scene.random.nextUniform()) * 2 * .pi
            let d = CGFloat(scene.random.nextUniform()) * PickupNode.maxPopDistance
            let p = CGPoint(x: origin.x + cos(a) * d, y: origin.y + sin(a) * d)
            if !scene.solidGrid.isBlocked(p, radius: clearance) { return p }
        }
        return origin
    }

    // MARK: Hero damage

    func checkContactDamage() {
        let hero = scene.hero
        guard !hero.health.isInvulnerable else { return }
        for e in scene.enemies where !e.isPoweredDown && !e.isHarmless && e.contactDamageNow > 0 {
            let dx = hero.position.x - e.position.x, dy = hero.position.y - e.position.y
            guard hypot(dx, dy) < hero.radius + e.radius else { continue }
            if hurtHero(e.contactDamageNow, from: e.position) { return }
        }
    }

    /// Any damage to the hero (contact, enemy shot, boss attack). Returns true when it landed.
    @discardableResult
    func hurtHero(_ amount: Int, from source: CGPoint) -> Bool {
        let hero = scene.hero
        guard scene.rescue == nil, amount > 0 else { return false }
        let dir = CGVector(dx: hero.position.x - source.x, dy: hero.position.y - source.y)
        switch hero.health.applyDamage(amount) {
        case .ignored:
            return false
        case .hit:
            hero.knockBack(along: dir)
            hero.animator.playHit(from: dir)
            scene.worldNode.addChild(Particles.heroHit(at: hero.position))
            scene.lightHaptic.impactOccurred()
            scene.audio?.play(.heroHurt)
        case .depleted:
            scene.lightHaptic.impactOccurred()
            scene.rescueController.begin()
        }
        return true
    }

    // MARK: Enemy shots (GDD §8: big, slow, colourful; stop at walls)

    func fireEnemyShots(from e: EnemyNode, angles: [CGFloat], attack a: EnemyAttackDef) {
        let kind: EnemyProjectileNode.Kind = a.slowMultiplier != nil ? .spore : .laser
        let muzzle = e.radius + 6
        for angle in angles {
            let p = CGPoint(x: e.position.x + cos(angle) * muzzle, y: e.position.y + sin(angle) * muzzle)
            spawnEnemyShot(kind: kind, at: p, angle: angle, speed: CGFloat(a.projectileSpeed ?? 200),
                           radius: CGFloat(a.projectileRadius ?? 10), damage: a.damage, range: CGFloat(a.range),
                           slowMultiplier: a.slowMultiplier, slowSec: a.slowSec)
        }
        scene.audio?.play(.enemyShot)
    }

    func spawnEnemyShot(kind: EnemyProjectileNode.Kind, at p: CGPoint, angle: CGFloat, speed: CGFloat, radius: CGFloat,
                        damage: Int, range: CGFloat, slowMultiplier: Double? = nil, slowSec: Double? = nil) {
        let glow = scene.darkFloor, world = scene.worldNode
        _ = scene.enemyShots.spawn(in: world) {
            $0.activate(kind: kind, at: p, angle: angle, speed: speed, radius: radius, damage: damage, range: range,
                        slowMultiplier: slowMultiplier, slowSec: slowSec, glow: glow, world: world)
        }
    }

    func updateEnemyShots(dt: Double) {
        let hero = scene.hero, grid = scene.solidGrid
        var done: [(EnemyProjectileNode, Bool)] = []
        scene.enemyShots.forEachActive { s in
            guard s.step(dt: dt) else { done.append((s, false)); return }
            if grid.isBlocked(s.position, radius: s.radius * 0.5) { done.append((s, true)); return }
            let d = hypot(hero.position.x - s.position.x, hero.position.y - s.position.y)
            guard d < hero.radius + s.radius, scene.rescue == nil else { return }
            if hurtHero(s.damage, from: s.position), let m = s.slowMultiplier, let sec = s.slowSec {
                hero.applySlow(multiplier: m, sec: sec)
                scene.pixelDirector.heroSlowed()
            }
            done.append((s, true))
        }
        for (s, pop) in done {
            if pop { scene.worldNode.addChild(s.popEffect()) }
            scene.enemyShots.recycle(s)
        }
    }

    /// `debug.damageHero`: ignores the invulnerability window (rebuilds Health at the target HP).
    func damageHero(_ amount: Int) {
        guard scene.rescue == nil else { return }
        let hero = scene.hero
        let target = max(0, hero.health.current - max(0, amount))
        hero.health = Health(max: hero.health.max, invulnerableSec: hero.health.invulnerableSec)
        if target < hero.health.max { _ = hero.health.applyDamage(hero.health.max - target) }
        scene.hud.pushHUD()
        if hero.health.isDepleted { scene.rescueController.begin() }
    }
}
