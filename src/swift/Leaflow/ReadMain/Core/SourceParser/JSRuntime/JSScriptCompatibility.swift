// 原路径: ReadMain/Core/SourceParser/ReadMain/Core/SourceParser/JSRuntime/JSScriptCompatibility.swift
// 证据:
//   - PGO: sanitizeJavaScriptForCompatibility(_:convertLegadoTemplates:) (0x10007e570 L15-57) / convertSimpleIdentifierTemplatesInTemplateLiterals(LL) (0x10007ea0c L59-107)
//   - CovMap: L15-57 @0x10007e570；L59-107 @0x10007ea0c
//   - IDA: 0x10007e570/0x10007ea0c
//   - 模板字面量标识符转换
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: medium（清洗规则集合见读后记仍不清楚 1）
// 还原: 2026-11-19


import Foundation

/// JS 兼容清洗（JSScriptCompatibility）。
enum JSScriptCompatibility {

    /// 伪代码 0x10007e570（L15-57）：清洗 + Legado 模板转换。
    static func sanitizeJavaScriptForCompatibility(
        _ script: String,
        convertLegadoTemplates: Bool
    ) -> String {
        var prepared = script
        if convertLegadoTemplates {
            prepared = convertSimpleIdentifierTemplatesInTemplateLiterals(prepared)
        }
        // 伪代码：模板字面量内简单标识符 → 安全形态，规避 iOS JavaScriptCore 语法差异。
        return prepared
    }

    /// 伪代码 0x10007ea0c（L59-107）：`{{name}}` 简单标识符模板转换。
    static func convertSimpleIdentifierTemplatesInTemplateLiterals(_ script: String) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: "\\{\\{\\s*([A-Za-z_$][A-Za-z0-9_$]*)\\s*\\}\\}"
        ) else {
            return script
        }
        let range = NSRange(script.startIndex..<script.endIndex, in: script)
        return regex.stringByReplacingMatches(
            in: script, options: [], range: range,
            withTemplate: "$${$1}"
        )
    }
}
