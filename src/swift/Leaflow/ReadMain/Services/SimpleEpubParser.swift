// 原路径: ReadMain/Services/SimpleEpubParser.swift
// 证据:
//   - PGO: 54 条记录（index/task_functions.csv T-901-03 /
//     SimpleEpubParser.swift；14 函数，伪代码域 300 行）
//   - CovMap: 上述 L 区段（parse(epubURL:)/coverData(for:baseURL:)/
//     extractCoverData/isImageItem/looksLikeHtmlPath/
//     looksLikeImagePath/normalizedBodyText/normalizedParagraph/
//     normalizedText/parseChapter/htmlText/parseHTML/parseXML/
//     url(relativeTo:href:) 域）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Services/SimpleEpubParser.c
//     （3281 行）
//   - 块体确证（签名域）：
//     parse(epubURL: URL) throws / coverData(for: EpubManifestItem,
//     baseURL: URL) / extractCoverData(opfDoc: Kanna.XMLDocument,
//     manifest: ...) / isImageItem(EpubManifestItem) /
//     looksLikeHtmlPath(String) / looksLikeImagePath(String) /
//     normalizedBodyText(String?) / normalizedParagraph(String?) /
//     normalizedText(String?) / parseChapter(htmlText: String,
//     fallbackTitle: String) / parseHTML(String) / parseXML(String) /
//     url(relativeTo: URL, href: String) /
//     SimpleEpubParserError.errorDescription getter
//   - 事实：EPUB 三段解析（META-INF/container.xml → OPF manifest/spine
//     → 章节 HTML）+ 封面提取域
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（十四签名域确证）
// 还原: 2026-11-20

import Foundation
import Kanna

/// 简易 EPUB 解析器（parse(epubURL:) 签名域确证）。
enum SimpleEpubParser {

    /// 解析错误（errorDescription 签名域确证）。
    enum SimpleEpubParserError: LocalizedError {
        case notEpub
        case containerMissing
        case opfMissing

        var errorDescription: String? {
            switch self {
            case .notEpub:
                return "文件不是有效的 EPUB"
            case .containerMissing:
                return "EPUB 缺少 container.xml"
            case .opfMissing:
                return "EPUB 缺少 OPF 清单"
            }
        }
    }

    /// 清单条目（EpubManifestItem 域还原桥）。
    struct EpubManifestItem {
        let id: String
        let href: String
        let mediaType: String

        var isImage: Bool {
            mediaType.hasPrefix("image/")
        }
    }

    /// 解析产物（章节 + 封面域）。
    struct ParseResult {
        var title: String
        var chapters: [(title: String, content: String)]
        var coverData: Data?
    }

    /// parse(epubURL:)（签名域确证：解压 → container → OPF → 章节链）。
    static func parse(epubURL: URL) throws -> ParseResult {
        guard epubURL.pathExtension.lowercased() == "epub"
            || looksLikeHtmlPath(epubURL.lastPathComponent) == false else {
            throw SimpleEpubParserError.notEpub
        }
        let extractDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "epub_\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: extractDir) }
        try ZipUtility.extractZip(from: epubURL, to: extractDir)

        // META-INF/container.xml 域。
        let containerURL = extractDir
            .appendingPathComponent("META-INF/container.xml")
        guard let containerText = try? String(
            contentsOf: containerURL, encoding: .utf8) else {
            throw SimpleEpubParserError.containerMissing
        }
        let opfPath = opfPath(in: containerText)
        let opfURL = url(relativeTo: extractDir, href: opfPath)
        guard let opfText = try? String(
            contentsOf: opfURL, encoding: .utf8) else {
            throw SimpleEpubParserError.opfMissing
        }
        guard let opfDoc = parseXML(opfText) else {
            throw SimpleEpubParserError.opfMissing
        }
        let manifest = manifestItems(opfDoc: opfDoc)
        let title = opfTitle(opfDoc: opfDoc) ?? "EPUB"

        // 封面域（extractCoverData 签名域确证）。
        let cover = extractCoverData(
            opfDoc: opfDoc, manifest: manifest, baseURL: opfURL
                .deletingLastPathComponent())

        // spine 域（idref 顺序 → 章节 HTML 链）。
        let spineIDs = spineIDRefs(opfDoc: opfDoc)
        let idToItem = Dictionary(
            uniqueKeysWithValues: manifest.map { ($0.id, $0) })
        var chapters: [(title: String, content: String)] = []
        for id in spineIDs {
            guard let item = idToItem[id],
                  looksLikeHtmlPath(item.href) else {
                continue
            }
            let href = url(relativeTo: opfURL.deletingLastPathComponent(),
                           href: item.href)
            guard let html = try? String(
                contentsOf: href, encoding: .utf8) else {
                continue
            }
            chapters.append(parseChapter(
                htmlText: html, fallbackTitle: normalizedTitle(item.href)))
        }
        return ParseResult(
            title: title, chapters: chapters, coverData: cover)
    }

    // MARK: OPF 域（parseXML/manifestItems/spineIDRefs/opfTitle 域）

    /// parseXML(String)（签名域确证：Kanna XML 域）。
    private static func parseXML(_ xml: String) -> XMLDocument? {
        try? Kanna.XML(xml: xml, encoding: .utf8)
    }

