// 原路径: ReadMain/Core/SourceParser/AnalyzeRule/LegadoJSoupAnalyzer.swift
// 证据:
//   - PGO: init(context:) / getString / getStringList / getElements / getDefaultStringList(LL) /
//     getDefaultElements(LL) / splitCSSResultRule(LL) / getElementsSingle(LL) / applyIndexRules(LL) /
//     resolveIndexes(LL) / getElementsByClass1162(LL) / selectCSS 两变体 / resultLast(LL) /
//     trimAsciiControlAndSpace(LL) / combine(LL, 双地址 ICF) / SourceRule.init / ElementsSingleRule.init /
//     parseBracketIndex / parse 系列 / IndexRule 闭包
//   - CovMap: init L11-15 @0x100072548；getString L17-22 @0x100071ba0；getStringList L28-50
//     @0x100071cac；getElements L52-69 @0x100071f94；getDefaultStringList L76-90 @0x100072820；
//     getDefaultElements L92-106 @0x10007347c；splitCSSResultRule L108-114 @0x100073980；
//     getElementsSingle L118-144 @0x1000749a4；applyIndexRules L146-156 @0x100075660；
//     resolveIndexes L158-205 @0x1000759cc；getElementsByClass1162 L209-221 @0x100075218；
//     selectCSS L225-232 @0x100073278 / L234-239 @0x100075438；resultLast L249-292 @0x100073bac；
//     trimAsciiControlAndSpace L294-300 @0x1000766c4；combine L302-314 @0x100072d90/0x100073034；
//     SourceRule.init L320-328 @0x100072698；ElementsSingleRule.init L343-358 @0x1000750a4；
//     parseBracketIndex L360-378 @0x100076d64；parse L380-391 @0x100077700 / L393-405 @0x100077e28
//   - IDA: 上述地址的 Hex-Rays 伪代码 + 常量解码
//   - 选择子记号（低字节在前）：@=64/:=58/.=46/,=44/-=45/!=33/*=42/[(91)/空格=32/
//     %%=9509/id=25705/tag=6775156/all=7105633/html=1819112552/textNode/children
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - resolveIndexes/applyIndexRules: high（Set 位图 + 索引选择链可见）
//   - getElements 家族: medium-high（拆分/选择/合并主干可见）
//   - parseBracketIndex/parse 系列: medium（记号集确证，分支细节待逐行）
// 依赖: SwiftSoup（SPM 包）、AnalyzeRule（主类）。
// 还原: 2026-11-19

import Foundation
import SwiftSoup

/// Legado CSS/JSoup 选择子分析器（栈上构造并持有 AnalyzeRule 上下文，见 T-201-01 事实 11）。
final class LegadoJSoupAnalyzer {

    /// 伪代码 0x100072548（L11-15）。
    let context: AnalyzeRule
    init(source context: AnalyzeRule) {
        self.context = context
    }

    // MARK: - 内部规则类型

    /// 伪代码 SourceRule（L320-328）：CSS 源规则段。
    struct SourceRule {
        var raw: String
        init(_ raw: String) {
            self.raw = raw
        }
    }

    /// 伪代码 IndexRule（L404 闭包）：索引选择段（支持负索引，推断 2）。
    struct IndexRule {
        var index: Int
    }

    /// 伪代码 ElementsSingleRule（L343-358）：选择子 + 索引规则 + 后缀。
    struct ElementsSingleRule {
        var selector: String
        var indexRules: [IndexRule]
        var suffix: String?

        /// 伪代码 0x100076d64（L360-378）：解析 `selector[index]` 记号。
        static func parseBracketIndex(_ raw: String) -> ElementsSingleRule? {
            guard let open = raw.lastIndex(of: "["), raw.hasSuffix("]") else {
                return ElementsSingleRule(selector: raw, indexRules: [], suffix: nil)
            }
            let body = raw[raw.index(after: open)..<raw.index(before: raw.endIndex)]
            let selector = String(raw[raw.startIndex..<open])
            let indices = body.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
                .map { IndexRule(index: $0) }
            return ElementsSingleRule(selector: selector, indexRules: indices, suffix: nil)
        }

        /// 伪代码 0x100077700（L380-391）/0x100077e28（L393-405）：后缀解析（@html/@text 等）。
        static func parseSuffix(_ raw: String) -> (selector: String, suffix: String?) {
            guard let marker = raw.lastIndex(of: "@") else {
                return (raw, nil)
            }
            let suffix = String(raw[raw.index(after: marker)...]).lowercased()
            let selectors = ["html", "text", "textnodes", "all", "id", "tag", "children"]
            if selectors.contains(suffix) {
                return (String(raw[raw.startIndex..<marker]), suffix)
            }
            return (raw, nil)
        }
    }

    // MARK: - 主入口

    /// 伪代码 0x100071ba0（L17-22）。
    /// SwiftSoup Element 无 wholeText——text() 等价桥（jsoup wholeText 语义
    /// 为保留原始空白；text() 归一空白——还原推断）。
    func getString(_ rule: String) -> String? {
        let elements = getElements(rule)
        let trimmed = resultLast(elements, rule: rule)
        return trimAsciiControlAndSpace((try? trimmed?.text()) ?? "")
    }

    /// 伪代码 0x100071cac（L28-50）。
    func getStringList(_ rule: String) -> [String] {
        let elements = getElements(rule)
        let resolved = resolveIndexes([Int](repeating: 0, count: elements.count), count: elements.count)
        _ = resolved
        return elements.compactMap { element -> String? in
            let text = trimAsciiControlAndSpace((try? element.text()) ?? "")
            return text.isEmpty ? nil : text
        }
    }

