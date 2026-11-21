// 原路径: ReadMain/Views/Bookshelf/BookActionSheetView.swift
// 证据:
//   - PGO: 185 条记录（index/task_functions.csv T-601-05 /
//     BookActionSheetView.swift；伪代码域 10751 行）。关键地址：
//     CacheDownloadRequest getChapterList 0x1003f54e8 L37-45 /
//     getChapterContent 0x1003f5584 L52-62 / CacheDownloadManager.start
//     0x1003f5bf4 L90-166 / cancel（签名）/ bookSource 0x1003f5c58
//     L210-216 / sourceStateSource（签名）/ currentSourceVariable（签名）/
//     hasLogin 0x1003f6220 L231-234 / latestBook 0x1003f7cb4 L237-241 /
//     body 0x1003f80a0 L243-376 / bookInfoCard 0x1003f8b10 L380-445 /
//     bookTypePicker 0x1003f8c14 L460-492 / actionButtons 0x1003f9334
//     L500-556 / actionButton 0x10040b328 L558-584 / downloadAllSection
//     0x1003f9434 L588-655 / advancedOptions 0x1003f95c8 L659-688 /
//     advancedRow 0x100412258 L690-713 / progressText 0x1003ff0b8
//     L447-455 / refreshChapterList 0x10040319c L717-730 /
//     refreshBookInfo 0x1004034cc L734-755 / toggleSkipUpdate
//     0x1004036b4 L759-764 / clearBookCache 0x1003fc0ec L768-770 /
//     downloadAllChapters 0x1003fc6ec L774-780 / variableEditorSheet
//     0x1004120a0 L784-831 / bookVariableEditorSheet 0x1003fab88
//     L835-882 / saveBingCoverLocally 0x1003faff4 L895-909 /
//     saveSourceVariable 0x1004097d4 L886-893 / saveBookVariable（签名）/
//     isPinned（签名确证）
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Bookshelf/
//     BookActionSheetView.c（10751 行）
//   - 字符串确证（位模式/指针）："sourceVariable_" L155/"编辑书籍" L314/
//     "确认删除" L1970/"清除缓存" L2014/"将清除《" L3804+""》吗？" L3614/
//     "次阅读时需重新加载" @ptr L3610/" N 章未缓存。" @ptr L3808/
//     "skipUpdate" L3989/"bookType" L4005/"building.columns" @ptr L4879/
//     "pin.slash" L5959/"info.circle" L6043/"arrow.down.circle" @ptr L6073/
//     "arrow.triangle.2.circlepath" @ptr L6104/"换封面" L6105/
//     "magnifyingglass" L6136/"搜索封面" L6138/"arrow.clockwise" L6522/
//     "刷新目录" L6524/"刷新章节" L6560/"bell.slash" L6588/"已完成" L7884/
//     "已缓存 " L7890/"chevron." L7956/"pencil.and.list.clipboard" @ptr
//     L8256/"配置登录" L8258/"curlybraces" L8339/"源变量" L8342/
//     "过 source.getVariable() 获取" @ptr L8408/"书籍变量" L8410/
//     "curlybraces.square" @ptr L8467/"编辑配置" L8469/"清除源变量" L9873/
//     "确定要从书架中删除《" @ptr L10147/"书籍变量 (bookVariable)" @ptr
//     L10381/"BookCovers" L10699/"可能需要较长时间。" @ptr L9463
//   - 事实：CacheDownloadManager/CacheDownloadRequest 缓存下载域
//     （getChapterList/getChapterContent L37-62 + start L90-166）；
//     变量域（sourceVariable_ 前缀 + 源变量/书籍变量双编辑器）；
//     换封面域（BookCovers 域确证）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - 动作面板主链: high（地址 + 位模式确证）
//   - 视图树形状: medium（结构性还原；布局待真机）
// 还原: 2026-11-20

import SwiftUI

// MARK: - 缓存下载域（0x1003f54e8 L37-45 域确证）

/// 缓存下载请求（getChapterList/getChapterContent 域确证）。
struct CacheDownloadRequest {
    let book: Book
    let useReplaceRule: Bool
}

/// 缓存下载管理器（0x1003f5bf4 L90-166 域确证）。
final class CacheDownloadManager: ObservableObject {

    static let shared = CacheDownloadManager()

    @Published private(set) var isDownloading = false
    @Published private(set) var cachedCount = 0
    @Published private(set) var totalCount = 0

    private var downloadTask: Task<Void, Never>?

