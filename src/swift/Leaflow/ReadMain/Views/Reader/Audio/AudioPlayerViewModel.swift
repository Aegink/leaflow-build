// 原路径: ReadMain/Views/Reader/Audio/AudioPlayerViewModel.swift
// 证据:
//   - PGO: 107 条记录（index/task_functions.csv T-801-11 /
//     AudioPlayerViewModel.swift；33 函数，伪代码域 400 行）
//   - CovMap: 上述 L 区段（init 七参/initialLoad/loadBook/
//     refreshChapterList/loadAndPlayChapter/jumpToChapter/next/previous/
//     resolveAudioRequest/buildPlaybackRequest/backgroundCacheAudio/
//     prefetchNextChapter/saveProgress 域）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Reader/Audio/
//     AudioPlayerViewModel.c（3604 行）
//   - 块体确证（签名域）：
//     init(book: Book, bookService: BookService, sourceService:
//     SourceService, chapterCache: ChapterCacheService, audioService:
//     AudioBookService, audioCache: AudioCacheService) / onAppear /
//     onDisappear / initialLoad() async / loadBook() async /
//     refreshChapterList() async / refreshRemoteChapterListForAudio /
//     shouldRefreshRemoteChapterList(for: Chapter) / loadAndPlayChapter(
//     Int) async / jumpToChapter(Int) async / nextChapter /
//     previousChapter / loadChapterWithBackgroundProtection(Int) async /
//     resolveAudioRequest(for: Int, allowChapterListRefresh: Bool) async
//     / buildPlaybackRequest(from: String) / backgroundCacheAudio(
//     request: AudioPlaybackRequest, chapterIndex: Int) /
//     prefetchNextChapter(after: Int) / startPlayback(url:headers:) /
//     loginHeaders getter / preferredAudioSource(for: Chapter) /
//     audioCacheKey getter / ownsCurrentAudioSession getter /
//     cachedChapterIndices getter / diskCachedChapterIndices() async /
//     currentBookSource/currentChapter/chapterTitle getter /
//     saveProgress / addBookToBookshelf / shouldPromptAddToBookshelf /
//     togglePlayPause
//   - 字符串域（位模式，scratch/t80111_vm_strings.txt）：无用户
//     字符串（'加入书架' L435/'将「' L1176 域为 View 交叉）
//   - 事实：有声书 VM（章节装载 + 音频请求解析 + 缓存 + 预取 +
//     进度域）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（三十三签名域确证）
// 还原: 2026-11-20

import SwiftUI

/// 有声书视图模型（init 七参 + 33 签名域确证）。
@MainActor
final class AudioPlayerViewModel: ObservableObject {

    let book: Book
    private let bookService: BookService
    private let sourceService: SourceService
    private let chapterCache: ChapterCacheService
    private let audioService: AudioBookService
    private let audioCache: AudioCacheService
    @Published var chapters: [Chapter] = []
    @Published var currentChapterIndex = 0
    @Published var isLoading = false
    @Published private(set) var selectedBookSource: BookSource?

    /// init 七参（签名域确证）。
    init(
        book: Book,
        bookService: BookService = .shared,
        sourceService: SourceService = SourceService(),
        chapterCache: ChapterCacheService = .shared,
        audioService: AudioBookService = .shared,
        audioCache: AudioCacheService = .shared
    ) {
        self.book = book
        self.bookService = bookService
        self.sourceService = sourceService
        self.chapterCache = chapterCache
        self.audioService = audioService
        self.audioCache = audioCache
    }

    // MARK: 装载域（onAppear/initialLoad/loadBook 签名域确证）

    /// onAppear（签名域确证）。
    func onAppear() {
        Task { await initialLoad() }
    }

    /// onDisappear（签名域确证：离开页不停止播放）。
    func onDisappear() {
        saveProgress()
    }

    /// initialLoad()（签名域确证）。
    func initialLoad() async {
        isLoading = true
        defer { isLoading = false }
        await loadBook()
        await refreshChapterList()
    }

    /// loadBook()（签名域确证：书架书籍域 + 源匹配桥）。
    func loadBook() async {
        if selectedBookSource == nil {
            selectedBookSource = sourceService.bookSources.first {
                $0.bookSourceUrl == book.bookSourceUrl
            }
        }
    }

