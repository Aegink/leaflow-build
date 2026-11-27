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
        case chapterListEmpty

        var errorDescription: String? {
            switch self {
            case .notEpub:
                return "文件不是有效的 EPUB"
            case .containerMissing:
                return "EPUB 容器文件缺失"
            case .opfMissing:
                return "EPUB 目录文件缺失"
            case .chapterListEmpty:
                return "未解析到可阅读章节"
            }
        }
    }

    /// 清单条目（EpubManifestItem 域还原桥）。
    struct EpubManifestItem {
        let id: String
        let href: String
        let mediaType: String?
        var properties: String? = nil

        var isImage: Bool {
            mediaType?.lowercased().hasPrefix("image/") == true
        }
    }

    /// 解析产物（章节 + 封面域）。
    struct ParseResult {
        var title: String?
        var chapters: [(title: String, content: String)]
        var coverData: Data?
        var author: String? = nil
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
        return try parseContents(in: extractDir)
    }

    static func parseContents(in extractDir: URL) throws -> ParseResult {
        // META-INF/container.xml 域。
        let containerURL = extractDir
            .appendingPathComponent("META-INF/container.xml")
        guard let containerText = try? String(
            contentsOf: containerURL, encoding: .utf8) else {
            throw SimpleEpubParserError.containerMissing
        }
        let opfPath = opfPath(in: containerText)
        let opfURL = url(relativeTo: extractDir, href: opfPath)
        guard isInside(opfURL, root: extractDir) else { throw SimpleEpubParserError.opfMissing }
        guard let opfText = try? String(
            contentsOf: opfURL, encoding: .utf8) else {
            throw SimpleEpubParserError.opfMissing
        }
        guard let opfDoc = parseXML(opfText) else {
            throw SimpleEpubParserError.opfMissing
        }
        let manifest = manifestItems(opfDoc: opfDoc)
        let title = normalizedParagraph(opfTitle(opfDoc: opfDoc))
        let author = normalizedParagraph(opfDoc.at_xpath("//*[local-name()='creator']")?.text)

        // 封面域（extractCoverData 签名域确证）。
        let cover = extractCoverData(
            opfDoc: opfDoc, manifest: manifest, baseURL: opfURL
                .deletingLastPathComponent(), root: extractDir)

        // spine 域（idref 顺序 → 章节 HTML 链）。
        let spineIDs = spineIDRefs(opfDoc: opfDoc)
        let idToItem = Dictionary(manifest.map { ($0.id, $0) }, uniquingKeysWith: { _, latest in latest })
        var chapterPaths = spineIDs.compactMap { idToItem[$0]?.href }
        if chapterPaths.isEmpty {
            chapterPaths = idToItem.values.map(\.href).filter { looksLikeHtmlPath(cleanPath($0)) }.sorted()
        }
        var chapters: [(title: String, content: String)] = []
        var visited = Set<String>()
        for path in chapterPaths {
            guard looksLikeHtmlPath(cleanPath(path)) else { continue }
            let href = url(relativeTo: opfURL.deletingLastPathComponent(),
                           href: path)
            guard visited.insert(href.path).inserted, let html = readText(href, root: extractDir) else {
                continue
            }
            if let parsed = parseChapter(htmlText: html, fallbackTitle: "第\(chapters.count + 1)章") {
                chapters.append(parsed)
            }
        }
        guard !chapters.isEmpty else { throw SimpleEpubParserError.chapterListEmpty }
        return ParseResult(title: title, chapters: chapters, coverData: cover, author: author)
    }

    // MARK: OPF 域（parseXML/manifestItems/spineIDRefs/opfTitle 域）

    /// parseXML(String)（签名域确证：Kanna XML 域）。
    private static func parseXML(_ xml: String) -> XMLDocument? {
        try? Kanna.XML(xml: xml, encoding: .utf8)
    }

    /// opfPath(in:)（container.xml rootfile 域还原桥）。
    private static func opfPath(in containerText: String) -> String {
        guard let doc = parseXML(containerText),
              let rootfile = doc.at_xpath("//*[local-name()='rootfile']"),
              let fullPath = rootfile["full-path"] else {
            return "content.opf"
        }
        return fullPath
    }

    /// manifestItems(opfDoc:)（manifest 域还原桥）。
    private static func manifestItems(
        opfDoc: XMLDocument
    ) -> [EpubManifestItem] {
        let nodes = opfDoc.xpath("//*[local-name()='manifest']/*[local-name()='item']")
        return nodes.compactMap { node in
            guard let id = node["id"], let href = node["href"] else {
                return nil
            }
            return EpubManifestItem(
                id: id, href: href, mediaType: node["media-type"], properties: node["properties"])
        }
    }

    /// spineIDRefs(opfDoc:)（spine 域还原桥）。
    private static func spineIDRefs(opfDoc: XMLDocument) -> [String] {
        opfDoc.xpath("//*[local-name()='spine']/*[local-name()='itemref']").compactMap { $0["idref"] }
    }

    /// opfTitle(opfDoc:)（dc:title 域还原桥）。
    private static func opfTitle(opfDoc: XMLDocument) -> String? {
        opfDoc.at_xpath("//*[local-name()='title']")?.text
    }

    // MARK: 封面域（coverData/extractCoverData/isImageItem 域确证）

    /// coverData(for:baseURL:)（签名域确证）。
    private static func coverData(
        for item: EpubManifestItem, baseURL: URL, root: URL
    ) -> Data? {
        let fileURL = url(relativeTo: baseURL, href: item.href)
        guard isInside(fileURL, root: root) else { return nil }
        if isImageItem(item) { return try? Data(contentsOf: fileURL) }
        guard looksLikeHtmlPath(cleanPath(item.href)), let html = readText(fileURL, root: root),
              let document = parseHTML(html) else { return nil }
        let image = document.at_css("image")
        guard let href = document.at_css("img")?["src"] ?? image?["href"] ?? image?["xlink:href"] else { return nil }
        let imageURL = url(relativeTo: fileURL.deletingLastPathComponent(), href: href)
        guard isInside(imageURL, root: root) else { return nil }
        return try? Data(contentsOf: imageURL)
    }

    /// extractCoverData(opfDoc:manifest:baseURL:)（签名域确证：
    /// meta cover + manifest image 双探测域）。
    private static func extractCoverData(
        opfDoc: XMLDocument, manifest: [EpubManifestItem],
        baseURL: URL, root: URL
    ) -> Data? {
        var candidates: [EpubManifestItem] = []
        if let coverID = opfDoc.at_xpath(
            "//*[local-name()='metadata']/*[local-name()='meta'][translate(@name,'ABCDEFGHIJKLMNOPQRSTUVWXYZ','abcdefghijklmnopqrstuvwxyz')='cover']")?["content"],
           let item = manifest.last(where: { $0.id == coverID }) {
            candidates.append(item)
        }
        candidates += manifest.filter { ($0.properties ?? "").split(whereSeparator: \.isWhitespace)
            .contains(where: { $0.lowercased() == "cover-image" }) }
        candidates += manifest.filter { isImageItem($0) && ($0.id + " " + $0.href).lowercased().contains("cover") }
        candidates += opfDoc.xpath("//*[local-name()='guide']/*[local-name()='reference'][translate(@type,'ABCDEFGHIJKLMNOPQRSTUVWXYZ','abcdefghijklmnopqrstuvwxyz')='cover']")
            .compactMap { node in node["href"].map { EpubManifestItem(id: "guide-cover", href: $0, mediaType: nil) } }
        var visited = Set<String>()
        for item in candidates where visited.insert(item.href).inserted {
            if let data = coverData(for: item, baseURL: baseURL, root: root) { return data }
        }
        return nil
    }

    /// isImageItem(EpubManifestItem)（签名域确证）。
    private static func isImageItem(_ item: EpubManifestItem) -> Bool {
        item.isImage || looksLikeImagePath(cleanPath(item.href))
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
        baseURL.appendingPathComponent(cleanPath(href)).standardizedFileURL
    }

    // 0x1003a3cfc实际为路径归一：先删fragment/query，再百分号解码和反斜杠归一。
    private static func cleanPath(_ href: String) -> String {
        let path = href.components(separatedBy: "#")[0].components(separatedBy: "?")[0]
        return (path.removingPercentEncoding ?? path).replacingOccurrences(of: "\\", with: "/")
    }

    private static func isInside(_ url: URL, root: URL) -> Bool {
        url.resolvingSymlinksInPath().path.hasPrefix(root.resolvingSymlinksInPath().path + "/")
    }

    private static func readText(_ url: URL, root: URL) -> String? {
        guard isInside(url, root: root), let data = try? Data(contentsOf: url) else { return nil }
        let encodings: [String.Encoding] = [.utf8, .utf16, .isoLatin1]
        for encoding in encodings {
            if let text = String(data: data, encoding: encoding) { return text }
        }
        return nil
    }

    // MARK: 章节域（parseChapter/parseHTML/normalized 三件 域确证）

    /// parseChapter(htmlText:fallbackTitle:)（签名域确证）。
    private static func parseChapter(
        htmlText: String, fallbackTitle: String
    ) -> (title: String, content: String)? {
        guard let doc = parseHTML(htmlText) else {
            return nil
        }
        let title = normalizedParagraph(doc.at_xpath("//h1|//h2|//h3")?.text) ?? fallbackTitle
        var paragraphs = doc.xpath("//p").compactMap { node in
            normalizedParagraph(node.text)
        }
        if paragraphs.isEmpty {
            paragraphs = (normalizedBodyText(doc.at_xpath("//body")?.text) ?? "")
                .components(separatedBy: .newlines).compactMap(normalizedParagraph)
        }
        while paragraphs.first == title { paragraphs.removeFirst() }
        let body = paragraphs.joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return nil }
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
    }
}
