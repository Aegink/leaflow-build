// 原始归属: ReadMain/Views/Reader/PageViewController.swift；拆分不改变336文件统计。
import UIKit

extension PageViewController.Coordinator {
    // MARK: PageCurlDriver

    /// 卷页驱动（伪代码 L651-L1168）。
    @MainActor
    final class PageCurlDriver {
        private unowned let coordinator: PageViewController.Coordinator
        private var turnState = PageCurlTurnState()
        private var resolver: PageCurlPageResolver?

        init(coordinator: PageViewController.Coordinator) {
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
