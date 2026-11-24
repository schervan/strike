import XCTest

/// M3-6: intro card → quick slot Q1 (start-gift heal pack) → damage → Q1 heals → bag → tidy →
/// close → rescue → relaunch → Continue. Saves the M3 screenshots to the scratchpad.
final class StrikeInventoryUITests: XCTestCase {
    static let shotDir = "/private/tmp/claude-503/-Users-flyingbull-Developer-Strike/8a9e170c-024e-4dbc-b225-45e9eb286ba8/scratchpad"

    override func setUp() { continueAfterFailure = false }

    private func shot(_ name: String) {
        let s = XCUIScreen.main.screenshot()
        let a = XCTAttachment(screenshot: s)
        a.name = name
        a.lifetime = .keepAlways
        add(a)
        try? s.pngRepresentation.write(to: URL(fileURLWithPath: "\(Self.shotDir)/\(name).png"))
    }

    private func hp(_ app: XCUIApplication) -> Int {
        let v = app.descendants(matching: .any)["hud.hpBar"].value as? String ?? ""
        return Int(v.split(separator: " ").first ?? "") ?? -1
    }

    @MainActor
    func testQuickSlotInventoryRescueAndContinue() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments += ["-StrikeLevel", "l1", "-StrikeSeed", "42", "-StrikeFreshSave"]
        app.launch()

        let newGame = app.buttons["title.newGame"]
        XCTAssertTrue(newGame.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["title.continue"].exists, "fresh save: no Continue")
        newGame.tap()

        let intro = app.descendants(matching: .any)["levelIntro.view"]
        XCTAssertTrue(intro.waitForExistence(timeout: 10))
        intro.tap()
        XCTAssertTrue(intro.waitForNonExistence(timeout: 5))

        // Start gift: Q1 = heal pack × 1 (GDD §7 auto-assign), Q2 = apples.
        let q1 = app.buttons["hud.quickSlot.0"]
        XCTAssertTrue(q1.waitForExistence(timeout: 5))
        XCTAssertEqual(q1.value as? String, "1")
        XCTAssertGreaterThanOrEqual(q1.frame.width, 64)
        XCTAssertEqual(app.buttons["hud.quickSlot.1"].value as? String, "2")

        // Pixel's first line in the top-centre bubble.
        let bubble = app.descendants(matching: .any)["pixel.bubble"]
        if !bubble.waitForExistence(timeout: 5) { print("HIERARCHY\n\(app.debugDescription)") }
        XCTAssertTrue(bubble.exists)
        shot("m3_pixel")

        // Damage, then Q1 heals and the count drops to 0 (link stays).
        let full = hp(app)
        app.buttons["debug.damageHero"].tap()
        let hurt = hp(app)
        XCTAssertLessThan(hurt, full)
        q1.tap()
        let deadline = Date().addingTimeInterval(3)
        while q1.value as? String != "0", Date() < deadline { usleep(100_000) }
        XCTAssertEqual(q1.value as? String, "0")
        XCTAssertGreaterThan(hp(app), hurt)

        // Bag: open from the HUD, tidy, close.
        app.buttons["hud.inventoryButton"].tap()
        let inv = app.descendants(matching: .any)["inventory.view"]
        XCTAssertTrue(inv.waitForExistence(timeout: 5))
        // The used heal pack left slot 0 empty; Tidy moves the apples to the front.
        app.buttons["inventory.tidy"].tap()
        let slot0 = app.buttons["inventory.slot.0"]
        XCTAssertTrue(slot0.exists)
        XCTAssertEqual(slot0.value as? String, "food_apple 2")
        slot0.tap()
        XCTAssertTrue(app.buttons["inventory.drop"].waitForExistence(timeout: 3))
        XCTAssertGreaterThanOrEqual(app.buttons["inventory.drop"].frame.height, 64)
        XCTAssertTrue(app.buttons["inventory.use"].exists)
        shot("m3_inventory")
        app.buttons["inventory.close"].tap()
        XCTAssertTrue(inv.waitForNonExistence(timeout: 5))

        // Pause menu has Inventory.
        app.buttons["menuButton"].tap()
        XCTAssertTrue(app.buttons["pause.inventory"].waitForExistence(timeout: 5))
        app.buttons["pause.resume"].tap()

        // Rescue: drop to 0 HP, catch the beam.
        for _ in 0..<4 { app.buttons["debug.damageHero"].tap() }
        usleep(600_000)
        shot("m3_rescue")
        sleep(3)
        XCTAssertEqual(hp(app), 100, "rescued with full HP")

        // Relaunch without -StrikeFreshSave: Continue exists.
        app.terminate()
        let again = XCUIApplication()
        again.launch()
        XCTAssertTrue(again.buttons["title.continue"].waitForExistence(timeout: 10))
        again.buttons["title.continue"].tap()
        let intro2 = again.descendants(matching: .any)["levelIntro.view"]
        XCTAssertTrue(intro2.waitForExistence(timeout: 10))
        intro2.tap()
        let q1b = again.buttons["hud.quickSlot.0"]
        XCTAssertTrue(q1b.waitForExistence(timeout: 5))
        // The used heal pack stays used (the start gift tops it back up to 1 on level start).
        XCTAssertEqual(q1b.value as? String, "1")
    }
}
