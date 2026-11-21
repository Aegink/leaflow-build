// 原路径: ReadMain/Core/SourceParser/AnalyzeRule/AnalyzeRule+ElementExtraction.swift
// 证据:
//   - PGO: getElements/getElement/getElementsSingle/executeElementPipeline*/limitedElementPipelineValue/
//     referenceJSONPipeline*/stringForElementPipeline/analyzersForElementPipeline/
//     executeElementPipelineXPath|Css/analyzerForElementPipeline/wrapElementPipelineResult/
//     wrapNodesAsChildRules/wrapSoupNodesAsChildRules/wrapJsonItemsAsChildRules/
//     wrapRegexGroupListsAsChildRules/isKannaElementNode/jsonObjectForElementPipeline/
//     extractExcludeInfo/remainingCapacity 及全部 inline closure
//   - CovMap: getElements L12-189 @0x1000177f4；appendCapped L31-44 @0x10001959c；
//     executeElementPipelineRules L191-212 @0x100019740；executeElementPipelineStep L219-239
//     @0x10001b044；executeElementPipelineJson L246-283 @0x10001b6fc；
//     limitedElementPipelineValue L285-297 @0x10001b224；referenceJSONPipelineValues L299-306
//     @0x10001ca18；referenceJSONPipelineString L308-319 @0x10001cbf8；
//     stringForElementPipeline L337-358 @0x10001c110；analyzersForElementPipeline L368-372
//     @0x10001c8c8；XPath 闭包#1 L381-383 @0x10001c774；wrapElementPipelineResult L386-392
//     @0x10001b474；getElement L394-429 @0x10001d060；getElementsSingle L433-498 @0x100019b50；
//     closure#3 L484-484 @0x10001bfe8；wrapNodesAsChildRules L503-535 @0x10001ac98；
//     Kanna 闭包#1 L504-534 @0x10001d66c；闭包#3 L525-525 @0x10001e2a4；
//     SwiftSoup 闭包#1 L539-551 @0x10001dd10；wrapJsonItemsAsChildRules L560-573 @0x10001ad8c；
//     闭包#1 L561-572 @0x10001dfec
//   - IDA: 上述地址的 Hex-Rays 伪代码
//   - 关键常量（低字节在前）："&&"=9766、"||"=31868、"%%"=9509、"<js>"=1047751228、
//     "</js>"=0x3E736A2F3C、"@js:"=980642368、":"=58
//   - 归组噪声（事实 42）：0x1002f468…0x100894f58 等 36 个地址被归为
//     `closure #6 in getElements`（同一 CovMap L145），但其伪代码引用
//     `章节索引越界`/`[BookService]` 字符串，属 CovMap 行号归组失真，
//     不按本文件语义还原；本文件以主条目 0x100021da0 为准。
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - getElements/getElementsSingle/getElement: medium-high（组合器语义/模式分发/
//     limit hint 逐条对应；细节门控见读后记“仍不清楚”）
//   - pipeline 家族（executeElementPipeline*）: medium-high
//   - wrap* 家族: medium-high（init(source:parent:)/ivar 继承/setContent 链可见）
//   - extractExcludeInfo / jsonObjectForElementPipeline: medium（PGO-only 无地址）
// 依赖: LegadoSourceRule/RuleMode（RuleModels 骨架）、LegadoRuleAnalyzer/LegadoJSoupAnalyzer/
//       LRUCache（T-206）、Kanna/SwiftSoup（SPM 包，只调用）、AnalyzeRule 主类
//       init(source:parent:)/setContent/readJsonPath/executeXPathRuleForNodes 等（T-201 后续）。
// 还原: 2026-11-18

import Foundation
import SwiftSoup
import Kanna

extension AnalyzeRule {

    // MARK: - 元素提取主入口

