import XCTest

final class StrikeCoreLoopUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testStartShowsHUDAndReloadDoesNotCrash() {
        let app = XCUIApplication()
        app.launch()

        let start = app.buttons["startButton"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        start.tap()

        let gameView = app.descendants(matching: .any)["gameView"]
        XCTAssertTrue(gameView.waitForExistence(timeout: 10))

        let hp = app.descendants(matching: .any)["hud.hpBar"]
        XCTAssertTrue(hp.waitForExistence(timeout: 5))

        let ammo = app.descendants(matching: .any)["hud.ammoLabel"]
        XCTAssertTrue(ammo.waitForExistence(timeout: 5))
        XCTAssertEqual(ammo.value as? String, "12 / 48")

        let reload = app.buttons["hud.reloadButton"]
        XCTAssertTrue(reload.waitForExistence(timeout: 5))
        reload.tap()
        XCTAssertTrue(gameView.exists)

        // Drag on the aim side to fire a few shots, then reload for real.
        let aimStart = app.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.7))
        let aimEnd = app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.7))
        aimStart.press(forDuration: 0.1, thenDragTo: aimEnd, withVelocity: .slow, thenHoldForDuration: 1.0)
        reload.tap()
        XCTAssertTrue(gameView.exists)
        XCTAssertTrue(hp.exists)
    }
}
