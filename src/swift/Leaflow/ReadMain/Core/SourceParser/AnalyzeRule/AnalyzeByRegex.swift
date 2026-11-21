// 原路径: Leaflow/ReadMain/Core/SourceParser/AnalyzeRule/AnalyzeByRegex.swift
// 证据:
//   - PGO: 9 个方法名（getElement/getElements/regex/getString/getStringList/replace/replaceFirst/matches/split）
//   - CovMap: getElement L22-64 @0x100004048；getElements L72-117 @0x100004518
//   - IDA: 0x100004048、0x100004518 的 Hex-Rays 伪代码
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - getElement / getElements: high（逐分支对照伪代码）
//   - 其余 6 个: medium（无独立地址，按 demangled 签名 + NSRegularExpression 标准行为还原）
// 还原: 2026-11-18

import Foundation

/// 书源规则里的正则小工具。
///
/// 规则数组按顺序尝试：当前规则没有匹配时，递归尝试下一条。
/// 匹配结果按 `NSRegularExpression` 的捕获组顺序返回；未命中的组返回空串。
final class AnalyzeByRegex {
    /// 正则选项：伪代码里 `cachedRegex` 的 options 原始值为 8，
    /// 对应 `NSRegularExpression.Options.dotMatchesLineSeparators`。
    private static let options: NSRegularExpression.Options = [.dotMatchesLineSeparators]

    /// 用规则数组中的第 `index` 条正则抓取第一个匹配的全部捕获组。
    ///
    /// - Parameters:
    ///   - string: 待匹配文本
    ///   - rules: 规则数组（按顺序回退）
    ///   - index: 当前规则下标
    /// - Returns: 捕获组数组；规则耗尽或正则非法时返回 nil。
    static func getElement(_ string: String, _ rules: [String], _ index: Int = 0) -> [String]? {
        guard index >= 0, index < rules.count else { return nil }

        let pattern = rules[index]
        guard let regex = AnalyzeRule.cachedRegex(pattern, options: options) else {
            return nil
        }

        let fullRange = NSRange(string.startIndex..<string.endIndex, in: string)
        guard let match = regex.firstMatch(in: string, options: [], range: fullRange) else {
            // 当前规则没命中：尝试下一条。
            return getElement(string, rules, index + 1)
        }

        return capturedGroups(of: match, in: string)
    }

    /// 用规则数组中的第 `index` 条正则抓取全部匹配，每条匹配返回全部捕获组。
    ///
    /// - Returns: 二维捕获组数组；规则耗尽或正则非法时返回空数组。
    static func getElements(_ string: String, _ rules: [String], _ index: Int = 0) -> [[String]] {
        guard index >= 0, index < rules.count else { return [] }

        let pattern = rules[index]
        guard let regex = AnalyzeRule.cachedRegex(pattern, options: options) else {
            return []
        }

        let fullRange = NSRange(string.startIndex..<string.endIndex, in: string)
        let matches = regex.matches(in: string, options: [], range: fullRange)
        guard !matches.isEmpty else {
            // 当前规则没命中：尝试下一条。
            return getElements(string, rules, index + 1)
        }

        return matches.map { capturedGroups(of: $0, in: string) }
    }

    /// 单条正则的私有构造入口（PGO 里是 private 的 `regex(_:)`）。
    /// 说明：主路径实际走 `AnalyzeRule.cachedRegex`；这里保留给单测/回退使用。
    private static func regex(_ pattern: String) -> NSRegularExpression? {
        try? NSRegularExpression(pattern: pattern, options: options)
    }

    /// 取第一个捕获组（等价于 `getElement(...)?[0]`）。
    static func getString(_ string: String, _ rule: String, _ index: Int = 0) -> String? {
        getElement(string, [rule], index)?.first
    }

    /// 取全部捕获组（未命中返回空数组）。
    static func getStringList(_ string: String, _ rule: String, _ index: Int = 0) -> [String] {
        getElement(string, [rule], index) ?? []
    }

    /// 正则全量替换。
    static func replace(_ string: String, _ pattern: String, _ replacement: String) -> String {
        guard let regex = AnalyzeRule.cachedRegex(pattern, options: options) else {
            return string
        }
        let fullRange = NSRange(string.startIndex..<string.endIndex, in: string)
        return regex.stringByReplacingMatches(
            in: string,
            options: [],
            range: fullRange,
            withTemplate: replacement
        )
    }

    /// 正则替换第一个匹配。
    static func replaceFirst(_ string: String, _ pattern: String, _ replacement: String) -> String {
        guard let regex = AnalyzeRule.cachedRegex(pattern, options: options) else {
            return string
        }
        let fullRange = NSRange(string.startIndex..<string.endIndex, in: string)
        guard let match = regex.firstMatch(in: string, options: [], range: fullRange),
              let matchRange = Range(match.range, in: string) else {
            return string
        }
        let replacementText = regex.replacementString(
            for: match,
            in: string,
            offset: 0,
            template: replacement
        )
        return string.replacingCharacters(in: matchRange, with: replacementText)
    }

    /// 判断是否至少有一个匹配。
    static func matches(_ string: String, _ pattern: String) -> Bool {
        guard let regex = AnalyzeRule.cachedRegex(pattern, options: options) else {
            return false
        }
        let fullRange = NSRange(string.startIndex..<string.endIndex, in: string)
        return regex.firstMatch(in: string, options: [], range: fullRange) != nil
    }

    /// 按正则切分（分隔符不保留）。
    static func split(_ string: String, _ pattern: String) -> [String] {
        guard let regex = AnalyzeRule.cachedRegex(pattern, options: options) else {
            return [string]
        }
        let fullRange = NSRange(string.startIndex..<string.endIndex, in: string)
        let matches = regex.matches(in: string, options: [], range: fullRange)
        guard !matches.isEmpty else { return [string] }

        var result: [String] = []
        var cursor = string.startIndex
        for match in matches {
            guard let range = Range(match.range, in: string) else { continue }
            result.append(String(string[cursor..<range.lowerBound]))
            cursor = range.upperBound
        }
        result.append(String(string[cursor...]))
        return result
    }

    // MARK: - 捕获组

    /// 伪代码：遍历 `numberOfRanges`，`rangeAtIndex:` 为 NSNotFound 时追加空串，
    /// 否则取子串。
    private static func capturedGroups(of match: NSTextCheckingResult, in string: String) -> [String] {
        (0..<match.numberOfRanges).map { index in
            let range = match.range(at: index)
            guard range.location != NSNotFound, let swiftRange = Range(range, in: string) else {
                return ""
            }
            return String(string[swiftRange])
        }
    }
}
