// 原路径: ReadMain/Core/SourceParser/AnalyzeRule/LegadoRuleAnalyzer.swift
// 证据:
//   - PGO: trim / splitRule([String]) / innerRule(_:suffix:transform:) / firstTopLevelDelimiter(LL) /
//     isTopLevel(LL) / findBalancedEnd(LL) 及 implicit closure
//   - CovMap: trim L23-35 @0x100079728；splitRule L41-65 @0x100079898；innerRule L67-96
//     @0x100079460；firstTopLevelDelimiter L98-107 @0x100079b84；isTopLevel L114-157 @0x10007a440；
//     findBalancedEnd L163-209 @0x100079d5c
//   - IDA: 上述地址的 Hex-Rays 伪代码
//   - 状态机常量：`'`=39/`"`=34/`` ` ``(96)/`\`=92/`(`=40/`)`=41/`[`=91/`]`=93/`{`=123/`}`=125/`@`=64
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - isTopLevel / findBalancedEnd: high（引号/转义/括号栈逐条对应）
//   - splitRule / firstTopLevelDelimiter / innerRule: high
//   - trim: high（@ 与空白跳过可见；空白判定复用 parseBracketIndex 闭包）
// 还原: 2026-11-19

import Foundation

/// Legado 规则字符串分析器：引号/括号感知的顶层扫描器。
/// 分析器持有一条规则串与扫描游标（trim 推进、splitRule 分段）。
final class LegadoRuleAnalyzer {

    /// 当前规则串与游标（伪代码 v0[2]/v0[3] 与 v0[5..8] 的对应物）。
    private(set) var rule: String
    private var startIndex: String.Index
    private var cursor: String.Index
    private var currentDelimiter: String?

    /// 静态回传：最近一次 splitRule 命中的组合符（readJsonPath/getElements 使用）。
    static var lastCombiner: String = "&&"

    init(_ rule: String) {
        self.rule = rule
        self.startIndex = rule.startIndex
        self.cursor = rule.startIndex
    }

    // MARK: - 静态便捷入口

    /// innerRule 的静态包装（组合符 + 内嵌规则双用途）。
    /// - markers 模式：按 &&/||/%% 顶层拆段（T-201-01/02 调用形态）。
    /// - startMark 模式：内嵌规则展开（readJsonPath 的 `{$.` 形态）。
    static func innerRule(_ rule: String, markers: [String]) -> [String] {
        let analyzer = LegadoRuleAnalyzer(rule)
        return analyzer.splitRule(markers)
    }

    static func innerRule(
        _ rule: String,
        startMark: String,
        transform: (String) -> String?
    ) -> String? {
        let endToken = startMark == "{$." ? "}" : "}}"
        var result = ""
        var found = false
        var index = rule.startIndex
        while index < rule.endIndex {
            let rest = rule[index...]
            guard let openRange = rest.range(of: startMark) else {
                result += rest
                break
            }
            let openIndex = index
            let contentStart = openRange.upperBound
            guard let endIndex = findBalancedEnd(
                from: contentStart, in: rule, endToken: endToken
            ) else {
                result += String(rule[openIndex...])
                break
            }
            let inner = String(rule[contentStart..<endIndex])
            if let transformed = transform(inner) {
                result += transformed
                found = true
            } else {
                result += String(rule[openIndex..<rule.index(after: endIndex)])
            }
            index = rule.index(endIndex, offsetBy: endToken.count, limitedBy: rule.endIndex)
                ?? rule.endIndex
        }
        return found ? result : nil
    }