    /// opfPath(in:)（container.xml rootfile 域还原桥）。
    private static func opfPath(in containerText: String) -> String {
        guard let doc = parseXML(containerText),
              let rootfile = doc.at_xpath("//rootfile"),
              let fullPath = rootfile["full-path"] else {
            return "content.opf"
        }
        return fullPath
    }

    /// manifestItems(opfDoc:)（manifest 域还原桥）。
    private static func manifestItems(
        opfDoc: XMLDocument
    ) -> [EpubManifestItem] {
        let nodes = opfDoc.xpath("//manifest/item")
        return nodes.compactMap { node in
            guard let id = node["id"], let href = node["href"],
                  let mediaType = node["media-type"] else {
                return nil
            }
            return EpubManifestItem(
                id: id, href: href, mediaType: mediaType)
        }
    }

    /// spineIDRefs(opfDoc:)（spine 域还原桥）。
    private static func spineIDRefs(opfDoc: XMLDocument) -> [String] {
        opfDoc.xpath("//spine/itemref").compactMap { $0["idref"] }
    }

    /// opfTitle(opfDoc:)（dc:title 域还原桥）。
    private static func opfTitle(opfDoc: XMLDocument) -> String? {
        opfDoc.at_xpath("//title")?.text
    }

    // MARK: 封面域（coverData/extractCoverData/isImageItem 域确证）

    /// coverData(for:baseURL:)（签名域确证）。
    private static func coverData(
        for item: EpubManifestItem, baseURL: URL
    ) -> Data? {
        let fileURL = url(relativeTo: baseURL, href: item.href)
        return try? Data(contentsOf: fileURL)
    }

    /// extractCoverData(opfDoc:manifest:baseURL:)（签名域确证：
    /// meta cover + manifest image 双探测域）。
    private static func extractCoverData(
        opfDoc: XMLDocument, manifest: [EpubManifestItem],
        baseURL: URL
    ) -> Data? {
        if let coverID = opfDoc.at_xpath(
            "//meta[@name='cover']")?["content"],
           let item = manifest.first(where: { $0.id == coverID }),
           let data = coverData(for: item, baseURL: baseURL) {
            return data
        }
        if let imageItem = manifest.first(where: isImageItem) {
            return coverData(for: imageItem, baseURL: baseURL)
        }
        return nil
    }

    /// isImageItem(EpubManifestItem)（签名域确证）。
    private static func isImageItem(_ item: EpubManifestItem) -> Bool {
        item.isImage || looksLikeImagePath(item.href)
    }

    // MARK: 路径域（looksLikeHtmlPath/looksLikeImagePath/url 域确证）

    /// looksLikeHtmlPath(String)（签名域确证）。
    private static func looksLikeHtmlPath(_ path: String) -> Bool {
        ["html", "htm", "xhtml"].contains(
            (path as NSString).pathExtension.lowercased())
    }

    /// looksLikeImagePath(String)（签名域确证）。
    private static func looksLikeImagePath(_ path: String) -> Bool {
        ["png", "jpg", "jpeg", "gif"].contains(
            (path as NSString).pathExtension.lowercased())
    }

    /// url(relativeTo:href:)（签名域确证：URL 路径解码域）。
    private static func url(relativeTo baseURL: URL, href: String)
        -> URL {
        let decoded = href
            .replacingOccurrences(of: "%20", with: " ")
        return baseURL.appendingPathComponent(decoded)
    }

    // MARK: 章节域（parseChapter/parseHTML/normalized 三件 域确证）

    /// parseChapter(htmlText:fallbackTitle:)（签名域确证）。
    private static func parseChapter(
        htmlText: String, fallbackTitle: String
    ) -> (title: String, content: String) {
        guard let doc = parseHTML(htmlText) else {
            return (fallbackTitle, normalizedBodyText(htmlText) ?? "")
        }
        let title = doc.at_xpath("//h1|h2|h3")?.text ?? fallbackTitle
        let paragraphs = doc.xpath("//p").compactMap { node in
            normalizedParagraph(node.text)
        }
        let body = paragraphs.isEmpty
            ? (normalizedBodyText(doc.at_xpath("//body")?.text) ?? "")
            : paragraphs.joined(separator: "\n\n")
        return (normalizedTitle(title), body)
    }

    /// parseHTML(String)（签名域确证：Kanna HTML 域）。
    private static func parseHTML(_ html: String) -> HTMLDocument? {
        try? Kanna.HTML(html: html, encoding: .utf8)
    }

    /// normalizedText(String?)（签名域确证）。
    private static func normalizedText(_ text: String?) -> String? {
        guard let text else { return nil }
        return text
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// normalizedParagraph(String?)（签名域确证）。
    private static func normalizedParagraph(_ text: String?) -> String? {
        guard let normalized = normalizedText(text), !normalized.isEmpty
        else {
            return nil
        }
        return normalized
    }

    /// normalizedBodyText(String?)（签名域确证）。
    private static func normalizedBodyText(_ text: String?) -> String? {
        guard let normalized = normalizedText(text), !normalized.isEmpty
        else {
            return nil
        }
        return normalized
            .replacingOccurrences(of: "\n{2,}", with: "\n\n",
                                  options: .regularExpression)
    }

    /// normalizedTitle(String)（标题清洗域）。
    private static func normalizedTitle(_ title: String) -> String {
        title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "_")
    }
}
