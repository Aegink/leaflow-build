// 原路径: ReadMain/Core/SourceParser/SoupXPathProjection.swift
// 证据:
//   - PGO: init(document:…) (0x100168090 L18-22) / build(document:isXML:) (0x100167504 L24-77) / scopedXPath (0x10016743c L97-103) / selfInclusiveLeadingStep (0x10016871c) / isNameTest (0x100168a7c) / parseKanna (0x100168188) / kannaPath(of:) (0x1001683bc) / SoupDOMContext.xpathProjection (0x100167328 L174-178)
//   - CovMap: 上述 L 区段
//   - IDA: 上述地址
//   - SwiftSoup 文档 → Kanna XML 投影（T-206 CSS/XPath 混合查询）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: medium-high（投影链确证；build 细节见读后记仍不清楚 2）
// 还原: 2026-11-19


import Foundation
import SwiftSoup
import Kanna

/// SwiftSoup → Kanna 的 XPath 投影。
final class SoupXPathProjection {

    let document: KannaXMLDocument

    init(document: KannaXMLDocument) {
        self.document = document
    }

    /// 伪代码 0x100167504（L24-77）：从 SwiftSoup 文档构建投影。
    static func build(document: SwiftSoupDocument, isXML: Bool) -> SoupXPathProjection {
        let html = (try? document.html()) ?? ""
        // Kanna 工厂域桥（XMLDocument 为协议——Kanna.XML(xml:encoding:)
        // throws 工厂，wave-76；"<html/>" 兜底恒可解析）。
        let fallbackDocument = try! Kanna.XML(xml: "<html/>", encoding: .utf8)
        return SoupXPathProjection(
            document: (try? Kanna.XML(xml: html, encoding: .utf8))
                ?? fallbackDocument)
    }

    /// XPath 求值桥（T-1401-09 xpathResults 0x10010caf8 消费域；Kanna
    /// xpath 求值 → 元素 HTML 串数组）。
    func evaluate(_ xpath: String) -> [String] {
        let nodes = document.xpath(xpath)
        return nodes.map { node in
            node.innerHTML ?? node.text ?? ""
        }
    }

    /// 伪代码 0x10016743c（L97-103）：当前节点作用域化 XPath。
    static func scopedXPath(_ xpath: String) -> String {
        if xpath.hasPrefix("/") {
            return "." + xpath
        }
        return "./" + xpath
    }

    /// 伪代码 0x10016871c（L108-121）。
    static func selfInclusiveLeadingStep(_ xpath: String) -> String {
        guard let first = xpath.first, first == "/" else { return xpath }
        return "/" + xpath
    }

    /// 伪代码 0x100168a7c（L123-127）：名称测试段判定。
    static func isNameTest(_ segment: Substring) -> Bool {
        guard let first = segment.first else { return false }
        return first.isLetter || first == "_" || first == "*"
    }

    /// 伪代码 0x100168188（L136-143）/0x1001683bc（L145-159）。
    static func parseKanna(_ node: KannaXMLElement) -> String {
        kannaPath(of: node)
    }

    static func kannaPath(of node: KannaXMLElement) -> String {
        // 节点路径桥（Kanna 5.3 xpath 为方法域非属性——祖先序拼接，
        // 真机核清项）。
        var segments: [String] = []
        var cursor: XMLNode? = node
        while let current = cursor {
            if let element = current as? XMLElement {
                segments.insert(element.name ?? "*", at: 0)
            }
            cursor = current.parent
        }
        return "/" + segments.joined(separator: "/")
    }
}

/// 伪代码 SoupDOMContext（L174-178）。
extension SoupDOMContext {
    func xpathProjection() -> SoupXPathProjection? {
        if let cached = cachedProjection { return cached }
        guard let document else { return nil }
        let built = SoupXPathProjection.build(document: document, isXML: false)
        cachedProjection = built
        return built
    }
}

/// DOM 上下文（与 JsoupDomStore 配对）。
final class SoupDOMContext {
    let document: SwiftSoupDocument?
    let handle: String
    /// XPath 投影缓存（invalidateXPathProjection 清空域；T-1401-09）。
    private var cachedProjection: SoupXPathProjection?

    init(handle: String, document: SwiftSoupDocument?) {
        self.handle = handle
        self.document = document
    }
}

extension SoupDOMContext {

    /// 伪代码 0x1001673d4（L180-182）：XPath 投影失效（缓存清空域）。
    func invalidateXPathProjection() {
        cachedProjection = nil
    }
}
