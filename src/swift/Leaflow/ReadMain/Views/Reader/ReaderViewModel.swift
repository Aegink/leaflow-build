// 原路径: ReadMain/Views/Reader/ReaderViewModel.swift
// 证据:
//   - PGO: 主类函数集（index/task_functions.csv T-301-10 / ReaderViewModel.swift）；
//     分册：+Loading（loadBookWithProgress 0x100875d24 L57-225 等）/+Navigation
//     （onPageIndexChanged 0x100886ce0 L9-54 等）/+Pagination/+Speech/+WebViewVerticalScroll
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Reader/ReaderViewModel.c 系列
//   - 事实（主类）：状态域 —— pages/chapterPages/chapterContents/chapterPageMeta/
//     currentChapterIndex/currentPageIndex/currentBookSource/menuVisible/
//     isLoadingPage/hasError/clearLoadingIndicator 族/autoLoadSuppression 族/
//     chapterCacheKey/activeReadAloudAnchor
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - 状态域/生命周期骨架: high（签名族确证）
//   - 事件分发细节: medium（各分册承载，待真机对照）
// 还原: 2026-11-19

import SwiftUI
import UIKit

/// 阅读器视图模型（@Observable；分册扩展承载各域）。
@Observable
@MainActor
final class ReaderViewModel {

    // MARK: 页面状态

    // wave-16：跨分册扩展（+Loading/+Navigation/+Pagination）有写入，
    // setter 由 private(set) 放宽到 internal（原始二进制无文件边界概念）。
    var pages: [PageData] = []
    var chapterPages: [PageData] = []
    var chapterContents: [String] = []
    var chapterPageMeta: [ChapterPageMeta] = []
    var currentChapterIndex = 0
    var currentPageIndex = 0
    private(set) var currentBookSource: BookSource?
    // T-1601-C0：本地阅读桥需要写入展示域（原 private(set) 阻止跨视图
    // 适配；与 pages 等字段同域放宽）。
    var bookName = ""
    var totalChapters = 0
    var currentBook: Book?
    var chapters: [Chapter] = []
    @ObservationIgnored var sourceService = SourceService.shared
    @ObservationIgnored lazy var bookService = BookService(sourceService: sourceService)
    @ObservationIgnored var replaceRuleService = ReplaceRuleService.shared
    // 固定样本可替换 I/O，仍执行生产装配、分页和导航链。
    var chapterListProvider: ((Book, Bool) async throws -> [Chapter])?
    var chapterContentProvider: ((Book, Int, Bool) async throws -> ChapterContent)?
    @ObservationIgnored var pageCommitHandler: ((ReaderPageCommit) -> Void)?

    func configure(book: Book, settings: ReadingSettings) {
        if currentBook?.bookUrl != book.bookUrl || currentBook?.bookSourceUrl != book.bookSourceUrl {
            paginationRevision &+= 1
            paginationRebuildTask?.cancel()
            paginationRebuildTask = nil
            isRebuildPending = false
        }
        currentBook = book
        bookName = book.name
        self.settings = settings
        if !sourceService.hasLoadedOnce && sourceService.bookSources.isEmpty {
            sourceService.quickLoadLocalSources()
        }
        currentBookSource = sourceService.bookSources.first {
            $0.bookSourceUrl == book.bookSourceUrl
        }
    }

    func refreshCurrentBookSource() async {
        await sourceService.loadLocalSources()
        currentBookSource = sourceService.bookSources.first { $0.bookSourceUrl == currentBook?.bookSourceUrl }
    }

    var currentPage: PageData? {
        pages.indices.contains(currentPageIndex) ? pages[currentPageIndex] : nil
    }

    /// 本章页区间（ReaderContentSurface 调用方确证）。
    var currentChapterPageRange: (start: Int, end: Int, count: Int) {
        let inChapter = pages.filter { $0.chapterIndex == currentChapterIndex }
        guard let first = inChapter.first?.pageIndex else { return (0, 0, 0) }
        return (first, inChapter.last?.pageIndex ?? first, inChapter.count)
    }

    var currentPageInChapter: Int {
        currentPage?.pageIndex ?? 0
    }

    // MARK: 加载/界面状态

