import XCTest

/// M3-7 simulator pass: quick slots, Pixel tap hint, save + kill app + Continue, de/en screens, L4 crowd.
final class StrikeM3PassUITests: XCTestCase {
    static let dir = "/private/tmp/claude-503/-Users-flyingbull-Developer-Strike/8a9e170c-024e-4dbc-b225-45e9eb286ba8/scratchpad"

    override func setUp() { continueAfterFailure = true }

    @MainActor private func shot(_ name: String) {
        let s = XCUIScreen.main.screenshot()
        let a = XCTAttachment(screenshot: s); a.name = name; a.lifetime = .keepAlways; add(a)
        try? s.pngRepresentation.write(to: URL(fileURLWithPath: "\(Self.dir)/qa_m3_\(name).png"))
    }

    @MainActor private func el(_ app: XCUIApplication, _ id: String) -> XCUIElement { app.descendants(matching: .any)[id] }

    @MainActor private func hp(_ app: XCUIApplication) -> Int {
        Int((el(app, "hud.hpBar").value as? String ?? "").split(separator: " ").first ?? "") ?? -1
    }

    @MainActor private func launch(_ args: [String]) -> XCUIApplication {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments += args
        app.launch()
        return app
    }

    @MainActor private func startNewGame(_ app: XCUIApplication) {
        let n = app.buttons["title.newGame"]
        XCTAssertTrue(n.waitForExistence(timeout: 10))
        n.tap()
    }

    @MainActor private func dismissIntro(_ app: XCUIApplication, shotName: String? = nil) {
        let intro = el(app, "levelIntro.view")
        XCTAssertTrue(intro.waitForExistence(timeout: 10), "intro card")
        if let shotName { sleep(1); shot(shotName) }
        // The intro is several lines: tap until it is gone.
        for _ in 0..<8 where intro.exists { intro.tap(); usleep(500_000) }
        XCTAssertTrue(intro.waitForNonExistence(timeout: 5), "intro should close")
    }

    /// Quick slots, Pixel tap hint, level complete, kill the app, Continue.
    @MainActor
    func testSaveResumeQuickSlotsAndPixelHint() {
        let app = launch(["-StrikeLevel", "l1", "-StrikeSeed", "5", "-StrikeFreshSave"])
        startNewGame(app)
        dismissIntro(app, shotName: "en_intro")

        let q1 = app.buttons["hud.quickSlot.0"], q2 = app.buttons["hud.quickSlot.1"]
        XCTAssertTrue(q1.waitForExistence(timeout: 5))
        print("M3 start Q1=\(q1.value ?? "?") Q2=\(q2.value ?? "?") Q3=\(app.buttons["hud.quickSlot.2"].value ?? "?") Q4=\(app.buttons["hud.quickSlot.3"].value ?? "?")")
        XCTAssertEqual(q1.value as? String, "1"); XCTAssertEqual(q2.value as? String, "2")
        for i in 0..<4 { XCTAssertGreaterThanOrEqual(app.buttons["hud.quickSlot.\(i)"].frame.width, 60, "quick slot \(i) touch target") }
        shot("en_hud")

        // Quick slots: hurt, eat an apple (Q2), then the heal pack (Q1).
        app.buttons["debug.damageHero"].tap()
        let hurt = hp(app)
        q2.tap(); sleep(1)
        let afterApple = hp(app)
        print("M3 HP full->\(hurt) after apple \(afterApple), Q2 now \(q2.value ?? "?")")
        XCTAssertGreaterThan(afterApple, hurt); XCTAssertEqual(q2.value as? String, "1")
        app.buttons["debug.damageHero"].tap()
        q1.tap(); sleep(1)
        XCTAssertEqual(q1.value as? String, "0", "heal pack used up")
        shot("en_quick_used")

        // Pixel tap: Pixel floats up-left of the hero (about 0.42 / 0.52 of the screen in the shots).
        let tap = app.coordinate(withNormalizedOffset: CGVector(dx: 0.4225, dy: 0.524))
        tap.tap()
        let bubble = el(app, "pixel.bubble")
        let appeared = bubble.waitForExistence(timeout: 3)
        print("M3 Pixel tap -> bubble \(appeared): \(appeared ? bubble.label : "-")")
        sleep(1)
        shot("en_pixel_tap_hint")
        XCTAssertTrue(appeared, "tapping Pixel should show a hint line")

        // Finish the level with the debug shortcuts, then kill the app on the card.
        el(app, "debug.solveAll").tap()
        el(app, "debug.gotoExit").tap()
        XCTAssertTrue(el(app, "levelComplete.view").waitForExistence(timeout: 8))
        sleep(1)
        shot("en_complete")
        app.terminate()

        let again = launch([])
        let cont = again.buttons["title.continue"]
        XCTAssertTrue(cont.waitForExistence(timeout: 10), "Continue must exist after a completed level")
        shot("en_title_continue")
        cont.tap()
        dismissIntro(again, shotName: "en_l2_intro")
        XCTAssertTrue(el(again, "debug.seed").waitForExistence(timeout: 8))
        let seedLabel = el(again, "debug.seed").label
        print("M3 resumed at: \(seedLabel)")
        XCTAssertTrue(seedLabel.hasPrefix("l2"), "Continue should resume at L2, got \(seedLabel)")
        let rq1 = again.buttons["hud.quickSlot.0"], rq2 = again.buttons["hud.quickSlot.1"]
        XCTAssertTrue(rq1.waitForExistence(timeout: 5))
        print("M3 resumed Q1=\(rq1.value ?? "?") Q2=\(rq2.value ?? "?")")
        XCTAssertEqual(rq2.value as? String, "1", "the apple stack (2 - 1 eaten) must come back after relaunch")
        shot("en_l2_resumed")
        again.terminate()
    }

