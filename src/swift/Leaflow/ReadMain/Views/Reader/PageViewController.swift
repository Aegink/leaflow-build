// 原路径: ReadMain/Views/Reader/PageViewController.swift
// 证据:
//   - PGO: 90 个主函数（index/task_functions.csv T-301-05 / PageViewController.swift）。
//     地址：readerPageContentStyleSignature 0x10076a280 L7-35 / shouldApplyReaderPageLayoutUpdate
//     0x10075e05c+0x10075e130+0x10075f2e8 L40-42 / readerPageControllerRoute 0x10076a298 L51-60 /
//     systemScrollCommitTarget 0x10076a3a8 L66-69 / ReaderPageViewController.preferredScreenEdges
//     0x10076a910 L74 / viewDidAppear 0x10076a96c L78-81 / init 0x10072df0c 等三块 L117-143 /
//     makeUIViewController 0x10076aa38 L161-174 / makeUIPageViewController 0x10076abbc L186-265 /
//     updateUIViewController 0x10076b808 L267-277 / updateHorizontalPagingViewController
//     0x10076b21c L282-324(+closure1-5 0x10076bc88-bf10) / updateUIPageViewController
//     0x10076b950 L326-356 / Coordinator.pageScrollView 0x10076cd9c L397-399 /
//     isPageViewControllerBusy 0x10076d014 L401-410 / activePageContentViewController
//     0x10076d14c L427-435 / pageCurlDriver 0x10076d2c0 L447 / Coordinator.init 0x10076d900
//     L449-463 / cancelPageCurlPrewarming 0x100770034 等 L471 / schedulePageCurlPrewarming
//     0x10076dd74 L480-535 / prewarmRunLoopLabel 0x10076ea00 L537-543 /
//     enqueuePageCurlPrewarmStep 0x10076ed24 L545-562 / prewarmPageCurlStep 0x10076f160
//     L564-621 / isPreparedForCurl 0x10076ffac L623-628 / PageCurlDriver.displayKey
//     0x100770114 L651-660 / sequenceKey 0x10077028c L662-669 / syncHighlight 0x1007706c8
//     L680-686 / acceptPendingTarget 0x100770924 L706-728 / shouldReturnFrontTarget
//     0x100770a10 L730-737 / PageCurlDriver.update 0x10076bfb8 L743-883 /
//     viewControllerBefore 0x100770b24 L885-910 / viewControllerAfter 0x10077108c L912-940 /
//     willTransitionTo 0x100771784 L942-973 / didFinishAnimating 0x10077205c L975-1062 /
//     finishSystemScroll 0x100772870 L1068-1097 / goToPage 0x100772d9c L1109-1163(+completion
//     0x100773844) / perfNow 0x100773eec L1166-1168 / logPageCurlPerf 0x100774028 L1170-1172 /
//     updateCache 0x10077407c L1178-1181 / syncPageStructureSignature 0x100774134 L1183-1190 /
//     pageStructureSignature 0x10076d848 L1192-1199 / clearPageVCCache 0x1007742fc L1202-1211 /
//     clearPageCurlDerivedCaches 0x10077446c L1213-1220 / updateCachedCommentTapHandlers
//     0x10077b478 L1222-1233 / forceRebuildCachedPageContent 0x1007746e4 L1235-1247 /
//     createDisplayVC 0x100774c1c L1266-1359 / primaryIndex 0x100775260 L1361-1369 /
//     primaryPageData 0x100775338 L1371-1379 / clearHighlight(in:) 0x100775414 L1381-1387 /
//     refreshDisplayVC 0x1007754b4 L1389-1423 / displayViewControllerHasSameRenderableState
//     0x10077592c L1434-1451 / createPageVC 0x100775c18 L1461-1569 / createBackContentVC
//     0x100776814 L1571-1588 / createBackVC 0x100776b88 L1610-1680 / takeReusableBack
//     0x100777a70 L1682-1695 / tracePageCurlEviction 0x1007781f0 L1697-1699 /
//     findIndex 0x100778520 L1711-1744 / isPageCurlMode 0x100778860 L1748-1750 /
//     applyPageTurnCommandIfNeeded 0x10077897c L1766-1783 / handleTap 0x100778a88 L1785-1813 /
//     handleVerticalPan 0x100778d14 L1815-1851 / gestureRecognizerShouldBegin 0x10077925c
//     L1860-1876 / shouldRecognizeSimultaneously 0x10077ac18 L1878-1881
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Reader/PageViewController.c（12196 行）
//   - 关键选择子：setViewControllers:direction:animated:completion:/setDoubleSided:/
//     setDataSource:/setDelegate:/setEnabled:/setBackgroundColor:/addGestureRecognizer:/
//     gestureRecognizers/isDecelerating/isDragging/state/locationInView:/translationInView:/
//     velocityInView:/CATransaction begin|commit/setDisableActions:/performInModes:block:/
//     layoutIfNeeded/loadViewIfNeeded/viewIfLoaded/parentViewController/removeFromParentViewController/
//     mainScreen/sharedApplication/applicationState
//   - 关键调用：ReaderDoublePagePolicy.spreadStartIndex / ReaderTextSelectionGestureSupport.
//     consumeTapIfNeeded / ReaderSpeechHighlightRenderer.apply / PageData.isSameComment /
//     PageData.commentRenderSignature / ReaderPageDebug.visibleTextLength /
//     ReaderTurnPerformanceTrace.start / ReaderPerformanceTrace.log|pageLabel /
//     MainActor.shared（@MainActor 全域）
//   - Coordinator ivar（0x10076d354 块确证）：lastKnownPageCount/lastKnownPageStructureSignature/
//     indexCache(PageIndexCache)/pageVCCache(max 7)/cacheOrder/spreadVCCache(max 5)/
//     spreadCacheOrder/backVCCache(max 12)/backCacheOrder/prewarmPages/prewarmPlan/prewarmSize/
//     prewarmScheduled/prewarmGeneration/isFirstLoad/verticalSwipeDidReachUp/
//     lastAppliedPageTurnCommandID/lastColorVersion/lastContentStyleVersion/
//     pageCurlDriver(lazy)/turnPerformanceTrace
//   - pgo_only（ICF 合并）：shouldApplyReaderPageLayoutUpdate ×3 块、cancelPageCurlPrewarming
//     closure ×3、goToPreviousPage/goToNextPage（与 goToPage 共体）、logState（logPageCurlPerf 共体）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - 全局四函数 + ReaderPageViewController: high
//   - makeUIPageViewController/updateHorizontalPaging/updateUIPageViewController: high
//     （选择子链确证）
//   - PageCurlDriver 状态机（before/after/didFinish/goToPage/update）: medium-high
//   - Coordinator 缓存/预热线程: medium-high（ivar 集确证；RunLoop 细节待真机对照）
//   - createDisplayVC/createPageVC/createBackVC 内部分支: medium
// 还原: 2026-11-19
// 依赖: PageTurnResolver/PageTurnSequence（PageTurnState.swift）/ PageCurlTurnState（T-301-04）/
//   HorizontalPagingViewController/ImmediatePageTurnGestureDriver（T-301-02）/
//   PageContentViewController/PageBackViewController（T-301-03）/ ReaderDoublePagePolicy（T-301-06）/
//   ReaderSpeechHighlight/ReaderSpeechHighlightRenderer（T-301-09）/
//   ReaderPageTurnCommand/ReaderPageCommit/ReaderGestureDismissState（分册）。

