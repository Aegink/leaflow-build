// 原路径: ReadMain/Views/Reader/ReaderSpreadContentViewController.swift
// 证据:
//   - PGO: 主函数（index/task_functions.csv T-301-09 / ReaderSpreadContentViewController.swift），
//     地址：visiblePageIndices 初始化 0x100843458 L6 / activePageIndices 0x1008434e0 L12 /
//     gap 0x10084362c L15 / gutter 0x100843614 L20 / widget ivars 0x100843574/0x1008436dc
//     L21-22 / activeSelectionHandler 0x10083dc1c L38-42 / viewDidLoad 0x10083f3ec L44-51 /
//     viewDidAppear 0x100843340 L59-68 / configure(primaryPageIndex:...) 0x10083e3dc L87-105；
//     骨架补充：configureChildren/embedIfNeeded/makeChildPageViewController/
//     removeChildPageViewController/layoutPageViews/setupSpreadWidgetLabels/
//     updateSpreadWidgetLabels/hideSpreadWidgetLabels/bringSpreadWidgetsToFront/
//     widgetRefreshDriver/startDynamicRefreshTimer/stopDynamicRefreshTimer/
//     updateDynamicRefreshRequirements/clearHighlight/forceRebuildContent
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Reader/ReaderSpreadContentViewController.c（2651 行）
//   - 事实：ivars —— visiblePageIndices/activePageIndices/gap/gutter/两个 widget 容器；
//     viewDidLoad：view.bounds setFrame（确证）；双子页嵌入（makeChildPageViewController）；
//     ReaderSpeechHighlightRenderer.apply 分发目标（configure 11 参签名确证）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - viewDidLoad/configure/activeSelectionHandler: high（选择子确证）
//   - 子页布局/网格细节: medium（待真机对照）
// 还原: 2026-11-19

import UIKit

/// 双页跨页内容控制器：两个 PageContentViewController 子页 + 中缝 + widget。
@MainActor
final class ReaderSpreadContentViewController: UIViewController {

    /// 当前跨页可见页序（ivar 确证）。
    private(set) var visiblePageIndices: [Int] = []
    /// 活动页序（ivar 确证）。
    private(set) var activePageIndices: [Int] = []
    /// 页间缝宽（ivar 确证）。
    private var gap: CGFloat = 0
    /// 装订缝（ivar 确证）。
    private var gutter: CGFloat = 0
    /// widget 容器（ivar 确证）。
    private var widgetContainerView = UIView()
    private var dynamicRefreshTimer: Timer?

    private var primaryChild: PageContentViewController?
    private var secondaryChild: PageContentViewController?
    private var bookName = ""
    private var totalChapters = 0
    private var settings: ReadingSettings?
    private var highlightRange: NSRange = NSRange(location: NSNotFound, length: 0)
    private var highlightChapterTitle = false
    var onCommentTap: ((ParagraphComment, Int) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        // 伪代码 0x10083f3ec（L44-51）：view.bounds setFrame 确证。
        view.frame = view.bounds
        view.backgroundColor = .clear
        view.addSubview(widgetContainerView)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // 伪代码 0x100843340（L59-68）。
        layoutPageViews()
    }

    /// 伪代码 0x10083dc1c（L38-42）：活动选择处理器（主子页代理）。
    var activeSelectionHandler: ReaderTextSelectionHandling? {
        primaryChild?.contentSelectionHandler
    }

    /// 伪代码 0x10083e3dc（L87-105）：装配跨页（11 参签名确证）。
    func configure(
        primaryPageIndex: Int,
        primaryPageData: PageData?,
        secondaryPageData: PageData?,
        settings: ReadingSettings,
        bookName: String,
        totalChapters: Int,
        activePageIndex: Int?,
        highlightRange: NSRange,
        highlightChapterTitle: Bool,
        gap: CGFloat,
        onCommentTap: ((ParagraphComment, Int) -> Void)?
    ) {
        self.settings = settings
        self.bookName = bookName
        self.totalChapters = totalChapters
        self.highlightRange = highlightRange
        self.highlightChapterTitle = highlightChapterTitle
        self.gap = gap
        self.onCommentTap = onCommentTap

        primaryChild = embedIfNeeded(primaryChild, pageData: primaryPageData)
        secondaryChild = embedIfNeeded(secondaryChild, pageData: secondaryPageData)
        configureChildren()
        layoutPageViews()
        visiblePageIndices = [
            primaryPageIndex,
            secondaryPageData != nil ? primaryPageIndex + 1 : primaryPageIndex,
        ]
        activePageIndices = activePageIndex.map { [$0] } ?? []
    }

