// T-1602：固定三章样本，验证生产加载/分页链，不访问网络。
// 对照 ReaderViewModel+Loading 0x100875d24 L57-225、+Pagination 0x10088d370 L326-415。
import Foundation
import UIKit

enum ReaderSampleSelfTest {
    @MainActor
    static func run(emit: (String, [String], [String]) -> Void) async {
        do {
            let book = try JSONDecoder().decode(Book.self, from: Data("""
                {"name":"固定三章","bookUrl":"https://sample.invalid/book",
                 "bookSourceUrl":"https://sample.invalid","durChapterIndex":1,"durChapterPos":300}
                """.utf8))
            let chapters = try JSONDecoder().decode([Chapter].self, from: Data("""
                [{"name":"第一章","url":"/1","index":0},
                 {"name":"第二章","url":"/2","index":1},
                 {"name":"第三章","url":"/3","index":2}]
                """.utf8))
            let settings = ReadingSettings.load()
            let vm = ReaderViewModel()
            vm.configure(book: book, settings: settings)
            vm.containerSize = CGSize(width: 320, height: 480)
            vm.chapterListProvider = { _, _ in chapters }
            vm.chapterContentProvider = { _, index, _ in
                ChapterContent(content: String(repeating: "固定正文，第\(index + 1)章。\n", count: 100),
                    nextUrl: nil, isPay: false, comments: [],
                    readerAccessURL: nil, chapterTitle: chapters[index].name)
            }
            await vm.loadBookWithProgress(nil, needRefresh: false,
                targetChapterIndex: nil, targetPageOffset: nil)
            let restoredPosition = vm.currentPage?.contentRangeInChapter.map {
                NSLocationInRange(300, $0)
            } ?? false
            emit("reader_progress_restore", ["1", "false", "true", "true"],
                [String(vm.currentChapterIndex), String(vm.hasError),
                 String(!vm.pages.isEmpty), String(restoredPosition)])
            // 乱序完成：3 → 1，不得让 Task 完成顺序污染页面顺序。
            await vm.loadChapterContent(2, forceRefresh: false)
            await vm.loadChapterContent(0, forceRefresh: false)
            emit("reader_three_chapters", ["0", "1", "2"],
                Array(Set(vm.pages.map(\.chapterIndex))).sorted().map(String.init))
            let ordered = vm.pages.map { $0.chapterIndex * 10_000 + $0.pageIndex }
            let realContent = (0..<3).allSatisfy { chapter in
                vm.pages.filter { $0.chapterIndex == chapter }
                    .map(\.content).joined().contains("固定正文，第\(chapter + 1)章")
            }
            emit("reader_page_order", ["true", "false", "true"],
                [String(ordered == ordered.sorted()),
                 String(vm.pages.contains { $0.isLoadingPlaceholder }), String(realContent)])
        } catch {
            emit("reader_progress_restore", ["通过"], [error.localizedDescription])
            emit("reader_three_chapters", ["通过"], [])
            emit("reader_page_order", ["通过"], [])
        }
    }
}
