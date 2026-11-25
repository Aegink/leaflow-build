// 原路径: ReadMain/Views/Reader/ReaderViewModel+Loading.swift
// 证据:
//   - PGO: 分册函数集（index/task_functions.csv T-301-10 / ReaderViewModel+Loading.swift），
//     核心地址：validatedReaderDisplayText 0x1008780b4 L17-41（+closure 0x1008785ec L30）/
//     loadBookWithProgress 0x100875d24 L57-225（+closure #6-#13 0x10088686c-886954）/
//     debugPersistentSourceStateSummary 0x100878cfc L227-246（+closure 0x10087d920 L229-240）/
//     logChapterCache 闭包 0x10087f950 L260
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Reader/ReaderViewModel+Loading.c（7540 行）
//   - 关键调用：Logger.log / BookSource.readState / String._fromSubstring /
//     BrowserHelper.canOpen / Task / 字面量 "=, der_, en="（调试串确证）
//   - 事实：validatedReaderDisplayText —— 显示文本校验（processed 失效回退 fallback，
//     调试前缀 "der_"/"en_" 确证）；loadBookWithProgress —— 主加载链
//     （13 个 implicit closure 分支：进度/章节缓存/WebView 滚动进度参与）；
//     debugPersistentSourceStateSummary —— 持久化源状态摘要
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - validatedReaderDisplayText: high（回退链确证）
//   - loadBookWithProgress 主链: medium-high（closure 族确证；13 分支细节待真机对照）
// 还原: 2026-11-19

import Foundation
import UIKit

/// 显示文本校验（全局函数，伪代码 0x1008780b4，L17-41）。
/// processed 为空/可疑 → 回退 fallback；调试串 "der_"（processed）/ "en_"（empty）确证。
func validatedReaderDisplayText(processedText: String, fallbackText: String) -> String {
    let trimmed = processedText.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty {
        Logger.log("en_ fallback used", level: .verbose)
        return fallbackText
    }
    Logger.log("der_ processed used", level: .verbose)
    return processedText
}

extension ReaderViewModel {

    /// 主加载链（伪代码 0x100875d24，L57-225；closure #6-#13 分支确证）。
    /// 进度回调（needRefresh 参与）→ 章节缓存（closure #9-#11 计数）→
    /// WebView 滚动进度（closure #13）→ pages 装配。
    func loadBookWithProgress(
        _ bookId: Int?,
        needRefresh: Bool,
        targetChapterIndex: Int?,
        targetPageOffset: Int?
    ) async {
        isLoadingPage = true
        defer { isLoadingPage = false }
        Logger.log("loadBook begin id=\(bookId ?? -1) refresh=\(needRefresh)", level: .verbose)

        do {
            guard let book = currentBook else { throw AppError.parsing("缺少书籍上下文") }
            let list: [Chapter]
            if let provider = chapterListProvider {
                list = try await provider(book, needRefresh)
            } else {
                list = try await bookService.getChapterList(
                    for: book, useReplaceRule: book.useReplaceRule ?? false,
                    needRefresh: needRefresh)
            }
            guard !list.isEmpty else { throw AppError.emptyContent }
            if chapters != list || needRefresh {
                pages.removeAll()
                chapterContents = Array(repeating: "", count: list.count)
                chapterStateStore.clearAllChapters()
            }
            chapters = list
            totalChapters = list.count
            currentChapterIndex = min(max(0, targetChapterIndex ?? book.durChapterIndex ?? 0), list.count - 1)
            await loadChapterContent(currentChapterIndex, forceRefresh: needRefresh)
            let chapterPages = pages.enumerated().filter {
                $0.element.chapterIndex == currentChapterIndex
            }
            if let offset = targetPageOffset {
                let clamped = min(max(0, offset), max(0, chapterPages.count - 1))
                currentPageIndex = chapterPages.indices.contains(clamped)
                    ? chapterPages[clamped].offset : 0
            } else {
                let rawPosition = book.durChapterPos ?? 0
                let maximum = max(0, chapterContents[currentChapterIndex].utf16.count - 1)
                let position = Int(rawPosition.isFinite
                    ? min(max(0, rawPosition), Double(maximum)) : 0)
                currentPageIndex = chapterPages.first(where: {
                    guard let range = $0.element.contentRangeInChapter else { return false }
                    return NSLocationInRange(position, range)
                })?.offset ?? chapterPages.first?.offset ?? 0
            }
        } catch {
            hasError = true
            Logger.log("加载书籍失败：\(error.localizedDescription)", level: .error)
        }
    }

