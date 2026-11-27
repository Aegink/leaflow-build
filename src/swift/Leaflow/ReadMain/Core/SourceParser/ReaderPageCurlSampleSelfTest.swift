// T-1602：跨章卷页、连续目标携带、取消/换向与数组快照更新固定样本。
import UIKit

enum ReaderPageCurlSampleSelfTest {
    @MainActor
    static func run(emit: (String, [String], [String]) -> Void) async {
        let pages = (0..<5).map {
            ReadAloudSampleSelfTest.page(chapter: $0 < 2 ? 7 : 8,
                index: $0 < 2 ? $0 : $0 - 2, text: "卷页固定正文\($0)")
        }
        let keys = pages.map(PageCurlPageKey.init)
        let resolver = PageCurlPageResolver(pages: pages, isDoublePage: false)
        let double = PageCurlPageResolver(pages: pages, isDoublePage: true)
        emit("curl_key_cross_chapter", ["ch7p1", "2", "true", "true", "true"],
            [keys[1].description, String(resolver.index(for: keys[2]) ?? -1),
             String(resolver.adjacentKey(from: keys[1], direction: .next) == keys[2]),
             String(resolver.direction(from: keys[1], to: keys[2]) == .next),
             String(resolver.direction(from: keys[2], to: keys[1]) == .previous)])
        emit("curl_key_missing_bounds", Array(repeating: "true", count: 5),
            [String(resolver.index(for: .init(chapterIndex: 99, pageIndex: 0)) == nil),
             String(resolver.index(for: nil) == nil), String(resolver.key(for: nil) == nil),
             String(resolver.key(at: Int.max) == keys[4]),
             String(PageCurlPageResolver(pages: [], isDoublePage: true).key(at: 0) == nil)])
        emit("curl_key_double_stride", Array(repeating: "true", count: 5),
            [String(double.key(at: 3) == keys[2]), String(double.key(for: pages[1]) == keys[0]),
             String(double.index(for: keys[3]) == 2),
             String(double.adjacentKey(from: keys[1], direction: .next) == keys[2]),
             String(double.direction(from: keys[0], to: keys[4]) == nil)])
        var loadingPages = pages
        loadingPages[2].isLoadingPlaceholder = true
        let loading = PageCurlPageResolver(pages: loadingPages, isDoublePage: false)
        emit("curl_loading_boundary", Array(repeating: "true", count: 4),
            [String(loading.adjacentKey(from: keys[2], direction: .next) == nil),
             String(loading.adjacentKey(from: keys[2], direction: .previous) == keys[1]),
             String(loading.adjacentKey(from: keys[0], direction: .previous) == nil),
             String(loading.adjacentKey(from: keys[4], direction: .next) == nil)])

        var state = PageCurlTurnState()
        state.begin(start: keys[0])
        state.begin(start: keys[4])
        let first = state.accept(target: keys[1], start: keys[0], directionFrom: resolver.direction)
        let duplicate = state.accept(target: keys[1], start: keys[4], directionFrom: resolver.direction)
        let origin = state.accept(target: keys[0], start: keys[4], directionFrom: resolver.direction)
        let skipped = state.accept(target: keys[4], start: keys[0], directionFrom: resolver.direction)
        emit("curl_accept_idempotence", Array(repeating: "true", count: 7),
            [String(first), String(duplicate), String(origin), String(!skipped),
             String(state.startKey == keys[0]), String(state.acceptedTargets == [keys[1]]),
             String(state.isActive && !state.hasCarriedTargets)])
        _ = state.accept(target: keys[2], start: keys[0], directionFrom: resolver.direction)
        _ = state.accept(target: keys[3], start: keys[0], directionFrom: resolver.direction)
        state.notePagesChanged()
        let completion = state.complete(displayed: keys[1], completed: true)
        emit("curl_complete_carries_targets", Array(repeating: "true", count: 6),
            [String(completion == .committed(displayed: keys[1],
                carriedTargets: [keys[2], keys[3]], pagesChanged: true)),
             String(state.phase == .carrying), String(state.startKey == keys[1]),
             String(state.latestAcceptedTarget == keys[3]),
             String(!state.pagesChangedDuringTurn), String(state.hasCarriedTargets)])
        state.begin(start: keys[1])
        let retained = state.acceptedTargets == [keys[2], keys[3]]
        state.begin(start: keys[2])
        let consumed = state.acceptedTargets == [keys[3]] && state.phase == .carrying
        state.begin(start: keys[3])
        emit("curl_begin_consumes_carry", Array(repeating: "true", count: 4),
            [String(retained), String(consumed),
             String(state.phase == .tracking && state.acceptedTargets.isEmpty),
             String(state.direction == nil && state.startKey == keys[3])])
        _ = state.accept(target: keys[4], start: keys[3], directionFrom: resolver.direction)
        let unchanged = state.complete(displayed: keys[3], completed: true)
        state.begin(start: keys[0])
        emit("curl_carry_external_jump", Array(repeating: "true", count: 4),
            [String(unchanged == .unchanged(displayed: keys[3], carriedTargets: [keys[4]])),
             String(state.startKey == keys[0]), String(state.direction == nil),
             String(state.acceptedTargets.isEmpty && state.phase == .tracking)])

        state.reset()
        _ = state.accept(target: keys[3], start: keys[2], directionFrom: resolver.direction)
        let rejected = !state.accept(target: keys[1], start: keys[2], directionFrom: resolver.direction)
        _ = state.complete(displayed: keys[2], completed: true)
        let redirected = state.accept(target: keys[1], start: keys[2], directionFrom: resolver.direction)
        emit("curl_carry_direction_change", Array(repeating: "true", count: 4),
            [String(rejected), String(redirected), String(state.direction == .previous),
             String(state.acceptedTargets == [keys[1]] && state.phase == .tracking)])
        state.notePagesChanged()
        let cancelled = state.complete(displayed: keys[1], completed: false)
        let reset = state.phase == .idle && state.startKey == nil && state.direction == nil
            && state.acceptedTargets.isEmpty && !state.pagesChangedDuringTurn
        state.begin(start: keys[0])
        let missing = state.complete(displayed: nil, completed: true)
        emit("curl_cancel_unresolved_reset", ["true", "true", "true", "true"],
            [String(cancelled == .cancelled), String(reset), String(missing == .unresolved),
             String(state.phase == .idle)])
        state.begin(start: keys[0])
        let noMovement = state.complete(displayed: keys[0], completed: true)
        state.begin(start: keys[0])
        state.notePagesChanged()
        let external = state.complete(displayed: keys[4], completed: true)
        emit("curl_complete_no_pending", Array(repeating: "true", count: 3),
            [String(noMovement == .unchanged(displayed: keys[0], carriedTargets: [])),
             String(external == .committed(displayed: keys[4], carriedTargets: [], pagesChanged: true)),
             String(state.phase == .idle)])
        checkCache(pages: pages, emit: emit)
        await checkController(emit: emit)
    }