    var isLoadingPage = false
    var hasError = false
    var menuVisible = false
    var menuToggleHandler: (() -> Void)?
    private(set) var speechHighlight = ReaderSpeechHighlight.none
    private(set) var colorVersion = 0
    var isRebuildPending = false
    @ObservationIgnored var paginationRebuildTask: Task<Void, Never>?
    @ObservationIgnored var paginationRevision: UInt64 = 0
    private(set) var pendingPageTurnCommand: ReaderPageTurnCommand?
    var containerSize: CGSize = .zero
    var paginationSafeAreaInsets: UIEdgeInsets = .zero

    var canCancelLoadingIndicator: Bool {
        isLoadingPage
    }

    private(set) var activeReadAloudAnchor: ReadAloudAnchor?
    func applyReadAloudAnchor(_ anchor: ReadAloudAnchor?) {
        activeReadAloudAnchor = anchor
        speechHighlight = ReaderSpeechHighlight(anchor: anchor, pages: pages)
    }
    private var autoLoadSuppressionReason: String?

    // MARK: - T-1401-05 逐域补齐（核心域）——状态成员归位（wave-16 修复：
    // 原错位于 struct ChapterPageMeta 体内，导致类体被劈开）

    /// 章节阅读访问 URL 集（0x100864a48 L87 varinit 域；块体含异步装配域
    /// swift_task_alloc 确证——默认空表 + 异步回填）。
    private(set) var chapterReaderAccessURLs: [Int: String] = [:]

    /// 章节加载状态表（ChapterLoadState 五 getter 域消费；跨分册扩展
    /// 有写入——setter 放宽到 internal）。
    var chapterLoadStates: [Int: ChapterLoadState] = [:]

    /// 语音会话准备标志（isSpeechPreparing 计算源；speech 分册联动域）。
    var speechSessionPreparing: Bool = false

    /// 在途章节加载集（loadChapterContent 去重域 ivar 确证）。
    var inFlightChapterLoads: Set<Int> = []

    /// 阅读设置引用（Navigation/Loading 分册消费域）。
    weak var settings: ReadingSettings?

    /// 初始重排请求（shouldConsumeInitialReaderRepaginationRequest 消费域）。
    var needsRepagination: Bool = false

    /// 章节状态存储（Loading/Pagination 分册共享域）。
    let chapterStateStore = ChapterStateStore()

    /// 初始加载任务句柄（initialLoad/runInitialLoadTask 去重域）。
    private var initialLoadTask: Task<Void, Never>?

    /// 书籍信息任务句柄（scheduleBookInfoIfNeeded/runBookInfoIfNeeded 去重域）。
    private var bookInfoTask: Task<Void, Never>?

    /// 章节加载层标题（showChapterLoadingIndicator 域）。
    private(set) var chapterLoadingTitle: String = ""

    // MARK: 生命周期

    init() {}

    /// 取消全部任务（骨架签名）。
    func cancelAllTasks() {
        paginationRevision &+= 1
        paginationRebuildTask?.cancel()
        paginationRebuildTask = nil
        isRebuildPending = false
        isLoadingPage = false
    }

    func cancelInitialLoad() {
        isLoadingPage = false
    }

    func canCancelChapterLoading() -> Bool {
        isLoadingPage
    }

    // MARK: 加载指示

    func clearLoadingIndicator() {
        isLoadingPage = false
    }

    func clearOperationLoadingIndicator() {
        isLoadingPage = false
    }

    func clearChapterLoadingIndicator(force: Bool) {
        if force || isLoadingPage {
            isLoadingPage = false
        }
    }

    // MARK: 自动加载抑制（armAutoLoadSuppression 族确证）

    func armAutoLoadSuppression(reason: String) {
        autoLoadSuppressionReason = reason
    }

    func clearAutoLoadSuppression(reason: String) {
        if autoLoadSuppressionReason == reason {
            autoLoadSuppressionReason = nil
        }
    }

    func consumeAutoLoadSuppressionIfNeeded(name: String) -> Bool {
        defer { autoLoadSuppressionReason = nil }
        return autoLoadSuppressionReason != nil
    }

    // MARK: 事件入口（Surface 调用方确证）

    func handleTap() {
        if let menuToggleHandler { menuToggleHandler(); return }
        menuVisible.toggle()
    }

    func handleSwipeUp() {}
    func handleSwipeUpDown() {}
    func handleSwipeUpProgress(_ state: ReaderGestureDismissState) {}
    func handleSwipeUpCancel() {}

    func handlePageCommitted(_ commit: ReaderPageCommit) {
        if let pageCommitHandler { pageCommitHandler(commit); return }
        guard commit.shouldApply(currentIndex: currentPageIndex, pageCount: pages.count) else {
            return
        }
        onPageIndexChanged(from: currentPageIndex, to: commit.index)
    }

