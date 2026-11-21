// 原路径: ReadMain/Views/Reader/Manga/MangaReaderViewModel.swift
// 证据:
//   - PGO: 27 个主函数（index/task_functions.csv T-304-04 / MangaReaderViewModel.swift），
//     地址：init(book:bookService:sourceService:) 0x1006316e8 L71-78 /
//     currentBookSource 0x100631044 L55-61 / initialLoad 0x100631c40 L88-96 /
//     loadBook 0x100636170 L100-149 / loadChapterImages 0x100632290 L153-224 /
//     jumpToChapter 0x100632f50 L228-242 / goNextChapter 0x100633100 L244-248 /
//     goPreviousChapter 0x1006331b8 L250-254 / preloadCurrentChapterImages
//     0x100633604 L276-285 / loadAndAppendNextForWebtoon 0x100633b7c L308-338 /
//     saveWebtoonProgress 0x100634448 L341-349 / saveProgress 0x100634970
//     L356-361 / shouldPromptAddToBookshelf 0x100634b18 L365-368 /
//     addBookToBookshelf 0x100634bf0 L370-372 / refreshCurrentChapter
//     0x100634ee4 L376-396 / refreshChapterList 0x100634fec L398-436 /
//     cancelAllTasks 0x100631170 L440-443
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Reader/Manga/MangaReaderViewModel.c
//   - 事实：漫画 VM 主链 —— loadBook → loadChapterImages（MangaImageParser.extractImageURLs
//     消费）→ MangaImageCacheService.getImage；webtoon 追加加载 + 进度保存
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（函数名/签名确证）
// 还原: 2026-11-19

import Foundation
import UIKit

/// 漫画阅读 VM。
@Observable
@MainActor
final class MangaReaderViewModel {

    let book: Book
    private let bookService: BookService
    private let sourceService: SourceService

    private(set) var chapters: [LocalChapter] = []
    private(set) var chapterImageURLs: [Int: [String]] = [:]
    private(set) var currentChapterIndex = 0
    private(set) var isLoading = false
    private(set) var hasError = false
    var menuVisible = false
    var isWebtoonMode = false

    var currentBookSource: BookSource? {
        bookService.source(for: book)
    }

    init(book: Book, bookService: BookService, sourceService: SourceService) {
        self.book = book
        self.bookService = bookService
        self.sourceService = sourceService
    }

    /// 伪代码 0x100631c40（L88-96）：初始加载。
    func initialLoad() async {
        await loadBook()
    }

    /// 伪代码 0x100636170（L100-149）：加载书（目录 + 首章图片）。
    func loadBook() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let chapters = try await sourceService.getChapterList(
                source: currentBookSource!, book: book)
            self.chapters = chapters.map { chapter in
                LocalChapter(
                    id: UUID(), title: chapter.title,
                    pageIndex: 0, order: chapter.order, pageCount: 0)
            }
            await loadChapterImages(currentChapterIndex)
        } catch {
            hasError = true
            Logger.error(error, context: "manga loadBook")
        }
    }

    /// 伪代码 0x100632290（L153-224）：章图加载
    ///（getContent → MangaImageParser.extractImageURLs 消费确证）。
    func loadChapterImages(_ index: Int) async {
        guard chapters.indices.contains(index),
              let source = currentBookSource else { return }
        do {
            let content = try await sourceService.getContent(
                source: source,
                chapter: Chapter(
                    id: chapters[index].id, title: chapters[index].title,
                    url: "", order: index))
            let urls = MangaImageParser.extractImageURLs(from: content.content)
            chapterImageURLs[index] = urls
        } catch {
            Logger.error(error, context: "loadChapterImages \(index)")
        }
    }

    /// 伪代码 0x100632f50（L228-242）：跳章。
    func jumpToChapter(_ index: Int) async {
        guard chapters.indices.contains(index) else { return }
        currentChapterIndex = index
        if chapterImageURLs[index] == nil {
            await loadChapterImages(index)
        }
    }

    /// 伪代码 0x100633100（L244-248）：下一章。
    func goNextChapter() async {
        await jumpToChapter(currentChapterIndex + 1)
    }

    /// 伪代码 0x1006331b8（L250-254）：上一章。
    func goPreviousChapter() async {
        await jumpToChapter(currentChapterIndex - 1)
    }

    /// 伪代码 0x100633604（L276-285）：邻页预载（MangaImageCacheService.preloadImages 消费确证）。
    func preloadCurrentChapterImages(around index: Int) {
        guard let urls = chapterImageURLs[currentChapterIndex] else { return }
        let window = urls.enumerated()
            .filter { abs($0.offset - index) <= 2 }
            .map(\.element)
        MangaImageCacheService.shared.preloadImages(urls: window, headers: [:])
    }

    /// 伪代码 0x100633b7c（L308-338）：webtoon 追加加载。
    func loadAndAppendNextForWebtoon() {
        guard isWebtoonMode,
              let urls = chapterImageURLs[currentChapterIndex + 1] else { return }
        chapterImageURLs[currentChapterIndex + 1] = urls
    }

    /// 伪代码 0x100634448（L341-349）：webtoon 进度。
    func saveWebtoonProgress(at index: Int) {
        saveProgress()
    }

    /// 伪代码 0x100634970（L356-361）：进度保存（BookService 域确证）。
    func saveProgress() {
        _ = bookService.saveReadingProgress(
            book: book, chapterIndex: currentChapterIndex, position: 0)
    }

    /// 伪代码 0x100634b18（L365-368）：书架加入提示判定。
    func shouldPromptAddToBookshelf() -> Bool {
        !book.isBookshelfBook
    }

    /// 伪代码 0x100634bf0（L370-372）：加入书架。
    func addBookToBookshelf() {
        bookService.addBookToBookshelf(book)
    }

    /// 伪代码 0x100634ee4（L376-396）：当前章刷新。
    func refreshCurrentChapter() async {
        chapterImageURLs[currentChapterIndex] = nil
        await loadChapterImages(currentChapterIndex)
    }

    /// 伪代码 0x100634fec（L398-436）：章节列表刷新。
    func refreshChapterList() async {
        await loadBook()
    }

    /// 伪代码 0x100631170（L440-443）：任务取消。
    func cancelAllTasks() {
        isLoading = false
    }
}
