// 原路径: ReadMain/Views/Explore/ExploreSourceDetailView.swift
// 分类解析、分页和生命周期从原文件机械拆出，行为与桩继续计入原归属。
import SwiftUI

extension ExploreSourceDetailView {
    // MARK: 状态 getter（签名确证）

    /// filterSelections getter（签名确证）。
    var filterSelections: [String: String] {
        filterValues
    }

    /// selectFilters getter（签名确证）。
    var selectFilters: [ExploreCategory] {
        categoryGroups.flatMap(\.categories)
            .filter { !$0.isActionControl }
    }

    /// ensureFilterEngine（签名确证）。
    func ensureFilterEngine() -> ExploreFilterEngine {
        if let engine = filterEngine { return engine }
        let engine = ExploreFilterEngine(
            source: source, sourceService: sourceService)
        let split = _splitExploreCategories(
            selectFilters + actionControls)
        engine.applyControls(
            filters: split.filters, controls: split.actionControls)
        filterEngine = engine
        return engine
    }

    // MARK: 追踪域

    /// nextExploreTraceId（签名确证）。
    func nextExploreTraceId() -> Int {
        traceCounter += 1
        return traceCounter
    }

    /// logExploreTrace（签名确证；"[EXPLORE-TRACE] " @ptr L1323 域确证）。
    func logExploreTrace(_ event: String, _ detail: String) {
        Logger.log(
            "[EXPLORE-TRACE] #\(nextExploreTraceId()) \(event) \(detail)",
            level: .info)
    }

    // MARK: 分类解析

    /// parseCategories(forceRefresh:re…)（签名域确证）。
    func parseCategories(
        forceRefresh: Bool, reparseCategories: Bool
    ) async {
        guard !parseTaskActive else {
            logExploreTrace("parse.skip", "cause=parseTaskActive")
            return
        }
        parseTaskActive = true
        defer { parseTaskActive = false }
        // 列表缓存命中域（parse.listCacheHit 确证）。
        if !forceRefresh, !reparseCategories,
           let cached = ExploreListCacheStore.entry(
                for: source, ttl: 1800) {
            applyCategories(
                categories: cached.categories, resetFilters: false,
                action: "parse.listCacheHit")
            return
        }
        if source.resolvedExploreUrl.isEmpty {
            logExploreTrace("parse.noExploreUrl", "")
            await MainActor.run {
                errorMessage = "无法解析分类"
            }
            return
        }
        do {
            var categories: [(title: String, url: String)] = []
            if forceRefresh {
                // 远端分类域（RemoteBackendService.getExploreUrl 真身确证）。
                categories = try await RemoteBackendService.shared
                    .getExploreUrl(bookSourceUrl: source.bookSourceUrl, need: true)
            }
            if categories.isEmpty {
                // 本地规则域（exploreUrl 规则行解析，fetchBody 私有域不直调）。
                categories = parseExploreRuleCategories(
                    from: "", rule: _configuredExploreAnalyzeRule(
                        source: source, infoValues: filterValues))
            }
            await MainActor.run {
                applyCategories(
                    categories: categories, resetFilters: forceRefresh,
                    action: forceRefresh
                        ? "parse.remoteDone" : "parse.localDone")
            }
            ExploreListCacheStore.put(
                ExploreListCacheEntry(categories: categories), for: source)
        } catch {
            logExploreTrace("parse.cancelled", " reason=\(error.localizedDescription)")
            await MainActor.run {
                errorMessage = "获取分类失败: \(error.localizedDescription)"
            }
        }
    }

    /// 规则分类解析（"<explore-info-map-data>" 桥域确证）。
    func parseExploreRuleCategories(
        from body: String, rule: AnalyzeRule?
    ) -> [(title: String, url: String)] {
        guard let rule else { return [] }
        var categories: [(title: String, url: String)] = []
        // exploreUrl 规则列表段（" groups, " 域确证）。
        for category in source.resolvedExploreUrl
            .split(separator: "\n") {
            let segments = category
                .trimmingCharacters(in: .whitespaces)
                .components(separatedBy: "::")
            guard segments.count == 2 else { continue }
            categories.append((title: segments[0], url: segments[1]))
        }
        _ = body
        return categories
    }

