// 原路径: ReadMain/Core/SourceParser/AnalyzeRule/AnalyzeRule+PostProcessing.swift
// 证据:
//   - PGO: applyPostProcessing(rule:result:isUrl:) / applyRegexReplace(LL)
//   - CovMap: applyPostProcessing L7-64 @0x1000649a4；applyRegexReplace L73-133 @0x100065094
//   - IDA: 上述地址的 Hex-Rays 伪代码
//   - 关键常量："["=91（JSON 结果前缀）、"{{"=31611、"}}"=32125、"$"=36
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - applyRegexReplace: high（缓存/字面回退/$N 展开逐条对应）
//   - applyPostProcessing: high（JSON 索引/replaceRegex/putMap/formatUrl 链确证）
// 依赖: processInnerJs（InnerRuleProcessor）、formatUrl（LegadoChain）。
// 还原: 2026-11-18

import Foundation

extension AnalyzeRule {

    /// 伪代码 0x1000649a4（L7-64）：规则后处理。
    /// 1. 规则标志字节（跳过 JSON 步骤）→ 直接进 replaceRegex；
    /// 2. 结果 `[` 开头 → JSON 解析 + 索引取元素（负索引回绕），元素为
    ///    JSON 对象时重新字符串化，否则 String(describing:)；
    /// 3. replaceRegex：pattern/replacement 含 {{...}} 先过 processInnerJs，
    ///    再 applyRegexReplace；
    /// 4. putMap 存在 → isJsonContent 检查（变量写入）；
    /// 5. isUrl 且结果非 nil → formatUrl。
    func applyPostProcessing(rule: LegadoSourceRule, result: String?, isUrl: Bool) -> String? {
        var value = result

        // 事实 1：`[` 前缀 JSON 索引提取。
        if !rule.skipsJsonPostProcessing, var text = value, text.hasPrefix("[") {
            if let data = text.data(using: .utf8),
                let parsed = try? JSONSerialization.jsonObject(with: data) {
                if let array = parsed as? [Any] {
                    var index = rule.indexExtract ?? 0
                    if index < 0 { index += array.count }
                    if index >= 0, index < array.count {
                        let element = array[index]
                        if JSONSerialization.isValidJSONObject(element) {
                            if let jsonData = try? JSONSerialization.data(
                                withJSONObject: element, options: []
                            ), let json = String(data: jsonData, encoding: .utf8) {
                                text = json
                            } else {
                                text = String(describing: element)
                            }
                        } else {
                            text = String(describing: element)
                        }
                        value = text
                    }
                }
            }
        }

        // 事实 2：replaceRegex。
        if let pattern = rule.replaceRegex, !pattern.isEmpty, value != nil {
            var processedPattern = pattern
            if processedPattern.hasPrefix("{{"), processedPattern.hasSuffix("}}") {
                processedPattern = processInnerJs(processedPattern)
            }
            var processedReplacement = rule.replacement ?? ""
            if processedReplacement.hasPrefix("{{"), processedReplacement.hasSuffix("}}") {
                processedReplacement = processInnerJs(processedReplacement)
            }
            value = Self.applyRegexReplace(
                content: value ?? "",
                pattern: processedPattern,
                replacement: processedReplacement,
                replaceFirst: rule.replaceFirst
            )
        }

        // 事实 2：putMap 变量写入。
        if let putMap = rule.putMap {
            _ = executeLegadoPutMap(putMap)
        }

        // 事实 2：isUrl → formatUrl。
        if isUrl, let text = value {
            value = formatUrl(text)
        }
        return value
    }

    /// 伪代码 0x100065094（L73-133）：正则替换。
    /// 编译失败 → replaceFirst 走 range(of:) 首处字面替换，否则字面全替；
    /// `$N` 模板逐组展开；非 replaceFirst 倒序逐匹配替换；replaceFirst 只替换首处。
    static func applyRegexReplace(
        content: String,
        pattern: String,
        replacement: String,
        replaceFirst: Bool
    ) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            // 事实 3：编译失败的字面回退。
            if replaceFirst {
                guard let range = content.range(of: pattern) else { return content }
                return content.replacingCharacters(in: range, with: replacement)
            }
            return content.replacingOccurrences(of: pattern, with: replacement)
        }

        let fullRange = NSRange(content.startIndex..<content.endIndex, in: content)
        let matches = regex.matches(in: content, options: [], range: fullRange)
        if matches.isEmpty {
            return replaceFirst ? nil : content
        }

        if replaceFirst {
            // 伪代码 L746-L844：首个匹配展开 $N 后替换。
            let match = matches[0]
            guard let matchRange = Range(match.range, in: content) else { return content }
            let matched = String(content[matchRange])
            let expanded = expandTemplate(replacement, match: match, in: content)
            return content.replacingOccurrences(
                of: matched,
                with: expanded,
                options: .regularExpression,
                range: content.startIndex..<content.endIndex
            )
        }

        // 伪代码 L610-L723：倒序逐匹配替换（避免区间位移）。
        var result = content
        for match in matches.reversed() {
            guard let matchRange = Range(match.range, in: result) else { continue }
            let expanded = expandTemplate(replacement, match: match, in: result)
            result.replaceSubrange(matchRange, with: expanded)
        }
        return result
    }

    /// 伪代码 L661-L707：`$N` 模板展开 —— 逐组 replacingOccurrences。
    private static func expandTemplate(
        _ template: String,
        match: NSTextCheckingResult,
        in content: String
    ) -> String {
        var expanded = template
        for groupIndex in 0..<match.numberOfRanges {
            guard let groupRange = Range(match.range(at: groupIndex), in: content) else {
                continue
            }
            let groupText = String(content[groupRange])
            expanded = expanded.replacingOccurrences(
                of: "$\(groupIndex)",
                with: groupText
            )
        }
        return expanded
    }
}
