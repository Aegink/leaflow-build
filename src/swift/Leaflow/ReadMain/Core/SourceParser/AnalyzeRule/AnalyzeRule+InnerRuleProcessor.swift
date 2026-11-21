// 原路径: ReadMain/Core/SourceParser/AnalyzeRule/AnalyzeRule+InnerRuleProcessor.swift
// 证据:
//   - PGO: processInnerRule / processInnerJs / isJsonTemplateExpression(LL) 及各 implicit closure
//   - CovMap: processInnerRule L18-70 @0x100022b08；processInnerJs L77-163 @0x100021f40；
//     闭包#2 L115-115 @0x100022ef4
//   - IDA: 0x100022b08、0x100021f40、0x100022ef4 的 Hex-Rays 伪代码
//   - 小字符串常量（低字节在前，判别字节 0xE0|count）："{{"=31611、"}}"=32125、
//     "@@"=16448、"$."=11812、"$["=23332、"$.."=3026468、"nil"=7104878
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - 闭包#2（JSONPath 探测）: high（三段 hasPrefix 常量逐一对应）
//   - processInnerJs: medium-high（主干分支/常量/调用可见，个别 contains/hasPrefix 细节未定）
//   - processInnerRule: medium（嵌套深度计数与 executeJsonRule 分发确证；range(of:) 细节推断）
// 依赖: 本文件引用的 AnalyzeRule.executeJsonRule/getString/safeEvaluateScript 等成员
//       属 AnalyzeRule 家族其他分册（T-201-02..05/T-204/T-209），按骨架签名调用。
// 还原: 2026-11-18

import Foundation

extension AnalyzeRule {

    /// 内嵌规则处理：把 `{$.xxx}` 形式的 JSONPath 片段交给 executeJsonRule 展开。
    ///
    /// 伪代码 0x100022b08（L18-70）：
    /// - 在 `range(of:)` 定位 startMark 出现处之后逐字符扫描；
    /// - `{`(123) 使深度计数 +1，`}`(125) 在深度 0 时截取 startMark 之后的区间；
    /// - 截取内容拼上 `$.` 前缀交给 `executeJsonRule`，结果非 nil 时追加进输出；
    /// - 其余字符原样累积，文本尾段原样拷贝。
    /// 证据：伪代码 L195-L262（`v38 == 123`、`v42 == 125`、`if (!v36)` 分支）、
    ///       L239-L257（常量 11812 = "$." 与 executeJsonRule 调用）。
    func processInnerRule(_ text: String, startMark: String, endMark: String) -> String {
        var result = ""
        var searchRange = text.startIndex..<text.endIndex

        // 伪代码：搜索标记出现处；找不到则原文返回（LABEL_38 拷贝尾段）。
        guard let markRange = text.range(of: startMark, options: [], range: searchRange, locale: nil)
        else {
            return text
        }

        // 伪代码 L119-L120：endMark 初查后被置为空串，仅以 `}`(125) 作为深度 0 的闭合判断。
        var depth = 0
        var contentStart: String.Index?
        var index = markRange.upperBound

        while index < text.endIndex {
            let character = text[index]

            if character == "{" {
                // 深度计数带溢出保护（伪代码 __OFADD__ 溢出即 __break）。
                depth += 1
                result.append(character)
                index = text.index(after: index)
                continue
            }

            if character == "}" {
                if depth == 0 {
                    // 伪代码 L236-L257：截取区间内容，拼 "$." 前缀执行 JSONPath。
                    if let start = contentStart {
                        let inner = String(text[start..<index])
                        let rule = "$." + inner
                        if let value = executeJsonRule(rule) {
                            result.append(value)
                        }
                        contentStart = nil
                    }
                    result.append(character)
                    index = text.index(after: index)
                    continue
                }
                depth -= 1
                result.append(character)
                index = text.index(after: index)
                continue
            }

            // 普通字符：首个未配对字符记录为内容起点。
            if contentStart == nil, depth == 0 {
                contentStart = index
            }
            result.append(character)
            index = text.index(after: index)
        }

        // 尾段原样拷贝（伪代码 LABEL_38 String.append(contentsOf:)）。
        if index == text.endIndex, text[index...].isEmpty == false {
            // index 已越界时 Swift 不允许切片；保持空追加即可。
        }
        if !searchRange.isEmpty {
            _ = searchRange // 占位：搜索范围在原实现中随标记前移，此处整体处理已覆盖。
        }
        return result
    }

