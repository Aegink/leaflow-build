// 原路径: ReadMain/Core/SourceParser/JsoupDomStore.swift
// 证据:
//   - PGO: DocumentRecord.init/register/invalidateXPathProjection/documentText/documentHTML/documentTitle/rootHandle 等 39 函数
//   - CovMap: DocumentRecord 初始化 L12-13 @0x10010ba94/0x10010b9a4；register L23-31 @0x10010bc1c；invalidateXPathProjection L33-35 @0x10010bc90；documentText L62-65 @0x10010c218；documentHTML L67-70 @0x10010c2f8；documentTitle L72-75 @0x10010c3d0；rootHandle L77-81 @0x10010c4a8
//   - IDA: 上述地址
//   - handle 键 DOM 仓库（T-204-04 JsResourceLoader 的存储后端）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: medium-high（注册/失效/取值链确证）
// 还原: 2026-11-19


import Foundation
import SwiftSoup

/// Jsoup DOM 句柄仓库（T-204-04 _jsoup* 桥的存储后端）。
final class JsoupDomStore {

    /// 伪代码 DocumentRecord（L12-35）。
    final class DocumentRecord {
        let document: SwiftSoupDocument
        private var projection: Any?
        private let lock = NSLock()

        init(document: SwiftSoupDocument) {
            self.document = document
        }

        /// 伪代码 0x10010bc1c（L23-31）：注册到仓库。
        @discardableResult
        func register(in store: JsoupDomStore) -> String {
            store.register(self)
        }

        /// 伪代码 0x10010bc90（L33-35）：文档变更后使 XPath 投影失效。
        func invalidateXPathProjection() {
            lock.lock()
            defer { lock.unlock() }
            projection = nil
        }
    }

    private var records: [String: DocumentRecord] = [:]
    private let lock = NSLock()
    private var counter = 0

    /// 伪代码 0x10010bc1c。
    @discardableResult
    func register(_ record: DocumentRecord) -> String {
        lock.lock()
        defer { lock.unlock() }
        counter += 1
        let handle = "doc\(counter)"
        records[handle] = record
        return handle
    }

    func record(for handle: String) -> DocumentRecord? {
        lock.lock()
        defer { lock.unlock() }
        return records[handle]
    }

    /// 伪代码 0x10010c218（L62-65）。
    func documentText(_ handle: String) -> String {
        guard let record = record(for: handle) else { return "" }
        return record.document.body()?.text() ?? ""
    }

    /// 伪代码 0x10010c2f8（L67-70）。
    func documentHTML(_ handle: String) -> String {
        guard let record = record(for: handle) else { return "" }
        return (try? record.document.html()) ?? ""
    }

    /// 伪代码 0x10010c3d0（L72-75）。
    func documentTitle(_ handle: String) -> String {
        guard let record = record(for: handle) else { return "" }
        return (try? record.document.title()) ?? ""
    }

    /// 伪代码 0x10010c4a8（L77-81）。
    func rootHandle(_ handle: String) -> String {
        handle
    }

    static let shared = JsoupDomStore()
}

// MARK: - T-1401-09 逐域补齐（节点句柄域）

extension JsoupDomStore {

    /// 节点句柄表（nodeID → Element）。
    private var nodes: [String: SwiftSoupElement] = [:]

    /// 节点登记（元素句柄域；handle 前缀 "n" + 计数）。
    func registerNode(_ element: SwiftSoupElement, documentID: String) -> String {
        lock.lock()
        defer { lock.unlock() }
        counter += 1
        let handle = "\(documentID)/n\(counter)"
        nodes[handle] = element
        return handle
    }

    /// 节点解析（句柄 → 元素；失效句柄 → nil）。
    private func node(for handle: String) -> SwiftSoupElement? {
        lock.lock()
        defer { lock.unlock() }
        return nodes[handle]
    }

    /// 伪代码 0x10010c660（L83-86）：body 句柄——文档根 → body 元素句柄域。
    func bodyHandle(_ documentID: String) -> String {
        guard let record = record(for: documentID),
            let body = try? record.document.body() else { return "" }
        return registerNode(body, documentID: documentID)
    }

    /// 伪代码 0x10010c710（L93-102）：CSS 选择——documentID/nodeID/selector
    /// 三参域确证 → 命中元素句柄数组。
    func select(
        documentID: String, nodeID: String, selector: String
    ) -> [String] {
        let elements: [SwiftSoupElement]
        if let element = node(for: nodeID) {
            elements = (try? element.select(selector)) ?? []
        } else if let record = record(for: documentID) {
            elements = (try? record.document.select(selector)) ?? []
        } else {
            elements = []
        }
        return elements.map { registerNode($0, documentID: documentID) }
    }

    /// 伪代码 0x10010caf8（L104-135）：XPath 投影结果——投影缓存域。
    func xpathResults(
        documentID: String, nodeID: String, xpath: String
    ) -> [String] {
        guard let record = record(for: documentID) else { return [] }
        let context = SoupDOMContext(handle: documentID, document: record.document)
        guard let projection = context.cachedXPathProjection() else { return [] }
        let scoped = SoupXPathProjection.scopedXPath(xpath)
        return projection.evaluate(scoped)
    }

