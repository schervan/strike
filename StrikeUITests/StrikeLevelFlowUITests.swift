import XCTest

/// M2-6: title → L1 (seed 42) → debug solve → exit pad → Level complete → Continue → L2.
final class StrikeLevelFlowUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    @MainActor
    func testLevelFlowL1ToL2() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments += ["-StrikeFreshSave"]
        app.launchArguments += ["-StrikeLevel", "l1", "-StrikeSeed", "42"]
        app.launch()

        let start = app.buttons["title.newGame"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        start.tap()
        let intro = app.descendants(matching: .any)["levelIntro.view"]
        if intro.waitForExistence(timeout: 5) { intro.tap() }

        XCTAssertTrue(app.descendants(matching: .any)["gameView"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["hud.minimap"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["hud.interactButton"].waitForExistence(timeout: 5))
        let seed = app.staticTexts["debug.seed"]
        XCTAssertTrue(seed.waitForExistence(timeout: 5))
        XCTAssertTrue(seed.label.hasPrefix("l1"), seed.label)
        XCTAssertTrue(seed.label.hasSuffix("42"), seed.label)

        app.buttons["debug.solveAll"].tap()
        app.buttons["debug.gotoExit"].tap()

        let card = app.descendants(matching: .any)["levelComplete.view"]
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        let next = app.buttons["levelComplete.continue"]
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        next.tap()

        XCTAssertTrue(app.descendants(matching: .any)["gameView"].waitForExistence(timeout: 10))
        let seed2 = app.staticTexts["debug.seed"]
        XCTAssertTrue(seed2.waitForExistence(timeout: 5))
        XCTAssertTrue(seed2.label.hasPrefix("l2"), seed2.label)
    }
}
