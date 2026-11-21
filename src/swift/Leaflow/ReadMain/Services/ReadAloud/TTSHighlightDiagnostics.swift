// 原路径: ReadMain/Services/ReadAloud/TTSHighlightDiagnostics.swift
// 证据:
//   - PGO: 40 条记录（index/task_functions.csv T-801-10 /
//     TTSHighlightDiagnostics.swift；十八签名域）
//   - CovMap: 上述 L 区段（anchorSummary/logContentHighlightApplied/
//     logContentHighlightFailure/logContentLifecycle/logDriverAnchor/
//     logHighlightDispatch/logHighlightResolution/logPaginationCommit/
//     logPaginationRefresh/engineLabel/pageSummary/pageWindow/
//     rangeLabel/textFingerprint/textPreview/textSummary 域）
//   - IDA: 伪代码域 TTSHighlightDiagnostics.c（域内嵌于
//     TtsPlayerView.c 域；诊断域无用户字符串）
//   - 事实：TTS 高亮诊断域（十六签名：日志桥 + 指纹 + 预览）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（十六签名域确证）
// 还原: 2026-11-20

import Foundation

/// TTS 高亮诊断（anchorSummary/log 签名域确证）。
enum TTSHighlightDiagnostics {

    /// 日志前缀域（诊断域还原桥）。
    private static let prefix = "[TTS-HL]"

    /// anchorSummary(_:pages:)（签名域确证：锚点摘要域）。
    static func anchorSummary(
        _ anchor: ReadAloudAnchor?, pages: [PageData]
    ) -> String {
        guard let anchor else { return "anchor=nil" }
        let pageIndex = anchor.location.pageIndex
        let pageText = pages.first { $0.pageIndex == pageIndex }?
            .content
        let fingerprint = pageText.map(textFingerprint) ?? "-"
        return "anchor(page=\(pageIndex), off=\(anchor.rangeInPage.location)"
            + ", len=\(anchor.rangeInPage.length), fp=\(fingerprint))"
    }

    /// logContentHighlightApplied(page:viewController:contentRange:
    /// renderedRange:renderedText:)（签名域确证）。
    static func logContentHighlightApplied(
        page: PageData?, viewController: AnyObject,
        contentRange: NSRange, renderedRange: NSRange,
        renderedText: String
    ) {
        let message = "applied page=\(page?.pageIndex ?? -1)"
            + " content=\(describe(contentRange))"
            + " rendered=\(describe(renderedRange))"
            + " text=\(textPreview(renderedText, range: renderedRange, limit: 32))"
        log(message)
    }

    /// logContentHighlightFailure(reason:page:viewController:
    /// textStorageText:extra:)（签名域确证）。
    static func logContentHighlightFailure(
        reason: String, page: PageData?, viewController: AnyObject,
        contentRange: NSRange, textStorageText: String, extra: String
    ) {
        let message = "failure reason=\(reason)"
            + " page=\(page?.pageIndex ?? -1)"
            + " content=\(describe(contentRange))"
            + " storage=\(textSummary(textStorageText))"
            + " extra=\(extra)"
        log(message)
    }

    /// logContentLifecycle(stage:page:previousPage:viewController:
    /// highlightRange:highlightsChapterTitle:textStorageText:extra:)
    /// （签名域确证）。
    static func logContentLifecycle(
        stage: String, page: PageData?, previousPage: PageData?,
        viewController: AnyObject, highlightRange: NSRange,
        highlightsChapterTitle: Bool, textStorageText: String,
        extra: String
    ) {
        let message = "lifecycle stage=\(stage)"
            + " page=\(page?.pageIndex ?? -1)"
            + " prev=\(previousPage?.pageIndex ?? -1)"
            + " range=\(describe(highlightRange))"
            + " title=\(highlightsChapterTitle)"
            + " extra=\(extra)"
        log(message)
    }

    /// logDriverAnchor(event:generation:segmentIndex:engine:raw:
    /// resolved:pages:)（签名域确证）。
    static func logDriverAnchor(
        event: Int, generation: Int, segmentIndex: Int,
        engine: ReadAloudEngineSelection?, raw: ReadAloudAnchor,
        resolved: ReadAloudAnchor?, pages: [PageData]
    ) {
        let message = "driver event=\(event) gen=\(generation)"
            + " seg=\(segmentIndex) engine=\(engineLabel(engine))"
            + " raw=\(anchorSummary(raw, pages: pages))"
            + " resolved=\(anchorSummary(resolved, pages: pages))"
        log(message)
    }

