// T-1602：登录头与表单分域、请求头合并、Cookie域过滤；所有状态为UUID隔离样本。
import Foundation

enum LoginHeaderSampleSelfTest {
    static func run(emit: (String, [String], [String]) -> Void) {
        let suite = "T1602.LoginHeader." + UUID().uuidString
        guard let defaults = UserDefaults(suiteName: suite) else { return }
        defer { defaults.removePersistentDomain(forName: suite) }
        var source = BookSource(bookSourceUrl: "https://" + UUID().uuidString.lowercased() + ".invalid",
            bookSourceName: "登录头样本")
        _ = LoginService.persistLoginInfo(["account": "原表单"], source: source, defaults: defaults)
        LoginService.persistLoginHeader(source: source, rawValue: "  {\"Cookie\":\"sid=fixed\",\"Authorization\":\"sample\"} \n", defaults: defaults)
        let raw = LoginService.rawLoginHeader(source: source, defaults: defaults)
        emit("login_header_distinct_state", ["原表单", "sid=fixed"],
            [LoginService.loginInfoMap(source: source, persistDefaults: false, defaults: defaults)["account"] ?? "",
             LoginService.parseLoginHeaderMap(from: raw)?["Cookie"] ?? ""])
        emit("login_header_reopen", ["true"],
            [String(LoginService.rawLoginHeader(source: source, defaults: UserDefaults(suiteName: suite)!) == raw)])
        var headers = ["cookie": "old", "COOKIE": "duplicate", "Other": "keep"]
        LoginService.setHeader("Cookie", value: "new", in: &headers)
        emit("login_header_case_insensitive_replace", ["2", "new", "keep"],
            [String(headers.count), LoginService.headerValue(in: headers, named: "COOKIE") ?? "", headers["Other"] ?? ""])
        LoginService.removeHeader(named: "cOoKiE", from: &headers)
        emit("login_header_case_insensitive_remove", ["true"], [String(headers == ["Other": "keep"])])
        let merged = LoginService.mergedHeaderMap(source: source,
            sourceHeaders: ["cookie": "old", "user-agent": "custom", "X-Source": "keep"], defaults: defaults)
        emit("login_header_merge_precedence", ["sid=fixed", "sample", "custom", "keep", "4"],
            [LoginService.headerValue(in: merged, named: "Cookie") ?? "", merged["Authorization"] ?? "",
             LoginService.headerValue(in: merged, named: "User-Agent") ?? "", merged["X-Source"] ?? "", String(merged.count)])
        let skipped = LoginService.mergedHeaderMap(source: source, sourceHeaders: ["Cookie": "base"],
            hasLoginHeader: false, defaults: defaults)
        emit("login_header_opt_out_and_user_agent", ["base", "true", "true"],
            [skipped["Cookie"] ?? "", String(skipped["Authorization"] == nil), String(skipped["User-Agent"]?.isEmpty == false)])
        LoginService.persistLoginHeader(source: source, rawValue: "opaque-value", defaults: defaults)
        emit("login_header_raw_preserved", ["opaque-value", "true"],
            [LoginService.rawLoginHeader(source: source, defaults: defaults) ?? "",
             String(LoginService.parseLoginHeaderMap(from: "opaque-value") == nil)])
        LoginService.removeLoginHeaderState(source: source, loginUrl: nil, defaults: defaults)
        emit("login_header_clear_preserves_form", ["true", "原表单"],
            [String(LoginService.rawLoginHeader(source: source, defaults: defaults) == nil),
             LoginService.loginInfoMap(source: source, persistDefaults: false, defaults: defaults)["account"] ?? ""])
        source.loginUrl = "@js:function login(){ source.putLoginHeader({Cookie:'bridge=fixed'}); }"
        let bridge = LoginService.evaluateLocalAction(source: source, action: nil, formData: [:], defaults: defaults)
        emit("login_header_script_bridge", ["true", "bridge=fixed"],
            [String(bridge.success), LoginService.parseLoginHeaderMap(from: LoginService.rawLoginHeader(source: source, defaults: defaults))?["Cookie"] ?? ""])
        let remove = LoginService.evaluateLocalAction(source: source,
            action: "source.putLoginHeader({Cookie:'x'}); if(source.getLoginHeaderMap().Cookie !== 'x') throw '坏值'; source.removeLoginHeader();",
            formData: [:], defaults: defaults)
        emit("login_header_script_remove", ["true", "true"],
            [String(remove.success), String(LoginService.rawLoginHeader(source: source, defaults: defaults) == nil)])

        source.header = #"{"X-Source":"base","Cookie":"base"}"#
        let standardKey = "\(source.stateKey).loginHeader_"
        defer { UserDefaults.standard.removeObject(forKey: standardKey) }
        LoginService.persistLoginHeader(source: source, rawValue: #"{"Cookie":"request=fixed"}"#)
        let request = AnalyzeUrl(ruleUrl: source.bookSourceUrl + "/book", key: nil, page: 1,
            baseUrl: source.bookSourceUrl, source: source)
        emit("login_header_reaches_request", ["base", "request=fixed"],
            [request.headers["X-Source"] ?? "", request.headers["Cookie"] ?? ""])
        let analyzer = AnalyzeRule(source: source, parent: nil, isolatedJavaScript: true)
        defer { analyzer.releaseOwnedJSContext() }
        analyzer.setContent("固定正文", baseUrl: source.bookSourceUrl)
        emit("login_header_reaches_rule_source_bridge", ["request=fixed"],
            [analyzer.getString(rule: "@js:source.getLoginHeaderMap().Cookie", isUrl: false) ?? ""])
        let cookies = [
            HTTPCookie(properties: [.domain: ".example.invalid", .path: "/", .name: "valid", .value: "yes"])!,
            HTTPCookie(properties: [.domain: "other.invalid", .path: "/", .name: "wrong", .value: "no"])!,
            HTTPCookie(properties: [.domain: ".example.invalid", .path: "/", .name: "expired", .value: "no",
                .expires: Date(timeIntervalSince1970: 1)])!
        ]
        let filtered = LoginWebView.matchingCookies(cookies, url: URL(string: "https://sub.example.invalid/")!,
            now: Date(timeIntervalSince1970: 100))
        emit("login_cookie_filter_domain_expiry", ["valid"], [filtered.map(\.name).joined(separator: ",")])
        emit("login_cookie_reject_suffix_collision", ["true"],
            [String(LoginWebView.matchingCookies(cookies, url: URL(string: "https://badexample.invalid/")!).isEmpty)])
    }
}
