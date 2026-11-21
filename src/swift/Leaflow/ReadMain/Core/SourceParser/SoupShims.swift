// MARK: - SwiftSoup/Kanna 类型别名桥（T-1401 构建域；还原层命名对齐）

// 还原层使用 SwiftSoupDocument/SwiftSoupElement/KannaXMLDocument 等命名
//（T-206/T-209 签名域确证）；真实 SPM 包类型经本桥对齐（零新依赖：
// SwiftSoup/Kanna 为原应用 SPM 集，docs/10 P-006）。

import SwiftSoup
import Kanna

typealias SwiftSoupDocument = SwiftSoup.Document
typealias SwiftSoupElement = SwiftSoup.Element
// Kanna 5.3：XMLDocument/XMLElement 为协议（具体类 internal，经 Kanna.XML
// 工厂构造）；XPathObject 为枚举结果域（wave-16 别名修正）。
typealias KannaXMLDocument = Kanna.XMLDocument
typealias KannaXMLElement = Kanna.XMLElement
typealias KannaXPathObject = Kanna.XPathObject

extension Kanna.XPathObject {
    /// elements 数组桥（XPathObject 枚举无 Sequence 一致性——迭代取值，
    /// wave-16 补桥）。
    var leaflowElements: [any Kanna.XMLElement] {
        var result: [any Kanna.XMLElement] = []
        var iterator = makeIterator()
        while let element = iterator.next() {
            result.append(element)
        }
        return result
    }
}
