// 原路径: ReadMain/Views/Reader/Manga/ReaderRouter.swift
// 类型表8901/34242：Book、预装配文本阅读器、BookService及音频/漫画/文本三分支。
// 0x10063c848：优先同书架身份，再同内容且同来源；0x10063d128/0x10063d5f4：类型解析。
import SwiftUI

@MainActor
struct ReaderRouter: View {
    let book: Book
    var preparedTextReader: ReaderViewModel?
    @EnvironmentObject private var bookService: BookService
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var sourceService: SourceService
    @State private var settings: ReadingSettings
    @State private var ready = false

    init(book: Book, settings: ReadingSettings = .load(), preparedTextReader: ReaderViewModel? = nil) {
        self.book = book
        self.preparedTextReader = preparedTextReader
        _settings = State(initialValue: settings)
        _sourceService = ObservedObject(wrappedValue: preparedTextReader?.sourceService ?? .shared)
    }

    var body: some View {
        NavigationStack {
            Group {
                if ready {
                    let latest = Self.latestBook(for: book, bookService: bookService)
                    if Self.isAudioSource(latest, sourceService: sourceService) {
                        AudioPlayerView(book: latest)
                    } else if Self.isMangaSource(latest, sourceService: sourceService) {
                        MangaReaderView(book: latest)
                    } else {
                        ReaderView(settings: $settings, book: latest, viewModel: preparedTextReader)
                    }
                } else {
                    ProgressView("正在打开书籍")
                }
            }
            .navigationTitle(book.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                        .accessibilityIdentifier("reader-router-close")
                }
            }
        }
        .task {
            await bookService.waitUntilReady()
            if !sourceService.hasLoadedOnce { await sourceService.loadLocalSources() }
            guard !Task.isCancelled else { return }
            ready = true
        }
    }

    static func latestBook(for book: Book, bookService: BookService) -> Book {
        latestBook(for: book, bookshelf: bookService.bookshelf)
    }

    static func latestBook(for book: Book, bookshelf: [Book]) -> Book {
        bookshelf.first(where: { $0.matchesBookshelfIdentity(as: book) })
            ?? bookshelf.first(where: { $0.isSameContent(as: book) && $0.matchesSourceScope(as: book) })
            ?? book
    }

    static func isTextBook(_ book: Book, sourceService: SourceService = .shared) -> Bool {
        !isAudioSource(book, sourceService: sourceService) && !isMangaSource(book, sourceService: sourceService)
    }

    static func isAudioSource(_ book: Book, sourceService: SourceService = .shared) -> Bool {
        matchesType(book, type: 1, tab: "听书", sourceService: sourceService)
    }

    static func isMangaSource(_ book: Book, sourceService: SourceService = .shared) -> Bool {
        matchesType(book, type: 2, tab: "漫画", sourceService: sourceService)
    }

    private static func matchesType(_ book: Book, type: Int, tab: String, sourceService: SourceService) -> Bool {
        // 有效整数是显式覆盖；0及未知整数也须阻止源类型回退。
        if let value = book.getVariable("bookType"), let selected = Int(value) { return selected == type }
        guard let sourceURL = book.bookSourceUrl else { return false }
        let source: BookSource?
        if let storage = book.sourceStorageKind {
            source = sourceService.getSource(byUrl: sourceURL, storageKind: storage)
        } else {
            source = sourceService.getSource(byUrl: sourceURL)
        }
        guard let source else { return false }
        if source.bookSourceType == type { return true }
        guard let state = BookSource.readState("sourceVariable_", source: source),
              let data = state.data(using: .utf8),
              let values = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return false }
        return values["tab"] as? String == tab
    }
}
