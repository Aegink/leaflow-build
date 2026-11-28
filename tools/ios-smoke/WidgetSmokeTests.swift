import XCTest

extension LeaflowSmokeTests {
    func testWidgetEditEntryAndColdRendering() {
        executionTimeAllowance = 300
        let arguments = ["-smokeReaderPageTurn", "-smokeLayoutWidgets"]
        launch(arguments)
        let open = app.buttons["reader-widget-open-settings"]
        XCTAssertTrue(open.waitForExistence(timeout: 20))
        open.tap()
        let edit = app.buttons["reader-edit-widgets"]
        for _ in 0..<5 {
            if edit.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(edit.isHittable)
        edit.tap()
        let add = app.buttons["reader-widget-add"]
        XCTAssertTrue(add.waitForExistence(timeout: 15))
        add.tap()
        let text = app.textFields["reader-widget-custom-text"]
        XCTAssertTrue(text.waitForExistence(timeout: 10))
        text.tap()
        text.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: (text.value as? String ?? "").count) + "fixed-widget")
        app.buttons["reader-widget-panel-done"].tap()
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        app.buttons["reader-widget-done"].tap()
        XCTAssertFalse(add.exists)
        XCTAssertTrue(app.staticTexts["fixed-widget"].waitForExistence(timeout: 10))
        capture("widget-rendered-after-editor")
        launch(arguments)
        XCTAssertTrue(open.waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["fixed-widget"].waitForExistence(timeout: 10))
        XCTAssertFalse(add.exists)
        capture("widget-cold-rendered")
        passed("reader_widget_edit_persistence")
    }
}
