// T-1602：原版书评字段、双用contentRule、请求与响应baseURL、错误和冷启动源查找。
import Foundation

enum BookReviewSampleSelfTest {
    static let body = """
        <html><body><article avatar="../avatar.png" time="今天">固定评论</article>
        <article>第二条评论</article><article avatar="empty.png"></article></body></html>
        """

    static func source() -> BookSource {
        var source = BookSource(bookSourceUrl: "https://sample.invalid", bookSourceName: "固定书评源")
        source.ruleReview.reviewUrl = "reviews"
        source.ruleReview.contentRule = "//article"
        source.ruleReview.avatarRule = "//article/@avatar"
        source.ruleReview.postTimeRule = "//article/@time"
        source.header = #"{"X-Review-Sample":"固定头"}"#
        return source
    }

    static func chapter() -> Chapter {
        Chapter(name: "第一章", url: "https://sample.invalid/book/chapters/1", index: 0,
            isRead: false, isPay: nil, resourceUrl: nil, isVip: false, isVolume: false,
            updateTime: nil, wordCount: nil, variable: nil)
    }

    @MainActor
    static func run(emit: (String, [String], [String]) -> Void) async {
        let source = source()
        let book = Book(bookUrl: "https://sample.invalid/book/detail", name: "固定书评书籍",
            bookSourceUrl: source.bookSourceUrl)
        let chapter = chapter()
        let service = SourceService()
        do {
            var called = false
            let missing = try await service.getReviews(source: BookSource(), book: book, chapter: nil) { _ in
                called = true
                throw URLError(.badURL)
            }
            emit("book_review_missing_rule", ["0", "false"], [String(missing.count), String(called)])

            var requestUrl = ""
            var requestHeader = ""
            let reviews = try await service.getReviews(source: source, book: book, chapter: chapter) { analyzer in
                requestUrl = analyzer.url
                requestHeader = analyzer.headers["X-Review-Sample"] ?? ""
                return StrResponse(body: body, code: 200, message: "成功", headers: [:],
                    url: "https://cdn.invalid/reviews/list")
            }
            emit("book_review_parse_response_base", ["2", "固定评论|第二条评论", "https://cdn.invalid/avatar.png",
                "今天", "true", "true", "https://sample.invalid/book/chapters/reviews", "固定头"],
                [String(reviews.count), reviews.map(\.content).joined(separator: "|"), reviews.first?.avatar ?? "",
                 reviews.first?.postTime ?? "", String(reviews.allSatisfy { $0.quote == nil }),
                 String(Set(reviews.map(\.id)).count == reviews.count), requestUrl, requestHeader])

            var fallback = ""
            _ = try await service.getReviews(source: source, book: book, chapter: nil) { analyzer in
                fallback = analyzer.url
                return StrResponse(body: "", code: 200, message: "成功", headers: [:])
            }
            emit("book_review_book_base_fallback", ["https://sample.invalid/book/reviews"], [fallback])

            var scripted = source
            scripted.bookSourceName = "带'引号\\与换行\n源"
            scripted.ruleReview.reviewUrl = "{{source.bookSourceUrl}}/review/{{page}}"
            var scriptUrl = ""
            _ = try await service.getReviews(source: scripted, book: book, chapter: chapter) { analyzer in
                scriptUrl = analyzer.url
                return StrResponse(body: "", code: 200, message: "成功", headers: [:])
            }
            emit("book_review_source_request_context", ["https://sample.invalid/review/1"], [scriptUrl])

            let first = reviews.first ?? BookReview(avatar: nil, content: "解析为空", postTime: nil, quote: nil)
            let decoded = try JSONDecoder().decode(BookReview.self, from: JSONEncoder().encode(first))
            emit("book_review_model_roundtrip", ["true", "false"], [String(decoded == first && !reviews.isEmpty),
                String(String(decoding: try JSONEncoder().encode(decoded), as: UTF8.self).contains("authorName"))])

            var contextual = source
            contextual.ruleReview.postTimeRule = "@js:book.name + ':' + chapter.title"
            let contextualReviews = LocalSourceParser.parseReviews(source: contextual, book: book,
                chapter: chapter, body: "<article>正文</article>", baseUrl: book.bookUrl ?? "")
            emit("book_review_rule_context", ["固定书评书籍:第一章"], [contextualReviews.first?.postTime ?? ""])
        } catch {
            emit("book_review_setup", ["成功"], [error.localizedDescription])
            return
        }
        var httpRejected = false
        do {
            _ = try await service.getReviews(source: source, book: book, chapter: chapter) { _ in
                StrResponse(body: body, code: 503, message: "暂不可用", headers: [:])
            }
        } catch { httpRejected = error.localizedDescription.contains("503") }
        emit("book_review_http_failure", ["true"], [String(httpRejected)])
        var transportRejected = false
        do {
            _ = try await service.getReviews(source: source, book: book, chapter: chapter) { _ in
                throw URLError(.notConnectedToInternet)
            }
        } catch { transportRejected = (error as? URLError)?.code == .notConnectedToInternet }
        emit("book_review_transport_failure", ["true"], [String(transportRejected)])

        let manager = FileManager.default
        let directory = manager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        do {
            defer { try? manager.removeItem(at: directory) }
            let original = SourceService(storageDirectory: directory)
            let text = String(decoding: try JSONEncoder().encode([source]), as: UTF8.self)
            let saved = await original.importSourcesAsync(from: text, storageKind: .local)
            let vm = ReaderViewModel()
            vm.sourceService = SourceService(storageDirectory: directory)
            vm.configure(book: book, settings: ReadingSettings.load())
            await vm.refreshCurrentBookSource()
            emit("reader_source_disk_resolution", ["1", source.bookSourceUrl, "1"],
                [String(saved), vm.currentBookSource?.bookSourceUrl ?? "", String(vm.sourceService.bookSources.count)])
        } catch {
            emit("book_review_setup", ["成功"], [error.localizedDescription])
            return
        }
        emit("book_review_setup", ["成功"], ["成功"])
    }
}
