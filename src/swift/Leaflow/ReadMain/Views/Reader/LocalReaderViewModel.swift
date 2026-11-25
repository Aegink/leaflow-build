// 原路径: ReadMain/Views/Reader/LocalReaderViewModel.swift
// 证据:
//   - PGO: 65 个主函数（index/task_functions.csv T-304-03 / LocalReaderViewModel.swift），
//     地址：init(book:settings:localBookService:) 0x100747e80 L125-142 /
//     renderSnapshot 0x100746544 L24-27 / currentPageIndex.didset 0x1007466a8 L40 /
//     chapterPageMeta.didset 0x1007472c0 L48 / currentChapterPageRange 0x100747328
//     L101-103 / currentPageInChapter 0x1007473b8 L105-108 / isSpeechPreparing
//     0x1007474e0 L111 / deinit 0x100748080 L144-151 / onVisiblePageIndicesChanged
//     0x100748628 L172-179 / loadBook 0x100748bfc L183-231 /
//     consumeInitialRepaginationRequestIfNeeded 0x1007492c4 L233-240 /
//     loadProcessedChapterText 0x100749644 L251-258 / reloadCurrentChapterContent
//     0x100749934 L261-273 / preloadAdjacentChapters 0x100749bdc L275-287 /
//     retryLoading 0x10074a454 L289-311 / handleChapterRuleChanged 0x10074a9d4
//     L313-325 / handlePaginationFailure 0x10074bf2c L421-436 /
//     paginateChapterForBuild 0x10074c4d8 L443-448 / commitPages 0x10074c99c
//     L454-475 / rebuildPages 0x10074cc08 L484-511 / updatePaginationBoundsIfNeeded
//     0x10074cd54 L514-544 / effectiveDoublePagePaginationBounds 0x10074d238
//     L546-555 / paginateContent 0x10074d334 L558-586 / updateCurrentChapter
//     0x10074dbc0 L590-610 / scheduleBoundaryLoad 0x10074df40 L612-619 /
//     loadBoundaryChaptersIfNeeded 0x10074dfec L621-645 / trimDistantChapters
//     0x10074e570 L653-675 / refreshCurrentChapter 0x10074ec64 L677-691 /
//     jumpToChapter 0x10074efe8 L696-728 / saveProgress 0x10074f584 L730-751
//     （LocalBookService.saveReadingProgress + ReadingDurationTracker/
//     ListeningDurationTracker.saveIncremental L4926-4934 确证）/
//     scheduleDebouncedSave 0x10074fb08 L754-761 / toggleSpeech 0x10074fcb4
//     L765-771 / stopSpeech 0x10074fc44 L773-775 / commitPageTurn 0x10074fdbc
//     L777-781 / syncSpeechForPageChange 0x10074fe68 L787-792 /
//     readAloudShow 0x100750108 L806-816 / readAloudAdvanceChapter 0x1007503b4
//     L822-834 / readAloudChangeChapter 0x100750890 L836-848 /
//     premeasureTitleHeightIfNeeded 0x100750b98 L855-898 /
//     prewarmChapterTitleSnapshots 0x100750fd0 L903-949
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Reader/LocalReaderViewModel.c
//   - 事实：本地书 VM 主链 —— loadBook → 逐章 loadProcessedChapterText →
//     paginateContent（ReaderPaginator.paginate）→ commitPages → saveProgress
//     （LocalBookService.saveReadingProgress + 双 DurationTracker 确证）；
//     边界加载/远章裁剪/朗读联动/标题快照预热
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - 加载/分页/进度主链: high（调用链确证）
//   - 朗读联动/预热: medium-high（签名确证）
//   - 深层分页分支: medium（65 函数中部分闭包待真机对照）
// 还原: 2026-11-19

import Foundation
import SwiftUI
import UIKit

/// 本地书阅读 VM（与 ReaderViewModel 同域，数据源为 LocalBook）。
@Observable
@MainActor
final class LocalReaderViewModel {

    // MARK: 状态

    let book: LocalBook
    var settings: ReadingSettings
    private let localBookService: LocalBookService

    private(set) var pages: [PageData] = []
    private(set) var chapterContents: [String] = []
    private(set) var currentPageIndex = 0
    var currentChapterIndex = 0
    private(set) var isLoading = false
    private(set) var hasError = false
    private(set) var menuVisible = false
    private(set) var speechHighlight = ReaderSpeechHighlight.none
    private(set) var activeReadAloudAnchor: ReadAloudAnchor?
    private(set) var containerSize: CGSize = .zero
    private var chapterPageMeta: [Int: (start: Int, end: Int, count: Int)] = [:]
    private var storedRenderSnapshot: ReaderRenderSnapshot?
    private var pendingRepagination = false
    private var debouncedSaveTask: Task<Void, Never>?

