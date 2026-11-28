import XCTest

extension LeaflowSmokeTests {
    func testReadingSettingsColdPersistence() {
        launch(["-smokeReadingSettings"])
        let open = app.buttons["settings-open-editor"]
        XCTAssertTrue(open.waitForExistence(timeout: 15))
        open.tap()
        let fontSize = app.sliders["reader-setting-字号"]
        XCTAssertTrue(fontSize.waitForExistence(timeout: 10))
        fontSize.adjust(toNormalizedSliderPosition: 0.75)
        let spacing = app.sliders["reader-setting-行距"]
        for _ in 0..<4 {
            if spacing.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(spacing.isHittable)
        spacing.adjust(toNormalizedSliderPosition: 0.65)
        app.buttons["完成"].tap()
        XCTAssertTrue(open.waitForExistence(timeout: 10))
        let size = app.staticTexts["settings-saved-font-size"].label
        let line = app.staticTexts["settings-saved-line-spacing"].label
        XCTAssertGreaterThan(Double(size) ?? 0, 22)
        XCTAssertGreaterThan(Double(line) ?? 0, 10)
        capture("reading-settings-saved")
        launch(["-smokeReadingSettings"])
        XCTAssertTrue(open.waitForExistence(timeout: 15))
        XCTAssertEqual(app.staticTexts["settings-saved-font-size"].label, size)
        XCTAssertEqual(app.staticTexts["settings-saved-line-spacing"].label, line)
        capture("reading-settings-cold")
        passed("reading_settings_cold_persistence")
    }
}
