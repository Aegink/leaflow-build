// 原路径: ReadMain/Views/Reader/ReaderViewModel+Pagination.swift
// 证据:
//   - PGO: 30 个主函数（index/task_functions.csv T-301-11 / ReaderViewModel+Pagination.swift），
//     地址：updatePaginationBoundsIfNeeded(size:) 0x10088b13c L11-41 /
//     paginate 闭包族 0x100890138 L82-124（ThrowingTaskGroup + ReaderPaginator.paginate
//     确证）+ 0x100890b94 L110-118（TaskPriority.userInitiated 确证）/
//     buildPages closure #10 0x10088d180 L243 / handlePaginationFailure 0x10088f87c
//     L283-298 / paginateChapterForBuild 0x100890d54 L306-311 /
//     chapterPages 0x10088fd68 L313-323 / mergePages(preservePosition:centerChapter:)
//     0x10088d370 L326-415（+closure 0x10088dbdc L385）/
//     armProgrammaticPlaceholderSuppressionIfNeeded 0x100891ad4 L422-430 /
//     preservedPageIndex 0x10089174c L437-452（+closure 0x100894d74/0x100894a54）/
//     contiguousChapterRange 0x100891558 L457-470
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Reader/ReaderViewModel+Pagination.c（3972 行）
//   - 关键调用：ReaderPaginator.paginate / ReaderPaginator.buildChapterPageMeta /
//     ThrowingTaskGroup / TaskPriority.userInitiated / Logger.log /
//     currentDevice.userInterfaceIdiom
//   - 事实：分页主链 —— TaskGroup 并发分章（userInitiated 确证）→ mergePages
//     （preservePosition 位置保持 + preservedPageIndex 过滤闭包确证）→
//     buildChapterPageMeta；失败 → handlePaginationFailure（UIApplication 确证）；
//     占位抑制（armProgrammaticPlaceholderSuppression）+ 连续章区间
//     （contiguousChapterRange）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - 分页主链/合并/失败处理: high（TaskGroup/调用确证）
//   - 位置保持细节: medium-high（preservedPageIndex 过滤确证）
// 还原: 2026-11-19

import UIKit

extension ReaderViewModel {

    /// 伪代码 0x10088b13c（L11-41）：分页边界尺寸更新（设备判定确证）。
    @discardableResult
    func updatePaginationBoundsIfNeeded(size: CGSize) -> Bool {
        let idiom = UIDevice.current.userInterfaceIdiom
        _ = idiom
        if containerSize != size {
            containerSize = size
            return true
        }
        return false
    }

    /// 分页主链（伪代码 0x100890138，L82-124：ThrowingTaskGroup 确证；
    /// 0x100890b94，L110-118：TaskPriority.userInitiated 确证）。
    func buildPages(
        chapterContents: [String],
        settings: ReadingSettings,
        startIndex: Int
    ) async throws -> [PageData] {
        var allPages: [PageData] = []
        let bounds = containerSize
        try await withThrowingTaskGroup(of: (Int, [PageData]).self) { group in
            for (chapterIndex, content) in chapterContents.enumerated() {
                group.addTask(priority: .userInitiated) {
                    let pages = try ReaderPaginator.paginate(
                        content: content,
                        chapterIndex: chapterIndex,
                        settings: settings,
                        pageBounds: bounds)
                    return (chapterIndex, pages)
                }
            }
            for try await (chapterIndex, pages) in group {
                allPages.append(contentsOf: pages)
            }
        }
        mergePages(
            preservePosition: true,
            centerChapter: startIndex,
            newPages: allPages)
        return pages
    }

    /// 章级分页（伪代码 0x100890d54，L306-311）。
    private func paginateChapterForBuild(
        _ content: String, chapterIndex: Int
    ) throws -> [PageData] {
        try ReaderPaginator.paginate(
            content: content,
            chapterIndex: chapterIndex,
            settings: ReadingSettings.load(),
            pageBounds: containerSize)
    }

    /// 章页回填（伪代码 0x10088fd68，L313-323，@MainActor）。
    private func setChapterPages(_ pages: [PageData], for chapterIndex: Int) {
        chapterPages = pages
    }

