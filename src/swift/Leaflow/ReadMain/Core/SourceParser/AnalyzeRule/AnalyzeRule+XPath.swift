// 原路径: ReadMain/Core/SourceParser/AnalyzeRule/AnalyzeRule+XPath.swift
// 证据:
//   - PGO: isValidXPath / maskQuotedXPathLiterals(LL) / getXPathDocument(LL) /
//     preparedXPathSource(LL) / xpathObjects(LL) / xpathObjectIsEmpty(LL) /
//     xpathObjectStrings(LL) / executeXPathRule / executeXPathSingleRuleForList(LL) /
//     executeXPathSingleRuleForNodes(LL) / executeXPathRuleForNodes /
//     executeXPathRuleForList / xpathNodeString(LL) / LibxmlStderrSuppressor 闭包
//   - CovMap: suppressor L22-33/L39-50 @0x10006e2b0/0x10006e360；isValidXPath L58-158
//     @0x10006d360；maskQuotedXPathLiterals L160-178 @0x10006e408；getXPathDocument L191-207
//     @0x10006e658；preparedXPathSource L209-219 @0x10006e8c8；xpathObjects L221-240 @0x10006eb14；
//     xpathObjectIsEmpty L242-255 @0x10006efc0；xpathObjectStrings L257-273 @0x10006f0a4；
//     executeXPathRule L276-279 @0x10006f5d4；executeXPathSingleRuleForList L281-298 @0x10006fee8；
//     executeXPathSingleRuleForNodes L300-313 @0x100070230；executeXPathRuleForNodes L315-347
//     @0x10006cb34；executeXPathRuleForList L350-383 @0x10006f6b8；xpathNodeString L385-398
//     @0x10006f310
//   - IDA: 上述地址的 Hex-Rays 伪代码 + 字符串常量表
//   - 校验正则：^//\s*\| / \|\s*//\s*$ / \|\s*\| / ^//\s*\d+\s*$ / ^[/\d\s]+$
//   - 常量："/dev/null"、innerhtml/textnode、</table>/</tbody>、@*、@、@js:、"@"=64
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - maskQuotedXPathLiterals / xpathNodeString: medium-high（常量与关键字确证）
//   - isValidXPath: medium-high（五条校验正则确证；通过/拒绝方向见读后记“仍不清楚”2）
//   - executeXPath* 家族: medium-high（链式拆分/求值/归一主干可见）
// 依赖: Kanna（SPM 包，只调用）、AnalyzeRule 主类 currentContent。
// 还原: 2026-11-18

import Foundation
import Kanna

extension AnalyzeRule {

    // MARK: - stderr 抑制

    /// 伪代码 0x10006e2b0/0x10006e360（L22-50）：libxml2 解析期间 stderr → /dev/null。
    static func withLibxmlStderrSuppressed<T>(_ body: () throws -> T) rethrows -> T {
        let original = dup(2)
        let devnull = open("/dev/null", O_WRONLY)
        if devnull >= 0 {
            dup2(devnull, 2)
        }
        defer {
            if devnull >= 0 {
                close(devnull)
                dup2(original, 2)
                close(original)
            }
        }
        return try body()
    }

    // MARK: - 校验

    /// 伪代码 0x10006e408（L160-178）：掩码引号字面量（'...'/"..."，含 \ 转义）。
    static func maskQuotedXPathLiterals(_ xpath: String) -> String {
        var result = ""
        var quote: Character?
        var index = xpath.startIndex
        while index < xpath.endIndex {
            let character = xpath[index]
            if let current = quote {
                if character == "\\" {
                    // 转义字符连同下一个字符一起掩码。
                    result.append("\\")
                    if let next = xpath.index(index, offsetBy: 1, limitedBy: xpath.endIndex) {
                        result.append("n")
                        index = xpath.index(after: next)
                        continue
                    }
                } else if character == current {
                    quote = nil
                    result.append("n")
                    index = xpath.index(after: index)
                    continue
                } else {
                    result.append("n")
                    index = xpath.index(after: index)
                    continue
                }
            } else if character == "'" || character == "\"" {
                quote = character
                result.append("n")
                index = xpath.index(after: index)
                continue
            } else {
                result.append(character)
            }
            index = xpath.index(after: index)
        }
        return result
    }

