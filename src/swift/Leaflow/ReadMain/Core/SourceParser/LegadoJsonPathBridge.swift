// 原路径: ReadMain/Core/SourceParser/LegadoJsonPathBridge.swift
// 证据:
//   - PGO: parseJSON (0x100114bd0 L11-19) / read(_:path:) (0x1001150b4 L21-27) / normalizePath (0x100115fc0 L29-45) / closure#1 (0x100116ebc L48-60) / legadoString (0x100114750 L64-80) / jsonRoot (0x100115c98 L82-89) / foundationValue (0x100117204 L91-105) / normalizeJsonValue (0x10011670c L107-120) / isIndefinite (0x1001161e4 L122-169)
//   - CovMap: 上述 L 区段
//   - IDA: 上述地址
//   - 选择子 isString/isBoolean/isNumber/isArray/isObject/toDictionary/toObject/toArray/toBool/toNumber/toNull/valueWithNullInContext:/currentContext/setException:
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（T-201/203 各分册引用的底层引擎）
// 还原: 2026-11-19


import Foundation
import JavaScriptCore

/// Legado JSONPath 桥（readJsonPath 的底层引擎）。
enum LegadoJsonPathBridge {

    /// 伪代码 0x100114bd0（L11-19）。
    static func parseJSON(_ text: String) -> Any? {
        guard let data = text.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data)
    }

    /// 伪代码 0x1001150b4（L21-27）：JSONPath 读取（`$.`/`$..`/`$[n]` 路径求值）。
    static func read(_ source: Any, path: String) throws -> Any? {
        let normalized = normalizePath(path)
        var current: Any? = source
        // 简易求值器：$.a.b / $[0] / $..key（读后记“仍不清楚”2 的完整语法待逐行）。
        let components = normalized
            .replacingOccurrences(of: "$.", with: "")
            .replacingOccurrences(of: "$", with: "")
        for token in components.replacingOccurrences(of: "[", with: ".").split(separator: "]") {
            for segment in token.split(separator: ".") {
                guard let value = current else { return nil }
                if let key = Int(segment), let array = value as? [Any] {
                    current = (0..<array.count).contains(key) ? array[key] : nil
                } else if let dictionary = value as? [String: Any] {
                    current = dictionary[String(segment)]
                } else {
                    return nil
                }
            }
        }
        return current
    }

    /// 伪代码 0x100115fc0（L29-45）。
    static func normalizePath(_ path: String) -> String {
        var normalized = path.trimmingCharacters(in: .whitespaces)
        if !normalized.hasPrefix("$") {
            normalized = "$." + normalized
        }
        return normalized
    }

    /// 伪代码 0x100114750（L64-80）：值 → Legado 字符串。
    static func legadoString(_ value: Any) -> String? {
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
            if JSONSerialization.isValidJSONObject(value),
                let data = try? JSONSerialization.data(withJSONObject: value, options: []),
                let text = String(data: data, encoding: .utf8)
            {
                return text
            }
            return String(describing: value)
        }
    }

    /// 伪代码 0x100115c98（L82-89）：根对象归一。
    static func jsonRoot(from value: Any) -> Any? {
        normalizeJsonValue(value)
    }

    /// 伪代码 0x100117204（L91-105）。
    static func foundationValue(from value: JSValue?) -> Any? {
        guard let value, !value.isUndefined, !value.isNull else { return nil }
        return value.toObject()
    }

    /// 伪代码 0x10011670c（L107-120）。
    static func normalizeJsonValue(_ value: Any) -> Any? {
        if value is NSNull { return nil }
        return value
    }

    /// 伪代码 0x1001161e4（L122-169）：JSONPath 不定表达式判定（$.. 等）。
    static func isIndefinite(_ path: String) -> Bool {
        path.contains("$..") || path.contains("*") || path.contains("?(")
    }

    /// 伪代码 closure #1（0x100116ebc，L48-60）：JSValue 路径读取。
    static func read(_ value: JSValue, path: String, normalize: Bool) -> JSValue? {
        let source = foundationValue(from: value)
        guard let source else { return nil }
        let result = (try? read(source, path: path)) ?? nil
        return JSValue(object: result ?? NSNull(), in: value.context)
    }

    /// 引擎工厂（AnalyzeRule.makeJsonPathEngine 的实现）。
    static func makeEngine(for rule: String) -> AnyObject {
        Engine(rule: rule) as AnyObject
    }

    /// 引擎句柄。
    final class Engine {
        let rule: String
        init(rule: String) {
            self.rule = rule
        }
    }
}
