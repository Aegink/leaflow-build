// 原路径: ReadMain/Services/SourceService+Parsing.swift
// 证据:
//   - PGO: 80 个主函数（index/task_functions.csv T-401-01 / SourceService+Parsing.swift），
//     地址：searchBook 0x1003c1320 L31-33 / getBookInfo 0x1003c195c L440-474
//     （"[远程后端] getBookInfo 成功" 诊断串确证）/ getChapterList 0x1003bdc3c
//     L147-230 / getChapterContent 0x1003be6bc L235-368 / classifyNetworkError
//     0x1003c0bc4 L412-430 / exploreBook 0x1003c1d6c L479-481 / getReviews
//     0x1003c1fb4 L548-565
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Services/SourceService+Parsing.c
//   - 事实：书源解析主链 —— AnalyzeRule 引擎消费（getElements/getString 域）+
//     分类网络错误（URLError 分档确证）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - 主链/错误分类: high（诊断串/URLError 确证）
//   - AnalyzeRule 调用细节: medium-high（T-201 落地后交叉）
// 还原: 2026-11-19

import Foundation

extension SourceService {

    // MARK: 搜索

    /// 伪代码 0x1003c1320（L31-33）：搜索入口。
    func searchBook(
        source: BookSource, keyword: String, page: Int
    ) async throws -> [Book] {
        let rule = source.ruleSearch
        let searchUrl = rule.bookList.isEmpty
            ? "" : source.bookSourceUrl
        guard !searchUrl.isEmpty else { return [] }
        let body = try await fetchBody(
            source: source, url: searchUrl, keyword: keyword, page: page)
        return try parseBooks(from: body, source: source, rule: rule)
    }

    /// 伪代码 0x1003c195c（L440-474）：书籍详情
    ///（"[远程后端] getBookInfo 成功" 诊断串确证）。
    func getBookInfo(
        source: BookSource, book: Book, canReName: Bool
    ) async -> Book? {
        do {
            let body = try await fetchBody(
                source: source, url: book.bookUrl ?? "", keyword: nil, page: 1)
            var updated = try parseBookInfo(from: body, source: source, book: book)
            if canReName && updated.name.isEmpty {
                updated.name = book.name
            }
            Logger.log("[远程后端] getBookInfo 成功", level: .info)
            return updated
        } catch {
            Logger.error(error, context: "getBookInfo")
            return nil
        }
    }

    /// 伪代码 0x1003c1d6c（L479-481）：发现页。
    func exploreBook(
        source: BookSource, exploreUrl: String, page: Int
    ) async throws -> [Book] {
        let body = try await fetchBody(
            source: source, url: exploreUrl, keyword: nil, page: page)
        return try parseBooks(from: body, source: source, rule: source.ruleExplore)
    }

    // MARK: 目录与正文

    /// 伪代码 0x1003bdc3c（L147-230）：目录。
    func getChapterList(
        source: BookSource, book: Book, needRefresh: Bool
    ) async throws -> [Chapter] {
        let tocRule = source.ruleToc
        let body = try await fetchBody(
            source: source, url: book.tocUrl ?? book.bookUrl ?? "",
            keyword: nil, page: 1)
        var chapters = try parseChapters(from: body, source: source, rule: tocRule)
        // 反向目录（nextTocUrl 链确证）。
        if tocRule.nextTocUrl.isEmpty == false {
            var nextUrl = firstNextTocUrl(from: body, rule: tocRule)
            var guardCount = 0
            while let next = nextUrl, !next.isEmpty, guardCount < 50 {
                let pageBody = try await fetchBody(
                    source: source, url: next, keyword: nil, page: 1)
                let more = try parseChapters(from: pageBody, source: source, rule: tocRule)
                chapters.append(contentsOf: more)
                nextUrl = firstNextTocUrl(from: pageBody, rule: tocRule)
                guardCount += 1
            }
        }
        return chapters
    }

