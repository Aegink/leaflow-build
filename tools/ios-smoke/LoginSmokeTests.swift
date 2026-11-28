import XCTest

extension LeaflowSmokeTests {
    func testSourceLoginActionsAndColdPersistence() {
        executionTimeAllowance = 300
        launch(["-smokeSourceLogin"])
        openSourceLogin()
        let account = app.textFields["source-login-field-account"]
        XCTAssertTrue(account.waitForExistence(timeout: 10))
        let statusField = app.textFields["source-login-field-status"]
        XCTAssertGreaterThan(statusField.frame.minY, account.frame.maxY)
        XCTAssertGreaterThan(account.frame.width, app.frame.width * 0.7)
        XCTAssertFalse(app.staticTexts["登录成功"].exists)
        account.tap()
        account.typeText("sample")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "字段:sample"), object: statusField)], timeout: 10), .completed)
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", "执行:sample"),
            object: app.buttons["source-login-action-apply"])], timeout: 10), .completed)
        app.buttons["source-login-action-apply"].tap()
        let status = app.staticTexts["source-login-status"]
        XCTAssertTrue(status.waitForExistence(timeout: 10))
        XCTAssertEqual(status.label, "动作执行成功")
        XCTAssertEqual(app.textFields["source-login-field-status"].value as? String, "按钮:sample")
        app.buttons["source-login-submit"].tap()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", "登录成功"), object: status)], timeout: 10), .completed)
        XCTAssertEqual(app.textFields["source-login-field-status"].value as? String, "登录:sample")
        app.buttons["source-login-action-fail"].tap()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS %@", "执行失败"), object: status)], timeout: 10), .completed)
        capture("source-login-failure")
        app.buttons["source-login-close"].tap()
        launch(["-smokeSourceLogin"])
        openSourceLogin()
        XCTAssertTrue(account.waitForExistence(timeout: 10))
        XCTAssertEqual(account.value as? String, "sample")
        XCTAssertEqual(app.textFields["source-login-field-status"].value as? String, "登录:sample")
        capture("source-login-cold")
        passed("source_login_actions_persistence")
    }

    private func openSourceLogin() {
        let menu = app.buttons["book-detail-menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 30))
        menu.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let login = app.buttons["book-detail-login"]
        XCTAssertTrue(login.waitForExistence(timeout: 10))
        login.tap()
    }
}
