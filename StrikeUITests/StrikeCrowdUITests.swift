import XCTest

/// M3-5 performance check: L4 + `debug.spawnCrowd` (12 boltbots + 2 crates), fight for a while,
/// screenshot with the DEBUG FPS / node counter for the log.
final class StrikeCrowdUITests: XCTestCase {
    static let shotDir = "/private/tmp/claude-503/-Users-flyingbull-Developer-Strike/8a9e170c-024e-4dbc-b225-45e9eb286ba8/scratchpad"

    @MainActor
    func testCrowdOnL4() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments += ["-StrikeAutoStart", "-StrikeLevel", "l4", "-StrikeSeed", "7"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["gameView"].waitForExistence(timeout: 10))
        let crowd = app.buttons["debug.spawnCrowd"]
        XCTAssertTrue(crowd.waitForExistence(timeout: 5))
        crowd.tap()
        // Hold the aim stick (auto-fire) for a few seconds while the crowd attacks.
        let a0 = app.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.65))
        let a1 = app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.6))
        a0.press(forDuration: 0.1, thenDragTo: a1, withVelocity: .slow, thenHoldForDuration: 6)
        let s = XCUIScreen.main.screenshot()
        try? s.pngRepresentation.write(to: URL(fileURLWithPath: "\(Self.shotDir)/m3_crowd_l4.png"))
        XCTAssertTrue(app.descendants(matching: .any)["gameView"].exists)
    }
}
