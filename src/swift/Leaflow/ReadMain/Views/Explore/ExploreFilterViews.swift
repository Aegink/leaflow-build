// 原路径: ReadMain/Views/Explore/ExploreFilterViews.swift
// 证据:
//   - PGO: 69 条记录（index/task_functions.csv T-501-02 /
//     ExploreFilterViews.swift；45 个伪代码块）。关键域：
//     ExploreFilterBar.body（ForEach[ExploreCategory] → Menu(glassFilterStyle
//     标签) + ForEach[ExploreCategory] → ExploreActionControlButton 双段
//     签名确证）/ ExploreActionControlButton.body / ExploreCategoryFilterSheet
//     （_searchText/_displayedGroups/_displayedActionControls 变量初始化 +
//     useLightweightChips/gridColumns getter/body/header/searchBar/
//     scrollContent/emptyState/actionSection(title:controls:)/
//     groupSection(ExploreCategoryGroup)/updateDisplayedGroups/
//     categoryButton(ExploreCategory)/actionButton(title:systemImage:))
//   - CovMap: L 域映射（index/restoration_status.csv）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Explore/ExploreFilterViews.c
//     （5963 行）
//   - 字符串确证（位模式/指针）："分类筛选"（L3111）/"当前 · "（L3173）/
//     "的分类标签" @ptr L3189/"快捷操作"（L3383）/"没有找到匹配的分类"
//     @ptr L5230/"试试别的关键词" @ptr L2584/"magnifyingglass"（'magnifyi'
//     L2554）/"checkmark"（L500 域）/"ilterViews.swift" @ptr L5205（诊断域）；
//     布局常量 0x4024=10.0/0x4014=5.0/0x4018=6.0 域
//   - 事实：FilterBar 双 ForEach（Menu 过滤段 + ActionControlButton 段）+
//     glassFilterStyle 修饰（签名确证）；Sheet 大屏 gridColumns /
//     小屏 lightweightChips 分流（useLightweightChips 签名确证）；
//     当前选中态 "当前 · " 域确证
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - 结构分流/文案: high（签名族 + 位模式确证）
//   - 布局细节: medium（结构性还原，待真机对照）
// 还原: 2026-11-20

import SwiftUI

// MARK: - glassFilterStyle（签名确证）

extension View {
    /// glassFilterStyle（FilterBar Menu 标签签名确证）。
    func glassFilterStyle() -> some View {
        self
            .padding(.horizontal, 10.0)
            .padding(.vertical, 6.0)
            .background(
                Capsule().fill(Color(uiColor: .secondarySystemBackground)))
    }
}

// MARK: - ExploreFilterBar

/// 发现筛选条（双 ForEach 签名确证）。
struct ExploreFilterBar: View {
    @ObservedObject var engine: ExploreFilterEngine