    /// 伪代码 0x10006d360（L58-158）：XPath 合法性校验。
    /// 五条校验正则（事实 21）作用于掩码后文本；方向见读后记“仍不清楚”2。
    static func isValidXPath(_ xpath: String) -> Bool {
        let masked = maskQuotedXPathLiterals(xpath)
        let invalidPatterns = [
            "^//\\s*\\|",        // //| 开头
            "\\|\\s*//\\s*$",    // |// 结尾
            "\\|\\s*\\|",        // 连续 ||
            "^//\\s*\\d+\\s*$",  // //纯数字
            "^[/\\d\\s]+$",      // 全部为 / 数字 空白
        ]
        for pattern in invalidPatterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(masked.startIndex..<masked.endIndex, in: masked)
            if regex.firstMatch(in: masked, options: [], range: range) != nil {
                return false
            }
        }
        return true
    }

    // MARK: - 文档与求值

    /// 伪代码 0x10006e8c8（L209-219）：源预处理（表格片段补全闭合标签）。
    func preparedXPathSource(_ source: String) -> String {
        var text = source
        if text.contains("<table") && !text.contains("</table>") {
            text += "</table>"
        }
        if text.contains("<tbody") && !text.contains("</tbody>") {
            text += "</tbody>"
        }
        return text
    }

    /// 伪代码 0x10006e658（L191-207）：Kanna 文档构造（stderr 抑制）。
    /// 构造走 Kanna.XML 工厂（5.3 域：XMLDocument 为协议，wave-16）。
    func getXPathDocument(from source: String) -> KannaXMLDocument? {
        withLibxmlStderrSuppressed {
            let prepared = preparedXPathSource(source)
            return try Kanna.XML(xml: prepared, encoding: .utf8)
        }
    }

    /// 伪代码 0x10006eb14（L221-240）：XPath 求值。
    func xpathObjects(_ xpath: String, document: KannaXMLDocument?) -> KannaXPathObject? {
        guard let document else { return nil }
        return withLibxmlStderrSuppressed {
            try? document.xpath(xpath)
        }
    }

    /// 伪代码 0x10006efc0（L242-255）：结果空判定。
    static func xpathObjectIsEmpty(_ object: KannaXPathObject?) -> Bool {
        guard let object else { return true }
        return object.count == 0
    }

    /// 伪代码 0x10006f0a4（L257-273）：结果取串。
    /// 节点迭代经 leaflowElements 桥（XPathObject 枚举域，wave-16）。
    static func xpathObjectStrings(_ object: KannaXPathObject?) -> [String] {
        guard let object else { return [] }
        return object.leaflowElements.compactMap { node -> String? in
            let text = node.text ?? ""
            return text.isEmpty ? nil : text
        }
    }

    // MARK: - 规则执行

    /// 伪代码 0x10006f5d4（L276-279）：XPath 单值执行。
    func executeXPathRule(_ rule: String) -> String? {
        let document = getXPathDocument(from: contentString)
        let objects = xpathObjects(rule, document: document)
        return xpathObjectStrings(objects).first
    }

    /// 伪代码 0x10006fee8（L281-298）：XPath 单规则列表执行。
    func executeXPathSingleRuleForList(_ rule: String) -> [String] {
        let document = getXPathDocument(from: contentString)
        let objects = xpathObjects(rule, document: document)
        return xpathObjectStrings(objects)
    }

    /// 伪代码 0x100070230（L300-313）：XPath 单规则节点执行。
    /// 节点迭代经 leaflowElements 桥（XPathObject 枚举域，wave-16）。
    func executeXPathSingleRuleForNodes(_ rule: String) -> [KannaXMLElement] {
        let document = getXPathDocument(from: contentString)
        guard let objects = xpathObjects(rule, document: document) else { return [] }
        return objects.leaflowElements
    }

    /// 伪代码 0x10006cb34（L315-347）：链式节点提取 —— `|` 分段逐级求值。
    func executeXPathRuleForNodes(_ rule: String) -> [KannaXMLElement]? {
        let segments = rule.split(separator: "|").map(String.init)
        guard !segments.isEmpty else { return nil }
        var nodes: [KannaXMLElement] = executeXPathSingleRuleForNodes(segments[0])
        for segment in segments.dropFirst() {
            if nodes.isEmpty {
                break
            }
            // 后续段在已提取节点的字符串形态上重新解析。
            // innerHTML 为协议域（String? 非 throwing，wave-16）。
            let joined = nodes.compactMap { $0.innerHTML ?? "" }
                .joined(separator: "\n")
            nodes = executeXPathSingleRuleForNodes(segment, sourceOverride: joined)
        }
        return nodes.isEmpty ? nil : nodes
    }

    /// 伪代码 0x10006f6b8（L350-383）：链式字符串列表提取。
    func executeXPathRuleForList(_ rule: String) -> [String]? {
        let document = getXPathDocument(from: contentString)
        let segments = rule.split(separator: "|").map(String.init)
        var result: [String] = []
        for segment in segments {
            guard let objects = xpathObjects(segment, document: document) else { continue }
            result.append(contentsOf: xpathObjectStrings(objects))
        }
        return result.isEmpty ? nil : result
    }

    /// 伪代码 0x10006f310（L385-398）：节点取串。
    /// `@html`/innerhtml 关键字 → innerHTML；否则 text（textnode）。
    /// innerHTML 为协议域（String? 非 throwing，wave-16）。
    func xpathNodeString(_ node: KannaXMLElement) -> String? {
        let html = node.innerHTML ?? ""
        if html.isEmpty {
            let text = node.text ?? ""
            return text.isEmpty ? nil : text
        }
        return html
    }

    /// 源覆盖变体（链式段落用）。
    private func executeXPathSingleRuleForNodes(
        _ rule: String,
        sourceOverride: String
    ) -> [KannaXMLElement] {
        let document = getXPathDocument(from: sourceOverride)
        guard let objects = xpathObjects(rule, document: document) else { return [] }
        return objects.leaflowElements
    }
}
