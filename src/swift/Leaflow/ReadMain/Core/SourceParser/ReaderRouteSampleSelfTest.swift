// T-1602：生产书籍身份、类型分流及发现详情关闭后的载荷消费。
import Foundation

enum ReaderRouteSampleSelfTest {
    @MainActor
    static func run(emit: (String, [String], [String]) -> Void) {
        let sourceURL = "https://sample.invalid/reader-route"
        var selected = Book(bookUrl: "/book", name: "Book", author: "Author", bookSourceUrl: sourceURL)
        emit("book_identity_legacy_digest", ["3c06eb86f7", "09df274a52"],
            [selected.legacyId, Book(name: "固定书籍", author: "样本作者").legacyId])
        var local = selected
        local.bookUrl = " /book\n"
        local.bookSourceUrl = " \(sourceURL)\n"
        local.sourceStorageKind = .local
        local.durChapterIndex = 2
        local.durChapterPos = 300
        local.id_ = "另一存储标识"
        emit("book_identity_normalized_scope", ["true", "true", "true"],
            [String(local.matchesBookshelfIdentity(as: selected)),
                String(Book.normalizedIdentifier(" \n") == nil), String(Book.normalizedIdentifier(nil) == nil)])
        var remote = local
        remote.sourceStorageKind = .remote
        emit("book_identity_storage_isolation", ["false", "false"],
            [String(remote.matchesBookshelfIdentity(as: selected)), String(remote.matchesSourceScope(as: selected))])
        let latest = ReaderRouter.latestBook(for: selected, bookshelf: [remote, local])
        emit("reader_route_latest_progress", ["2", "300.0", "local"],
            [String(latest.durChapterIndex ?? -1), String(latest.durChapterPos ?? -1),
                latest.sourceStorageKind?.rawValue ?? "无"])
        var renamedURL = local
        renamedURL.bookUrl = "/changed-url"
        renamedURL.name = "  BOOK\n"
        renamedURL.author = " AUTHOR "
        emit("reader_route_content_fallback", ["/changed-url", "/book"],
            [ReaderRouter.latestBook(for: selected, bookshelf: [remote, renamedURL]).bookUrl ?? "",
                ReaderRouter.latestBook(for: selected, bookshelf: [remote]).bookUrl ?? ""])
        emit("book_identity_content_boundaries", ["false", "false", "true"],
            [String(Book(name: "a|b", author: "c").isSameContent(as: Book(name: "a", author: "b|c"))),
                String(Book(name: " ", author: "a").isSameContent(as: Book(name: "", author: "a"))),
                String(Book(name: "A", author: nil).isSameContent(as: Book(name: " a ", author: " ")))])
        var exact = local
        exact.name = "新书名"
        emit("reader_route_identity_priority", ["新书名"],
            [ReaderRouter.latestBook(for: selected, bookshelf: [renamedURL, exact]).name])

        let service = SourceService()
        var audio = BookSource(bookSourceUrl: sourceURL, bookSourceName: "音频源")
        audio.storageKind = .local
        audio.bookSourceType = 1
        var manga = audio
        manga.storageKind = .remote
        manga.bookSourceType = 2
        service.bookSources = [audio, manga]
        emit("reader_route_source_types", ["true", "false", "true", "false"],
            [String(ReaderRouter.isAudioSource(selected, sourceService: service)),
                String(ReaderRouter.isMangaSource(selected, sourceService: service)),
                String(ReaderRouter.isMangaSource(Book(bookSourceUrl: sourceURL, sourceStorageKind: .remote), sourceService: service)),
                String(ReaderRouter.isAudioSource(Book(bookSourceUrl: sourceURL, sourceStorageKind: .remote), sourceService: service))])
        selected.putVariable("bookType", value: "2")
        emit("reader_route_book_override", ["false", "true"],
            [String(ReaderRouter.isAudioSource(selected, sourceService: service)),
                String(ReaderRouter.isMangaSource(selected, sourceService: service))])
        selected.putVariable("bookType", value: "0")
        emit("reader_route_text_override", ["true"],
            [String(ReaderRouter.isTextBook(selected, sourceService: service))])
        selected.putVariable("bookType", value: "9")
        emit("reader_route_unknown_override", ["true"],
            [String(ReaderRouter.isTextBook(selected, sourceService: service))])
        selected.putVariable("bookType", value: "not-an-integer")
        emit("reader_route_invalid_override_fallback", ["true"],
            [String(ReaderRouter.isAudioSource(selected, sourceService: service))])
        emit("reader_route_missing_source", ["true"],
            [String(ReaderRouter.isTextBook(Book(bookSourceUrl: sourceURL + "/missing"), sourceService: service))])
        var tabSource = BookSource(bookSourceUrl: sourceURL + "/tab", bookSourceName: "标签源")
        tabSource.storageKind = .local
        service.bookSources = [tabSource]
        let tabBook = Book(bookSourceUrl: tabSource.bookSourceUrl, sourceStorageKind: .local)
        let previous = BookSource.readState("sourceVariable_", source: tabSource)
        defer { BookSource.writeState("sourceVariable_", source: tabSource, value: previous) }
        BookSource.writeState("sourceVariable_", source: tabSource, value: "{\"tab\":\"听书\"}")
        emit("reader_route_audio_tab", ["true", "false"],
            [String(ReaderRouter.isAudioSource(tabBook, sourceService: service)),
                String(ReaderRouter.isMangaSource(tabBook, sourceService: service))])
        BookSource.writeState("sourceVariable_", source: tabSource, value: "{\"tab\":\"漫画\"}")
        emit("reader_route_manga_tab", ["false", "true"],
            [String(ReaderRouter.isAudioSource(tabBook, sourceService: service)),
                String(ReaderRouter.isMangaSource(tabBook, sourceService: service))])
        BookSource.writeState("sourceVariable_", source: tabSource, value: "{\"tab\":2}")
        emit("reader_route_invalid_tab", ["true"],
            [String(ReaderRouter.isTextBook(tabBook, sourceService: service))])
        BookSource.writeState("sourceVariable_", source: tabSource, value: "{")
        emit("reader_route_malformed_state", ["true"],
            [String(ReaderRouter.isTextBook(tabBook, sourceService: service))])

        var pending: Book? = local
        let held = ExploreReaderRequest.takePending(isDetailPresented: true, pending: &pending)
        emit("explore_reader_waits_for_detail", ["true", "true"],
            [String(held == nil), String(pending != nil)])
        let payload = ExploreReaderRequest.takePending(isDetailPresented: false, pending: &pending)
        emit("explore_reader_complete_payload", ["true", "true"],
            [String(payload == local), String(pending == nil)])
        emit("explore_reader_consumed_once", ["true"],
            [String(ExploreReaderRequest.takePending(isDetailPresented: false, pending: &pending) == nil)])
        var cancelled: Book?
        emit("explore_reader_cancelled_detail", ["true"],
            [String(ExploreReaderRequest.takePending(isDetailPresented: false, pending: &cancelled) == nil)])
        emit("explore_detail_presentation_identity", ["true"],
            [String(ExploreSelectedBook(book: local).id != ExploreSelectedBook(book: local).id)])
    }
}
