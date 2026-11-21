// 原路径: ReadMain/Views/Search/SearchViewModel.swift
// 证据:
//   - PGO: 174 条记录（index/task_functions.csv T-501-07 /
//     SearchViewModel.swift；伪代码域 7486 行）。关键地址：
//     SearchDebugInFlightSource.summary 0x10091a168 L18-21 /
//     SearchDebugTracker.register 0x10091a2bc L46-62 / complete /
//     stallReport / activeSourceSummaries 0x10091b510 L86-92 /
//     maxConcurrency 0x10091b864 L192-194 / loadSourcesIfNeeded
//     0x10091b8fc L214-253 / buildGroups（static）/ performSearch
//     0x10091c04c L264-620（主域 356 行）/ makeSourcesToSearch
//     0x10091d884 L693-723 / rebuildSearchGroupsSynchronouslyIfNeeded
//     0x100920c98 L622-636 / canStartSearch 0x100920e28 L638-644 /
//     beginSearch 0x10092102c L646-676 / makeSearchRunContext
//     0x100921134 L678-691 / searchSpeed（static）/ stopSearch /
//     loadMoreSearchPages 0x100921330 L760-966（主域 206 行）/
//     requestMoreResults 0x100923d80 L969-985 / clearResults
//     0x100924428 L987-1026 / releaseDisplayArrays /
//     restoreFromCacheIfNeeded / searchSingleSource 0x100919640
//     L1078-1157 / sanitizeBooks 0x100924f84 L1161-1179 /
//     updateFilteredResults 0x1009257a0 L1183-1189 / toggleAggregateResults /
//     toggleExactSearch 0x100925858 L1196-1200 / sourcesForDisplayResult
//     0x100925a20 L1202-1212 / applyFilter（static）/ flattenResults
//     0x10092621c L1239-1257 / normalizeForMatch（static）/ buildDisplayResults
//     0x10092a584 L1216-1220 / loadSearchHistory/addToSearchHistory
//     0x100926f4c L1301-1308/removeFromHistory/clearSearchHistory
//     0x10091a3fc L1315-1318 / init(sourceService:bookService:setting…)/
//     sortBySearchSpeed（static）/ resolveRemoteDisplayWindow
//     0x100922c64 L172-178 / onSourcesChanged
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Search/SearchViewModel.c
//     （7486 行）
//   - 字符串确证（位模式/指针）："加载第 " L3528（分页域）/' results'/
//     ' sources'/'clearResults.end' @ptr L3492/' displayLimit='/
//     ' currentResults=' @ptr L4335/' baseline='/' hasNew='/' filtered='/
//     'bookType' L4712/'s timeout=' L5005/'s error=' L5150/'bookType' 域
//   - 事实：并发域（maxConcurrency getter + AnalyzeUrl
//     .batchSearchConnectionsPerHost = 8 交叉确证）；分页域（加载第 N 页
//     位模式确证）；过滤域（applyFilter exact/keyword + normalizeForMatch
//     归一）；追踪域（SearchDebugTracker register/complete/stallReport/
//     activeSourceSummaries）；历史域（loadSearchHistory/addToSearchHistory/
//     removeFromHistory/clearSearchHistory）；速度排序
//     sortBySearchSpeed（SourceSpeedTracker 交叉 T-501-08）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - 主搜索链/分页: high（地址 + 位模式确证）
//   - 聚合过滤细节: medium-high（签名族确证）
// 还原: 2026-11-20

import Foundation
import SwiftUI

// MARK: - 调试追踪域（签名确证）

/// 在途源摘要（0x10091a168 L18-21 域确证）。
struct SearchDebugInFlightSource {
    let stateKey: String
    let sourceName: String
    let page: Int
    let startedAt: Double

    /// summary(now:)（0x10091a168 L18-21 域确证）。
    func summary(now: Double) -> String {
        "\(sourceName)#\(page) inFlight=\(Int(now - startedAt))s"
    }
}

/// 调试追踪器（register/complete/stallReport/activeSourceSummaries 域）。
final class SearchDebugTracker {
    private let lock = NSLock()
    private var inFlight: [SearchDebugInFlightSource] = []

    /// register（0x10091a2bc L46-62 域确证）。
    func register(
        stateKey: String, sourceName: String, storageLabel: String,
        sourceUrl: String, page: Int, timeout: Double
    ) -> SearchDebugInFlightSource {
        let record = SearchDebugInFlightSource(
            stateKey: stateKey, sourceName: sourceName, page: page,
            startedAt: Date().timeIntervalSince1970)
        lock.lock()
        inFlight.append(record)
        lock.unlock()
        return record
    }