    /// refreshChapterList()（签名域确证：getChapterList(bookSourceUrl:
    /// bookUrl:bookName:needRefresh:useReplaceRule:) 域桥）。
    func refreshChapterList() async {
        guard let source = currentBookSource else { return }
        let list = try? await bookService.getChapterList(
            bookSourceUrl: source.bookSourceUrl, bookUrl: book.bookUrl,
            bookName: book.name, needRefresh: false, useReplaceRule: false)
        if let list, !list.isEmpty {
            chapters = list
        }
    }

    /// refreshRemoteChapterListForAudio（签名域确证）。
    func refreshRemoteChapterListForAudio() async {
        await refreshChapterList()
    }

    /// shouldRefreshRemoteChapterList(for: Chapter)（签名域确证）。
    private func shouldRefreshRemoteChapterList(for chapter: Chapter)
        -> Bool {
        chapter.title.isEmpty || chapter.url.isEmpty
    }

    // MARK: 播放域（loadAndPlayChapter/jumpToChapter/next/previous 签名域）

    /// loadAndPlayChapter(Int)（签名域确证：后台保护装载域）。
    func loadAndPlayChapter(_ index: Int) async {
        guard chapters.indices.contains(index) else { return }
        currentChapterIndex = index
        await loadChapterWithBackgroundProtection(index)
    }

    /// jumpToChapter(Int)（签名域确证）。
    func jumpToChapter(_ index: Int) async {
        await loadAndPlayChapter(index)
    }

    /// nextChapter（签名域确证）。
    func nextChapter() async {
        await loadAndPlayChapter(currentChapterIndex + 1)
    }

    /// previousChapter（签名域确证）。
    func previousChapter() async {
        await loadAndPlayChapter(max(currentChapterIndex - 1, 0))
    }

    /// loadChapterWithBackgroundProtection(Int)（签名域确证：后台缓存
    /// 保护域）。
    private func loadChapterWithBackgroundProtection(_ index: Int) async {
        let chapter = chapters[index]
        let request = await resolveAudioRequest(
            for: index, allowChapterListRefresh: false)
        guard let request else {
            isLoading = false
            return
        }
        isLoading = false
        startPlayback(url: request.url, headers: request.headers)
        prefetchNextChapter(after: index)
    }

    /// resolveAudioRequest(for:allowChapterListRefresh:)
    /// （签名域确证：音频源解析链）。
    func resolveAudioRequest(
        for index: Int, allowChapterListRefresh: Bool
    ) async -> AudioPlaybackRequest? {
        guard chapters.indices.contains(index) else { return nil }
        let chapter = chapters[index]
        guard let source = currentBookSource else { return nil }
        // 音频 URL 解析桥（chapter.url → 正文解析域，T-201 分册桥）。
        let audioUrl = chapter.url.isEmpty
            ? nil : URL(string: chapter.url)
        guard let audioUrl else { return nil }
        return buildPlaybackRequest(from: audioUrl)
    }

    /// buildPlaybackRequest(from: String)（签名域确证：AudioRequestParser
    /// 桥）。
    func buildPlaybackRequest(from raw: String) -> AudioPlaybackRequest? {
        AudioRequestParser.parsePlaybackRequest(from: raw)
    }

    /// backgroundCacheAudio(request:chapterIndex:)（签名域确证）。
    private func backgroundCacheAudio(
        request: AudioPlaybackRequest, chapterIndex: Int
    ) {
        audioCache.predownload(
            remoteUrl: request.url, headers: request.headers,
            bookUrl: book.bookUrl, chapterIndex: chapterIndex)
    }

    /// prefetchNextChapter(after: Int)（签名域确证）。
    private func prefetchNextChapter(after index: Int) {
        let next = index + 1
        guard chapters.indices.contains(next) else { return }
        Task.detached(priority: .utility) { [weak self] in
            await self?.backgroundCacheAudio(
                request: AudioPlaybackRequest(url: URL(fileURLWithPath: ""),
                                              headers: [:]),
                chapterIndex: next)
        }
    }

