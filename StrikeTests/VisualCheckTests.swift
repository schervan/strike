import SpriteKit
import Testing
import UIKit
@testable import Strike

/// M2-7 visual leftovers: renders the alert "!" and the power-down sparkles from a real scene to PNGs
/// in the scratchpad so QA can look at them (no assertions on pixels, only that something rendered).
@MainActor
struct VisualCheckTests {
    static let dir = "/private/tmp/claude-503/-Users-flyingbull-Developer-Strike/8a9e170c-024e-4dbc-b225-45e9eb286ba8/scratchpad"

    static func png(_ view: SKView, _ node: SKNode, crop: CGRect, name: String) {
        guard let tex = view.texture(from: node, crop: crop) else { return }
        let ui = UIImage(cgImage: tex.cgImage())
        if let data = ui.pngData() { try? data.write(to: URL(fileURLWithPath: "\(dir)/qa_m2_\(name).png")) }
    }

    static func spin(_ sec: Double) { RunLoop.main.run(until: Date().addingTimeInterval(sec)) }

    @Test func alertBubbleAndPowerDownRender() throws {
        let data = try TestData.load()
        let def = try #require(data.levels["l1"])
        let scene = GameScene(data: data, level: def, seed: 11)
        let view = SKView(frame: CGRect(origin: .zero, size: GameScene.logicalSize))
        view.presentScene(scene)
        scene.hero.health.reset(invulnerableFor: 1_000_000)
        let enemy = try #require(scene.enemies.first { $0.def.id == "boltbot" })
        // Put the hero 220 pt away with line of sight.
        let offsets: [CGPoint] = [CGPoint(x: 220, y: 0), CGPoint(x: -220, y: 0), CGPoint(x: 0, y: 220), CGPoint(x: 0, y: -220), CGPoint(x: 140, y: 0), CGPoint(x: -140, y: 0)]
        var placed = false
        for o in offsets {
            let p = CGPoint(x: enemy.position.x + o.x, y: enemy.position.y + o.y)
            if scene.solidGrid.isWalkable(scene.level.grid.cell(at: p)), scene.solidGrid.hasLineOfSight(from: enemy.position, to: p) {
                scene.hero.position = p; placed = true; break
            }
        }
        #expect(placed)
        let r = CGRect(x: enemy.position.x - 170, y: enemy.position.y - 130, width: 340, height: 260)
        // Alert: step until the enemy notices, then let the pop-in animation run for a moment.
        var stepped = 0
        while !(enemy.brain.currentState is AlertState), stepped < 20 { scene.step(dt: 0.02); stepped += 1 }
        #expect(enemy.brain.currentState is AlertState, "boltbot should alert when the hero is in range with line of sight")
        Self.spin(0.2)
        Self.png(view, scene.worldNode, crop: r, name: "alert")
        // Chase after the alert time.
        for _ in 0..<30 { scene.step(dt: 0.02) }
        #expect(enemy.brain.currentState is ChaseState || enemy.brain.currentState is HopState, "alert should lead to chase")
        Self.png(view, scene.worldNode, crop: r, name: "chase")

        // Power down: poof + enemy animation, as the scene does on a lethal hit.
        scene.hero.position = CGPoint(x: enemy.position.x + 150, y: enemy.position.y)
        let origin = enemy.position
        scene.worldNode.addChild(Particles.poof(at: origin))
        enemy.powerDown { }
        Self.spin(0.12)
        Self.png(view, scene.worldNode, crop: CGRect(x: origin.x - 130, y: origin.y - 110, width: 260, height: 220), name: "powerdown_a")
        Self.spin(0.25)
        Self.png(view, scene.worldNode, crop: CGRect(x: origin.x - 130, y: origin.y - 110, width: 260, height: 220), name: "powerdown_b")
        #expect(enemy.isPoweredDown)
    }

    /// Door lights/counter and the door opening, rendered from a real scene (L2: one gate, then the exit).
    @Test func doorsRender() throws {
        let data = try TestData.load()
        let def = try #require(data.levels["l2"])
        let scene = GameScene(data: data, level: def, seed: 11)
        let view = SKView(frame: CGRect(origin: .zero, size: GameScene.logicalSize))
        view.presentScene(scene)
        scene.hero.health.reset(invulnerableFor: 1_000_000)
        let level = scene.level
        let gate = try #require(level.gates.first)
        let door = try #require(scene.built.gates[gate.id])
        func crop(_ c: CGPoint, _ w: CGFloat = 360, _ h: CGFloat = 300) -> CGRect { CGRect(x: c.x - w / 2, y: c.y - h / 2, width: w, height: h) }
        Self.spin(0.3)
        Self.png(view, scene.worldNode, crop: crop(door.position), name: "gate_closed")
        let elId = try #require(gate.elementIds.first)
        let el = try #require(level.element(elId))
        #expect(ScenePlaythroughTests.walk(scene, to: ScenePlaythroughTests.near(el)))
        if let n = scene.built.interactables[el.id] {
            let dx = n.position.x - scene.hero.position.x, dy = n.position.y - scene.hero.position.y
            let d = hypot(dx, dy), want = 56 + n.reachPadding
            if d > want { scene.hero.position.x += dx / d * (d - want); scene.hero.position.y += dy / d * (d - want) }
        }
        ScenePlaythroughTests.settle(scene, seconds: 0.2)
        Self.png(view, scene.worldNode, crop: crop(scene.hero.position, 300, 260), name: "button_focus")
        scene.handle(.interact)
        ScenePlaythroughTests.settle(scene, seconds: 0.2)
        Self.spin(0.3)
        Self.png(view, scene.worldNode, crop: crop(scene.hero.position, 300, 260), name: "button_on")
        ScenePlaythroughTests.settle(scene, seconds: 1.3)   // pan time + opening
        Self.spin(1.0)
        Self.png(view, scene.worldNode, crop: crop(door.position), name: "gate_open")
        #expect(door.isOpen)
    }
}