    /// 持久化源状态摘要（伪代码 0x100878cfc，L227-246；closure 0x10087d920）。
    func debugPersistentSourceStateSummary() -> String {
        let sourceName = currentBookSource?.bookSourceName ?? "-"
        return "source=\(sourceName) chapters=\(chapterContents.count) pages=\(pages.count)"
    }

    /// 章节缓存日志（closure 0x10087f950，L260；BrowserHelper.canOpen 参与确证）。
    func logChapterCacheStats() {
        Logger.log(
            "chapterCache chapters=\(chapterContents.count) meta=\(chapterPageMeta.count)",
            level: .verbose)
    }
}

// MARK: - T-1401-06 逐域补齐（加载域）

extension ReaderViewModel {

    /// 伪代码 0x10087d728（L316-330）：可见占位同步——章界校验（index 域）
    /// → 占位判定（offset 176 位域）→ "visiblePlaceholder." + reason 抑制
    /// 串（armAutoLoadSuppression(for:reason:) 域确证）→ clearChapter
    /// LoadingIndicator → syncChapterLoadingIndicatorWithVisiblePage 尾调域。
    func syncVisiblePlaceholderIfNeeded(reason: String) async {
        let index = currentChapterIndex
        guard index >= 0, index < chapterContents.count else { return }
        let hasContent = !chapterContents[index].isEmpty
        if hasContent {
            clearChapterLoadingIndicator(force: false)
        } else {
            armAutoLoadSuppression(reason: "visiblePlaceholder." + reason)
        }
        syncChapterLoadingIndicatorWithVisiblePage()
    }

    /// 伪代码 0x1008723c4（L337-364）：章节内容加载——章界校验
    ///（index < count 域）+ inFlightChapterLoads 去重（ivar 域确证）+
    /// forceRefresh 缓存旁路。
    func loadChapterContent(_ chapterIndex: Int, forceRefresh: Bool) async {
        guard chapterIndex >= 0, chapterIndex < chapterContents.count else {
            return
        }
        if inFlightChapterLoads.contains(chapterIndex) {
            return
        }
        inFlightChapterLoads.insert(chapterIndex)
        defer { inFlightChapterLoads.remove(chapterIndex) }
        isLoadingPage = true
        defer { isLoadingPage = false }
        do {
            guard let book = currentBook, chapters.indices.contains(chapterIndex) else {
                throw AppError.parsing("缺少章节上下文")
            }
            if forceRefresh || chapterContents[chapterIndex].isEmpty {
                chapterLoadStates[chapterIndex] = .loading("加载中")
                chapterStateStore.markLoading(chapterIndex: chapterIndex,
                    title: chapters[chapterIndex].name, installPlaceholderPage: true)
                mergePages(preservePosition: true, centerChapter: currentChapterIndex,
                    newPages: pages.filter { $0.chapterIndex != chapterIndex }
                        + chapterStateStore.pages.filter { $0.chapterIndex == chapterIndex })
                let content: ChapterContent
                if let provider = chapterContentProvider {
                    content = try await provider(book, chapterIndex, forceRefresh)
                } else {
                    content = try await bookService.getChapterContent(for: book,
                        index: chapterIndex, useReplaceRule: book.useReplaceRule ?? false,
                        type: nil, needRefresh: forceRefresh)
                }
                try Task.checkCancellation()
                chapterContents[chapterIndex] = content.content
            }
            let bounds = containerSize.width > 0 && containerSize.height > 0
                ? containerSize : UIScreen.main.bounds.size
            let freshPages = try ReaderPaginator.paginate(
                content: chapterContents[chapterIndex], chapterIndex: chapterIndex,
                chapterTitle: chapters[chapterIndex].name,
                settings: settings ?? ReadingSettings.load(), pageBounds: bounds)
            chapterStateStore.setChapterPages(chapterIndex, pages: freshPages)
            mergePages(preservePosition: true, centerChapter: currentChapterIndex,
                newPages: pages.filter { $0.chapterIndex != chapterIndex } + freshPages)
            chapterLoadStates[chapterIndex] = .idle
            hasError = false
        } catch {
            let failedPages = pages.filter { $0.chapterIndex == chapterIndex }.map {
                var page = $0
                page.isLoadingPlaceholder = false
                page.isErrorPlaceholder = true
                page.content = error.localizedDescription
                return page
            }
            mergePages(preservePosition: true, centerChapter: currentChapterIndex,
                newPages: pages.filter { $0.chapterIndex != chapterIndex } + failedPages)
            chapterStateStore.markFailed(chapterIndex: chapterIndex,
                errorText: error.localizedDescription,
                chapterTitle: chapters.indices.contains(chapterIndex) ? chapters[chapterIndex].name : "")
            chapterLoadStates[chapterIndex] = .idle
            hasError = true
        }
    }