    /// German UI: intro card, HUD + Pixel bubble, inventory and pause screens (clipping check by eye).
    @MainActor
    func testGermanScreens() {
        let app = launch(["-StrikeLevel", "l1", "-StrikeSeed", "5", "-StrikeFreshSave", "-AppleLanguages", "(de)", "-AppleLocale", "de_DE"])
        startNewGame(app)
        dismissIntro(app, shotName: "de_intro")
        sleep(2)
        shot("de_hud_pixel")
        app.buttons["hud.inventoryButton"].tap()
        XCTAssertTrue(el(app, "inventory.view").waitForExistence(timeout: 5))
        app.buttons["inventory.slot.0"].tap()
        sleep(1)
        shot("de_inventory")
        app.buttons["inventory.close"].tap()
        app.buttons["menuButton"].tap()
        XCTAssertTrue(el(app, "pause.view").waitForExistence(timeout: 5))
        shot("de_pause")
        app.buttons["pause.resume"].tap()
        el(app, "debug.solveAll").tap()
        el(app, "debug.gotoExit").tap()
        XCTAssertTrue(el(app, "levelComplete.view").waitForExistence(timeout: 8))
        sleep(1)
        shot("de_complete")
        app.terminate()
    }

    @MainActor
    func testCrowdOnL4() {
        let app = launch(["-StrikeAutoStart", "-StrikeLevel", "l4", "-StrikeSeed", "7", "-StrikeFreshSave"])
        XCTAssertTrue(el(app, "gameView").waitForExistence(timeout: 15))
        let intro = el(app, "levelIntro.view")
        if intro.waitForExistence(timeout: 2) { for _ in 0..<8 where intro.exists { intro.tap(); usleep(400_000) } }
        shot("crowd_before")
        app.buttons["debug.spawnCrowd"].tap()
        sleep(2)
        shot("crowd_2s")
        let a0 = app.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.65))
        let a1 = app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.6))
        a0.press(forDuration: 0.1, thenDragTo: a1, withVelocity: .slow, thenHoldForDuration: 8)
        shot("crowd_fight")
        sleep(2)
        shot("crowd_after")
        app.terminate()
    }
}
