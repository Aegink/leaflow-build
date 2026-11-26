// 原路径: ReadMain/Core/SourceParser/AnalyzeRule/AnalyzeRule+Parsing.swift
// 证据:
//   - PGO: initialRuleEvaluationInput(LL) / finalizeStringResult(LL) / finalizeStringListResult
//     及闭包 #1 / executeStringSourceRules(LL) / executeStringListSourceRules(LL) /
//     getString(rule:isUrl:) / getStringList(rule:isUrl:)
//   - CovMap: initialRuleEvaluationInput L13-27 @0x100063758；finalizeStringResult L29-41
//     @0x1000639f0；finalizeStringListResult 闭包#1 L47-54 @0x100063ec8；
//     executeStringSourceRules L57-78 @0x1000640b8；executeStringListSourceRules L80-121
//     @0x1000642d4；getString L126-150 @0x100063158；getStringList L155-161 @0x1000645f4
//   - IDA: 上述地址的 Hex-Rays 伪代码
//   - 关键常量："\n"=10、"http://"=0x2F2F3A70747468、"https://"=0x2F2F3A7370747468、
//     "//"=12079、"nil"=7104878；调试锚点 131/137/146
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - getString/getStringList/executeString*Rules: high（回退链/逐段执行/收尾逐条对应）
//   - finalizeStringResult: high（isUrl 取首行 URL 链确证）
//   - initialRuleEvaluationInput: medium-high（回退链可见；ivar 精确归属见“仍不清楚”4）
// 依赖: splitRules（本文件族 T-201-03 RuleSplitter）、formatUrl（LegadoChain）。
// 还原: 2026-11-18

import Foundation

extension AnalyzeRule {

    /// 伪代码 0x100063758（L13-27）：求值初始输入回退链。
    /// 内容串 → 输入 Any（[Any]/[String] 数组亦可）→ 备选 Any → 内容串兜底。
    func initialRuleEvaluationInput() -> Any? {
        if !contentString.isEmpty {
            return contentString
        }
        if let pending = pendingEvaluationInput {
            return pending
        }
        if let alternate = alternateEvaluationInput {
            return alternate
        }
        return contentString
    }

    /// 伪代码 0x1000639f0（L29-41）：字符串结果收尾。
    /// nil 透传；非 isUrl 原样；isUrl 且含 "\n"：URL 前缀串抽 URL 子串，
    /// 否则拆行 trim 取首个非空行。
    func finalizeStringResult(_ result: String?, isUrl: Bool) -> String? {
        guard var text = result else { return nil }
        guard isUrl, text.contains("\n") else { return text }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://")
            || trimmed.hasPrefix("//") {
            // 伪代码：swift_once 缓存的 URL 正则 firstMatch 抽取。
            if let url = Self.firstUrlSubstring(in: trimmed) {
                return url
            }
        }
        for line in text.components(separatedBy: "\n") {
            let line = line.trimmingCharacters(in: .whitespaces)
            if !line.isEmpty {
                return line
            }
        }
        return text
    }

    /// finalizeStringListResult 闭包 #1（0x100063ec8）：列表收尾。
    /// isUrl → formatUrl + 去重 + 去空；否则原样。
    func finalizeStringListResult(_ list: [String], isUrl: Bool) -> [String] {
        guard isUrl else { return list }
        var seen = Set<String>()
        var result: [String] = []
        for item in list {
            let formatted = formatUrl(item)
            if formatted.isEmpty { continue }
            if seen.insert(formatted).inserted {
                result.append(formatted)
            }
        }
        return result
    }

