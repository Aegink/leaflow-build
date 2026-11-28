// T-1602：登录配置静态/脚本输入、书籍章节上下文与错误结果，隔离用户状态。
import Foundation

enum LoginUISampleSelfTest {
    static func run(emit: (String, [String], [String]) -> Void) {
        let suite = "T1602.LoginUI." + UUID().uuidString
        guard let defaults = UserDefaults(suiteName: suite) else { return }
        defer { defaults.removePersistentDomain(forName: suite) }
        var source = BookSource(bookSourceUrl: "https://login-ui.invalid/" + UUID().uuidString, bookSourceName: "表单配置")
        source.loginUi = #"[{"name":"static","defaultValue":"静态值"}]"#
        var parsed = LoginService.parseLoginUiItems(source: source, defaults: defaults)
        emit("login_ui_static_json", ["static", "静态值", "true"],
            [parsed.items.first?.name ?? "", parsed.items.first?.resolvedDefaultValue ?? "", String(parsed.error == nil)])
        _ = LoginService.persistLoginInfo(["account": "存值"], source: source, defaults: defaults)
        source.jsLib = "function title(){return '库值';}"
        source.loginUrl = "@js:function makeUi(){return [{name:'generated',defaultValue:title() + ':' + result.get('account')}];}"
        source.loginUi = "@js:JSON.stringify(makeUi())"
        parsed = LoginService.parseLoginUiItems(source: source, defaults: defaults)
        emit("login_ui_script_json_and_context", ["generated", "库值:存值", "true"],
            [parsed.items.first?.name ?? "", parsed.items.first?.resolvedDefaultValue ?? "", String(parsed.error == nil)])
        source.loginUi = "<js>makeUi()</js>"
        parsed = LoginService.parseLoginUiItems(source: source, defaults: defaults)
        emit("login_ui_script_array_block", ["库值:存值", "true"],
            [parsed.items.first?.resolvedDefaultValue ?? "", String(parsed.error == nil)])
        let book = Book(name: "上下文书籍")
        let chapter = Chapter(name: "上下文章节", url: "/chapter", index: 0, isRead: false,
            isPay: false, resourceUrl: nil, isVip: false, isVolume: false,
            updateTime: nil, wordCount: nil, variable: nil)
        source.loginUi = "@js:[{name:'context',defaultValue:book.name + '/' + chapter.name}]"
        parsed = LoginService.parseLoginUiItems(source: source, book: book, chapter: chapter, defaults: defaults)
        emit("login_ui_book_chapter_context", ["上下文书籍/上下文章节"], [parsed.items.first?.resolvedDefaultValue ?? ""])
        source.loginUi = "@js:throw new Error('固定错误')"
        parsed = LoginService.parseLoginUiItems(source: source, defaults: defaults)
        emit("login_ui_script_error_not_empty_success", ["true", "true"], [String(parsed.items.isEmpty), String(parsed.error != nil)])
        source.loginUi = "{"
        parsed = LoginService.parseLoginUiItems(source: source, defaults: defaults)
        emit("login_ui_invalid_json_error", ["true"], [String(parsed.error != nil)])
        source.loginUi = "@js:undefined"
        parsed = LoginService.parseLoginUiItems(source: source, defaults: defaults)
        emit("login_ui_missing_script_result_error", ["true"], [String(parsed.error != nil)])
        source.loginUi = nil
        parsed = LoginService.parseLoginUiItems(source: source, defaults: defaults)
        emit("login_ui_absent_configuration", ["true", "true"], [String(parsed.items.isEmpty), String(parsed.error == nil)])
        source.loginUrl = "@js:function login(){java.upLoginData({account:'桥更新',remove:null,flag:true,count:3});}"
        let action = LoginService.evaluateLocalAction(source: source, action: nil,
            formData: ["account": "旧值", "remove": "删除", "keep": "保留"], defaults: defaults)
        emit("login_callback_updates_persisted_form", ["true", "桥更新", "保留", "true", "true", "3"],
            [String(action.success), action.values["account"] ?? "", action.values["keep"] ?? "",
             String(action.values["remove"] == nil), action.values["flag"] ?? "", action.values["count"] ?? ""])
        let empty = LoginService.evaluateLocalAction(source: source, action: "java.upLoginData(null)",
            formData: ["keep": "未清空"], defaults: defaults)
        emit("login_callback_null_preserves_form", ["true", "未清空"], [String(empty.success), empty.values["keep"] ?? ""])
        let reload = LoginService.evaluateLocalAction(source: source,
            action: "java.reLoginView(true);java.refreshExplore();", formData: ["keep": "刷新不丢"], defaults: defaults)
        emit("login_callback_reload_methods_execute", ["true", "刷新不丢"], [String(reload.success), reload.values["keep"] ?? ""])
        let second = BookSource(bookSourceUrl: source.bookSourceUrl + "/other", bookSourceName: "另一书源")
        emit("login_callback_source_state_isolation", ["true"],
            [String(LoginService.loginInfoMap(source: second, persistDefaults: false, defaults: defaults).isEmpty)])
    }
}
