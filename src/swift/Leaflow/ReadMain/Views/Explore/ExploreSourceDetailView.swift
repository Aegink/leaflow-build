// 原路径: ReadMain/Views/Explore/ExploreSourceDetailView.swift
// 证据:
//   - PGO: 277 条记录（index/task_functions.csv T-501-03 /
//     ExploreSourceDetailView.swift；伪代码域 15642 行）。关键域：
//     ExploreInfoMapStore（static update(_:for:persist:)/cacheKey(for:)/
//     values(for:)/decode(String)）/_configuredExploreAnalyzeRule/
//     _exploreInfoSnapshot(from: AnalyzeRule)/ExploreOpenRoute.displayTitle/
//     ExploreSearchRoute.displayTitle/_exploreCategoryApplicationAction
//     (selectedCategory:categoryGroups:isFilterRefresh:skipReloadIfSame:)/
//     _exploreBrowserDismissAction(presentationContext:)/describe 助手族/
//     filterSelections/selectFilters/actionControls/pendingFilterRefresh
//     getter / ensureFilterEngine/parseCategories(forceRefresh:re…)/
//     selectCategory(_:r…)/nextExploreTraceId/logExploreTrace/body/
//     refreshExplore/handleViewAppear/handleViewDisappear/
//     handleRefreshExploreNotification/handleStartBrowserNotification
//   - CovMap: L 域映射（index/restoration_status.csv）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Explore/
//     ExploreSourceDetailView.c（15642 行）
//   - JS 桥标记确证（指针）："__exploreInfoMapData" + "<explore-info-map-data>"
//     + "<explore-info-map-snapshot>" + "<explore-info-map-save-flag>" +
//     "put(k, v); }\n        };\n    }" + "     }\n    }\n})();"（探索信息表
//     JS 注入域确证）；追踪串域：'[EXPLORE-TRACE] ' @ptr L1323 /
//     "[filter-dbg] loadBooks called: " @ptr L8799 / "[filter-dbg] loadBooks
//     result: " @ptr L9305 / "[EXPLORE-LIST-DIAG] page=" @ptr L9641；
//     trace 键位模式：parse.remoteDone/parse.localDone/parse.cancelled/
//     parse.noExploreUrl/parse.listCacheHit/reparseCategories/applyCategories/
//     tap.category/select.ignoredSame/load.start/load.skip/load.finish/
//     load.fail/load.suc/loadMore.skip/footer.onAppear/retry.initial/
//     retry.loadMore/contentSection.retry/view.onAppear/pullToRefresh/
//     browser.present.now/login.dismiss.refresh/notification.refreshExplore；
//     状态键域："infoMap_"（L578）/" sourceUrl="/" author="/" bookId="/
//     " bookUrl="/" storage=" 诊断域；" 无法解析分类" @ptr L4355/"该分类下
//     暂无书籍" @ptr L4940/"选择分类" L4946/"使用上方操作" @ptr L4964 域/
//     "没有更多了" L5213/"暂无内容" L5422/"点击重试" L6197/"书源请求解析
//     失败" @ptr L10665/"没有搜索结果" @ptr L13440/"[发现] JS exploreUrl
//     异常: " @ptr L2071；参数域 " reason="/" forceRefresh="/" infoKeys="
//     " resetFilters="/" skipReloadIfSame="/" action="/" category={"
//     " selected={"/" isLoading="/" hasMore="/" appended="/" tCount="
//   - 事实：parseCategories 缓存命中域（parse.listCacheHit）+ 双任务门
//     （loadTaskActive/parseTaskActive @ptr 域）+ onDisappear 域；
//     loadBooks 追踪链（load.start→load.finish/fail + appended 计数）；
//     loadMore 分页门（cause=noMore/cause=isLoading）；
//     triggersParserCleanup=0 域（解析清理域确证）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - 解析主链/追踪域: high（trace 键位模式 + 域串确证）
//   - JS 信息表桥: high（三标记指针确证）
//   - 视图树形状: medium（结构性还原；布局待真机）
// 还原: 2026-11-20

import SwiftUI
import WebKit

// MARK: - ExploreInfoMapStore

/// 发现信息表持久化（static 四件签名确证；"infoMap_" L578 域确证）。
enum ExploreInfoMapStore {

    /// cacheKey(for:)（签名确证）。
    private static func cacheKey(for source: BookSource) -> String {
        "infoMap_\(source.bookSourceUrl)"
    }

