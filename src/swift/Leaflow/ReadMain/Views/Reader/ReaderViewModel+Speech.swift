// 原路径: ReadMain/Views/Reader/ReaderViewModel+Speech.swift
// 证据: ReaderViewModel+Speech.c：0x100895694 L47-57 show；
// 0x10089590c L63-72 advance；0x100896178 L74-82 change。
// 属主八项要求来自 index/task_functions.csv 与类型表 17684。
import Foundation

extension ReaderViewModel {
    var readAloudCoordinator: ReadAloudCoordinator { ReaderSpeechSupport.sharedCoordinator }
    var readAloudOwner: ReadAloudSessionOwner { self }

    func toggleSpeech() { readAloudCoordinator.toggle(owner: self) }
    func stopSpeech() { readAloudCoordinator.stop(owner: self) }

    func syncSpeechForPageChange(to pageIndex: Int) {
        guard readAloudCoordinator.owns(self), pages.indices.contains(pageIndex) else { return }
        readAloudCoordinator.seekToCurrentPage(owner: self)
    }

    var readAloudCurrentPageIndex: Int { currentPageIndex }
    var readAloudPages: [PageData] { pages }
    var readAloudMetadata: ReadAloudMetadata {
        .init(bookName: currentBook?.name ?? bookName,
            chapterName: chapters.indices.contains(currentChapterIndex) ? chapters[currentChapterIndex].name : "",
            author: currentBook?.author ?? "", bookFingerprint: currentBook?.contentFingerprint ?? "",
            coverURL: currentBook?.coverUrl)
    }

    func readAloudShow(location: ReadAloudLocation) {
        guard let index = pages.firstIndex(where: {
            $0.chapterIndex == location.chapterIndex && $0.pageIndex == location.pageIndex
        }) else { return }
        currentPageIndex = index
        currentChapterIndex = location.chapterIndex
        speechSessionPreparing = false
        applyReadAloudAnchor(readAloudCoordinator.currentAnchor)
    }

    func readAloudSaveProgress() {
        if let book = currentBook, let page = currentPage {
            let position = readAloudCoordinator.currentAnchor?.rangeInChapter?.location
                ?? page.contentRangeInChapter?.location ?? 0
            bookService.saveReadProgress(book: book, chapterIndex: page.chapterIndex,
                chapterTitle: page.chapterTitle, position: Double(position))
        }
    }

    func readAloudSessionDidFinish() {
        speechSessionPreparing = false
        applyReadAloudAnchor(nil)
    }

    func readAloudAdvanceChapter() async -> ReadAloudChapterAdvanceResult {
        await readAloudChangeChapter(by: 1)
    }

    func readAloudChangeChapter(by offset: Int) async -> ReadAloudChapterChangeResult {
        let target = currentChapterIndex + offset
        guard chapters.indices.contains(target) else { return .exhausted }
        await loadChapterForReadAloud(target)
        guard let index = pages.firstIndex(where: {
            $0.chapterIndex == target && ReadAloudQueueBuilder.isReadable($0)
        }) else { return .exhausted }
        currentChapterIndex = target
        currentPageIndex = index
        return .advanced
    }

    func loadChapterForReadAloud(_ index: Int) async {
        await loadChapterContent(index, forceRefresh: false)
    }

    func commitPageTurn() { saveProgress() }
    func readAloudShow() { speechSessionPreparing = false }
}

@MainActor
enum ReaderSpeechSupport {
    static let defaults: UserDefaults = {
        guard ProcessInfo.processInfo.arguments.contains("-smokeTtsSources") else { return .standard }
        let suite = "t1602-tts-sources-ui"
        let defaults = UserDefaults(suiteName: suite)!
        if ProcessInfo.processInfo.arguments.contains("-smokeTtsSourcesReset") {
            defaults.removePersistentDomain(forName: suite)
        }
        return defaults
    }()
    static let runtimeStore = HttpTtsRuntimeStore(defaults: defaults)
    static let preferences = ReadAloudPreferences(defaults: defaults)
    static let sources: HttpTtsSourceRepository = {
        let repository = HttpTtsSourceRepository(defaults: defaults, runtimeStore: runtimeStore)
        preferences.migrateLegacySourceSelection(using: repository)
        return repository
    }()
    static let sharedCoordinator = ReadAloudCoordinator(
        factory: DefaultReadAloudDriverFactory(preferences: preferences, sources: sources,
            synthesizer: HttpTtsSynthesizer(transport: URLSession.shared,
                webSocketTransport: URLSessionHttpTtsWebSocketTransport(), runtimeStore: runtimeStore)),
        preferences: preferences)
}
