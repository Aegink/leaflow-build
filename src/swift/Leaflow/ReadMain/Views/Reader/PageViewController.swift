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

/// SwiftUI异步更新可能从后台进入Representable；UIKit更新必须显式切回主线程。
nonisolated func performReaderUIUpdate(_ update: @escaping @MainActor () -> Void) {
    if Thread.isMainThread {
        MainActor.assumeIsolated { update() }
    } else {
        DispatchQueue.main.async { update() }
    }
}

// MARK: - 顶层工具函数

/// 页面内容样式签名（伪代码 0x10076a280，L7-35；displayScale/traitCollection 参与）。
/// @MainActor：ReadingSettings 属性域隔离（wave-16）。
@MainActor
func readerPageContentStyleSignature(
    for settings: ReadingSettings, pageMode: ReadingSettings.PageMode?
) -> Int {
    var hasher = Hasher()
    hasher.combine(settings.paginationSettingsSignature)
    hasher.combine(settings.fontSize)
    hasher.combine(settings.lineSpacing)
    hasher.combine(settings.textAlignment)
    hasher.combine(settings.verticalJustify)
    hasher.combine(settings.doublePageMode)
    hasher.combine(settings.typographyRevision)
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
@MainActor
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
    var onPaginationMetrics: ((CGSize, UIEdgeInsets) -> Void)? = nil
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
        makeUIPageViewController(coordinator: context.coordinator)
    }

    // 与固定样本共用生产装配入口。
    func makeUIPageViewController(coordinator: Coordinator) -> UIPageViewController {
        let isCurl = readerPageControllerRoute(for: pageMode) == .pageCurl
        let pageVC = ReaderPageViewController(
            transitionStyle: isCurl ? .pageCurl : .scroll,
            navigationOrientation: .horizontal,
            options: [.spineLocation: UIPageViewController.SpineLocation.min.rawValue])
        coordinator.parentContainer = pageVC
        pageVC.isDoubleSided = isCurl
        pageVC.dataSource = coordinator.pageCurlDriver
        pageVC.delegate = coordinator.pageCurlDriver
        for gesture in pageVC.gestureRecognizers {
            if gesture is UITapGestureRecognizer { gesture.isEnabled = false }
        }
        pageVC.view.backgroundColor = .white
        let tap = UITapGestureRecognizer(target: coordinator, action: #selector(Coordinator.handleTap(_:)))
        tap.delegate = coordinator
        pageVC.view.addGestureRecognizer(tap)
        let pan = UIPanGestureRecognizer(target: coordinator, action: #selector(Coordinator.handleVerticalPan(_:)))
        pan.delegate = coordinator
        pageVC.view.addGestureRecognizer(pan)
        let resolver = PageCurlPageResolver(pages: pages, isDoublePage: isDoublePageActive)
        let index = resolver.index(for: resolver.key(at: currentPageIndex)) ?? 0
        let startVC = pages.isEmpty ? UIViewController()
            : coordinator.createDisplayVC(for: index, speechHighlight: speechHighlight)
        pageVC.setViewControllers(
            [startVC], direction: .forward, animated: false, completion: nil)
        return pageVC
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        performReaderUIUpdate { applyViewControllerUpdate(uiViewController, context: context) }
    }

    private func applyViewControllerUpdate(_ uiViewController: UIViewController, context: Context) {
        context.coordinator.parent = self
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
        controller.onPaginationMetrics = onPaginationMetrics
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
        controller.onPageCommitted = onPageCommitted
        controller.menuVisible = menuVisible
        controller.submitPageTurnCommand(pageTurnCommand)
        if controller.isViewLoaded { controller.view.setNeedsLayout() }
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
        coordinator.applyPageTurnCommandIfNeeded()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

}

/// 阅读页控制器路由（readerPageControllerRoute 返回域确证）。
enum ReaderPageControllerRoute: String {
    case pageCurl
    case horizontalPaging
    case systemScroll
}
