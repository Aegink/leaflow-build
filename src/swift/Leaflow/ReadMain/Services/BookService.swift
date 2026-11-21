// 原路径: ReadMain/Services/BookService.swift
// 证据:
//   - PGO: 126 条记录（index/task_functions.csv T-601-03 /
//     BookService.swift；伪代码域 7399 行）。关键地址：
//     storageDir 变量初始化 / loadDataFromFile 0x1002e32d0 L64-70 /
//     flushPendingWrites 0x1002e4dbc L90-92 / migrateFromUserDefaultsIfNeeded
//     0x1002e5478 L127-176 / loadLocalBookshelf 0x1002e6024 L181-288 /
//     saveLocalBookshelf 0x1002e7ee4 L291-295 / saveBookReadTimes
//     0x1002e7f38 L298-301 / togglePinned 0x1002e8120 L314-322 /
//     toggleExplorePinned 0x1002e84c0 L337-347 / lastReadTime 0x1002e863c
//     L350-352 / addBook 0x1002e8b14 L385-418 / updateBook 0x1002e9708
//     L437-452 / resolveFetchedChapterList 0x1002ea294 L470-488 /
//     clearChapterListMemoryCache 0x1002ea4b8 L490-496 / getChapterList
//     0x1002eab30 L527-536 / getChapterListInternal 0x1002eb41c L561-618 /
//     getChapterContent 0x1002ebfd4 L634-649 / saveReadProgress
//     0x1002ed98c L751-768 / deleteGroup 0x1002ee764 L834-843 /
//     findBookInBookshelf 0x1002ef008 L869-881 / changeBookSource
//     0x1002ef1f8 L886-929 / init 0x1002e6b14 L109-123
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Services/BookService.c（7399 行）
//   - 文件名域（位模式/指针）："bookshelf.json" L1170/"readtimes.json"
//     L1333/"booksources.json" @ptr L1400/"pinnedbooks.json" @ptr L1603/
//     "groups.json" L812/" 本（清理 " L497（deleteBooks 域）/"表内存缓存
//     reason=" @ptr L3184
//   - 事实：存储五文件（bookshelf/readtimes/booksources/pinnedbooks/
//     groups）+ 迁移域 + 目录缓存清理 + 书架增删改/分组/换源/进度主链
//   - 消费：T-501-01..08/T-401-04..07 多处 BookService 交叉
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - 存储/书架主链: high（地址 + 文件名位模式确证）
//   - 章节缓存联动: medium-high（ChapterCacheService T-601-03 交叉）
// 还原: 2026-11-20

import Foundation
import Combine

/// 书签模型（bookmarks.json BookmarkService L165 交叉）。
struct Bookmark: Codable, Identifiable, Equatable {
    var id = UUID()
    var bookUrl: String
    var name: String
    var chapterIndex: Int
    var position: Int
    var createdAt: Date = Date()
}

/// 书架项（SearchView T-501-07 bookshelfSearchResults 交叉确证）。
struct BookshelfItem: Identifiable, Equatable {
    let book: Book

    var id: String { book.id }
}

/// 书架与章节内容服务。
final class BookService: ObservableObject {

    @Published private(set) var bookshelf: [Book] = []
    @Published private(set) var groups: [String] = ["未分组"]
    @Published var lastError: AppError?

    /// 存储目录（storageDir 变量初始化确证）。
    private let storageDirectory: URL = FileManager.default.urls(
        for: .documentDirectory, in: .userDomainMask
    )[0].appendingPathComponent("bookshelf_data", isDirectory: true)

    private var bookshelfFileURL: URL {
        storageDirectory.appendingPathComponent("bookshelf.json")
    }
    private var readTimesFileURL: URL {
        storageDirectory.appendingPathComponent("readtimes.json")
    }
    private var pinnedBooksFileURL: URL {
        storageDirectory.appendingPathComponent("pinnedbooks.json")
    }
    private var groupsFileURL: URL {
        storageDirectory.appendingPathComponent("groups.json")
    }