    /// start（0x1003f5bf4 L90-166 域确证）。
    func start(
        book: Book, bookService: BookService,
        chapterCache: ChapterCacheService
    ) {
        cancel()
        isDownloading = true
        let request = CacheDownloadRequest(book: book, useReplaceRule: false)
        downloadTask = Task {
            do {
                let chapters = try await bookService.getChapterList(
                    for: request.book, useReplaceRule: request.useReplaceRule,
                    needRefresh: false)
                await MainActor.run {
                    totalCount = chapters.count
                }
                for index in 0..<chapters.count {
                    guard !Task.isCancelled else { break }
                    _ = try? await bookService.getChapterContent(
                        for: request.book, index: index,
                        useReplaceRule: request.useReplaceRule, type: nil)
                    await MainActor.run {
                        cachedCount = index + 1
                    }
                }
                await MainActor.run {
                    isDownloading = false
                }
            } catch {
                await MainActor.run {
                    isDownloading = false
                }
            }
        }
    }

    /// cancel（签名确证）。
    func cancel() {
        downloadTask?.cancel()
        isDownloading = false
    }
}

// MARK: - BookActionSheetView

/// 书籍操作面板。
struct BookActionSheetView: View {

    let book: Book
    let onRead: (Book) -> Void
    let onDelete: (Book) -> Void

    // 状态域（getter 签名确证）。
    @State private var showVariableEditor = false
    @State private var showBookVariableEditor = false
    @State private var sourceVariableText: String = ""
    @State private var bookVariableText: String = ""
    @State private var showDeleteConfirm = false
    @State private var showChangeCover = false

    private let bookService = BookService()
    private let sourceService = SourceService()

    /// bookSource getter（0x1003f5c58 L210-216 域确证）。
    private var bookSource: BookSource? {
        sourceService.bookSources.first {
            $0.bookSourceUrl == book.bookSourceUrl
        }
    }

    /// sourceStateSource getter（签名确证）。
    private var sourceStateSource: BookSource? {
        bookSource
    }

    /// currentSourceVariable（签名确证）。
    private func currentSourceVariable() -> String {
        sourceStateSource?.variable ?? ""
    }

    /// hasLogin getter（0x1003f6220 L231-234 域确证）。
    private var hasLogin: Bool {
        sourceStateSource?.loginUrl != nil
    }

    /// latestBook getter（0x1003f7cb4 L237-241 域确证）。
    private var latestBook: Book {
        book
    }

    /// isPinned getter（签名确证）。
    private var isPinned: Bool {
        bookService.isPinned(book.id)
    }

    /// progressText getter（0x1003ff0b8 L447-455 域确证）。
    private var progressText: String? {
        CacheDownloadManager.shared.isDownloading
            ? "\(CacheDownloadManager.shared.cachedCount)/"
                + "\(CacheDownloadManager.shared.totalCount)"
            : nil
    }

