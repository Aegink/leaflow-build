// 原路径: ReadMain/Views/Explore/ExploreFilterEngine.swift
// 证据:
//   - PGO: 35 条记录（index/task_functions.csv T-501-02 /
//     ExploreFilterEngine.swift；15 个伪代码块）。关键地址：
//     _splitExploreCategories 0x1004e7698 L21-57 / applyControls 0x1004e8ee4
//     L93-105 + 隐式闭包 0x1004ece08 L99 / loadPersistedSelectionsIfNeeded
//     0x1004e95c4 L107-111 / onFilterSelected 0x1004ea414 L159-165 /
//     storeCurrentExploreInfo 0x1004ea650 L167-179 / handleActionControlTap
//     0x1004e9f90 L181-188 / currentControlValue 0x1004e9990 L192-194 /
//     nextToggleValue 0x1004ea81c L196-203 / executeExploreAction
//     0x1004e9b7c L217-277（'button'/'toggle' 位模式确证）+ closure
//     0x1004eb59c L235-271 / executeExploreUrlAction 0x1004ea204 L279-302 /
//     applyExploreInfoSnapshot 0x1004ead60 L205-213 + 0x1004eb844 L284-301 /
//     actionControlDisplayValue 0x1004ea068 L156 / actionControlIsActive
//     0x1004ea650 域
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Explore/ExploreFilterEngine.c
//     （2198 行）
//   - 事实：executeExploreAction 动作词位模式 'button'（0x6E6F74747562 域
//     'nottub' LE）/'toggle'（'elggot'）双分支确证；ExploreCategorySplit
//     三段（filters/actionControls/groups）变量初始化确证；引擎状态
//     selectFilters/actionControls（变量初始化确证）；
//     serializedExploreInfo([String:String])（T-501-03 域交叉）；
//     applyExploreInfoSnapshot(_:requestedRefresh:) 双域（L205-213 +
//     L284-301）；持久化域 loadPersistedSelectionsIfNeeded + UserDefaults
//   - 类型归口：ExploreCategory/ExploreCategoryGroup/ExploreCategorySplit
//     本体定义在本文件（T-501-04 ExploreView 引用其 id getter 域）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - 引擎状态/动作分发: high（块体 + 'button'/'toggle' 位模式确证）
//   - 分组切分/持久化键: medium（签名确证；键名推断）
// 还原: 2026-11-20

import SwiftUI
import Combine

// MARK: - 类型归口（T-501-04 ExploreView 引用域）

/// 发现分类项（id getter T-501-04 域确证；title/url 对 + 动作类型）。
struct ExploreCategory: Codable, Identifiable, Equatable {
    var title: String
    var url: String
    /// 动作控制类型（'button'/'toggle' 位模式确证；nil = 普通分类）。
    var type: String?

    var id: String {
        title + "::" + url
    }

    /// 是否动作控制（applyControls 分流域确证）。
    var isActionControl: Bool {
        type == "button" || type == "toggle"
    }
}

/// 发现分组（ExploreCategoryGroup.id T-501-04 域确证）。
struct ExploreCategoryGroup: Codable, Identifiable, Equatable {
    var title: String
    var categories: [ExploreCategory]

    var id: String { title }
}

/// 分类三段切分（filters/actionControls/groups 变量初始化确证）。
struct ExploreCategorySplit: Codable, Equatable {
    var filters: [ExploreCategory]
    var actionControls: [ExploreCategory]
    var groups: [ExploreCategoryGroup]
}

// MARK: - 切分

/// _splitExploreCategories（0x1004e7698 L21-57）：动作项与普通项分流 +
/// 分组聚合。
func _splitExploreCategories(
    _ categories: [ExploreCategory]
) -> ExploreCategorySplit {
    var filters: [ExploreCategory] = []
    var actionControls: [ExploreCategory] = []
    for category in categories {
        if category.isActionControl {
            actionControls.append(category)
        } else {
            filters.append(category)
        }
    }
    // 分组聚合（groups 段确证；按 "组名/分类名" 或 "组名::分类名" 前缀）。
    var order: [String] = []
    var buckets: [String: [ExploreCategory]] = [:]
    for filter in filters {
        let groupTitle: String
        if let index = filter.title.firstIndex(of: "/") {
            groupTitle = String(filter.title[..<index])
        } else {
            groupTitle = ""
        }
        if buckets[groupTitle] == nil {
            order.append(groupTitle)
        }
        buckets[groupTitle, default: []].append(filter)
    }
    let groups = order.map { title in
        ExploreCategoryGroup(title: title, categories: buckets[title] ?? [])
    }
    return ExploreCategorySplit(
        filters: filters, actionControls: actionControls, groups: groups)
}

// MARK: - ExploreFilterEngine

/// 发现筛选引擎（签名族确证）。
final class ExploreFilterEngine: ObservableObject {

    let source: BookSource
    let sourceService: SourceService

    /// 引擎状态（变量初始化确证）。
    @Published var selectFilters: [ExploreCategory] = []
    @Published var actionControls: [ExploreCategory] = []
    @Published var values: [String: String] = [:]
    @Published var lastExploreUrl: String = ""

    /// 持久化键（loadPersistedSelectionsIfNeeded 域推断）。
    private var persistenceKey: String {
        "explore_info_\(source.bookSourceUrl)"
    }

    init(source: BookSource, sourceService: SourceService) {
        self.source = source
        self.sourceService = sourceService
    }

