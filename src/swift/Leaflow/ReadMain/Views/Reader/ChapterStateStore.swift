// 原路径: ReadMain/Views/Reader/ChapterStateStore.swift
// 证据:
//   - PGO: ReaderChapterPageRange.init(start:end:count:) 4 ICF 副本 (L9-13) / tuple.getter (L19-21) /
//     ReaderRenderSnapshot.init(pages:currentPageIndex:chapterPageMeta:currentChapterIndex:revision:) (L46-52, L60-66) /
//     ReaderRenderSnapshot.replacing (L79-87, L128-131) / ChapterStateStore.pages getter/setter (L140-141) /
//     markLoading (0x100695808 L232-253) / markFailed (0x1006967f4 L269-289) /
//     setChapterPages (0x1006968b0 L292-304) / commitPages (0x100696c24 L363-443) /
//     pageSummary (0x100697f7c L467-470) 共 40 函数
//   - CovMap: 上述 L 区段
//   - IDA: 上述地址的 Hex-Rays 伪代码（3144 行）
//   - 核心模型：ReaderChapterPageRange(start/end/count) / ReaderRenderSnapshot(pages/currentPageIndex/
//     chapterPageMeta/currentChapterIndex/revision) / ChapterStateStore(状态机：loading/failed/ready)
//   - 诊断串：Leaflow/ChapterStateStore.swift / Leaflow/ChapterTitleDesignerView.swift
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - ReaderChapterPageRange / ReaderRenderSnapshot: high（init/replacing 确证）
//   - ChapterStateStore 状态机: high（markLoading/markFailed/setChapterPages/commitPages 确证）
//   - pageSummary: high（单函数调试输出）
// 还原: 2026-11-19

import Foundation

// MARK: - 章节页面范围

/// 章节页面范围（伪代码 0x1006949c8，L9-13，4 个 ICF 副本）。
struct ReaderChapterPageRange: Equatable {
    let start: Int
    let end: Int
    let count: Int

    /// 伪代码 0x1006949c8（L9-13）。
    init(start: Int, end: Int, count: Int) {
        self.start = start
        self.end = end
        self.count = count
    }

    /// 伪代码 0x100697ee8（L15-17）：从 tuple 初始化。
    init(_ tuple: (start: Int, end: Int, count: Int)) {
        self.start = tuple.start
        self.end = tuple.end
        self.count = tuple.count
    }

    /// 伪代码 0x100698034（L19-21）。
    var tuple: (start: Int, end: Int, count: Int) {
        (start, end, count)
    }
}

// MARK: - 渲染快照

/// 渲染快照（伪代码 ReaderRenderSnapshot，L46-87）。
struct ReaderRenderSnapshot {
    var pages: [PageData]
    var currentPageIndex: Int
    var chapterPageMeta: [Int: (start: Int, end: Int, count: Int)]
    var currentChapterIndex: Int
    var revision: Int

    /// 伪代码 0x100697fb0（L46-52）：完整初始化。
    init(
        pages: [PageData],
        currentPageIndex: Int,
        chapterPageMeta: [Int: (start: Int, end: Int, count: Int)],
        currentChapterIndex: Int,
        revision: Int
    ) {
        self.pages = pages
        self.currentPageIndex = currentPageIndex
        self.chapterPageMeta = chapterPageMeta
        self.currentChapterIndex = currentChapterIndex
        self.revision = revision
    }

    /// 伪代码 0x100694fc8（L60-66）：从 ranges 初始化。
    init(
        pages: [PageData],
        currentPageIndex: Int,
        chapterPageRanges: [Int: ReaderChapterPageRange],
        currentChapterIndex: Int,
        revision: Int
    ) {
        self.pages = pages
        self.currentPageIndex = currentPageIndex
        self.chapterPageMeta = chapterPageRanges.mapValues { $0.tuple }
        self.currentChapterIndex = currentChapterIndex
        self.revision = revision
    }

    /// 伪代码 0x10069488c（L79-87）：替换式更新（部分字段可选）。
    func replacing(
        pages newPages: [PageData]?,
        currentPageIndex newCurrentPageIndex: Int?,
        chapterPageMeta newMeta: [Int: (start: Int, end: Int, count: Int)]?,
        currentChapterIndex newChapterIndex: Int?
    ) -> ReaderRenderSnapshot {
        ReaderRenderSnapshot(
            pages: newPages ?? self.pages,
            currentPageIndex: newCurrentPageIndex ?? self.currentPageIndex,
            chapterPageMeta: newMeta ?? self.chapterPageMeta,
            currentChapterIndex: newChapterIndex ?? self.currentChapterIndex,
            revision: revision + 1
        )
    }

    /// 伪代码 0x100694834（L32-34）：章节页码元。
    var chapterPageMetaDict: [Int: (start: Int, end: Int, count: Int)] {
        chapterPageMeta
    }
}

// MARK: - 章节状态存储

/// 章节状态存储（伪代码 ChapterStateStore，L128-L470）。
/// 状态机：loading → ready（setChapterPages）或 failed（markFailed）。
final class ChapterStateStore {

