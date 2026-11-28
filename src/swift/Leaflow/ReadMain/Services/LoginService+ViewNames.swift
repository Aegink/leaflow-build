// 原路径: ReadMain/Services/LoginService.swift
// 0x100353154/0x100353774/0x100353eb4：字面名直接返回，表达式逐项独立执行。
import Foundation

extension LoginService {
    static func resolveLoginUiViewNames(
        source: BookSource, items: [LoginUiItem], formData: [String: String]
    ) async -> [String: String] {
        await Task.detached(priority: .userInitiated) {
            evaluateLoginUiViewNames(source: source, items: items, formData: formData)
        }.value
    }

    static func evaluateLoginUiViewNames(
        source: BookSource, items: [LoginUiItem], formData: [String: String], defaults: UserDefaults = .standard
    ) -> [String: String] {
        var names: [String: String] = [:]
        let script = browserURL(source.loginUrl ?? "") == nil ? (getLoginJs(source: source) ?? "") : ""
        for item in items {
            if let literal = item.literalViewName { names[item.name] = literal; continue }
            guard let expression = item.viewName?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !expression.isEmpty else { continue }
            let analyzer = configuredAnalyzeRule(source: source, defaults: defaults)
            defer { analyzer.releaseOwnedJSContext() }
            let context = analyzer.jsContextHandle()
            if context.exception != nil { names[item.name] = "err"; continue }
            injectLoginResultObject(formData, into: analyzer)
            context.exception = nil
            let value = context.evaluateScript(script + "\n" + expression)
            if context.exception != nil { names[item.name] = "err"; continue }
            if let value, !value.isUndefined, !value.isNull, let text = value.toString(),
               !text.isEmpty, text != "undefined" { names[item.name] = text }
        }
        return names
    }

    /// SourceLoginView 0x100c8fcd4：保留已存字段，只覆盖非按钮表单，空字符串也是编辑结果。
    static func editedLoginInfo(
        source: BookSource, items: [LoginUiItem], values: [String: String], defaults: UserDefaults = .standard
    ) -> [String: String] {
        var result = loginInfoMap(source: source, persistDefaults: false, defaults: defaults)
        for item in items where item.normalizedType != "button" {
            result[item.name] = values[item.name] ?? item.resolvedDefaultValue
        }
        return result
    }
}
