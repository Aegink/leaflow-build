// 原路径: ReadMain/Views/Reader/ChangeSourceView.swift
// 证据:
//   - PGO: 131 条记录（index/functions.csv ChangeSourceView.swift），含
//     bootstrapPlan / cacheKey / hasMatchingSearchResultCache /
//     buildSourceNameCache / restoreFromCache / restoreFromSearchCache /
//     startObservingSearchResultCacheIfNeeded / stopObservingSearchResultCache /
//     saveToCacheOnExit / clearSearchCachesInBackground / searchSources /
//     beginChangeSourceSearch / sortedSearchableSources /
//     makeChangeSourceSearchTask / pollChangeSourceSearch /
//     finishChangeSourceSearch / refreshChangeSourceResults /
//     updateSearchResults / selectSource / stopCurrentSearch /
//     refreshButton / leadingButtons / sourceListContent /
//     matchingChangeSources / isChangeSourceMatch / isSearchableChangeSource /
//     sortedChangeSources / sourceSpeed / saveChangeSearchSpeedRecords /
//     runChangeSourceSearch / startInitialChangeSearchTasks /
//     scheduleNextChangeSearchTask / makeChangeSourceSearchContext /
//     SourceOptionRow。
//   - 类型树（index/swift_types_dump.txt L9225-9253）：
//     ChangeSourceView 字段（book/onSourceChanged/cache/9 个 @State）/
//     ChangeSourceSearchContext（runID/searchKeyword/targetName/targetAuthor/
//     currentSourceUrl/threadCount/timeout）/ SourceOptionRow（book/
//     isCurrentSource/sourceName/sourceMode/isChanging/onSelect）。
//   - 依赖：ChangeSourceCache（entry/update）/ SearchEngine（mergeAndSnapshot）/
//     SearchViewModel.searchSingleSource / SourceSpeedTracker。
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（函数表/字段表/调用链确证；UI 布局细节 medium）
// 还原: 2026-11-19（C-0 逐页展开：搜索/缓存/换源链，2026-11-22）

import SwiftUI

/// 引导计划（伪代码 0x1006745a8，L11-28）。
struct ChangeSourceBootstrapPlan {
    var shouldLoadFromCache: Bool
    var shouldStartSearch: Bool

    /// 伪代码 0x1006745a8（L11-28）：根据缓存状态和搜索结果决定引导路径。
    static func make(
        hasCompletedChangeSourceCache: Bool,
        hasMatchingCache: Bool,
        hasMatchingSearchResultCache: Bool = false
    ) -> ChangeSourceBootstrapPlan {
        let hasAnyCache =
            hasCompletedChangeSourceCache && hasMatchingCache
        return ChangeSourceBootstrapPlan(
            shouldLoadFromCache: hasAnyCache || hasMatchingSearchResultCache,
            shouldStartSearch: !hasAnyCache || !hasMatchingSearchResultCache
        )
    }
}

/// 缓存身份。
enum ChangeSourceCacheIdentity {
    /// 伪代码 0x1004cd218（L36-40）：选中书籍并保留身份标识。
    static func selectedBook(
        _ book: Book, preservingIdentityFrom original: Book
    ) -> Book {
        var selected = book
        selected.bookUrl = original.bookUrl
        return selected
    }

    /// cacheKey(for:)（PGO 签名确证）：书名 + 作者归一键。
    static func cacheKey(for book: Book) -> String {
        let name = book.name.trimmingCharacters(in: .whitespaces)
        let author = (book.author ?? "")
            .trimmingCharacters(in: .whitespaces)
        return "\(name.lowercased())|\(author.lowercased())"
    }
}

/// 换源搜索上下文（类型树 L9245-9253）。
struct ChangeSourceSearchContext {
    let runID: UUID
    let searchKeyword: String
    let targetName: String
    let targetAuthor: String
    let currentSourceUrl: String?
    let threadCount: Int
    let timeout: Double
}

/// 换源视图（伪代码 0x100675cd4，L101-160）。
struct ChangeSourceView: View {

    @Environment(\.colorScheme) private var colorScheme
    let book: Book
    let onSourceChanged: (Book) -> Void
    var cache: ChangeSourceCache? = .shared
    @Environment(\.dismiss) private var dismiss

