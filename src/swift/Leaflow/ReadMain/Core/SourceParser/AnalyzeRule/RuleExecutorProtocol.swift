// 原路径: ReadMain/Core/SourceParser/AnalyzeRule/RuleExecutorProtocol.swift
// 证据:
//   - PGO: RuleExecutor.executeForList(扩展默认) / CssRuleExecutor / XPathRuleExecutor /
//     JsonRuleExecutor / JsRuleExecutor / WebJsRuleExecutor / RegexRuleExecutor
//   - CovMap: 扩展默认 L20 @0x10007b8b0；Css.execute L43-45 @0x10007b8e4 / ForList L46-48
//     @0x10007b910；XPath.execute L52-54 @0x10007b944 / ForList L55-57 @0x10007b970；
//     Json.execute L61-63 @0x10007b9a4；Js.executeForList L74-100 @0x10007ba30；
//     WebJs.execute L104-106 @0x10007bee4；Regex.execute L110-112 @0x10007bf18
//   - IDA: 上述地址的 Hex-Rays 伪代码
//   - 归属错位（读后记事实 11）：witness 调用与类型名 off-by-one 错位
//     （labeled-Css→executeXPathRule、labeled-XPath→executeJsonRule、labeled-Json→executeJsRule、
//     labeled-WebJs→executeRegexRuleForList、labeled-Regex→executeVariableRule），
//     本还原按 detectMode/executeRule 闭包 #2 的自洽分发写入语义，
//     原始调用关系保留在下方注释，供 witness 表反查后复核。
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: medium-high（分发语义自洽；错位机制见读后记“仍不清楚”1）
// 还原: 2026-11-19

import Foundation

/// 规则执行器协议：按模式分派的执行通道。
protocol RuleExecutor {
    func execute(rule: String, context: AnalyzeRule) -> String?
    func executeForList(rule: String, context: AnalyzeRule) -> [String]?
}

extension RuleExecutor {
    /// 伪代码 0x10007b8b0（L20）：默认列表执行 → executeCssRuleForList（sub_1000173D0）。
    /// 归属错位说明：该默认实现补上 Css 位，与 witness 错位模式一致。
    func executeForList(rule: String, context: AnalyzeRule) -> [String]? {
        context.executeCssRuleForList(rule)
    }
}

/// 原始 witness 调用（供复核，读后记事实 10）：
///   0x10007b8e4 labeled-Css.execute      → AnalyzeRule.executeXPathRule
///   0x10007b910 labeled-Css.executeForList → AnalyzeRule.executeXPathRuleForList
///   0x10007b944 labeled-XPath.execute    → AnalyzeRule.executeJsonRule
///   0x10007b970 labeled-XPath.executeForList → AnalyzeRule.executeJsonRuleForList
///   0x10007b9a4 labeled-Json.execute     → AnalyzeRule.executeJsRule(_:input:resultBinding:)
///   0x10007ba30 labeled-Js.executeForList → sub_10004DAEC（JS 列表求值）逐元素归一
///   0x10007bee4 labeled-WebJs.execute    → AnalyzeRule.executeRegexRuleForList
///   0x10007bf18 labeled-Regex.execute    → AnalyzeRule.executeVariableRule

/// CSS 执行器（mode 7）：语义映射按 executeRule 闭包 #2（mode 7 → executeCssRule）。
struct CssRuleExecutor: RuleExecutor {
    func execute(rule: String, context: AnalyzeRule) -> String? {
        context.executeCssRule(rule)
    }

    func executeForList(rule: String, context: AnalyzeRule) -> [String]? {
        context.executeCssRuleForList(rule)
    }
}

/// XPath 执行器（mode 1）。
struct XPathRuleExecutor: RuleExecutor {
    func execute(rule: String, context: AnalyzeRule) -> String? {
        context.executeXPathRule(rule)
    }

