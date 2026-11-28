import XCTest

extension LeaflowSmokeTests {
    func testTtsConfigurationActionAndColdPersistence() {
        executionTimeAllowance = 300
        func openConfig(_ arguments: [String]) {
            launch(arguments)
            let actions = app.buttons["tts-source-row-actions-1602005"]
            XCTAssertTrue(actions.waitForExistence(timeout: 15))
            actions.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            app.buttons["配置"].tap()
            XCTAssertTrue(app.textFields["tts-config-text-account"].waitForExistence(timeout: 15))
        }
        openConfig(["-smokeTtsSources", "-smokeTtsSourcesReset", "-smokeTtsConfigSeed"])
        let account = app.textFields["tts-config-text-account"]
        account.tap()
        account.typeText("fixed")
        app.buttons["tts-config-action-apply"].tap()
        let status = app.textFields["tts-config-text-status"]
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "fixed-saved"), object: status)], timeout: 15), .completed)
        XCTAssertEqual(app.staticTexts["tts-config-result"].label, "配置已执行")
        capture("tts-configuration-action")
        app.buttons["保存"].tap()
        openConfig(["-smokeTtsSources"])
        XCTAssertEqual(account.value as? String, "fixed")
        XCTAssertEqual(status.value as? String, "fixed-saved")
        capture("tts-configuration-cold")
        app.buttons["关闭"].tap()
        passed("tts_configuration_action_persistence")
    }

    func testTtsHelpLoadsAndSearches() {
        launch(["-smokeTtsSources"])
        let help = app.buttons["tts-source-help"]
        XCTAssertTrue(help.waitForExistence(timeout: 15))
        help.tap()
        XCTAssertTrue(app.webViews.firstMatch.waitForExistence(timeout: 20))
        XCTAssertFalse(app.staticTexts["帮助文档未随包提供"].exists)
        // 模态页下方管理页也暴露搜索框，必须选择当前帮助页的搜索框。
        let search = app.searchFields.matching(NSPredicate(format: "label BEGINSWITH %@", "匹配")).firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()
        search.typeText("setResponseBase64")
        let count = app.staticTexts["tts-help-match-count"]
        let positive = NSPredicate { _, _ in
            (Int(count.label.replacingOccurrences(of: "匹配 ", with: "")) ?? 0) > 0
        }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: positive, object: count)], timeout: 20), .completed)
        capture("tts-help-search")
        search.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 17))
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "匹配 0"), object: count)], timeout: 10), .completed)
        let cancelSearch = app.buttons.matching(NSPredicate(format: "label IN %@", ["Cancel", "取消"])).firstMatch
        XCTAssertTrue(cancelSearch.waitForExistence(timeout: 10))
        cancelSearch.tap()
        let close = app.buttons["关闭"]
        XCTAssertTrue(close.waitForExistence(timeout: 10))
        close.tap()
        XCTAssertTrue(help.waitForExistence(timeout: 10))
        passed("tts_help_document_search")
    }

    func testTtsSourceFilePickerEntry() {
        launch(["-smokeTtsSources"])
        let menu = app.buttons["tts-source-actions"]
        XCTAssertTrue(menu.waitForExistence(timeout: 15))
        XCTAssertFalse(menu.frame.isEmpty)
        XCTAssertTrue(app.frame.contains(menu.frame))
        menu.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        app.buttons["从文件导入"].tap()
        let cancel = app.buttons.matching(NSPredicate(format: "label IN %@", ["Cancel", "取消"])).firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 30))
        capture("tts-source-file-picker")
        cancel.tap()
        XCTAssertTrue(menu.waitForExistence(timeout: 10))
        passed("tts_source_file_picker_entry")
    }

    func testTtsSourceSelectionAndEditPersistence() {
        executionTimeAllowance = 300
        launch(["-smokeTtsSources", "-smokeTtsSourcesReset"])
        let add = app.buttons["tts-source-add"]
        XCTAssertTrue(add.waitForExistence(timeout: 15))
        add.tap()
        let name = app.textFields["名称"]
        XCTAssertTrue(name.waitForExistence(timeout: 10))
        name.tap()
        name.typeText("固定朗读源")
        let url = app.textViews["tts-edit-url"].exists
            ? app.textViews["tts-edit-url"] : app.textFields["tts-edit-url"]
        XCTAssertTrue(url.exists)
        url.tap()
        url.typeText("https://sample.invalid/tts")
        app.buttons["保存"].tap()
        let select = app.buttons["tts-source-select-8568882549994028021"]
        XCTAssertTrue(select.waitForExistence(timeout: 10))
        select.tap()
        XCTAssertEqual(select.value as? String, "已选择")
        let edit = app.buttons["tts-source-current-edit"]
        XCTAssertTrue(edit.waitForExistence(timeout: 10))
        edit.tap()
        XCTAssertTrue(name.waitForExistence(timeout: 10))
        XCTAssertEqual(name.value as? String, "固定朗读源")
        XCTAssertEqual(url.value as? String, "https://sample.invalid/tts")
        name.tap()
        name.typeText("改名")
        app.buttons["保存"].tap()
        XCTAssertTrue(edit.waitForExistence(timeout: 10))
        capture("tts-source-selected-edited")
        launch(["-smokeTtsSources"])
        XCTAssertTrue(edit.waitForExistence(timeout: 15))
        XCTAssertEqual(select.value as? String, "已选择")
        XCTAssertTrue(app.staticTexts["固定朗读源改名"].firstMatch.exists)
        edit.tap()
        XCTAssertTrue(name.waitForExistence(timeout: 10))
        XCTAssertEqual(name.value as? String, "固定朗读源改名")
        app.buttons["取消"].tap()
        let system = app.buttons["tts-source-system"]
        XCTAssertTrue(system.waitForExistence(timeout: 10))
        system.tap()
        XCTAssertEqual(system.value as? String, "已选择")
        capture("tts-source-system-selected")
        passed("tts_source_selection_edit_persistence")
    }
}
