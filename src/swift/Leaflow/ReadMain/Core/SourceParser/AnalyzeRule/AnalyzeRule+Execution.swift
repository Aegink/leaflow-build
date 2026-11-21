// 原路径: ReadMain/Core/SourceParser/AnalyzeRule/AnalyzeRule+Execution.swift
// 证据:
//   - PGO: makeUpRuleInput(LL) / shouldExecuteAgainstPreviousResult(LL) / executeRule /
//     executeRuleForList / stringFromRuleResult / stringListFromJsRuleResult /
//     executeJsRuleForListWithPreviousResult / regexGroupValue 及两个闭包
//   - CovMap: makeUpRuleInput L8-19 @0x10001ea14；shouldExecuteAgainstPreviousResult L21-29
//     @0x10001eb88；executeRule L81-230 @0x10001f07c；closure#2 L165-199 @0x10002006c；
//     stringFromRuleResult L232-244 @0x1000204dc；stringListFromJsRuleResult L246-267
//     @0x100020ec4；executeJsRuleForListWithPreviousResult L276-287 @0x100020b6c；
//     regexGroupValue L289-294 @0x100020950；executeRuleForList L304-380 @0x10002130c；
//     closure#1 L318-372 @0x1000215a0
//   - IDA: 上述地址的 Hex-Rays 伪代码
//   - 关键常量（低字节在前）："{{"=31611、"}}"=32125、"{$."=3023995、"$"=36、
//     "//"=12079、"<js>"=1047751228、"@js:"=980642368、"@get:{"=0x7B3A74656740、
//     "true"=1702195828、"false"=0x65736C6166、"&&"=9766、"||"=31868、"%%"=9509
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - makeUpRuleInput / shouldExecuteAgainstPreviousResult / regexGroupValue: high
//     （回退链与分支逐条对应）
//   - stringFromRuleResult / stringListFromJsRuleResult: high（cast 链与 JSON 兜底可见）
//   - executeRule / executeRuleForList: medium-high（模板短路/模式分发/计时确证；
//     细粒度门控见读后记“仍不清楚”；LRUCache.put 命中仅打日志为推断）
//   - executeRule 闭包 #2 / executeRuleForList 闭包 #1: medium-high（分发序完整可见）
// 依赖: LegadoSourceRule/RuleMode（RuleModels 骨架）、AnalyzeRule 主类成员
//       （T-201 后续分册）、ParseDiagnostic（T-201 后续）、Logger（T-101）。
// 还原: 2026-11-18

import Foundation

extension AnalyzeRule {

    // MARK: - 执行前输入与门控

    /// 伪代码 0x10001ea14（L8-19）：makeUp 阶段使用的输入回退链：
    /// previousResult → self.currentContent(+72) → self 内容串(+56/64) → self.idContent(+24)。
    func makeUpRuleInput(previousResult: Any?) -> Any? {
        if let previousResult {
            return previousResult
        }
        if let content = currentContent {
            return content
        }
        if !contentString.isEmpty {
            return contentString
        }
        return idContent
    }

    /// 伪代码 0x10001eb88（L21-29）：
    /// previousResult 为 nil → false；mode ∈ {3, 6} → false；其余 → true。
    /// 即：无上游结果时不执行；JS（3）与模式 6 的规则不基于 previousResult 复跑。
    func shouldExecuteAgainstPreviousResult(
        _ mode: RuleMode,
        previousResult: Any?
    ) -> Bool {
        guard previousResult != nil else { return false }
        if mode == .js || mode == .mode6 {
            return false
        }
        return true
    }

    // MARK: - 单值执行