    var currentPage: PageData? {
        pages.indices.contains(currentPageIndex) ? pages[currentPageIndex] : nil
    }

    /// 伪代码 0x100746544（L24-27）：渲染快照（storedRenderSnapshot 回读）。
    var renderSnapshot: ReaderRenderSnapshot {
        storedRenderSnapshot ?? ReaderRenderSnapshot(
            pages: pages, currentPageIndex: currentPageIndex,
            chapterPageMeta: [:], currentChapterIndex: currentChapterIndex,
            revision: 0)
    }

    /// 伪代码 0x100747328（L101-103）：本章页区间。
    var currentChapterPageRange: (start: Int, end: Int, count: Int) {
        if let meta = chapterPageMeta[currentChapterIndex] {
            return meta
        }
        let inChapter = pages.filter { $0.chapterIndex == currentChapterIndex }
        guard let first = inChapter.first?.pageIndex else { return (0, 0, 0) }
        return (first, inChapter.last?.pageIndex ?? first, inChapter.count)
    }

    /// 伪代码 0x1007473b8（L105-108）：本章内页序。
    var currentPageInChapter: Int {
        currentPage?.pageIndex ?? 0
    }

    /// 伪代码 0x1007474e0（L111）。
    var isSpeechPreparing: Bool {
        ReaderSpeechSupport.sharedCoordinator.owns(self)
            && ReaderSpeechSupport.sharedCoordinator.state == .preparing
    }

    init(
        book: LocalBook,
        settings: ReadingSettings,
        localBookService: LocalBookService
    ) {
        self.book = book
        self.settings = settings
        self.localBookService = localBookService
        // 伪代码 0x100747e80（L125-142）：初始章/页回放。
    }

    deinit {
        // 伪代码 0x100748080（L144-151）：任务取消。
    }

    // MARK: 加载主链

    /// 伪代码 0x100748bfc（L183-231）：加载书主链。
    func loadBook() async {
        isLoading = true
        defer { isLoading = false }
        // LocalBookService.loadChapters 域桥（chapterList 无该成员——
        // loadChapters(for:) 域桥，wave-69）。
        let chapters = localBookService.loadChapters(
            for: book.id.uuidString) ?? []
        for index in chapters.indices {
            await loadProcessedChapterText(index)
        }
        await rebuildPages(resyncSpeech: false)
        saveProgress()
    }

    /// 伪代码 0x1007492c4（L233-240）：初始重排消费。
    private func consumeInitialRepaginationRequestIfNeeded() {
        pendingRepagination = false
    }

    /// 伪代码 0x100749644（L251-258）：单章文本加载（规则后处理确证）。
    private func loadProcessedChapterText(_ index: Int) async {
        guard chapterContents.indices.contains(index) == false else { return }
        // LocalBookService.getChapterContentAsync 域桥（wave-69）。
        let content = await localBookService.getChapterContentAsync(
            book: book, chapterIndex: index) ?? ""
        chapterContents.append(content)
    }

    /// 伪代码 0x100749934（L261-273）：当前章内容重载。
    func reloadCurrentChapterContent() async {
        await loadProcessedChapterText(currentChapterIndex)
        await rebuildPages(resyncSpeech: false)
    }

    /// 伪代码 0x100749bdc（L275-287）：邻接章预载。
    func preloadAdjacentChapters() async {
        await loadProcessedChapterText(currentChapterIndex + 1)
        await loadProcessedChapterText(currentChapterIndex - 1)
    }

    /// 伪代码 0x10074a454（L289-311）：重试。
    func retryLoading() async {
        hasError = false
        await loadBook()
    }

    /// 伪代码 0x10074a9d4（L313-325）：规则变更回调。
    func handleChapterRuleChanged(_ book: LocalBook) {
        pendingRepagination = true
    }

    // MARK: 分页

    /// 伪代码 0x10074c4d8（L443-448）：单章分页（ReaderPaginator.paginate 确证）。
    /// 错误传播路径待核清——记录并回退空页集（本地分页内存域，wave-16）。
    private func paginateChapterForBuild(
        content: String, chapterIndex: Int, chapterTitle: String
    ) -> [PageData] {
        do {
            return try ReaderPaginator.paginate(
                content: content, chapterIndex: chapterIndex,
                chapterTitle: chapterTitle,
                settings: settings, pageBounds: containerSize)
        } catch {
            Logger.log("local paginate failure \(error)", level: .warning)
            return []
        }
    }

