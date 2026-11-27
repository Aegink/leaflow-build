// T-1602：使用真实本地书服务和分页器复算阅读进度及跨章提交。
import Foundation
import UIKit

enum LocalReaderSampleSelfTest {
    @MainActor
    static func run(emit: (String, [String], [String]) -> Void) async {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("local-reader-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let input = root.appendingPathComponent("reader.txt")
            let content = (1...3).map { "Chapter \($0)\n" + String(repeating: "固定本地分页正文。\n", count: 100) }.joined(separator: "\n")
            try content.write(to: input, atomically: true, encoding: .utf8)
            let service = LocalBookService(storageDirectory: root.appendingPathComponent("store"))
            guard var book = await service.importBook(from: input) else { throw AppError.emptyContent }
            book.durChapterIndex = 1
            book.durChapterPos = 300
            service.updateBook(book)
            let vm = LocalReaderViewModel(book: book, settings: .load(), localBookService: service)
            vm.updatePaginationBoundsIfNeeded(size: CGSize(width: 320, height: 480))
            await vm.loadBook()
            emit("local_reader_restore_offset", ["1", "true", "false"], [String(vm.currentChapterIndex),
                String(vm.currentPage?.contentRangeInChapter.map { NSLocationInRange(300, $0) } ?? false), String(vm.hasError)])
            guard let target = vm.pages.firstIndex(where: { $0.chapterIndex == 2 }) else { throw AppError.emptyContent }
            let adapter = ReaderViewModel()
            adapter.pageCommitHandler = { [weak vm] in vm?.commitPageTurn($0) }
            adapter.handlePageCommitted(ReaderPageCommit(index: target, pages: vm.pages, isDoublePage: false))
            emit("local_reader_adapter_commit", ["2", String(target)], [String(vm.currentChapterIndex), String(vm.currentPageIndex)])
            await vm.jumpToChapter(1, coordinateReadAloud: false)
            emit("local_reader_jump_global_index", ["1", "0", "true"], [String(vm.currentChapterIndex), String(vm.currentPage?.pageIndex ?? -1),
                String(vm.currentChapterPageRange.start == vm.currentPageIndex && vm.currentChapterPageRange.start > 0)])
            let chapterPages = vm.pages.indices.filter { vm.pages[$0].chapterIndex == 1 }
            guard chapterPages.count > 1 else { throw AppError.emptyContent }
            vm.setCurrentPageIndex(chapterPages[1])
            let offset = vm.currentPage?.contentRangeInChapter?.location ?? -1
            vm.saveProgress()
            let saved = service.books.first!
            emit("local_reader_persist_character_offset", ["1", String(Double(offset)), "true"],
                [String(saved.durChapterIndex), String(saved.durChapterPos), String(offset > 0)])
            vm.updatePaginationBoundsIfNeeded(size: CGSize(width: 280, height: 390))
            await vm.rebuildPages(resyncSpeech: false)
            emit("local_reader_repagination_anchor", ["1", "true"], [String(vm.currentChapterIndex),
                String(vm.currentPage?.contentRangeInChapter.map { NSLocationInRange(offset, $0) } ?? false)])
            let cold = LocalReaderViewModel(book: saved, settings: .load(), localBookService: service)
            cold.updatePaginationBoundsIfNeeded(size: CGSize(width: 280, height: 390))
            await cold.loadBook()
            emit("local_reader_reopen_anchor", ["1", "true"], [String(cold.currentChapterIndex),
                String(cold.currentPage?.contentRangeInChapter.map { NSLocationInRange(offset, $0) } ?? false)])
            let oldIndex = cold.currentPageIndex
            cold.commitPageTurn(ReaderPageCommit(index: -1, pages: cold.pages, isDoublePage: false))
            cold.commitPageTurn(ReaderPageCommit(index: cold.pages.count, pages: cold.pages, isDoublePage: false))
            emit("local_reader_reject_out_of_bounds", [String(oldIndex)], [String(cold.currentPageIndex)])
        } catch { emit("local_reader_restore_offset", ["通过"], [error.localizedDescription]) }
    }
}