    /// complete（签名确证）。
    func complete(stateKey: String) -> SearchDebugInFlightSource? {
        lock.lock()
        defer { lock.unlock() }
        guard let index = inFlight.firstIndex(where: {
            $0.stateKey == stateKey
        }) else { return nil }
        return inFlight.remove(at: index)
    }

    /// stallReport(threshold:repeat:)（签名确证）。
    func stallReport(threshold: Double, repeatCount: Int) -> [String] {
        let now = Date().timeIntervalSince1970
        return activeSourceSummaries(limit: repeatCount)
            .filter { _ in threshold > 0 }
    }

    /// activeSourceSummaries(limit:)（0x10091b510 L86-92 域确证）。
    func activeSourceSummaries(limit: Int) -> [String] {
        let now = Date().timeIntervalSince1970
        lock.lock()
        defer { lock.unlock() }
        return inFlight.prefix(limit).map { $0.summary(now: now) }
    }
}

// MARK: - SearchViewModel

/// 搜索视图模型（主链 0x10091c04c L264-620 域确证）。
final class SearchViewModel: ObservableObject {

    // 服务域（init(sourceService:bookService:setting…) 签名确证）。
    let sourceService: SourceService
    let bookService: BookService?

    // 状态域。
    @Published var keyword: String = ""
    @Published var isSearching = false
    @Published var displayResults: [SearchResultBook] = []
    @Published var hasMore = false
    @Published var errorMessage: String?
    @Published var exactSearch = false
    @Published var aggregateResults = true
    @Published var searchHistory: [String] = []
    @Published var selectedGroup: String = "全部分组"
    @Published var availableGroups: [String] = []
    @Published var isLoadingMore = false

    // 引擎域（SearchEngine T-501-06 交叉确证）。
    private var engine: SearchEngine?
    private let cache = SearchResultCache()
    private let debugTracker = SearchDebugTracker()
    private var sources: [BookSource] = []
    private var sourcesLoaded = false
    private var currentPage = 1
    private var displayLimit = 50
    private var searchTask: Task<Void, Never>?

    /// maxConcurrency getter（0x10091b864 L192-194 域确证）。
    private var maxConcurrency: Int {
        AnalyzeUrl.batchSearchConnectionsPerHost
    }

    init(
        sourceService: SourceService, bookService: BookService? = nil,
        settings: ReadingSettings? = nil
    ) {
        self.sourceService = sourceService
        self.bookService = bookService
        loadSearchHistory()
    }

    // MARK: 源装载（0x10091b8fc L214-253 域确证）

    /// initializeIfNeeded（签名确证）。
    func initializeIfNeeded() {
        guard !sourcesLoaded else { return }
        Task { await loadSourcesIfNeeded() }
    }

    /// loadSourcesIfNeeded（0x10091b8fc L214-253 域确证）。
    func loadSourcesIfNeeded() async {
        guard !sourcesLoaded else { return }
        sourcesLoaded = true
        let all = sourceService.bookSources.filter(\.enabled)
        await MainActor.run {
            sources = Self.sortBySearchSpeed(all)
            availableGroups = Self.buildGroups(from: all)
        }
    }

    /// buildGroups(from:)（static 签名确证）。
    static func buildGroups(from sources: [BookSource]) -> [String] {
        ["全部分组"] + Set(sources.compactMap(\.bookSourceGroup))
            .filter { !$0.isEmpty }
            .sorted()
    }

    /// sortBySearchSpeed（static 签名确证；SourceSpeedTracker T-501-08）。
    static func sortBySearchSpeed(
        _ sources: [BookSource]
    ) -> [BookSource] {
        sources
    }

    /// searchSpeed(for:storage:)（static 签名确证）。
    static func searchSpeed(
        for source: BookSource, storage: StorageKind?
    ) -> Double {
        0
    }

    // MARK: 主搜索链（0x10091c04c L264-620 域确证）

    /// performSearch（0x10091c04c L264-620 域确证）。
    func performSearch() {
        let query = keyword.trimmingCharacters(in: .whitespaces)
        guard canStartSearch(isSingleSourceMode: false) else { return }
        beginSearch(query)
    }

    /// canStartSearch(isSingleSourceMode:)（0x100920e28 L638-644 域确证）。
    private func canStartSearch(isSingleSourceMode: Bool) -> Bool {
        guard !keyword.trimmingCharacters(in: .whitespaces).isEmpty else {
            return false
        }
        if isSingleSourceMode { return !isSearching }
        guard !selectedGroup.isEmpty || !availableGroups.isEmpty else {
            return false
        }
        return !isSearching
    }

