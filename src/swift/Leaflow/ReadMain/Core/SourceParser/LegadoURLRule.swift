// 原路径: ReadMain/Core/SourceParser/LegadoURLRule.swift
// 证据:
//   - PGO: Options.long(_:) (0x100118a6c L35-41) / Options.method (0x100118058 L43-49) / Options.usesWebView (0x10011885c L52-67) / Options.headers (0x100118444 L77-95) / Options.kotlinString(LL) (0x100118ee8 L105-123)
//   - CovMap: L35-41 @0x100118a6c；L43-49 @0x100118058；L52-67 @0x10011885c；L77-95 @0x100118444；L105-123 @0x100118ee8
//   - IDA: 上述地址
//   - 选择子 integerValue/boolValue/stringValue；诊断 [searchBook] source=/keywordChars=/hasSearchRule=
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（Options 访问器逐条对应）
// 还原: 2026-11-19


import Foundation

/// Legado URL 规则的 options 字典访问器。
struct LegadoURLRule {

    struct Options {
        let dictionary: [String: Any]

        /// 伪代码 0x100118a6c（L35-41）。
        static func long(_ value: Any?) -> Int? {
            (value as? NSNumber)?.intValue ?? Int(value as? String ?? "")
        }

        /// 伪代码 0x100118058（L43-49）。
        func method() -> String {
            let raw = dictionary["method"] as? String ?? "GET"
            return raw.uppercased()
        }

        /// 伪代码 0x10011885c（L52-67）。
        func usesWebView() -> Bool {
            let value = dictionary["webView"]
            if let flag = value as? Bool { return flag }
            if let text = value as? String { return text == "true" }
            if let number = value as? Int { return number == 1 }
            return false
        }

        /// 伪代码 0x100118444（L77-95）。
        func headers() -> [String: String]? {
            dictionary["headers"] as? [String: String]
        }

        /// 伪代码 0x100118ee8（L105-123）：Kotlin 风格字符串化。
        static func kotlinString(_ value: Any) -> String {
            if let string = value as? String { return string }
            if let number = value as? NSNumber { return number.stringValue }
            return String(describing: value)
        }

        var charset: String {
            dictionary["charset"] as? String ?? "utf-8"
        }

        var body: String? {
            dictionary["body"] as? String
        }

        var retry: Int {
            Options.long(dictionary["retry"]) ?? 0
        }
    }
}