    func handleCommentTap(_ comment: ParagraphComment, pageIndex: Int) {}

    func containerSizeChanged(from oldSize: CGSize, to newSize: CGSize,
                              safeAreaInsets: UIEdgeInsets = .zero) {
        let insetsChanged = paginationSafeAreaInsets != safeAreaInsets
        paginationSafeAreaInsets = safeAreaInsets
        let sizeChanged = updatePaginationBoundsIfNeeded(size: newSize)
        if (sizeChanged || insetsChanged), !pages.isEmpty, pageCommitHandler == nil {
            requestRebuild(reason: "阅读区域变化")
        }
    }

    /// 章节缓存键（骨架签名）。
    var chapterCacheKey: String {
        "\(bookName)#\(currentChapterIndex)"
    }
}

/// 章节页元信息（chapterPageMeta 元素）。
/// wave-16 修复：原 T-1401-05 批量成员错位于此 struct 体内（类体被劈开），
/// 状态成员已归位 ReaderViewModel 类体，方法域归位 extension。
struct ChapterPageMeta {
    let chapterIndex: Int
    let pageCount: Int
}

// MARK: - T-1401-05 逐域补齐（行为域）——方法归位 extension

extension ReaderViewModel {

    /// 伪代码 0x100886a8c（L128）：已加载章节索引集（计数器桩；
    /// 按 chapterContents 非空推导）。
    var loadedChapterIndices: Set<Int> {
        Set(chapterContents.indices.filter { !chapterContents[$0].isEmpty })
    }

    /// 伪代码 0x100863ea4（L319）：语音准备中判定（计数器桩；会话标志联动）。
    var isSpeechPreparing: Bool {
        readAloudCoordinator.owns(self) && readAloudCoordinator.isPreparing
    }

    /// 伪代码 0x100864f70（L373-384）：章节状态调试标签。
    func debugChapterStateLabel() -> String {
        "chapters: \(currentChapterIndex + 1)/\(totalChapters)"
            + " loaded=\(loadedChapterIndices.count)"
            + " error=\(hasError)"
    }

    /// 伪代码 0x10086521c（L386-389）：页调试标签。
    func debugPageLabel() -> String {
        "page: \(currentPageIndex + 1)/\(pages.count)"
            + " ch=\(currentChapterIndex)"
    }

    /// 伪代码 0x100865418（L395-407）：渲染快照调试串。
    func debugRenderSnapshot() -> String {
        let meta = chapterPageMeta
            .map { "\($0.chapterIndex):\($0.pageCount)" }
            .joined(separator: ",")
        return "pages=\(pages.count) meta=[\(meta)] size=\(containerSize)"
    }

    /// 伪代码 0x100865918（L409-413）：操作级加载指示。
    func showOperationLoadingIndicator() {
        isLoadingPage = true
    }

    /// 伪代码 0x100865950（L415-423）：章节级加载指示（标题绑定层）。
    func showChapterLoadingIndicator(title: String) {
        isLoadingPage = true
        chapterLoadingTitle = title
    }

    /// 伪代码 0x100865bec（L474-485）：加载层点击处理（canCancel 分支域）。
    func handleLoadingIndicatorTap() {
        if canCancelLoadingIndicator {
            clearLoadingIndicator()
        }
    }

    /// 伪代码 0x1008661f8（L503-514）：初始加载任务体。
    func runInitialLoadTask() async {
        isLoadingPage = true
        await runBookInfoIfNeeded()
        isLoadingPage = false
    }

    /// 伪代码 0x100866914（L553-581）：初始加载编排（任务去重域）。
    func initialLoad() {
        guard initialLoadTask == nil else { return }
        initialLoadTask = Task { [weak self] in
            await self?.runInitialLoadTask()
            self?.initialLoadTask = nil
        }
    }

    /// 伪代码 0x100866448（L525-541）：加载指示与可见页同步
    ///（visiblePage 命中即收敛指示层域）。
    func syncChapterLoadingIndicatorWithVisiblePage() {
        guard isLoadingPage else { return }
        if currentPage != nil {
            clearChapterLoadingIndicator(force: false)
        }
    }

    /// 伪代码 0x100867114（L583-598）：缓存书籍呈现准备（页集就绪 → 收敛
    /// 指示层）。
    func prepareCachedBookForPresentation() {
        guard !pages.isEmpty else { return }
        isLoadingPage = false
    }