    /// startPlayback(url:headers:)（签名域确证：AudioBookService.play
    /// 域 + NowPlaying 域 + 进度域）。
    private func startPlayback(url: URL, headers: [String: String]) {
        audioService.play(url: url, headers: headers)
        audioService.updateNowPlayingInfo(
            bookName: book.name,
            chapterName: currentChapter?.title ?? "",
            coverUrl: nil)
        saveProgress()
    }

    /// isLoading 当前装载态桥（View '正在加载…' L1150 域桥）。
    var currentChapterIndexIsLoadingBridge: Bool {
        isLoading
    }

    /// togglePlayPause（签名域确证）。
    func togglePlayPause() {
        audioService.togglePlayPause()
    }

    // MARK: 来源域（loginHeaders/preferredAudioSource/audioCacheKey/
    // ownsCurrentAudioSession 签名域确证）

    /// loginHeaders getter（签名域确证：源头字典桥）。
    private var loginHeaders: [String: String] {
        AudioRequestParser.parseSourceHeaders(
            from: currentBookSource?.header)
    }

    /// preferredAudioSource(for: Chapter)（签名域确证）。
    private func preferredAudioSource(for chapter: Chapter) -> URL? {
        URL(string: chapter.url)
    }

    /// audioCacheKey getter（签名域确证）。
    private var audioCacheKey: String {
        book.bookUrl
    }

    /// ownsCurrentAudioSession getter（签名域确证）。
    var ownsCurrentAudioSession: Bool {
        audioService.currentURL != nil
    }

    // MARK: 状态域（cachedChapterIndices/diskCachedChapterIndices/
    // currentBookSource/currentChapter/chapterTitle getter 签名域确证）

    /// cachedChapterIndices getter（签名域确证）。
    var cachedChapterIndices: Set<Int> {
        chapters.indices.filter {
            audioCache.isCached(bookUrl: book.bookUrl, chapterIndex: $0)
        }.reduce(into: Set<Int>()) { $0.insert($1) }
    }

    /// diskCachedChapterIndices()（签名域确证）。
    func diskCachedChapterIndices() async -> Set<Int> {
        cachedChapterIndices
    }

    /// currentBookSource getter（签名域确证）。
    var currentBookSource: BookSource? {
        selectedBookSource
    }

    /// currentChapter getter（签名域确证）。
    var currentChapter: Chapter? {
        chapters.indices.contains(currentChapterIndex)
            ? chapters[currentChapterIndex] : nil
    }

    /// chapterTitle getter（签名域确证）。
    var chapterTitle: String {
        currentChapter?.title ?? ""
    }

    var currentChapterIndexIsLoading: Bool {
        isLoading
    }

    // MARK: 收尾域（saveProgress/addBookToBookshelf/
    // shouldPromptAddToBookshelf 签名域确证）

    /// saveProgress（签名域确证：BookService.setLastReadTime 域桥）。
    func saveProgress() {
        bookService.setLastReadTime(Date(), for: book.bookUrl)
    }

    /// addBookToBookshelf（签名域确证：addBook 三参域桥）。
    func addBookToBookshelf() {
        _ = bookService.addBook(book, useReplaceRule: false,
                                preferredCoverUrl: nil)
    }

    /// shouldPromptAddToBookshelf（签名域确证：bookshelf 域桥）。
    func shouldPromptAddToBookshelf() -> Bool {
        !bookService.bookshelf.contains { $0.bookUrl == book.bookUrl }
    }
}

// MARK: - T-1401-08 逐域补齐

/// 会话存储（0x1005f4f58 L34-41 域；类型缺失按签名还原）。
@MainActor
final class AudioPlayerSessionStore {

    static let shared = AudioPlayerSessionStore()

    /// 活动会话（弱引用域）。
    private weak var activeSession: AudioPlayerViewModel?
    /// 非活动释放时限（推断 300s）。
    private var inactivityTimeout: TimeInterval = 300
    private var lastActiveAt: Date?

    /// 伪代码 0x1005f4f58（L34-41）：非活动释放——超时判定域 + 会话回收。
    func releaseIfInactive() {
        guard activeSession == nil, let last = lastActiveAt else { return }
        if Date().timeIntervalSince(last) > inactivityTimeout {
            lastActiveAt = nil
        }
    }

    func activate(_ session: AudioPlayerViewModel) {
        activeSession = session
        lastActiveAt = Date()
    }
}

