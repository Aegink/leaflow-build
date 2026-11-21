// 原路径: ReadMain/Views/Reader/WebViewVerticalScroll/ReaderViewModel+WebViewVerticalScroll.swift
// 证据:
//   - PGO: 主函数（index/task_functions.csv T-301-14 / ReaderViewModel+WebViewVerticalScroll.swift），
//     地址：webViewChapterCount 0x100643534 L8-10 / webViewBookDisplayName 0x1006435f4
//     L12-14 / webViewChapterTitle 闭包 ×3 0x10064695c/0x100646994/0x1008857c0 L17 /
//     webViewShouldShowBoundaryLoadingIndicator 0x100643644 L24-28 /
//     webViewInitialChapterIndex 0x1006439cc L38-44 / webViewSettingsSignature
//     0x100643cf8 L46-80 / webViewChapterPayload 闭包 ×3 0x1008857c0/0x100885d34/0x100885d48
//     L123 / webViewPreloadAdjacentChapters 0x100644ccc L145-168（utility 确证）
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Reader/WebViewVerticalScroll/
//     ReaderViewModel+WebViewVerticalScroll.c（1894 行）
//   - 事实：在线书 WebView 数据源桥（与 Local 版同构；边界加载指示判定确证）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（桥接面/预取链确证）
// 还原: 2026-11-19

import Foundation

extension ReaderViewModel {

    /// 伪代码 0x100643534（L8-10）：章数。
    var webViewChapterCount: Int {
        chapterContents.count
    }

    /// 伪代码 0x1006435f4（L12-14）：书名。
    var webViewBookDisplayName: String {
        bookName
    }

    /// 伪代码 0x100643644（L24-28）：边界加载指示判定。
    func webViewShouldShowBoundaryLoadingIndicator(for index: Int) -> Bool {
        guard index >= 0, index < webViewChapterCount else { return false }
        return chapterContents[index].isEmpty
    }

    /// 伪代码 0x1006439cc（L38-44）：初始章。
    var webViewInitialChapterIndex: Int {
        currentChapterIndex
    }

    /// 伪代码 0x100643cf8（L46-80）：设置签名。
    /// settings 为可选（weak 引用域）——可选键入哈希（wave-16）。
    var webViewSettingsSignature: Int {
        var hasher = Hasher()
        hasher.combine(settings?.fontSize)
        hasher.combine(settings?.lineSpacing)
        hasher.combine(settings?.letterSpacing)
        hasher.combine(settings?.verticalJustify)
        hasher.combine(settings?.textAlignment)
        return hasher.finalize()
    }

    /// 章节标题（闭包 ×3 确证）。
    func webViewChapterTitle(at index: Int) -> String {
        pages.first { $0.chapterIndex == index }?.chapterTitle ?? ""
    }

    /// 章节载荷（闭包 ×3 确证，L123）。
    func webViewChapterPayload(
        for index: Int, forceRefresh: Bool
    ) -> WebViewVerticalScrollChapterPayload? {
        let content = chapterContents.indices.contains(index) ? chapterContents[index] : ""
        guard !content.isEmpty, let settings else { return nil }
        let html = WebViewChapterHTMLBuilder.build(content: content, settings: settings)
        return WebViewVerticalScrollPayloadFactory.chapterPayload(
            chapterIndex: index,
            title: webViewChapterTitle(at: index),
            html: html,
            settings: settings)
    }

    /// 伪代码 0x100644ccc（L145-168）：邻接章预取（utility 确证）。
    func webViewPreloadAdjacentChapters(around index: Int) {
        Task(priority: .utility) {
            _ = webViewChapterPayload(for: index + 1, forceRefresh: false)
            _ = webViewChapterPayload(for: index - 1, forceRefresh: false)
        }
    }
}

// MARK: - T-1401-07 逐域补齐（WebView 垂直滚动域）

extension ReaderViewModel {

    /// 伪代码 0x10064552c（L170-179）：可见章处理——章界 + 当前章对齐域。
    func handleWebViewVisibleChapter(_ index: Int, source: String) {
        guard chapterContents.indices.contains(index) else { return }
        if index != currentChapterIndex {
            currentChapterIndex = index
        }
    }

    /// 伪代码 0x100645660（L198-234）：滚动进度即时保存（UserDefaults 域）。
    func saveWebViewScrollProgressNow() {
        let key = "webvitals_scroll_\(bookName)"
        UserDefaults.standard.set(
            ["\(currentChapterIndex)", "\(currentPageIndex)"], forKey: key)
    }

    /// 伪代码 0x100645d5c（L236-270）：WebView 内章跳转。
    func webViewJumpToChapter(_ chapterIndex: Int) {
        jumpToChapter(chapterIndex, pageIndex: nil)
    }

    /// 伪代码 0x10064644c（L272-279）：WebView 设置变更记录（签名失效域）。
    func noteWebViewSettingsChanged() {
        settings?.invalidateTypographyCachesBridge()
    }

    /// 伪代码 0x10064414c（L281-293）：滚动进度回退值（进度缺失 → 0 域）。
    func fallbackWebViewScrollProgress(chapterIndex: Int) -> Double {
        guard chapterReaderAccessURLs[chapterIndex] != nil else { return 0 }
        return 0
    }
}

