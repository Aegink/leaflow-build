// MARK: - SwiftSoup/Kanna 类型别名桥（T-1401 构建域；还原层命名对齐）

// 还原层使用 SwiftSoupDocument/SwiftSoupElement/KannaXMLDocument 等命名
//（T-206/T-209 签名域确证）；真实 SPM 包类型经本桥对齐（零新依赖：
// SwiftSoup/Kanna 为原应用 SPM 集，docs/10 P-006）。

import SwiftSoup
import Kanna

typealias SwiftSoupDocument = SwiftSoup.Document
typealias SwiftSoupElement = SwiftSoup.Element
typealias KannaXMLDocument = Kanna.XMLDocument
typealias KannaXMLElement = Kanna.XMLElement
typealias KannaXPathObject = Kanna.XMLElement
