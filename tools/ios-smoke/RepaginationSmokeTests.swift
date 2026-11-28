import XCTest

extension LeaflowSmokeTests {
    func testReaderQuickSpacingRepagination() {
        executionTimeAllowance = 300
        let arguments = ["-smokeReaderRepagination"]
        launch(arguments)
        let count = app.staticTexts["repagination-page-count"]
        XCTAssertTrue(count.waitForExistence(timeout: 20))
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            (Int(count.label) ?? 0) > 1
        }, object: count)], timeout: 30), .completed)
        let before = Int(count.label) ?? 0
        let body = app.textViews.firstMatch
        XCTAssertTrue(body.waitForExistence(timeout: 15))
        // 章标题也暴露为TextView，点击屏幕正文中央，避免FirstMatch命中标题或内嵌附件。
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let settings = app.buttons["reader-toolbar-设置"]
        XCTAssertTrue(settings.waitForExistence(timeout: 10))
        settings.tap()
        let spacing = app.buttons["reader-quick-排版"]
        XCTAssertTrue(spacing.waitForExistence(timeout: 10))
        spacing.tap()
        let font = app.sliders["reader-spacing-字号"]
        XCTAssertTrue(font.waitForExistence(timeout: 10))
        font.adjust(toNormalizedSliderPosition: 0.95)
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            (Int(count.label) ?? 0) > before && self.app.staticTexts["repagination-state"].label == "就绪"
        }, object: count)], timeout: 20), .completed)
        let saved = app.staticTexts["repagination-font-size"].label
        XCTAssertGreaterThan(Double(saved) ?? 0, 26)
        app.buttons["reader-spacing-back"].tap()
        XCTAssertTrue(spacing.waitForExistence(timeout: 10))
        capture("reader-spacing-repaginated")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4)).tap()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"), object: settings)], timeout: 10), .completed)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4)).tap()
        XCTAssertTrue(settings.waitForExistence(timeout: 10))
        XCTAssertFalse(spacing.exists)
        launch(arguments)
        XCTAssertTrue(count.waitForExistence(timeout: 20))
        XCTAssertEqual(app.staticTexts["repagination-font-size"].label, saved)
        XCTAssertTrue(body.waitForExistence(timeout: 30))
        capture("reader-spacing-cold")
        passed("reader_quick_spacing_repagination")
    }
}
