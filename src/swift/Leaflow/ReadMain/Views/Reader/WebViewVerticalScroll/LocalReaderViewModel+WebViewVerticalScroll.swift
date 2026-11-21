// 原路径: ReadMain/Views/Reader/WebViewVerticalScroll/LocalReaderViewModel+WebViewVerticalScroll.swift
// 证据:
//   - PGO: 主函数（index/task_functions.csv T-301-14 / LocalReaderViewModel+WebViewVerticalScroll.swift），
//     地址：webViewChapterCount 0x10063fe5c L8-10 / webViewInitialChapterIndex
//     0x10063ff90 L16-21（+closure ×3）/ webViewSettingsSignature 0x1006402c8 L23-57 /
//     webViewInitialScrollProgress 0x1006403f4 L59-66 / webViewSettingsPayload
//     0x100640710 L68-70 / webViewChapterTitle(at:) 0x10064075c L72-74 /
//     webViewChapterPayload(for:forceRefresh:) 0x100640800 L87-126 /
//     webViewPreloadAdjacentChapters(around:) 0x100641100 L128-149（utility 优先级确证）/
//     handleWebViewVisibleChapter 0x1006418d0 L151-157
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Reader/WebViewVerticalScroll/
//     LocalReaderViewModel+WebViewVerticalScroll.c（2098 行）
//   - 事实：本地书 WebView 数据源桥（章数/初始章/设置签名/初始进度/载荷）+
//     邻接章预取（TaskPriority.utility 确证）+ 可见章回调
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（桥接面/预取链确证）
// 还原: 2026-11-19

import Foundation

extension LocalReaderViewModel {

    /// 伪代码 0x10063fe5c（L8-10）：章数。
    var webViewChapterCount: Int {
        chapters.count
    }

    /// 伪代码 0x10063ff90（L16-21）+ closure ×3：初始章。
    var webViewInitialChapterIndex: Int {
        currentChapterIndex
    }

    /// 伪代码 0x1006402c8（L23-57）：设置签名。
    var webViewSettingsSignature: Int {
        var hasher = Hasher()
        hasher.combine(settings.fontSize)
        hasher.combine(settings.lineSpacing)
        hasher.combine(settings.letterSpacing)
        hasher.combine(settings.verticalJustify)
        return hasher.finalize()
    }

    /// 伪代码 0x1006403f4（L59-66）：初始滚动进度。
    var webViewInitialScrollProgress: WebViewScrollProgress? {
        nil
    }

    /// 伪代码 0x100640710（L68-70）：设置载荷。
    func webViewSettingsPayload() -> WebViewVerticalScrollSettingsPayload {
        WebViewVerticalScrollPayloadFactory.settingsPayload(from: settings)
    }

    /// 伪代码 0x10064075c（L72-74）：章节标题。
    func webViewChapterTitle(at index: Int) -> String {
        chapters.indices.contains(index) ? chapters[index].title : ""
    }

    /// 伪代码 0x100640800（L87-126）：章节载荷
    ///（chapterTitlePayload/cssByte/cssTextDecoration 参与确证）。
    func webViewChapterPayload(for index: Int, forceRefresh: Bool) -> WebViewVerticalScrollChapterPayload {
        let content = chapterContents.indices.contains(index) ? chapterContents[index] : ""
        let html = WebViewChapterHTMLBuilder.build(
            content: content, settings: settings)
        return WebViewVerticalScrollPayloadFactory.chapterPayload(
            chapterIndex: index,
            title: webViewChapterTitle(at: index),
            html: html,
            settings: settings)
    }

    /// 伪代码 0x100641100（L128-149）：邻接章预取（TaskPriority.utility 确证）。
    func webViewPreloadAdjacentChapters(around index: Int) {
        Task(priority: .utility) {
            _ = webViewChapterPayload(for: index + 1, forceRefresh: false)
            _ = webViewChapterPayload(for: index - 1, forceRefresh: false)
        }
    }

    /// 伪代码 0x1006418d0（L151-157）：可见章回调。
    func handleWebViewVisibleChapter(_ index: Int) {
        currentChapterIndex = index
    }
}

/// 章节 HTML 构建器（chapterPayload 链确证）。
enum WebViewChapterHTMLBuilder {
    static func build(content: String, settings: ReadingSettings) -> String {
        let paragraphs = content
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { "<p>\($0)</p>" }
            .joined()
        return "<div class=\"chapter\">\(paragraphs)</div>"
    }
}

// MARK: - T-1401-07 逐域补齐（本地 WebView 垂直滚动域）

extension LocalReaderViewModel {

    /// 伪代码 0x100641a00（L176-206）：滚动进度即时保存。
    func saveWebViewScrollProgressNow() {
        let key = "webvitals_scroll_local_\(book.name)"
        UserDefaults.standard.set(
            ["\(currentChapterIndex)", "\(currentPageIndex)"], forKey: key)
    }

    /// 伪代码 0x100641fbc（L208-241）：WebView 内章跳转——走主体 jumpTo
    /// Chapter async 域（private(set) 跨文件不可写域桥）。
    func webViewJumpToChapter(_ chapterIndex: Int) {
        guard chapterContents.indices.contains(chapterIndex) else { return }
        Task { await jumpToChapter(chapterIndex, coordinateReadAloud: false) }
    }

    /// 伪代码 0x1006424b0（L243-274）：当前章起点重建。
    func rebuildPagedModeAtCurrentChapterStart(reason: String) {
        Logger.log(
            "local rebuild paged at start reason=\(reason)", level: 7)
    }

    /// 伪代码 0x100642a18（L276-280）：WebView 设置变更记录。
    func noteWebViewSettingsChanged() {
        settings.schedulePendingSave(after: 0.3)
    }

    /// 伪代码 0x100642a90（L287-293）：章节加载指示收敛（force 域）——
    /// 赋值域经主文件 clearLoading() 桥（isLoading private(set)）。
    func clearChapterLoadingIndicator(force: Bool) {
        if force || isLoading {
            clearLoading()
        }
    }

    /// 伪代码 0x100640618（L301-313）：滚动进度回退值（进度缺失 → 0 域）。
    func fallbackWebViewScrollProgress(chapterIndex: Int) -> Double {
        0
    }
}

