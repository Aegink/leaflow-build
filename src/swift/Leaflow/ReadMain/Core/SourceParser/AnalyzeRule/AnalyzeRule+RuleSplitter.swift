// 原路径: ReadMain/Core/SourceParser/AnalyzeRule/AnalyzeRule+RuleSplitter.swift
// 证据:
//   - PGO: splitRules / parseLegadoPutMap / unquoteLegadoPutToken(LL) /
//     splitElementPipelineRules / splitFirstEmbeddedJsBlock(LL) / splitFirstJsSuffix(LL) /
//     findReplaceRegex(LL) / detectMode(LL) / containsMakeUpTemplate(LL) / isJsonContent /
//     removePrefix(LL) / isJsBlockRule / executeLegadoPutMap / splitJavaScriptPipelineRulesIfNeeded(LL) /
//     strippedPutMapBraces(LL) / isRegexBlockRule / countOccurrences / isJsonPathRule 等及全部闭包
//   - CovMap: splitRules L11-232 @0x100066b90；parseLegadoPutMap L234-255 @0x100069208；
//     unquoteLegadoPutToken L275-315 @0x10006ad50；splitElementPipelineRules L317-345 @0x100066784；
//     splitFirstEmbeddedJsBlock L369-380 @0x10006b598；splitFirstJsSuffix L382-396 @0x10006ba18；
//     findReplaceRegex L400-427 @0x100069bbc；detectMode L442-498 @0x10006a16c；
//     containsMakeUpTemplate L500-502 @0x10006c3bc（5 个 ICF 副本）；isJsonContent L505-513
//     @0x100068f3c；removePrefix L516-533 @0x10006a8c0
//   - IDA: 上述地址的 Hex-Rays 伪代码 + 字符串常量表
//   - 关键常量（低字节在前）：前缀映射 @css:→7 / @xpath:→1 / @json:→2 / @webjs:→4 /
//     @regex:→5 / @get:→6 / @put:→6（0x3A736A40 系列）；"$."/"$["/"$.."→2；
//     "//"=12079；转义感知扫描 "\n"=10/`"`=34/`'`=39/`:`=58/`\`=92/`` ` ``=96/n=110/r=114/t=116；
//     makeUp 模板 {{result(0x746C757365727B7B)/result =(0x3D20746C75736572)/' + result + '
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - detectMode: high（前缀→mode 映射逐条对应；默认 3 的语义见读后记推断 1）
//   - findReplaceRegex / parseLegadoPutMap / unquoteLegadoPutToken: medium-high
//   - splitRules: medium-high（mode 赋值/JS 块剥离余段置 7/LRU+调试串可见；
//     逐字符扫描细节见“仍不清楚”）
// 依赖: LegadoSourceRule/RuleMode（RuleModels 骨架）。
// 还原: 2026-11-18

import Foundation

extension AnalyzeRule {

    // MARK: - 模式探测

    /// 伪代码 0x10006a16c（L442-498）：规则模式探测。
    /// trim + lowercased 后按前缀分发；无前缀且无 `|`/`[` → 默认 .js（推断 1）。
    func detectMode(_ rule: String) -> RuleMode {
        let trimmed = rule.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowered = trimmed.lowercased()
        if lowered.hasPrefix("@css:") { return .css }
        if lowered.hasPrefix("@xpath:") { return .xpath }
        if lowered.hasPrefix("@json:") { return .json }
        if lowered.hasPrefix("@js:") || lowered.hasPrefix("<js>") { return .js }
        if lowered.hasPrefix("@webjs:") { return .mode4 }
        if lowered.hasPrefix("@regex:") { return .regex }
        if lowered.hasPrefix("@get:") || lowered.hasPrefix("@put:") { return .mode6 }
        // 引号包裹的 put token → CSS。
        if Self.isQuotedToken(trimmed) { return .css }
        if Self.isJsonContent() { return .json }
        if lowered.hasPrefix("$.") || lowered.hasPrefix("$[") || lowered.hasPrefix("$..") {
            return .json
        }
        if lowered.hasPrefix("//") {
            return Self.isValidXPath(trimmed) ? .xpath : .css
        }
        if trimmed.contains("|") || trimmed.contains("[") {
            return Self.isValidXPath(trimmed) ? .xpath : .css
        }
        // 事实 11：无前缀默认 → .js（JS 求值链内部回退文本，见推断 1）。
        return .js
    }

    /// 事实 11：引号包裹判定（unquote 闭包 #5 的字符级实现）。
    static func isQuotedToken(_ token: String) -> Bool {
        guard let first = token.first, let last = token.last, first == last else {
            return false
        }
        return first == "'" || first == "\"" || first == "`"
    }

    // MARK: - 主拆分器

