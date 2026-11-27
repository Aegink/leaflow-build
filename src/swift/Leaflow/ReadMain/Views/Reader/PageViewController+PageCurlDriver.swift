// 原始归属: ReadMain/Views/Reader/PageViewController.swift；拆分不改变336文件统计。
// 0x100770b24/0x10077108c前后页、0x100771784开始、0x10077205c结束、0x100772d9c命令。
import UIKit

extension PageViewController.Coordinator {
    @MainActor
    final class PageCurlDriver: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        private unowned let coordinator: PageViewController.Coordinator
        private(set) var turnState = PageCurlTurnState()
        private var commandBuffer = ReaderPageTurnCommandBuffer()
        private var programmaticTurnInFlight = false

        init(coordinator: PageViewController.Coordinator) {
            self.coordinator = coordinator
            super.init()
        }

        private var resolver: PageCurlPageResolver {
            PageCurlPageResolver(pages: coordinator.parent.pages,
                isDoublePage: coordinator.parent.isDoublePageActive)
        }

        private var isCurl: Bool {
            readerPageControllerRoute(for: coordinator.parent.pageMode) == .pageCurl
        }

        func displayKey(for viewController: UIViewController?) -> PageCurlPageKey? {
            if let content = viewController as? PageContentViewController {
                return resolver.key(for: content.pageData)
            }
            if let spread = viewController as? ReaderSpreadContentViewController,
               let index = spread.visiblePageIndices.first {
                return resolver.key(at: index)
            }
            return nil
        }

        func sequenceKey(for viewController: UIViewController?) -> PageCurlPageKey? {
            if let back = viewController as? PageBackViewController,
               let index = coordinator.indexCache.index(forLayoutId: back.associatedPageId) {
                return resolver.key(at: index)
            }
            return displayKey(for: viewController)
        }

        func syncHighlight(in viewController: UIViewController) {
            let index = resolver.index(for: displayKey(for: viewController))
            let highlight = coordinator.parent.speechHighlight
            ReaderSpeechHighlightRenderer.apply(
                highlight.pageIndex == index ? highlight : .none, to: viewController, pageIndex: index)
        }

        func acceptPendingTarget(_ target: PageCurlPageKey, start: PageCurlPageKey, event: String) -> Bool {
            let accepted = turnState.accept(target: target, start: start, directionFrom: resolver.direction)
            if !accepted { logPageCurlPerf("拒绝目标 \(target)，事件 \(event)") }
            return accepted
        }

        // 0x100770a10：空闲或回到起点可返回；否则必须通过状态机的方向/目标检查。
        func shouldReturnFrontTarget(_ target: PageCurlPageKey, from start: PageCurlPageKey) -> Bool {
            if turnState.phase == .idle || target == turnState.startKey { return true }
            return acceptPendingTarget(target, start: turnState.startKey ?? start, event: "正面请求")
        }

        func update(pageViewController: UIPageViewController, pagesChanged: Bool, pageStructureChanged: Bool) {
            if (pagesChanged || pageStructureChanged), turnState.phase != .idle {
                turnState.notePagesChanged()
            }
            guard !programmaticTurnInFlight, !turnState.isActive,
                  !coordinator.isPageViewControllerBusy else { return }
            let parent = coordinator.parent
            guard let target = resolver.key(at: parent.currentPageIndex),
                  let index = resolver.index(for: target) else { return }
            let current = pageViewController.viewControllers?.first
            if displayKey(for: current) != target {
                turnState.reset()
                let content = coordinator.createDisplayVC(for: index, speechHighlight: parent.speechHighlight)
                pageViewController.setViewControllers([content], direction: .forward, animated: false)
            } else if let current {
                coordinator.refreshDisplayVC(current, for: index)
                syncHighlight(in: current)
            }
            consumePendingCommand()
        }

        func pageViewController(_ pageViewController: UIPageViewController,
                                viewControllerBefore viewController: UIViewController) -> UIViewController? {
            adjacentController(pageViewController, from: viewController, direction: .previous)
        }

        func pageViewController(_ pageViewController: UIPageViewController,
                                viewControllerAfter viewController: UIViewController) -> UIViewController? {
            adjacentController(pageViewController, from: viewController, direction: .next)
        }

        private func adjacentController(_ pageVC: UIPageViewController, from controller: UIViewController,
                                        direction: ReaderPageTurnDirection) -> UIViewController? {
            guard !coordinator.parent.menuVisible, let source = sequenceKey(for: controller) else { return nil }
            if isCurl {
                if controller is PageBackViewController {
                    let target = direction == .previous ? source : resolver.adjacentKey(from: source, direction: .next)
                    guard let target, shouldReturnFrontTarget(target, from: source),
                          let index = resolver.index(for: target) else { return nil }
                    return coordinator.createDisplayVC(for: index, speechHighlight: coordinator.parent.speechHighlight)
                }
                let target = resolver.adjacentKey(from: source, direction: direction)
                guard let target else { return nil }
                // 下一页经过当前纸张背面；上一页经过上一张纸的背面。
                let backKey = direction == .next ? source : target
                guard let index = resolver.index(for: backKey) else { return nil }
                return coordinator.createBackVC(for: pageVC, index: index)
            }
            guard let target = resolver.adjacentKey(from: source, direction: direction),
                  let index = resolver.index(for: target) else { return nil }
            return coordinator.createDisplayVC(for: index, speechHighlight: coordinator.parent.speechHighlight)
        }

