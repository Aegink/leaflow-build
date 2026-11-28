// T-1602：固定登录字段、真实JavaScript执行、持久化与异常反馈。只写UUID隔离域。
import Foundation

enum LoginActionSampleSelfTest {
    static func run(emit: (String, [String], [String]) -> Void) {
        let suite = "T1602.Login." + UUID().uuidString
        guard let defaults = UserDefaults(suiteName: suite) else { return }
        defer { defaults.removePersistentDomain(forName: suite) }
        var source = BookSource(bookSourceUrl: "https://login.invalid/" + UUID().uuidString,
            bookSourceName: "登录固定样本")
        source.loginUi = #"[{"name":"account","defaultValue":"初始"},{"name":"option","type":"select","chars":[null,"甲","乙"]},{"name":"account","defaultValue":"最终默认"}]"#
        let key = LoginService.loginInfoStateKey(source: source)
        let initial = LoginService.loginInfoMap(source: source, persistDefaults: false, defaults: defaults)
        emit("login_state_defaults_no_write", ["最终默认", "甲", "true"],
            [initial["account"] ?? "", initial["option"] ?? "", String(defaults.object(forKey: key) == nil)])
        _ = LoginService.loginInfoMap(source: source, persistDefaults: true, defaults: defaults)
        emit("login_state_defaults_persist", ["true"],
            [String(LoginService.parseLoginInfoMap(from: defaults.string(forKey: key)) == initial)])
        let edited = ["account": "", "option": "乙", "token": "固定本地值"]
        let saved = LoginService.persistLoginInfo(edited, source: source, defaults: defaults)
        let reopened = UserDefaults(suiteName: suite)!
        emit("login_state_reopen_and_empty", ["true", "true"],
            [String(saved), String(LoginService.loginInfoMap(source: source, persistDefaults: false, defaults: reopened) == edited)])
        defaults.set(#"{"account":"","option":""}"#, forKey: key)
        let resolved = LoginService.resolvedLoginInfo(source: source, items: nil, defaults: defaults)
        emit("login_state_resolved_selection_only", ["", "甲"], [resolved["account"] ?? "缺失", resolved["option"] ?? "缺失"])
        _ = LoginService.persistLoginInfo([:], source: source, defaults: defaults)
        emit("login_state_empty_object_preserved", ["true"],
            [String(LoginService.loginInfoMap(source: source, persistDefaults: true, defaults: defaults).isEmpty)])
        defaults.removeObject(forKey: key)
        defaults.set(["account": "旧值"], forKey: LoginService.loginInfoDefaultsCacheKey(source: source))
        let migrated = LoginService.loginInfoMap(source: source, persistDefaults: true, defaults: defaults)
        emit("login_state_legacy_migration", ["旧值", "true", "true"],
            [migrated["account"] ?? "", String(defaults.string(forKey: key) != nil),
             String(defaults.object(forKey: LoginService.loginInfoDefaultsCacheKey(source: source)) != nil)])
        defaults.set("{", forKey: key)
        emit("login_state_malformed_falls_back", ["最终默认"],
            [LoginService.loginInfoMap(source: source, persistDefaults: false, defaults: defaults)["account"] ?? ""])

        source.loginUrl = "@js:function login(){ result.put('status', result.get('account') + ':' + source.bookSourceName); source.putLoginInfo(result); }"
        let login = LoginService.evaluateLocalAction(source: source, action: nil, formData: ["account": "固定账号"], defaults: defaults)
        emit("login_action_calls_login_and_persists", ["true", "固定账号:登录固定样本"],
            [String(login.success), login.values["status"] ?? ""])
        source.jsLib = "function suffix(v){ return v + ':库'; }"
        source.loginUrl = "<js>function choose(){ result.put('status', suffix(result.get('account'))); source.putLoginInfo(JSON.stringify(result)); }</js>"
        let button = LoginService.evaluateLocalAction(source: source, action: "choose()", formData: ["account": "按钮"], defaults: defaults)
        emit("login_action_library_and_button", ["true", "按钮:库"],
            [String(button.success), button.values["status"] ?? ""])
        source.jsLib = nil
        source.loginUrl = "@js:"
        let mapAction = """
        if(result.get('missing') !== null || result.put('account','替换') !== '原值') throw '取值错误';
        result.putAll({other:3, ignored:function(){}});
        if(!result.containsKey('other') || !result.containsValue('3') || result.size() !== 2) throw '映射错误';
        if(result.remove('other') !== '3' || result.isEmpty()) throw '移除错误';
        source.putLoginInfo(result);
        """
        let map = LoginService.evaluateLocalAction(source: source, action: mapAction,
            formData: ["account": "原值"], defaults: defaults)
        emit("login_action_result_map_contract", ["true", "true"],
            [String(map.success), String(map.values == ["account": "替换"])])
        let throwing = LoginService.evaluateLocalAction(source: source, action: "throw new Error('固定失败')",
            formData: ["account": "保留输入"], defaults: defaults)
        emit("login_action_exception_is_failure", ["false", "true", "保留输入"],
            [String(throwing.success), String(throwing.message != nil), throwing.values["account"] ?? ""])
        let invalid = LoginService.evaluateLocalAction(source: source, action: "function {",
            formData: [:], defaults: defaults)
        emit("login_action_syntax_error_is_failure", ["false"], [String(invalid.success)])
        let falseValue = LoginService.evaluateLocalAction(source: source, action: "false", formData: [:], defaults: defaults)
        emit("login_action_false_value_without_exception", ["true"], [String(falseValue.success)])
        source.loginUrl = "@js:function login(){ source.putLoginInfo({ok:'1'}); }"
        _ = LoginService.evaluateLocalAction(source: source, action: nil, formData: [:], defaults: defaults)
        source.loginUrl = "@js:var noLogin = true;"
        let missing = LoginService.evaluateLocalAction(source: source, action: nil, formData: [:], defaults: defaults)
        emit("login_action_context_does_not_inherit_login", ["false"], [String(missing.success)])
        let browser = LoginService.evaluateLocalAction(source: source, action: "https://login.invalid/page", formData: [:], defaults: defaults)
        emit("login_action_browser_not_false_success", ["false", "true", "true"],
            [String(browser.success), String(LoginService.browserURL("@js:login()") == nil),
             String(LoginService.browserURL("javascript:login()") == nil)])
        source.loginUrl = "<js>function login(){}"
        emit("login_script_unclosed_block_rejected", ["true"], [String(LoginService.getLoginJs(source: source) == nil)])
        source.loginUrl = "@js:function login(){}"
        source.jsLib = "throw new Error('库失败')"
        let badLibrary = LoginService.evaluateLocalAction(source: source, action: nil, formData: [:], defaults: defaults)
        emit("login_action_library_failure_preserved", ["false"], [String(badLibrary.success)])
        do {
            let literal = try JSONDecoder().decode(LoginUiItem.self,
                from: Data(#"{"name":"display","type":"button","viewName":"  '固定名称'  "}"#.utf8))
            let dynamic = try JSONDecoder().decode(LoginUiItem.self,
                from: Data(#"{"name":"display","type":"button","viewName":"source.name"}"#.utf8))
            emit("login_model_literal_and_expression", ["固定名称", "true"],
                [literal.literalViewName ?? "", String(dynamic.literalViewName == nil)])
        } catch { emit("login_model_literal_and_expression", ["通过"], [error.localizedDescription]) }
    }
}