    /// 伪代码 0x100066b90（L11-232）：规则拆分主入口。
    /// `##` 替换段先剥离（findReplaceRegex，引号感知）；JS 块/后缀剥离后
    /// 余段置 mode 7；逐段 detectMode + LegadoSourceRule 组装；mode 结果
    /// LRUCache 登记（调试串 `!`/`rule=`/`regex=`/` index=`）。
    func splitRules(_ rule: String?, allInOne: Bool) -> [LegadoSourceRule] {
        guard let rule, !rule.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        var body = rule
        var replaceRegex: String?
        var replacement: String?
        var replaceFirst = false

        // 事实 15：## 替换段（引号感知扫描）。
        if let replaceRange = Self.findReplaceRegex(in: body) {
            let replaceBody = String(body[replaceRange.upperBound...])
            body = String(body[body.startIndex..<replaceRange.lowerBound])
            let parts = replaceBody.split(separator: "##", omittingEmptySubsequences: false)
                .map(String.init)
            if parts.count >= 1 { replaceRegex = parts[0] }
            if parts.count >= 2 { replacement = parts[1] }
            replaceFirst = parts.count >= 3
        }

        // 事实 12：JS 块/后缀剥离。
        var jsPipeline: [LegadoSourceRule] = []
        if let split = splitFirstJsSuffix(body) {
            jsPipeline.append(contentsOf: splitRules(split.before, allInOne: allInOne))
            jsPipeline.append(
                LegadoSourceRule(
                    rule: split.jsCode,
                    mode: .js,
                    replaceRegex: nil,
                    replacement: nil,
                    replaceFirst: false,
                    putMap: nil,
                    indexExtract: nil,
                    ruleParam: nil,
                    ruleType: nil
                )
            )
            return jsPipeline
        }

        let mode = detectMode(body)
        if Self.debugMode {
            Logger.log(
                "!\(mode) rule=\(body) regex=\(replaceRegex ?? "-") index=\(allInOne ? 1 : 0)",
                level: Self.executeRuleLogLevel
            )
        }

        var result: [LegadoSourceRule] = [
            LegadoSourceRule(
                rule: body,
                mode: mode,
                replaceRegex: replaceRegex,
                replacement: replacement,
                replaceFirst: replaceFirst,
                putMap: strippedPutMapBraces(body).flatMap { parseLegadoPutMap($0) },
                indexExtract: Self.indexExtract(from: body),
                ruleParam: nil,
                ruleType: nil
            )
        ]
        if !allInOne {
            result.append(contentsOf: jsPipeline)
        }
        return result
    }

    /// 伪代码 0x100066784（L317-345）：元素管道拆分（&&/||/%% 由调用方处理）。
    /// 与 splitRules 同链路但保留管道组合符语义。
    func splitElementPipelineRules(_ rule: String?, allInOne: Bool) -> [LegadoSourceRule] {
        guard let rule, !rule.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        if let split = splitJavaScriptPipelineRulesIfNeeded(rule, allInOne: allInOne) {
            return split
        }
        return splitRules(rule, allInOne: allInOne)
    }

    /// 别名函数（骨架）：JS 管道拆分入口。
    func splitJavaScriptPipelineRulesIfNeeded(
        _ rule: String,
        allInOne: Bool
    ) -> [LegadoSourceRule]? {
        guard let split = splitFirstEmbeddedJsBlock(rule) else { return nil }
        var result: [LegadoSourceRule] = []
        if !split.before.isEmpty {
            result.append(contentsOf: splitRules(split.before, allInOne: allInOne))
        }
        result.append(
            LegadoSourceRule(
                rule: split.jsCode,
                mode: .js,
                replaceRegex: nil,
                replacement: nil,
                replaceFirst: false,
                putMap: nil,
                indexExtract: nil,
                ruleParam: nil,
                ruleType: nil
            )
        )
        if !split.after.isEmpty {
            result.append(contentsOf: splitRules(split.after, allInOne: allInOne))
        }
        return result
    }

    /// 伪代码 0x10006b598（L369-380）：首个内嵌 `<js>...</js>` 块剥离。
    func splitFirstEmbeddedJsBlock(_ rule: String) -> (before: String, jsCode: String, after: String)? {
        guard let open = rule.range(of: "<js>") else { return nil }
        guard let close = rule.range(of: "</js>", range: open.upperBound..<rule.endIndex) else {
            return nil
        }
        return (
            String(rule[rule.startIndex..<open.lowerBound]),
            String(rule[open.upperBound..<close.lowerBound]),
            String(rule[close.upperBound...])
        )
    }

    /// 伪代码 0x10006ba18（L382-396）：`@js:` 后缀剥离。
    func splitFirstJsSuffix(_ rule: String) -> (before: String, jsCode: String)? {
        guard let marker = rule.range(of: "@js:", options: .caseInsensitive) else {
            return nil
        }
        return (
            String(rule[rule.startIndex..<marker.lowerBound]),
            String(rule[marker.upperBound...])
        )
    }

    // MARK: - 替换段定位

