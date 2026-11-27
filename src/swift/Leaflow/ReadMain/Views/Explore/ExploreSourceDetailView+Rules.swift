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
    // AnalyzeRule 构造带 source/parent 双参（签名域确证，wave-16）。
    let rule = AnalyzeRule(source: source, parent: nil)
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
        for line in input.split(separator: "\n") {
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
