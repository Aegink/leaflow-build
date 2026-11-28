// T-1602：固定序列检验跨章、双页、占位、重定位、取消及真实控制器提交。
import UIKit

enum ReaderPageTurnSampleSelfTest {
    static func sequence(_ ids: [Int], double: Bool = false, loading: Set<Int> = [],
                         error: Set<Int> = []) -> PageTurnSequence {
        PageTurnSequence(pages: ids.map {
            .init(id: PageTurnPageID(chapterIndex: $0 / 2, pageIndex: $0 % 2),
                isLoadingPlaceholder: loading.contains($0), isErrorPlaceholder: error.contains($0))
        }, isDoublePage: double)
    }

    @MainActor
    static func run(emit: (String, [String], [String]) -> Void) async {
        let single = PageTurnResolver(sequence: sequence([0, 1, 2, 3, 4]))
        let double = PageTurnResolver(sequence: sequence([0, 1, 2, 3, 4], double: true))
        emit("turn_canonical_bounds", ["0", "0", "4", "2", "4", "0"],
            [String(single.canonicalIndex(Int.min)), String(single.canonicalIndex(-2)),
             String(single.canonicalIndex(Int.max)), String(double.canonicalIndex(3)),
             String(double.canonicalIndex(Int.max)),
             String(PageTurnResolver(sequence: sequence([])).canonicalIndex(3))])
        emit("turn_direction_values", ["0", "1", "true", "true"],
            [String(ReaderPageTurnDirection.previous.rawValue), String(ReaderPageTurnDirection.next.rawValue),
             String(single.targetIndex(from: 0, direction: .previous) == nil),
             String(single.targetIndex(from: 4, direction: .next) == nil)])
        emit("turn_double_stride", ["2", "0", "4", "true", "[4]"],
            [String(double.targetIndex(from: 1, direction: .next) ?? -1),
             String(double.targetIndex(from: 3, direction: .previous) ?? -1),
             String(double.targetIndex(from: 3, direction: .next) ?? -1),
             String(double.targetIndex(from: 4, direction: .next) == nil),
             String(describing: double.displayedIndices(at: 4))])
        let loading = PageTurnResolver(sequence: sequence([0, 1, 2, 3], loading: [2]))
        let blocked = PageTurnResolver(sequence: sequence([0, 1, 2, 3], loading: [2], error: [1]))
        let loadingPair = PageTurnResolver(sequence: sequence([0, 1, 2, 3, 4], double: true, loading: [3]))
        emit("turn_loading_policy", Array(repeating: "true", count: 5),
            [String(loading.targetIndex(from: 2, direction: .next) == nil),
             String(loading.targetIndex(from: 2, direction: .previous) == 1),
             String(blocked.targetIndex(from: 2, direction: .previous) == nil),
             String(loading.targetIndex(from: 1, direction: .next) == 2),
             String(loadingPair.targetIndex(from: 2, direction: .next) == nil)])
        var state = PageTurnState(sequence: sequence([0, 1, 2, 3]), committedIndex: 1)
        let transition = state.beginTurn(.next)
        emit("turn_cross_chapter_begin", ["1", "2", "1", "0", "true"],
            [String(transition?.sourceIndex ?? -1), String(transition?.targetIndex ?? -1),
             String(transition?.targetID.chapterIndex ?? -1), String(transition?.targetID.pageIndex ?? -1),
             String(state.beginTurn(.next) == nil)])
        emit("turn_commit_cancel", ["true", "true", "true", "2"],
            [String(state.finishTurn(committed: true) == .committed(index: 2)),
             String(state.beginTurn(.previous) != nil),
             String(state.finishTurn(committed: false) == .cancelled(index: 2)), String(state.currentIndex)])
        emit("turn_finish_idle", ["true"], [String(state.finishTurn(committed: true) == nil)])
        _ = state.beginTurn(.next)
        let rebased = state.replaceSequence(sequence([8, 9, 0, 1, 2, 3]), committedIndex: 4)
        var kept = false
        if case .preserved(let turn) = rebased { kept = turn.sourceIndex == 4 && turn.targetIndex == 5 }
        emit("turn_rebase_preserves_ids", ["true", "true", "5"],
            [String(kept), String(state.finishTurn(committed: true) == .committed(index: 5)), String(state.currentIndex)])
        state = PageTurnState(sequence: sequence([0, 1, 2, 3]), committedIndex: 1)
        _ = state.beginTurn(.next)
        let removed = state.replaceSequence(sequence([0, 1, 3]), committedIndex: 1)
        emit("turn_rebase_missing_target", ["true", "true", "true"],
            [String(removed == .cancelled(index: 1)), String(state.transition == nil),
             String(state.finishTurn(committed: true) == nil)])
        _ = state.beginTurn(.next)
        let moved = state.replaceSequence(sequence([0, 1, 3]), committedIndex: 0)
        emit("turn_rebase_external_jump", ["true", "0"],
            [String(moved == .cancelled(index: 0)), String(state.currentIndex)])
        state = PageTurnState(sequence: sequence([0, 1, 2, 3]), committedIndex: 1)
        _ = state.beginTurn(.next)
        emit("turn_rebase_nonadjacent", ["true"],
            [String(state.replaceSequence(sequence([0, 1, 8, 2, 3]), committedIndex: 1) == .cancelled(index: 1))])
        var immediate = ImmediatePageTurnGestureDriver()
        immediate.begin()
        let left = immediate.end(translation: -30, velocity: 0, width: 400)
        immediate.begin()
        let right = immediate.end(translation: 30, velocity: 0, width: 400)
        immediate.begin()
        let flick = immediate.end(translation: -9, velocity: 501, width: 400)
        immediate.begin(); immediate.cancel()
        emit("turn_immediate_direction_cancel", Array(repeating: "true", count: 4),
            [String(left == .next), String(right == .previous), String(flick == .previous),
             String(immediate.end(translation: -200, velocity: -800, width: 400) == nil)])
        var slide = SlidePageTurnGestureDriver()
        slide.begin()
        let small = slide.update(translation: -23, width: 400)
        let begin = slide.update(translation: -24, width: 400)
        let reverse = slide.update(translation: 30, width: 400)
        let cancel = slide.end(translation: 30, velocity: 0, width: 400)
        emit("turn_slide_reverse_cancel", Array(repeating: "true", count: 4),
            [String(small == .none), String(begin == .begin(.next, progress: 0.06)),
             String(reverse == .progress(.next, progress: 0)), String(cancel == .cancel(.next))])
        slide.begin(); _ = slide.update(translation: -24, width: 400)
        let threshold = slide.end(translation: -120, velocity: 0, width: 400)
        slide.begin(); _ = slide.update(translation: -24, width: 400)
        let complete = slide.end(translation: -121, velocity: 0, width: 400)
        slide.begin(); _ = slide.update(translation: 24, width: 400)
        let abort = slide.cancel()
        emit("turn_slide_threshold", Array(repeating: "true", count: 3),
            [String(threshold == .cancel(.next)), String(complete == .commit(.next)), String(abort == .cancel(.previous))])
        var buffer = ReaderPageTurnCommandBuffer()
        buffer.submit(.init(id: 2, direction: .next))
        buffer.submit(.init(id: 1, direction: .previous)); buffer.submit(nil)
        let command = buffer.take()
        buffer.submit(.init(id: 2, direction: .previous))
        buffer.submit(.init(id: 0, direction: .next))
        emit("turn_command_dedup", ["2", "true", "true", "2"],
            [String(command?.id ?? -1), String(command?.direction == .next),
             String(buffer.take() == nil), String(buffer.lastConsumedCommandID)])
        var issuer = ReaderPageTurnCommandIssuer()
        let edge = issuer.command(direction: .previous, currentIndex: 0, pageCount: 3)
        let first = issuer.command(direction: .next, currentIndex: 0, pageCount: 3)
        let second = issuer.command(direction: .previous, currentIndex: 1, pageCount: 3)
        emit("turn_command_sequence", ["true", "1", "2"],
            [String(edge == nil), String(first?.id ?? -1), String(second?.id ?? -1)])
        checkVisuals(emit: emit)
        await checkController(emit: emit)
    }