    /// 伪代码 0x100069bbc（L400-427）：字符级扫描 `##`，引号内内容跳过。
    static func findReplaceRegex(in rule: String) -> Range<String.Index>? {
        var quote: Character?
        var index = rule.startIndex
        while index < rule.endIndex {
            let character = rule[index]
            if let current = quote {
                if character == current {
                    quote = nil
                }
            } else if character == "'" || character == "\"" {
                quote = character
            } else if character == "#",
                      rule.index(after: index) < rule.endIndex,
                      rule[rule.index(after: index)] == "#" {
                return index..<rule.index(after: index)
            }
            index = rule.index(after: index)
        }
        return nil
    }

    // MARK: - putMap 与引号

    /// 伪代码 0x100069208（L234-255）：`key:value` 逗号分隔 putMap 解析。
    func parseLegadoPutMap(_ text: String) -> [String: String]? {
        var result: [String: String] = [:]
        var found = false
        for pair in text.split(separator: ",") {
            let parts = pair.split(separator: ":", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            result[unquoteLegadoPutToken(parts[0])] = unquoteLegadoPutToken(parts[1])
            found = true
        }
        return found ? result : nil
    }

    /// 伪代码 0x10006ad50（L275-315）：剥离包裹引号并还原转义（\n/\r/\t/\\）。
    func unquoteLegadoPutToken(_ token: String) -> String {
        var body = token.trimmingCharacters(in: .whitespaces)
        if body.count >= 2 {
            let first = body.first!, last = body.last!
            if first == last, first == "'" || first == "\"" || first == "`" {
                body = String(body.dropFirst().dropLast())
            }
        }
        return body
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\r", with: "\r")
            .replacingOccurrences(of: "\\t", with: "\t")
            .replacingOccurrences(of: "\\\\", with: "\\")
    }

    /// 别名函数（骨架）：`{...}` 包裹剥离。
    func strippedPutMapBraces(_ rule: String) -> String? {
        guard let open = rule.firstIndex(of: "{"),
              let close = rule.lastIndex(of: "}"), open < close else {
            return nil
        }
        return String(rule[rule.index(after: open)..<close])
    }

    /// 别名函数（骨架）：putMap 变量写入（executeLegadoPutMap）。
    func executeLegadoPutMap(_ putMap: [String: String]) -> String {
        for (key, value) in putMap {
            putVariable(key, value: value)
        }
        return putMap.values.joined(separator: ",")
    }

    /// 别名函数（骨架）：`$N` 索引提取（indexExtract 参数）。
    static func indexExtract(from rule: String) -> Int? {
        guard let range = rule.range(of: "$", options: .backwards) else { return nil }
        let body = rule[range.upperBound...]
        guard let number = Int(body) else { return nil }
        return number
    }

    // MARK: - 辅助判定

    /// 伪代码 0x10006c3bc（L500-502）：makeUp 模板包含判定。
    static func containsMakeUpTemplate(_ rule: String) -> Bool {
        rule.contains("{{") && rule.contains("}}")
    }

    /// 伪代码 0x100068f3c（L505-513）：当前内容是否 JSON。
    func isJsonContent() -> Bool {
        let trimmed = contentString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("{") || trimmed.hasPrefix("[") else { return false }
        guard let data = trimmed.data(using: .utf8) else { return false }
        return (try? JSONSerialization.jsonObject(with: data)) != nil
    }

    /// 伪代码 0x10006a8c0（L516-533）：规则前缀剥离（@css:/@xpath: 等）。
    static func removePrefix(_ rule: String) -> String {
        let lowered = rule.lowercased()
        let prefixes = ["@css:", "@xpath:", "@json:", "@js:", "@webjs:", "@regex:", "@get:", "@put:"]
        for prefix in prefixes where lowered.hasPrefix(prefix) {
            return String(rule.dropFirst(prefix.count))
        }
        return rule
    }

    /// 伪代码 L552（closure #2，含 5 个 ICF 副本）：JS 块判定。
    static func isJsBlockRule(_ rule: String) -> Bool {
        let lowered = rule.lowercased()
        return lowered.hasPrefix("<js>") || lowered.contains("</js>")
            || lowered.hasPrefix("@js:") || lowered.contains("@js:")
    }

    /// 别名函数（骨架）：正则块判定（与 isJsBlockRule 同构）。
    static func isRegexBlockRule(_ rule: String) -> Bool {
        rule.lowercased().hasPrefix("@regex:")
    }

    /// 别名函数（骨架）：子串出现次数。
    static func countOccurrences(of needle: String, in haystack: Substring) -> Int {
        guard !needle.isEmpty else { return 0 }
        return haystack.components(separatedBy: needle).count - 1
    }

    /// 别名函数（骨架）：JSONPath 规则判定。
    static func isJsonPathRule(_ rule: String) -> Bool {
        rule.hasPrefix("$.") || rule.hasPrefix("$[") || rule.hasPrefix("$..")
    }
}