    /// 伪代码 0x10001f07c（L81-230）：
    /// 1. `makeUpRuleInput(previousResult:)` → `LegadoSourceRule.makeUpRule` 得到生效规则串；
    /// 2. 规则级 LRU（LRUCache.put）命中时打调试日志
    ///    "[executeRule] mode=... rule=... result=... isUrl=..."（推断 6：命中只打日志）；
    /// 3. 完整 `{{...}}` 模板 → `processInnerJs`；`{$.` 前缀（mode != 2）→
    ///    `processInnerRule(rule, "{$.", "}")`；模板结果呈 JS/XPath 形态
    ///    （lowercased 后 `<js>` / `@js:` / `//` 前缀）时短路返回；
    /// 4. makeUp 改写且含 `@get:{` → 模板变量替换短路；
    /// 5. 常规：`shouldExecuteAgainstPreviousResult` 门 → 计时执行闭包 #2 →
    ///    ParseDiagnostic（模式 3/4 → 标志 2，否则 1）→ `applyPostProcessing`。
    func executeRule(
        _ rule: LegadoSourceRule,
        isUrl: Bool,
        previousResult: Any?,
        previousResultIsCurrentContent: Bool
    ) -> String? {
        // 事实 13：makeUp 链。
        // makeUpRule 返回生效规则结构体——取规则串域（wave-16）。
        let input = makeUpRuleInput(previousResult: previousResult)
        let effectiveRule = rule.makeUpRule(result: input, context: self).rule

        // 推断 6：LRU 命中只打调试日志，不改变控制流。
        if Self.ruleCache.contains(ruleKey(effectiveRule, isUrl: isUrl)) {
            let mode = isJsonContent() ? "json" : "text"
            Logger.log(
                "[executeRule] mode=\(mode) rule=\(effectiveRule) "
                    + "result=true isUrl=\(isUrl)",
                level: Self.executeRuleLogLevel
            )
        }
        Self.ruleCache.insert(ruleKey(effectiveRule, isUrl: isUrl))

        // 事实 14：完整模板 → processInnerJs。
        if effectiveRule.hasPrefix("{{"), effectiveRule.hasSuffix("}}") {
            let templated = processInnerJs(effectiveRule)
            let lowered = templated.lowercased()
            // 伪代码 L624-L640：结果呈 JS/XPath 形态时短路；否则以模板结果继续后续检查。
            if lowered.hasPrefix("<js>") || lowered.hasPrefix("@js:") || lowered.hasPrefix("//") {
                return applyPostProcessing(rule: rule, result: templated, isUrl: isUrl)
            }
            return applyPostProcessing(rule: rule, result: templated, isUrl: isUrl)
        }

        // 事实 14：{$. → processInnerRule(rule, "{$.", "}")（mode 2 除外）。
        if effectiveRule.hasPrefix("{$."), rule.mode != .json {
            let inner = processInnerRule(effectiveRule, startMark: "{$.", endMark: "}")
            let lowered = inner.lowercased()
            if lowered.hasPrefix("<js>") || lowered.hasPrefix("@js:") || lowered.hasPrefix("//") {
                return applyPostProcessing(rule: rule, result: inner, isUrl: isUrl)
            }
            return applyPostProcessing(rule: rule, result: inner, isUrl: isUrl)
        }

        // 事实 15：makeUp 改写 + @get:{ → 模板变量替换短路。
        if effectiveRule != rule.rule,
           !effectiveRule.hasPrefix("{{"),
           effectiveRule.range(
               of: "@get:{",
               options: .caseInsensitive,
               locale: nil
           ) != nil {
            let replaced = replaceTemplateVariables(effectiveRule)
            return applyPostProcessing(rule: rule, result: replaced, isUrl: isUrl)
        }

        // 事实 16：常规执行（计时 + shouldExecute 门 + ParseDiagnostic）。
        let start = CFAbsoluteTimeGetCurrent()
        var result: String?
        if shouldExecuteAgainstPreviousResult(rule.mode, previousResult) {
            result = executeRuleBody(
                effectiveRule,
                rule,
                previousResult: previousResult,
                previousResultIsCurrentContent: previousResultIsCurrentContent
            )
        }
        let elapsed = CFAbsoluteTimeGetCurrent() - start

        // 伪代码 L917-L924：模式 3/4 → 诊断标志 2，否则 1。
        let diagnosticKind = (rule.mode == .js || rule.mode == .mode4) ? 2 : 1
        if Self.debugMode {
            let rendered = result ?? "nil"
            Logger.log(
                "[getElements] pipelineRules=\(rule.rule) -> \(rendered) "
                    + String(format: "(%.3fs, diag=%d)", elapsed, diagnosticKind),
                level: Self.executeRuleLogLevel
            )
        }
        return applyPostProcessing(rule: rule, result: result, isUrl: isUrl)
    }