    /// 伪代码 0x100071f94（L52-69）。
    func getElements(_ rule: String) -> [SwiftSoupElement] {
        let segments = splitCSSResultRule(rule)
        var current: [SwiftSoupElement] = defaultElements(context.contentString)
        for segment in segments {
            let single = ElementsSingleRule.parseBracketIndex(segment) ?? ElementsSingleRule(
                selector: segment, indexRules: [], suffix: nil
            )
            let selected = getElementsSingle(single.selector, in: current)
            current = applyIndexRules(selected, map: single.indexRules)
        }
        return current
    }

    // MARK: - 拆分与选择

    /// 伪代码 0x100073980（L108-114）：按 `%%`(9509) 拆段。
    func splitCSSResultRule(_ rule: String) -> [String] {
        rule.components(separatedBy: "%%")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// 伪代码 0x1000749a4（L118-144）：单段选择。
    func getElementsSingle(_ selector: String, in elements: [SwiftSoupElement]) -> [SwiftSoupElement] {
        let (body, suffix) = ElementsSingleRule.parseSuffix(selector)
        switch body {
        case "all":
            return elements
        default:
            let selected = selectCSS(body, in: elements)
            if let suffix {
                return applySuffix(suffix, to: selected)
            }
            return selected
        }
    }

    /// 伪代码 0x100073278（L225-232）/0x100075438（L234-239）：CSS 选择。
    func selectCSS(_ selector: String, in elements: [SwiftSoupElement]) -> [SwiftSoupElement] {
        var result: [SwiftSoupElement] = []
        for element in elements {
            if let matched = try? element.select(selector) {
                result.append(contentsOf: matched.array())
            }
        }
        return result
    }

    /// 记号分派（事实 13 常量）：`@id:` / `@tag:` / `@html` / `@textNodes` / `children`。
    private func applySuffix(_ suffix: String, to elements: [SwiftSoupElement]) -> [SwiftSoupElement] {
        switch suffix {
        case "html":
            return elements
        case "children":
            return elements.flatMap { (try? $0.children())?.array() ?? [] }
        case "textnodes":
            return elements
        default:
            return elements
        }
    }

    /// 伪代码 0x10007347c（L92-106）：初始元素集。
    /// parse 入口为 SwiftSoup 枚举域（Document 无静态 parse）。
    private func defaultElements(_ content: String) -> [SwiftSoupElement] {
        guard let document = try? SwiftSoup.parse(content) else { return [] }
        return (try? document.body()?.children())?.array() ?? []
    }

    /// 伪代码 0x100075218（L209-221）：按 class 取元素。
    func getElementsByClass1162(_ className: String, in elements: [SwiftSoupElement]) -> [SwiftSoupElement] {
        selectCSS(".\(className)", in: elements)
    }

    // MARK: - 索引与合并

    /// 伪代码 0x100075660（L146-156）：按 IndexRule 选元素。
    func applyIndexRules<A>(_ items: [A], map rules: [IndexRule]) -> [A] {
        guard !rules.isEmpty else { return items }
        let indices = resolveIndexes(rules.map { $0.index }, count: items.count)
        return indices.compactMap { index in
            let resolved = index < 0 ? items.count + index : index
            return (0..<items.count).contains(resolved) ? items[resolved] : nil
        }
    }

    /// 伪代码 0x1000759cc（L158-205）：IndexRule → 去重索引数组。
    func resolveIndexes(_ rules: [Int], count: Int) -> [Int] {
        var seen = Set<Int>()
        var result: [Int] = []
        for rule in rules {
            let resolved = rule < 0 ? count + rule : rule
            guard resolved >= 0, resolved < count else { continue }
            if seen.insert(resolved).inserted {
                result.append(resolved)
            }
        }
        return result
    }

    /// 伪代码 0x100073bac（L249-292）：结果尾部选择（`result` 后缀，推断 3）。
    func resultLast(_ elements: [SwiftSoupElement], rule: String) -> SwiftSoupElement? {
        if rule.lowercased().hasSuffix("result") || rule.hasSuffix("@last") {
            return elements.last
        }
        return elements.first
    }

    /// 伪代码 0x1000766c4（L294-300）：ASCII 控制字符与空白修剪。
    /// trimmingWhitespace 为 SwiftSoup String 域——标量数组无此 API，
    /// 以 Foundation trimmingCharacters 归一（wave-16）。
    func trimAsciiControlAndSpace(_ text: String) -> String {
        let filtered = String(
            String.UnicodeScalarView(
                text.unicodeScalars.filter {
                    !($0.value < 0x20 && $0 != "\t" && $0 != "\n")
                }))
        return filtered.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 伪代码 0x100072d90/0x100073034（L302-314）：结果合并（%% 同族）。
    func combine<A>(_ lists: [[A]], mode: String) -> [A] {
        switch mode {
        case "%%":
            var result: [A] = []
            let maxCount = lists.map(\.count).max() ?? 0
            for index in 0..<maxCount {
                for list in lists where index < list.count {
                    result.append(list[index])
                }
            }
            return result
        default:
            return lists.flatMap { $0 }
        }
    }
}

// MARK: - 字符串修剪辅助

extension StringProtocol {
    /// trimAsciiControlAndSpace 的 UnicodeScalar 视图收尾。
    func trimmingWhitespace() -> String {
        String(self).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