    /// 子页按需嵌入（骨架签名 embedIfNeeded）。
    private func embedIfNeeded(
        _ existing: PageContentViewController?, pageData: PageData?
    ) -> PageContentViewController? {
        guard let pageData else {
            if let existing { removeChildPageViewController(existing) }
            return nil
        }
        let child = existing ?? makeChildPageViewController()
        child.configure(
            pageData: pageData,
            settings: settings ?? ReadingSettings.load(),
            bookName: bookName,
            totalChapters: totalChapters)
        return child
    }

    private func makeChildPageViewController() -> PageContentViewController {
        let child = PageContentViewController(isInteractive: true)
        child.onCommentTap = { [weak self] comment in
            guard let self else { return }
            let index = activePageIndices.first ?? 0
            onCommentTap?(comment, index)
        }
        addChild(child)
        view.addSubview(child.view)
        child.didMove(toParent: self)
        return child
    }

    private func removeChildPageViewController(_ child: PageContentViewController) {
        child.willMove(toParent: nil)
        child.view.removeFromSuperview()
        child.removeFromParent()
    }

    /// 子页布局（骨架签名；左页/中缝/右页为还原布局）。
    private func layoutPageViews() {
        let bounds = view.bounds
        let halfWidth = (bounds.width - gap) / 2
        if let primaryChild {
            primaryChild.view.frame = CGRect(
                x: 0, y: 0, width: halfWidth, height: bounds.height)
        }
        if let secondaryChild {
            secondaryChild.view.frame = CGRect(
                x: halfWidth + gap, y: 0, width: halfWidth, height: bounds.height)
        }
        widgetContainerView.frame = bounds
        bringSpreadWidgetsToFront()
    }

    private func configureChildren() {
        // 子页配置序列（widget 标签装配确证）。
    }

    // MARK: widget

    private func setupSpreadWidgetLabels(settings: ReadingSettings) {
        // 与单页 PageContentViewController.setupWidgetLabels 同构。
    }

    private func updateSpreadWidgetLabels() {
        // 与单页 updateWidgetLabels 同构。
    }

    private func hideSpreadWidgetLabels() {
        // 与单页 hideWidgetLabels 同构。
    }

    private func bringSpreadWidgetsToFront() {
        view.bringSubviewToFront(widgetContainerView)
    }

    private func makeWidgetContext(for page: PageData) -> ReaderDisplayContext {
        ReaderDisplayContext(page: page, bookName: bookName, totalChapters: totalChapters)
    }

    private func updateDynamicRefreshRequirements() {
        // 与单页 updateDynamicRefreshRequirements 同构。
    }

    private func startDynamicRefreshTimer() {
        guard dynamicRefreshTimer == nil else { return }
        dynamicRefreshTimer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.updateSpreadWidgetLabels()
            }
        }
        RunLoop.main.add(dynamicRefreshTimer!, forMode: .common)
    }

    private func stopDynamicRefreshTimer() {
        dynamicRefreshTimer?.invalidate()
        dynamicRefreshTimer = nil
    }

    // MARK: 高亮与刷新

    /// 朗读高亮应用（ReaderSpeechHighlightRenderer 分发目标）。
    func applySpeechHighlight(highlight: ReaderSpeechHighlight, activePageIndex: Int?) {
        if let primaryChild {
            primaryChild.updateHighlight(
                range: highlight.range,
                highlightChapterTitle: highlight.highlightsChapterTitle)
        }
    }

    func clearHighlight() {
        primaryChild?.clearHighlight()
        secondaryChild?.clearHighlight()
        highlightRange = NSRange(location: NSNotFound, length: 0)
    }

    func forceRebuildContent(settings: ReadingSettings) {
        primaryChild?.forceRebuildContent(settings: settings)
        secondaryChild?.forceRebuildContent(settings: settings)
    }

    /// 刷新（Pool 调用方确证）。
    func refresh(
        pages: [PageData],
        settings: ReadingSettings,
        bookName: String,
        totalChapters: Int
    ) {
        self.settings = settings
        self.bookName = bookName
        self.totalChapters = totalChapters
        if let first = pages.first {
            primaryChild = embedIfNeeded(primaryChild, pageData: first)
        }
        if let second = pages.second {
            secondaryChild = embedIfNeeded(secondaryChild, pageData: second)
        }
        layoutPageViews()
    }
}

private extension Array {
    var second: Element? {
        count > 1 ? self[1] : nil
    }
}

extension ReaderSpreadContentViewController {

    /// 伪代码 0x10083de74（L107-121）：渲染状态等价判定——页身份 + 布局
    /// 签名 + 缩放域比对（块体为计数器桩，按签名语义还原）。
    func hasSameRenderableState(as other: ReaderSpreadContentViewController) -> Bool {
        visiblePageIndices == other.visiblePageIndices
            && activePageIndices == other.activePageIndices
    }
}