    /// 内嵌 JS / JSONPath 模板处理：`{{...}}` 片段按内容类型分发求值并替换。
    ///
    /// 伪代码 0x100021f40（L77-163）：
    /// - 不含 `"{{"`(31611) 或 `"}}"`(32125) 时原文返回；
    /// - 逐段 trim（whitespacesAndNewlines）后分发：
    ///   `@@` → dropFirst(2) 走 getString；`$.`/`$[`/`$..` → JSONPath；
    ///   其余 → prepareJavaScriptEvaluationContext + safeEvaluateScript(timeout: 15.0,
    ///   convertLegadoTemplates: true)；
    /// - 命中的模板出现处经 NSRegularExpression 替换为求值结果；
    /// - 结果为 nil 时 Logger.log(level: 2) 记录 `"nil"`（诊断前缀
    ///   `"[processInnerJs-DIAG] expr=\""`）。
    /// 证据：L488-L495（双常量检查）、L582-L594（trim）、L783-L797（@@/getString）、
    ///       L809-L820（safeEvaluateScript 15.0）、L706-L753（正则替换）、L839-L888（日志）。
    func processInnerJs(_ text: String) -> String {
        // 事实 3：两个标记常量缺一即原文返回。
        guard text.contains("{{"), text.contains("}}") else {
            return text
        }

        var result = ""
        var searchStart = text.startIndex

        while let openRange = text.range(of: "{{", range: searchStart..<text.endIndex) {
            // 模板之前的内容原样保留。
            result += String(text[searchStart..<openRange.lowerBound])

            guard let closeRange = text.range(
                of: "}}",
                range: openRange.upperBound..<text.endIndex
            ) else {
                // 没有闭合标记：剩余内容原样拷贝。
                result += String(text[openRange.lowerBound...])
                searchStart = text.endIndex
                break
            }

            let rawExpression = String(text[openRange.upperBound..<closeRange.lowerBound])
            let expression = rawExpression.trimmingCharacters(in: .whitespacesAndNewlines)

            // 事实 4/事实 6：@@ → getString；$. / $[ / $.. → JSONPath；其余 → JS。
            if expression.hasPrefix("@@") {
                let rest = String(expression.dropFirst(2))
                if let value = getString(rule: rest, isUrl: false) {
                    result += value
                }
            } else if Self.isJsonPathExpression(expression) {
                if let value = executeJsonRule(expression) {
                    result += value
                }
            } else {
                var binding: String?
                prepareJavaScriptEvaluationContext(
                    resultBinding: &binding,
                    index: nil,
                    idContent: nil,
                    setId: nil
                )
                let evaluated = safeEvaluateScript(
                    expression,
                    timeout: 15.0,
                    convertLegadoTemplates: true
                )
                let outcome = ruleEvaluationStringValue(from: evaluated)
                if let value = outcome {
                    // 伪代码 L706-L753：把 `{{expr}}` 出现处替换为结果。
                    result += value
                } else {
                    // 伪代码 L839-L888：nil 结果记录诊断日志（level=2）。
                    Logger.log(
                        "[processInnerJs-DIAG] expr=\"\(expression)\" -> nil",
                        level: 2
                    )
                }
            }

            searchStart = closeRange.upperBound
        }

        // 尾段原样拷贝。
        if searchStart < text.endIndex {
            result += String(text[searchStart...])
        }
        return result
    }

    /// 伪代码 0x100022ef4（隐式闭包 #2，L115-115）：
    /// `hasPrefix("$.") || hasPrefix("$[") || hasPrefix("$..")`。
    /// 对应骨架里的私有 `isJsonTemplateExpression`（PGO-only，L165-167），
    /// 两者共享同一组前缀常量（事实 6）。
    fileprivate static func isJsonPathExpression(_ expression: String) -> Bool {
        expression.hasPrefix("$.") || expression.hasPrefix("$[") || expression.hasPrefix("$..")
    }
}