    /// values(for:)（签名确证）。
    static func values(for source: BookSource) -> [String: String] {
        guard
            let json = UserDefaults.standard.string(
                forKey: cacheKey(for: source)),
            let map = decode(json)
        else { return [:] }
        return map
    }

    /// update(_:for:persist:)（签名确证）。
    static func update(
        _ values: [String: String], for source: BookSource, persist: Bool
    ) {
        guard persist else { return }
        guard
            let data = try? JSONSerialization.data(
                withJSONObject: values, options: [.sortedKeys]),
            let json = String(data: data, encoding: .utf8)
        else { return }
        UserDefaults.standard.set(json, forKey: cacheKey(for: source))
    }

    /// decode(String)（签名确证）。
    static func decode(_ json: String) -> [String: String]? {
        guard
            let data = json.data(using: .utf8),
            let object = try? JSONSerialization.jsonObject(with: data),
            let map = object as? [String: String]
        else { return nil }
        return map
    }
}

// MARK: - 信息表快照

/// 信息表快照（ExploreInfoMapSnapshot 域确证）。
struct ExploreInfoMapSnapshot {
    let values: [String: String]
    let needsSave: Bool
}

/// 快照读取（_exploreInfoSnapshot(from:) 签名确证；
/// "__exploreInfoMapData" 指针域确证，getVariable 真身确证）。
func _exploreInfoSnapshot(from rule: AnalyzeRule) -> ExploreInfoMapSnapshot {
    var values: [String: String] = [:]
    if let json = rule.getVariable("__exploreInfoMapData") {
        values = ExploreInfoMapStore.decode(json) ?? [:]
    }
    let needsSave = rule.getVariable("<explore-info-map-save-flag>") == "1"
    return ExploreInfoMapSnapshot(values: values, needsSave: needsSave)
}

/// 规则装配（_configuredExploreAnalyzeRule 签名确证；
/// putVariable 真身确证）。
func _configuredExploreAnalyzeRule(
    source: BookSource?, infoValues: [String: String]
) -> AnalyzeRule? {
    guard let source else { return nil }
    let rule = AnalyzeRule()
    for (key, value) in infoValues {
        rule.putVariable(key, value: value)
    }
    return rule
}

// MARK: - 路由

/// 打开路由（displayTitle 签名确证）。
struct ExploreOpenRoute: Identifiable, Equatable {
    let url: String
    var id: String { url }

    var displayTitle: String { "浏览" }
}

/// 搜索路由（displayTitle 签名确证）。
struct ExploreSearchRoute: Identifiable, Equatable {
    let keyword: String
    let sourceUrl: String
    var id: String { keyword + "|" + sourceUrl }

    var displayTitle: String { "搜索" }
}

// MARK: - 分类应用动作

/// 分类应用动作（_ExploreCategoryApplicationAction 域确证）。
enum _ExploreCategoryApplicationAction: Equatable {
    case none
    case reload(reason: String)
    case replaceFilters([ExploreCategoryGroup], reset: Bool)
}

/// 浏览器关闭动作（_exploreBrowserDismissAction 签名确证）。
enum _ExploreBrowserDismissAction {
    case refresh
    case none
}

func _exploreBrowserDismissAction(
    presentationContext: JSBrowserPresentationContext
) -> _ExploreBrowserDismissAction {
    switch presentationContext {
    case .loginSheet:
        return .none
    case .readerSheet:
        return .refresh
    }
}

// MARK: - 诊断助手（describe 族签名确证）

func _describeExploreApplicationAction(
    _ action: _ExploreCategoryApplicationAction
) -> String {
    switch action {
    case .none: return "none"
    case .reload(let reason): return "reload(reason=\(reason))"
    case .replaceFilters(let groups, let reset):
        return "replaceFilters(groups=\(groups.count), reset=\(reset))"
    }
}

func _describeExploreInfoKeys(_ info: [String: String]) -> String {
    info.keys.sorted().joined(separator: ",")
}

func _describeExploreBook(_ book: Book) -> String {
    " author=\(book.author ?? "") bookUrl=\(book.bookUrl ?? "")"
        + " sourceUrl=\(book.bookSourceUrl ?? "")"
        + " storage=\(book.sourceStorageKind?.rawValue ?? "")"
}

// MARK: - ExploreSourceDetailView

/// 发现源详情页（分类 + 筛选 + 列表）。
struct ExploreSourceDetailView: View {