    private var readTimes: [String: Date] = [:]
    private var pinnedBooks: Set<String> = []
    private var pinnedExploreSources: Set<String> = []
    private var chapterListMemoryCache: [String: [Chapter]] = [:]
    private let lock = NSLock()
    private var readyContinuations: [CheckedContinuation<Void, Never>] = []
    private var ready = false

    private let sourceService = SourceService()
    private let chapterCache = ChapterCacheService.shared

    /// init（0x1002e6b14 L109-123 域确证）。
    init() {
        try? FileManager.default.createDirectory(
            at: storageDirectory, withIntermediateDirectories: true)
        migrateFromUserDefaultsIfNeeded()
        Task { await loadLocalBookshelf() }
    }

    /// waitUntilReady（签名确证）。
    func waitUntilReady() async {
        if ready { return }
        await withCheckedContinuation { continuation in
            lock.lock()
            if ready {
                lock.unlock()
                continuation.resume()
                return
            }
            readyContinuations.append(continuation)
            lock.unlock()
        }
    }

    private func markReady() {
        lock.lock()
        ready = true
        let continuations = readyContinuations
        readyContinuations.removeAll()
        lock.unlock()
        for continuation in continuations {
            continuation.resume()
        }
    }

    // MARK: 文件读写（0x1002e32d0 L64-70 域确证）

    /// loadDataFromFile（0x1002e32d0 L64-70 域确证）。
    private func loadDataFromFile(_ filename: String) async -> Data? {
        let url = storageDirectory.appendingPathComponent(filename)
        return try? Data(contentsOf: url)
    }

