import XCTest

/// M1-11 manual-style play pass: simulated touches on both halves of the screen, HUD readouts and screenshots.
final class StrikePlayPassUITests: XCTestCase {
    static let shotDir = "/private/tmp/claude-503/-Users-flyingbull-Developer-Strike/8a9e170c-024e-4dbc-b225-45e9eb286ba8/scratchpad"

    override func setUp() { continueAfterFailure = true }

    @MainActor private func shot(_ name: String) {
        let s = XCUIScreen.main.screenshot()
        let a = XCTAttachment(screenshot: s)
        a.name = name; a.lifetime = .keepAlways
        add(a)
        try? s.pngRepresentation.write(to: URL(fileURLWithPath: "\(Self.shotDir)/qa_\(name).png"))
    }

    @MainActor private func value(_ app: XCUIApplication, _ id: String) -> String {
        (app.descendants(matching: .any)[id].value as? String) ?? "?"
    }

    @MainActor
    func testPlayPass() {
        // Without this the simulator injects touches rotated 90 degrees from the landscape-only app.
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments += ["-StrikeAutoStart"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["gameView"].waitForExistence(timeout: 10))
        let hp0 = value(app, "hud.hpBar"), ammo0 = value(app, "hud.ammoLabel")
        print("PLAY start hp=\(hp0) ammo=\(ammo0)")
        shot("1_start")

        // Move: left half drag.
        let l0 = app.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.6))
        let l1 = app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5))
        l0.press(forDuration: 0.1, thenDragTo: l1, withVelocity: .slow, thenHoldForDuration: 1.5)
        shot("2_moved")

        // Aim/fire: right half drag held. Ammo must drop.
        let r0 = app.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.6))
        let r1 = app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.45))
        r0.press(forDuration: 0.1, thenDragTo: r1, withVelocity: .slow, thenHoldForDuration: 1.2)
        let ammo1 = value(app, "hud.ammoLabel")
        print("PLAY after fire ammo=\(ammo1)")
        shot("3_firing")
        XCTAssertNotEqual(ammo0, ammo1, "firing did not change ammo")

        // Manual reload.
        app.buttons["hud.reloadButton"].tap()
        sleep(2)
        print("PLAY after reload ammo=\(value(app, "hud.ammoLabel"))")

        // Alternate move toward enemies and fire in several directions for ~40 s; track HP.
        var minHp = 999
        var respawned = false
        var lastHp = Int(hp0.split(separator: " ").first ?? "0") ?? 0
        let dirs: [(CGFloat, CGFloat)] = [(0.9, 0.3), (0.9, 0.8), (0.6, 0.8), (0.6, 0.3), (0.95, 0.55)]
        for i in 0..<20 {
            let d = dirs[i % dirs.count]
            let e = app.coordinate(withNormalizedOffset: CGVector(dx: d.0, dy: d.1))
            r0.press(forDuration: 0.05, thenDragTo: e, withVelocity: .slow, thenHoldForDuration: 2.0)
            if i % 3 == 0 {
                let m = app.coordinate(withNormalizedOffset: CGVector(dx: 0.1 + 0.1 * CGFloat(i % 4), dy: 0.7))
                l0.press(forDuration: 0.05, thenDragTo: m, withVelocity: .slow, thenHoldForDuration: 1.0)
            }
            let hp = Int(value(app, "hud.hpBar").split(separator: " ").first ?? "0") ?? 0
            if hp > lastHp { respawned = respawned || lastHp < 30 }
            minHp = min(minHp, hp); lastHp = hp
            print("PLAY t\(i) hp=\(value(app, "hud.hpBar")) ammo=\(value(app, "hud.ammoLabel"))")
            if i == 2 { shot("4_fight") }
            if i == 6 { app.buttons["hud.reloadButton"].tap() }
            if i == 10 { shot("4b_mid") }
        }
        shot("5_later")
        print("PLAY minHp=\(minHp) respawnSeen=\(respawned)")

        // Idle until enemies hurt the hero (contact damage / respawn).
        for i in 0..<10 {
            sleep(4)
            let hp = Int(value(app, "hud.hpBar").split(separator: " ").first ?? "0") ?? 0
            print("PLAY idle\(i) hp=\(value(app, "hud.hpBar"))")
            if hp > lastHp && lastHp <= 20 { respawned = true }
            minHp = min(minHp, hp); lastHp = hp
        }
        shot("6_idle")
        print("PLAY final minHp=\(minHp) respawnSeen=\(respawned)")
    }
}