    var body: some View {
        // 伪代码 0x1003f80a0（L243-376）：操作面板主链。
        NavigationStack {
            ScrollView {
                VStack(spacing: 12.0) {
                    bookInfoCard
                    bookTypePicker
                    actionButtons
                    downloadAllSection
                    advancedOptions
                }
                .padding(.all, 12.0)
            }
            .navigationTitle(book.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                }
            }
            .sheet(isPresented: $showVariableEditor) {
                variableEditorSheet
            }
            .sheet(isPresented: $showBookVariableEditor) {
                bookVariableEditorSheet
            }
            .confirmationDialog(
                "确定要从书架中删除《\(book.name)》",
                isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("确认删除", role: .destructive) {
                    onDelete(book)
                    dismiss()
                }
                Button("取消", role: .cancel) {}
            } message: {
                // "次阅读时需重新加载" @ptr L3610 域确证。
                Text("将清除《\(book.name)》吗？次阅读时需重新加载")
            }
        }
    }

    // MARK: 信息卡（0x1003f8b10 L380-445 域确证）

    /// bookInfoCard getter（0x1003f8b10 L380-445 域确证）。
    private var bookInfoCard: some View {
        HStack(spacing: 10.0) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(uiColor: .tertiarySystemFill))
                .frame(width: 50.0, height: 70.0)
                .overlay {
                    Image(systemName: "book.closed")
                        .foregroundColor(.secondary)
                }
            VStack(alignment: .leading, spacing: 4.0) {
                Text(book.name)
                    .appThemeText(.headline)
                if let author = book.author {
                    Text(author)
                        .appThemeText(.caption, opacity: 0.6)
                }
                if let source = bookSource?.bookSourceName {
                    // "building.columns" @ptr L4879 域确证。
                    Label(source, systemImage: "building.columns")
                        .appThemeText(.caption, opacity: 0.6)
                }
                if hasLogin {
                    Text("已登录")
                        .appThemeText(.caption)
                        .foregroundColor(.green)
                }
            }
            Spacer()
        }
        .padding(.all, 10.0)
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12, antialiased: true)
    }

    /// bookTypePicker（0x1003f8c14 L460-492 域确证；"bookType" L4005 域）。
    private var bookTypePicker: some View {
        Picker("类型", selection: .constant(book.bookType)) {
            Text("文本").tag(0)
            Text("音频").tag(8)
            Text("图片").tag(16)
        }
        .pickerStyle(.segmented)
    }

    // MARK: 动作按钮（0x1003f9334 L500-556 域确证）

    /// actionButtons getter（0x1003f9334 L500-556 域确证）。
    private var actionButtons: some View {
        VStack(spacing: 8.0) {
            Button {
                onRead(book)
            } label: {
                Label("开始阅读", systemImage: "book.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            // 0x10040b328 L558-584 actionButton 签名确证。
            actionButton(icon: "pin.fill", title: "置顶") {
                bookService.togglePinned(book.id)
            }
            actionButton(icon: "arrow.triangle.2.circlepath", title: "刷新目录") {
                refreshChapterList()
            }
            actionButton(icon: "info.circle", title: "刷新书籍信息") {
                refreshBookInfo()
            }
            actionButton(icon: "pencil", title: "编辑书籍") {
                // 编辑域（"编辑书籍" L314 确证）。
            }
        }
    }

    /// actionButton(icon:title:action:)（0x10040b328 L558-584 域确证）。
    private func actionButton(
        icon: String, title: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.bordered)
    }

    // MARK: 缓存域（0x1003f9434 L588-655 域确证）

    /// downloadAllSection getter（0x1003f9434 L588-655 域确证）。
    private var downloadAllSection: some View {
        VStack(alignment: .leading, spacing: 8.0) {
            if let progress = progressText {
                HStack {
                    ProgressView(value: Double(
                        CacheDownloadManager.shared.cachedCount))
                    Text(progress)
                        .appThemeText(.caption, opacity: 0.6)
                }
            } else {
                Button {
                    downloadAllChapters()
                } label: {
                    // "arrow.down.circle" @ptr L6073 域确证。
                    Label("缓存全部章节", systemImage: "arrow.down.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                // "可能需要较长时间。" @ptr L9463 域确证。
                Text("可能需要较长时间。")
                    .appThemeText(.caption, opacity: 0.5)
            }
        }
        .padding(.all, 10.0)
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12, antialiased: true)
    }

    // MARK: 高级域（0x1003f95c8 L659-688 域确证）

    /// advancedOptions getter（0x1003f95c8 L659-688 域确证）。
    private var advancedOptions: some View {
        VStack(spacing: 4.0) {
            advancedRow(icon: "curlybraces", title: "源变量") {
                sourceVariableText = currentSourceVariable()
                showVariableEditor = true
            }
            advancedRow(icon: "curlybraces.square", title: "书籍变量") {
                bookVariableText = book.variable ?? ""
                showBookVariableEditor = true
            }
            advancedRow(icon: "bell.slash", title: "跳过更新") {
                toggleSkipUpdate()
            }
            advancedRow(icon: "arrow.triangle.2.circlepath", title: "刷新章节") {
                refreshChapterList()
            }
            advancedRow(icon: "trash", title: "清除缓存") {
                clearBookCache()
            }
            advancedRow(icon: "pencil.and.list.clipboard", title: "配置登录") {
                // TODO(T-401-06 域): SourceLoginView 接入。
            }
        }
        .padding(.all, 10.0)
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12, antialiased: true)
    }

    /// advancedRow(icon:title:action:)（0x100412258 L690-713 域确证）。
    private func advancedRow(
        icon: String, title: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 24.0)
                Text(title)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 6.0)
        }
        .buttonStyle(.plain)
    }

    // MARK: 动作域（0x10040319c L717-730 + 0x1004034cc L734-755 域确证）

    /// refreshChapterList（0x10040319c L717-730 域确证）。
    private func refreshChapterList() {
        Task {
            _ = try? await bookService.getChapterList(
                for: book, useReplaceRule: false, needRefresh: true)
        }
    }

    /// refreshBookInfo（0x1004034cc L734-755 域确证）。
    private func refreshBookInfo() {
        guard let source = bookSource else { return }
        Task {
            _ = await sourceService.getBookInfo(
                source: source, book: book, canReName: false)
        }
    }

    /// toggleSkipUpdate（0x1004036b4 L759-764 域确证；"skipUpdate" L3989）。
    private func toggleSkipUpdate() {
        var updated = book
        updated.skipUpdate = !(updated.skipUpdate ?? false)
        bookService.updateBook(updated)
    }

    /// clearBookCache（0x1003fc0ec L768-770 域确证）。
    private func clearBookCache() {
        ChapterCacheService.shared.clearCache(bookUrl: book.bookUrl ?? "")
    }

    /// downloadAllChapters（0x1003fc6ec L774-780 域确证）。
    private func downloadAllChapters() {
        CacheDownloadManager.shared.start(
            book: book, bookService: bookService,
            chapterCache: ChapterCacheService.shared)
    }

    // MARK: 变量编辑器（0x1004120a0 L784-831 域确证）

    /// variableEditorSheet（0x1004120a0 L784-831 域确证）。
    private var variableEditorSheet: some View {
        NavigationStack {
            VStack(spacing: 12.0) {
                Text("源变量")
                    .appThemeText(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                TextEditor(text: $sourceVariableText)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 200.0)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .cornerRadius(8, antialiased: true)
                Button("保存") { saveSourceVariable() }
                    .buttonStyle(.borderedProminent)
                Spacer()
            }
            .padding(.all, 16.0)
            .navigationTitle("源变量")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { showVariableEditor = false }
                }
            }
        }
    }

    /// bookVariableEditorSheet（0x1003fab88 L835-882 域确证；
    /// "书籍变量 (bookVariable)" @ptr L10381 域确证）。
    private var bookVariableEditorSheet: some View {
        NavigationStack {
            VStack(spacing: 12.0) {
                Text("书籍变量 (bookVariable)")
                    .appThemeText(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                TextEditor(text: $bookVariableText)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 200.0)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .cornerRadius(8, antialiased: true)
                Button("保存") { saveBookVariable() }
                    .buttonStyle(.borderedProminent)
                Spacer()
            }
            .padding(.all, 16.0)
            .navigationTitle("书籍变量")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { showBookVariableEditor = false }
                }
            }
        }
    }

    /// saveSourceVariable（0x1004097d4 L886-893 域确证）。
    private func saveSourceVariable() {
        // TODO(T-501-01 交叉): RemoteBackendService.setVariable 写回。
        showVariableEditor = false
    }

    /// saveBookVariable（签名确证）。
    private func saveBookVariable() {
        var updated = book
        updated.variable = bookVariableText
        bookService.updateBook(updated)
        showBookVariableEditor = false
    }

    /// saveBingCoverLocally（0x1003faff4 L895-909 域确证）。
    private func saveBingCoverLocally(
        _ image: UIImage, bookId: String
    ) {
        guard let data = image.pngData() else { return }
        LocalBookCoverCache.shared.saveCover(data: data, for: bookId)
    }

    @Environment(\.dismiss) private var dismiss
}

extension CacheDownloadManager {

    /// 伪代码 0x1003f5f6c（L75）：总页数 varinit（计数器桩；进度条消费域）。
    var total: Int {
        totalCount
    }
}
// MARK: - T-1401-13/14 逐域补齐（书架操作桥域）

extension BookService {

    /// 伪代码 0x1003f54e8（L37-45，BookActionSheetView 域）：书架操作桥
    /// —— CacheDownloadRequest 简式章列表（useCache 域）。
    func getChapterList(for request: CacheDownloadRequest) async throws -> [Chapter] {
        try await getChapterList(
            bookSourceUrl: request.book.bookSourceUrl ?? "",
            bookUrl: request.book.bookUrl ?? "",
            bookName: request.book.name,
            needRefresh: false,
            useReplaceRule: request.useReplaceRule)
    }

    /// 伪代码 0x1003f5584（L52-62，BookActionSheetView 域）：书架操作桥
    /// —— CacheDownloadRequest 简式正文（index 域）。
    func getChapterContent(
        for request: CacheDownloadRequest, index: Int
    ) async throws -> ChapterContent {
        try await getChapterContent(
            for: request.book, index: index,
            useReplaceRule: request.useReplaceRule, type: nil)
    }
}


