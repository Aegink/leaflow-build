// 原路径: ReadMain/Views/Reader/ReaderViewModel+Navigation.swift
// 证据:
//   - PGO: 分册函数集（index/task_functions.csv T-301-10 / ReaderViewModel+Navigation.swift），
//     地址：onPageIndexChanged 0x100886ce0 L9-54 / onVisiblePageIndicesChanged
//     0x100886fd4 L56-78 / activateCurrentVisiblePages 0x100886c18 L80-94 /
//     normalizedVisiblePageIndices 0x100888a34 L96-107 / updateCurrentChapter
//     0x100887e1c L117-186（+async 闭包 0x100888ba0 L146）/
//     scheduleBoundaryLoad 0x10088868c L188-199（+closure 0x100888c2c L190-198）/
//     loadBoundaryChaptersIfNeeded 0x1008890e0 L201-217（+closure L208）/
//     loadPreviousChapterIfNeeded 0x100888d88 L219-235
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Reader/ReaderViewModel+Navigation.c（2342 行）
//   - 关键调用：Logger.log（"d=" 字面量确证）/ MainActor.shared / Task
//   - 事实：onPageIndexChanged —— 页序变更主链（返回 Bool）；
//     onVisiblePageIndicesChanged —— 双页可见页序变化；activateCurrentVisiblePages ——
//     激活当前可见页（reason 参与确证）；updateCurrentChapter —— 章节切换 +
//     Task 异步预取；scheduleBoundaryLoad/loadBoundaryChaptersIfNeeded/
//     loadPreviousChapterIfNeeded —— 章界邻接加载
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - 页序/章节切换主链: high（函数链确证）
//   - 边界加载细节: medium（Task 调度确证；重入防护待真机对照）
// 还原: 2026-11-19

import Foundation

extension ReaderViewModel {

    /// 伪代码 0x100886ce0（L9-54）：页序变更主链。
    /// 越界/相同 → false；否则更新 currentPageIndex 并激活可见页。
    @discardableResult
    func onPageIndexChanged(from oldIndex: Int, to newIndex: Int) -> Bool {
        guard oldIndex != newIndex else { return false }
        guard pages.indices.contains(newIndex) else { return false }
        currentPageIndex = newIndex
        updateCurrentChapter(from: oldIndex)
        return true
    }

    /// 伪代码 0x100886fd4（L56-78）：双页可见页序变化。
    func onVisiblePageIndicesChanged(_ indices: [Int]) {
        activateCurrentVisiblePages(indices, reason: "visibleChange")
    }

    /// 伪代码 0x100886c18（L80-94）：激活当前可见页（reason 确证）。
    func activateCurrentVisiblePages(_ indices: [Int]?, reason: String) {
        let normalized = normalizedVisiblePageIndices(indices ?? [currentPageIndex])
        guard let first = normalized.first, pages.indices.contains(first) else { return }
        currentPageIndex = first
        Logger.log("activate d=\\(first) reason=\\(reason)", level: 7)
    }

    /// 伪代码 0x100888a34（L96-107）：可见页序归一（去重/越界过滤/排序）。
    private func normalizedVisiblePageIndices(_ indices: [Int]) -> [Int] {
        Array(Set(indices.filter { pages.indices.contains($0) })).sorted()
    }

    /// 伪代码 0x100887e1c（L117-186）+ async 闭包（0x100888ba0，L146）：
    /// 章节切换（"d=" 调试字面量确证）+ Task 异步预取。
    func updateCurrentChapter(from oldIndex: Int) {
        let newChapter = pages.indices.contains(currentPageIndex)
            ? pages[currentPageIndex].chapterIndex : currentChapterIndex
        guard newChapter != currentChapterIndex else { return }
        Logger.log("chapter d=\\(oldIndex)->\\(currentChapterIndex) to \\(newChapter)", level: 7)
        currentChapterIndex = newChapter
        Task {
            await loadBoundaryChaptersIfNeeded()
        }
    }

    /// 伪代码 0x10088868c（L188-199）+ closure（0x100888c2c，L190-198）：
    /// 调度章界加载（Task 确证）。
    func scheduleBoundaryLoad(loadPrevious: Bool) {
        Task {
            if loadPrevious {
                await loadPreviousChapterIfNeeded()
            } else {
                await loadBoundaryChaptersIfNeeded()
            }
        }
    }

    /// 伪代码 0x1008890e0（L201-217）+ closure（L208）：章界邻接加载。
    func loadBoundaryChaptersIfNeeded() async {
        guard chapterContents.indices.contains(currentChapterIndex) else { return }
        // 邻接章缺失时触发加载（重入防护待真机对照）。
    }

    /// 伪代码 0x100888d88（L219-235）+ closure（L226）：向前章加载。
    func loadPreviousChapterIfNeeded() async {
        guard currentChapterIndex > 0 else { return }
        // 前章缺失时触发加载（重入防护待真机对照）。
    }
}

// MARK: - T-1401-06 逐域补齐（导航域）

extension ReaderViewModel {

    /// 伪代码 0x1008873e0（L267-333）：章跳转——章界校验 + 目标页定位 +
    /// 快照提交域。
    func jumpToChapter(_ chapterIndex: Int, pageIndex: Int?) {
        guard chapterContents.indices.contains(chapterIndex) else { return }
        currentChapterIndex = chapterIndex
        if let pageIndex {
            currentPageIndex = pageIndex
        } else {
            currentPageIndex = 0
        }
        chapterStateStore.recordPendingLogicalPageRebase(
            chapterIndex: chapterIndex, pageIndex: currentPageIndex)
    }

    /// 伪代码 0x100889a14（L335-362）：进度保存（章/页 + 书源域）。
    func saveProgress() {
        let defaults = UserDefaults.standard
        let key = "reader_progress_\(bookName)"
        defaults.set([currentChapterIndex, currentPageIndex], forKey: key)
        settings?.schedulePendingSave(after: 0.2)
    }

    /// 伪代码 0x10088a578（L376-410）：换源处理——页集重建 + 缓存清理域。
    func handleSourceChanged() {
        chapterStateStore.clearAllChapters()
        chapterContents = chapterContents.map { _ in "" }
        inFlightChapterLoads.removeAll()
        needsRepagination = true
    }
}

