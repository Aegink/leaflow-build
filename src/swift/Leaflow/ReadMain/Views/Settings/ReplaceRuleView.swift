// 原路径: ReadMain/Views/Settings/ReplaceRuleView.swift
// 证据:
//   - PGO: 36 条记录（index/task_functions.csv T-701-08 /
//     ReplaceRuleView.swift；伪代码域 80 行）
//   - CovMap: 上述 L 区段（body/enabledCount/filteredRules/
//     groupedRules 域）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Settings/
//     ReplaceRuleView.c（1459 行）
//   - 块体确证（签名域）：
//     body getter / enabledCount getter / filteredRules getter /
//     groupedRules getter
//   - 字符串域（位模式+指针，scratch/t70108_rule_strings.txt）：
//     '操作' L172 / '取消' L389 / '删除' L422 / '编辑' L1105 /
//     '」吗？' L1257（ReplaceRule 域交叉）
//   - 事实：规则主页 = List + 分组导航 + 搜索过滤 + 导入导出/
//     新建入口（PresentationsModifier 承载弹层）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（四签名域 + 字符串链确证）
// 还原: 2026-11-20

import SwiftUI

/// 替换规则主页（body/enabledCount/filteredRules/groupedRules
/// 签名域确证）。
struct ReplaceRuleView: View {

    @StateObject private var listModel = ReplaceRuleListViewModel()
    @State private var searchText = ""
    @State private var showAddRule = false
    @State private var editTarget: ReplaceRule?
    @State private var showImportExport = false
    @State private var showRenameGroup = false
    @State private var deleteTarget: ReplaceRule?

    var body: some View {
        NavigationStack {
            Group {
                if listModel.groups.isEmpty {
                    ContentUnavailableView(
                        "暂无规则", systemImage: "arrow.triangle.swap",
                        description: Text("点击右上角添加替换规则"))
                } else {
                    ReplaceRuleListContent(service: listModel)
                }
            }
            .navigationTitle("替换规则")
            .searchable(text: $searchText, prompt: "搜索规则")
            .replaceRulePresentations(
                showAddRule: $showAddRule,
                editTarget: $editTarget,
                showImportExport: $showImportExport,
                showRenameGroup: $showRenameGroup,
                deleteTarget: $deleteTarget)
            .onAppear {
                listModel.reload()
            }
        }
    }

    /// enabledCount getter（签名域确证）。
    private var enabledCount: Int {
        listModel.rules.count { $0.enabled ?? true }
    }

    /// filteredRules getter（签名域确证：搜索过滤域）。
    private var filteredRules: [ReplaceRule] {
        let query = searchText.trimmingCharacters(
            in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return listModel.rules }
        return listModel.rules.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || $0.pattern.localizedCaseInsensitiveContains(query)
        }
    }

    /// groupedRules getter（签名域确证：分组聚合域）。
    private var groupedRules: [String: [ReplaceRule]] {
        Dictionary(grouping: filteredRules) { $0.group ?? "" }
    }
}
