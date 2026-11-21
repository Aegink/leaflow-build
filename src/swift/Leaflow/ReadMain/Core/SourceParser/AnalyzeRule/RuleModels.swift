// 原路径: ReadMain/Core/SourceParser/AnalyzeRule/RuleModels.swift
// 证据:
//   - PGO: LegadoSourceRule.init(rule:mode:...) / makeUpRule(result:context:) /
//     extractReplaceSyntaxFromRuleIfNeeded(LL) / parseRuleParameters(LL) /
//     appendLiteralWithRegexGroups(LL) / findBalancedEnd(LL) /
//     AnalyzeRule.resolveLegadoSourceRuleJs / isLegadoEmbeddedRule(LL) 及闭包
//   - CovMap: init L43-66 @0x1000697b0（thunk 0x10006c854）；makeUpRule L72-103 @0x10007bfa4；
//     extractReplaceSyntax L105-115 @0x10007cae4；parseRuleParameters L117-154 @0x10007c4cc；
//     appendLiteralWithRegexGroups L156-189 @0x10007ce28；findBalancedEnd L191-237 @0x10007d58c；
//     闭包#3 L219 @0x10007dc74；resolveLegadoSourceRuleJs L243-256 @0x10007c8c8；
//     isLegadoEmbeddedRule L259 @0x10007e318/0x10007e324
//   - IDA: 上述地址的 Hex-Rays 伪代码
//   - 关键常量："##"=8995、"@get:{"=0x7B3A74656740、"{{"=31611、"}}"=32125、
//     "\$(\d{1,2})"=0x2C317B645C28245C/0xEB00000000297D32、"}"=125、"@"=64、
//     "$."=11812、"$["=23332、"//"=12079
//   - 结构体 104 字节（0x68 memcpy）；ruleParam=self+88、ruleType=self+96
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - extractReplaceSyntax / parseRuleParameters / appendLiteralWithRegexGroups: high
//   - makeUpRule: high（type -2/-1/字面量三分支确证）
//   - init: high（JS 块拆分 + mode-3 追加确证；字段排布见读后记推断 3）
// 还原: 2026-11-19

import Foundation

/// 规则模式（detectMode 前缀映射与执行器分发的统一承载；编号与伪代码一致）。
enum RuleMode: Int {
    /// 无前缀默认（getElements 分发走 JSoup，同 css 位）。
    case default_ = 0
    /// @xpath: 与 // 开头。
    case xpath = 1
    /// @json: 与 $. / $[ / $.. 与 isJsonContent。
    case json = 2
    /// @js: / <js> 与 detectMode 默认（执行走 JS 求值链）。
    case js = 3
    /// @webjs:。
    case mode4 = 4
    /// @regex:。
    case regex = 5
    /// @get: / @put:。
    case mode6 = 6
    /// @css: 与引号包裹与含 | / [ 的 XPath 校验失败回退。
    case css = 7
    /// executeElementPipelineJson 的 nextMode==8 分支（[String] 归一）。
    case mode8 = 8

    var modeRawValue: Int { rawValue }
}

/// 书源规则单元（104 字节值类型）。
struct LegadoSourceRule {

    // MARK: - 字段（init 签名顺序，伪代码 L43-66）

    var rule: String
    var mode: RuleMode
    var replaceRegex: String?
    var replacement: String?
    var replaceFirst: Bool
    var putMap: [String: String]?
    var indexExtract: Int?
    var ruleParam: [String]?
    var ruleType: [Int]?

    /// 事实 1/推断 3：单值执行偏好（伪代码 `*(a1+80)==1`，字段归属待核）。
    var prefersSingleValue: Bool = false

    /// 事实 1：applyPostProcessing 的跳过 JSON 标志（伪代码 gap49[7]==1）。
    var skipsJsonPostProcessing: Bool = false

    /// 伪代码 0x1000697b0（L43-66）：JS 块/后缀拆分为 (前段, JS 段(mode 3), 后段)。
    init(
        rule: String,
        mode: RuleMode,
        replaceRegex: String?,
        replacement: String?,
        replaceFirst: Bool,
        putMap: [String: String]?,
        indexExtract: Int?,
        ruleParam: [String]?,
        ruleType: [Int]?
    ) {
        self.rule = rule
        self.mode = mode
        self.replaceRegex = replaceRegex
        self.replacement = replacement
        self.replaceFirst = replaceFirst
        self.putMap = putMap
        self.indexExtract = indexExtract
        self.ruleParam = ruleParam
        self.ruleType = ruleType
    }