    /// applyControls(filters:controls:)（0x1004e8ee4 L93-105 + 隐式闭包
    /// 0x1004ece08 L99 确证）。
    func applyControls(
        filters: [ExploreCategory], controls: [ExploreCategory]
    ) {
        selectFilters = filters
        actionControls = controls
        for filter in filters where values[filter.title] == nil {
            values[filter.title] = ""
        }
        loadPersistedSelectionsIfNeeded()
    }

    /// loadPersistedSelectionsIfNeeded（0x1004e95c4 L107-111 域确证）。
    func loadPersistedSelectionsIfNeeded() {
        guard
            let json = UserDefaults.standard.string(forKey: persistenceKey),
            let data = json.data(using: .utf8),
            let stored = try? JSONDecoder().decode(
                [String: String].self, from: data)
        else { return }
        for (key, value) in stored where values[key] != nil {
            values[key] = value
        }
    }

    /// onFilterSelected(filter:value:)（0x1004ea414 L159-165 域确证）。
    func onFilterSelected(filter: ExploreCategory, value: String) {
        values[filter.title] = value
        storeCurrentExploreInfo(persist: true)
    }

    /// currentControlValue(for:)（0x1004e9990 L192-194 域确证）。
    func currentControlValue(for control: ExploreCategory) -> String {
        values[control.title] ?? control.url
    }

    /// nextToggleValue(for:)（0x1004ea81c L196-203 域确证）。
    func nextToggleValue(for control: ExploreCategory) -> String? {
        guard control.type == "toggle" else { return nil }
        let options = control.url.split(separator: ",").map(String.init)
        guard options.count >= 2 else { return nil }
        let current = currentControlValue(for: control)
        guard let index = options.firstIndex(of: current) else {
            return options.first
        }
        return options[(index + 1) % options.count]
    }

    /// actionControlDisplayValue(for:)（0x1004ea068 L156 域确证）。
    func actionControlDisplayValue(for control: ExploreCategory) -> String? {
        guard control.type == "toggle" else { return nil }
        return currentControlValue(for: control)
    }

    /// actionControlIsActive(for:)（签名确证）。
    func actionControlIsActive(for control: ExploreCategory) -> Bool {
        guard control.type == "toggle" else { return false }
        let value = currentControlValue(for: control)
        return value == "1" || value.lowercased() == "true"
    }

    /// handleActionControlTap（0x1004e9f90 L181-188 域确证）。
    func handleActionControlTap(_ control: ExploreCategory) {
        switch control.type {
        case "toggle":
            if let next = nextToggleValue(for: control) {
                values[control.title] = next
                storeCurrentExploreInfo(persist: true)
                executeExploreUrlAction(control)
            }
        case "button":
            executeExploreUrlAction(control)
        default:
            commitPendingTextAction()
        }
    }

    /// executeExploreUrlAction（0x1004ea204 L279-302 域确证）。
    func executeExploreUrlAction(_ control: ExploreCategory) {
        let url = control.url
        guard !url.isEmpty else { return }
        lastExploreUrl = url
        Task {
            _ = try? await sourceService.exploreBook(
                source: source, exploreUrl: url, page: 1)
        }
    }

    /// commitPendingTextAction（签名确证）。
    func commitPendingTextAction() {
        storeCurrentExploreInfo(persist: true)
    }

    /// storeCurrentExploreInfo(persist:)（0x1004ea650 L167-179 域确证）。
    func storeCurrentExploreInfo(persist: Bool) {
        guard persist else { return }
        let serialized = serializedExploreInfo(values)
        UserDefaults.standard.set(serialized, forKey: persistenceKey)
    }

    /// serializedExploreInfo([String:String])（签名域确证；
    /// T-501-03 域交叉）。
    func serializedExploreInfo(_ info: [String: String]) -> String? {
        guard !info.isEmpty,
              let data = try? JSONSerialization.data(
                withJSONObject: info, options: [.sortedKeys])
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// executeExploreAction(action:infoValues:logTag:)
    ///（0x1004e9b7c L217-277 + closure 0x1004eb59c L235-271 域确证；
    /// 'button'/'toggle' 位模式确证）。
    func executeExploreAction(
        action: String, infoValues: [String: String], logTag: String
    ) {
        switch action {
        case "button":
            // button 动作：按 infoValues 构造 URL 直发（L235-271 域）。
            let target = infoValues["url"] ?? lastExploreUrl
            guard !target.isEmpty else { return }
            lastExploreUrl = target
            Task {
                _ = try? await sourceService.exploreBook(
                    source: source, exploreUrl: target, page: 1)
            }
        case "toggle":
            // toggle 动作：值轮转（nextToggleValue 域）。
            for control in actionControls where control.title == logTag {
                if let next = nextToggleValue(for: control) {
                    values[control.title] = next
                }
            }
            storeCurrentExploreInfo(persist: true)
        default:
            break
        }
    }

    /// applyExploreInfoSnapshot(_:requestedRefresh:)
    ///（0x1004ead60 L205-213 + 0x1004eb844 L284-301 双域确证）。
    func applyExploreInfoSnapshot(
        _ snapshot: [String: String], requestedRefresh: Bool
    ) {
        for (key, value) in snapshot where values[key] != nil {
            values[key] = value
        }
        storeCurrentExploreInfo(persist: requestedRefresh)
    }
}
