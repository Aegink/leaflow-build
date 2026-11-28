// 原路径: ReadMain/Services/LoginService.swift
// 0x1003518a8实际执行loginUi规则：前缀剥离、已存result、登录脚本前置、结果解码。
import Foundation

extension LoginService {
    struct UIParseResult {
        let items: [LoginUiItem]
        let error: String?
    }

    static func parseLoginUi(source: BookSource, book: Book?, chapter: Chapter?) async -> UIParseResult {
        await Task.detached(priority: .userInitiated) {
            parseLoginUiItems(source: source, book: book, chapter: chapter)
        }.value
    }

    static func parseLoginUiItems(
        source: BookSource, book: Book? = nil, chapter: Chapter? = nil, defaults: UserDefaults = .standard
    ) -> UIParseResult {
        guard let raw = source.loginUi, !raw.isEmpty else { return UIParseResult(items: [], error: nil) }
        var json = raw
        if raw.hasPrefix("@js:") || raw.hasPrefix("<js>") {
            var uiSource = source
            uiSource.loginUrl = raw
            guard let script = getLoginJs(source: uiSource) else {
                return UIParseResult(items: [], error: "登录表单脚本格式无效")
            }
            let analyzer = configuredAnalyzeRule(source: source, book: book, chapter: chapter, defaults: defaults)
            defer { analyzer.releaseOwnedJSContext() }
            let context = analyzer.jsContextHandle()
            guard context.exception == nil else { return UIParseResult(items: [], error: "登录脚本库执行失败") }
            let persisted = parseLoginInfoMap(from: defaults.string(forKey: loginInfoStateKey(source: source))) ?? [:]
            injectLoginResultObject(persisted, into: analyzer)
            let prefix = browserURL(source.loginUrl ?? "") == nil ? (getLoginJs(source: source) ?? "") : ""
            context.exception = nil
            let evaluated = context.evaluateScript(prefix + "\n" + script)
            guard context.exception == nil, let evaluated, !evaluated.isUndefined, !evaluated.isNull else {
                return UIParseResult(items: [], error: "登录表单脚本执行失败")
            }
            if evaluated.isString { json = evaluated.toString() ?? "" }
            else if let object = evaluated.toObject(), JSONSerialization.isValidJSONObject(object),
                    let data = try? JSONSerialization.data(withJSONObject: object) {
                json = String(decoding: data, as: UTF8.self)
            } else { return UIParseResult(items: [], error: "登录表单脚本未返回有效配置") }
        }
        guard let items = decodeLoginUiItems(from: json) else {
            return UIParseResult(items: [], error: "登录表单配置格式无效")
        }
        return UIParseResult(items: items, error: nil)
    }
}