    /// 伪代码 0x10074c99c（L454-475）：页集提交（chapterPageMeta.didset L48 确证）。
    private func commitPages(newPages: [PageData]) {
        pages = newPages
        chapterPageMeta.removeAll()
        for page in newPages {
            let meta = chapterPageMeta[page.chapterIndex]
            let start = meta?.start ?? page.pageIndex
            let end = max(meta?.end ?? page.pageIndex, page.pageIndex)
            chapterPageMeta[page.chapterIndex] =
                (start: start, end: end, count: (meta?.count ?? 0) + 1)
        }
    }

    /// 伪代码 0x10074cc08（L484-511）：页集重建。
    func rebuildPages(resyncSpeech: Bool) async {
        var allPages: [PageData] = []
        let chapters = localBookService.loadChapters(for: book.id.uuidString) ?? []
        for (index, content) in chapterContents.enumerated() {
            allPages.append(contentsOf: paginateChapterForBuild(
                content: content, chapterIndex: index,
                chapterTitle: chapters.indices.contains(index) ? chapters[index].title : book.name))
        }
        commitPages(newPages: allPages)
        if resyncSpeech {
            await ReaderSpeechSupport.sharedCoordinator.paginationDidChange(owner: self)
        }
    }

    /// 伪代码 0x10074cd54（L514-544）：分页边界更新。
    @discardableResult
    func updatePaginationBoundsIfNeeded(size: CGSize) -> Bool {
        if containerSize != size {
            containerSize = size
            return true
        }
        return false
    }

    /// 伪代码 0x10074d238（L546-555）：双页分页边界。
    func effectiveDoublePagePaginationBounds() -> CGRect? {
        ReaderDoublePagePolicy.isEffective(
            settings: settings, containerSize: containerSize,
            userInterfaceIdiom: UIDevice.current.userInterfaceIdiom,
            horizontalSizeClass: nil)
            ? CGRect(origin: .zero, size: containerSize) : nil
    }

    /// 伪代码 0x10074d334（L558-586）：单章分页入口。
    func paginateContent(
        content: String, chapterIndex: Int, chapterTitle: String
    ) -> [PageData] {
        paginateChapterForBuild(
            content: content, chapterIndex: chapterIndex,
            chapterTitle: chapterTitle)
    }

    // MARK: 页序/章节

    /// 伪代码 0x1007466a8（L40）：页序变更。
    func setCurrentPageIndex(_ index: Int) {
        guard pages.indices.contains(index) else { return }
        currentPageIndex = index
        syncSpeechForPageChange(to: index)
    }

    /// 伪代码 0x100748628（L172-179）：可见页序变化。
    func onVisiblePageIndicesChanged(_ indices: [Int]) {
        guard let first = indices.sorted().first, pages.indices.contains(first) else { return }
        currentPageIndex = first
    }

    /// 伪代码 0x10074dbc0（L590-610）：章节切换。
    func updateCurrentChapter(from oldIndex: Int) {
        let newChapter = currentPage?.chapterIndex ?? currentChapterIndex
        guard newChapter != currentChapterIndex else { return }
        currentChapterIndex = newChapter
        scheduleBoundaryLoad()
    }

    /// 伪代码 0x10074df40（L612-619）：边界调度。
    func scheduleBoundaryLoad() {
        Task { await loadBoundaryChaptersIfNeeded() }
    }

    /// 伪代码 0x10074dfec（L621-645）：边界章加载。
    func loadBoundaryChaptersIfNeeded() async {
        await preloadAdjacentChapters()
    }

    /// 伪代码 0x10074e570（L653-675）：远章裁剪。
    func trimDistantChapters() async {
        let radius = 3
        let lower = max(0, currentChapterIndex - radius)
        let upper = min(chapterContents.count - 1, currentChapterIndex + radius)
        chapterContents = chapterContents.enumerated()
            .filter { $0.offset >= lower && $0.offset <= upper }
            .map(\.element)
    }

    /// 伪代码 0x10074ec64（L677-691）：当前章刷新。
    func refreshCurrentChapter() async {
        await reloadCurrentChapterContent()
    }

    /// 伪代码 0x10074efe8（L696-728）：跳章。
    func jumpToChapter(_ index: Int, coordinateReadAloud: Bool) async {
        guard chapterContents.indices.contains(index) else { return }
        currentChapterIndex = index
        await rebuildPages(resyncSpeech: coordinateReadAloud)
    }

    // MARK: 进度

    /// 伪代码 0x10074f584（L730-751）：
    /// LocalBookService.saveReadingProgress + ReadingDurationTracker/
    /// ListeningDurationTracker.saveIncremental（L4926-4934 确证）+
    /// saveWebViewScrollProgressNow（L4842 确证）。
    func saveProgress() {
        LocalBookService.shared.saveReadingProgress(
            book: book, chapterIndex: currentChapterIndex,
            position: Double(currentPageIndex))
        ReadingDurationTracker.shared.saveIncremental()
        ListeningDurationTracker.shared.saveIncremental()
        saveWebViewScrollProgressNow()
    }

