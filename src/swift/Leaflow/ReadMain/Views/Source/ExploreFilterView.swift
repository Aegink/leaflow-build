// 原路径: ReadMain/Views/Source/ExploreFilterView.swift
// 证据:
//   - PGO: 29 条记录（index/task_functions.csv T-401-04 /
//     ExploreFilterView.swift；全部 pgo_only —— 该文件无独立伪代码块，
//     函数体未成功导出，按闭包签名族 + ExploreModels 模型交叉还原）。
//     覆盖：ExploreFilterView._filters 变量初始化 / body / body 闭包族
//     （padding → ForEach[ExploreFilter] → Menu(cornerRadius) →
//     ForEach[ExploreFilterOption] → Button(Text) → MainActor 动作 →
//     cornerRadius 闭包 → TupleView<(Text, Text?, font)> → 选中判断
//     (ExploreFilterOption)->Bool）/ loadFilters；ExploreFilterSheet
//     ._filters/_tempSelections 变量初始化 / body / toolbar 闭包族
//     （ForEach[ExploreFilter] → Section(Text, LazyVGrid(ForEach[
//     ExploreFilterOption] → Button(cornerRadius)))）/ 工具栏按钮 ×2
//     （重置/确定）
//   - CovMap: 行号映射（index/restoration_status.csv）
//   - IDA: 无独立伪代码（ExploreFilterView.c 未导出块）——pgo_only 全家
//   - 事实：ExploreFilter/ExploreFilterOption 模型（ExploreModels.swift
//     T-401 域确证：id = UUID()、selectedIndex = 0）；Menu 标签经
//     cornerRadius 胶囊 + TupleView<(Text, Text?, font)> 行布局确证；
//     Sheet 用 Section(header:) + LazyVGrid 网格确证；_tempSelections
//     字典态确证（临时选择，确定时落回）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: medium（pgo_only 签名族结构性还原；文案与布局待真机对照）
// 还原: 2026-11-20

import SwiftUI

/// 发现页过滤条（横排 Menu 胶囊）。
struct ExploreFilterView: View {

    // PGO 变量初始化确证：_filters。
    @State private var filters: [ExploreFilter] = []

    var body: some View {
        // 闭包签名族：padding 域 → ForEach → Menu(cornerRadius)。
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8.0) {
                ForEach(filters) { filter in
                    Menu {
                        ForEach(filter.options) { option in
                            Button(option.label) {
                                // MainActor 动作闭包确证。
                                select(option: option, in: filter)
                            }
                        }
                    } label: {
                        // cornerRadius 闭包 + TupleView<(Text, Text?, font)>
                        // 行布局确证。
                        HStack(spacing: 4.0) {
                            Text(filter.title)
                            if let selected = selectedLabel(filter) {
                                Text(selected)
                                    .font(.caption)
                            }
                        }
                        .appThemeText(.caption)
                        .padding(.horizontal, 10.0)
                        .padding(.vertical, 6.0)
                        .cornerRadius(12, antialiased: true)
                    }
                }
            }
            .padding(.horizontal, 12.0)
        }
        .onAppear {
            loadFilters()
        }
    }

    /// 选中项标签（(ExploreFilterOption)->Bool 判断闭包确证）。
    private func selectedLabel(_ filter: ExploreFilter) -> String? {
        filter.options.indices.contains(filter.selectedIndex)
            ? filter.options[filter.selectedIndex].label
            : nil
    }

    /// 选中落回（MainActor 动作闭包确证）。
    private func select(option: ExploreFilterOption, in filter: ExploreFilter) {
        guard let idx = filters.firstIndex(where: { $0.id == filter.id }),
              let optionIdx = filter.options.firstIndex(where: {
                  $0.id == option.id
              })
        else { return }
        filters[idx].selectedIndex = optionIdx
    }

    /// pgo_only loadFilters()：过滤器装载——数据源待 Explore 分册交叉
    /// （跨任务依赖登记：ExploreFilterEngine 域，见分册 §4 仍不清楚 2）。
    private func loadFilters() {
        // 伪代码未导出（pgo_only）；装载源随 T-401-05/06 Explore 域落地。
    }
}

/// 发现页过滤面板（Section + LazyVGrid 网格）。
struct ExploreFilterSheet: View {

    // PGO 变量初始化确证：_filters/_tempSelections。
    @State private var filters: [ExploreFilter] = []
    @State private var tempSelections: [String: String] = [:]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        // 闭包签名族：toolbar 域 → ForEach → Section(Text, LazyVGrid)。
        NavigationStack {
            List {
                ForEach(filters) { filter in
                    Section {
                        LazyVGrid(
                            columns: Array(
                                repeating: GridItem(.flexible()), count: 3),
                            spacing: 8.0
                        ) {
                            ForEach(filter.options) { option in
                                // cornerRadius 网格按钮确证。
                                Button {
                                    tempSelections[filter.title] = option.value
                                } label: {
                                    Text(option.label)
                                        .appThemeText(.caption)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 6.0)
                                        .cornerRadius(8, antialiased: true)
                                }
                                .buttonStyle(.bordered)
                                .tint(
                                    tempSelections[filter.title]
                                        == option.value ? .blue : .secondary)
                            }
                        }
                        .padding(.vertical, 4.0)
                    } header: {
                        Text(filter.title)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("筛选")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // 工具栏按钮 ×2（重置/确定，ToolbarContentBuilder.buildBlock
                // <A, B> 两元确证）。
                ToolbarItem(placement: .topBarLeading) {
                    Button("重置") {
                        tempSelections = [:]
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("确定") {
                        applyTempSelections()
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadFilters()
            }
        }
    }

    /// 临时选择落回 filters（closure #2 () -> () 域确证）。
    private func applyTempSelections() {
        for idx in filters.indices {
            if let value = tempSelections[filters[idx].title],
               let optionIdx = filters[idx].options.firstIndex(where: {
                   $0.value == value
               }) {
                filters[idx].selectedIndex = optionIdx
            }
        }
    }

    /// 过滤器装载（同 ExploreFilterView.loadFilters——待 Explore 分册交叉）。
    private func loadFilters() {
        // 伪代码未导出（pgo_only）；装载源随 T-401-05/06 Explore 域落地。
    }
}
