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
        // T-1601-B5：searchUrl 为原版 BookSource 字段（此前误用
        // bookSourceUrl——源首页地址不是搜索地址）。
        guard !rule.bookList.isEmpty else { return [] }
        let searchUrl = (source.searchUrl ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
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
            var nextUrl = firstNextTocUrl(
                from: body, rule: tocRule,
                baseUrl: book.tocUrl ?? book.bookUrl ?? "")
            var guardCount = 0
            while let next = nextUrl, !next.isEmpty, guardCount < 50 {
                let pageBody = try await fetchBody(
                    source: source, url: next, keyword: nil, page: 1)
                let more = try parseChapters(from: pageBody, source: source, rule: tocRule)
                chapters.append(contentsOf: more)
                nextUrl = firstNextTocUrl(
                    from: pageBody, rule: tocRule, baseUrl: next)
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
        var nextUrl = firstNextContentUrl(
            from: body, rule: contentRule, baseUrl: chapter.url)
        var guardCount = 0
        while let next = nextUrl, !next.isEmpty, guardCount < 30 {
            let pageBody = try await fetchBody(
                source: source, url: next, keyword: nil, page: 1)
            let more = parseContent(from: pageBody, source: source, rule: contentRule)
            content += "\n" + more
            nextUrl = firstNextContentUrl(
                from: pageBody, rule: contentRule, baseUrl: next)
            guardCount += 1
        }
        return ChapterContent(
            content: content, nextUrl: nil, isPay: false,
            comments: nil, readerAccessURL: nil, chapterTitle: nil)
    }

    /// 0x1003c1cec→0x1003c1d6c实际转发书评，PGO exploreBook标签交错。
    func getReviews(
        source: BookSource, book: Book, chapter: Chapter?,
        request: LocalSourceParser.ReviewRequest? = nil
    ) async throws -> [BookReview] {
        try await LocalSourceParser.getReviews(source: source, book: book, chapter: chapter, request: request)
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

    private func firstNextTocUrl(
        from body: String, rule: TocRule, baseUrl: String
    ) -> String? {
        AnalyzeRuleBridge.parseNextUrl(
            from: body, rule: rule.nextTocUrl, baseUrl: baseUrl)
    }

    private func firstNextContentUrl(
        from body: String, rule: ContentRule, baseUrl: String
    ) -> String? {
        AnalyzeRuleBridge.parseNextUrl(
            from: body, rule: rule.nextContentUrl, baseUrl: baseUrl)
    }
}

/// AnalyzeRule 桥（T-1601-B5：由占位空体改为真实规则引擎消费）。
///
/// 证据：
///   - 伪代码 SourceService+Parsing.c：searchBook/getBookInfo/getChapterList/
///     getChapterContent 均构造 AnalyzeRule 并在页面内容上执行规则；
///     `AnalyzeRule.getElements(rule:maxResults:)` PGO 域在
///     searchBook 闭包内确证（0x1003c2e2c 块内联调用）。
///   - 字段表：index/swift_types_dump.txt SearchRule/BookInfoRule/TocRule/
///     ContentRule/ExploreRule。
enum AnalyzeRuleBridge {

    // MARK: 网络

    static func fetchAndAnalyze(
        source: BookSource, url: String, keyword: String?, page: Int
    ) async throws -> String {
        let analyzeUrl = AnalyzeUrl(
            ruleUrl: url, key: keyword, page: page,
            baseUrl: source.bookSourceUrl)
        analyzeUrl.setExtraHeaders(source.headerMap)
        let response = try await analyzeUrl.getStrResponse(skipWebView: false)
        Logger.log(
            "[AnalyzeRuleBridge] fetch code=\(response.code) "
                + "len=\(response.body.count) url=\(analyzeUrl.url)",
            level: .verbose)
        return response.body
    }

    // MARK: 列表解析

    static func parseBooks(
        from body: String, source: BookSource, rule: ExploreRule
    ) throws -> [Book] {
        parseBookList(
            from: body, source: source, listRule: rule.bookList,
            name: rule.name, author: rule.author, coverUrl: rule.coverUrl,
            intro: rule.intro, kind: rule.kind,
            lastChapter: rule.lastChapter, bookUrl: rule.bookUrl,
            wordCount: rule.wordCount)
    }

    static func parseSearchBooks(
        from body: String, source: BookSource, rule: SearchRule
    ) throws -> [Book] {
        parseBookList(
            from: body, source: source, listRule: rule.bookList,
            name: rule.name, author: rule.author, coverUrl: rule.coverUrl,
            intro: rule.intro, kind: rule.kind,
            lastChapter: rule.lastChapter, bookUrl: rule.bookUrl,
            wordCount: rule.wordCount)
    }

    // MARK: 详情

    static func parseBookInfo(
        from body: String, source: BookSource, book: Book
    ) throws -> Book {
        let root = makeAnalyzer(body: body, source: source)
        let rule = source.ruleBookInfo
        var updated = book
        updated.name = nonEmpty(string(root, rule.name)) ?? book.name
        updated.author = nonEmpty(string(root, rule.author)) ?? book.author
        updated.coverUrl =
            nonEmpty(string(root, rule.coverUrl, isUrl: true))
            ?? book.coverUrl
        updated.intro = nonEmpty(string(root, rule.intro)) ?? book.intro
        updated.kind = nonEmpty(string(root, rule.kind)) ?? book.kind
        updated.wordCount =
            nonEmpty(string(root, rule.wordCount)) ?? book.wordCount
        updated.lastChapter =
            nonEmpty(string(root, rule.lastChapter)) ?? book.lastChapter
        if let toc = nonEmpty(string(root, rule.tocUrl, isUrl: true)) {
            updated.tocUrl = toc
        }
        return updated
    }

    // MARK: 目录 / 正文

    static func parseChapters(
        from body: String, source: BookSource, rule: TocRule
    ) throws -> [Chapter] {
        guard !rule.chapterList.isEmpty else { return [] }
        let root = makeAnalyzer(body: body, source: source)
        let elements = root.getElements(rule: rule.chapterList, maxResults: nil)
        var chapters: [Chapter] = []
        for element in elements {
            let name = string(element, rule.chapterName)
            let url = string(element, rule.chapterUrl, isUrl: true)
            if name.isEmpty && url.isEmpty { continue }
            chapters.append(
                Chapter(
                    name: name.isEmpty ? url : name,
                    url: url,
                    index: chapters.count,
                    isRead: false,
                    isPay: nil,
                    resourceUrl: nil,
                    isVip: string(element, rule.isVip) == "1",
                    isVolume: string(element, rule.isVolume) == "1",
                    updateTime: nonEmpty(string(element, rule.updateTime)),
                    wordCount: nil,
                    variable: nil))
        }
        return chapters
    }

    static func parseContent(
        from body: String, source: BookSource, rule: ContentRule
    ) -> String {
        guard !rule.content.isEmpty else { return "" }
        let root = makeAnalyzer(body: body, source: source)
        return root.getString(rule: rule.content, isUrl: false) ?? ""
    }

    static func parseNextUrl(
        from body: String, rule: String, baseUrl: String = ""
    ) -> String? {
        guard !rule.isEmpty else { return nil }
        let root = AnalyzeRule(source: nil, parent: nil)
        root.setContent(body, baseUrl: baseUrl)
        return nonEmpty(root.getString(rule: rule, isUrl: true))
    }

    // MARK: 内部

    private static func makeAnalyzer(
        body: String, source: BookSource
    ) -> AnalyzeRule {
        let root = AnalyzeRule(source: source, parent: nil)
        root.setContent(body, baseUrl: source.bookSourceUrl)
        return root
    }

    private static func parseBookList(
        from body: String, source: BookSource, listRule: String,
        name: String, author: String, coverUrl: String, intro: String,
        kind: String, lastChapter: String, bookUrl: String,
        wordCount: String
    ) -> [Book] {
        guard !listRule.isEmpty else { return [] }
        let root = makeAnalyzer(body: body, source: source)
        let elements = root.getElements(rule: listRule, maxResults: nil)
        var books: [Book] = []
        for element in elements {
            let bookName = string(element, name)
            let url = string(element, bookUrl, isUrl: true)
            if bookName.isEmpty && url.isEmpty { continue }
            books.append(
                Book(
                    bookUrl: nonEmpty(url),
                    name: bookName.isEmpty ? url : bookName,
                    author: nonEmpty(string(element, author)),
                    coverUrl: nonEmpty(
                        string(element, coverUrl, isUrl: true)),
                    intro: nonEmpty(string(element, intro)),
                    kind: nonEmpty(string(element, kind)),
                    wordCount: nonEmpty(string(element, wordCount)),
                    lastChapter: nonEmpty(string(element, lastChapter)),
                    bookSourceUrl: source.bookSourceUrl))
        }
        return books
    }

    private static func string(
        _ element: AnalyzeRule, _ rule: String, isUrl: Bool = false
    ) -> String {
        guard !rule.isEmpty else { return "" }
        return element.getString(rule: rule, isUrl: isUrl) ?? ""
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
