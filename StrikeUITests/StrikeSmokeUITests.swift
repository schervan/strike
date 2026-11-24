import XCTest

final class StrikeSmokeUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchTapStartShowsGameView() {
        let app = XCUIApplication()
        app.launchArguments += ["-StrikeFreshSave"]
        app.launch()

        let start = app.buttons["title.newGame"]
        XCTAssertTrue(start.waitForExistence(timeout: 10), "Start button should be visible on the title screen")
        start.tap()
        let intro = app.descendants(matching: .any)["levelIntro.view"]
        if intro.waitForExistence(timeout: 5) { intro.tap() }

        let gameView = app.descendants(matching: .any)["gameView"]
        XCTAssertTrue(gameView.waitForExistence(timeout: 10), "Game view should appear after tapping Start")
        XCTAssertFalse(start.exists, "Title screen should be gone")
    }
}