    @State private var isSearching = false
    @State private var isChanging = false
    @State private var searchResults: [Book] = []
    @State private var searchedCount = 0
    @State private var totalCount = 0
    @State private var sourceNameCache: [String: String] = [:]
    @State private var shouldStopSearch = false
    @State private var searchTask: Task<Void, Never>?
    @State private var searchResultCacheObservationTask: Task<Void, Never>?
    @State private var activeSearchRunID = UUID()
    @State private var seenSourceUrls: Set<String> = []
    @State private var seenBookIds: Set<String> = []

    private let sourceService = SourceService()
    private let searchResultCache = SearchResultCache()

    /// settings getter（PGO 签名确证）。
    private var settings: ReadingSettings {
        ReadingSettings.load()
    }

    // MARK: - 引导与缓存键

    /// cacheKey getter（PGO 签名确证）。
    private var cacheKey: String {
        ChangeSourceCacheIdentity.cacheKey(for: book)
    }

    /// hasMatchingSearchResultCache getter（PGO 签名确证）。
    private var hasMatchingSearchResultCache: Bool {
        let sources = searchResultCache.sourcesForBook(
            bookname: book.name, author: book.author)
        return !sources.isEmpty
    }

    /// 伪代码 0x10067475c（L85-91）：引导计划。
    private var bootstrapPlan: ChangeSourceBootstrapPlan {
        let cached = cache?.entry(for: cacheKey)
        return .make(
            hasCompletedChangeSourceCache: cached != nil,
            hasMatchingCache: !(cached?.items.isEmpty ?? true),
            hasMatchingSearchResultCache: hasMatchingSearchResultCache)
    }

    // MARK: - Body

    /// 伪代码 0x100675cd4（L101-160）：主 body。
    var body: some View {
        NavigationStack {
            sourceListContent
                .navigationTitle("换源")
                .toolbar {
                    leadingButtons
                    refreshButton
                }
                .scrollContentBackground(.hidden)
        }
        .onAppear {
            buildSourceNameCache()
            restoreFromCache()
            restoreFromSearchCache()
            startObservingSearchResultCacheIfNeeded()
            if bootstrapPlan.shouldStartSearch {
                startSearch()
            }
        }
        .onDisappear {
            stopCurrentSearch(updateUI: false)
            stopObservingSearchResultCache()
            saveToCacheOnExit()
            clearSearchCachesInBackground()
        }
    }

    // MARK: - 列表内容