    @MainActor
    static func pages() -> [PageData] {
        ["固定翻页正文甲", "固定翻页正文乙", "固定翻页正文丙"].enumerated().map {
            ReadAloudSampleSelfTest.page(chapter: $0.offset == 2 ? 1 : 0,
                index: $0.offset == 2 ? 0 : $0.offset, text: $0.element)
        }
    }

    @MainActor
    private static func checkVisuals(emit: (String, [String], [String]) -> Void) {
        let slide = PageTransitionStyle.slide
        let immediate = PageTransitionStyle.none
        emit("turn_visual_style_values", ["0", "1", "2", "2", "true", "false", "true"],
            [String(slide.layerOrder(for: .next).rawValue), String(slide.layerOrder(for: .previous).rawValue),
             String(immediate.layerOrder(for: .next).rawValue), String(immediate.layerOrder(for: .previous).rawValue),
             String(slide.usesTransparentPageBackground), String(immediate.usesTransparentPageBackground),
             String(immediate.visualState(direction: .next, progress: 0.5) == .identity)])
        emit("turn_visual_progress_edges", Array(repeating: "true", count: 4),
            [String(slide.visualState(direction: .next, progress: -1) == slide.visualState(direction: .next, progress: 0)),
             String(slide.visualState(direction: .previous, progress: 2) == slide.visualState(direction: .previous, progress: 1)),
             String(slide.visualState(direction: .next, progress: .nan) == slide.visualState(direction: .next, progress: 0)),
             String(slide.visualState(direction: .next, progress: .infinity) == slide.visualState(direction: .next, progress: 1))])
        let host = UIViewController()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 600))
        window.layer.cornerRadius = 24
        window.rootViewController = host
        window.isHidden = false
        defer { window.isHidden = true; window.rootViewController = nil }
        host.view.frame = window.bounds
        let renderer = ReaderTwoPageRenderer()
        renderer.install(in: host)
        let current = UIViewController()
        let incoming = UIViewController()
        renderer.setCurrentViewController(current)
        let next = PageTurnTransition(sourceID: .init(chapterIndex: 0, pageIndex: 0),
            targetID: .init(chapterIndex: 0, pageIndex: 1), direction: .next, sourceIndex: 0, targetIndex: 1)
        renderer.prepare(transition: next, incoming: incoming)
        renderer.render(progress: 0.5)
        let forward: [CGFloat] = [current.view.superview?.transform.tx ?? 999, incoming.view.superview?.transform.tx ?? 999,
            host.view.subviews.dropLast().last?.alpha ?? 999, current.view.superview?.layer.cornerRadius ?? 999]
        _ = renderer.finishSettlement(committed: false)
        let previous = PageTurnTransition(sourceID: next.targetID, targetID: next.sourceID,
            direction: .previous, sourceIndex: 1, targetIndex: 0)
        renderer.prepare(transition: previous, incoming: incoming)
        renderer.render(progress: 0.5)
        let reverse: [CGFloat] = [current.view.superview?.transform.tx ?? 999, incoming.view.superview?.transform.tx ?? 999,
            host.view.subviews.dropLast().last?.alpha ?? 999, incoming.view.superview?.layer.cornerRadius ?? 999]
        emit("turn_renderer_visual_fields", ["-200.00", "-30.00", "0.15", "24.00", "30.00", "-200.00", "0.15", "24.00"],
            (forward + reverse).map { String(format: "%.2f", Double($0)) })
        _ = renderer.finishSettlement(committed: true)
        let durations = [
            ReaderTwoPageRenderer.settlementDuration(progress: 0.5, completes: true, direction: .next, velocity: -4000, width: 400),
            ReaderTwoPageRenderer.settlementDuration(progress: 0.5, completes: true, direction: .next, velocity: 4000, width: 400),
            ReaderTwoPageRenderer.settlementDuration(progress: 0.5, completes: false, direction: .previous, velocity: -4000, width: 400),
            ReaderTwoPageRenderer.settlementDuration(progress: 0.5, completes: false, direction: .previous, velocity: 4000, width: 400)]
        emit("turn_animation_signed_velocity", ["0.05", "0.14", "0.05", "0.14"],
            durations.map { String(format: "%.2f", $0) })
    }

    @MainActor
    private static func checkController(emit: (String, [String], [String]) -> Void) async {
        let pages = pages()
        let settings = ReadingSettings.load()
        let controller = HorizontalPagingViewController()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 600))
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true; window.rootViewController = nil }
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(x: 0, y: 0, width: 400, height: 600)
        controller.additionalSafeAreaInsets = UIEdgeInsets(top: 100, left: 0, bottom: 20, right: 0)
        var actualSize: CGSize = .zero
        var actualInsets: UIEdgeInsets = .zero
        controller.onPaginationMetrics = { actualSize = $0; actualInsets = $1 }
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        await ReadAloudSampleSelfTest.settle()
        emit("turn_layout_reports_actual_safe_area", ["true", "true"],
            [String(actualSize == controller.view.bounds.size), String(actualInsets.top >= 100 && actualInsets.bottom >= 20)])
        controller.transitionStyle = .none
        var synchronousMainUpdate = false
        performReaderUIUpdate { synchronousMainUpdate = Thread.isMainThread }
        emit("turn_ui_main_update_synchronous", ["true"], [String(synchronousMainUpdate)])
        let deliveredOnMain: Bool = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                performReaderUIUpdate {
                    controller.apply(pages: pages, committedIndex: 1, settings: settings, bookName: "后台更新样本",
                        totalChapters: 2, speechHighlight: .none, isDoublePageActive: false)
                    continuation.resume(returning: Thread.isMainThread)
                }
            }
        }
        emit("turn_ui_background_update_reaches_main", ["true", "1", "固定翻页正文乙"],
            [String(deliveredOnMain), String(controller.currentIndex),
             (controller.children.first as? PageContentViewController)?.contentTextView.text ?? ""])
        controller.apply(pages: pages, committedIndex: 1, settings: settings, bookName: "翻页样本",
            totalChapters: 2, speechHighlight: .none, isDoublePageActive: false)
        var commits: [ReaderPageCommit] = []
        controller.onPageCommitted = { commits.append($0) }
        let next = controller.requestTurn(.next)
        let child = controller.children.first as? PageContentViewController
        emit("turn_controller_cross_chapter", ["true", "2", "固定翻页正文丙", "2"],
            [String(next), String(controller.currentIndex), child?.contentTextView.text ?? "",
             String(commits.last?.index ?? -1)])
        controller.view.layoutIfNeeded()
        child?.view.layoutIfNeeded()
        emit("reader_body_safe_area", ["true"],
            [String((child?.contentTextView.frame.minY ?? 0) >= 100)])
        let edge = controller.requestTurn(.next)
        controller.menuVisible = true
        let menu = controller.requestTurn(.previous)
        controller.menuVisible = false
        controller.handleHorizontalPan(state: .began, translation: 0, velocity: 0, width: 400)
        controller.handleHorizontalPan(state: .cancelled, translation: 200, velocity: 1000, width: 400)
        emit("turn_controller_cancel_boundary", ["false", "false", "2", "1"],
            [String(edge), String(menu), String(controller.currentIndex), String(commits.count)])
        controller.transitionStyle = .slide
        controller.handleHorizontalPan(state: .began, translation: 0, velocity: 0, width: 400)
        controller.handleHorizontalPan(state: .changed, translation: 100, velocity: 0, width: 400)
        controller.handleHorizontalPan(state: .cancelled, translation: 100, velocity: 0, width: 400)
        try? await Task.sleep(nanoseconds: 400_000_000)
        emit("turn_controller_slide_cancel", ["2", "false", "1"],
            [String(controller.currentIndex), String(controller.isTransitioning), String(commits.count)])
        let commit = ReaderPageCommit(index: 1, pages: pages, isDoublePage: true)
        emit("turn_commit_spread_count", [String(pages[0].charCount + pages[1].charCount), "true", "false"],
            [String(commit.characterCount), String(commit.shouldApply(currentIndex: 0, pageCount: 3)),
             String(commit.shouldApply(currentIndex: 0, pageCount: 1))])
        let vm = ReaderViewModel()
        vm.pages = pages
        vm.currentPageIndex = 1
        vm.handlePageCommitted(ReaderPageCommit(index: 2, pages: pages, isDoublePage: false))
        emit("turn_viewmodel_global_commit", ["2", "1"], [String(vm.currentPageIndex), String(vm.currentChapterIndex)])
        controller.apply(pages: [], committedIndex: 0, settings: settings, bookName: "翻页样本",
            totalChapters: 2, speechHighlight: .none, isDoublePageActive: false)
        controller.transitionStyle = .none
        controller.submitPageTurnCommand(.init(id: 1, direction: .next))
        controller.applyPendingPageTurnCommandIfPossible()
        controller.apply(pages: pages, committedIndex: 0, settings: settings, bookName: "翻页样本",
            totalChapters: 2, speechHighlight: .none, isDoublePageActive: false)
        controller.applyPendingPageTurnCommandIfPossible()
        emit("turn_command_waits_for_pages", ["1", "2"],
            [String(controller.currentIndex), String(commits.count)])
        controller.menuVisible = true
        controller.submitPageTurnCommand(.init(id: 2, direction: .next))
        controller.applyPendingPageTurnCommandIfPossible()
        let heldIndex = controller.currentIndex
        controller.menuVisible = false
        controller.applyPendingPageTurnCommandIfPossible()
        controller.submitPageTurnCommand(.init(id: 2, direction: .next))
        controller.applyPendingPageTurnCommandIfPossible()
        emit("turn_command_menu_deferred_once", ["1", "2", "3"],
            [String(heldIndex), String(controller.currentIndex), String(commits.count)])
    }
}
