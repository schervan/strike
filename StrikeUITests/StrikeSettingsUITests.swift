import XCTest

/// Settings: title gear → move both sliders → Done; pause menu → Settings → Done → Resume.
final class StrikeSettingsUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    @MainActor private func percent(_ e: XCUIElement) -> Int {
        Int((e.value as? String ?? "").filter(\.isNumber)) ?? -1
    }

    @MainActor
    func testSettingsFromTitleMovesSlidersAndCloses() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments += ["-StrikeFreshSave"]
        app.launchArguments += ["-StrikeResetSettings"]
        app.launch()

        let gear = app.buttons["title.settingsButton"]
        XCTAssertTrue(gear.waitForExistence(timeout: 10))
        XCTAssertGreaterThanOrEqual(gear.frame.width, 64)
        gear.tap()

        let music = app.sliders["settings.musicSlider"]
        let sfx = app.sliders["settings.sfxSlider"]
        XCTAssertTrue(music.waitForExistence(timeout: 5))
        XCTAssertTrue(sfx.exists)
        XCTAssertEqual(percent(music), 80)
        XCTAssertEqual(percent(sfx), 80)

        music.adjust(toNormalizedSliderPosition: 0.2)
        sfx.adjust(toNormalizedSliderPosition: 0.5)
        XCTAssertLessThan(percent(music), 40, "music slider moved down")
        XCTAssertLessThan(percent(sfx), 70, "sfx slider moved down")
        XCTAssertGreaterThan(percent(sfx), 30)

        let plus = app.buttons["settings.musicSlider.plus"]
        XCTAssertGreaterThanOrEqual(plus.frame.height, 64)
        let before = percent(music)
        plus.tap()
        XCTAssertGreaterThan(percent(music), before)

        app.switches["settings.muteToggle"].firstMatch.tap()

        let done = app.buttons["settings.done"]
        XCTAssertGreaterThanOrEqual(done.frame.height, 64)
        done.tap()
        XCTAssertTrue(music.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["title.newGame"].isHittable)

        // Values persist while the app runs: reopen and check.
        gear.tap()
        XCTAssertTrue(music.waitForExistence(timeout: 5))
        XCTAssertLessThan(percent(music), 50)
        app.buttons["settings.done"].tap()
    }

    @MainActor
    func testSettingsFromPauseMenu() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments += ["-StrikeFreshSave"]
        app.launchArguments += ["-StrikeResetSettings", "-StrikeLevel", "l1", "-StrikeSeed", "42"]
        app.launch()
        let start = app.buttons["title.newGame"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        start.tap()
        let intro = app.descendants(matching: .any)["levelIntro.view"]
        if intro.waitForExistence(timeout: 5) { intro.tap() }

        let menu = app.buttons["menuButton"]
        XCTAssertTrue(menu.waitForExistence(timeout: 10))
        menu.tap()
        let settings = app.buttons["pause.settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        settings.tap()
        XCTAssertTrue(app.sliders["settings.sfxSlider"].waitForExistence(timeout: 5))
        app.buttons["settings.done"].tap()
        let resume = app.buttons["pause.resume"]
        XCTAssertTrue(resume.waitForExistence(timeout: 5))
        resume.tap()
        XCTAssertTrue(resume.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["gameView"].exists)
    }
}
