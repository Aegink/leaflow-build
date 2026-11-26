// 原始归属: ReadMain/Core/SourceParser/LocalSourceParser.swift
// 0x10014a800入口、0x10014acb4请求、0x10014aeec L3535-3562解析循环。
// PGO标签交错，原始指令与ReviewRule字段偏移互证，见t1602_reader_probe.txt。
import Foundation

extension LocalSourceParser {
    typealias ReviewRequest = (AnalyzeUrl) async throws -> StrResponse

    static func getReviews(
        source: BookSource, book: Book, chapter: Chapter?,
        request: ReviewRequest? = nil
    ) async throws -> [BookReview] {
        let rule = source.ruleReview
        guard !rule.reviewUrl.isEmpty else { return [] }
        let base = chapter.flatMap { $0.url.isEmpty ? nil : $0.url } ?? book.bookUrl ?? ""
        // 原请求体传source，book/chapter在请求构造时为空；解析时再绑定两者。
        let analyzer = AnalyzeUrl(ruleUrl: rule.reviewUrl, key: nil, page: 1, baseUrl: base, source: source)
        defer { analyzer.endJSContextScope() }
        analyzer.setExtraHeaders(source.headerMap)
        let response: StrResponse
        if let request {
            response = try await request(analyzer)
        } else {
            response = try await analyzer.getStrResponse(skipWebView: false)
        }
        guard (200..<300).contains(response.code) else {
            throw SourceParserError(stage: "书评", message: "请求失败（\(response.code)）：\(response.message)")
        }
        return parseReviews(source: source, book: book, chapter: chapter,
            body: response.body, baseUrl: response.url ?? analyzer.url)
    }

    static func parseReviews(
        source: BookSource, book: Book, chapter: Chapter?, body: String, baseUrl: String
    ) -> [BookReview] {
        let rule = source.ruleReview
        let analyzer = AnalyzeRule(source: source, parent: nil)
        analyzer.book = book
        analyzer.currentChapter = chapter.map { BookChapter(title: $0.name, url: $0.url, index: $0.index) }
        analyzer.setContent(body, baseUrl: baseUrl)
        defer { analyzer.releaseOwnedJSContext() }
        // 原循环确实同用contentRule提取列表和逐项正文，不能擅改用旧重建字段reviewList。
        return analyzer.getElements(rule: rule.contentRule, maxResults: nil).compactMap { element in
            defer { element.releaseOwnedJSContext() }
            let avatar = rule.avatarRule.isEmpty ? nil : element.getString(rule: rule.avatarRule, isUrl: true)
            let content = element.getString(rule: rule.contentRule, isUrl: false) ?? ""
            let time = rule.postTimeRule.isEmpty ? nil : element.getString(rule: rule.postTimeRule, isUrl: false)
            guard !content.isEmpty else { return nil }
            return BookReview(avatar: avatar, content: content, postTime: time, quote: nil)
        }
    }
}
