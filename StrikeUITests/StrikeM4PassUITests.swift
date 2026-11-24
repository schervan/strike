import XCTest

/// M4-7 simulator pass: every enemy type in action, the boss arena through its phases, FPS / node log.
final class StrikeM4PassUITests: XCTestCase {
    static let dir = "/private/tmp/claude-503/-Users-flyingbull-Developer-Strike/8a9e170c-024e-4dbc-b225-45e9eb286ba8/scratchpad"

    override func setUp() { continueAfterFailure = true }

    @MainActor private func shot(_ name: String) {
        let s = XCUIScreen.main.screenshot()
        let a = XCTAttachment(screenshot: s); a.name = name; a.lifetime = .keepAlways; add(a)
        try? s.pngRepresentation.write(to: URL(fileURLWithPath: "\(Self.dir)/qa_m4_\(name).png"))
    }

    @MainActor private func el(_ app: XCUIApplication, _ id: String) -> XCUIElement { app.descendants(matching: .any)[id] }

    @MainActor private func launch(_ level: String, seed: Int, extra: [String] = []) -> XCUIApplication {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments += ["-StrikeAutoStart", "-StrikeFreshSave", "-StrikeResetSettings", "-StrikeLevel", level, "-StrikeSeed", "\(seed)"] + extra
        app.launch()
        XCTAssertTrue(el(app, "gameView").waitForExistence(timeout: 15))
        let intro = el(app, "levelIntro.view")
        if intro.waitForExistence(timeout: 2) { for _ in 0..<8 where intro.exists { intro.tap(); usleep(400_000) } }
        return app
    }

    @MainActor private func stats(_ app: XCUIApplication) -> String { el(app, "debug.stats").label }

    /// One room per enemy type: spawn, watch the telegraph, shoot it down, see the sparkles.
    @MainActor
    func testEveryEnemyTypeInAction() {
        for (id, name) in [("boltbot", "boltbot"), ("laserdrone", "drone"), ("slimemutant", "slime"), ("shieldandroid", "shield"), ("sporeplant", "spore")] {
            let app = launch("l1", seed: 42)
            app.buttons["debug.giveBlasters"].tap()
            app.buttons["debug.spawn.\(id)"].tap()
            usleep(900_000)
            shot("enemy_\(name)_1_spawn")
            usleep(1_200_000)
            shot("enemy_\(name)_2_act")
            print("M4 \(name) stats before fight: \(stats(app))")
            // Fire in a fan of directions (auto-fire + aim assist) for a few seconds.
            let a0 = app.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.6))
            for tgt in [(0.9, 0.6), (0.65, 0.45), (0.9, 0.8)] {
                a0.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: tgt.0, dy: tgt.1)), withVelocity: .slow, thenHoldForDuration: 1.0)
            }
            shot("enemy_\(name)_3_after")
            print("M4 \(name) stats after fight: \(stats(app)) hp \((el(app, "hud.hpBar").value as? String) ?? "?")")
            app.terminate()
        }
    }

    /// Boss arena: start, hold fire at the boss, PHASE to the shield with carriers, PHASE to overload, defeat.
    @MainActor
    func testBossArenaPhasesAndFPS() {
        let app = launch("l5", seed: 1, extra: ["-StrikeBossArena"])
        let bar = el(app, "hud.bossBar")
        XCTAssertTrue(bar.waitForExistence(timeout: 10), "boss bar")
        sleep(2)
        shot("boss_0_start")
        print("M4 boss phase 1 start: \(bar.label) | \(stats(app))")
        // Phase 1: shoot toward where the boss walks in from; sample frames of its attacks.
        let a0 = app.coordinate(withNormalizedOffset: CGVector(dx: 0.78, dy: 0.62))
        let a1 = app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))
        a0.press(forDuration: 0.05, thenDragTo: a1, withVelocity: .slow, thenHoldForDuration: 3)
        shot("boss_1_fire")
        sleep(1)
        shot("boss_1b")
        print("M4 boss during phase 1: \(bar.label) | \(stats(app))")
        let next = app.buttons["debug.bossNextPhase"]
        next.tap(); sleep(4)
        shot("boss_2_shield")
        print("M4 boss phase 2 (shield): \(bar.label) | \(stats(app))")
        sleep(6)
        shot("boss_2b_carriers")
        next.tap(); sleep(3)
        shot("boss_3_overload")
        print("M4 boss phase 3: \(bar.label) | \(stats(app))")
        a0.press(forDuration: 0.05, thenDragTo: a1, withVelocity: .slow, thenHoldForDuration: 4)
        shot("boss_3b")
        next.tap()
        usleep(1_500_000)
        shot("boss_4_defeat_a")
        usleep(1_200_000)
        shot("boss_4_defeat_b")
        let card = el(app, "seasonComplete.view")
        XCTAssertTrue(card.waitForExistence(timeout: 12), "Season complete card")
        sleep(2)
        shot("season_complete")
        app.terminate()
    }

    @MainActor
    func testL5CrowdFPS() {
        let app = launch("l5", seed: 7)
        sleep(1)
        for id in ["boltbot", "laserdrone", "slimemutant", "shieldandroid", "sporeplant"] { app.buttons["debug.spawn.\(id)"].tap() }
        app.buttons["debug.spawnCrowd"].tap()
        var samples: [String] = []
        for _ in 0..<6 { sleep(1); samples.append(stats(app)) }
        print("M4 PERF l5 + 5 types + crowd: \(samples.joined(separator: " | "))")
        shot("l5_crowd")
        app.terminate()
    }
}