    /// applyCategories（"applyCategories" trace 键位模式确证；
    /// " filters="/" controls="/" groups="/" resetFilters=" 域）。
    func applyCategories(
        categories: [(title: String, url: String)], resetFilters: Bool,
        action: String
    ) {
        let split = _splitExploreCategories(
            categories.map {
                ExploreCategory(title: $0.title, url: $0.url, type: nil)
            })
        categoryGroups = split.groups
        actionControls = split.actionControls
        if resetFilters {
            filterValues = [:]
        }
        if let engine = filterEngine {
            engine.applyControls(
                filters: split.filters, controls: split.actionControls)
        }
        logExploreTrace(
            action,
            " filters=\(split.filters.count) controls=\(split.actionControls.count)"
                + " groups=\(split.groups.count)"
                + " resetFilters=\(resetFilters)")
        if selectedCategory == nil {
            selectCategory(split.filters.first, reset: true)
        }
    }

    /// selectCategory(_:r…)（"tap.category"/"select.ignoredSame"/
    /// ", reset=" 域确证）。
    func selectCategory(
        _ category: ExploreCategory?, reset: Bool
    ) {
        guard let category else { return }
        if category.id == selectedCategory?.id && !reset {
            logExploreTrace("select.ignoredSame", "")
            return
        }
        selectedCategory = category
        filterEngine?.onFilterSelected(
            filter: category, value: category.url)
        logExploreTrace("tap.category", " category={\(category.title)}, reset=\(reset)")
        Task {
            await loadBooks(reset: true)
        }
    }

    // MARK: 列表加载

    /// loadBooks（"[filter-dbg] loadBooks called: " @ptr L8799 +
    /// load.start/skip/finish/fail + "[EXPLORE-LIST-DIAG] page=" 域确证）。
    func loadBooks(reset: Bool) async {
        guard !loadTaskActive else {
            logExploreTrace("load.skip", " cause=loadTaskActive")
            return
        }
        loadTaskActive = true
        isLoading = true
        defer {
            loadTaskActive = false
            isLoading = false
        }
        if reset {
            currentPage = 1
            books = []
        }
        let exploreUrl = selectedCategory?.url ?? ""
        logExploreTrace("load.start", "page=\(currentPage)")
        do {
            let fetched = try await sourceService.exploreBook(
                source: source, exploreUrl: exploreUrl, page: currentPage)
            await MainActor.run {
                if reset {
                    books = fetched
                } else {
                    books.append(contentsOf: fetched)
                }
                hasMore = !fetched.isEmpty
                logExploreTrace(
                    "load.finish", " books loaded=\(fetched.count)")
                Logger.log(
                    "[EXPLORE-LIST-DIAG] page=\(currentPage)"
                        + " books=\(fetched.count)", level: .info)
            }
        } catch {
            await MainActor.run {
                errorMessage = "书源请求解析失败"
                logExploreTrace("load.fail", " cause=\(error.localizedDescription)")
            }
        }
    }

    /// loadMore（"loadMore.skip"/" cause=noMore"/"footer.onAppear" 域确证）。
    func loadMore() {
        guard hasMore, !isLoading else {
            logExploreTrace(
                "loadMore.skip",
                isLoading ? " cause=isLoading" : " cause=noMore")
            return
        }
        currentPage += 1
        logExploreTrace("footer.onAppear", "page=\(currentPage)")
        Task {
            await loadBooks(reset: false)
        }
    }

    // MARK: 生命周期（签名域确证）

    /// handleViewAppear（"view.onAppear" 域确证）。
    func handleViewAppear() {
        Task {
            if categoryGroups.isEmpty {
                await parseCategories(
                    forceRefresh: false, reparseCategories: false)
            }
        }
    }

    /// handleViewDisappear（"onDisappear" 域确证；triggersParserCleanup=0）。
    func handleViewDisappear() {
        // triggersParserCleanup=0（解析清理域确证）。
    }

    /// handleRefreshExploreNotification（"notification.refreshExplore" 域）。
    func handleRefreshExploreNotification() {
        Task {
            await parseCategories(
                forceRefresh: true, reparseCategories: false)
        }
    }

    /// handleStartBrowserNotification（"browser.present.now" 域确证）。
    func handleStartBrowserNotification(_ notification: Notification) {
        guard
            let request = notification.userInfo?["request"]
                as? RemoteBrowserRequest
        else { return }
        browserRequest = request
        showBrowser = true
        logExploreTrace("browser.present.now", request.url.absoluteString)
    }

    func handleReadBookFromDetail(_ book: Book) {
        pendingReadBook = book
        selectedBook = nil
    }
}