    var body: some View {
        // 闭包签名族：padding 域 + 过滤 Menu 段 + 动作按钮段。
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8.0) {
                // ForEach[ExploreCategory] → Menu(glassFilterStyle)。
                ForEach(engine.selectFilters) { filter in
                    Menu {
                        // 同组兄弟分类（Menu 段签名确证）。
                        ForEach(
                            engine.selectFilters.filter {
                                $0.id != filter.id
                            }
                        ) { sibling in
                            Button {
                                engine.onFilterSelected(
                                    filter: sibling, value: sibling.url)
                            } label: {
                                HStack {
                                    Text(sibling.title)
                                    if engine.currentControlValue(for: sibling)
                                        == sibling.url {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        // "当前 · " 域确证（选中前缀）。
                        Text(filterDisplayTitle(filter))
                            .glassFilterStyle()
                    }
                }
                // ForEach[ExploreCategory] → ExploreActionControlButton。
                ForEach(engine.actionControls) { control in
                    ExploreActionControlButton(
                        control: control,
                        displayValue: engine.actionControlDisplayValue(
                            for: control),
                        isActive: engine.actionControlIsActive(for: control)) {
                        engine.handleActionControlTap(control)
                    }
                }
            }
            .padding(.horizontal, 12.0)
        }
    }

    /// 显示标题（"当前 · " 域确证）。
    private func filterDisplayTitle(_ filter: ExploreCategory) -> String {
        let value = engine.currentControlValue(for: filter)
        return value.isEmpty ? filter.title : "当前 · \(value)"
    }
}

// MARK: - ExploreActionControlButton

/// 动作控制按钮（签名确证）。
struct ExploreActionControlButton: View {
    let control: ExploreCategory
    let displayValue: String?
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4.0) {
                Image(
                    systemName: control.type == "toggle"
                        ? (isActive ? "toggle.on" : "toggle.off")
                        : "bolt.horizontal")
                Text(displayValue ?? control.title)
            }
            .appThemeText(.caption)
            .glassFilterStyle()
            .foregroundColor(isActive ? .blue : .primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - ExploreCategoryFilterSheet

/// 分类筛选面板（变量初始化 + 分段族签名确证）。
struct ExploreCategoryFilterSheet: View {

    let groups: [ExploreCategoryGroup]
    let actionControls: [ExploreCategory]
    let onSelect: (ExploreCategory) -> Void
    let onAction: (ExploreCategory) -> Void

    // 变量初始化确证：_searchText/_displayedGroups/_displayedActionControls。
    @State private var searchText: String = ""
    @State private var displayedGroups: [ExploreCategoryGroup] = []
    @State private var displayedActionControls: [ExploreCategory] = []
    @Environment(\.dismiss) private var dismiss

    /// useLightweightChips getter（签名确证；小屏轻量 chips）。
    private var useLightweightChips: Bool {
        UIScreen.main.bounds.width < 500
    }

    /// gridColumns getter（签名确证）。
    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible()), count: 3)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                searchBar
                if displayedGroups.isEmpty && displayedActionControls.isEmpty
                {
                    emptyState
                } else {
                    scrollContent
                }
            }
            .navigationTitle("分类筛选")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                }
            }
            .onAppear {
                updateDisplayedGroups()
            }
            .onChange(of: searchText) { _ in
                updateDisplayedGroups()
            }
        }
    }

    /// header getter（签名确证）。
    private var header: some View {
        VStack(alignment: .leading, spacing: 4.0) {
            Text("分类筛选")
                .appThemeText(.headline)
            Text("\(groups.count) 组 · \(actionControls.count) 快捷操作")
                .appThemeText(.caption, opacity: 0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16.0)
        .padding(.vertical, 8.0)
    }

    /// searchBar getter（签名确证；"magnifyingglass" 域确证）。
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("搜索分类", text: $searchText)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 12.0)
        .padding(.vertical, 8.0)
        .background(Color(uiColor: .secondarySystemBackground))
        .padding(.horizontal, 16.0)
    }

    /// scrollContent getter（签名确证）。
    private var scrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12.0) {
                if useLightweightChips {
                    ForEach(displayedGroups) { group in
                        groupSection(group)
                    }
                } else {
                    ForEach(displayedGroups) { group in
                        LazyVGrid(columns: gridColumns, spacing: 8.0) {
                            ForEach(group.categories) { category in
                                categoryButton(category)
                            }
                        }
                        .padding(.horizontal, 16.0)
                    }
                }
                if !displayedActionControls.isEmpty {
                    actionSection(
                        title: "快捷操作",
                        controls: displayedActionControls)
                }
            }
            .padding(.vertical, 12.0)
        }
    }

    /// emptyState getter（签名确证；"没有找到匹配的分类" @ptr + "试试别的
    /// 关键词" @ptr 域确证）。
    private var emptyState: some View {
        VStack(spacing: 8.0) {
            Image(systemName: "magnifyingglass")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("没有找到匹配的分类")
                .appThemeText(.body)
            Text("试试别的关键词")
                .appThemeText(.caption, opacity: 0.6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// actionSection(title:controls:)（签名确证；"快捷操作" L3383 域）。
    @ViewBuilder
    private func actionSection(
        title: String, controls: [ExploreCategory]
    ) -> some View {
        VStack(alignment: .leading, spacing: 8.0) {
            Text(title)
                .appThemeText(.subheadline)
                .padding(.horizontal, 16.0)
            ForEach(controls) { control in
                actionButton(
                    title: control.title, systemImage: "bolt.horizontal") {
                    onAction(control)
                    dismiss()
                }
                .padding(.horizontal, 16.0)
            }
        }
    }

    /// groupSection(ExploreCategoryGroup)（签名确证）。
    @ViewBuilder
    private func groupSection(_ group: ExploreCategoryGroup) -> some View {
        VStack(alignment: .leading, spacing: 6.0) {
            Text(group.title.isEmpty ? "全部" : group.title)
                .appThemeText(.subheadline)
                .padding(.horizontal, 16.0)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8.0) {
                    ForEach(group.categories) { category in
                        categoryButton(category)
                    }
                }
                .padding(.horizontal, 16.0)
            }
        }
    }

    /// updateDisplayedGroups（签名确证）。
    private func updateDisplayedGroups() {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        if query.isEmpty {
            displayedGroups = groups
            displayedActionControls = actionControls
        } else {
            displayedGroups = groups.compactMap { group in
                let matched = group.categories.filter {
                    $0.title.localizedCaseInsensitiveContains(query)
                }
                return matched.isEmpty
                    ? nil
                    : ExploreCategoryGroup(
                        title: group.title, categories: matched)
            }
            displayedActionControls = actionControls.filter {
                $0.title.localizedCaseInsensitiveContains(query)
            }
        }
    }

    /// categoryButton(ExploreCategory)（签名确证）。
    private func categoryButton(_ category: ExploreCategory) -> some View {
        Button {
            onSelect(category)
            dismiss()
        } label: {
            Text(category.title)
                .appThemeText(.caption)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8.0)
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(8, antialiased: true)
        }
        .buttonStyle(.plain)
    }

    /// actionButton(title:systemImage:)（签名确证）。
    private func actionButton(
        title: String, systemImage: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.bordered)
    }
}