    /// 伪代码 0x1008675f8（L609-622）：书籍信息调度（任务去重域）。
    func scheduleBookInfoIfNeeded() {
        guard bookInfoTask == nil else { return }
        bookInfoTask = Task { [weak self] in
            await self?.runBookInfoIfNeeded()
            self?.bookInfoTask = nil
        }
    }

    /// 伪代码 0x100867b58（L628-681）：书籍信息加载体（书名/总章数回填域；
    /// 详情域随书源管线对齐）。
    func runBookInfoIfNeeded() async {
        guard bookName.isEmpty else { return }
        // 书名/总章数回填域：详情请求随书源管线落地（记入仍不清楚）。
    }

    /// 伪代码 0x100868640（L684-693）：加书架提示判定（本地导入 + 非书架域）。
    func shouldPromptAddToBookshelf(
        bookInShelf: Bool, isLocalImport: Bool
    ) -> Bool {
        !bookInShelf && isLocalImport
    }

    /// 伪代码 0x100862ef8（L287-299）：段评图片动作执行——AnalyzeRule
    /// (source:parent:) 域确证 + clickActionScript 执行域。
    static func executeParagraphImageAction(
        _ comment: ParagraphComment,
        source: BookSource,
        book: Book,
        chapter: Chapter
    ) {
        guard let script = comment.clickActionScript, !script.isEmpty else {
            return
        }
        let rule = AnalyzeRule(source: source, parent: nil)
        // 正文内容注入：Chapter 无 content 成员——规则上下文正文随阅读
        // 会话管线对齐（记入仍不清楚；暂以空串维持求值域结构）。
        rule.setContent("", baseUrl: "")
        rule.putVariable("commentImage", value: comment.imageSource)
        _ = rule.safeEvaluateScript(
            script, timeout: 15.0, convertLegadoTemplates: true)
    }

    /// 伪代码 0x1008639d4（L301-316）：段评点击处理——图片源 → 动作执行域；
    /// 纯文本 → 浮层路由（comment 浮层随 T-303 域）。
    func handleParagraphCommentTap(_ comment: ParagraphComment, pageIndex: Int) {
        guard let source = currentBookSource else { return }
        guard !comment.imageSource.isEmpty else { return }
        // 章节正文源（chapterContents 域）+ 书源域组装；书籍/章节实体随
        // 阅读会话管线注入（executeParagraphImageAction 调用域）。
        var chapter = Chapter(
            name: "", url: "", index: pageIndex, isRead: true,
            isPay: nil, resourceUrl: nil, isVip: false, isVolume: false,
            updateTime: nil, wordCount: nil, variable: nil)
        _ = chapter
        let book = Book()
        Self.executeParagraphImageAction(comment, source: source, book: book, chapter: chapter)
    }
}

// MARK: - T-1401-05 逐域补齐（状态与判定域）

/// 章节加载状态（ChapterLoadState 五 getter 域确证：loadedText/loadedComments/
/// isLoaded/isError/isLoadedNonEmpty；档位推断）。
enum ChapterLoadState {
    case idle
    case loading(String)
    case loaded(String, [ParagraphComment])
    case failed(String)

    /// 伪代码 0x100643ee8（L25-28）：已加载正文。
    var loadedText: String? {
        if case .loaded(let text, _) = self { return text }
        return nil
    }

    /// 伪代码 0x10064385c（L30-33）：已加载段评。
    var loadedComments: [ParagraphComment]? {
        if case .loaded(_, let comments) = self { return comments }
        return nil
    }

    /// 伪代码 0x100643718（L40-43，ICF 副本 1）：加载完成判定。
    var isLoaded: Bool {
        if case .loaded = self { return true }
        return false
    }

    /// 伪代码 0x100644ea4（L45-48）：失败判定。
    var isError: Bool {
        if case .failed = self { return true }
        return false
    }

    /// 伪代码 0x100861e7c（L51-54）：非空完成判定。
    var isLoadedNonEmpty: Bool {
        loadedText?.isEmpty == false
    }
}

/// 伪代码 0x10086198c（L8-13）：初始重排请求消费判定——needsRepagination
/// 且页集非空（payload 计数域确证）。
func shouldConsumeInitialReaderRepaginationRequest(
    needsRepagination: Bool, pages: [PageData]
) -> Bool {
    guard needsRepagination else { return false }
    return !pages.isEmpty
}