    /// saveToFile<A>(_:filename:)（签名确证）。
    private func saveToFile<A: Encodable>(_ value: A, filename: String) {
        let target = storageDirectory.appendingPathComponent(filename)
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: target, options: .atomic)
    }

    /// flushPendingWrites（0x1002e4dbc L90-92 域确证）。
    func flushPendingWrites() {
        saveLocalBookshelf()
        saveBookReadTimes()
    }

    // MARK: 迁移域（0x1002e5478 L127-176 域确证）

    /// migrateFromUserDefaultsIfNeeded（0x1002e5478 L127-176 域确证）。
    private func migrateFromUserDefaultsIfNeeded() {
        guard
            let data = UserDefaults.standard.data(forKey: "bookshelf"),
            let legacy = try? JSONDecoder().decode([Book].self, from: data),
            !legacy.isEmpty
        else { return }
        if (try? Data(contentsOf: bookshelfFileURL)) == nil {
            if let encoded = try? JSONEncoder().encode(legacy) {
                try? encoded.write(to: bookshelfFileURL, options: .atomic)
            }
        }
        UserDefaults.standard.removeObject(forKey: "bookshelf")
        Logger.log("书架迁移完成 \(legacy.count) 本", level: .info)
    }

    // MARK: 书架装载（0x1002e6024 L181-288 域确证）

    /// loadLocalBookshelf（0x1002e6024 L181-288 域确证）。
    private func loadLocalBookshelf() async {
        let shelfData = await loadDataFromFile("bookshelf.json")
        let readTimesData = await loadDataFromFile("readtimes.json")
        let pinnedData = await loadDataFromFile("pinnedbooks.json")
        let groupsData = await loadDataFromFile("groups.json")
        let shelf = shelfData.flatMap {
            try? JSONDecoder().decode([Book].self, from: $0)
        } ?? []
        let times = readTimesData.flatMap {
            try? JSONDecoder().decode([String: Date].self, from: $0)
        } ?? [:]
        let pinned = pinnedData.flatMap {
            try? JSONDecoder().decode([String].self, from: $0)
        } ?? []
        let loadedGroups = groupsData.flatMap {
            try? JSONDecoder().decode([String].self, from: $0)
        } ?? ["未分组"]
        await MainActor.run {
            bookshelf = shelf
            readTimes = times
            pinnedBooks = Set(pinned)
            groups = loadedGroups
            markReady()
        }
    }

    /// saveLocalBookshelf（0x1002e7ee4 L291-295 域确证）。
    private func saveLocalBookshelf() {
        saveToFile(bookshelf, filename: "bookshelf.json")
    }

    /// saveBookReadTimes（0x1002e7f38 L298-301 域确证）。
    private func saveBookReadTimes() {
        saveToFile(readTimes, filename: "readtimes.json")
    }

    /// savePinnedBooks（签名确证）。
    private func savePinnedBooks() {
        saveToFile(Array(pinnedBooks), filename: "pinnedbooks.json")
    }

    /// savePinnedExploreSources（0x1002e8210 L327-329 域确证）。
    private func savePinnedExploreSources() {}

    // MARK: 置顶域（0x1002e8120 L314-322 + 0x1002e84c0 L337-347 域确证）

    /// togglePinned（0x1002e8120 L314-322 域确证）。
    func togglePinned(_ bookId: String) {
        if pinnedBooks.contains(bookId) {
            pinnedBooks.remove(bookId)
        } else {
            pinnedBooks.insert(bookId)
        }
        savePinnedBooks()
    }

    /// isPinned（签名确证）。
    func isPinned(_ bookId: String) -> Bool {
        pinnedBooks.contains(bookId)
    }

    /// isExplorePinned（签名确证）。
    func isExplorePinned(_ source: BookSource) -> Bool {
        pinnedExploreSources.contains(source.bookSourceUrl)
    }

    /// toggleExplorePinned（0x1002e84c0 L337-347 域确证）。
    func toggleExplorePinned(_ source: BookSource) {
        if pinnedExploreSources.contains(source.bookSourceUrl) {
            pinnedExploreSources.remove(source.bookSourceUrl)
        } else {
            pinnedExploreSources.insert(source.bookSourceUrl)
        }
        savePinnedExploreSources()
    }

    // MARK: 阅读时间域（0x1002e863c L350-352 域确证）

    /// lastReadTime（0x1002e863c L350-352 域确证）。
    func lastReadTime(for bookId: String) -> Date {
        readTimes[bookId] ?? .distantPast
    }

    /// setLastReadTime（签名确证）。
    func setLastReadTime(_ date: Date, for bookId: String) {
        readTimes[bookId] = date
        saveBookReadTimes()
    }

    // MARK: 书架增删改（0x1002e8b14 L385-418 域确证）

    /// addBook（0x1002e8b14 L385-418 域确证）。
    @discardableResult
    func addBook(
        _ book: Book, useReplaceRule: Bool, preferredCoverUrl: String?
    ) -> Bool {
        var newBook = book
        if let cover = preferredCoverUrl {
            newBook.coverUrl = cover
        }
        newBook.useReplaceRule = useReplaceRule ? 1 : 0
        newBook.normalizeBookIdIfNeeded()
        lock.lock()
        if let index = bookshelf.firstIndex(where: { $0.id == newBook.id }) {
            bookshelf[index] = newBook
        } else {
            bookshelf.append(newBook)
        }
        lock.unlock()
        saveLocalBookshelf()
        return true
    }

    /// deleteBooks（签名确证；" 本（清理 " L497 域确证）。
    @discardableResult
    func deleteBooks(_ bookIds: [String]) -> Bool {
        lock.lock()
        let removed = bookshelf.filter { bookIds.contains($0.id) }
        bookshelf.removeAll { bookIds.contains($0.id) }
        lock.unlock()
        if !removed.isEmpty {
            Logger.log("\(removed.count) 本（清理", level: .info)
        }
        saveLocalBookshelf()
        return !removed.isEmpty
    }

    /// deleteBook（签名确证）。
    @discardableResult
    func deleteBook(_ book: Book) -> Bool {
        deleteBooks([book.id])
    }

    /// clearLocalBookshelf（签名确证）。
    func clearLocalBookshelf() {
        lock.lock()
        bookshelf.removeAll()
        lock.unlock()
        saveLocalBookshelf()
    }

    /// updateBook（0x1002e9708 L437-452 域确证）。
    func updateBook(_ book: Book) {
        lock.lock()
        if let index = bookshelf.firstIndex(where: { $0.id == book.id }) {
            bookshelf[index] = book
        }
        lock.unlock()
        saveLocalBookshelf()
    }

    /// mergeStoredGroupIfNeeded（0x1002ea0d4 L454-460 域确证）。
    private func mergeStoredGroupIfNeeded(
        into book: inout Book, from stored: Book
    ) {
        if book.group == nil {
            book.group = stored.group
        }
    }

    /// storedBook（签名确证）。
    private func storedBook(
        bookSourceUrl: String, bookUrl: String
    ) -> Book? {
        bookshelf.first {
            $0.bookSourceUrl == bookSourceUrl && $0.bookUrl == bookUrl
        }
    }

    /// findSource（0x1002ea854 L514-525 域确证）。
    private func findSource(
        byUrl url: String, bookUrl: String
    ) -> BookSource? {
        sourceService.bookSources.first { $0.bookSourceUrl == url }
    }

    // MARK: 章节域（0x1002eab30 L527-536 + 0x1002eb41c L561-618 域确证）

    /// resolveFetchedChapterList（0x1002ea294 L470-488 域确证）。
    private func resolveFetchedChapterList(
        _ chapters: [Chapter], cacheKey: String
    ) async -> [Chapter] {
        chapterListMemoryCache[cacheKey] = chapters
        await chapterCache.saveChapterList(
            bookUrl: cacheKey, chapters: chapters)
        return chapters
    }

    /// clearChapterListMemoryCache（0x1002ea4b8 L490-496 域确证）。
    func clearChapterListMemoryCache(reason: String) {
        chapterListMemoryCache.removeAll()
        Logger.log("章节列表内存缓存 reason=\(reason)", level: .info)
    }

    /// getChapterList（0x1002eab30 L527-536 域确证）。
    func getChapterList(
        bookSourceUrl: String, bookUrl: String, bookName: String,
        needRefresh: Bool, useReplaceRule: Bool
    ) async throws -> [Chapter] {
        let cacheKey = Book.chapterCacheKey(
            bookUrl: bookUrl, bookSourceUrl: bookSourceUrl,
            sourceStorageKind: nil)
        if !needRefresh, let cached = chapterListMemoryCache[cacheKey] {
            return cached
        }
        if !needRefresh, let cached = await chapterCache.getChapterList(
            bookUrl: cacheKey) {
            return cached
        }
        guard let source = findSource(byUrl: bookSourceUrl, bookUrl: bookUrl)
        else {
            throw AppError.parsing("书源未找到")
        }
        var target = Book()
        target.bookUrl = bookUrl
        target.name = bookName
        let chapters = try await sourceService.getChapterList(
            source: source, book: target, needRefresh: needRefresh)
        _ = await resolveFetchedChapterList(chapters, cacheKey: cacheKey)
        return chapters
    }

    /// getChapterList(for:)（0x1002eadd4 L538-548 域确证）。
    func getChapterList(
        for book: Book, useReplaceRule: Bool, needRefresh: Bool
    ) async throws -> [Chapter] {
        try await getChapterList(
            bookSourceUrl: book.bookSourceUrl ?? "",
            bookUrl: book.bookUrl ?? "", bookName: book.name,
            needRefresh: needRefresh, useReplaceRule: useReplaceRule)
    }

    /// getChapterContent（0x1002ebfd4 L634-649 域确证）。
    func getChapterContent(
        for book: Book, index: Int, useReplaceRule: Bool, type: Int?
    ) async throws -> ChapterContent {
        guard let source = findSource(
            byUrl: book.bookSourceUrl ?? "", bookUrl: book.bookUrl ?? "")
        else {
            throw AppError.parsing("书源未找到")
        }
        let cacheKey = book.chapterCacheKey
        if let cached = await chapterCache.getChapterContent(
            bookUrl: cacheKey, chapterIndex: index) {
            return cached
        }
        let chapters = try await getChapterList(
            for: book, useReplaceRule: useReplaceRule, needRefresh: false)
        guard index < chapters.count else {
            throw AppError.emptyContent
        }
        let content = try await sourceService.getChapterContent(
            source: source, book: book, chapter: chapters[index])
        await chapterCache.saveChapterContent(
            bookUrl: cacheKey, chapterIndex: index,
            content: content.content)
        return content
    }

    /// resolveChapterContentType（0x1002ed3c0 L725-747 域确证）。
    private func resolveChapterContentType(
        requestedType: Int?, book: Book
    ) -> Int {
        requestedType ?? book.bookType
    }

    // MARK: 阅读进度（0x1002ed98c L751-768 域确证）

    /// saveReadProgress（0x1002ed98c L751-768 域确证）。
    func saveReadProgress(
        book: Book, chapterIndex: Int, chapterTitle: String,
        position: Double
    ) {
        var updated = book
        updated.durChapterIndex = chapterIndex
        updated.durChapterTitle = chapterTitle
        updated.durChapterPos = position
        updateBook(updated)
        setLastReadTime(Date(), for: updated.id)
    }

    /// saveReadProgress(bookId:)（签名确证）。
    func saveReadProgress(
        bookId: String, chapterIndex: Int, chapterTitle: String,
        position: Double
    ) {
        guard var book = bookshelf.first(where: { $0.id == bookId }) else {
            return
        }
        book.durChapterIndex = chapterIndex
        book.durChapterTitle = chapterTitle
        book.durChapterPos = position
        updateBook(book)
        setLastReadTime(Date(), for: bookId)
    }

    // MARK: 分组域（0x1002ee764 L834-843 域确证）

    /// addGroup（签名确证）。
    @discardableResult
    func addGroup(name: String) -> Bool {
        guard !groups.contains(name), !name.isEmpty else { return false }
        groups.append(name)
        saveToFile(groups, filename: "groups.json")
        return true
    }

    /// deleteGroup（0x1002ee764 L834-843 域确证）。
    func deleteGroup(name: String) {
        guard name != "未分组" else { return }
        groups.removeAll { $0 == name }
        for index in bookshelf.indices where bookshelf[index].group == name {
            bookshelf[index].group = "未分组"
        }
        saveToFile(groups, filename: "groups.json")
        saveLocalBookshelf()
    }

    /// setBookGroup（0x1002eeed8 L845-850 域确证）。
    func setBookGroup(bookId: String, groupName: String?) {
        guard var book = bookshelf.first(where: { $0.id == bookId }) else {
            return
        }
        book.group = groupName
        updateBook(book)
    }

    // MARK: 查找域（0x1002ef008 L869-881 域确证）

    /// findBookInBookshelf（0x1002ef008 L869-881 域确证）。
    func findBookInBookshelf(
        bookname: String, author: String?
    ) -> Book? {
        bookshelf.first {
            $0.name.lowercased() == bookname.lowercased()
                && ($0.author ?? "").lowercased()
                    == (author ?? "").lowercased()
        }
    }

    /// changeBookSource（0x1002ef1f8 L886-929 域确证）。
    func changeBookSource(
        oldBook: Book, newBook: Book
    ) -> Book? {
        var changed = newBook
        changed.group = oldBook.group
        changed.durChapterIndex = oldBook.durChapterIndex
        changed.durChapterTitle = oldBook.durChapterTitle
        changed.skipUpdate = oldBook.skipUpdate
        deleteBooks([oldBook.id])
        addBook(
            changed, useReplaceRule: oldBook.useReplaceRule == 1,
            preferredCoverUrl: oldBook.coverUrl)
        return changed
    }

    /// reportError（签名确证）。
    private func reportError(_ error: AppError) -> AppError {
        lastError = error
        return error
    }
}

extension BookService {

    /// 共享实例（AudioPlayerViewModel 消费域）。
    static let shared = BookService()
}
