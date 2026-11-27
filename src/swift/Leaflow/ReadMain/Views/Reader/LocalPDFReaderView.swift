// 原路径: ReadMain/Views/Reader/LocalPDFReaderView.swift
// 类型表9602：书籍、页图、目录、当前页和加载错误；0x100710198读取真实filePath，0x100710c00预载前1后3页。
// 横向页列与目录/进度主链恢复；TODO(T-304-03)：原版其他阅读模式和菜单细节仍需恢复。
import SwiftUI
import PDFKit

@MainActor
struct LocalPDFReaderView: View {
    let book: LocalBook
    @StateObject private var vm: LocalPDFReaderViewModel
    @State private var showMenu = false
    @State private var showChapterList = false

    init(book: LocalBook, localBookService: LocalBookService = .shared) {
        self.book = book
        _vm = StateObject(wrappedValue: LocalPDFReaderViewModel(book: book, service: localBookService))
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                readerContent(geometry: geometry)
                if vm.isLoading { ProgressView("加载PDF") }
                if showMenu { menuOverlay(geometry: geometry) }
            }
        }
        .task { await loadBook() }
        .task(id: vm.currentPage) { await preloadPages(around: vm.currentPage) }
        .onDisappear { vm.saveProgress() }
        .modifier(ReadingStatisticsLifecycleModifier(
            bookFingerprint: book.id.uuidString, bookName: book.name,
            pageIndex: vm.currentPage, chapterIndex: vm.currentDirectoryIndex,
            charCount: 0, isReady: !vm.isLoading && vm.loadError == nil && vm.images[vm.currentPage] != nil))
        .sheet(isPresented: $showChapterList) {
            NavigationStack {
                List(vm.directoryChapters) { chapter in
                    Button(chapter.title) {
                        vm.jumpToDirectoryItem(chapter.startPosition)
                        showChapterList = false
                    }
                }
                .navigationTitle("目录")
                .toolbar { ToolbarItem(placement: .topBarLeading) { Button("关闭") { showChapterList = false } } }
            }
        }
    }

    @ViewBuilder
    private func readerContent(geometry: GeometryProxy) -> some View {
        if let error = vm.loadError {
            VStack(spacing: 12) {
                Text(error)
                Button("点击重试") { Task { await loadBook() } }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if vm.pageCount > 0 {
            // 类型表LocalPDFReaderView.Body直接消费MangaPagedView，提交只在翻页完成后发生。
            MangaPagedView(pages: vm.pages, startIndex: vm.currentPage,
                onCenterTap: { showMenu.toggle() }, onPageChange: vm.jumpToPage)
                .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }

    private func menuOverlay(geometry: GeometryProxy) -> some View {
        VStack {
            HStack {
                Text("第 \(vm.currentPage + 1) / \(vm.pageCount) 页")
                    .accessibilityIdentifier("pdf-page-position")
                Spacer()
                Button("目录") { showChapterList = true }
                    .accessibilityIdentifier("pdf-directory")
                Button { showMenu = false } label: { Image(systemName: "chevron.down") }
            }
            .padding()
            .background(.ultraThinMaterial)
            Spacer()
        }
    }

    private func loadBook() async { await vm.loadBook() }
    private func preloadPages(around index: Int) async { await vm.preloadPages(around: index) }
    private var currentDirectoryIndex: Int { vm.currentDirectoryIndex }
}

@MainActor
final class LocalPDFReaderViewModel: ObservableObject {
    @Published private(set) var currentPage = 0
    @Published private(set) var pageCount = 0
    @Published private(set) var pages: [MangaPage] = []
    @Published private(set) var directoryChapters: [LocalChapter] = []
    @Published private(set) var images: [Int: UIImage] = [:]
    @Published private(set) var isLoading = false
    @Published private(set) var loadError: String?
    private let book: LocalBook
    private let service: LocalBookService
    private var document: PDFDocument?

    init(book: LocalBook, service: LocalBookService) {
        self.book = book
        self.service = service
    }

    var currentDirectoryIndex: Int {
        directoryChapters.lastIndex(where: { $0.startPosition <= currentPage }) ?? 0
    }

    func loadBook() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        guard book.format.uppercased() == "PDF", let opened = PDFDocument(url: book.fileURL),
              opened.pageCount > 0 else {
            loadError = "无法读取PDF文件"
            return
        }
        document = opened
        pageCount = opened.pageCount
        pages = (0..<pageCount).map { index in
            MangaPage(chapterIndex: 0, pageIndex: index,
                imageURL: PDFPageImageSource.makeURL(bookId: book.id.uuidString,
                    fileName: book.fileURL.lastPathComponent, pageIndex: index)?.absoluteString ?? "",
                imageRequestContext: nil, chapterTitle: "第\(index + 1)页", content: "")
        }
        directoryChapters = PDFPageImageSource.directoryChapters(at: book.fileURL, pageCount: pageCount)
            .map { LocalChapter(id: $0.order, title: $0.title, startPosition: $0.pageIndex, endPosition: $0.pageIndex + 1) }
        currentPage = min(max(0, book.durChapterIndex), pageCount - 1)
        await preloadPages(around: currentPage)
    }

    func jumpToPage(_ page: Int) {
        guard pageCount > 0 else { return }
        currentPage = min(max(page, 0), pageCount - 1)
        saveProgress()
    }

    func jumpToDirectoryItem(_ pageIndex: Int) {
        jumpToPage(pageIndex)
    }

    func preloadPages(around index: Int) async {
        guard let document, pageCount > 0 else { return }
        let center = min(max(index, 0), pageCount - 1)
        let range = max(0, center - 1)...min(pageCount - 1, center + 3)
        for target in range where images[target] == nil {
            guard !Task.isCancelled else { return }
            if let image = PDFPageImageSource.renderPage(document: document, pageIndex: target, maxPixelSize: 2048) {
                images[target] = image
            }
            await Task.yield()
        }
    }

    func saveProgress() {
        guard pageCount > 0 else { return }
        service.saveReadingProgress(book: book, chapterIndex: currentPage, position: 0)
        ReadingDurationTracker.shared.saveIncremental()
    }
}