        func pageViewController(_ pageViewController: UIPageViewController,
                                willTransitionTo pendingViewControllers: [UIViewController]) {
            guard let start = displayKey(for: pageViewController.viewControllers?.first) else { return }
            turnState.begin(start: start)
            coordinator.cancelPageCurlPrewarming(reason: "开始翻页")
            for controller in pendingViewControllers {
                if let target = displayKey(for: controller) {
                    _ = acceptPendingTarget(target, start: start, event: "开始手势")
                }
            }
        }

        func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool,
                                previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
            finish(pageViewController, completed: completed)
        }

        private func finish(_ pageVC: UIPageViewController, completed: Bool) {
            let current = pageVC.viewControllers?.first
            let result = turnState.complete(displayed: displayKey(for: current), completed: completed)
            if case .committed(let key, _, _) = result, let index = resolver.index(for: key) {
                coordinator.parent.currentPageIndex = index
                if let current {
                    coordinator.refreshDisplayVC(current, for: index)
                    syncHighlight(in: current)
                }
                coordinator.parent.onPageCommitted?(ReaderPageCommit(
                    index: index, pages: coordinator.parent.pages,
                    isDoublePage: coordinator.parent.isDoublePageActive))
            } else if let current, let index = resolver.index(for: displayKey(for: current)) {
                coordinator.refreshDisplayVC(current, for: index)
                syncHighlight(in: current)
            }
            programmaticTurnInFlight = false
            coordinator.schedulePageCurlPrewarming()
            // 等UIKit完成本轮回调再发起下一条命令，避免嵌套转场。
            DispatchQueue.main.async { [weak self] in self?.consumePendingCommand() }
        }

        // 0x100773844 L1148-1161：命令完成使用捕获的目标键，重新解析当前数组。
        // UIKit双面动画返回的控制器序列可能首先是纸背，不能据此丢失目标提交。
        private func finishCommand(_ pageVC: UIPageViewController, target: PageCurlPageKey,
                                   content: UIViewController, completed: Bool) {
            turnState.reset()
            programmaticTurnInFlight = false
            if completed, let index = resolver.index(for: target) {
                coordinator.parent.currentPageIndex = index
                coordinator.refreshDisplayVC(content, for: index)
                syncHighlight(in: content)
                coordinator.parent.onPageCommitted?(ReaderPageCommit(
                    index: index, pages: coordinator.parent.pages,
                    isDoublePage: coordinator.parent.isDoublePageActive))
            }
            // 提交后的SwiftUI更新也走此入口；同步样本/非SwiftUI宿主同样恢复到正面。
            update(pageViewController: pageVC, pagesChanged: false, pageStructureChanged: false)
            coordinator.schedulePageCurlPrewarming()
        }

        func commandViewControllers(_ pageVC: UIPageViewController, content: UIViewController,
                                    start: PageCurlPageKey, targetIndex: Int,
                                    direction: ReaderPageTurnDirection) -> [UIViewController]? {
            guard isCurl else { return [content] }
            // 0x100772d9c L1109-1163：前翻配当前纸背，回翻配目标纸背。
            let backIndex = direction == .next ? resolver.index(for: start) : targetIndex
            guard let backIndex, let back = coordinator.createBackVC(for: pageVC, index: backIndex) else {
                return nil
            }
            return [content, back]
        }

        @discardableResult
        func goToPage(direction: ReaderPageTurnDirection) -> Bool {
            guard !programmaticTurnInFlight, !turnState.isActive, !coordinator.parent.menuVisible,
                  !coordinator.isPageViewControllerBusy,
                  let pageVC = coordinator.parentContainer as? UIPageViewController,
                  let start = displayKey(for: pageVC.viewControllers?.first),
                  let target = resolver.adjacentKey(from: start, direction: direction),
                  let index = resolver.index(for: target) else { return false }
            turnState.begin(start: start)
            guard acceptPendingTarget(target, start: start, event: "翻页命令") else {
                turnState.reset()
                return false
            }
            let content = coordinator.createDisplayVC(for: index, speechHighlight: coordinator.parent.speechHighlight)
            guard let controllers = commandViewControllers(pageVC, content: content,
                start: start, targetIndex: index, direction: direction) else {
                turnState.reset()
                return false
            }
            programmaticTurnInFlight = true
            coordinator.cancelPageCurlPrewarming(reason: "翻页命令")
            pageVC.setViewControllers(controllers, direction: direction == .next ? .forward : .reverse,
                                     animated: true) { [weak self, weak pageVC] finished in
                guard let self, let pageVC else { return }
                self.finishCommand(pageVC, target: target, content: content, completed: finished)
            }
            return true
        }

        func applyPendingTurnCommand(_ command: ReaderPageTurnCommand?) {
            commandBuffer.submit(command)
            consumePendingCommand()
        }

        private func consumePendingCommand() {
            guard !coordinator.parent.pages.isEmpty, !coordinator.parent.menuVisible,
                  !programmaticTurnInFlight, !turnState.isActive, !coordinator.isPageViewControllerBusy,
                  let pageVC = coordinator.parentContainer as? UIPageViewController,
                  displayKey(for: pageVC.viewControllers?.first) != nil,
                  let command = commandBuffer.take() else { return }
            _ = goToPage(direction: command.direction)
        }

        private func logPageCurlPerf(_ event: String) {
            Logger.log("卷页 \(event) \(CACurrentMediaTime())", level: .verbose)
        }
    }
}
