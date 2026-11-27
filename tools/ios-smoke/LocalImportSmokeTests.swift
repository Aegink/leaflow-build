import XCTest

// 本地文件导入与重开检查仍由同一测试类执行。
extension LeaflowSmokeTests {
    private func waitForCenteredPDFPage(_ index: Int) {
        let page = app.images["pdf-page-\(index)"]
        XCTAssertTrue(page.waitForExistence(timeout: 30))
        let screen = app.frame
        let centered = NSPredicate { _, _ in
            let frame = page.frame
            return page.value as? String == "已加载" && !frame.isEmpty && abs(frame.midX - screen.midX) < 2
                && frame.minX >= screen.minX - 2 && frame.maxX <= screen.maxX + 2
        }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: centered, object: page)], timeout: 15),
            .completed, "PDF目标页尚未居中，不能采集通过截图")
    }

    func testPDFFileImport() {
        launch(["-smokePDFImport"])
        let input = app.buttons["local-import-fixture"]
        XCTAssertTrue(input.waitForExistence(timeout: 30))
        input.tap()
        let save = app.buttons["local-book-import-save"]
        XCTAssertTrue(save.waitForExistence(timeout: 10))
        save.tap()
        let read = app.buttons["local-import-read"]
        XCTAssertTrue(read.waitForExistence(timeout: 20))
        XCTAssertEqual(app.staticTexts["local-import-chapter-count"].label, "章节数：6")
        read.tap()
        waitForCenteredPDFPage(0)
        assertVisibleText("PDF PAGE 1")
        app.swipeLeft()
        waitForCenteredPDFPage(1)
        assertVisibleText("PDF PAGE 2")
        app.buttons["local-import-reader-close"].tap()
        launch(["-smokePDFImport"])
        XCTAssertTrue(read.waitForExistence(timeout: 30))
        read.tap()
        waitForCenteredPDFPage(1)
        assertVisibleText("PDF PAGE 2")
        capture("pdf-cold-reader")
        app.buttons["local-import-reader-close"].tap()
        app.buttons["local-import-delete"].tap()
        passed("pdf_import_reader")
    }
    func testLocalBookFileImport() {
        launch(["-smokeLocalBookImport"])
        let input = app.buttons["local-import-fixture"]
        XCTAssertTrue(input.waitForExistence(timeout: 30))
        input.tap()
        let save = app.buttons["local-book-import-save"]
        XCTAssertTrue(save.waitForExistence(timeout: 10))
        XCTAssertEqual(app.textFields["书名"].value as? String, "固定导入书籍")
        capture("local-book-import-preview")
        save.tap()
        let read = app.buttons["local-import-read"]
        XCTAssertTrue(read.waitForExistence(timeout: 20))
        XCTAssertEqual(app.staticTexts["local-import-chapter-count"].label, "章节数：3")
        read.tap()
        XCTAssertTrue(app.textViews.firstMatch.waitForExistence(timeout: 30))
        assertVisibleText("固定本地正文")
        capture("local-book-import-reader")
        app.swipeLeft()
        XCTAssertEqual(app.sliders["local-reader-chapter-slider"].value as? String, "第2章")
        assertVisibleText("固定本地正文乙")
        app.buttons["local-import-reader-close"].tap()
        launch(["-smokeLocalBookImport"])
        XCTAssertTrue(read.waitForExistence(timeout: 30))
        XCTAssertEqual(app.staticTexts["local-import-chapter-count"].label, "章节数：3")
        read.tap()
        XCTAssertTrue(app.textViews.firstMatch.waitForExistence(timeout: 30))
        XCTAssertEqual(app.sliders["local-reader-chapter-slider"].value as? String, "第2章")
        assertVisibleText("固定本地正文乙")
        capture("local-book-import-cold-reader")
        passed("local_book_import_reader")
    }

    func testEpubFileImport() {
        launch(["-smokeEpubImport"])
        let input = app.buttons["local-import-fixture"]
        XCTAssertTrue(input.waitForExistence(timeout: 30))
        input.tap()
        let title = app.textFields["书名"]
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "固定EPUB书籍"), object: title)], timeout: 20), .completed)
        capture("epub-import-metadata")
        app.buttons["local-book-import-save"].tap()
        let read = app.buttons["local-import-read"]
        XCTAssertTrue(read.waitForExistence(timeout: 20))
        XCTAssertEqual(app.staticTexts["local-import-chapter-count"].label, "章节数：2")
        read.tap()
        XCTAssertTrue(app.textViews.firstMatch.waitForExistence(timeout: 30))
        assertVisibleText("正文乙")
        app.swipeLeft()
        assertVisibleText("正文甲")
        app.buttons["local-import-reader-close"].tap()
        launch(["-smokeEpubImport"])
        XCTAssertTrue(read.waitForExistence(timeout: 30))
        read.tap()
        XCTAssertTrue(app.textViews.firstMatch.waitForExistence(timeout: 30))
        assertVisibleText("正文甲")
        capture("epub-cold-reader")
        app.buttons["local-import-reader-close"].tap()
        app.buttons["local-import-delete"].tap()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"), object: read)], timeout: 10), .completed)
        passed("epub_import_reader")
    }

}
