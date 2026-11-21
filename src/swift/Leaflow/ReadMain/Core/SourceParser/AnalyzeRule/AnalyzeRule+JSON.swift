// 原路径: ReadMain/Core/SourceParser/AnalyzeRule/AnalyzeRule+JSON.swift
// 证据:
//   - PGO: executeJsonRule / executeJsonRuleForList / readJsonPath(LL) / executeJsonInnerRule(LL) /
//     stripJsonPrefix(LL) / isNonEmptyJsonPathResult(LL) / jsonObjectForElementPipeline /
//     jsonPathResultArray(LL) 及闭包
//   - CovMap: L30-58 @0x10005821c；L60-71 @0x100059498；L90-133 @0x100058b20；
//     L135-145 @0x100059958；L147-153 @0x1000598a4；L155-161 @0x100059ce8；
//     L163-166 @0x100059fd4（ICF 副本 0x100066224）
//   - IDA: 上述地址的 Hex-Rays 伪代码
//   - 关键常量："&&"=9766、"||"=31868、"%%"=9509、"{$."=3023995
//   - 诊断串："[JSON] 执行规则: \""、"[JSON] JsonPath返回nil, path=\""
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - readJsonPath: high（拆段/组合符/内嵌规则链逐条对应）
//   - executeJsonRule / executeJsonRuleForList / executeJsonInnerRule: high
//   - isNonEmptyJsonPathResult / stripJsonPrefix / jsonPathResultArray: high
// 依赖: LegadoRuleAnalyzer（T-201 后续）、LegadoJsonPathBridge（T-201 后续）、LRUCache。
// 还原: 2026-11-18

import Foundation

extension AnalyzeRule {

    /// 伪代码 0x10005821c（L30-58）：JSONPath 单值执行。
    /// 引擎 LRU 缓存 → readJsonPath → nil 记日志返回 nil；
    /// 数组 → legadoString 过滤空 joined("\n")；单值 → legadoString（空 → nil）。
    func executeJsonRule(_ rule: String) -> String? {
        let engine = Self.jsonPathEngineCache.getOrPut(rule) {
            Self.makeJsonPathEngine(for: rule)
        }
        if Self.debugMode {
            Logger.log(
                "[JSON] 执行规则: \"\(rule)\" 内容长度=\(contentString.count)",
                level: Self.executeRuleLogLevel
            )
        }
        guard let value = readJsonPath(contentString, rule: rule, engine: engine) else {
            if Self.debugMode {
                Logger.log(
                    "[JSON] JsonPath返回nil, path=\"\(rule)\"",
                    level: Self.executeRuleLogLevel
                )
            }
            return nil
        }
        if let items = value as? [Any] {
            let strings = items.compactMap { LegadoJsonPathBridge.legadoString($0) }
                .filter { !$0.isEmpty }
            return strings.isEmpty ? nil : strings.joined(separator: "\n")
        }
        let single = LegadoJsonPathBridge.legadoString(value)
        return (single?.isEmpty == false) ? single : nil
    }

    /// 伪代码 0x100059498（L60-71）：JSONPath 列表执行。
    /// 数组 → [String]（空 → nil）；单值 → 单元素数组；nil → nil。
    func executeJsonRuleForList(_ rule: String) -> [String]? {
        let engine = Self.jsonPathEngineCache.getOrPut(rule) {
            Self.makeJsonPathEngine(for: rule)
        }
        guard let value = readJsonPath(contentString, rule: rule, engine: engine) else {
            return nil
        }
        if let items = value as? [Any] {
            let strings = items.compactMap { LegadoJsonPathBridge.legadoString($0) }
            return strings.isEmpty ? nil : strings
        }
        guard let single = LegadoJsonPathBridge.legadoString(value), !single.isEmpty else {
            return nil
        }
        return [single]
    }