    let source: BookSource

    // 分类态（getter 签名确证）。
    @State private var categoryGroups: [ExploreCategoryGroup] = []
    @State private var actionControls: [ExploreCategory] = []
    @State private var selectedCategory: ExploreCategory?
    @State private var filterValues: [String: String] = [:]
    @State private var pendingFilterRefresh = false

    // 列表态。
    @State private var books: [Book] = []
    @State private var isLoading = false
    @State private var hasMore = true
    @State private var currentPage = 1
    @State private var errorMessage: String?

    // 引擎与任务门（ensureFilterEngine/loadTaskActive/parseTaskActive 域）。
    @State private var filterEngine: ExploreFilterEngine?
    @State private var parseTaskActive = false
    @State private var loadTaskActive = false
    @State private var traceCounter = 0
    @State private var showFilterSheet = false
    @State private var showBrowser = false
    @State private var browserRequest: RemoteBrowserRequest?
    @State private var openRoute: ExploreOpenRoute?
    @State private var searchRoute: ExploreSearchRoute?

    private let sourceService = SourceService()

    var body: some View {
        // body（签名域）：分类选择 + 列表 + 筛选面板 + 弹层。
        VStack(spacing: 0) {
            if categoryGroups.isEmpty && actionControls.isEmpty {
                emptyState
            } else {
                ExploreFilterBar(engine: ensureFilterEngine())
                bookList
            }
        }
        .navigationTitle(source.bookSourceName)
        .navigationBarTitleDisplayMode(.inline)
        .modifier(
            ExploreSourceDetailLifecycleModifier(
                onAppear: { handleViewAppear() },
                onDisappear: { handleViewDisappear() }))
        .modifier(
            ExploreSourceDetailPresentationsModifier(
                filterSheet: $showFilterSheet,
                browserRequest: $browserRequest,
                openRoute: $openRoute,
                searchRoute: $searchRoute,
                source: source))
        .onReceive(
            NotificationCenter.default.publisher(
                for: Notification.Name("notification.refreshExplore"))
        ) { _ in
            handleRefreshExploreNotification()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: Notification.Name("browser.present.now"))
        ) { notification in
            handleStartBrowserNotification(notification)
        }
    }

    // MARK: 状态 getter（签名确证）

    /// filterSelections getter（签名确证）。
    private var filterSelections: [String: String] {
        filterValues
    }

    /// selectFilters getter（签名确证）。
    private var selectFilters: [ExploreCategory] {
        categoryGroups.flatMap(\.categories)
            .filter { !$0.isActionControl }
    }

    /// ensureFilterEngine（签名确证）。
    private func ensureFilterEngine() -> ExploreFilterEngine {
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
    private func nextExploreTraceId() -> Int {
        traceCounter += 1
        return traceCounter
    }

    /// logExploreTrace（签名确证；"[EXPLORE-TRACE] " @ptr L1323 域确证）。
    private func logExploreTrace(_ event: String, _ detail: String) {
        Logger.log(
            "[EXPLORE-TRACE] #\(nextExploreTraceId()) \(event) \(detail)",
            level: .info)
    }

    // MARK: 分类解析

    /// parseCategories(forceRefresh:re…)（签名域确证）。
    private func parseCategories(
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
        if source.ruleExplore.exploreUrl.isEmpty {
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
    private func parseExploreRuleCategories(
        from body: String, rule: AnalyzeRule?
    ) -> [(title: String, url: String)] {
        guard let rule else { return [] }
        var categories: [(title: String, url: String)] = []
        // exploreUrl 规则列表段（" groups, " 域确证）。
        for category in source.ruleExplore.exploreUrl
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
    private func applyCategories(
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
    private func selectCategory(
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
    private func loadBooks(reset: Bool) async {
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
    private func loadMore() {
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
    private func handleViewAppear() {
        Task {
            if categoryGroups.isEmpty {
                await parseCategories(
                    forceRefresh: false, reparseCategories: false)
            }
        }
    }

    /// handleViewDisappear（"onDisappear" 域确证；triggersParserCleanup=0）。
    private func handleViewDisappear() {
        // triggersParserCleanup=0（解析清理域确证）。
    }

    /// handleRefreshExploreNotification（"notification.refreshExplore" 域）。
    private func handleRefreshExploreNotification() {
        Task {
            await parseCategories(
                forceRefresh: true, reparseCategories: false)
        }
    }

    /// handleStartBrowserNotification（"browser.present.now" 域确证）。
    private func handleStartBrowserNotification(_ notification: Notification) {
        guard
            let request = notification.userInfo?["request"]
                as? RemoteBrowserRequest
        else { return }
        browserRequest = request
        showBrowser = true
        logExploreTrace("browser.present.now", request.url.absoluteString)
    }

    // MARK: 空态

    private var emptyState: some View {
        VStack(spacing: 8.0) {
            Image(systemName: "square.grid.2x2")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("选择分类")
                .appThemeText(.body)
            Text("使用上方操作")
                .appThemeText(.caption, opacity: 0.6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 书籍列表（"该分类下暂无书籍" @ptr L4940/"暂无内容"/"没有更多了"/
    /// "点击重试"/"contentSection.retry" 域确证）。
    @ViewBuilder
    private var bookList: some View {
        if let errorMessage {
            VStack(spacing: 8.0) {
                Text(errorMessage)
                    .appThemeText(.caption, opacity: 0.7)
                Button("点击重试") {
                    logExploreTrace("contentSection.retry", "retry.initial")
                    Task {
                        await parseCategories(
                            forceRefresh: true, reparseCategories: false)
                    }
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32.0)
        } else if books.isEmpty && !isLoading {
            Text("该分类下暂无书籍")
                .appThemeText(.caption, opacity: 0.6)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32.0)
        } else {
            List {
                ForEach(books, id: \.bookUrl) { book in
                    NavigationLink {
                        BookDetailView(book: book, availableSources: []) {
                            target in
                            // TODO(T-601-01): ReaderRouter 阅读入口。
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 2.0) {
                            Text(book.name).lineLimit(1)
                            if let author = book.author {
                                Text(author)
                                    .appThemeText(.caption, opacity: 0.6)
                            }
                        }
                    }
                }
                if hasMore {
                    HStack {
                        Spacer()
                        if isLoading {
                            ProgressView()
                        } else {
                            Text("没有更多了")
                                .appThemeText(.caption, opacity: 0.5)
                        }
                        Spacer()
                    }
                    .onAppear {
                        loadMore()
                    }
                }
            }
            .listStyle(.plain)
            .refreshable {
                logExploreTrace("pullToRefresh", "")
                await parseCategories(
                    forceRefresh: true, reparseCategories: true)
                await loadBooks(reset: true)
            }
        }
    }
}

// MARK: - T-1401-14 逐域补齐（发现域）

extension ExploreSourceDetailView {

    /// 伪代码 0x1005744f0（L76-79）：分页加载后余量判定——已载/追加双参域
    ///（计数器桩；语义还原）。
    func _exploreHasMoreAfterPageLoad(
        resultCount: Int, appendedCount: Int
    ) -> Bool {
        appendedCount > 0 || resultCount > 0
    }

    /// 伪代码 0x100536720（L191-218）：发现页 JS 函数绑定脚本
    ///（函数键族域确证：getExploreCategories/getExploreContent）。
    func exploreJavaScriptFunctionBindingScript() -> String {
        """
        window.getExploreCategories = function(){ return null; };
        window.getExploreContent = function(){ return null; };
        """
    }

    /// 伪代码 0x100546690（L1129-1140）：发现分类解析后处理——去重域
    ///（ExploreCategory 模型域）。
    func _parseFoundCategories(_ input: String) -> [ExploreCategory] {
        var seen = Set<String>()
        var result: [ExploreCategory] = []
        for line in input.split(separator: "
") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            let parts = trimmed.split(separator: "&&", maxSplits: 1)
            let title = String(parts[0])
            guard seen.insert(title).inserted else { continue }
            let url = parts.count > 1 ? String(parts[1]) : title
            result.append(ExploreCategory(title: title, url: url))
        }
        return result
    }
}

extension ExploreSourceDetailView {

    /// 伪代码 0x100548724（L1044-1064）：发现分类解析——标题/URL 双提取域
    ///（与 SourceFullTestView.parseExploreCategories 交叉域对齐）。
    func parseExploreCategories(_ input: String) -> [ExploreCategory] {
        input
            .split(separator: "\n")
            .compactMap { line -> ExploreCategory? in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return nil }
                let parts = trimmed.split(separator: "&&", maxSplits: 1)
                let title = String(parts[0])
                let url = parts.count > 1 ? String(parts[1]) : title
                return ExploreCategory(title: title, url: url)
            }
    }
}

