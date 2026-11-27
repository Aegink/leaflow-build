// 原路径: ReadMain/Views/Reader/Manga/MangaPagedView.swift
// 证据:
//   - PGO: 8 个主函数（index/task_functions.csv T-304-04 / MangaPagedView.swift），
//     地址：makeUIViewController 0x100614f2c L13-28 / Coordinator.init
//     0x100615318 L59-65 / pageController(for:) 0x100615534 L67-81 /
//     navigatePage(direction:) 0x100615640 L83-93 / viewControllerBefore
//     0x10061592c L97-101 / didFinishAnimating 0x100615b14 L111-124
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Reader/Manga/MangaPagedView.c
//   - 事实：漫画分页容器（UIPageViewController + 池化页控制器确证）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（分页链确证）
// 还原: 2026-11-19

import SwiftUI
import UIKit

/// 漫画分页视图（UIPageViewController 承载）。
struct MangaPagedView: UIViewControllerRepresentable {

    var pages: [MangaPage]
    var startIndex: Int
    var onCenterTap: () -> Void
    var onPageChange: (Int) -> Void

    func makeUIViewController(context: Context) -> UIPageViewController {
        // 伪代码 0x100614f2c（L13-28）。
        let controller = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal)
        controller.dataSource = context.coordinator
        controller.delegate = context.coordinator
        context.coordinator.controller = controller
        guard pages.indices.contains(startIndex),
              let first = context.coordinator.pageController(for: startIndex) else {
            return controller
        }
        controller.setViewControllers(
            [first], direction: .forward, animated: false, completion: nil)
        return controller
    }

    func updateUIViewController(_ controller: UIPageViewController, context: Context) {
        context.coordinator.update(pages: pages, selectedIndex: startIndex,
                                   onCenterTap: onCenterTap, onPageChange: onPageChange)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            pages: pages, startIndex: startIndex,
            onCenterTap: onCenterTap, onPageChange: onPageChange)
    }

    // MARK: Coordinator

    @MainActor
    final class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {

        var pages: [MangaPage]
        weak var controller: UIPageViewController?
        private var startIndex: Int
        private var onCenterTap: () -> Void
        private var onPageChange: (Int) -> Void
        private var pageCache: [Int: MangaPageContentViewController] = [:]
        private var transitioning = false
        private var deferredIndex: Int?

        /// 伪代码 0x100615318（L59-65）。
        init(
            pages: [MangaPage], startIndex: Int,
            onCenterTap: @escaping () -> Void,
            onPageChange: @escaping (Int) -> Void
        ) {
            self.pages = pages
            self.startIndex = startIndex
            self.onCenterTap = onCenterTap
            self.onPageChange = onPageChange
        }

        /// 伪代码 0x100615534（L67-81）：池化页控制器。
        func pageController(for index: Int) -> MangaPageContentViewController? {
            guard pages.indices.contains(index) else { return nil }
            if let cached = pageCache[index] {
                return cached
            }
            let controller = MangaPageContentViewController()
            controller.configure(page: pages[index], totalPages: pages.count)
            controller.onCenterTap = { [weak self] in self?.onCenterTap() }
            pageCache[index] = controller
            return controller
        }

        /// 伪代码 0x100615640（L83-93）：程序化翻页。
        func navigatePage(direction: ReaderPageTurnDirection) {
            guard let pageVC = currentViewController() else { return }
            let delta = direction == .next ? 1 : -1
            guard let targetIndex = index(of: pageVC).flatMap({ $0 + delta }),
                  pages.indices.contains(targetIndex),
                  let target = pageController(for: targetIndex) else { return }
            guard !transitioning, let controller else { return }
            transitioning = true
            controller.setViewControllers([target], direction: delta > 0 ? .forward : .reverse, animated: true) { [weak self] completed in
                guard let self else { return }
                self.transitioning = false
                if completed { self.startIndex = targetIndex; self.onPageChange(targetIndex) }
                self.applyDeferredIndex()
            }
        }

        private func currentViewController() -> UIViewController? {
            controller?.viewControllers?.first
        }

        func update(pages: [MangaPage], selectedIndex: Int, onCenterTap: @escaping () -> Void,
                    onPageChange: @escaping (Int) -> Void) {
            let changed = self.pages != pages
            if changed {
                self.pages = pages
                pageCache = pageCache.filter { index, controller in
                    pages.indices.contains(index) && controller.page == pages[index]
                }
            }
            self.onCenterTap = onCenterTap
            self.onPageChange = onPageChange
            guard changed || selectedIndex != startIndex || currentViewController() == nil else { return }
            deferredIndex = selectedIndex
            applyDeferredIndex()
        }

        private func applyDeferredIndex() {
            guard !transitioning, let selected = deferredIndex, let controller,
                  let target = pageController(for: selected) else { return }
            deferredIndex = nil
            let direction: UIPageViewController.NavigationDirection = selected >= startIndex ? .forward : .reverse
            startIndex = selected
            controller.setViewControllers([target], direction: direction, animated: false)
        }

        func pageViewController(_ pageViewController: UIPageViewController,
                                willTransitionTo pendingViewControllers: [UIViewController]) {
            transitioning = true
        }

        private func index(of viewController: UIViewController) -> Int? {
            guard let content = viewController as? MangaPageContentViewController,
                  let page = content.page else { return nil }
            return pages.firstIndex(where: { $0.id == page.id })
        }

        // MARK: DataSource / Delegate

        func pageViewController(
            _ pageViewController: UIPageViewController,
            viewControllerBefore viewController: UIViewController
        ) -> UIViewController? {
            // 伪代码 0x10061592c（L97-101）。
            guard let index = index(of: viewController), index > 0 else { return nil }
            return pageController(for: index - 1)
        }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            viewControllerAfter viewController: UIViewController
        ) -> UIViewController? {
            guard let index = index(of: viewController),
                  index + 1 < pages.count else { return nil }
            return pageController(for: index + 1)
        }

        /// 伪代码 0x100615b14（L111-124）：翻页完成 → onPageChange。
        func pageViewController(
            _ pageViewController: UIPageViewController,
            didFinishAnimating finished: Bool,
            previousViewControllers: [UIViewController],
            transitionCompleted completed: Bool
        ) {
            transitioning = false
            guard finished, completed,
                  let current = pageViewController.viewControllers?.first,
                  let index = index(of: current) else { applyDeferredIndex(); return }
            startIndex = index
            onPageChange(index)
            pageCache = pageCache.filter { abs($0.key - index) <= 3 }
            applyDeferredIndex()
        }
    }
}
