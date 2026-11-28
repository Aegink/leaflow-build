// 仅-smokeReaderRepagination：生产阅读页/快捷排版/分页器，固定长正文与独立设置域。
import SwiftUI

@MainActor
struct ReaderRepaginationSmokeView: View {
    @State private var settings: ReadingSettings
    @State private var vm: ReaderViewModel
    private let book = Book(bookUrl: "https://sample.invalid/repagination/book", name: "重排验证书籍",
        author: "固定重排样本", bookSourceUrl: "https://sample.invalid/repagination")

    init() {
        let settings = ReadingSettings.load(from: UserDefaults(suiteName: "t1602-repagination-ui")!)
        let vm = ReaderViewModel()
        let chapter = Chapter(name: "固定重排章节", url: "/chapter", index: 0, isRead: false,
            isPay: false, resourceUrl: nil, isVip: false, isVolume: false, updateTime: nil, wordCount: nil, variable: nil)
        vm.chapterListProvider = { _, _ in [chapter] }
        vm.chapterContentProvider = { _, _, _ in
            ChapterContent(content: String(repeating: "固定重排正文保持连续，字号变化后重新计算页面。", count: 200),
                nextUrl: nil, isPay: false, comments: [], readerAccessURL: nil, chapterTitle: chapter.name)
        }
        _settings = State(initialValue: settings)
        _vm = State(initialValue: vm)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Text(String(vm.pages.count)).accessibilityIdentifier("repagination-page-count")
                Text(String(Double(settings.fontSize))).accessibilityIdentifier("repagination-font-size")
                Text(vm.isRebuildPending ? "重排中" : "就绪").accessibilityIdentifier("repagination-state")
                ReaderView(settings: $settings, book: book, viewModel: vm)
            }
        }
    }
}