    /// 伪代码 0x1000177f4（L12-189）：元素列表提取。
    /// 1. 规则为空 → 返回当前内容；
    /// 2. maxResults 与 `searchResultLimitHint` 收敛（mode 1 不受限）；
    /// 3. `splitElementPipelineRules(rule, allInOne: true)` 拆出 ≥2 段 → pipeline 模式：
    ///    `executeElementPipelineRules` 后（mode 1 之外）`prefix(maxResults)` 截断；
    /// 4. 单段：JS 探测（`<js>...</js>` / lowercased `@js:` / `:` 前缀）→
    ///    `splitRules` + 模式分发循环；否则 `LegadoRuleAnalyzer.splitRule` 按
    ///    `&&`/`||`/`%%` 组合符拆段：
    ///    `||` 返回首个非空段结果；`%%` 各段收集后按索引轮转交错；
    ///    `&&` 顺序追加（达上限即停）；单段回退模式分发循环。
    func getElements(rule: String?, maxResults: Int?) -> [AnalyzeRule] {
        // 事实 23：空规则返回当前内容。
        guard let rule, !rule.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return [self]
        }

        // 事实 23：maxResults 与 searchResultLimitHint 收敛。
        let limit = resolveElementResultLimit(maxResults)

        // 事实 23：pipeline 拆分。
        let pipelineRules = splitElementPipelineRules(rule, allInOne: true)
        if pipelineRules.count >= 2 {
            let executed = AnalyzeRule.executeElementPipelineRules(
                pipelineRules,
                initialResult: nil,
                maxResults: maxResults
            )
            if limit.isUnlimited {
                return executed
            }
            return Array(executed.prefix(limit.value))
        }

        // 事实 24：JS 探测。
        let trimmed = rule.trimmingCharacters(in: .whitespacesAndNewlines)
        let isJsBlock = (trimmed.hasPrefix("<js>") && trimmed.contains("</js>"))
            || trimmed.lowercased().hasPrefix("@js:")
            || trimmed.hasPrefix(":")

        if isJsBlock {
            return collectElementsByMode(rules: splitRules(trimmed, allInOne: true), limit: limit)
        }

        // 事实 26/27：组合符拆段。
        let segments = Array(
            LegadoRuleAnalyzer
                .innerRule(trimmed, markers: ["&&", "||", "%%"])
                .split { $0.isEmpty }.map { String($0.joined()) })
        if segments.count <= 1 {
            return collectElementsByMode(rules: splitRules(trimmed, allInOne: true), limit: limit)
        }

