import XCTest

/// M2-7 simulator pass: launch args pick the level/seed, real drags move the hero, debug buttons shortcut the puzzle.
final class StrikeM2PassUITests: XCTestCase {
    static let dir = "/private/tmp/claude-503/-Users-flyingbull-Developer-Strike/8a9e170c-024e-4dbc-b225-45e9eb286ba8/scratchpad"

    override func setUp() { continueAfterFailure = true }

    private func shot(_ name: String) {
        let s = XCUIScreen.main.screenshot()
        let a = XCTAttachment(screenshot: s); a.name = name; a.lifetime = .keepAlways; add(a)
        try? s.pngRepresentation.write(to: URL(fileURLWithPath: "\(Self.dir)/qa_m2_\(name).png"))
    }

    private func launch(_ level: String, seed: Int) -> XCUIApplication {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments += ["-StrikeAutoStart", "-StrikeLevel", level, "-StrikeSeed", String(seed)]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["gameView"].waitForExistence(timeout: 15))
        return app
    }

    private func el(_ app: XCUIApplication, _ id: String) -> XCUIElement { app.descendants(matching: .any)[id] }

    @MainActor
    func testL1AndL3FlowToLevelComplete() {
        for (level, seed) in [("l1", 11), ("l3", 3333)] {
            let app = launch(level, seed: seed)
            XCTAssertEqual(el(app, "debug.seed").label.hasPrefix(level), true, "debug label \(el(app, "debug.seed").label)")
            sleep(1)
            shot("\(level)_1_start")

            // Real movement: left-zone drag, hero must move (screenshots differ).
            let m0 = app.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.6))
            let m1 = app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.6))
            m0.press(forDuration: 0.1, thenDragTo: m1, withVelocity: .slow, thenHoldForDuration: 1.2)
            shot("\(level)_2_moved")

            let interact = app.buttons["hud.interactButton"]
            XCTAssertTrue(interact.exists, "INTERACT button should be on screen")
            XCTAssertGreaterThanOrEqual(interact.frame.width, 60, "interact touch target >= 60 pt")

            el(app, "debug.revealMap").tap()
            sleep(1)
            shot("\(level)_3_map")
            XCTAssertTrue(el(app, "hud.minimap").exists, "minimap present")

            el(app, "debug.solveAll").tap()
            sleep(1)
            shot("\(level)_4_all_on")
            el(app, "debug.gotoExit").tap()
            let card = el(app, "levelComplete.view")
            XCTAssertTrue(card.waitForExistence(timeout: 6), "Level complete card should appear on the exit pad")
            shot("\(level)_5_complete")
            let cont = app.buttons["levelComplete.continue"]
            XCTAssertTrue(cont.exists)
            XCTAssertGreaterThanOrEqual(cont.frame.height, 60)
            cont.tap()
            let next = level == "l1" ? "l2" : "l4"
            XCTAssertTrue(el(app, "debug.seed").waitForExistence(timeout: 8))
            XCTAssertTrue(el(app, "debug.seed").label.hasPrefix(next), "Continue should lead to \(next), got \(el(app, "debug.seed").label)")
            sleep(1)
            shot("\(level)_6_next_\(next)")
            app.terminate()
        }
    }

    @MainActor
    func testL4HeavyRoomFPS() {
        let app = launch("l4", seed: 77)
        el(app, "debug.revealMap").tap()
        let a0 = app.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.6))
        let a1 = app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))
        // Fire for a few seconds, shot taken on a second thread so the HUD node/fps text is captured mid-fight.
        DispatchQueue.global().asyncAfter(deadline: .now() + 3.0) {
            let s = XCUIScreen.main.screenshot()
            try? s.pngRepresentation.write(to: URL(fileURLWithPath: "\(Self.dir)/qa_m2_l4_fight.png"))
        }
        a0.press(forDuration: 0.1, thenDragTo: a1, withVelocity: .slow, thenHoldForDuration: 5.0)
        shot("l4_after")
    }
}