    /// logHighlightDispatch(highlight:viewController:suppliedPageIndex:
    /// page:)（签名域确证）。
    static func logHighlightDispatch(
        highlight: ReaderSpeechHighlight, viewController: AnyObject,
        suppliedPageIndex: Int?, page: PageData?
    ) {
        let message = "dispatch page=\(suppliedPageIndex ?? -1)"
            + " actual=\(page?.pageIndex ?? -1)"
            + " range=\(describe(highlight.range))"
        log(message)
    }

    /// logHighlightResolution(anchor:resolved:absolutePageIndex:pages:)
    /// （签名域确证）。
    static func logHighlightResolution(
        anchor: ReadAloudAnchor, resolved: ReadAloudAnchor?,
        absolutePageIndex: Int?, pages: [PageData]
    ) {
        let message = "resolution absolute=\(absolutePageIndex ?? -1)"
            + " raw=\(anchorSummary(anchor, pages: pages))"
            + " resolved=\(anchorSummary(resolved, pages: pages))"
        log(message)
    }

    /// logPaginationCommit(source:applied:revision:currentPageIndex:
    /// pages:)（签名域确证）。
    static func logPaginationCommit(
        source: String, applied: Bool, revision: UInt64,
        currentPageIndex: Int, pages: [PageData]
    ) {
        let message = "commit source=\(source) applied=\(applied)"
            + " rev=\(revision) page=\(currentPageIndex)"
            + " count=\(pages.count)"
        log(message)
    }

    /// logPaginationRefresh(stage:revision:generation:currentPageIndex:
    /// raw:before:after:pages:)（签名域确证）。
    static func logPaginationRefresh(
        stage: String, revision: Int, generation: Int,
        currentPageIndex: Int, raw: ReadAloudAnchor?,
        before: ReadAloudAnchor?, after: ReadAloudAnchor?,
        pages: [PageData]
    ) {
        let message = "refresh stage=\(stage) rev=\(revision)"
            + " gen=\(generation) page=\(currentPageIndex)"
            + " raw=\(anchorSummary(raw, pages: pages))"
            + " before=\(anchorSummary(before, pages: pages))"
            + " after=\(anchorSummary(after, pages: pages))"
        log(message)
    }

    // MARK: 摘要域（engineLabel/pageSummary/pageWindow/rangeLabel/
    // textFingerprint/textPreview/textSummary 签名域确证）

    /// engineLabel(ReadAloudEngineSelection?)（签名域确证）。
    static func engineLabel(_ engine: ReadAloudEngineSelection?)
        -> String {
        engine?.rawValue ?? "none"
    }

    /// pageSummary(PageData?)（签名域确证）。
    static func pageSummary(_ page: PageData?) -> String {
        guard let page else { return "page=nil" }
        return "page(\(page.pageIndex), len=\(page.content.count))"
    }

    /// pageWindow(_:pages:)（签名域确证：当前页 ±1 窗口摘要）。
    static func pageWindow(
        _ pageIndex: Int?, pages: [PageData]
    ) -> String {
        guard let pageIndex else { return "window=nil" }
        let lower = max(pageIndex - 1, 0)
        let upper = min(pageIndex + 1, pages.count - 1)
        guard lower <= upper else { return "window=empty" }
        return (lower...upper)
            .map { offset in
                pages.first { $0.pageIndex == offset }.map {
                    "p\(offset):\(textFingerprint($0.content))"
                } ?? "p\(offset):missing"
            }
            .joined(separator: ",")
    }

    /// rangeLabel(NSRange?)（签名域确证）。
    static func rangeLabel(_ range: NSRange?) -> String {
        guard let range else { return "range=nil" }
        return describe(range)
    }

    /// textFingerprint(String)（签名域确证：内容指纹域）。
    static func textFingerprint(_ text: String) -> String {
        var hasher = Hasher()
        hasher.combine(text)
        return String(format: "%08x", UInt32(bitPattern: hasher.finalize()))
    }

    /// textPreview(_:range:limit:)（签名域确证：片段预览域）。
    static func textPreview(
        _ text: String?, range: NSRange, limit: Int
    ) -> String {
        guard let text, !text.isEmpty else { return "-" }
        let nsText = text as NSString
        let clampedLocation = min(range.location, nsText.length)
        let clampedLength = min(range.length, nsText.length - clampedLocation)
        let substring = nsText.substring(
            with: NSRange(location: clampedLocation, length: clampedLength))
        if substring.count > limit {
            return String(substring.prefix(limit)) + "…"
        }
        return substring
    }

    /// textSummary(String)（签名域确证）。
    static func textSummary(_ text: String) -> String {
        "len=\(text.count) fp=\(textFingerprint(text))"
    }

    private static func describe(_ range: NSRange) -> String {
        "(\(range.location),\(range.length))"
    }

    private static func log(_ message: String) {
        print("\(prefix) \(message)")
    }
}