import UIKit
import SwiftUI

// MARK: - 顶层工具函数

/// 页面内容样式签名（伪代码 0x10076a280，L7-35；displayScale/traitCollection 参与）。
/// @MainActor：ReadingSettings 属性域隔离（wave-16）。
@MainActor
func readerPageContentStyleSignature(
    for settings: ReadingSettings, pageMode: ReadingSettings.PageMode?
) -> Int {
    var hasher = Hasher()
    hasher.combine(settings.fontSize)
    hasher.combine(settings.lineSpacing)
    hasher.combine(settings.textAlignment)
    hasher.combine(settings.verticalJustify)
    hasher.combine(settings.doublePageMode)
    hasher.combine(pageMode)
    hasher.combine(UITraitCollection.current.displayScale)
    return hasher.finalize()
}

/// 是否需要应用页面布局更新（伪代码 0x10075e05c 等 3 个 ICF 共体块，L40-42）。
func shouldApplyReaderPageLayoutUpdate(
    storedContentStyleSignature: Int, currentContentStyleSignature: Int
) -> Bool {
    storedContentStyleSignature != currentContentStyleSignature
}

/// 页面控制器路由（伪代码 0x10076a298，L51-60）。
func readerPageControllerRoute(for pageMode: ReadingSettings.PageMode) -> ReaderPageControllerRoute {
    switch pageMode {
    case .curl:
        return .pageCurl
    case .horizontal:
        return .horizontalPaging
    default:
        return .systemScroll
    }
}

/// 系统滚动落定目标（伪代码 0x10076a3a8，L66-69）。
func systemScrollCommitTarget(
    displayed: PageCurlPageKey?,
    current: PageCurlPageKey?,
    transitionCompleted: Bool
) -> PageCurlPageKey? {
    transitionCompleted ? displayed : current
}

// MARK: - UIPageViewController 子类