    func executeForList(rule: String, context: AnalyzeRule) -> [String]? {
        context.executeXPathRuleForList(rule)
    }
}

/// JSONPath 执行器（mode 2）。
struct JsonRuleExecutor: RuleExecutor {
    func execute(rule: String, context: AnalyzeRule) -> String? {
        context.executeJsonRule(rule)
    }

    func executeForList(rule: String, context: AnalyzeRule) -> [String]? {
        context.executeJsonRuleForList(rule)
    }
}

/// JS 执行器（mode 3）：单值走 executeJsRule；列表走 JS 列表求值后逐元素归一。
struct JsRuleExecutor: RuleExecutor {
    func execute(rule: String, context: AnalyzeRule) -> String? {
        context.executeJsRule(rule, input: context.contentString)
    }

    /// 伪代码 0x10007ba30（L74-100）：String → 单元素数组；
    /// 数组 → 逐元素 String cast / JSON 字符串化 / legadoString 过滤空。
    /// T-1601-B2：结构化求值保留数组形态。
    func executeForList(rule: String, context: AnalyzeRule) -> [String]? {
        guard let evaluated = context.executeJsRuleStructured(
            rule, input: context.contentString
        ) else {
            return nil
        }
        return AnalyzeRule.stringListFromJsRuleResult(evaluated)
    }
}

/// 网页 JS 执行器（mode 4，推断 2）。
struct WebJsRuleExecutor: RuleExecutor {
    func execute(rule: String, context: AnalyzeRule) -> String? {
        context.executeJsRule(rule, input: context.contentString)
    }

    func executeForList(rule: String, context: AnalyzeRule) -> [String]? {
        guard let evaluated = context.executeJsRule(rule, input: context.contentString) else {
            return nil
        }
        return AnalyzeRule.stringListFromJsRuleResult(evaluated)
    }
}

/// 正则执行器（mode 5）：列表走 executeRegexRuleForList。
struct RegexRuleExecutor: RuleExecutor {
    func execute(rule: String, context: AnalyzeRule) -> String? {
        context.splitRegexChain(rule).first
    }

    func executeForList(rule: String, context: AnalyzeRule) -> [String]? {
        context.executeRegexRuleForList(rule)
    }
}

/// 变量执行器（mode 6）。
struct VariableRuleExecutor: RuleExecutor {
    func execute(rule: String, context: AnalyzeRule) -> String? {
        context.executeVariableRule(rule)
    }

    func executeForList(rule: String, context: AnalyzeRule) -> [String]? {
        guard let value = context.executeVariableRule(rule) else { return nil }
        return [value]
    }
}

/// 管道 JSON 归一执行器（mode 8）：按 `referenceJSONPipelineValues`
/// 把值归一为 `[String]`（AnalyzeRule+ElementExtraction L299-306 域）。
struct Mode8RuleExecutor: RuleExecutor {
    func execute(rule: String, context: AnalyzeRule) -> String? {
        executeForList(rule: rule, context: context)?.first
    }

    func executeForList(rule: String, context: AnalyzeRule) -> [String]? {
        AnalyzeRule.executeElementPipelineJson(
            rule,
            currentResult: context.contentString,
            nextMode: .mode8,
            maxResults: nil
        ) as? [String]
    }
}

/// 模式 → 执行器分派（pipelineExecutor 家族的协议化承载）。
enum RuleExecutorRegistry {
    static func executor(for mode: RuleMode) -> RuleExecutor? {
        switch mode {
        case .css, .default_:
            return CssRuleExecutor()
        case .xpath:
            return XPathRuleExecutor()
        case .json:
            return JsonRuleExecutor()
        case .js:
            return JsRuleExecutor()
        case .mode4:
            return WebJsRuleExecutor()
        case .regex:
            return RegexRuleExecutor()
        case .mode6:
            return VariableRuleExecutor()
        case .mode8:
            return Mode8RuleExecutor()
        }
    }
}
