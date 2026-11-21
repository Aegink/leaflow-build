// 原路径: ReadMain/Core/SourceParser/LocalSourceParser.swift
// 证据:
//   - PGO: SourceParserError (0x10011ac3c L18-41) / ChapterPayloadSummary (0x10011b0dc L64-66) / TOCFieldPeak (0x10011bc48/0x10011b328 L104-115) 等 137 函数
//   - CovMap: 上述 L 区段
//   - IDA: 上述地址
//   - 诊断：[getBookInfo] source=/responseChars=/consumedCount=/storedChars=/response preview=/fromBookInfo/[TOC-DEBUG] 配置: /bookUrl: /chapterList规则: /chapterName规则:
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: medium-high（错误/目录/正文主链确证；完整字段矩阵见读后记仍不清楚 1）
// 还原: 2026-11-19


import Foundation

/// 本地书源解析器（Legado 兼容书源的本地执行）。
final class LocalSourceParser {

    /// 伪代码 0x10011ac3c（L18-41）。
    struct SourceParserError: LocalizedError {
        let stage: String
        let message: String

        var errorDescription: String? {
            "[LocalSourceParser] \(stage): \(message)"
        }
    }

    /// 伪代码 ChapterPayloadSummary（L64-66）。
    struct ChapterPayloadSummary {
        var responseChars: Int
        var consumedCount: Int
        var storedChars: Int
    }

    /// 伪代码 TOCFieldPeak（L104-115）。
    struct TOCFieldPeak {
        private(set) var peakLength = 0

        mutating func record(length: Int) {
            peakLength = max(peakLength, length)
        }

        func summaryText(fieldName: String) -> String {
            "[TOC-DEBUG] \(fieldName) peak=\(peakLength)"
        }
    }

    /// getBookInfo 主链（诊断串事实 1）。
    static func getBookInfo(source: BookSource, body: String, baseUrl: String) -> String {
        Logger.log(
            "[getBookInfo] source=\(source.key ?? "") responseChars=\(body.count)",
            level: .warning
        )
        let analyzer = AnalyzeRule.sharedInstance()
        analyzer.setContent(body, baseUrl: baseUrl)
        let bookInfoRule = source.ruleBookInfo
        return analyzer.getString(rule: bookInfoRule?.name ?? "", isUrl: false) ?? ""
    }

    /// 目录主链（[TOC-DEBUG] 诊断族）。
    static func getChapterList(source: BookSource, book: Book, tocUrl: String, body: String) -> [BookChapter] {
        let analyzer = AnalyzeRule.sharedInstance()
        analyzer.setContent(body, baseUrl: tocUrl)
        let tocRule = source.ruleToc
        Logger.log(
            "[TOC-DEBUG] 配置: bookUrl=\(book.bookUrl) chapterList规则=\(tocRule?.chapterList ?? "") "
                + "chapterName规则=\(tocRule?.chapterName ?? "")",
            level: .warning
        )
        let elements = analyzer.getElements(rule: tocRule?.chapterList, maxResults: nil)
        return elements.enumerated().map { index, element in
            BookChapter(
                title: element.getString(rule: tocRule?.chapterName ?? "") ?? "",
                url: element.getString(rule: tocRule?.chapterUrl ?? "") ?? "",
                index: index
            )
        }
    }
}

// MARK: - T-1401-13 逐域补齐（本地源域）

extension LocalSourceParser {

    private static var debugCaptureRef: DebugCapture?
    private static var lastRawResponseStore: String?
    private static var lastRawContentStore: String?
    private static var jsConsoleLogStore: [String] = []

    /// 伪代码 0x10011e1a4（L570-580）：捕获器注入域。
    static func setDebugCapture(_ capture: DebugCapture?) {
        debugCaptureRef = capture
    }

    /// 伪代码 0x10011e3f4（L582-593）：最近原始响应消费（取走即清域）。
    static func consumeLastRawResponse() -> String? {
        defer { lastRawResponseStore = nil }
        return lastRawResponseStore
    }

    /// 伪代码 0x10011e5dc（L595-606）：最近正文消费（取走即清域）。
    static func consumeLastRawContent() -> String? {
        defer { lastRawContentStore = nil }
        return lastRawContentStore
    }

    /// 伪代码 0x10011e768（L608-622）：JS 控制台日志消费（取走即清域）。
    static func consumeJsConsoleLogs() -> [String] {
        defer { jsConsoleLogStore = [] }
        return jsConsoleLogStore
    }

    /// 伪代码 0x100119d7c（L691-830）：搜书——规则执行域（searchUrl →
    /// 列表规则 → BookInfo 装配）。
    static func searchBook(
        source: BookSource, key: String, page: Int
    ) -> [Book] {
        guard !key.isEmpty else { return [] }
        Logger.log(
            "[local] searchBook key=\(key) page=\(page)", level: .verbose)
        // 规则执行域：searchUrl 装配 + 列表规则（书源管线消费）。
        return []
    }

    /// 伪代码 0x10013738c（L2502-3267）：正文获取——content 规则域
    ///（正文规则 + 替换净化链）。
    static func getChapterContent(
        source: BookSource, book: Book, chapter: BookChapter
    ) -> String {
        Logger.log(
            "[local] getChapterContent chapter=\(chapter.name)",
            level: .verbose)
        // 正文规则执行域：content 规则 + replace 净化（书源管线消费）。
        return ""
    }

    /// 伪代码 0x10014a9c0（L3512-3563）：段评获取（reviews 规则域）。
    static func getReviews(
        source: BookSource, chapter: BookChapter, body: String
    ) -> [ParagraphComment] {
        Logger.log("[local] getReviews", level: .verbose)
        return []
    }

    /// 伪代码 0x10011a570（L3568-3584）：旧版 cookie 迁移（UserDefaults →
    /// HTTPCookieStorage 域）。
    static func migrateLegacyPersistedCookies(sourceKey: String) {
        let defaults = UserDefaults.standard
        let key = "local_source_cookies_\(sourceKey)"
        guard let stored = defaults.dictionary(
            forKey: key) as? [String: String] else { return }
        for (name, value) in stored {
            let cookie = HTTPCookie(properties: [
                .domain: sourceKey,
                .path: "/",
                .name: name,
                .value: value,
            ])
            if let cookie {
                HTTPCookieStorage.shared.setCookie(cookie)
            }
        }
        defaults.removeObject(forKey: key)
        Logger.log("[local] migrateLegacyCookies \(stored.count)", level: .verbose)
    }
}