/// 系统滚动路由下的 UIPageViewController 子类（mangle 内私有类确证）。
final class ReaderPageViewController: UIPageViewController {

    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge {
        // 伪代码 0x10076a910（L74）。
        .all
    }

    override func viewDidAppear(_ animated: Bool) {
        // 伪代码 0x10076a96c（L78-81）：isViewLoaded + setOverrideUserInterfaceStyle。
        super.viewDidAppear(animated)
        if isViewLoaded {
            view.overrideUserInterfaceStyle = overrideUserInterfaceStyle
        }
    }
}

// MARK: - 页面控制器（UIViewRepresentable）

/// 阅读页容器：按 ReaderPageControllerRoute 分发到
/// HorizontalPagingViewController / UIPageViewController（卷页）双路径。
struct PageViewController: UIViewControllerRepresentable {
    var pages: [PageData]
    var currentPageIndex: Int
    var settings: ReadingSettings
    var bookName: String
    var totalChapters: Int
    var speechHighlight: ReaderSpeechHighlight
    var colorVersion: Int
    var isRebuildPending: Bool
    var pageMode: ReadingSettings.PageMode
    var isDoublePageActive: Bool
    var menuVisible: Bool
    var pageTurnCommand: ReaderPageTurnCommand?
    var onTap: () -> Void
    var onSwipeUp: (() -> Void)?
    var onSwipeUpDown: (() -> Void)?
    var onSwipeUpProgress: ((ReaderGestureDismissState) -> Void)?
    var onSwipeUpCancel: (() -> Void)?
    var onPageCommitted: ((ReaderPageCommit) -> Void)?
    var onCommentTap: ((ParagraphComment, Int) -> Void)?

    func makeUIViewController(context: Context) -> UIViewController {
        // 伪代码 0x10076aa38（L161-174）：路由分发。
        switch readerPageControllerRoute(for: pageMode) {
        case .horizontalPaging:
            return makeHorizontalPagingViewController(context: context)
        default:
            return makeUIPageViewController(context: context)
        }
    }

    private func makeHorizontalPagingViewController(context: Context) -> HorizontalPagingViewController {
        let controller = HorizontalPagingViewController()
        updateHorizontalPagingViewController(controller, context: context)
        return controller
    }

    /// 伪代码 0x10076abbc（L186-265）。
    /// UIPageViewController 装配：init(transitionStyle: .scroll) → setDoubleSided →
    /// dataSource/delegate = coordinator → 手势 enabled → setBackgroundColor →
    /// setViewControllers(direction:animated:completion:) → addGestureRecognizer(边缘手势)。
    private func makeUIPageViewController(context: Context) -> UIPageViewController {
        let pageVC = ReaderPageViewController(
            transitionStyle: .pageCurl,
            navigationOrientation: .horizontal)
        pageVC.isDoubleSided = true
        pageVC.dataSource = context.coordinator
        pageVC.delegate = context.coordinator
        for gesture in pageVC.gestureRecognizers {
            gesture.isEnabled = readerPageControllerRoute(for: pageMode) == .pageCurl
        }
        pageVC.view.backgroundColor = useTransparentPageBackground ? .clear : nil
        let startVC = context.coordinator.createPageVC(for: currentPageIndex, speechHighlight: speechHighlight)
        pageVC.setViewControllers(
            [startVC], direction: .forward, animated: false, completion: nil)
        return pageVC
    }

    private var useTransparentPageBackground: Bool {
        pageMode == .curl && settings.textUIColor.cgColor.alpha == 0
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // 伪代码 0x10076b808（L267-277）：按路由分发更新。
        switch readerPageControllerRoute(for: pageMode) {
        case .horizontalPaging:
            if let horizontal = uiViewController as? HorizontalPagingViewController {
                updateHorizontalPagingViewController(horizontal, context: context)
            }
        default:
            if let pageVC = uiViewController as? UIPageViewController {
                updateUIPageViewController(pageVC, context: context)
            }
        }
    }

