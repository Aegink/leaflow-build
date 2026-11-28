import XCTest

extension LeaflowSmokeTests {
    func testReadingFontPickerPersistence() {
        executionTimeAllowance = 300
        launch(["-smokeReadingSettings"])
        let open = app.buttons["settings-open-editor"]
        XCTAssertTrue(open.waitForExistence(timeout: 15))
        open.tap()
        let picker = app.buttons["reader-font-picker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 15))
        picker.tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 15))
        search.tap()
        search.typeText("Courier")
        let font = app.buttons["reader-font-Courier New"]
        XCTAssertTrue(font.waitForExistence(timeout: 15))
        font.tap()
        XCTAssertTrue(picker.waitForExistence(timeout: 10))
        app.buttons["完成"].tap()
        XCTAssertTrue(open.waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["settings-saved-font-name"].label, "Courier New")
        capture("reader-font-selected")
        launch(["-smokeReadingSettings"])
        XCTAssertTrue(open.waitForExistence(timeout: 15))
        XCTAssertEqual(app.staticTexts["settings-saved-font-name"].label, "Courier New")
        open.tap()
        XCTAssertTrue(picker.waitForExistence(timeout: 15))
        picker.tap()
        let system = app.buttons["reader-font-System"]
        XCTAssertTrue(system.waitForExistence(timeout: 15))
        system.tap()
        XCTAssertTrue(picker.waitForExistence(timeout: 10))
        app.buttons["完成"].tap()
        XCTAssertEqual(app.staticTexts["settings-saved-font-name"].label, "System")
        passed("reader_font_picker_persistence")
    }

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