    /// 伪代码 0x10002006c（闭包 #2，L165-199）：
    /// trim 后空串 → previousResult 派生值；`$N` 组引用 → 直接返回；
    /// 按模式分发：3=JS、7=CSS、其余经规则类型元数据 witness。
    private func executeRuleBody(
        _ ruleText: String,
        _ rule: LegadoSourceRule,
        previousResult: Any?,
        previousResultIsCurrentContent: Bool
    ) -> String? {
        let trimmed = ruleText.trimmingCharacters(in: .whitespacesAndNewlines)

        // 事实 17：空串 → previousResult 派生值。
        if trimmed.isEmpty {
            if let string = previousResult as? String {
                return string
            }
            if let previous = previousResult {
                return Self.stringFromRuleResult(previous)
            }
            return nil
        }

        // 事实 17：$N 组引用优先。
        if let group = Self.regexGroupValue(for: trimmed) {
            return group
        }

        switch rule.mode {
        case .js:
            // 事实 17/推断 8：mode 3 —— 单值 JS 或列表 JS 取 indexExtract。
            if rule.prefersSingleValue {
                return executeJsRule(trimmed, input: previousResult)
            }
            let list = executeJsRuleForListWithPreviousResult(trimmed, previousResult: previousResult)
            return Self.extractByIndex(list, index: rule.indexExtract)
        case .css:
            // 事实 17：mode 7 —— 单值 CSS 或列表 CSS 取 indexExtract。
            if rule.prefersSingleValue {
                return executeCssRule(trimmed)
            }
            let list = executeCssRuleForList(trimmed)
            return Self.extractByIndex(list, index: rule.indexExtract)
        default:
            // 事实 17：其余模式经类型元数据 witness 执行；取不到 → nil。
            guard let executor = Self.pipelineExecutor(for: rule.mode) else {
                return nil
            }
            let result = executor(trimmed, previousResult, previousResultIsCurrentContent)
            if let string = result as? String {
                return string
            }
            return Self.extractByIndex(result as? [String], index: rule.indexExtract)
        }
    }

    // MARK: - 列表执行

    /// 伪代码 0x10002130c（L304-380）：
    /// `{{...}}` 或 `{$.` 前缀 → 走 `executeRule` 单值路径，结果装箱为单元素数组；
    /// 否则 `shouldExecuteAgainstPreviousResult` 门 + 闭包 #1。
    func executeRuleForList(
        _ rule: LegadoSourceRule,
        previousResult: Any?,
        previousResultIsCurrentContent: Bool
    ) -> [String]? {
        let input = makeUpRuleInput(previousResult: previousResult)
        _ = rule.makeUpRule(result: input, context: self)

        // 事实 21：模板前缀 → 单值路径装箱。
        if rule.rule.hasPrefix("{{") || rule.rule.hasPrefix("{$.") {
            guard let single = executeRule(
                rule,
                isUrl: false,
                previousResult: previousResult,
                previousResultIsCurrentContent: previousResultIsCurrentContent
            ) else {
                return nil
            }
            return [single]
        }

        guard shouldExecuteAgainstPreviousResult(rule.mode, previousResult) else {
            return nil
        }
        return executeRuleForListBody(
            rule,
            previousResult: previousResult,
            previousResultIsCurrentContent: previousResultIsCurrentContent
        )
    }

    /// 伪代码 0x1000215a0（闭包 #1，L318-372）：列表执行体。
    private func executeRuleForListBody(
        _ rule: LegadoSourceRule,
        previousResult: Any?,
        previousResultIsCurrentContent: Bool
    ) -> [String]? {
        switch rule.mode {
        case .js:
            // 事实 21：mode 3 → executeJsRuleForListWithPreviousResult。
            let list = executeJsRuleForListWithPreviousResult(
                rule.rule,
                previousResult: previousResult
            )
            return postProcessList(rule, list)
        case .css:
            // 事实 21：mode 7 → CSS 列表；nil 回退单值执行再装箱。
            if let list = executeCssRuleForList(rule.rule) {
                return postProcessList(rule, list)
            }
            guard let single = executeRule(
                rule,
                isUrl: false,
                previousResult: previousResult,
                previousResultIsCurrentContent: previousResultIsCurrentContent
            ) else {
                return nil
            }
            return [single]
        default:
            // 事实 21：其余模式 witness 执行；nil 回退单值执行再装箱。
            guard let executor = Self.pipelineListExecutor(for: rule.mode) else {
                return nil
            }
            if let list = executor(rule.rule, previousResult, previousResultIsCurrentContent) {
                return postProcessList(rule, list)
            }
            guard let single = executeRule(
                rule,
                isUrl: false,
                previousResult: previousResult,
                previousResultIsCurrentContent: previousResultIsCurrentContent
            ) else {
                return nil
            }
            return [single]
        }
    }