    /// 伪代码 0x100079d5c（L163-209）：从索引扫描平衡端点。
    static func findBalancedEnd(
        from start: String.Index,
        in text: String,
        endToken: String
    ) -> String.Index? {
        var quote: Character?
        var escaped = false
        var stack: [Character] = []
        var index = start
        while index < text.endIndex {
            let character = text[index]
            if escaped {
                escaped = false
                index = text.index(after: index)
                continue
            }
            if let current = quote {
                if character == "\\" {
                    escaped = true
                } else if character == current {
                    quote = nil
                }
                index = text.index(after: index)
                continue
            }
            if character == "'" || character == "\"" || character == "`" {
                quote = character
                index = text.index(after: index)
                continue
            }
            if character == "\\" {
                escaped = true
                index = text.index(after: index)
                continue
            }
            if character == "(" {
                stack.append(")")
            } else if character == "[" {
                stack.append("]")
            } else if character == "{" {
                stack.append("}")
            } else if !stack.isEmpty, character == stack.last! {
                stack.removeLast()
            } else if stack.isEmpty, text[index...].hasPrefix(endToken) {
                return index
            }
            index = text.index(after: index)
        }
        return nil
    }

    // MARK: - 实例扫描

    /// 伪代码 0x100079728（L23-35）：起点跳过 `@` 与空白。
    func trim() {
        while cursor < rule.endIndex {
            let character = rule[cursor]
            if character == "@" || character.isWhitespace || character.isNewline {
                cursor = rule.index(after: cursor)
            } else {
                break
            }
        }
        startIndex = cursor
    }

    /// 伪代码 0x100079898（L41-65）：按顶层分隔符拆分。
    func splitRule(_ markers: [String]) -> [String] {
        let remainder = String(rule[cursor...])
        guard !remainder.isEmpty else { return [] }

        guard let delimiter = Self.firstTopLevelDelimiter(remainder, markers: markers) else {
            currentDelimiter = nil
            Self.lastCombiner = "&&"
            return [remainder]
        }
        currentDelimiter = delimiter
        Self.lastCombiner = delimiter

        var segments: [String] = []
        var index = remainder.startIndex
        var segmentStart = remainder.startIndex
        while index < remainder.endIndex {
            if remainder[index...].hasPrefix(delimiter) {
                segments.append(String(remainder[segmentStart..<index]))
                index = remainder.index(index, offsetBy: delimiter.count, limitedBy: remainder.endIndex)
                    ?? remainder.endIndex
                segmentStart = index
                continue
            }
            index = remainder.index(after: index)
        }
        segments.append(String(remainder[segmentStart...]))
        return segments
    }

    /// 伪代码 0x100079b84（L98-107）：首个顶层分隔符。
    static func firstTopLevelDelimiter(_ text: String, markers: [String]) -> String? {
        var index = text.startIndex
        while index < text.endIndex {
            if isTopLevel(index, in: text) {
                for marker in markers where text[index...].hasPrefix(marker) {
                    return marker
                }
            }
            index = text.index(after: index)
        }
        return nil
    }

    /// 伪代码 0x10007a440（L114-157）：索引处是否顶层（引号/括号栈状态机）。
    static func isTopLevel(_ position: String.Index, in text: String) -> Bool {
        var quote: Character?
        var escaped = false
        var stack: [Character] = []
        var index = text.startIndex
        while index < text.endIndex {
            let character = text[index]
            if escaped {
                escaped = false
                index = text.index(after: index)
                continue
            }
            if let current = quote {
                if character == "\\" {
                    escaped = true
                } else if character == current {
                    quote = nil
                }
                index = text.index(after: index)
                continue
            }
            if character == "'" || character == "\"" || character == "`" {
                quote = character
                index = text.index(after: index)
                continue
            }
            if character == "\\" {
                escaped = true
                index = text.index(after: index)
                continue
            }
            if character == "(" {
                stack.append(")")
            } else if character == "[" {
                stack.append("]")
            } else if character == "{" {
                stack.append("}")
            } else if !stack.isEmpty, character == stack.last! {
                stack.removeLast()
            }
            if index == position {
                return quote == nil && stack.isEmpty
            }
            index = text.index(after: index)
        }
        return index == position && quote == nil && stack.isEmpty
    }
}
