import XCTest

/// M2 level screenshots (DEBUG build: the SpriteKit FPS / node counter is in the bottom-right).
final class StrikeLevelScreenshotUITests: XCTestCase {
    static let shotDir = "/private/tmp/claude-503/-Users-flyingbull-Developer-Strike/8a9e170c-024e-4dbc-b225-45e9eb286ba8/scratchpad"

    override func setUp() { continueAfterFailure = true }

    private func shot(_ name: String) {
        let s = XCUIScreen.main.screenshot()
        let a = XCTAttachment(screenshot: s)
        a.name = name; a.lifetime = .keepAlways
        add(a)
        try? s.pngRepresentation.write(to: URL(fileURLWithPath: "\(Self.shotDir)/\(name).png"))
    }

    @MainActor
    private func launch(_ level: String, seed: Int) -> XCUIApplication {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments += ["-StrikeAutoStart", "-StrikeLevel", level, "-StrikeSeed", "\(seed)"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["gameView"].waitForExistence(timeout: 10))
        return app
    }

    @MainActor
    func testL1Start() {
        _ = launch("l1", seed: 42)
        sleep(3)
        shot("m2_l1")
    }

    @MainActor
    func testL3Walk() {
        let app = launch("l3", seed: 42)
        sleep(2)
        let l0 = app.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.7))
        let l1 = app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.7))
        l0.press(forDuration: 0.1, thenDragTo: l1, withVelocity: .slow, thenHoldForDuration: 1.5)
        sleep(2)
        shot("m2_l3")
    }

    @MainActor
    func testL4Minimap() {
        let app = launch("l4", seed: 42)
        sleep(2)
        app.buttons["debug.revealMap"].tap()
        sleep(3)
        shot("m2_l4")
    }
}