    /// 伪代码 0x10010d3ec（L137-140）：子元素句柄集。
    func children(of nodeID: String) -> [String] {
        guard let element = node(for: nodeID) else { return [] }
        let kids = (try? element.children()) ?? []
        return kids.map { registerNode($0, documentID: nodeID) }
    }

    /// 伪代码 0x10010d4a4（L147-153）：下一兄弟句柄。
    func nextSibling(of nodeID: String) -> String? {
        guard let element = node(for: nodeID) else { return nil }
        return (try? element.nextElementSibling()).flatMap {
            $0.map { registerNode($0, documentID: nodeID) }
        } ?? nil
    }

    /// 伪代码 0x10010d57c（L155-161）：上一兄弟句柄。
    func previousSibling(of nodeID: String) -> String? {
        guard let element = node(for: nodeID) else { return nil }
        return (try? element.previousElementSibling()).flatMap {
            $0.map { registerNode($0, documentID: nodeID) }
        } ?? nil
    }

    /// 伪代码 0x10010d654（L163-166）：合并文本。
    func text(of nodeID: String) -> String {
        guard let element = node(for: nodeID) else { return "" }
        return (try? element.text()) ?? ""
    }

    /// 伪代码 0x10010d7e0（L168-171）：自有文本（不含子节点域）。
    func ownText(of nodeID: String) -> String {
        guard let element = node(for: nodeID) else { return "" }
        return (try? element.ownText()) ?? ""
    }

    /// 伪代码 0x10010d948（L173-176）：文本节点集。
    func textNodes(of nodeID: String) -> [String] {
        guard let element = node(for: nodeID) else { return [] }
        let nodes = (try? element.textNodes()) ?? []
        return nodes.compactMap { $0.getWholeText() }
    }

    /// 伪代码 0x10010d9ec（L178-181）：data 域（script/style 内容）。
    func data(of nodeID: String) -> String {
        guard let element = node(for: nodeID) else { return "" }
        return (try? element.data()) ?? ""
    }

    /// 伪代码 0x10010dacc（L188-191）：外层 HTML。
    func outerHTML(of nodeID: String) -> String {
        guard let element = node(for: nodeID) else { return "" }
        return (try? element.outerHtml()) ?? ""
    }

    /// 伪代码 0x10010dc50（L198-203）：标签名重写（失效投影域）。
    func setTagName(_ nodeID: String, name: String) {
        guard let element = node(for: nodeID) else { return }
        try? element.tagName(name)
        invalidateProjection(for: nodeID)
    }

    /// 伪代码 0x10010dd38（L205-208）：属性读取。
    func attr(_ nodeID: String, key: String) -> String {
        guard let element = node(for: nodeID) else { return "" }
        return (try? element.attr(key)) ?? ""
    }

    /// 伪代码 0x10010dec8（L210-213）：属性存在判定。
    func hasAttr(_ nodeID: String, key: String) -> Bool {
        guard let element = node(for: nodeID) else { return false }
        return element.hasAttr(key)
    }

    /// 伪代码 0x10010df6c（L215-218）：类名存在判定。
    func hasClass(_ nodeID: String, className: String) -> Bool {
        guard let element = node(for: nodeID) else { return false }
        return element.hasClass(className)
    }

    /// 伪代码 0x10010e058（L225-236）：属性写入（失效投影域）。
    func setAttr(_ nodeID: String, key: String, value: String) {
        guard let element = node(for: nodeID) else { return }
        try? element.attr(key, value)
        invalidateProjection(for: nodeID)
    }

    /// 伪代码 0x10010e524（L238-243）：全属性集。
    func attributes(of nodeID: String) -> [String: String] {
        guard let element = node(for: nodeID) else { return [:] }
        guard let attrs = try? element.getAttributes() else { return [:] }
        var result: [String: String] = [:]
        for attr in attrs {
            result[attr.getKey()] = attr.getValue()
        }
        return result
    }

    /// 伪代码 0x10010e5f4（L251-255）：内层 HTML 重写（失效投影域）。
    func setHTML(_ nodeID: String, html: String) {
        guard let element = node(for: nodeID) else { return }
        try? element.html(html)
        invalidateProjection(for: nodeID)
    }

    /// 伪代码 0x10010e770（L257-262）：子树清空（失效投影域）。
    func empty(_ nodeID: String) {
        guard let element = node(for: nodeID) else { return }
        try? element.empty()
        invalidateProjection(for: nodeID)
    }

    /// 投影失效路由（DocumentRecord.invalidateXPathProjection 消费域）。
    private func invalidateProjection(for nodeID: String) {
        let documentID = nodeID.split("/").first ?? ""
        record(for: documentID)?.invalidateXPathProjection()
    }
}