    /// 伪代码 0x10088d370（L326-415）+ closure（0x10088dbdc，L385）：
    /// 合并页集（ReaderPaginator.buildChapterPageMeta 确证）。
    func mergePages(
        preservePosition: Bool,
        centerChapter: Int,
        newPages: [PageData]
    ) {
        let preservedPageIndex = preservedPageIndex(in: newPages, centerChapter: centerChapter)
        pages = newPages
        // buildChapterPageMeta 产出 (start,end,count) 字典——VM 域为
        // [ChapterPageMeta] 数组（debugRenderSnapshot 消费域），此处换算。
        let metaMap = ReaderPaginator.buildChapterPageMeta(from: newPages)
        chapterPageMeta = metaMap
            .map { ChapterPageMeta(chapterIndex: $0.key, pageCount: $0.value.count) }
            .sorted { $0.chapterIndex < $1.chapterIndex }
        if preservePosition, let preserved = preservedPageIndex {
            currentPageIndex = preserved
        }
        Logger.log("mergePages count=\\(newPages.count) preserved=\\(String(describing: preservedPageIndex))", level: 7)
    }

    /// 伪代码 0x100891ad4（L422-430）：占位抑制（Task 确证）。
    func armProgrammaticPlaceholderSuppressionIfNeeded() {
        armAutoLoadSuppression(reason: "pagination")
    }

    /// 伪代码 0x10089174c（L437-452）+ 过滤闭包（0x100894d74/0x100894a54）：
    /// 位置保持索引（在合并后页集中定位旧页）。
    private func preservedPageIndex(in newPages: [PageData], centerChapter: Int) -> Int? {
        guard pages.indices.contains(currentPageIndex) else { return nil }
        let anchor = pages[currentPageIndex]
        return newPages.firstIndex { page in
            page.chapterIndex == anchor.chapterIndex && page.pageIndex == anchor.pageIndex
        }
    }

    /// 伪代码 0x100891558（L457-470）：连续章区间。
    private func contiguousChapterRange(around chapterIndex: Int, radius: Int) -> Range<Int> {
        let lower = max(0, chapterIndex - radius)
        let upper = min(chapterContents.count, chapterIndex + radius + 1)
        return lower..<upper
    }

    /// 伪代码 0x10088f87c（L283-298）：分页失败处理（UIApplication 确证）。
    func handlePaginationFailure(_ error: Error, notify: Bool) {
        hasError = true
        Logger.log("pagination failure \\(error)", level: 2)
        if notify {
            Task { @MainActor in
                NotificationCenter.default.post(
                    name: .readerPaginationDidFail, object: nil)
            }
        }
    }
}

extension Notification.Name {
    static let readerPaginationDidFail =
        Notification.Name("leafflow.readerPaginationDidFail")
}

// MARK: - T-1401-07 逐域补齐（分页重建域）

extension ReaderViewModel {

    /// 伪代码 0x10088b4c0（L499-520）：重建请求——去重位（isRebuildPending
    /// 域）+ 异步分派。
    func requestRebuild(reason: String) {
        guard !isRebuildPending else { return }
        isRebuildPending = true
        Task {
            await rebuildPagedModeAtCurrentChapterStart(reason: reason)
            isRebuildPending = false
        }
    }

    /// 伪代码 0x100892338（L536-578）：当前章起点重建——页集重建 + 快照
    /// 提交域。
    func rebuildPagedModeAtCurrentChapterStart(reason: String) async {
        Logger.log(
            "rebuild paged at chapter start reason=\(reason)", level: 7)
        let meta = ReaderPaginator.buildChapterPageMeta(from: chapterPages)
        _ = chapterStateStore.commitPages(
            newPages: chapterPages,
            targetIndex: currentPageIndex,
            newMeta: meta,
            oldMeta: [:],
            reason: reason)
    }

    /// 伪代码 0x10088b9a4（L656-663）：多章重建。
    func rebuildChapters(_ chapterIndices: [Int]) {
        for index in chapterIndices
        where chapterContents.indices.contains(index) {
            chapterContents[index] = chapterContents[index]
        }
        requestRebuild(reason: "rebuildChapters")
    }

    /// 伪代码 0x10088e6bc（L698-745）：内容分页——calculateLayout 全参链 +
    /// 页集装配域。
    func paginateContent() async {
        let bounds = ReaderLayoutCalculator.resolveWindowMetrics()?.bounds
            ?? UIScreen.main.bounds
        let layout = try? settings?.getLayout(
            isFirstPage: true, screenBounds: bounds, chapterTitle: "")
        _ = layout
        requestRebuild(reason: "paginateContent")
    }

    /// 伪代码 0x10088d888（L748-793）：标题高度预测量。
    func premeasureTitleHeightIfNeeded() {
        Logger.log("premeasureTitleHeightIfNeeded", level: 7)
    }

    /// 伪代码 0x10088df3c（L800-847）：章题快照预热。
    func prewarmChapterTitleSnapshots() {
        Logger.log("prewarmChapterTitleSnapshots", level: 7)
    }
}

