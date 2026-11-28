import XCTest

extension LeaflowSmokeTests {
    func testBackupRestoreFilePickerEntry() {
        launch(["-smokeBackupSettings"])
        let restore = app.buttons["backup-import-restore"]
        for _ in 0..<4 where !restore.isHittable { app.swipeUp() }
        XCTAssertTrue(restore.waitForExistence(timeout: 10))
        restore.tap()
        let cancel = app.buttons.matching(NSPredicate(format: "label IN %@", ["Cancel", "取消"])).firstMatch
        // 失败层级已出现系统选择器；首次文件服务启动可能超过15秒，仍要求实际取消按钮可操作。
        XCTAssertTrue(cancel.waitForExistence(timeout: 30), "备份恢复必须打开系统文件选择器")
        capture("backup-restore-file-picker")
        cancel.tap()
        XCTAssertTrue(restore.waitForExistence(timeout: 10))
        XCTAssertFalse(app.alerts["确认恢复"].exists)
        passed("backup_restore_import_entry")
    }

    func testBackupCategoryPersistence() {
        executionTimeAllowance = 300
        let categories = ["bookshelf", "bookmarks", "readingStats", "config", "chapterRules", "replaceRules",
                          "ttsSources", "readingSettings", "highlightRules", "appearance", "localBooks"]
        func open() {
            launch(["-smokeBackupSettings"])
            let content = app.buttons["backup-sync-categories"]
            if !content.isHittable { app.swipeUp() }
            XCTAssertTrue(content.waitForExistence(timeout: 15))
            content.tap()
            XCTAssertTrue(app.navigationBars["同步内容"].waitForExistence(timeout: 10))
        }
        func toggle(_ name: String, to enabled: Bool) {
            let control = app.switches["sync-category-" + name]
            for _ in 0..<4 {
                if control.isHittable { break }
                app.swipeUp()
            }
            XCTAssertTrue(control.exists || control.waitForExistence(timeout: 10))
            XCTAssertTrue(control.isHittable)
            if (control.value as? String == "1") != enabled {
                // 失败层级同时暴露整行Switch和51×31实体Switch，直接定位行内实体中心。
                let row = control.frame
                let actual = app.switches.allElementsBoundByIndex.first {
                    let frame = $0.frame
                    return frame.width > 0 && frame.width < 80
                        && row.contains(CGPoint(x: frame.midX, y: frame.midY)) && $0.isHittable
                }
                XCTAssertNotNil(actual, "同步分类行必须包含实际开关")
                actual?.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            }
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "value == %@", enabled ? "1" : "0"), object: control)], timeout: 5), .completed)
        }
        open()
        for category in categories { toggle(category, to: false) }
        capture("backup-all-categories-off")
        open()
        for category in categories {
            let control = app.switches["sync-category-" + category]
            for _ in 0..<4 {
                if control.isHittable { break }
                app.swipeUp()
            }
            XCTAssertTrue(control.exists || control.waitForExistence(timeout: 10))
            XCTAssertEqual(control.value as? String, "0")
        }
        capture("backup-empty-selection-cold")
        passed("backup_category_persistence")
    }

    func testBackupCategoryRestoreDefaults() {
        executionTimeAllowance = 300
        launch(["-smokeBackupSettings", "-smokeBackupEmptySelection"])
        let content = app.buttons["backup-sync-categories"]
        if !content.isHittable { app.swipeUp() }
        XCTAssertTrue(content.waitForExistence(timeout: 15))
        content.tap()
        XCTAssertTrue(app.navigationBars["同步内容"].waitForExistence(timeout: 10))
        let categories = ["bookshelf", "bookmarks", "readingStats", "config", "chapterRules", "replaceRules",
                          "ttsSources", "readingSettings", "highlightRules", "appearance", "localBooks"]
        for category in categories {
            let control = app.switches["sync-category-" + category]
            for _ in 0..<4 {
                if control.isHittable { break }
                app.swipeUp()
            }
            XCTAssertTrue(control.isHittable)
            XCTAssertEqual(control.value as? String, "0")
            guard category != "localBooks" else { continue }
            let row = control.frame
            let actual = app.switches.allElementsBoundByIndex.first {
                let frame = $0.frame
                return frame.width > 0 && frame.width < 80
                    && row.contains(CGPoint(x: frame.midX, y: frame.midY)) && $0.isHittable
            }
            XCTAssertNotNil(actual)
            if let actual {
                let frame = actual.frame
                app.coordinate(withNormalizedOffset: .zero)
                    .withOffset(CGVector(dx: frame.midX, dy: frame.midY)).tap()
            }
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "value == %@", "1"), object: control)], timeout: 5), .completed)
        }
        capture("backup-default-categories-restored")
        passed("backup_category_restore_defaults")
    }
}