        // 事实 27：组合语义 —— 拆分器回传命中的组合符。
        switch LegadoRuleAnalyzer.lastCombiner {
        case "||":
            // 伪代码 L1578-L1627：逐段 getElements，首个非空即返回。
            for segment in segments {
                let part = getElements(rule: segment, maxResults: maxResults)
                if !part.isEmpty {
                    return part
                }
            }
            return []
        case "%%":
            // 伪代码 L1635-L1688 + L1345-L1445：各段 getElementsSingle 收集，
            // 按索引轮转交错，受上限约束。
            var collected: [[AnalyzeRule]] = []
            for segment in segments {
                collected.append(getElementsSingle(rule: segment))
            }
            return interleave(collected, limit: limit)
        default:
            // 伪代码 L1693-L1780：&& 顺序追加，达上限即停。
            var result: [AnalyzeRule] = []
            for (offset, segment) in segments.enumerated() {
                let remaining = remainingCapacity(of: result, limit: limit)
                let isLast = offset == segments.count - 1
                let part = getElements(
                    rule: segment,
                    maxResults: isLast ? maxResults : remaining
                )
                appendCapped(part, to: &result, limit: limit)
                if !limit.isUnlimited, result.count >= limit.value {
                    break
                }
            }
            return result
        }
    }

    /// 伪代码 0x10001959c（appendCapped #1，L31-44）：
    /// mode 1 直接追加；否则剩余容量不足时 `prefix(remaining)` 截断；
    /// 返回“是否已达上限”。
    @discardableResult
    private func appendCapped(
        _ elements: [AnalyzeRule],
        to target: inout [AnalyzeRule],
        limit: ElementResultLimit
    ) -> Bool {
        if limit.isUnlimited {
            target.append(contentsOf: elements)
            return false
        }
        let remaining = limit.value - target.count
        if remaining <= 0 {
            return true
        }
        if remaining < elements.count {
            target.append(contentsOf: elements.prefix(remaining))
            return true
        }
        target.append(contentsOf: elements)
        return target.count >= limit.value
    }

    /// 别名 `remainingCapacity #1`（@0x100019740 L46-49）：返回剩余可收集数量，
    /// 不限流时为 nil。
    private func remainingCapacity(of collected: [AnalyzeRule], limit: ElementResultLimit) -> Int? {
        limit.isUnlimited ? nil : max(0, limit.value - collected.count)
    }

    /// getElements 的本地限额类型：mode 1 → 无限；否则为收敛后的数值。
    private func resolveElementResultLimit(_ maxResults: Int?) -> ElementResultLimit {
        if maxResults == 1 {
            return .unlimited
        }
        let requested = maxResults ?? 0
        if requested < 1 {
            return .unlimited
        }
        if searchResultLimitHintIsSet {
            return .capped(min(requested, searchResultLimitHint))
        }
        searchResultLimitHint = requested
        searchResultLimitHintIsSet = false
        return .capped(requested)
    }

    /// 事实 25：模式分发循环（LABEL_131 / LABEL_49 两处一致）。
    private func collectElementsByMode(
        rules: [LegadoSourceRule],
        limit: ElementResultLimit
    ) -> [AnalyzeRule] {
        var result: [AnalyzeRule] = []
        for sourceRule in rules {
            let effective = sourceRule.makeUpRule(result: contentString, context: self)
            switch effective.mode {
            case .default_, .css:
                // 事实 25：JSoup 选择子，结果 cap 后 wrapJsonItemsAsChildRules。
                let analyzer = LegadoJSoupAnalyzer(source: self)
                let nodes = analyzer.getElements(effective.rule)
                let capped = limit.isUnlimited ? nodes : Array(nodes.prefix(limit.value))
                appendCapped(AnalyzeRule.wrapJsonItemsAsChildRules(capped), to: &result, limit: limit)
            case .xpath:
                // 事实 25：XPath（空结果按伪代码记 `[XPath] -> 匹配 0` 日志）。
                // 节点装箱走 childRule 路径（wrapNodesAsChildRules 同域，wave-16）。
                let nodes = executeXPathRuleForNodes(effective.rule)
                if let nodes {
                    let wrapped = nodes.map { node in
                        AnalyzeRule.wrapNodesAsChildRules([node])
                    }
                    appendCapped(
                        Array(wrapped.joined()), to: &result, limit: limit)
                }
            case .json:
                // 事实 25：JSONPath（LRU 引擎缓存 + readJsonPath）。
                // getOrPut 无 key: 标签（LRUCache 签名域）；readJsonPath
                // 为 (source:rule:engine:) 三参域。
                let engine = Self.jsonPathEngineCache.getOrPut(effective.rule) {
                    Self.makeJsonPathEngine(for: effective.rule)
                }
                let value = readJsonPath(contentString, rule: effective.rule, engine: engine)
                if let anyValue = value {
                    appendCapped(
                        AnalyzeRule.wrapJsonItemsAsChildRules([anyValue]),
                        to: &result,
                        limit: limit
                    )
                }
            case .js:
                // 事实 25：executeJsRuleForElements + appendCapped。
                if let elements = executeJsRuleForElements(effective.rule) {
                    appendCapped(elements, to: &result, limit: limit)
                }
            case .regex:
                // 事实 25：AnalyzeByRegex.getElements（[String] 规则数组域）
                // + wrapJsonItemsAsChildRules（文本匹配装箱域）。
                let matches = AnalyzeByRegex.getElements(
                    contentString,
                    [effective.rule]
                ).flatMap { $0 }
                let capped = limit.isUnlimited ? matches : Array(matches.prefix(limit.value))
                appendCapped(AnalyzeRule.wrapJsonItemsAsChildRules(capped), to: &result, limit: limit)
            default:
                continue
            }
            if !limit.isUnlimited, result.count >= limit.value {
                break
            }
        }
        return result
    }

    /// 事实 27 的 `%%` 交错：按索引轮转合并多个数组。
    private func interleave(_ arrays: [[AnalyzeRule]], limit: ElementResultLimit) -> [AnalyzeRule] {
        guard !arrays.isEmpty else { return [] }
        var result: [AnalyzeRule] = []
        let maxCount = arrays.map(\.count).max() ?? 0
        for index in 0..<maxCount {
            for array in arrays where index < array.count {
                result.append(array[index])
                if !limit.isUnlimited, result.count >= limit.value {
                    return result
                }
            }
        }
        return result
    }

    // MARK: - 单元素提取

    /// 伪代码 0x10001d060（L394-429）：单元素提取 —— pipeline 逐级链接。
    /// mode ∈ {0,1,5,7}（位掩码 0xA3）→ `getElements(mode 1)` 取首元素并以其内容
    /// 作为下一段上下文；mode 2 → `executeElementPipelineJson`（nextMode=3）或
    /// `closure #7` + `readJsonPath`；mode 3 → JS 执行；任一段为空即返回 nil。
    func getElement(rule: String?) -> Any? {
        guard let rule, !rule.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        let pipelineRules = splitElementPipelineRules(rule, allInOne: true)
        if pipelineRules.isEmpty {
            return nil
        }

        var context: AnalyzeRule? = nil
        for (offset, sourceRule) in pipelineRules.enumerated() {
            let effective = sourceRule.makeUpRule(result: contentString, context: self)
            let nextIsJs = offset + 1 < pipelineRules.count
                && pipelineRules[offset + 1].mode == .js

            switch effective.mode {
            case .default_, .xpath, .regex, .css:
                // 事实 29：位掩码 0xA3 = {0,1,5,7}。
                let children = getElements(rule: effective.rule, maxResults: nil)
                guard let first = children.first else { return nil }
                context = first
            case .json:
                // 事实 29：mode 2 —— 下一级是 JS 时走 pipeline JSON，否则直接 readJsonPath。
                if nextIsJs {
                    guard let value = AnalyzeRule.executeElementPipelineJson(
                        effective.rule,
                        currentResult: context.map { $0 as Any } ?? contentString,
                        nextMode: .js,
                        maxResults: nil
                    ) else {
                        return nil
                    }
                    context = value as? AnalyzeRule
                } else {
                    let engine = Self.jsonPathEngineCache.getOrPut(effective.rule) {
                        Self.makeJsonPathEngine(for: effective.rule)
                    }
                    guard let value = readJsonPath(
                        contentString, rule: effective.rule, engine: engine) else {
                        return nil
                    }
                    context = Self.wrapElementPipelineResult(value).first
                }
            case .js:
                // 事实 29：mode 3 —— JS 直接以当前上下文求值。
                guard executeJsRuleWithValue(effective.rule, previousResult: context) != nil else {
                    return nil
                }
            default:
                return nil
            }
        }
        return context
    }

    /// 伪代码 0x100019b50（L433-498）：单条规则的元素列表。
    /// `:` 前缀走 innerRule 组合符拆分（语义与 getElements 一致：
    /// `||` 首个非空 / `%%` 交错 / `&&` 展平）；单段或无组合符 →
    /// splitElementPipelineRules（≥2 段 → pipeline）→ splitRules 模式分发。
    func getElementsSingle(rule: String?) -> [AnalyzeRule] {
        guard let rule, !rule.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        // 事实 41：组合符拆分。
        // 拆段 Array 化（ArraySlice→String 消解，wave-16）。
        let segments = Array(
            LegadoRuleAnalyzer
                .innerRule(rule.trimmingCharacters(in: .whitespacesAndNewlines),
                           markers: ["&&", "||", "%%"])
                .split { $0.isEmpty }.map { String($0.joined()) })
        if segments.count > 1 {
            switch LegadoRuleAnalyzer.lastCombiner {
            case "||":
                for segment in segments {
                    let part = getElementsSingle(rule: segment)
                    if !part.isEmpty {
                        return part
                    }
                }
                return []
            case "%%":
                var collected: [[AnalyzeRule]] = segments.map { getElementsSingle(rule: $0) }
                return interleave(collected, limit: .unlimited)
            default:
                // 伪代码 L8758-L8775：&& → append(contentsOf:) 展平。
                return segments.flatMap { getElementsSingle(rule: $0) }
            }
        }

        // 事实 41：pipeline 拆分。
        let pipelineRules = splitElementPipelineRules(rule, allInOne: true)
        if pipelineRules.count >= 2 {
            return AnalyzeRule.executeElementPipelineRules(
                pipelineRules,
                initialResult: nil,
                maxResults: nil
            )
        }

        return collectElementsByMode(rules: splitRules(rule, allInOne: true), limit: .unlimited)
    }

    /// 伪代码 0x10001bfe8（隐式闭包 #3，L484-484）：
    /// XPath 管道步骤 —— 对 analyzersForElementPipeline 逐个执行
    /// executeXPathRuleForNodes 并收集。
    func pipelineXPathClosure(_ rule: String, _ currentResult: Any) -> [AnalyzeRule] {
        var result: [AnalyzeRule] = []
        for analyzer in AnalyzeRule.analyzersForElementPipeline(currentResult) {
            let nodes = executeXPathRuleForNodes(rule)
            // 节点装箱走 wrapNodesAsChildRules（childRule 域，wave-16）。
            result.append(
                contentsOf: nodes.map { AnalyzeRule.wrapNodesAsChildRules($0) } ?? [])
        }
        return result
    }

    // MARK: - 元素管道

    /// 伪代码 0x100019740（L191-212）：管道规则顺序执行。
    /// 初始结果回退链与 makeUpRuleInput 相同（事实 30）；每步
    /// `executeElementPipelineStep`（nextMode 取下一段 mode）；mode 1 之外每步后
    /// `limitedElementPipelineValue` 截断；产出为空时清空上下文。
    static func executeElementPipelineRules(
        _ rules: [LegadoSourceRule],
        initialResult: Any?,
        maxResults: Int?
    ) -> [AnalyzeRule] {
        var current: Any? = initialResult
        for (offset, sourceRule) in rules.enumerated() {
            // 事实 30：i == 1（首段）直接 wrapElementPipelineResult。
            if offset == 0 {
                return wrapElementPipelineResult(current)
            }

            // 事实 30：每步 makeUp 后执行。
            // contentOf 为实例闭包域——经 sharedInstance 取用（wave-16）。
            let effective = sourceRule.makeUpRule(
                result: sharedInstance().contentOf(current), context: sharedInstance())
            let nextMode: RuleMode? = offset + 1 < rules.count ? rules[offset + 1].mode : nil
            guard !effective.rule.isEmpty else {
                break
            }
            let stepResult = executeElementPipelineStep(
                effective,
                currentResult: current ?? sharedInstance().contentOf(current) as Any,
                nextMode: nextMode,
                maxResults: maxResults
            )
            current = stepResult
            if maxResults != 1 {
                current = limitedElementPipelineValue(current, maxResults: maxResults ?? Int.max)
            }
            // 事实 30：产出为空内容时清空。
            if let text = current as? String, text.isEmpty {
                current = nil
            }
        }
        return wrapElementPipelineResult(current)
    }

    /// 伪代码 0x10001b044（L219-239）：管道单步 —— 按 mode 分发。
    static func executeElementPipelineStep(
        _ rule: LegadoSourceRule,
        currentResult: Any,
        nextMode: RuleMode?,
        maxResults: Int?
    ) -> Any? {
        switch rule.mode {
        case .default_, .css:
            // 事实 31：JSoup 管道步骤（executeElementPipelineXPath 闭包）。
            return sharedInstance().pipelineXPathClosure(rule.rule, currentResult)
        case .xpath:
            // 事实 31：getElementsSingle 的隐式闭包 #3。
            return sharedInstance().pipelineXPathClosure(rule.rule, currentResult)
        case .json:
            // 事实 31：executeElementPipelineJson。
            return AnalyzeRule.executeElementPipelineJson(
                rule.rule,
                currentResult: currentResult,
                nextMode: nextMode,
                maxResults: maxResults
            )
        case .js:
            // 事实 31：sub_10004DAEC —— JS 以当前结果求值。
            return sharedInstance().executeJsRuleWithValue(rule.rule, previousResult: currentResult)
        case .regex:
            // 事实 31：stringForElementPipeline + AnalyzeByRegex.getElements。
            let subject = stringForElementPipeline(currentResult)
            // AnalyzeByRegex.getElements 为 ([String], Int) 域——展平取值。
            return AnalyzeByRegex.getElements(subject, [rule.rule]).flatMap { $0 }
        default:
            return nil
        }
    }

    /// 伪代码 0x10001b6fc（L246-283）：管道 JSON 步骤。
    /// nextMode == 8 时结果按 [String] 归一（referenceJSONPipelineValues）；
    /// 逐 analyzer：LRU 引擎缓存 + readJsonPath；maxResults 截断（mode 1 之外）。
    static func executeElementPipelineJson(
        _ rule: String,
        currentResult: Any,
        nextMode: RuleMode?,
        maxResults: Int?
    ) -> Any? {
        let analyzers = analyzersForElementPipeline(currentResult)
        var values: [Any] = []
        for analyzer in analyzers {
            // getOrPut 无 key: 标签；readJsonPath 为 (source:rule:engine:) 域
            // ——以 analyzer 自身内容为源（wave-16）。
            let engine = jsonPathEngineCache.getOrPut(rule) {
                makeJsonPathEngine(for: rule)
            }
            guard let value = analyzer.readJsonPath(
                analyzer.contentString, rule: rule, engine: engine) else {
                continue
            }
            if nextMode == .mode8 {
                let references = referenceJSONPipelineValues(from: value)
                values.append(contentsOf: references.map { $0 as Any })
            } else {
                values.append(value)
            }
            if maxResults != 1, values.count >= (maxResults ?? Int.max) {
                break
            }
        }
        if values.isEmpty {
            return nil
        }
        return nextMode == .mode8
            ? values.compactMap { $0 as? String }
            : values
    }

    /// 伪代码 0x10001b224（L285-297）：管道值截断 —— 对
    /// [AnalyzeRule]/[Any]/[[String]] 三类分别 prefix(maxResults)。
    static func limitedElementPipelineValue(_ value: Any?, maxResults: Int) -> Any? {
        guard let value, maxResults > 0 else { return value }
        if let elements = value as? [AnalyzeRule], elements.count > maxResults {
            return Array(elements.prefix(maxResults))
        }
        if let items = value as? [Any], items.count > maxResults {
            return Array(items.prefix(maxResults))
        }
        if let lists = value as? [[String]], lists.count > maxResults {
            return Array(lists.prefix(maxResults))
        }
        return value
    }

    /// 伪代码 0x10001ca18（L299-306）：管道 JSON 值的字符串引用提取。
    static func referenceJSONPipelineValues(from value: Any) -> [String] {
        if let items = value as? [Any] {
            return items.compactMap { referenceJSONPipelineString(from: $0) }
        }
        if let single = referenceJSONPipelineString(from: value) {
            return [single]
        }
        return []
    }

    /// 伪代码 0x10001cbf8（L308-319）：JSON 对象字符串化，兜底
    /// LegadoJsonPathBridge.legadoString。
    static func referenceJSONPipelineString(from value: Any) -> String? {
        if value is NSNull {
            return nil
        }
        if JSONSerialization.isValidJSONObject(value) {
            if let data = try? JSONSerialization.data(withJSONObject: value, options: []),
               let string = String(data: data, encoding: .utf8) {
                return string
            }
        }
        let bridged = LegadoJsonPathBridge.legadoString(value)
        return (bridged?.isEmpty == false) ? bridged : nil
    }

    /// 伪代码 0x10001c110（L337-358）：管道值的字符串形态。
    /// String → 原样；AnalyzeRule → 内容串（空时 JSON 字符串化）；
    /// [AnalyzeRule] → 逐个内容串过滤空后 joined("\n")；JSON → 字符串化；
    /// 兜底 String(describing:)。
    static func stringForElementPipeline(_ value: Any) -> String {
        if let string = value as? String {
            return string
        }
        if let element = value as? AnalyzeRule {
            let content = element.contentString
            if !content.isEmpty {
                return content
            }
            if let object = element.jsonObject,
               JSONSerialization.isValidJSONObject(object),
               let data = try? JSONSerialization.data(withJSONObject: object, options: []),
               let string = String(data: data, encoding: .utf8) {
                return string
            }
            return ""
        }
        if let elements = value as? [AnalyzeRule] {
            return elements
                .map(\.contentString)
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
        }
        if JSONSerialization.isValidJSONObject(value) {
            if let data = try? JSONSerialization.data(withJSONObject: value, options: []),
               let string = String(data: data, encoding: .utf8) {
                return string
            }
        }
        return String(describing: value)
    }

    /// 伪代码 0x10001c8c8（L368-372）：[AnalyzeRule] 原样；单个装箱；其他归一。
    static func analyzersForElementPipeline(_ value: Any) -> [AnalyzeRule] {
        if let elements = value as? [AnalyzeRule] {
            return elements
        }
        if let element = value as? AnalyzeRule {
            return [element]
        }
        if let normalized = sharedInstance().normalizePipelineValue(value) {
            return [normalized]
        }
        return []
    }

    /// 别名 `analyzerForElementPipeline`（@0x10001d060 L360-366）：单值 → 首个 analyzer。
    static func analyzerForElementPipeline(_ value: Any) -> AnalyzeRule? {
        analyzersForElementPipeline(value).first
    }

    /// 伪代码 0x10001c774（闭包 #1 in executeElementPipelineXPath，L381-383）：
    /// 对每个 analyzer 执行 JSoup getElements + wrapJsonItemsAsChildRules。
    static func executeElementPipelineXPath(
        _ rule: String,
        currentResult: Any
    ) -> [AnalyzeRule] {
        var result: [AnalyzeRule] = []
        for analyzer in analyzersForElementPipeline(currentResult) {
            let nodes = LegadoJSoupAnalyzer(source: analyzer).getElements(rule)
            result.append(contentsOf: wrapJsonItemsAsChildRules(nodes))
        }
        return result
    }

    /// 别名 `executeElementPipelineCss`（@0x10001c8c8 L374-378）：
    /// 与 XPath 管道同构，走 CSS 选择子。
    static func executeElementPipelineCss(
        _ rule: String,
        currentResult: Any
    ) -> [AnalyzeRule] {
        var result: [AnalyzeRule] = []
        for analyzer in analyzersForElementPipeline(currentResult) {
            let nodes = LegadoJSoupAnalyzer(source: analyzer).getElements(rule)
            result.append(contentsOf: wrapJsonItemsAsChildRules(nodes))
        }
        return result
    }

    /// 伪代码 0x10001b474（L386-392）：管道结果包装。
    /// nil → []；AnalyzeRule → 单元素；[AnalyzeRule] → 原样；[Any] → 转换；
    /// 其他 JSON 单值 → 单元素可选数组。
    static func wrapElementPipelineResult(_ value: Any?) -> [AnalyzeRule] {
        guard let value else { return [] }
        if value is NSNull {
            return []
        }
        if let element = value as? AnalyzeRule {
            return [element]
        }
        if let elements = value as? [AnalyzeRule] {
            return elements
        }
        if let items = value as? [Any] {
            return wrapJsonItemsAsChildRules(items)
        }
        return wrapJsonItemsAsChildRules([value])
    }

    /// 别名 `wrapRegexGroupListsAsChildRules`（@0x10001b044 L575-585）：
    /// `[[String]]` → 每个内层组包成子 AnalyzeRule（配合 $N 组引用）。
    /// 经 childRule 构造（无 groupContent init，wave-16）。
    static func wrapRegexGroupListsAsChildRules(_ lists: [[String]]) -> [AnalyzeRule] {
        lists.compactMap { group in
            childRule(for: group as Any, contentClosure: { group.joined(separator: "\n") })
        }
    }

    /// 别名 `isKannaElementNode`（@0x10001dd10 L554-557）。
    static func isKannaElementNode(_ node: Any) -> Bool {
        node is KannaXMLElement
    }

    /// 伪代码 0x10001ac98（L503-535）+ 闭包 #1（0x10001d66c）：
    /// [Kanna.XMLElement] → 逐节点构造子 AnalyzeRule：
    /// 关联存储（节点 +168）命中 LRU 则复用；否则复制父级上下文
    /// （memcpy 0x578）→ `init(source:parent:)` → 继承 book/baseUrl →
    /// `setContent(_:baseUrl:)` → 写回关联存储。
    static func wrapNodesAsChildRules(_ nodes: [KannaXMLElement]) -> [AnalyzeRule] {
        nodes.compactMap { node in
            // Kanna XMLElement 无 xmlString——innerHTML 等价桥（协议域）。
            childRule(for: node, contentClosure: { node.innerHTML ?? "" })
        }
    }

    /// 伪代码 0x10001dd10（闭包 #1 in wrapSoupNodesAsChildRules，L539-551）：
    /// SwiftSoup.Element → html（throws）→ 同上构造子规则；
    /// v12[22] = element、v12[21] 链接父级关联对象。
    static func wrapSoupNodesAsChildRules(_ nodes: [SwiftSoupElement]) -> [AnalyzeRule] {
        nodes.compactMap { node in
            guard let html = try? node.html(), !html.isEmpty else {
                return nil
            }
            return childRule(for: node, contentClosure: { html })
        }
    }

    /// 伪代码 0x10001ad8c（L560-573）+ 闭包 #1（0x10001dfec）：
    /// [Any] → 逐项构造子规则：String → setContent；其他 → JSON 序列化
    /// 到内容（sub_100011994）；nil 项丢弃。
    static func wrapJsonItemsAsChildRules(_ items: [Any]) -> [AnalyzeRule] {
        items.compactMap { item in
            if item is NSNull {
                return nil
            }
            return childRule(for: item, contentClosure: {
                Self.stringFromRuleResult(item)
            })
        }
    }

    /// PGO-only `jsonObjectForElementPipeline`（无地址，可能内联）：
    /// 管道值的 JSON 对象形态。
    static func jsonObjectForElementPipeline(_ value: Any) -> Any? {
        if JSONSerialization.isValidJSONObject(value) {
            return value
        }
        if let string = value as? String,
           let data = string.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: data) {
            return object
        }
        return nil
    }

    /// PGO-only `extractExcludeInfo`（无地址）：解析排除信息元组。
    /// 依据：签名 `(String) -> (String, Bool, Bool, (start: Int, end: Int)?)`；
    /// 语义按 Legado 排除正则惯例还原（`##排除` 风格），细节待 T-201 后续交叉验证。
    static func extractExcludeInfo(_ rule: String) -> (String, Bool, Bool, (start: Int, end: Int)?) {
        guard let range = rule.range(of: "##") else {
            return (rule, false, false, nil)
        }
        let body = String(rule[range.upperBound...])
        let replaceFirst = body.hasSuffix("###")
        let trimmed = replaceFirst ? String(body.dropLast(3)) : body
        return (
            String(rule[rule.startIndex..<range.lowerBound]),
            !trimmed.isEmpty,
            replaceFirst,
            (rule.distance(from: rule.startIndex, to: range.lowerBound),
             rule.distance(from: rule.startIndex, to: rule.endIndex))
        )
    }
}

