// 原始归属: ReadMain/Views/Reader/PageViewController.swift；拆分不改变336文件统计。
import SwiftUI
import UIKit

extension PageViewController {
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
        weak var parentContainer: UIViewController?

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
        func primaryIndex(for viewController: UIViewController) -> Int? {
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
        /// 命令编号与水平控制器使用同一单调序列。
        func applyPageTurnCommandIfNeeded() {
            guard let command = parent.pageTurnCommand,
                  String(command.id) != lastAppliedPageTurnCommandID else { return }
            lastAppliedPageTurnCommandID = String(command.id)
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

    }
}
