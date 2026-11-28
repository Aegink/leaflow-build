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
        XCTAssertTrue(add.isHittable)
        add.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let text = app.textFields["reader-widget-custom-text"]
        XCTAssertTrue(text.waitForExistence(timeout: 10))
        app.buttons["reader-widget-item-bookName"].tap()
        XCTAssertFalse(text.exists)
        app.buttons["reader-widget-item-customText"].tap()
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
        open.tap()
        for _ in 0..<5 {
            if edit.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(edit.isHittable)
        edit.tap()
        XCTAssertTrue(add.waitForExistence(timeout: 15))
        let handle = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label == %@",
            "reader-widget-", "fixed-widget")).firstMatch
        XCTAssertTrue(handle.waitForExistence(timeout: 10))
        handle.tap()
        let delete = app.buttons["删除组件"]
        for _ in 0..<5 {
            if delete.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(delete.isHittable)
        delete.tap()
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        app.buttons["reader-widget-done"].tap()
        XCTAssertFalse(app.staticTexts["fixed-widget"].exists)
        passed("reader_widget_edit_persistence")
    }
}