    /// sourceListContent getter（PGO 签名确证）。
    @ViewBuilder
    private var sourceListContent: some View {
        List {
            Section("当前书源") {
                SourceOptionRow(
                    book: book,
                    isCurrentSource: true,
                    sourceName: sourceName(for: book),
                    sourceMode: book.sourceStorageKind ?? .remote,
                    isChanging: isChanging,
                    onSelect: {})
            }
            if isSearching {
                Section {
                    HStack(spacing: 8.0) {
                        ProgressView()
                        Text("正在搜索 \(searchedCount)/\(totalCount)")
                            .appThemeText(.caption, opacity: 0.7)
                        Spacer()
                        if shouldStopSearch {
                            Text("正在停止…")
                                .appThemeText(.caption, opacity: 0.5)
                        }
                    }
                }
            }
            Section("搜索结果") {
                if searchResults.isEmpty && !isSearching {
                    Text("未找到可换源结果")
                        .appThemeText(.caption, opacity: 0.6)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 20.0)
                }
                ForEach(searchResults, id: \.id) { result in
                    SourceOptionRow(
                        book: result,
                        isCurrentSource: isCurrentSource(result),
                        sourceName: sourceName(for: result),
                        sourceMode: result.sourceStorageKind ?? .remote,
                        isChanging: isChanging,
                        onSelect: { selectSource(result) })
                }
            }
        }
        .refreshable {
            startSearch()
        }
    }

    /// refreshButton getter（PGO 签名确证）。
    @ToolbarContentBuilder
    private var refreshButton: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                startSearch()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .disabled(isSearching)
        }
    }

    /// leadingButtons getter（PGO 签名确证）。
    @ToolbarContentBuilder
    private var leadingButtons: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button("关闭") { dismiss() }
        }
        if isSearching {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("停止") { stopCurrentSearch(updateUI: true) }
            }
        }
    }

    // MARK: - 缓存

    /// buildSourceNameCache（PGO 签名确证）。
    private func buildSourceNameCache() {
        var map: [String: String] = [:]
        for source in sourceService.bookSources {
            map[source.bookSourceUrl] = source.bookSourceName
        }
        sourceNameCache = map
    }

    /// restoreFromCache（PGO 签名确证）：ChangeSourceCache → 结果列表。
    private func restoreFromCache() {
        guard let entry = cache?.entry(for: cacheKey),
              !entry.items.isEmpty else { return }
        let books = entry.items.map { $0.toBook() }
        mergeRestored(books)
        totalCount = max(totalCount, entry.totalCount)
    }

    /// restoreFromSearchCache（PGO 签名确证）：搜索结果缓存 → 结果列表。
    @discardableResult
    private func restoreFromSearchCache() -> Bool {
        let sources = searchResultCache.sourcesForBook(
            bookname: book.name, author: book.author)
        guard !sources.isEmpty else { return false }
        mergeRestored(sources)
        return true
    }

    private func mergeRestored(_ books: [Book]) {
        var merged = searchResults
        var known = Set(merged.map(\.id))
        for candidate in books where known.insert(candidate.id).inserted {
            merged.append(candidate)
        }
        searchResults = merged
    }

    /// startObservingSearchResultCacheIfNeeded（PGO 签名确证）。
    private func startObservingSearchResultCacheIfNeeded() {
        guard searchResultCacheObservationTask == nil else { return }
        searchResultCache.setChangeHandler { [self] in
            Task { @MainActor in
                _ = restoreFromSearchCache()
            }
        }
        searchResultCacheObservationTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 800_000_000)
                _ = restoreFromSearchCache()
            }
        }
    }

    /// stopObservingSearchResultCache（PGO 签名确证）。
    private func stopObservingSearchResultCache() {
        searchResultCacheObservationTask?.cancel()
        searchResultCacheObservationTask = nil
        searchResultCache.setChangeHandler(nil)
    }

    /// saveToCacheOnExit（PGO 签名确证）。
    private func saveToCacheOnExit() {
        guard !searchResults.isEmpty else { return }
        let items = searchResults.map {
            ChangeSourceCache.SourceItem.from($0)
        }
        cache?.update(bookUrl: cacheKey, items: items)
    }

    /// clearSearchCachesInBackground（PGO 签名确证）。
    private func clearSearchCachesInBackground() {
        let key = cacheKey
        Task.detached(priority: .utility) {
            ChangeSourceCache.shared.clearEntry(for: key)
        }
    }

    // MARK: - 搜索

    /// beginChangeSourceSearch（PGO 签名确证）：新 runID + 重置态。
    private func beginChangeSourceSearch() -> UUID {
        let runID = UUID()
        activeSearchRunID = runID
        shouldStopSearch = false
        searchedCount = 0
        searchResults = []
        seenSourceUrls = []
        seenBookIds = []
        isSearching = true
        return runID
    }

    /// makeChangeSourceSearchContext（PGO 签名确证）。
    private func makeChangeSourceSearchContext(
        runID: UUID
    ) -> ChangeSourceSearchContext {
        ChangeSourceSearchContext(
            runID: runID,
            searchKeyword: book.name,
            targetName: book.name,
            targetAuthor: book.author ?? "",
            currentSourceUrl: book.bookSourceUrl,
            threadCount: 8,
            timeout: 15.0)
    }

    /// sortedSearchableSources（PGO 签名确证）。
    private func sortedSearchableSources() async -> [BookSource] {
        let all = sourceService.bookSources.filter {
            Self.isSearchableChangeSource($0)
        }
        return SourceSpeedTracker.shared.sortBySpeed(all)
    }

    /// searchSources（PGO 签名确证）。
    private func startSearch() {
        stopCurrentSearch(updateUI: false)
        let runID = beginChangeSourceSearch()
        let context = makeChangeSourceSearchContext(runID: runID)
        searchTask = Task { [self] in
            let sources = await self.sortedSearchableSources()
            await MainActor.run {
                self.totalCount = sources.count
            }
            let engine = SearchEngine(keyword: context.searchKeyword)
            await self.runChangeSourceSearch(
                sources: sources, context: context, engine: engine)
            await self.finishChangeSourceSearch(
                engine: engine, context: context)
        }
    }

    /// runChangeSourceSearch（PGO 签名确证）：线程池并发 + 增量合并。
    private func runChangeSourceSearch(
        sources: [BookSource],
        context: ChangeSourceSearchContext,
        engine: SearchEngine
    ) async {
        let limit = max(1, context.threadCount)
        await withTaskGroup(
            of: (books: [Book], sourceUrl: String, time: Double)?.self
        ) { group in
            var iterator = sources.makeIterator()
            for _ in 0..<limit {
                guard let source = iterator.next() else { break }
                group.addTask {
                    await Self.searchOneSource(
                        source, keyword: context.searchKeyword)
                }
            }
            while let result = await group.next() {
                if Task.isCancelled || shouldStopSearch {
                    group.cancelAll()
                    break
                }
                if let result {
                    SourceSpeedTracker.shared.record(
                        sourceUrl: result.sourceUrl, time: result.time)
                    let snapshot = engine.mergeAndSnapshot(result.books).snapshot
                    await MainActor.run {
                        self.updateSearchResults(
                            from: snapshot,
                            currentSourceUrl: context.currentSourceUrl)
                        self.searchedCount += 1
                    }
                } else {
                    await MainActor.run { self.searchedCount += 1 }
                }
                if let next = iterator.next() {
                    group.addTask {
                        await Self.searchOneSource(
                            next, keyword: context.searchKeyword)
                    }
                }
            }
        }
    }

    /// finishChangeSourceSearch（PGO 签名确证）。
    private func finishChangeSourceSearch(
        engine: SearchEngine, context: ChangeSourceSearchContext
    ) async {
        let snapshot = engine.finalSnapshot(clearState: false)
        await MainActor.run {
            guard self.activeSearchRunID == context.runID else { return }
            self.updateSearchResults(
                from: snapshot, currentSourceUrl: context.currentSourceUrl)
            self.isSearching = false
            self.saveToCacheOnExit()
            SourceSpeedTracker.shared.save()
        }
    }

    /// updateSearchResults（PGO 签名确证）。
    private func updateSearchResults(
        from snapshot: [SearchResultBook],
        currentSourceUrl: String?
    ) {
        var output: [Book] = []
        var seen = Set<String>()
        for result in snapshot {
            for candidate in result.sources {
                guard Self.isChangeSourceMatch(
                    candidate,
                    targetName: book.name,
                    targetAuthor: book.author ?? "") else { continue }
                guard seen.insert(candidate.id).inserted else { continue }
                output.append(candidate)
            }
        }
        searchResults = output.sorted {
            sourceName(for: $0) < sourceName(for: $1)
        }
        _ = currentSourceUrl
    }

    /// stopCurrentSearch（PGO 签名确证）。
    private func stopCurrentSearch(updateUI: Bool) {
        shouldStopSearch = true
        searchTask?.cancel()
        searchTask = nil
        if updateUI {
            isSearching = false
        }
    }

    /// selectSource（PGO 签名确证）。
    private func selectSource(_ target: Book) {
        guard !isChanging else { return }
        isChanging = true
        let selected = ChangeSourceCacheIdentity.selectedBook(
            target, preservingIdentityFrom: book)
        onSourceChanged(selected)
        isChanging = false
        dismiss()
    }

    /// isCurrentSource（PGO 签名确证）。
    private func isCurrentSource(_ candidate: Book) -> Bool {
        (candidate.bookSourceUrl ?? "") == (book.bookSourceUrl ?? "")
    }

    private func sourceName(for candidate: Book) -> String {
        let url = candidate.bookSourceUrl ?? ""
        return sourceNameCache[url] ?? (url.isEmpty ? "未知来源" : url)
    }

    // MARK: - 静态匹配/排序

    /// static isSearchableChangeSource（PGO 签名确证）。
    static func isSearchableChangeSource(_ source: BookSource) -> Bool {
        source.enabled
            && !source.ruleSearch.bookList.isEmpty
            && !(source.searchUrl ?? "").isEmpty
    }

    /// static isChangeSourceMatch（PGO 签名确证）。
    static func isChangeSourceMatch(
        _ candidate: Book, targetName: String, targetAuthor: String
    ) -> Bool {
        let name = candidate.name.trimmingCharacters(in: .whitespaces)
        guard !targetName.isEmpty else { return true }
        let nameMatched = name.localizedCaseInsensitiveContains(targetName)
            || targetName.localizedCaseInsensitiveContains(name)
        guard !targetAuthor.isEmpty else { return nameMatched }
        let author = (candidate.author ?? "")
            .trimmingCharacters(in: .whitespaces)
        let authorMatched = author.isEmpty
            || author.localizedCaseInsensitiveContains(targetAuthor)
            || targetAuthor.localizedCaseInsensitiveContains(author)
        return nameMatched && authorMatched
    }

    /// static matchingChangeSources（PGO 签名确证）。
    static func matchingChangeSources(
        from results: [SearchResultBook],
        targetName: String,
        targetAuthor: String
    ) -> [Book] {
        var output: [Book] = []
        var seen = Set<String>()
        for result in results {
            for candidate in result.sources {
                guard isChangeSourceMatch(
                    candidate, targetName: targetName,
                    targetAuthor: targetAuthor) else { continue }
                guard seen.insert(candidate.id).inserted else { continue }
                output.append(candidate)
            }
        }
        return output
    }

    /// static sortedChangeSources（PGO 签名确证）：速度优先、启用优先。
    static func sortedChangeSources(
        _ sources: [BookSource],
        speedSnapshot: [String: Double]
    ) -> [BookSource] {
        sources.sorted { lhs, rhs in
            let lSpeed = speedSnapshot[lhs.bookSourceUrl] ?? .infinity
            let rSpeed = speedSnapshot[rhs.bookSourceUrl] ?? .infinity
            if lSpeed != rSpeed { return lSpeed < rSpeed }
            if lhs.enabled != rhs.enabled { return lhs.enabled }
            return lhs.bookSourceName < rhs.bookSourceName
        }
    }

    /// static sourceSpeed（PGO 签名确证）。
    static func sourceSpeed(
        _ source: BookSource, speedSnapshot: [String: Double]
    ) -> Double {
        speedSnapshot[source.bookSourceUrl] ?? .infinity
    }

    /// static saveChangeSearchSpeedRecords（PGO 签名确证）。
    static func saveChangeSearchSpeedRecords(
        _ records: [(sourceUrl: String, time: Double)]
    ) {
        for record in records {
            SourceSpeedTracker.shared.record(
                sourceUrl: record.sourceUrl, time: record.time)
        }
        SourceSpeedTracker.shared.save()
    }

    /// 单源搜索（SearchViewModel.searchSingleSource 复用域）。
    private static func searchOneSource(
        _ source: BookSource, keyword: String
    ) async -> (books: [Book], sourceUrl: String, time: Double)? {
        let started = CFAbsoluteTimeGetCurrent()
        do {
            let books = try await SearchViewModel.searchSingleSource(
                source: source, keyword: keyword, page: 1)
            return (
                books, source.bookSourceUrl,
                CFAbsoluteTimeGetCurrent() - started)
        } catch {
            Logger.log(
                "[changeSource] source=\(source.bookSourceName)"
                    + " error=\(error.localizedDescription)",
                level: .warning)
            return (
                [], source.bookSourceUrl,
                CFAbsoluteTimeGetCurrent() - started)
        }
    }
}

/// 换源候选行（类型树 L9216-9223）。
struct SourceOptionRow: View {

    let book: Book
    let isCurrentSource: Bool
    let sourceName: String
    var sourceMode: StorageKind
    let isChanging: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 4.0) {
                HStack(spacing: 6.0) {
                    Text(book.name)
                        .appThemeText(.body)
                        .lineLimit(1)
                    if isCurrentSource {
                        Text("当前")
                            .appThemeText(.caption, opacity: 0.6)
                    }
                    Spacer()
                    if isChanging {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                HStack(spacing: 6.0) {
                    Text(sourceName)
                        .appThemeText(.caption, opacity: 0.7)
                    Text(sourceMode.rawValue)
                        .appThemeText(.caption, opacity: 0.5)
                    Spacer()
                    if let author = book.author, !author.isEmpty {
                        Text(author)
                            .appThemeText(.caption, opacity: 0.5)
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isChanging)
    }
}