    /// 伪代码 0x1000640b8（L57-78）：逐段字符串规则执行。
    /// 段空 → 返回当前累积；isUrl 仅最后一段；首段 previousResultIsCurrentContent。
    func executeStringSourceRules(
        _ rules: [LegadoSourceRule],
        initialResult: Any?,
        isUrl: Bool
    ) -> String? {
        var accumulated: Any? = initialResult
        for (offset, rule) in rules.enumerated() {
            if rule.rule.isEmpty {
                return accumulated as? String
            }
            let isLast = offset == rules.count - 1
            let result = executeRule(
                rule,
                isUrl: isUrl && isLast,
                previousResult: accumulated,
                previousResultIsCurrentContent: offset == 0
            )
            // 0x1000640b8：本段失败即清空累积，不得把输入HTML当作成功正文。
            guard let result else { return nil }
            accumulated = result
        }
        return accumulated as? String
    }

    /// 伪代码 0x1000642d4（L80-121）：逐段列表规则执行。
    /// 先试 executeRuleForList，命中即锁定列表；否则单值累积；
    /// 收尾：列表直接 finalize，字符串按 "\n" 拆分后 finalize。
    func executeStringListSourceRules(
        _ rules: [LegadoSourceRule],
        initialResult: Any?,
        isUrl: Bool
    ) -> [String] {
        var accumulated: Any? = initialResult
        var listResult: [String]?
        var stringResult: String?

        for (offset, rule) in rules.enumerated() {
            if listResult != nil {
                break
            }
            let isFirst = offset == 0
            if let list = executeRuleForList(
                rule,
                previousResult: accumulated,
                previousResultIsCurrentContent: isFirst
            ) {
                listResult = list
                accumulated = list
                continue
            }
            let single = executeRule(
                rule,
                isUrl: false,
                previousResult: accumulated,
                previousResultIsCurrentContent: isFirst
            )
            if let single {
                stringResult = single
                accumulated = single
            } else {
                stringResult = nil
                accumulated = nil
            }
        }

        if let listResult {
            return finalizeStringListResult(listResult, isUrl: isUrl)
        }
        if let stringResult {
            let lines = stringResult.components(separatedBy: "\n")
            return finalizeStringListResult(lines, isUrl: isUrl)
        }
        return []
    }

    /// 伪代码 0x100063158（L126-150）：字符串规则主入口。
    /// 规则空 → nil；splitRules → 初始输入 → 逐段执行 → finalize；debugMode 三处日志。
    func getString(rule: String?, isUrl: Bool) -> String? {
        guard let rule, !rule.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        if Self.debugMode {
            Logger.log(
                "[getString] rule=\"\(rule)\" isUrl=\(isUrl)",
                level: Self.executeRuleLogLevel
            )
        }
        let rules = splitRules(rule, allInOne: true)
        if Self.debugMode {
            Logger.log(
                "[getString] count=\(rules.count) rules=\(rules.map { "mode=\($0.mode) rule=\($0.rule)" })",
                level: Self.executeRuleLogLevel
            )
        }
        let input = initialRuleEvaluationInput()
        let executed = executeStringSourceRules(rules, initialResult: input, isUrl: isUrl)
        let finalized = finalizeStringResult(executed, isUrl: isUrl)
        if Self.debugMode {
            Logger.log(
                "[getString] -> \(finalized ?? "nil")",
                level: Self.executeRuleLogLevel
            )
        }
        return finalized
    }

    /// 伪代码 0x1000645f4（L155-161）：列表规则主入口。
    func getStringList(rule: String?, isUrl: Bool) -> [String] {
        guard let rule, !rule.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        let rules = splitRules(rule, allInOne: true)
        let input = initialRuleEvaluationInput()
        return executeStringListSourceRules(rules, initialResult: input, isUrl: isUrl)
    }

    /// finalizeStringResult 的 URL 子串抽取（swift_once 缓存的正则）。
    private static func firstUrlSubstring(in text: String) -> String? {
        // 伪代码常量：http:// 或 https:// 或 // 起始的连续 URL 段。
        let pattern = "(https?://|//)[^\\s\"'<>]+"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              let urlRange = Range(match.range, in: text) else {
            return nil
        }
        return String(text[urlRange])
    }
}
