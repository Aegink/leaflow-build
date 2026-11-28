// 仅-smokeExploreReading：实际详情、关闭交接、ReaderRouter及生产正文加载；隔离章节I/O。
import SwiftUI

@MainActor
struct ExploreReadingSmokeView: View {
    @State private var selectedBook: ExploreSelectedBook?
    @State private var pendingReadBook: Book?
    @State private var vm = ReaderViewModel()
    @State private var ready = false
    @State private var failure: String?
    private var isDetailState: Bool { ProcessInfo.processInfo.arguments.contains("-smokeExploreBookState") }
    private var isVariableState: Bool { ProcessInfo.processInfo.arguments.contains("-smokeExploreBookVariables") }
    private var isSourceVariableState: Bool { ProcessInfo.processInfo.arguments.contains("-smokeExploreSourceVariables") }
    private var source: BookSource {
        BookSource(bookSourceUrl: "https://sample.invalid/" + (isSourceVariableState ? "explore-source-variables" : isVariableState ? "explore-detail-variables" : isDetailState ? "explore-detail-state" : "explore-reading"),
                   bookSourceName: "发现阅读样本")
    }
    private var book: Book {
        Book(bookUrl: source.bookSourceUrl + "/book", name: "固定发现书籍", author: isSourceVariableState ? "源变量样本作者" : isVariableState ? "详情变量样本作者" : isDetailState ? "详情状态样本作者" : "发现阅读样本作者",
            bookSourceUrl: source.bookSourceUrl, sourceStorageKind: .local)
    }

    var body: some View {
        NavigationStack {
            Group {
                if ready {
                    Button(book.name) { selectedBook = ExploreSelectedBook(book: book) }
                        .accessibilityIdentifier("explore-reading-book")
                } else if let failure { Text(failure) }
                else { ProgressView("准备固定样本") }
            }
            .navigationTitle("发现阅读验证")
            .exploreSourceDetailPresentations(
                selectedBook: $selectedBook, pendingReadBook: $pendingReadBook,
                onReadBookFromDetail: { book in pendingReadBook = book; selectedBook = nil },
                filterSheet: .constant(false), browserRequest: .constant(nil),
                openRoute: .constant(nil), searchRoute: .constant(nil), source: source, preparedTextReader: vm)
        }
        .task {
            guard !ready else { return }
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent("explore-reading-sources")
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let service = SourceService(storageDirectory: directory)
                let data = try JSONEncoder().encode([source])
                guard await service.importSourcesAsync(from: String(decoding: data, as: UTF8.self), storageKind: .local) >= 0
                else { throw AppError.parsing("固定书源写盘失败") }
                let chapters = [Chapter(name: "发现样本第一章", url: "/chapter/1", index: 0, isRead: false,
                    isPay: false, resourceUrl: nil, isVip: false, isVolume: false,
                    updateTime: nil, wordCount: nil, variable: nil)]
                vm.sourceService = service
                vm.chapters = chapters
                vm.chapterListProvider = { _, _ in chapters }
                vm.chapterContentProvider = { selected, _, _ in
                    guard selected.bookUrl == book.bookUrl, selected.sourceStorageKind == .local else {
                        throw AppError.parsing("发现页书籍载荷丢失")
                    }
                    return ChapterContent(content: "固定发现正文已经到达阅读器。", nextUrl: nil, isPay: false,
                        comments: [], readerAccessURL: nil, chapterTitle: chapters[0].name)
                }
                ready = true
            } catch { failure = error.localizedDescription }
        }
    }
}
