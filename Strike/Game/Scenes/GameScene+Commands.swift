import SpriteKit

/// `GameCommand`s from the SwiftUI HUD, the pause menu, Settings and the debug overlay.
extension GameScene {
    func handle(_ command: GameCommand) {
        switch command {
        case .reload:
            hero.startReload()
        case .interact:
            interaction.interact()
        case .debugSolveAll:
            interaction.solveAll()
        case .debugGotoExit:
            hero.clearKnockback()
            hero.position = built.exitPad.position
            snapCamera()
        case .debugRevealMap:
            hud.revealAll()
            hud.pushMinimap(force: true)
        case .resetInput:
            resetTouches()
            hero.drive(direction: .zero, magnitude: 0, dt: 0)
        case .useQuick(let i):
            interaction.useItem(quickSlot: i, slot: nil)
        case .useItem(let slot):
            interaction.useItem(quickSlot: nil, slot: slot)
        case .dropItem(let slot, let count):
            interaction.dropItem(slot: slot, count: count)
        case .assignQuick(let itemId, let slot):
            inventory.assignQuick(itemId: itemId, to: slot)
        case .tidy:
            inventory.tidy()
        case .dismissBubble:
            pixelBrain.dismiss()
        case .debugSpawnCrowd:
            enemyDirector.spawnCrowd()
        case .debugDamageHero:
            combat.damageHero(Self.debugDamage)
        case .debugGiveBlasters:
            for id in weaponOrder { if let w = data.weapons[id] { hero.loadout.addWeapon(w) } }
        case .debugBossArena:
            interaction.debugEnterArena()
        case .debugBossNextPhase:
            bossDirector?.debugNextPhase()
        case .debugSpawn(let id):
            enemyDirector.debugSpawn(id)
        case .swapNext:
            if let id = hero.loadout.nextWeaponId(order: weaponOrder) { swap(to: id) }
        case .swapTo(let id):
            swap(to: id)
        case .settingsChanged:
            if let s = model?.progress.settings {
                aimAssistEnabled = s.aimAssist
                pixelBrain.setTalk(s.pixelTalk)
            }
        }
        hud.pushHUD()
        hud.pushBag()
    }

    /// SWAP / wheel pick (GDD §5.1): `swapSec` with no fire, a running reload is cancelled.
    func swap(to weaponId: String) {
        guard rescue == nil, !hero.weapon.isSwapping, let w = data.weapons[weaponId],
              hero.swap(to: w, swapSec: data.rules.weapons.swapSec) else { return }
        audio?.play(.reload)
        worldNode.addChild(Particles.stateOn(at: hero.position, color: Palette.projectile(style: w.projectileStyle), count: 4))
    }

}
