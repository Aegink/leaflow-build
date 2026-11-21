// 原路径: ReadMain/Core/SourceParser/LegadoJSONLiteral.swift
// 证据:
//   - PGO: parse(_:) (0x100112d8c L6-19) / stringMap(from:) (0x100113130 L34-43) / hasTopLevelArrayTrailingComma (0x100113840 L51-120) / jsonString(from:) (0x1001181d0 L122-128) / stringValue(_:) (0x100113494 L130-142)
//   - CovMap: 上述 L 区段
//   - IDA: 上述地址
//   - 桥键 _nativeJsonPathRead；宽松 JSON 容错（数组尾逗号）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（六函数逐条对应）
// 还原: 2026-11-19


import Foundation

/// Legado JSON 字面量工具（书源 JSON 的宽松解析）。
enum LegadoJSONLiteral {

    /// 伪代码 0x100112d8c（L6-19）。
    static func parse(_ text: String?) -> Any? {
        guard let text, !text.isEmpty else { return nil }
        if let data = text.data(using: .utf8),
            let object = try? JSONSerialization.jsonObject(with: data)
        {
            return object
        }
        // 容错：数组尾逗号修复后重试。
        if hasTopLevelArrayTrailingComma(text) {
            let repaired = text.replacingOccurrences(
                of: ",\\s*\\]", with: "]", options: .regularExpression
            )
            if let data = repaired.data(using: .utf8),
                let object = try? JSONSerialization.jsonObject(with: data)
            {
                return object
            }
        }
        return nil
    }

    /// 伪代码 0x100113130（L34-43）。
    static func stringMap(from value: Any?) -> [String: String]? {
        guard let dictionary = value as? [String: Any] else { return nil }
        var result: [String: String] = [:]
        for (key, item) in dictionary {
            result[key] = stringValue(item)
        }
        return result
    }

    /// 伪代码 0x100113840（L51-120）：顶层数组尾逗号检测。
    static func hasTopLevelArrayTrailingComma(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("["), trimmed.hasSuffix("]") else { return false }
        return trimmed.range(of: ",\\s*\\]", options: .regularExpression) != nil
    }

    /// 伪代码 0x1001181d0（L122-128）。
    static func jsonString(from value: Any) -> String? {
        guard JSONSerialization.isValidJSONObject(value),
            let data = try? JSONSerialization.data(withJSONObject: value, options: []),
            let text = String(data: data, encoding: .utf8)
        else { return nil }
        return text
    }

    /// 伪代码 0x100113494（L130-142）。
    static func stringValue(_ value: Any?) -> String? {
        guard let value else { return nil }
        switch value {
        case let string as String:
            return string
        case let number as NSNumber:
            return number.stringValue
        case let bool as Bool:
            return bool ? "true" : "false"
        case is NSNull:
            return nil
        default:
            return jsonString(from: value) ?? String(describing: value)
        }
    }
}