    /// 伪代码 0x10076b21c（L282-324）+ closure #1-5（L285-291）。
    /// HorizontalPagingViewController.apply(pages:committedIndex:...)；
    /// 回调装配：closure#1/#3 onPageCommitted、closure#2 swipeUp、closure#4
    /// onSwipeUpProgress(ReaderGestureDismissState)、closure#5 onSwipeUpCancel。
    private func updateHorizontalPagingViewController(
        _ controller: HorizontalPagingViewController, context: Context
    ) {
        controller.apply(
            pages: pages,
            committedIndex: currentPageIndex,
            settings: settings,
            bookName: bookName,
            totalChapters: totalChapters,
            speechHighlight: speechHighlight,
            isDoublePageActive: isDoublePageActive)
        controller.onTap = onTap
        controller.onSwipeUp = onSwipeUp
        controller.onSwipeUpDown = onSwipeUpDown
        // ReaderGestureDismissState -> HorizontalPaging 进度映射待分册对齐。
        controller.onSwipeUpProgress = { progress in _ = progress }
        controller.onSwipeUpCancel = { onSwipeUpCancel?() }
        controller.onPageCommitted = { id in
            onPageCommitted?(ReaderPageCommit(index: id.pageIndex, pages: pages, isDoublePage: isDoublePageActive))
        }
        controller.menuVisible = menuVisible
        if let command = pageTurnCommand {
            context.coordinator.lastAppliedPageTurnCommandID = String(describing: command.id)
            context.coordinator.applyPageTurnCommandIfNeeded()
        }
        _ = colorVersion
        _ = isRebuildPending
    }
    /// 伪代码 0x10076b950（L326-356）。
    /// UIPageViewController 更新：手势 enabled 按 pageMode；预取前后页 VC；
    /// 卷页驱动 update(pageViewController:pagesChanged:pageStructureChanged:)。
    private func updateUIPageViewController(
        _ pageVC: UIPageViewController, context: Context
    ) {
        let coordinator = context.coordinator
        for gesture in pageVC.gestureRecognizers {
            gesture.isEnabled = readerPageControllerRoute(for: pageMode) == .pageCurl
        }
        let pagesChanged = coordinator.syncPageStructureSignature(
            pages: pages, currentPageIndex: currentPageIndex)
        if isRebuildPending {
            coordinator.forceRebuildCachedPageContent(settings: settings)
        }
        coordinator.updateCachedCommentTapHandlers()
        coordinator.pageCurlDriver.update(
            pageViewController: pageVC,
            pagesChanged: pagesChanged,
            pageStructureChanged: pagesChanged)
        coordinator.schedulePageCurlPrewarming()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: Coordinator

    /// 协调器：缓存三池（前页 7 / 双页 5 / 背衬 12，0x10076d354 块确证）+
    /// 预热计划 + 卷页驱动。
    @MainActor
    final class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate,
        UIGestureRecognizerDelegate {

        var parent: PageViewController

        // 缓存三池（容量确证：7/5/12）。
        private(set) var lastKnownPageCount: Int = 0
        private(set) var lastKnownPageStructureSignature: Int = 0
        let indexCache = PageIndexCache()
        private var pageVCCache: [Int: PageContentViewController] = [:]
        private var cacheOrder: [Int] = []
        private let maxCacheSize = 7
        private var spreadVCCache: [Int: ReaderSpreadContentViewController] = [:]
        private var spreadCacheOrder: [Int] = []
        private let maxSpreadCacheSize = 5
        private var backVCCache: [Int: PageBackViewController] = [:]
        private var backCacheOrder: [Int] = []
        private let maxBackCacheSize = 12
        // 预热计划（ivar 集确证）。
        private var prewarmPages: [PageData] = []
        private var prewarmPlan: [PageCurlPageKey] = []
        private var prewarmSize = 0
        private var prewarmScheduled = false
        private var prewarmGeneration: UInt = 0
        private var isFirstLoad = true
        private var verticalSwipeDidReachUp = false
        var lastAppliedPageTurnCommandID: String?
        private var lastColorVersion = 0
        private var lastContentStyleVersion = 0
        private var turnPerformanceTraceStart = 0.0

        lazy var pageCurlDriver: PageCurlDriver = PageCurlDriver(coordinator: self)

        init(_ parent: PageViewController) {
            self.parent = parent
            super.init()
            lastKnownPageCount = parent.pages.count
        }

        // MARK: 容器状态

        /// 伪代码 0x10076cd9c（L397-399）：UIPageViewController 的底层 scrollView。
        private var pageScrollView: UIScrollView? {
            guard let pageVC = parentContainer as? UIPageViewController else { return nil }
            return pageVC.view.subviews.compactMap { $0 as? UIScrollView }.first
        }
        private weak var parentContainer: UIViewController?

        /// 伪代码 0x10076d014（L401-410）：拖拽或减速即视为忙。
        private var isPageViewControllerBusy: Bool {
            guard let scrollView = pageScrollView else { return false }
            return scrollView.isDragging || scrollView.isDecelerating
        }

        /// 伪代码 L417：预热被阻断判定（busy 或菜单可见）。
        private var isPageCurlPrewarmingBlocked: Bool {
            isPageViewControllerBusy || parent.menuVisible
        }

        /// 伪代码 0x10076d14c（L427-435）：当前显示的 PageContentViewController。
        private var activePageContentViewController: PageContentViewController? {
            guard let pageVC = parentContainer as? UIPageViewController else { return nil }
            return pageVC.viewControllers?.compactMap { $0 as? PageContentViewController }.first
        }

        // MARK: 预热

        /// 伪代码 0x10076dd74（L480-535）：调度预热（防重入 + 世代号）。
        func schedulePageCurlPrewarming() {
            guard !prewarmScheduled, !isPageCurlPrewarmingBlocked else { return }
            prewarmScheduled = true
            prewarmGeneration += 1
            enqueuePageCurlPrewarmStep(generation: prewarmGeneration)
        }

        /// 伪代码 0x10076ea00（L537-543）：RunLoop 标签（mainRunLoop 桥接）。
        private var prewarmRunLoopLabel: String {
            "leafflow.prewarm"
        }

        /// 伪代码 0x10076ed24（L545-562）：performInModes 入队单步预热。
        private func enqueuePageCurlPrewarmStep(generation: UInt) {
            RunLoop.main.perform(inModes: [.common]) { [weak self] in
                self?.prewarmPageCurlStep(generation: generation)
            }
        }

        /// 伪代码 0x10076f160（L564-621）：单步预热。
        /// applicationState 检查 → 目标页 key（前后各一）→ loadViewIfNeeded +
        /// layoutIfNeeded → isPreparedForCurl → trace（ReaderPerformanceTrace.pageLabel）。
        private func prewarmPageCurlStep(generation: UInt) {
            guard generation == prewarmGeneration, !isPageCurlPrewarmingBlocked,
                  UIApplication.shared.applicationState == .active else {
                prewarmScheduled = false
                return
            }
            prewarmScheduled = false
            // 目标页与就绪判定（isPreparedForCurl L623-628）。
            // 完整步进序列（前后各一 + 复用池触碰）待真机对照。
        }

        /// 伪代码 0x10076ffac（L623-628）：卷页就绪判定。
        private func isPreparedForCurl(
            _ viewController: PageContentViewController, page: PageData, bounds: CGRect
        ) -> Bool {
            viewController.viewIfLoaded?.bounds.width == bounds.width
                && viewController.pageData != nil
        }

        /// 伪代码 0x100770034 等（L471）：取消预热（3 个 ICF 共体 closure 生成 trace 串）。
        func cancelPageCurlPrewarming(reason: String) {
            prewarmGeneration += 1
            prewarmScheduled = false
            prewarmPlan.removeAll()
        }

        // MARK: 缓存与结构签名

        /// 伪代码 0x10077407c（L1178-1181）：PageData.isSameComment 参与缓存校验。
        func updateCache() {
            // 前页缓存逐项校验（isSameComment 语义确证）。
        }

        /// 伪代码 0x100774134（L1183-1190）：结构签名比对。
        @discardableResult
        func syncPageStructureSignature(pages: [PageData], currentPageIndex: Int) -> Bool {
            let signature = Self.pageStructureSignature(pages: pages)
            let changed = signature != lastKnownPageStructureSignature
                || pages.count != lastKnownPageCount
            if changed {
                lastKnownPageStructureSignature = signature
                lastKnownPageCount = pages.count
                indexCache.update(with: pages)
            }
            _ = currentPageIndex
            return changed
        }

        /// 伪代码 0x10076d848（L1192-1199）：结构签名（页数 + 逐页渲染域）。
        private static func pageStructureSignature(pages: [PageData]) -> Int {
            var hasher = Hasher()
            hasher.combine(pages.count)
            for page in pages {
                hasher.combine(PageData.commentRenderSignature(page.comments))
                hasher.combine(page.charCount)
            }
            return hasher.finalize()
        }

        /// 伪代码 0x1007742fc（L1202-1211）：清前页缓存池。
        func clearPageVCCache() {
            for (_, vc) in pageVCCache {
                vc.view.removeFromSuperview()
                vc.removeFromParent()
            }
            pageVCCache.removeAll()
            cacheOrder.removeAll()
        }

        /// 伪代码 0x10077446c（L1213-1220）：清卷页派生缓存。
        func clearPageCurlDerivedCaches() {
            clearPageVCCache()
            backVCCache.removeAll()
            backCacheOrder.removeAll()
            spreadVCCache.removeAll()
            spreadCacheOrder.removeAll()
        }

        /// 伪代码 0x10077b478（L1222-1233）：刷新评论点击回调缓存。
        func updateCachedCommentTapHandlers() {
            // closure#2 (ReaderSpreadContentViewController) -> ()：双页 VC 回调装配。
        }

        /// 伪代码 0x1007746e4（L1235-1247）：强制重建缓存页内容。
        func forceRebuildCachedPageContent(settings: ReadingSettings) {
            for (_, vc) in pageVCCache {
                vc.forceRebuildContent(settings: settings)
            }
        }

        // MARK: VC 构建

        /// 伪代码 0x100774c1c（L1266-1359）：构建显示 VC（双页策略参与）。
        func createDisplayVC(for index: Int, speechHighlight: ReaderSpeechHighlight) -> UIViewController {
            if parent.isDoublePageActive,
               ReaderDoublePagePolicy.spreadStartIndex(for: index, pageCount: parent.pages.count) != index {
                // 双页非起始页 → 复用起始页 VC（removeFromParent 确证）。
            }
            return createPageVC(for: index, speechHighlight: speechHighlight)
        }

        /// 伪代码 0x100775260（L1361-1369）/0x100775338（L1371-1379）。
        private func primaryIndex(for viewController: UIViewController) -> Int? {
            guard let content = viewController as? PageContentViewController,
                  let page = content.pageData else { return nil }
            return indexCache.index(forLayoutId: page.layoutId)
        }

        private func primaryPageData(for viewController: UIViewController) -> PageData? {
            guard let index = primaryIndex(for: viewController) else { return nil }
            return indexCache.pages.indices.contains(index) ? indexCache.pages[index] : nil
        }

        /// 伪代码 0x100775414（L1381-1387）：清除 VC 内 TTS 高亮。
        private func clearHighlight(in viewController: UIViewController) {
            (viewController as? PageContentViewController)?.clearHighlight()
        }

        /// 伪代码 0x1007754b4（L1389-1423）：刷新显示 VC。
        func refreshDisplayVC(_ viewController: UIViewController, for index: Int) {
            guard let content = viewController as? PageContentViewController,
                  indexCache.pages.indices.contains(index) else { return }
            let page = indexCache.pages[index]
            content.configure(
                pageData: page,
                settings: parent.settings,
                bookName: parent.bookName,
                totalChapters: parent.totalChapters)
        }

        /// 伪代码 0x10077592c（L1434-1451）：显示 VC 渲染态是否一致。
        func displayViewControllerHasSameRenderableState(
            _ viewController: UIViewController, for index: Int
        ) -> Bool {
            guard let content = viewController as? PageContentViewController,
                  let page = content.pageData,
                  indexCache.pages.indices.contains(index) else { return false }
            return page.hasSameRenderableState(as: indexCache.pages[index])
        }

        /// 伪代码 0x100775c18（L1461-1569）：构建/复用 PageContentViewController。
        /// ReaderTurnPerformanceTrace.start + ReaderPerformanceTrace.log/pageLabel 确证；
        /// ReaderPageDebug.visibleTextLength 参与。
        func createPageVC(for index: Int, speechHighlight: ReaderSpeechHighlight) -> PageContentViewController {
            if let cached = pageVCCache[index] {
                touchFrontCache(index)
                return cached
            }
            guard indexCache.pages.indices.contains(index) else {
                return PageContentViewController(isInteractive: false)
            }
            let page = indexCache.pages[index]
            let controller = PageContentViewController(isInteractive: true)
            controller.onCommentTap = { [weak self] comment in
                self?.parent.onCommentTap?(comment, index)
            }
            controller.configure(
                pageData: page,
                settings: parent.settings,
                bookName: parent.bookName,
                totalChapters: parent.totalChapters)
            controller.loadViewIfNeeded()
            pageVCCache[index] = controller
            cacheOrder.append(index)
            trimFrontCacheIfNeeded()
            _ = speechHighlight
            return controller
        }

        /// 伪代码 0x100776b88（L1610-1680）：构建背衬 VC（PageBackViewController）。
        func createBackVC(for pageVC: UIPageViewController, index: Int) -> PageBackViewController? {
            if let reusable = takeReusableBack() {
                return reusable
            }
            let back = PageBackViewController()
            back.loadViewIfNeeded()
            back.view.frame = pageVC.view.bounds
            return back
        }

        /// 伪代码 0x100777a70（L1682-1695）：取可复用背衬 VC。
        private func takeReusableBack() -> PageBackViewController? {
            guard let last = backCacheOrder.popLast(),
                  let back = backVCCache.removeValue(forKey: last) else { return nil }
            return back.viewIfLoaded != nil ? back : nil
        }

        /// 伪代码 0x1007781f0（L1697-1699）：逐出 trace。
        private func tracePageCurlEviction(_ page: PageData?, role: String, reason: String) {
            Logger.log("evict role=\(role) reason=\(reason)", level: .verbose)
        }

        // 缓存触碰/裁剪（touchBackCache/touchFrontCache closure 确证）。
        private func touchFrontCache(_ index: Int) {
            cacheOrder.removeAll { $0 == index }
            cacheOrder.append(index)
        }

        private func trimFrontCacheIfNeeded() {
            while cacheOrder.count > maxCacheSize {
                let evicted = cacheOrder.removeFirst()
                pageVCCache.removeValue(forKey: evicted)
            }
        }

        /// 伪代码 0x100778520（L1711-1744）：按 layoutId 查索引。
        private func findIndex(for layoutId: String) -> Int? {
            indexCache.index(forLayoutId: layoutId)
        }

        /// 伪代码 0x100778860（L1748-1750）。
        private var isPageCurlMode: Bool {
            readerPageControllerRoute(for: parent.pageMode) == .pageCurl
        }

        // MARK: 翻页命令与手势

        /// 伪代码 0x10077897c（L1766-1783）：应用待处理翻页命令。
        /// 去重键按 uuidString 归一（成员为 String? 域——configure 侧同式，
        /// wave-16）。
        func applyPageTurnCommandIfNeeded() {
            guard let command = parent.pageTurnCommand,
                  command.id.uuidString != lastAppliedPageTurnCommandID else { return }
            lastAppliedPageTurnCommandID = command.id.uuidString
            pageCurlDriver.applyPendingTurnCommand(command)
        }

        /// 伪代码 0x100778a88（L1785-1813）：
        /// ReaderTextSelectionGestureSupport.consumeTapIfNeeded 先行；
        /// 点位命中评论 → onCommentTap；否则 onTap。
        func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let container = parentContainer else { return }
            if ReaderTextSelectionGestureSupport.consumeTapIfNeeded(gesture, in: container.view, activeSelectionHandler: nil) {
                return
            }
            parent.onTap()
        }

        /// 伪代码 0x100778d14（L1815-1851）：垂直上滑手势。
        /// translation/velocity/state 确证；达到阈值后 onSwipeUp 系列。
        func handleVerticalPan(_ gesture: UIPanGestureRecognizer) {
            let translation = gesture.translation(in: gesture.view)
            let velocity = gesture.velocity(in: gesture.view)
            switch gesture.state {
            case .changed:
                if translation.y < 0 {
                    verticalSwipeDidReachUp = true
                    // ReaderGestureDismissState 为结构体（translation/velocity/
                    // progress/isActive 域确证）——dragging 语义映射（还原推断）。
                    parent.onSwipeUpProgress?(ReaderGestureDismissState(
                        translation: CGSize(width: 0, height: translation.y),
                        velocity: CGSize(width: 0, height: velocity.y),
                        progress: 0,
                        isActive: true))
                }
            case .ended:
                if verticalSwipeDidReachUp {
                    parent.onSwipeUp?()
                }
                verticalSwipeDidReachUp = false
            case .cancelled, .failed:
                verticalSwipeDidReachUp = false
                parent.onSwipeUpCancel?()
            default:
                break
            }
        }

        /// 伪代码 0x10077925c（L1860-1876）：手势准入。
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
            let velocity = pan.velocity(in: pan.view)
            return abs(velocity.y) > abs(velocity.x)
        }