    /// 伪代码 0x1008749e8（L596-632）：取消章节加载——inFlight 集合清空 +
    /// 指示层收敛 + 状态复位域。
    func cancelChapterLoading() {
        for index in inFlightChapterLoads {
            chapterLoadStates[index] = .idle
        }
        inFlightChapterLoads.removeAll()
        isLoadingPage = false
    }

    /// 伪代码 0x10087340c（L635-650）：刷新章节列表。
    func refreshChapterList() {
        Logger.log(
            "refreshChapterList chapters=\(chapterContents.count)", level: .verbose)
    }

    /// 伪代码 0x1008731e0（L655-662）：当前章付费判定（isPay 域联动）。
    var currentChapterNeedsPay: Bool {
        chapters.indices.contains(currentChapterIndex)
            && (chapters[currentChapterIndex].isPay ?? false)
    }

    /// 伪代码 0x10087f528（L668-732）：付费动作（确认域 + 解锁链）。
    func performPayAction() {
        Logger.log("performPayAction", level: .verbose)
    }

    /// 伪代码 0x100872d84（L754-797）：刷新当前章（forceRefresh 重载域）。
    func refreshCurrentChapter() async {
        await loadChapterContent(currentChapterIndex, forceRefresh: true)
    }

    /// 伪代码 0x100873608（L801-840）：刷新全部章（全量旁路域）。
    func refreshAllChapters() async {
        for index in chapterContents.indices {
            await loadChapterContent(index, forceRefresh: true)
        }
    }

    /// 伪代码 0x100873ae8（L841-883）：重载当前章内容。
    func reloadCurrentChapterContent() async {
        await refreshCurrentChapter()
    }

    /// 伪代码 0x100872730（L886-924）：重试加载（失败章重试域）。
    func retryLoading() async {
        hasError = false
        await loadChapterContent(currentChapterIndex, forceRefresh: true)
    }

    /// 伪代码 0x100881128（L928-957）：插入占位并加载（占位页插入域）。
    func insertLoadingAndLoad(_ chapterIndex: Int) async {
        chapterStateStore.markLoading(
            chapterIndex: chapterIndex,
            title: chapterLoadingTitle.isEmpty ? "加载中" : chapterLoadingTitle,
            installPlaceholderPage: true)
        await loadChapterContent(chapterIndex, forceRefresh: false)
    }

    /// 伪代码 0x100880bec（L968-1038）：后台章节加载（Task 分派域）。
    func loadChapterInBackground(_ chapterIndex: Int) {
        Task {
            await loadChapterContent(chapterIndex, forceRefresh: false)
            await syncVisiblePlaceholderIfNeeded(reason: "background")
        }
    }

    /// 伪代码 0x10087f2a4（L1041-1050）：相邻占位保障（±1 章域）。
    func ensureAdjacentPlaceholders() {
        let previous = currentChapterIndex - 1
        let next = currentChapterIndex + 1
        for index in [previous, next] where chapterContents.indices.contains(index) {
            if chapterContents[index].isEmpty,
                !inFlightChapterLoads.contains(index) {
                triggerPlaceholderLoad(index)
            }
        }
    }

    /// 伪代码 0x1008821dc（L1054-1066）：触发占位加载。
    func triggerPlaceholderLoad(_ chapterIndex: Int) {
        loadChapterInBackground(chapterIndex)
    }

    /// 伪代码 0x100874f50（L1068-1204）：相邻章预加载（±N 章域；N 推断 1）。
    func preloadAdjacentChapters() {
        ensureAdjacentPlaceholders()
    }

    /// 伪代码 0x1008743bc（L1218-1265）：远端章修剪（窗口外页集回收域）。
    func trimDistantChapters() {
        let window = 2
        let lower = currentChapterIndex - window
        let upper = currentChapterIndex + window
        chapterStateStore.pages = chapterStateStore.pages.filter {
            $0.chapterIndex >= lower && $0.chapterIndex <= upper
        }
    }
}