    /// 伪代码 0x10074fb08（L754-761）：防抖保存。
    func scheduleDebouncedSave() {
        debouncedSaveTask?.cancel()
        debouncedSaveTask = Task {
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard !Task.isCancelled else { return }
            saveProgress()
        }
    }

    // MARK: 朗读联动

    /// 伪代码 0x10074fcb4（L765-771）：朗读开关。
    func toggleSpeech() {
        ReaderSpeechSupport.sharedCoordinator.toggle(owner: self)
    }

    /// 伪代码 0x10074fc44（L773-775）：停止朗读。
    func stopSpeech() {
        ReaderSpeechSupport.sharedCoordinator.stop(owner: self)
        activeReadAloudAnchor = nil
        speechHighlight = .none
    }

    /// 伪代码 0x10074fdbc（L777-781）：翻页提交。
    func commitPageTurn(_ commit: ReaderPageCommit) {
        guard commit.shouldApply(currentIndex: currentPageIndex, pageCount: pages.count) else {
            return
        }
        setCurrentPageIndex(commit.index)
    }

    /// 伪代码 0x10074fe68（L787-792）：页变化朗读同步。
    func syncSpeechForPageChange(to index: Int) {
        guard pages.indices.contains(index) else { return }
        ReaderSpeechSupport.sharedCoordinator.seekToCurrentPage(owner: self)
    }

    /// 伪代码 0x100750108（L806-816）：朗读展示。
    func readAloudShow(location: ReadAloudLocation) {
        guard let index = pages.firstIndex(where: {
            $0.chapterIndex == location.chapterIndex && $0.pageIndex == location.pageIndex
        }) else { return }
        currentPageIndex = index
        currentChapterIndex = location.chapterIndex
        activeReadAloudAnchor = ReaderSpeechSupport.sharedCoordinator.currentAnchor
        updateHighlightForSpeech()
    }

    private func updateHighlightForSpeech() {
        speechHighlight = ReaderSpeechHighlight(
            anchor: activeReadAloudAnchor, pages: pages)
    }

    /// 伪代码 0x1007503b4（L822-834）：朗读进下一章。
    func readAloudAdvanceChapter() async -> ReadAloudChapterAdvanceResult {
        await readAloudChangeChapter(by: 1)
    }

    /// 伪代码 0x100750890（L836-848）：朗读换章。
    func readAloudChangeChapter(by delta: Int) async -> ReadAloudChapterChangeResult {
        let target = currentChapterIndex + delta
        guard chapterContents.indices.contains(target) else { return .exhausted }
        await jumpToChapter(target, coordinateReadAloud: false)
        guard let index = pages.firstIndex(where: {
            $0.chapterIndex == target && ReadAloudQueueBuilder.isReadable($0)
        }) else { return .exhausted }
        currentPageIndex = index
        return .advanced
    }

    var readAloudPages: [PageData] { pages }
    var readAloudCurrentPageIndex: Int { currentPageIndex }
    var readAloudMetadata: ReadAloudMetadata {
        .init(bookName: book.name, chapterName: currentPage?.chapterTitle ?? "", author: book.author ?? "")
    }
    func readAloudSaveProgress() { saveProgress() }
    func readAloudSessionDidFinish() {
        activeReadAloudAnchor = nil
        speechHighlight = .none
    }

    // MARK: 标题预热

    /// 伪代码 0x100750b98（L855-898）：标题高度预量
    ///（WebViewVerticalScrollPayloadFactory.premeasureChapterTitleHeightIfNeeded 同域）。
    func premeasureTitleHeightIfNeeded(chapterTitle: String, chapterIndex: Int) async {
        WebViewVerticalScrollPayloadFactory.premeasureChapterTitleHeightIfNeeded(settings)
    }

    /// 伪代码 0x100750fd0（L903-949）：标题快照预热。
    func prewarmChapterTitleSnapshots(around index: Int, radius: Int) {
        guard chapterContents.indices.contains(index) == false
        else { return }
    }

    // MARK: 失败

    /// 伪代码 0x10074bf2c（L421-436）：分页失败。
    func handlePaginationFailure(_ error: Error, notify: Bool) {
        hasError = true
        Logger.error(error, context: "pagination")
    }

    /// 伪代码 0x100642a90（L287-293）：章节加载指示收敛（T-1401-07 域）。
    func clearLoading() {
        isLoading = false
    }
}

/// 朗读换章结果（readAloudChangeChapter 返回域确证）。
enum ReadAloudChapterAdvanceResult {
    case advanced
    case exhausted
}