    /// 伪代码 0x100058b20（L90-133）：JSONPath 求值核心。
    /// 1. 入参 JSON 化为空 → nil；
    /// 2. innerRule 按 && / || / %% 拆段、trim、过滤空段；
    /// 3. 单段：内嵌规则 innerRule("{$.", stripJsonPrefix) 命中即返回；
    ///    否则 LegadoJsonPathBridge.read（出错 → nil）；
    /// 4. 多段：递归求值 + isNonEmptyJsonPathResult 过滤；
    ///    || 首个非空即止、%% 索引轮转交错、&& 顺序展平。
    func readJsonPath(_ source: Any, rule: String, engine: AnyObject? = nil) -> Any? {
        let jsonObject = Self.jsonObjectForElementPipeline(source)
        guard jsonObject != nil else { return nil }

        // 拆段 Array 化 + 元素 String 化（ArraySlice→String 消解，wave-16）。
        let segments = Array(
            LegadoRuleAnalyzer
                .innerRule(rule, markers: ["&&", "||", "%%"])
                .split { $0.isEmpty }
        ).map {
            $0.joined().trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if segments.count <= 1 {
            // 事实 7：单段 —— 内嵌规则优先。
            if let inner = LegadoRuleAnalyzer.innerRule(
                rule,
                startMark: "{$.",
                transform: { [weak self] inner in
                    self?.stripJsonPrefix(inner) ?? nil
                }
            ), !inner.isEmpty {
                return inner
            }
            do {
                return try LegadoJsonPathBridge.read(jsonObject!, path: rule)
            } catch {
                return nil
            }
        }

        // 事实 7：多段组合。
        var collected: [[Any]] = []
        for segment in segments {
            guard let value = readJsonPath(source, rule: segment, engine: engine),
                  Self.isNonEmptyJsonPathResult(value) else {
                if LegadoRuleAnalyzer.lastCombiner == "||" {
                    continue
                }
                collected.append([])
                continue
            }
            collected.append(Self.jsonPathResultArray(value))
            if LegadoRuleAnalyzer.lastCombiner == "||" {
                break
            }
        }

        switch LegadoRuleAnalyzer.lastCombiner {
        case "%%":
            // 伪代码 L923-L970：索引轮转交错。
            var result: [Any] = []
            let maxCount = collected.map(\.count).max() ?? 0
            for index in 0..<maxCount {
                for array in collected where index < array.count {
                    result.append(array[index])
                }
            }
            return result.isEmpty ? nil : result
        case "||":
            return collected.first { !$0.isEmpty } ?? nil
        default:
            // 伪代码 L864-L919：&& 顺序展平。
            let flattened = collected.flatMap { $0 }
            return flattened.isEmpty ? nil : flattened
        }
    }

    /// 伪代码 0x100059958（L135-145）：JSONPath 内嵌规则执行。
    /// 结果空 → nil；数组 → legadoString joined("\n")；单值 → legadoString。
    func executeJsonInnerRule(_ source: Any, rule: String) -> String? {
        guard let value = readJsonPath(source, rule: rule),
              Self.isNonEmptyJsonPathResult(value) else {
            return nil
        }
        if let items = value as? [Any] {
            let strings = items.compactMap { LegadoJsonPathBridge.legadoString($0) }
                .filter { !$0.isEmpty }
            return strings.isEmpty ? nil : strings.joined(separator: "\n")
        }
        let single = LegadoJsonPathBridge.legadoString(value)
        return (single?.isEmpty == false) ? single : nil
    }

    /// 伪代码 0x1000598a4（L147-153）：内嵌规则的 transform 回调。
    /// weak self 强加载失败 → nil。
    func stripJsonPrefix(_ inner: String) -> String? {
        executeJsonInnerRule(contentString, rule: inner)
    }

    /// 伪代码 0x100059ce8（L155-161）：
    /// [Any]/[String]/String 非空为真；NSNull → false；其余 → true。
    static func isNonEmptyJsonPathResult(_ value: Any) -> Bool {
        if let array = value as? [Any] {
            return !array.isEmpty
        }
        if let strings = value as? [String] {
            return !strings.isEmpty
        }
        if let string = value as? String {
            return !string.isEmpty
        }
        if value is NSNull {
            return false
        }
        return true
    }

    /// 伪代码 0x100059fd4（L163-166）：结果归一为数组形态。
    /// 已是数组 → 原样；其余 → 单元素数组。
    static func jsonPathResultArray(_ value: Any) -> [Any] {
        if let array = value as? [Any] {
            return array
        }
        return [value]
    }
}