    /// 伪代码 0x1003be6bc（L235-368）：正文（nextContentUrl 链确证）。
    func getChapterContent(
        source: BookSource, book: Book, chapter: Chapter
    ) async throws -> ChapterContent {
        let contentRule = source.ruleContent
        let body = try await fetchBody(
            source: source, url: chapter.url, keyword: nil, page: 1)
        var content = parseContent(from: body, source: source, rule: contentRule)
        var nextUrl = firstNextContentUrl(from: body, rule: contentRule)
        var guardCount = 0
        while let next = nextUrl, !next.isEmpty, guardCount < 30 {
            let pageBody = try await fetchBody(
                source: source, url: next, keyword: nil, page: 1)
            let more = parseContent(from: pageBody, source: source, rule: contentRule)
            content += "\n" + more
            nextUrl = firstNextContentUrl(from: pageBody, rule: contentRule)
            guardCount += 1
        }
        return ChapterContent(
            content: content, nextUrl: nil, isPay: false,
            comments: nil, readerAccessURL: nil)
    }

    /// 伪代码 0x1003c1fb4（L548-565）：书评。
    func getReviews(
        source: BookSource, book: Book, chapter: Chapter
    ) async throws -> [BookReview] {
        [] // 书评规则域（ReviewRule），样本待真机对照。
    }

    // MARK: 错误分类

    /// 伪代码 0x1003c0bc4（L412-430）：网络错误分类（AppError.badURLMessage 同域）。
    static func classifyNetworkError(_ error: Error) -> AppError {
        if let urlError = error as? URLError {
            return .network(urlError)
        }
        return .generic(error.localizedDescription)
    }

    // MARK: 内部（AnalyzeRule 域消费）

    /// 拉取页面（AnalyzeRule 域，T-201 消费）。
    private func fetchBody(
        source: BookSource, url: String, keyword: String?, page: Int
    ) async throws -> String {
        try await AnalyzeRuleBridge.fetchAndAnalyze(
            source: source, url: url, keyword: keyword, page: page)
    }

    /// 书籍列表解析。
    private func parseBooks(
        from body: String, source: BookSource, rule: ExploreRule
    ) throws -> [Book] {
        try AnalyzeRuleBridge.parseBooks(from: body, source: source, rule: rule)
    }

    private func parseBooks(
        from body: String, source: BookSource, rule: SearchRule
    ) throws -> [Book] {
        try AnalyzeRuleBridge.parseSearchBooks(from: body, source: source, rule: rule)
    }

    /// 详情解析。
    private func parseBookInfo(
        from body: String, source: BookSource, book: Book
    ) throws -> Book {
        try AnalyzeRuleBridge.parseBookInfo(from: body, source: source, book: book)
    }

    /// 目录解析。
    private func parseChapters(
        from body: String, source: BookSource, rule: TocRule
    ) throws -> [Chapter] {
        try AnalyzeRuleBridge.parseChapters(from: body, source: source, rule: rule)
    }

    /// 正文解析。
    private func parseContent(
        from body: String, source: BookSource, rule: ContentRule
    ) -> String {
        AnalyzeRuleBridge.parseContent(from: body, source: source, rule: rule)
    }

    private func firstNextTocUrl(from body: String, rule: TocRule) -> String? {
        AnalyzeRuleBridge.parseNextUrl(from: body, rule: rule.nextTocUrl)
    }

    private func firstNextContentUrl(from body: String, rule: ContentRule) -> String? {
        AnalyzeRuleBridge.parseNextUrl(from: body, rule: rule.nextContentUrl)
    }
}

/// AnalyzeRule 桥（占位；规则引擎域 T-201 消费）。
enum AnalyzeRuleBridge {
    static func fetchAndAnalyze(
        source: BookSource, url: String, keyword: String?, page: Int
    ) async throws -> String {
        ""
    }

    static func parseBooks(
        from body: String, source: BookSource, rule: ExploreRule
    ) throws -> [Book] { [] }

    static func parseSearchBooks(
        from body: String, source: BookSource, rule: SearchRule
    ) throws -> [Book] { [] }

    static func parseBookInfo(
        from body: String, source: BookSource, book: Book
    ) throws -> Book { book }

    static func parseChapters(
        from body: String, source: BookSource, rule: TocRule
    ) throws -> [Chapter] { [] }

    static func parseContent(
        from body: String, source: BookSource, rule: ContentRule
    ) -> String { "" }

    static func parseNextUrl(from body: String, rule: String) -> String? {
        nil
    }
}