    private static func checkCache(pages: [PageData], emit: (String, [String], [String]) -> Void) {
        let cache = PageIndexCache()
        let first = cache.update(with: pages)
        let repeated = cache.update(with: pages)
        var replacement = pages
        replacement[0].content = "等长缓存更新"
        let contentChanged = cache.update(with: replacement)
        let refreshed = cache.pages[0].content == "等长缓存更新"
        replacement[0].chapterIndex = 20
        let structureChanged = cache.update(with: replacement)
        emit("curl_index_cache_equal_count", Array(repeating: "true", count: 7),
            [String(first), String(!repeated), String(contentChanged), String(refreshed),
             String(structureChanged), String(cache.index(for: "7-0") == nil),
             String(cache.index(forLayoutId: replacement[0].layoutId) == 0)])
        let empty = cache.update(with: [])
        let emptyAgain = cache.update(with: [])
        emit("curl_index_cache_clear", Array(repeating: "true", count: 4),
            [String(empty), String(!emptyAgain),
             String(cache.pages.isEmpty), String(cache.index(for: "20-0") == nil)])
    }

    @MainActor
    private static func checkController(emit: (String, [String], [String]) -> Void) async {
        let pages = ReaderPageTurnSampleSelfTest.pages()
        var commits: [Int] = []
        let parent = PageViewController(pages: pages, currentPageIndex: 1,
            settings: ReadingSettings.load(), bookName: "卷页样本", totalChapters: 2,
            speechHighlight: .none, colorVersion: 0, isRebuildPending: false,
            pageMode: .curl, isDoublePageActive: false, menuVisible: false,
            pageTurnCommand: nil, onTap: {}, onPageCommitted: { commits.append($0.index) })
        let coordinator = parent.makeCoordinator()
        let controller = parent.makeUIPageViewController(coordinator: coordinator)
        let driver = coordinator.pageCurlDriver
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 600))
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true; window.rootViewController = nil }
        controller.view.layoutIfNeeded()
        let initial = controller.viewControllers?.first as? PageContentViewController
        emit("curl_controller_initial_page", ["固定翻页正文乙", "true", "true"],
            [initial?.contentTextView.text ?? "",
             String(initial.flatMap { coordinator.primaryIndex(for: $0) } == 1),
             String(controller.dataSource === driver && controller.delegate === driver)])
        if let initial {
            let back = driver.pageViewController(controller, viewControllerBefore: initial)
            let previous = back.flatMap { driver.pageViewController(controller, viewControllerBefore: $0) }
            let current = back.flatMap { driver.pageViewController(controller, viewControllerAfter: $0) }
            emit("curl_controller_back_sequence", Array(repeating: "true", count: 4),
                [String(back is PageBackViewController),
                 String((back as? PageBackViewController)?.embeddedContentViewController != nil),
                 String(driver.displayKey(for: previous) == PageCurlPageKey(pages[0])),
                 String(driver.displayKey(for: current) == PageCurlPageKey(pages[1]))])
        } else {
            emit("curl_controller_back_sequence", ["成功"], ["初始页面缺失"])
        }
        coordinator.parent.menuVisible = true
        driver.applyPendingTurnCommand(.init(id: 1, direction: .next))
        let deferred = commits.isEmpty
        coordinator.parent.menuVisible = false
        driver.applyPendingTurnCommand(nil)
        for _ in 0..<50 {
            if commits.count == 1 { break }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        driver.applyPendingTurnCommand(.init(id: 1, direction: .next))
        emit("curl_controller_command_commit", ["true", "[2]", "固定翻页正文丙", "true"],
            [String(deferred), String(describing: commits),
             (controller.viewControllers?.first as? PageContentViewController)?.contentTextView.text ?? "",
             String(coordinator.parent.currentPageIndex == 2)])
        let boundary = driver.goToPage(direction: .next)
        let previous = driver.goToPage(direction: .previous)
        for _ in 0..<50 {
            if commits.count == 2 { break }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        emit("curl_controller_reverse_boundary", ["false", "true", "[2, 1]", "固定翻页正文乙"],
            [String(boundary), String(previous), String(describing: commits),
             (controller.viewControllers?.first as? PageContentViewController)?.contentTextView.text ?? ""])
        let pending = coordinator.createPageVC(for: 2, speechHighlight: .none)
        driver.pageViewController(controller, willTransitionTo: [pending])
        driver.pageViewController(controller, didFinishAnimating: true,
            previousViewControllers: [], transitionCompleted: false)
        emit("curl_controller_cancel_no_commit", ["[2, 1]", "true"],
            [String(describing: commits), String(driver.turnState.phase == .idle)])
        var replacement = pages
        replacement[1].content = "固定翻页正文新"
        coordinator.parent.pages = replacement
        let changed = coordinator.syncPageStructureSignature(pages: replacement, currentPageIndex: 1)
        driver.update(pageViewController: controller, pagesChanged: changed, pageStructureChanged: changed)
        emit("curl_controller_same_count_refresh", ["true", "固定翻页正文新"],
            [String(changed),
             (controller.viewControllers?.first as? PageContentViewController)?.contentTextView.text ?? ""])
    }
}