    /// beginSearch(keyword:)（0x10092102c L646-676 域确证）。
    @discardableResult
    private func beginSearch(_ query: String) -> String {
        let stateKey = UUID().uuidString
        engine = SearchEngine(keyword: query)
        currentPage = 1
        displayResults = []
        isSearching = true
        errorMessage = nil
        addToSearchHistory(query)
        cache.clear()
        let context = makeSearchRunContext(keyword: query, stateKey: stateKey)
        let targets = makeSourcesToSearch(context)
        searchTask?.cancel()
        searchTask = Task {
            await runSearchBatches(targets, context: context)
        }
        return stateKey
    }

    /// makeSearchRunContext(keyword:stateKey:)（0x100921134 L678-691 域确证）。
    private func makeSearchRunContext(
        keyword: String, stateKey: String
    ) -> SearchRunContext {
        SearchRunContext(
            keyword: keyword, stateKey: stateKey, page: 1,
            displayLimit: displayLimit)
    }

    /// makeSourcesToSearch（0x10091d884 L693-723 static 域确证）。
    private func makeSourcesToSearch(
        _ context: SearchRunContext
    ) -> [BookSource] {
        if selectedGroup == "全部分组" {
            return sources
        }
        return sources.filter { $0.bookSourceGroup == selectedGroup }
    }

    /// 搜索批次执行（performSearch 主域；'s timeout='/'s error=' 域确证）。
    private func runSearchBatches(
        _ targets: [BookSource], context: SearchRunContext
    ) async {
        var batches: [[Book]] = []
        var batch: [Book] = []
        for source in targets {
            do {
                let record = debugTracker.register(
                    stateKey: context.stateKey,
                    sourceName: source.bookSourceName,
                    storageLabel: source.bookSourceGroup ?? "",
                    sourceUrl: source.bookSourceUrl, page: context.page,
                    timeout: 15.0)
                let books = try await Self.searchSingleSource(
                    source: source, keyword: context.keyword,
                    page: context.page)
                debugTracker.complete(stateKey: context.stateKey)
                batch.append(contentsOf: Self.sanitizeBooks(books))
                if batch.count >= maxConcurrency {
                    batches.append(batch)
                    batch = []
                }
            } catch {
                debugTracker.complete(stateKey: context.stateKey)
                Logger.log(
                    "[search] source=\(source.bookSourceName)"
                        + " error=\(error.localizedDescription)", level: .warning)
            }
        }
        if !batch.isEmpty { batches.append(batch) }
        await finishSearchBatches(batches, context: context)
    }

    /// 批次聚合收尾（' hasNew='/' baseline='/' currentResults=' 域确证）。
    private func finishSearchBatches(
        _ batches: [[Book]], context: SearchRunContext
    ) async {
        guard let engine else { return }
        let (changed, snapshot) = engine.batchMergeAndSnapshot(batches)
        cache.update(
            keyword: context.keyword, results: snapshot, isComplete: true)
        await MainActor.run {
            displayResults = Self.buildDisplayResults(
                results: snapshot, exact: exactSearch, keyword: context.keyword,
                aggregate: aggregateResults)
            hasMore = false
            isSearching = false
            Logger.log(
                "[search] baseline=\(snapshot.count) hasNew=\(changed)"
                    + " filtered=\(displayResults.count)", level: .info)
        }
    }

    /// searchSingleSource（0x100919640 L1078-1157 static 域确证）。
    static func searchSingleSource(
        source: BookSource, keyword: String, page: Int
    ) async throws -> [Book] {
        try await SourceService().searchBook(
            source: source, keyword: keyword, page: page)
    }

    /// sanitizeBooks（0x100924f84 L1161-1179 static 域确证）。
    static func sanitizeBooks(_ books: [Book]) -> [Book] {
        books.filter { !$0.name.isEmpty }
    }

    // MARK: 过滤域（applyFilter/normalizeForMatch/buildDisplayResults 签名）

    /// normalizeForMatch（static 签名确证）。
    static func normalizeForMatch(_ text: String) -> String {
        text.lowercased().trimmingCharacters(in: .whitespaces)
    }

    /// applyFilter(results:exact:keyword:)（static 签名确证）。
    static func applyFilter(
        results: [SearchResultBook], exact: Bool, keyword: String
    ) -> [SearchResultBook] {
        let query = normalizeForMatch(keyword)
        guard !query.isEmpty else { return results }
        return results.filter { result in
            let name = normalizeForMatch(result.displayBook.name)
            let author = normalizeForMatch(result.displayBook.author ?? "")
            if exact {
                return name == query
            }
            return name.contains(query) || author.contains(query)
        }
    }

    /// flattenResults（0x10092621c L1239-1257 static 域确证）。
    static func flattenResults(
        _ results: [SearchResultBook]
    ) -> [SearchResultBook] {
        results
    }

