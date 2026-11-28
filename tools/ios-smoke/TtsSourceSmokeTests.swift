import XCTest

extension LeaflowSmokeTests {
    func testTtsSourceFilePickerEntry() {
        launch(["-smokeTtsSources"])
        let menu = app.buttons["tts-source-actions"]
        XCTAssertTrue(menu.waitForExistence(timeout: 15))
        menu.tap()
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