    /// 事实 21：列表后处理 —— replaceRegex/putMap 存在时逐元素
    /// applyPostProcessing(rule, element, isUrl: false)，全 nil → nil。
    private func postProcessList(_ rule: LegadoSourceRule, _ list: [String]?) -> [String]? {
        guard var list else { return nil }
        if rule.replaceRegex != nil || rule.putMap != nil {
            let processed = list.compactMap { element -> String? in
                applyPostProcessing(rule: rule, result: element, isUrl: false)
            }
            list = processed
        }
        return list.isEmpty ? nil : list
    }

    // MARK: - 结果归一

    /// 伪代码 0x1000204dc（L232-244）：
    /// String → 原样；数组 → 过滤 nil 元素后 `joined(separator: "\n")`；
    /// JSON 对象 → `JSONSerialization` 字符串化；兜底 `String(describing:)`。
    static func stringFromRuleResult(_ value: Any) -> String {
        if let string = value as? String {
            return string
        }
        if let optionalList = value as? [String?] {
            return optionalList.compactMap { $0 }.joined(separator: "\n")
        }
        if let list = value as? [String] {
            return list.joined(separator: "\n")
        }
        if JSONSerialization.isValidJSONObject(value) {
            if let data = try? JSONSerialization.data(withJSONObject: value, options: []),
               let string = String(data: data, encoding: .utf8) {
                return string
            }
        }
        return String(describing: value)
    }

    /// 伪代码 0x100020ec4（L246-267）：
    /// String → 单元素数组；[Any] → 逐元素归一（String / JSON 字符串化 /
    /// LegadoJsonPathBridge.legadoString 兜底），其余跳过；非数组 → nil。
    static func stringListFromJsRuleResult(_ value: Any) -> [String]? {
        if let string = value as? String {
            return [string]
        }
        guard let items = value as? [Any] else {
            return nil
        }
        var result: [String] = []
        for item in items {
            if let string = item as? String {
                result.append(string)
                continue
            }
            if JSONSerialization.isValidJSONObject(item) {
                if let data = try? JSONSerialization.data(withJSONObject: item, options: []),
                   let string = String(data: data, encoding: .utf8) {
                    result.append(string)
                    continue
                }
            }
            if let string = LegadoJsonPathBridge.legadoString(item) {
                result.append(string)
            }
        }
        return result
    }

    /// 伪代码 0x100020b6c（L276-287）：按 previousResult 有无两条路径执行 JS
    /// （sub_10004DAEC），结果统一 stringListFromJsRuleResult。
    func executeJsRuleForListWithPreviousResult(
        _ rule: String,
        previousResult: Any?
    ) -> [String]? {
        guard let value = executeJsRule(rule, input: previousResult) else {
            return nil
        }
        return Self.stringListFromJsRuleResult(value)
    }

    /// 伪代码 0x100020950（L289-294）：
    /// trim；非 `$` 前缀 → nil；`dropFirst(1)` 转 Int 失败 → nil；
    /// 索引越界（`*(self+184)` 正则捕获组缓存）→ nil；否则取第 N 组。
    static func regexGroupValue(for rule: String) -> String? {
        let trimmed = rule.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("$") else { return nil }
        let body = trimmed.dropFirst()
        guard let index = Int(body), index >= 0, index < regexGroupStorage.count else {
            return nil
        }
        return regexGroupStorage[index]
    }

    // MARK: - 内部支撑

    /// 事实 15 的模板变量替换（@get:{name} → getVariable）。
    private func replaceTemplateVariables(_ rule: String) -> String {
        var result = rule
        while let open = result.range(of: "@get:{") {
            guard let close = result.range(
                of: "}",
                range: open.upperBound..<result.endIndex
            ) else {
                break
            }
            let name = String(result[open.upperBound..<close.lowerBound])
            let value = getVariable(name) ?? ""
            result.replaceSubrange(open.lowerBound..<close.upperBound, with: value)
        }
        return result
    }

    private func ruleKey(_ rule: String, isUrl: Bool) -> String {
        "\(isUrl ? 1 : 0)|\(rule)"
    }
}

// MARK: - 静态存储（对应伪代码的全局/静态缓存）

extension AnalyzeRule {

    /// 推断 6 的载体：规则级去重缓存（原实现为 LRUCache.put）。
    static var ruleCache: Set<String> = []

    /// 事实 18 的载体：正则捕获组缓存（原实现挂在 `*(self+184)` 数组 ivar）。
    static var regexGroupStorage: [String] = []
}