// MARK: - 私有支撑类型与静态缓存

extension AnalyzeRule {

    /// getElements 限额的语义承载（伪代码 mode-1 / 数值两态）。
    enum ElementResultLimit {
        case unlimited
        case capped(Int)

        var isUnlimited: Bool {
            if case .unlimited = self { return true }
            return false
        }

        var value: Int {
            if case .capped(let value) = self { return value }
            return Int.max
        }
    }

    /// 事实 25 的 JSONPath 引擎 LRU 缓存（伪代码 LRUCache.getOrPut）。
    /// 存储声明在主类文件（AnalyzeRule.jsonPathEngineCache）。

    /// 子规则构造共用路径（wrap* 三族共享）：
    /// 复制父级上下文 → init(source:parent:) → 继承 book/baseUrl → setContent。
    /// init source 为 BookSource?——泛型载荷经 as? 降取（wave-16）。
    static func childRule(
        for source: Any,
        contentClosure: () -> String
    ) -> AnalyzeRule? {
        let parent = sharedInstance()
        let child = AnalyzeRule(source: source as? BookSource, parent: parent)
        child.book = parent.book
        let content = contentClosure()
        guard !content.isEmpty else { return nil }
        child.setContent(content, baseUrl: parent.baseUrl)
        return child
    }

    /// 事实 23 载体：searchResultLimitHint（伪代码 ivar + 标志字节）。
    /// 存储域置于 AnalyzeRule 类体（extension 不可含存储属性，wave-16）。
    var searchResultLimitHint: Int {
        get { storedSearchResultLimitHint }
        set { storedSearchResultLimitHint = newValue }
    }

    var searchResultLimitHintIsSet: Bool {
        get { storedSearchResultLimitHintIsSet }
        set { storedSearchResultLimitHintIsSet = newValue }
    }
}