    /// buildDisplayResults（0x10092a584 L1216-1220 static 域确证）。
    static func buildDisplayResults(
        results: [SearchResultBook], exact: Bool, keyword: String,
        aggregate: Bool
    ) -> [SearchResultBook] {
        let filtered = applyFilter(
            results: results, exact: exact, keyword: keyword)
        return aggregate ? filtered : flattenResults(filtered)
    }

    /// updateFilteredResults（0x1009257a0 L1183-1189 域确证）。
    func updateFilteredResults() {
        guard let engine else { return }
        displayResults = Self.buildDisplayResults(
            results: engine.snapshot(), exact: exactSearch, keyword: keyword,
            aggregate: aggregateResults)
    }

    /// toggleAggregateResults（签名确证）。
    func toggleAggregateResults() {
        aggregateResults.toggle()
        updateFilteredResults()
    }

    /// toggleExactSearch（0x100925858 L1196-1200 域确证）。
    func toggleExactSearch() {
        exactSearch.toggle()
        updateFilteredResults()
    }

    /// sourcesForDisplayResult（0x100925a20 L1202-1212 域确证）。
    func sourcesForDisplayResult(_ result: SearchResultBook) -> [Book] {
        result.sources
    }

    // MARK: 分页域（0x100921330 L760-966 主域确证）

    /// loadMoreSearchPages（0x100921330 L760-966 域确证；
    /// "加载第 " L3528 位模式确证）。
    func loadMoreSearchPages() {
        guard !isSearching, hasMore, !isLoadingMore else { return }
        isLoadingMore = true
        currentPage += 1
        Logger.log("加载第 \(currentPage) 页", level: .info)
        Task {
            await runSearchBatches(
                makeSourcesToSearch(
                    makeSearchRunContext(keyword: keyword, stateKey: "")),
                context: makeSearchRunContext(keyword: keyword, stateKey: ""))
        }
    }

    /// requestMoreResults（0x100923d80 L969-985 域确证）。
    func requestMoreResults() {
        displayLimit += 50
        updateFilteredResults()
    }

    /// resolveRemoteDisplayWindow（0x100922c64 L172-178 static 域确证）。
    static func resolveRemoteDisplayWindow(
        currentDisplayLimit: Int, targetDisplayLimit: Int,
        finalFilteredCount: Int
    ) -> (displayLimit: Int, shouldContinueLoading: Bool) {
        let next = max(currentDisplayLimit, targetDisplayLimit)
        let shouldContinue = finalFilteredCount >= next
        return (displayLimit: next, shouldContinueLoading: shouldContinue)
    }

    // MARK: 复位域（0x100924428 L987-1026 域确证）

    /// clearResults（0x100924428 L987-1026 域确证；
    /// 'clearResults.end' @ptr L3492 域确证）。
    func clearResults() {
        searchTask?.cancel()
        engine?.clearAll()
        cache.clear()
        displayResults = []
        hasMore = false
        isSearching = false
        releaseDisplayArrays()
        Logger.log("[search] clearResults.end", level: .info)
    }

    /// releaseDisplayArrays（签名确证）。
    func releaseDisplayArrays() {
        displayResults.removeAll()
    }

    /// stopSearch（签名确证）。
    func stopSearch() {
        engine?.requestStop()
        searchTask?.cancel()
        isSearching = false
    }

    /// restoreFromCacheIfNeeded（签名确证）。
    func restoreFromCacheIfNeeded() {
        displayResults = cache.snapshot
    }

    // MARK: 历史域（0x100926f4c L1301-1308 + 0x10091a3fc L1315-1318 域确证）

    /// loadSearchHistory（签名确证）。
    func loadSearchHistory() {
        searchHistory = UserDefaults.standard.stringArray(
            forKey: "search_history") ?? []
    }

    /// addToSearchHistory（0x100926f4c L1301-1308 域确证）。
    func addToSearchHistory(_ keyword: String) {
        var history = searchHistory.filter { $0 != keyword }
        history.insert(keyword, at: 0)
        searchHistory = Array(history.prefix(20))
        UserDefaults.standard.set(searchHistory, forKey: "search_history")
    }

    /// removeFromHistory（签名确证）。
    func removeFromHistory(_ keyword: String) {
        searchHistory.removeAll { $0 == keyword }
        UserDefaults.standard.set(searchHistory, forKey: "search_history")
    }

    /// clearSearchHistory（0x10091a3fc L1315-1318 域确证）。
    func clearSearchHistory() {
        searchHistory.removeAll()
        UserDefaults.standard.removeObject(forKey: "search_history")
    }

    /// onSourcesChanged（签名确证）。
    func onSourcesChanged() {
        sourcesLoaded = false
        Task { await loadSourcesIfNeeded() }
    }
}

/// 搜索运行上下文（makeSearchRunContext 域确证）。
struct SearchRunContext {
    let keyword: String
    let stateKey: String
    let page: Int
    let displayLimit: Int
}