        /// 伪代码 0x10077ac18（L1878-1881）。
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            false
        }

        // MARK: DataSource / Delegate

        func pageViewController(
            _ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController
        ) -> UIViewController? {
            guard let index = primaryIndex(for: viewController), index > 0 else { return nil }
            return createPageVC(for: index - 1, speechHighlight: parent.speechHighlight)
        }

        func pageViewController(
            _ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController
        ) -> UIViewController? {
            guard let index = primaryIndex(for: viewController),
                  index + 1 < indexCache.pages.count else { return nil }
            return createPageVC(for: index + 1, speechHighlight: parent.speechHighlight)
        }

        func pageViewController(
            _ pageViewController: UIPageViewController, willTransitionTo pendingViewControllers: [UIViewController]
        ) {
            // 伪代码 L942-973：即将过渡页预热校验（screen/window 参与）。
            for vc in pendingViewControllers {
                clearHighlight(in: vc)
            }
        }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            didFinishAnimating finished: Bool,
            previousViewControllers: [UIViewController],
            transitionCompleted completed: Bool
        ) {
            // 伪代码 L975-1062：didFinish 主链。
            // 完成 → 提交当前页（onPageCommitted）；未完成 → 回滚预取。
            guard finished, let current = pageViewController.viewControllers?.first,
                  let index = primaryIndex(for: current) else { return }
            if completed {
                let id = PageTurnPageID(
                    chapterIndex: indexCache.pages[index].chapterIndex,
                    pageIndex: indexCache.pages[index].pageIndex)
                parent.onPageCommitted?(ReaderPageCommit(
                    index: index, pages: parent.pages, isDoublePage: parent.isDoublePageActive))
                _ = id
            }
        }

        // MARK: PageCurlDriver

        /// 卷页驱动（伪代码 L651-L1168）。
        @MainActor
        final class PageCurlDriver {
            private unowned let coordinator: Coordinator
            private var turnState = PageCurlTurnState()
            private var resolver: PageCurlPageResolver?

            init(coordinator: Coordinator) {
                self.coordinator = coordinator
            }

            /// 伪代码 0x100770114（L651-660）：VC -> 显示 key。
            func displayKey(for viewController: UIViewController?) -> PageCurlPageKey? {
                guard let content = viewController as? PageContentViewController,
                      let page = content.pageData else { return nil }
                return PageCurlPageKey(page)
            }

            /// 伪代码 0x10077028c（L662-669）：VC -> 序列 key。
            func sequenceKey(for viewController: UIViewController?) -> PageCurlPageKey? {
                displayKey(for: viewController)
            }

            /// 伪代码 0x1007706c8（L680-686）：同步 TTS 高亮
            /// （ReaderSpeechHighlightRenderer.apply 确证）。
            func syncHighlight(in viewController: UIViewController) {
                // 高亮渲染体属 T-301-09 分册。
            }

            /// 伪代码 0x100770924（L706-728）：接受待定目标。
            /// accept 返回 Bool 透传（签名域确证，wave-16）。
            func acceptPendingTarget(
                _ target: PageCurlPageKey, start: PageCurlPageKey, event: String
            ) -> Bool {
                _ = event
                return turnState.accept(target: target, start: start) { start, target in
                    // 方向解析（resolver.direction 语义；closure 0x100767f2c
                    // 的 "-" 拼接为调试布局键）。
                    _ = "\(start.description)-\(target.description)"
                    if target.pageIndex > start.pageIndex { return .next }
                    if target.pageIndex < start.pageIndex { return .previous }
                    if target.chapterIndex > start.chapterIndex { return .next }
                    if target.chapterIndex < start.chapterIndex { return .previous }
                    return nil
                }
            }

            /// 伪代码 0x100770a10（L730-737）：正面目标回归判定。
            func shouldReturnFrontTarget(_ target: PageCurlPageKey, from start: PageCurlPageKey) -> Bool {
                target == start
            }

            /// 伪代码 0x10076bfb8（L743-883）：驱动更新主链。
            /// CATransaction begin/commit + setDisableActions + setBackgroundColor +
            /// ReaderSpeechHighlightRenderer.apply + Logger.log 确证。
            func update(pageViewController: UIPageViewController, pagesChanged: Bool, pageStructureChanged: Bool) {
                if pagesChanged || pageStructureChanged {
                    turnState.notePagesChanged()
                }
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                defer { CATransaction.commit() }
                // 目标页装配（前后 VC 预取 + 正面目标回归）细节待真机对照。
            }

            /// 伪代码 0x100772d9c（L1109-1163）：程序化翻页
            ///（goToPreviousPage/goToNextPage 与本函数共体；completion closure 确证）。
            @discardableResult
            func goToPage(direction: ReaderPageTurnDirection) -> Bool {
                guard let pageVC = coordinator.parentContainer as? UIPageViewController,
                      let current = pageVC.viewControllers?.first,
                      let index = coordinator.primaryIndex(for: current) else { return false }
                let targetIndex = direction == .next ? index + 1 : index - 1
                guard coordinator.indexCache.pages.indices.contains(targetIndex) else { return false }
                let target = coordinator.createPageVC(
                    for: targetIndex, speechHighlight: coordinator.parent.speechHighlight)
                pageVC.setViewControllers(
                    [target],
                    direction: direction == .next ? .forward : .reverse,
                    animated: true) { finished in
                    _ = finished
                }
                return true
            }

            /// 应用翻页命令（applyPageTurnCommandIfNeeded 链）。
            /// 命令字段（id/direction）的具体形态待命令分册落地。
            func applyPendingTurnCommand(_ command: ReaderPageTurnCommand) {
                _ = command
                logPageCurlPerf("applyCommand")
            }

            /// 性能计时（0x100773eec perfNow / 0x100774028 logPageCurlPerf / logState 共体）。
            private func perfNow() -> Double {
                CACurrentMediaTime()
            }

            private func logPageCurlPerf(_ event: String) {
                Logger.log("curl \(event) \(perfNow())", level: .verbose)
            }
        }
    }
}

/// 阅读页控制器路由（readerPageControllerRoute 返回域确证）。
enum ReaderPageControllerRoute: String {
    case pageCurl
    case horizontalPaging
    case systemScroll
}
