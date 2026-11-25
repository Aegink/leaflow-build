// T-1602：模拟器真实手势与页面就绪断言，不替代 iPhone 真机或原版对照。
import XCTest

final class LeaflowSmokeTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws { continueAfterFailure = false }
    override func tearDownWithError() throws { app?.terminate() }

    func testBookCardReadDismissal() {
        launch(["-smokeBookActions"])
        openActions()
        capture("book-actions")
        app.buttons["开始阅读"].tap()
        let result = app.staticTexts["已请求阅读：固定书架样本"]
        XCTAssertTrue(result.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["开始阅读"].exists)
        passed("bookshelf_card_read_dismissal")
    }

    func testBookGridEditing() {
        launch(["-smokeBookActions", "-smokeBookGrid"])
        app.buttons["编辑"].tap()
        app.staticTexts["固定书架样本"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["已选择样本"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["未执行"].exists)
        app.staticTexts["固定书架样本"].firstMatch.press(forDuration: 1)
        XCTAssertFalse(app.buttons["开始阅读"].exists)
        app.buttons["完成"].tap()
        openActions()
        app.buttons["开始阅读"].tap()
        XCTAssertTrue(app.staticTexts["已请求阅读：固定书架样本"].waitForExistence(timeout: 10))
        passed("bookshelf_grid_editing")
    }

    func testBookEditAndCoverEntries() {
        launch(["-smokeBookActions"])
        openActions()
        app.buttons["编辑书籍"].tap()
        let title = app.textFields["书名"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertEqual(title.value as? String, "固定书架样本")
        capture("book-edit")
        let editClose = app.buttons["book-edit-close"]
        XCTAssertTrue(editClose.isHittable)
        editClose.tap()
        XCTAssertTrue(NSPredicate(format: "exists == false").evaluate(with: editClose)
            || XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"),
                object: editClose)], timeout: 10) == .completed)
        XCTAssertTrue(app.buttons["换封面"].waitForExistence(timeout: 10))
        app.buttons["换封面"].tap()
        XCTAssertTrue(app.staticTexts["当前封面"].waitForExistence(timeout: 10))
        capture("book-cover")
        passed("bookshelf_edit_cover_entries")
    }

    func testBookDeleteConfirmation() {
        launch(["-smokeBookActions"])
        openActions()
        let delete = app.buttons["从书架删除"]
        for _ in 0..<8 {
            if delete.exists && delete.isHittable { break }
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(delete.isHittable)
        delete.tap()
        XCTAssertTrue(app.buttons["确认删除"].waitForExistence(timeout: 5))
        app.buttons["确认删除"].tap()
        XCTAssertTrue(app.staticTexts["已删除"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["已请求阅读：固定书架样本"].exists)
        passed("bookshelf_delete_confirmation")
    }

    func testTtsRenderedSkins() {
        for (skin, dark, name) in [("classic", false, "tts-classic-ready"),
            ("apple", false, "tts-apple-ready"), ("apple", true, "tts-dark-ready")] {
            var arguments = ["-smokeTtsPlayer", "-tts_player_skin", skin]
            if dark { arguments.append("-smokeDark") }
            launch(arguments)
            XCTAssertTrue(app.staticTexts["固定朗读样本"].waitForExistence(timeout: 30))
            XCTAssertTrue(app.staticTexts["测试作者"].exists)
            XCTAssertTrue(app.buttons["收起播放器"].isHittable)
            capture(name)
            app.terminate()
        }
        passed("tts_rendered_skins")
    }

    func testTtsLargeTextScroll() {
        launch(["-smokeTtsQuick", "-smokeDark", "-smokeLargeText"])
        let panel = app.scrollViews["tts-quick-settings"]
        XCTAssertTrue(panel.waitForExistence(timeout: 30))
        XCTAssertTrue(app.buttons["停止朗读"].isHittable)
        capture("tts-quick-large-top")
        let settings = app.buttons["设置"]
        for _ in 0..<8 {
            if settings.exists && settings.isHittable { break }
            panel.swipeUp()
        }
        XCTAssertTrue(settings.isHittable)
        XCTAssertTrue(app.buttons["播放器"].isHittable)
        capture("tts-quick-large-bottom")
        passed("tts_large_text_scroll")
    }

    private func launch(_ arguments: [String]) {
        app?.terminate()
        app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
        app.activate()
    }
    func testSourceImportValidation() {
        launch(["-smokeSources", "-sourceManageViewingRemote", "NO"])
        openSourceImport()
        let input = app.textViews["source-import-text"]
        input.tap()
        input.typeText("{")
        app.buttons["source-import-submit"].tap()
        let result = app.staticTexts["source-import-result"]
        XCTAssertTrue(result.waitForExistence(timeout: 10))
        XCTAssertTrue(result.label.contains("解析失败"))
        XCTAssertTrue(input.exists)
        XCTAssertTrue(app.buttons["source-import-submit"].isEnabled)
        capture("source-import-error")
        passed("source_import_validation")
    }

    func testSourceImportPersistence() {
        launch(["-smokeSources", "-sourceManageViewingRemote", "NO"])
        openSourceImport()
        let input = app.textViews["source-import-text"]
        input.tap()
        input.typeText(#"{"bookSourceUrl":"https://sample.invalid/ui-import","bookSourceName":"固定导入样本"}"#)
        app.buttons["source-import-submit"].tap()
        XCTAssertTrue(app.staticTexts["固定导入样本"].firstMatch.waitForExistence(timeout: 20))
        XCTAssertFalse(input.exists)
        capture("source-import-list")
        launch(["-smokeSources", "-sourceManageViewingRemote", "NO"])
        XCTAssertTrue(app.staticTexts["固定导入样本"].firstMatch.waitForExistence(timeout: 30))
        capture("source-import-reloaded")
        passed("source_import_persistence")
    }

    private func openSourceImport() {
        let menu = app.buttons["source-manage-menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 30))
        menu.tap()
        app.buttons["文本导入"].tap()
        XCTAssertTrue(app.textViews["source-import-text"].waitForExistence(timeout: 10))
    }
    private func openActions() {
        let title = app.staticTexts["固定书架样本"].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 20))
        title.press(forDuration: 1)
        XCTAssertTrue(app.buttons["开始阅读"].waitForExistence(timeout: 10))
        // 展开真实操作表，避免 medium 档把下面的入口留在屏幕外。
        app.swipeUp()
    }
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    private func passed(_ name: String) { print("SMOKE_UI \(name) pass=true") }
}