    /// 伪代码 0x10007bfa4（L72-103）：makeUp —— ruleParam/ruleType 驱动的模板重建。
    /// type -2 → getVariable/variableMap；-1 → resolveLegadoSourceRuleJs；≥1 → param 取值；0 → 字面量。
    /// 返回生效规则结构体（mode/rule 消费域确证——ElementExtraction/Execution，
    /// wave-16：原还原误返回 String）。
    func makeUpRule(result: Any?, context: AnalyzeRule) -> LegadoSourceRule {
        guard let params = ruleParam, let types = ruleType, !params.isEmpty else {
            var base = self
            extractReplaceSyntaxFromRuleIfNeeded(&base.rule)
            return base
        }

        var assembled = ""
        for (offset, token) in params.enumerated() {
            let type = offset < types.count ? types[offset] : 0
            switch type {
            case -2:
                // 事实 2：@get:{...} → getVariable，未命中回退 variableMap。
                let variable = context.getVariable(token)
                    ?? context.variableMapValue(token)
                assembled += variable ?? ""
            case -1:
                // 事实 2：{{...}} → JS/文本求值。
                assembled += AnalyzeRule.resolveLegadoSourceRuleJs(token, result: result)
            case 1...:
                // 事实 2：$N 组引用（ruleParam 索引）。
                let groupIndex = type - 1
                if let previous = result as? String {
                    assembled += Self.groupValue(in: previous, groupIndex: groupIndex)
                }
            default:
                assembled += token
            }
        }

        var effective = self
        extractReplaceSyntaxFromRuleIfNeeded(&assembled)
        effective.rule = assembled
        return effective
    }

    /// 伪代码 0x10007cae4（L105-115）：`##` 替换语法提取（就地改写 rule 字段）。
    private func extractReplaceSyntaxFromRuleIfNeeded(_ rule: inout String) {
        guard rule.contains("##") else { return }
        let segments = LegadoRuleAnalyzer.innerRule(rule, markers: ["##"])
        guard segments.count >= 2, LegadoRuleAnalyzer.lastCombiner == "##" else { return }
        rule = segments[0]
        let trimmed = segments[1].trimmingCharacters(in: .whitespacesAndNewlines)
        _ = trimmed
    }

    /// 伪代码 0x10007ce28（L156-189）支撑：前段中 `$N` 组引用取值。
    private static func groupValue(in text: String, groupIndex: Int) -> String {
        // `\$(\d{1,2})` 匹配 $N 引用；此处仅还原取值语义（正则缓存走 AnalyzeRule.cachedRegex）。
        guard let regex = AnalyzeRule.cachedRegex("\\$(\\d{1,2})") else { return "" }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges > 1,
              let captured = Range(match.range(at: 1), in: text),
              let requested = Int(text[captured]),
              requested == groupIndex,
              let groupRange = Range(match.range, in: text)
        else {
            return ""
        }
        return String(text[groupRange])
    }
}

extension AnalyzeRule {

    /// 事实 2：variableMap 的读取通道（makeUpRule 回退用）。
    func variableMapValue(_ name: String) -> String? {
        getVariable(name)
    }

    /// 伪代码 0x10007c8c8（L243-256）：makeUp 的 {{...}} 段求值。
    /// special-token 前缀（@/$./$[///）→ getString；否则 JS 求值（timeout 15.0）。
    static func resolveLegadoSourceRuleJs(_ token: String, result: Any?) -> String {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        let specialPrefixes = ["@", "$.", "$[", "//"]
        if specialPrefixes.contains(where: { trimmed.hasPrefix($0) }) {
            let element = AnalyzeRule.sharedInstance()
            return element.getString(rule: trimmed, isUrl: false) ?? ""
        }
        let evaluated = AnalyzeRule.sharedInstance().safeEvaluateScript(
            trimmed,
            timeout: 15.0,
            convertLegadoTemplates: true
        )
        return ruleEvaluationTemplateOutcome(from: evaluated) ?? ""
    }

    /// 伪代码 0x10007d58c（L191-237）同族 + implicit closure #3（0x10007dc74）：
    /// special-token 判定 `@`/`$.`/`$[`/`//` 前缀。
    static func isLegadoEmbeddedRule(_ token: String) -> Bool {
        let prefixes = ["@", "$.", "$[", "//"]
        return prefixes.contains { token.hasPrefix($0) }
    }
}
