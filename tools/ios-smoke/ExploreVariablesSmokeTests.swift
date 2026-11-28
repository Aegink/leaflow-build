import XCTest

extension LeaflowSmokeTests {
    // 从过长的状态用例拆出完整变量链，保留实际输入、冷启动、清空与书架清理断言。
    func testExploreDetailBookVariablePersistence() {
        executionTimeAllowance = 300
        let arguments = ["-smokeExploreReading", "-smokeExploreBookVariables"]
        launch(arguments)
        let entry = app.buttons["explore-reading-book"]
        XCTAssertTrue(entry.waitForExistence(timeout: 30))
        entry.tap()
        let shelf = app.buttons["book-detail-shelf"]
        XCTAssertTrue(shelf.waitForExistence(timeout: 10))
        XCTAssertEqual(shelf.label, "书架")
        shelf.tap()
        openBookDetailMenu()
        app.buttons["书籍变量"].tap()
        let custom = app.textViews["book-detail-book-variable"]
        XCTAssertTrue(custom.waitForExistence(timeout: 10))
        custom.tap()
        custom.typeText("fixed-detail-value")
        app.buttons["book-detail-save-book-variable"].tap()
        launch(arguments)
        XCTAssertTrue(entry.waitForExistence(timeout: 30))
        entry.tap()
        openBookDetailMenu()
        app.buttons["书籍变量"].tap()
        XCTAssertTrue(custom.waitForExistence(timeout: 10))
        XCTAssertEqual(custom.value as? String, "fixed-detail-value")
        app.buttons["book-detail-save-book-variable"].tap()
        shelf.tap()
        app.buttons["删除"].tap()
        XCTAssertTrue(app.buttons.matching(identifier: "book-detail-shelf").matching(
            NSPredicate(format: "label == %@", "书架")).firstMatch.waitForExistence(timeout: 10))
        passed("explore_detail_variables_persistence")
    }

    func testExploreDetailSourceVariablePersistence() {
        executionTimeAllowance = 300
        let arguments = ["-smokeExploreReading", "-smokeExploreSourceVariables"]
        launch(arguments)
        let entry = app.buttons["explore-reading-book"]
        XCTAssertTrue(entry.waitForExistence(timeout: 30))
        entry.tap()
        openBookDetailMenu()
        app.buttons["源变量"].tap()
        let source = app.textViews["book-detail-source-variable"]
        XCTAssertTrue(source.waitForExistence(timeout: 10))
        source.tap()
        source.typeText("fixed-source-value")
        app.buttons["book-detail-save-source-variable"].tap()
        launch(arguments)
        XCTAssertTrue(entry.waitForExistence(timeout: 30))
        entry.tap()
        openBookDetailMenu()
        app.buttons["源变量"].tap()
        XCTAssertTrue(source.waitForExistence(timeout: 10))
        XCTAssertEqual(source.value as? String, "fixed-source-value")
        capture("explore-source-variable-cold")
        app.buttons["book-detail-save-source-variable"].tap()
        openBookDetailMenu()
        app.buttons["清除源变量"].tap()
        openBookDetailMenu()
        app.buttons["源变量"].tap()
        XCTAssertTrue(source.waitForExistence(timeout: 10))
        XCTAssertEqual(source.value as? String, "")
        app.buttons["book-detail-save-source-variable"].tap()
        passed("explore_source_variable_persistence")
    }
}
