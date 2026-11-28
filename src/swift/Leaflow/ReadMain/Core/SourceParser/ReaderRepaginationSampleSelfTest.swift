// T-1602：真实分页器、任务替换、页号回退及共享章节快照；偏好与文件使用隔离域。
import UIKit

@MainActor
enum ReaderRepaginationSampleSelfTest {
    static func run(emit: (String, [String], [String]) -> Void) async {
        let suite = "T1602.Repagination." + UUID().uuidString
        guard let defaults = UserDefaults(suiteName: suite) else { return }
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = ReadingSettings.load(from: defaults)
        let vm = ReaderViewModel()
        vm.settings = settings
        vm.containerSize = CGSize(width: 240, height: 320)
        vm.chapterContents = [String(repeating: "第一章固定正文用于验证字号变化。", count: 100),
            String(repeating: "第二章固定正文用于验证页号保持。", count: 100)]
        vm.chapters = (0..<2).map { Chapter(name: "样本\($0)", url: "/\($0)", index: $0, isRead: false,
            isPay: false, resourceUrl: nil, isVip: false, isVolume: false, updateTime: nil, wordCount: nil, variable: nil) }
        await vm.paginateContent()
        let smallCount = vm.pages.count
        emit("repaginate_builds_real_pages", ["true", "false", "true"],
            [String(smallCount > 2), String(vm.hasError), String(vm.pages.first?.chapterTitle == "样本0")])
        vm.currentPageIndex = vm.pages.firstIndex { $0.chapterIndex == 1 && $0.pageIndex == 1 } ?? 0
        vm.currentChapterIndex = 1
        settings.fontSize = 29
        vm.requestRebuild(reason: "固定字号变化")
        await vm.paginationRebuildTask?.value
        emit("repaginate_font_changes_page_count", ["true", "1", "1", "false"],
            [String(vm.pages.count > smallCount), String(vm.currentPage?.chapterIndex ?? -1),
             String(vm.currentPage?.pageIndex ?? -1), String(vm.isRebuildPending)])
        emit("repaginate_snapshot_matches_vm", ["true", "true", "1"],
            [String(vm.chapterStateStore.renderSnapshot.pages.count == vm.pages.count),
             String(vm.chapterStateStore.renderSnapshot.currentPageIndex == vm.currentPageIndex),
             String(vm.chapterStateStore.renderSnapshot.currentChapterIndex)])
        settings.fontSize = 12
        vm.requestRebuild(reason: "被替换的请求")
        let stale = vm.paginationRebuildTask
        settings.fontSize = 26
        vm.requestRebuild(reason: "最新请求")
        await vm.paginationRebuildTask?.value
        await stale?.value
        let expected = try? ReaderPaginator.paginate(content: vm.chapterContents[0], chapterIndex: 0,
            chapterTitle: "样本0", settings: settings, pageBounds: vm.containerSize)
        emit("repaginate_latest_request_wins", ["true", "false"],
            [String(vm.pages.filter { $0.chapterIndex == 0 }.map(\.content) == expected?.map(\.content)), String(vm.isRebuildPending)])
        await vm.rebuildPagedModeAtCurrentChapterStart(reason: "回到当前章起点")
        emit("repaginate_explicit_chapter_start", ["1", "0"],
            [String(vm.currentPage?.chapterIndex ?? -1), String(vm.currentPage?.pageIndex ?? -1)])
        let pages = ReaderPageTurnSampleSelfTest.pages()
        emit("repaginate_missing_page_clamped_in_chapter", ["1", "2", "0", "0"],
            [String(ReaderViewModel.preservedPageIndex(in: pages, oldChapterIndex: 0, oldPageInChapter: 99, fallbackIndex: 0)),
             String(ReaderViewModel.preservedPageIndex(in: pages, oldChapterIndex: 9, oldPageInChapter: 0, fallbackIndex: 99)),
             String(ReaderViewModel.preservedPageIndex(in: pages, oldChapterIndex: 0, oldPageInChapter: -1, fallbackIndex: 99)),
             String(ReaderViewModel.preservedPageIndex(in: [], oldChapterIndex: 0, oldPageInChapter: 0, fallbackIndex: 99))])
        let before = vm.pages.map(\.content)
        vm.requestRebuild(reason: "取消请求")
        let cancelled = vm.paginationRebuildTask
        vm.cancelAllTasks()
        await cancelled?.value
        emit("repaginate_cancel_keeps_committed_pages", ["true", "false"],
            [String(vm.pages.map(\.content) == before), String(vm.isRebuildPending)])
        emit("repaginate_invalid_bounds_rejected", ["false", "false", "false"],
            [String(vm.updatePaginationBoundsIfNeeded(size: .zero)),
             String(vm.updatePaginationBoundsIfNeeded(size: CGSize(width: CGFloat.nan, height: 320))),
             String(vm.updatePaginationBoundsIfNeeded(size: vm.containerSize))])
        let store = ChapterStateStore()
        store.setChapterPages(1, pages: pages.filter { $0.chapterIndex == 1 })
        store.setChapterPages(0, pages: pages.filter { $0.chapterIndex == 0 })
        emit("chapter_store_keeps_other_chapters", ["0,0,1"], [store.pages.map { String($0.chapterIndex) }.joined(separator: ",")])
        _ = store.commitPages(newPages: pages, targetIndex: 999,
            newMeta: ReaderPaginator.buildChapterPageMeta(from: pages), oldMeta: [:], reason: "固定范围")
        emit("chapter_snapshot_target_clamps", ["2", "1"],
            [String(store.renderSnapshot.currentPageIndex), String(store.renderSnapshot.currentChapterIndex)])
        var localMenu = false
        vm.menuToggleHandler = { localMenu.toggle() }
        vm.handleTap()
        let opened = localMenu
        vm.handleTap()
        emit("reader_local_menu_callback", ["true", "false", "false"],
            [String(opened), String(localMenu), String(vm.menuVisible)])
    }
}
