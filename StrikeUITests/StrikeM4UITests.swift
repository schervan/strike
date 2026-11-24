import XCTest

/// M4-5 / M4-6 simulator checks: real enemies (screenshot + FPS log), SWAP and the weapon wheel,
/// the boss arena through 3 phases to the Season complete card.
final class StrikeM4UITests: XCTestCase {
    static let dir = "/private/tmp/claude-503/-Users-flyingbull-Developer-Strike/8a9e170c-024e-4dbc-b225-45e9eb286ba8/scratchpad"

    override func setUp() { continueAfterFailure = true }

    @MainActor private func shot(_ name: String) {
        let s = XCUIScreen.main.screenshot()
        let a = XCTAttachment(screenshot: s); a.name = name; a.lifetime = .keepAlways; add(a)
        try? s.pngRepresentation.write(to: URL(fileURLWithPath: "\(Self.dir)/\(name).png"))
    }

    @MainActor private func el(_ app: XCUIApplication, _ id: String) -> XCUIElement { app.descendants(matching: .any)[id] }

    @MainActor private func launch(_ level: String, seed: Int, extra: [String] = []) -> XCUIApplication {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments += ["-StrikeAutoStart", "-StrikeFreshSave", "-StrikeResetSettings", "-StrikeLevel", level,
                                "-StrikeSeed", "\(seed)"] + extra
        app.launch()
        XCTAssertTrue(el(app, "gameView").waitForExistence(timeout: 10))
        return app
    }

    /// `-StrikeLevel l5 -StrikeBossArena -StrikeSeed 1`: boss bar, then 3 × next phase → Season complete.
    @MainActor
    func testBossArenaToSeasonComplete() {
        let app = launch("l5", seed: 1, extra: ["-StrikeBossArena"])
        let bar = el(app, "hud.bossBar")
        XCTAssertTrue(bar.waitForExistence(timeout: 10), "boss bar")
        sleep(4)
        shot("m4_boss")
        let next = app.buttons["debug.bossNextPhase"]
        XCTAssertTrue(next.exists)
        next.tap(); sleep(2)
        XCTAssertTrue(bar.exists)
        print("BOSS bar after phase 1: \(bar.label) / \(bar.value ?? "")")
        shot("m4_boss_phase2")
        next.tap(); sleep(2)
        next.tap()
        let card = el(app, "seasonComplete.view")
        XCTAssertTrue(card.waitForExistence(timeout: 12), "Season complete card")
        sleep(2)
        shot("m4_season_complete")
        let toTitle = app.buttons["seasonComplete.toTitle"]
        XCTAssertTrue(toTitle.waitForExistence(timeout: 5))
        toTitle.tap()
        XCTAssertTrue(app.staticTexts["titleLabel"].waitForExistence(timeout: 5))
    }

    /// SWAP appears with the 2nd blaster, a tap swaps, a long press opens the wheel.
    @MainActor
    func testSwapAndWeaponWheel() {
        let app = launch("l2", seed: 11)
        let swap = el(app, "hud.swapButton")
        XCTAssertFalse(swap.exists, "no SWAP with one blaster")
        app.buttons["debug.giveBlasters"].tap()
        XCTAssertTrue(swap.waitForExistence(timeout: 3), "SWAP visible with 2+ blasters")
        let ammo = el(app, "hud.ammoLabel")
        let before = swap.value as? String
        swap.tap()
        sleep(1)
        XCTAssertNotEqual(swap.value as? String, before, "tap swapped the blaster")
        swap.press(forDuration: 0.8)
        let wheel = el(app, "hud.weaponWheel")
        XCTAssertTrue(wheel.waitForExistence(timeout: 3), "long press opens the wheel")
        XCTAssertTrue(el(app, "hud.weaponWheel.slot.2").exists)
        sleep(1)
        shot("m4_wheel")
        el(app, "hud.weaponWheel.slot.2").tap()
        sleep(1)
        XCTAssertFalse(wheel.exists, "picking closes the wheel")
        XCTAssertEqual(swap.value as? String, "blaster_rapid")
        print("WHEEL ammo readout after pick: \(ammo.value ?? "")")
    }

    /// Drone + shield android + spore plant in one view (screenshot), then all 5 types + crowd on
    /// L5 for the FPS / node log.
    @MainActor
    func testEnemiesViewAndPerformance() {
        let app = launch("l1", seed: 42)
        sleep(2)
        for id in ["laserdrone", "shieldandroid", "sporeplant"] { app.buttons["debug.spawn.\(id)"].tap() }
        sleep(2)
        shot("m4_enemies")
        app.terminate()

        let l5 = launch("l5", seed: 7)
        sleep(2)
        for id in ["boltbot", "laserdrone", "slimemutant", "shieldandroid", "sporeplant"] { l5.buttons["debug.spawn.\(id)"].tap() }
        l5.buttons["debug.spawnCrowd"].tap()
        var samples: [String] = []
        for _ in 0..<6 { sleep(1); samples.append(el(l5, "debug.stats").label) }
        print("PERF l5 + 5 types + crowd: \(samples.joined(separator: " | "))")
        shot("m4_perf_l5")
    }
}
