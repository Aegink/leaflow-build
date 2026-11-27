// T-1602：模拟器真实手势与页面就绪断言，不替代 iPhone 真机或原版对照。
import XCTest

final class LeaflowSmokeTests: XCTestCase {
    private var app: XCUIApplication!
    private var pixelSequence = 0

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
        // 保存回调后延迟关闭；列表可先出现在下层，须等真实弹层消失再继续。
        XCTAssertTrue(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"), object: input)], timeout: 15) == .completed)
        XCTAssertTrue(app.staticTexts["固定导入样本"].firstMatch.waitForExistence(timeout: 20))
        capture("source-import-list")
        launch(["-smokeSources", "-sourceManageViewingRemote", "NO"])
        XCTAssertTrue(app.staticTexts["固定导入样本"].firstMatch.waitForExistence(timeout: 30))
        capture("source-import-reloaded")
        passed("source_import_persistence")
    }

    private func openSourceImport() {
        let menu = app.buttons["source-manage-menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 30))
        // 原生Menu的AX命中点返回(-1,-1)，按屏内实际边界点击后验证真实展开结果。
        XCTAssertFalse(menu.frame.isEmpty)
        XCTAssertTrue(app.frame.contains(CGPoint(x: menu.frame.midX, y: menu.frame.midY)))
        capture("source-menu-before-tap")
        print("配置菜单无障碍层级：\(menu.debugDescription)")
        menu.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let textImport = app.buttons["文本导入"]
        XCTAssertTrue(textImport.waitForExistence(timeout: 10))
        XCTAssertTrue(textImport.isHittable)
        textImport.tap()
        XCTAssertTrue(app.textViews["source-import-text"].waitForExistence(timeout: 10))
    }

    func testExploreImportedSourceEntry() {
        launch(["-smokeSources", "-sourceManageViewingRemote", "NO"])
        openSourceImport()
        let input = app.textViews["source-import-text"]
        input.tap()
        input.typeText(#"{"bookSourceUrl":"https://sample.invalid/ui-discovery","bookSourceName":"固定发现配置","exploreUrl":"推荐::https://sample.invalid/list","ruleExplore":{"bookList":"//li"}}"#)
        app.buttons["source-import-submit"].tap()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"), object: input)], timeout: 15), .completed)
        let exploreTab = app.tabBars.buttons["发现"]
        XCTAssertTrue(exploreTab.waitForExistence(timeout: 10))
        exploreTab.tap()
        XCTAssertTrue(app.staticTexts["固定发现配置"].firstMatch.waitForExistence(timeout: 20))
        capture("explore-imported-source")
        app.staticTexts["固定发现配置"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["固定发现配置"].waitForExistence(timeout: 15))
        capture("explore-source-entered")
        launch([])
        XCTAssertTrue(app.tabBars.buttons["发现"].waitForExistence(timeout: 30))
        app.tabBars.buttons["发现"].tap()
        XCTAssertTrue(app.staticTexts["固定发现配置"].firstMatch.waitForExistence(timeout: 20))
        capture("explore-source-cold-start")
        passed("explore_imported_source_entry")
    }

    func testReaderSelectedTextReplacement() {
        launch(["-smokeReaderSelection"])
        let text = app.textViews["reader-selection-text"]
        XCTAssertTrue(text.waitForExistence(timeout: 30))
        XCTAssertTrue(app.staticTexts["sample"].waitForExistence(timeout: 20))
        text.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.08)).press(forDuration: 1)
        capture("reader-selection-menu")
        let replace = app.menuItems["替换"]
        XCTAssertTrue(replace.waitForExistence(timeout: 10))
        replace.tap()
        let input = app.textFields["reader-replace-text"]
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        input.tap()
        input.typeText("replaced")
        capture("reader-replace-draft")
        app.buttons["reader-replace-save"].tap()
        let result = app.staticTexts["reader-selection-result"]
        XCTAssertTrue(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", "replaced"), object: result)], timeout: 20) == .completed)
        XCTAssertFalse(input.exists)
        capture("reader-replace-applied")
        passed("reader_selected_text_replacement")
    }
    func testBookReviewRenderedStates() {
        for (mode, expected) in [("", "固定评论"), ("-smokeReviewEmpty", "暂无评论"),
                                 ("-smokeReviewError", "book-review-error"),
                                 ("-smokeReviewNoChapters", "固定评论")] {
            launch(["-smokeBookReview", mode].filter { !$0.isEmpty })
            let more = app.buttons["更多操作"]
            XCTAssertTrue(more.waitForExistence(timeout: 30))
            if mode != "-smokeReviewNoChapters" {
                XCTAssertTrue(app.textViews.matching(NSPredicate(format: "value CONTAINS %@",
                    "固定正文，请从更多操作打开评论。")).firstMatch.waitForExistence(timeout: 20))
                assertVisibleText("固定正文")
            }
            capture("book-review-before-more")
            print("阅读更多操作按钮：\(more.debugDescription)")
            more.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            let review = app.buttons["评论"]
            let opened = review.waitForExistence(timeout: 10)
            print("阅读更多操作后应用状态：\(app.state.rawValue)")
            XCTAssertEqual(app.state, .runningForeground, "打开更多操作后应用异常退出")
            capture("book-review-after-more")
            print("阅读更多操作展开后层级：\(app.debugDescription)")
            XCTAssertTrue(opened)
            let progress = app.sliders["章节进度"]
            XCTAssertTrue(progress.exists)
            XCTAssertFalse(progress.isEnabled)
            XCTAssertTrue(review.isEnabled)
            review.tap()
            let result = app.staticTexts[expected]
            XCTAssertTrue(result.waitForExistence(timeout: 20))
            capture("book-review" + mode)
            app.buttons["book-review-close"].tap()
            XCTAssertTrue(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "exists == false"), object: result)], timeout: 10) == .completed)
        }
        passed("book_review_rendered_states")
    }

    private func openActions() {
        let title = app.staticTexts["固定书架样本"].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 20))
        title.press(forDuration: 1)
        XCTAssertTrue(app.buttons["开始阅读"].waitForExistence(timeout: 10))
        // 展开真实操作表，避免 medium 档把下面的入口留在屏幕外。
        app.swipeUp()
    }

    func testReaderHorizontalPageTurns() {
        checkReaderPageTurns(curl: false)
        passed("reader_horizontal_page_turns")
    }

    func testReaderCurlPageTurns() {
        checkReaderPageTurns(curl: true)
        passed("reader_curl_page_turns")
    }

    private func checkReaderPageTurns(curl: Bool) {
        launch(curl ? ["-smokeReaderPageTurn", "-smokePageCurl"] : ["-smokeReaderPageTurn"])
        let position = app.staticTexts["reader-turn-position"]
        XCTAssertTrue(position.waitForExistence(timeout: 30))
        waitForPosition("全局页0，章节0", position)
        assertVisibleText("固定翻页正文甲")
        app.swipeLeft()
        waitForPosition("全局页1，章节0", position)
        assertVisibleText("固定翻页正文乙")
        capture("reader-turn-second")
        app.swipeLeft()
        waitForPosition("全局页2，章节1", position)
        assertVisibleText("固定翻页正文丙")
        capture("reader-turn-cross-chapter")
        app.swipeLeft()
        waitForPosition("全局页2，章节1", position)
        app.swipeRight()
        waitForPosition("全局页1，章节0", position)
        assertVisibleText("固定翻页正文乙")
        app.swipeRight()
        waitForPosition("全局页0，章节0", position)
        assertVisibleText("固定翻页正文甲")
        capture("reader-turn-returned")
    }

    private func openBookDetailMenu() {
        let menu = app.buttons["book-detail-menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 10))
        XCTAssertFalse(menu.frame.isEmpty)
        XCTAssertTrue(app.frame.contains(CGPoint(x: menu.frame.midX, y: menu.frame.midY)))
        menu.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.buttons["书籍变量"].waitForExistence(timeout: 10))
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

    func testExploreDetailBookState() {
        launch(["-smokeExploreReading"])
        let entry = app.buttons["explore-reading-book"]
        XCTAssertTrue(entry.waitForExistence(timeout: 30))
        entry.tap()
        let shelf = app.buttons["book-detail-shelf"]
        XCTAssertTrue(shelf.waitForExistence(timeout: 10))
        XCTAssertEqual(shelf.label, "书架")
        shelf.tap()
        XCTAssertTrue(app.buttons.matching(identifier: "book-detail-shelf").matching(
            NSPredicate(format: "label == %@", "在书架")).firstMatch.waitForExistence(timeout: 10))
        openBookDetailMenu()
        app.buttons["书籍类型"].tap()
        app.buttons["音频"].tap()
        openBookDetailMenu()
        app.buttons["自动更新"].tap()
        openBookDetailMenu()
        app.buttons["书籍变量"].tap()
        let custom = app.textViews["book-detail-book-variable"]
        XCTAssertTrue(custom.waitForExistence(timeout: 10))
        custom.tap()
        custom.typeText("fixed-detail-value")
        app.buttons["book-detail-save-book-variable"].tap()
        XCTAssertTrue(app.buttons["book-detail-menu"].waitForExistence(timeout: 10))
        openBookDetailMenu()
        app.buttons["源变量"].tap()
        let source = app.textViews["book-detail-source-variable"]
        XCTAssertTrue(source.waitForExistence(timeout: 10))
        source.tap()
        source.typeText("fixed-source-value")
        app.buttons["book-detail-save-source-variable"].tap()
        capture("explore-detail-saved")
        launch([])
        XCTAssertTrue(app.staticTexts["固定发现书籍"].firstMatch.waitForExistence(timeout: 30))
        capture("explore-book-on-shelf")
        launch(["-smokeExploreReading"])
        XCTAssertTrue(entry.waitForExistence(timeout: 30))
        entry.tap()
        XCTAssertTrue(app.staticTexts["音频"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["已跳过更新"].exists)
        XCTAssertEqual(shelf.label, "在书架")
        openBookDetailMenu()
        app.buttons["书籍变量"].tap()
        XCTAssertTrue(custom.waitForExistence(timeout: 10))
        XCTAssertEqual(custom.value as? String, "fixed-detail-value")
        app.buttons["book-detail-save-book-variable"].tap()
        openBookDetailMenu()
        app.buttons["源变量"].tap()
        XCTAssertTrue(source.waitForExistence(timeout: 10))
        XCTAssertEqual(source.value as? String, "fixed-source-value")
        app.buttons["book-detail-save-source-variable"].tap()
        openBookDetailMenu()
        app.buttons["清除源变量"].tap()
        shelf.tap()
        app.buttons["取消"].tap()
        XCTAssertEqual(shelf.label, "在书架")
        shelf.tap()
        app.buttons["删除"].tap()
        XCTAssertTrue(app.buttons.matching(identifier: "book-detail-shelf").matching(
            NSPredicate(format: "label == %@", "书架")).firstMatch.waitForExistence(timeout: 10))
        capture("explore-detail-deleted")
        launch([])
        XCTAssertTrue(app.staticTexts["去搜索添加一些书籍吧"].waitForExistence(timeout: 30))
        XCTAssertFalse(app.staticTexts["固定发现书籍"].exists)
        passed("explore_detail_state_persistence")
    }

    func testExploreDetailReadingHandoff() {
        launch(["-smokeExploreReading"])
        let book = app.buttons["explore-reading-book"]
        XCTAssertTrue(book.waitForExistence(timeout: 30))
        book.tap()
        let read = app.buttons["开始阅读"]
        XCTAssertTrue(read.waitForExistence(timeout: 10))
        capture("explore-book-detail")
        app.buttons["explore-detail-close"].tap()
        XCTAssertTrue(book.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["reader-router-close"].exists)
        book.tap()
        XCTAssertTrue(read.waitForExistence(timeout: 10))
        read.tap()
        let close = app.buttons["reader-router-close"]
        XCTAssertTrue(close.waitForExistence(timeout: 30))
        let text = app.textViews.firstMatch
        XCTAssertTrue(text.waitForExistence(timeout: 20))
        assertVisibleText("固定发现正文")
        XCTAssertFalse(app.buttons["explore-detail-close"].exists)
        capture("explore-reader-opened")
        close.tap()
        XCTAssertTrue(book.waitForExistence(timeout: 10))
        book.tap()
        XCTAssertTrue(read.waitForExistence(timeout: 10))
        capture("explore-detail-reopened")
        passed("explore_detail_reading_handoff")
    }

    private func waitForPosition(_ expected: String, _ element: XCUIElement) {
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", expected), object: element)], timeout: 10), .completed)
    }

    private func assertVisibleText(_ expected: String) {
        // 模拟器只采集屏幕像素，macOS主机逐张识别；缺图、缺文字均阻断CI。
        let attachment = XCTAttachment(screenshot: app.screenshot())
        pixelSequence += 1
        attachment.name = "pixel-text-" + expected.utf8.map { String(format: "%02x", $0) }.joined() + "-\(pixelSequence)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    private func passed(_ name: String) { print("SMOKE_UI \(name) pass=true") }
}