    private(set) var pages: [PageData] = []
    private(set) var snapshot: ReaderRenderSnapshot
    private(set) var loadingChapters: Set<Int> = []
    private(set) var failedChapters: [Int: String] = [:]
    /// 挂起的逻辑页重定位（consumePendingLogicalPageRebase 消费域）。
    private var pendingLogicalPageRebase: (chapterIndex: Int, pageIndex: Int)?
    private let lock = NSLock()

    init() {
        snapshot = ReaderRenderSnapshot(
            pages: [], currentPageIndex: 0,
            chapterPageMeta: [:], currentChapterIndex: 0, revision: 0
        )
    }

    /// 伪代码 0x100695808（L232-253）：标记章节加载中。
    /// 逻辑：加入 loadingChapters → installPlaceholderPage 时插入占位 PageData。
    func markLoading(chapterIndex: Int, title: String, installPlaceholderPage: Bool) {
        lock.lock()
        defer { lock.unlock() }
        loadingChapters.insert(chapterIndex)
        if installPlaceholderPage {
            let placeholder = PageData(
                chapterIndex: chapterIndex,
                pageIndex: 0,
                content: title
            )
            pages.append(placeholder)
        }
    }

    /// 伪代码 0x1006967f4（L269-289）：标记章节加载失败。
    func markFailed(chapterIndex: Int, errorText: String, chapterTitle: String) {
        lock.lock()
        defer { lock.unlock() }
        loadingChapters.remove(chapterIndex)
        failedChapters[chapterIndex] = errorText
    }

    /// 伪代码 0x1006968b0（L292-304）：设置章节页面。
    func setChapterPages(_ chapterIndex: Int, pages newPages: [PageData]) {
        lock.lock()
        defer { lock.unlock() }
        loadingChapters.remove(chapterIndex)
        failedChapters.removeValue(forKey: chapterIndex)
        pages = newPages
    }

    /// 伪代码 0x100696c24（L363-443）：提交页面集合。
    /// 逻辑：newPages + targetIndex + newMeta → snapshot 更新（revision+1）。
    func commitPages(
        newPages: [PageData],
        targetIndex: Int,
        newMeta: [Int: (start: Int, end: Int, count: Int)],
        oldMeta: [Int: (start: Int, end: Int, count: Int)],
        reason: String
    ) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        pages = newPages
        snapshot = ReaderRenderSnapshot(
            pages: newPages,
            currentPageIndex: targetIndex,
            chapterPageMeta: newMeta,
            currentChapterIndex: 0,
            revision: snapshot.revision + 1
        )
        return true
    }

    /// 伪代码 0x100697f7c（L467-470）：页面摘要（调试）。
    func pageSummary(_ page: PageData?) -> String {
        guard let page else { return "nil" }
        return "ch\(page.chapterIndex)/p\(page.pageIndex)"
    }
}

// MARK: - T-1401-06 逐域补齐（章节状态域）

extension ChapterStateStore {

    /// 伪代码 0x100694950（L128-131）：渲染快照读取。
    var renderSnapshot: ReaderRenderSnapshot { snapshot }

    /// 伪代码 0x100694f00（L177-191）：消费挂起的逻辑页重定位——记录待消费
    /// 请求（chapterIndex+pageIndex 域），无挂起 → nil。
    func consumePendingLogicalPageRebase() -> (chapterIndex: Int, pageIndex: Int)? {
        lock.lock()
        defer { lock.unlock() }
        guard let pending = pendingLogicalPageRebase else { return nil }
        pendingLogicalPageRebase = nil
        return pending
    }

    /// 挂起重定位记录（consumePendingLogicalPageRebase 消费域；写入随
    /// commitPages 链推断）。
    func recordPendingLogicalPageRebase(
        chapterIndex: Int, pageIndex: Int
    ) {
        lock.lock()
        defer { lock.unlock() }
        pendingLogicalPageRebase = (chapterIndex, pageIndex)
    }

    /// 伪代码 0x100696970（L307-309）：章节页失效（页集清空 + revision 域）。
    func invalidateChapterPages() {
        lock.lock()
        defer { lock.unlock() }
        pages = []
        snapshot = ReaderRenderSnapshot(
            pages: [], currentPageIndex: 0,
            chapterPageMeta: snapshot.chapterPageMeta,
            currentChapterIndex: snapshot.currentChapterIndex,
            revision: snapshot.revision + 1)
    }

    /// 伪代码 0x100697eac（L317-322）：遗忘单章（页集 + 状态 + 失败表域）。
    func forgetChapter(_ chapterIndex: Int) {
        lock.lock()
        defer { lock.unlock() }
        pages.removeAll { $0.chapterIndex == chapterIndex }
        loadingChapters.remove(chapterIndex)
        failedChapters.removeValue(forKey: chapterIndex)
    }

    /// 伪代码 0x100696b74（L325-332）：全部章节清空。
    func clearAllChapters() {
        lock.lock()
        defer { lock.unlock() }
        pages = []
        loadingChapters = []
        failedChapters = [:]
        snapshot = ReaderRenderSnapshot(
            pages: [], currentPageIndex: 0,
            chapterPageMeta: [:], currentChapterIndex: 0,
            revision: snapshot.revision + 1)
    }
}

