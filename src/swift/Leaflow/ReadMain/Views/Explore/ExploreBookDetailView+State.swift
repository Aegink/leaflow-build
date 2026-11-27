// 原路径: ReadMain/Views/Explore/ExploreBookDetailView.swift
// 0x1004b18ec书架查找；0x1004b2674/2828来源；0x1004babc4/dfbc、0x1004d2be0/cd0状态写回。
import Foundation

@MainActor
enum BookDetailState {
    // 详情页用bookUrl与非空sourceURL组成身份；不沿用PGO误标的normalizeBookIdIfNeeded函数名。
    static func identity(_ book: Book) -> String {
        let url = book.bookUrl ?? ""
        guard let source = book.bookSourceUrl, !source.isEmpty else { return url }
        return url + "@" + source
    }

    static func bookshelfBook(for book: Book, bookshelf: [Book]) -> Book? {
        bookshelf.first { identity($0) == identity(book) }
    }

    static func source(for book: Book, service: SourceService) -> BookSource? {
        guard let url = book.bookSourceUrl else { return nil }
        if let storage = book.sourceStorageKind { return service.getSource(byUrl: url, storageKind: storage) }
        return service.getSource(byUrl: url)
    }

    static func stateSource(for book: Book, service: SourceService) -> BookSource? {
        if let source = source(for: book, service: service) { return source }
        guard let url = book.bookSourceUrl else { return nil }
        var source = BookSource(bookSourceUrl: url, bookSourceName: "")
        source.storageKind = book.sourceStorageKind ?? .local
        return source
    }

    static func sourceVariable(_ source: BookSource?) -> String {
        guard let source else { return "" }
        return BookSource.readState("sourceVariable_", source: source) ?? ""
    }

    static func saveSourceVariable(_ value: String, source: BookSource?) {
        guard let source else { return }
        BookSource.writeState("sourceVariable_", source: source, value: value.isEmpty ? nil : value)
    }

    static func normalizedGroup(_ value: String?) -> String? {
        Book.normalizedIdentifier(value)
    }

    static func selectedType(_ book: Book, service: SourceService) -> Int {
        if let raw = book.getVariable("bookType"), let value = Int(raw) { return value }
        if ReaderRouter.isAudioSource(book, sourceService: service) { return 1 }
        return ReaderRouter.isMangaSource(book, sourceService: service) ? 2 : 0
    }

    static func selectingType(_ type: Int, in book: Book) -> Book {
        var updated = book
        updated.putVariable("bookType", value: String(type))
        return updated
    }

    static func skipsUpdate(_ book: Book) -> Bool {
        book.getVariable("skipUpdate") == "true"
    }

    static func togglingUpdate(in book: Book) -> Book {
        var updated = book
        updated.putVariable("skipUpdate", value: skipsUpdate(book) ? nil : "true")
        return updated
    }

    static func settingCustomVariable(_ value: String, in book: Book) -> Book {
        var updated = book
        updated.putVariable("custom", value: value.isEmpty ? nil : value)
        return updated
    }
}
