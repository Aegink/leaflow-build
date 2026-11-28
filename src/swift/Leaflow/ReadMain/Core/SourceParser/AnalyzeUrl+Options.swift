// 原路径: ReadMain/Core/SourceParser/AnalyzeUrl.swift；原始文件规模与分母不变。
import Foundation

extension AnalyzeUrl {
    /// 0x10008d854：URL后的JSON配置包含完整大括号，剥离后URL才能交给请求构造。
    @discardableResult
    func parseJsonConfig(_ rule: String) -> String {
        guard let delimiter = rule.range(of: ",\\s*\\{", options: .regularExpression) else { return rule }
        let jsonStart = rule.index(before: delimiter.upperBound)
        guard let data = String(rule[jsonStart...]).data(using: .utf8),
              let config = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            urlParseError = "URL请求配置不是有效JSON对象"
            return ""
        }
        if let value = config["method"] as? String { method = value.uppercased() }
        if let value = config["charset"] as? String { charset = value }
        if let value = config["body"] as? String {
            body = value
        } else if let value = config["body"], JSONSerialization.isValidJSONObject(value),
                  let encoded = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]) {
            body = String(decoding: encoded, as: UTF8.self)
        }
        if let value = config["webView"] { useWebView = (value as? Bool) ?? (value as? String == "true") }
        if let value = config["retry"] as? Int { retry = max(0, value) }
        let header = config["headers"] ?? config["header"]
        if let value = header as? String {
            headersJson = value
        } else if let value = header as? [String: String],
                  let encoded = try? JSONSerialization.data(withJSONObject: value) {
            headersJson = String(decoding: encoded, as: UTF8.self)
        }
        return String(rule[..<delimiter.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
