// 原路径: ReadMain/Views/Settings/ReplaceRuleListContent.swift
// 证据:
//   - PGO: 55 条记录（index/task_functions.csv T-701-07 /
//     ReplaceRuleListContent.swift；body 签名域）
//   - CovMap: 上述 L 区段（body 域：分组列表 + 规则行）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Settings/
//     ReplaceRuleListContent.c（4152 行）
//   - 块体确证（签名域）：body getter
//   - 字符串域（位模式+指针，scratch/t70107_list_strings.txt）：
//     '添加' L125 / '编辑' L129 / '规则' L131 / '将「' L645 /
//     '将删除「' L1293 / '添加规则' L1353 / '导入/导出' L1401 /
//     '全部启用' L1433 / '全部禁用' L1465 / '取消' L817 / '删除' L829 /
//     '确定' L486
//   - 事实：分组列表 + 规则行（启用开关 + 编辑/删除菜单）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（body 域 + 工具栏字符串链确证）
// 还原: 2026-11-20

import SwiftUI

/// 替换规则列表内容（body 签名域确证）。
struct ReplaceRuleListContent: View {

    @ObservedObject var service: ReplaceRuleListViewModel
    @State private var editingRule: ReplaceRule?
    @State private var showEditSheet = false
    @State private var showImportExport = false
    @State private var deleteTarget: ReplaceRule?

    var body: some View {
        List {
            ForEach(service.groups, id: \.self) { group in
                Section(group == "" ? "未分组" : group) {
                    ForEach(service.rules(in: group)) { rule in
                        ruleRow(rule)
                    }
                    .onMove { from, to in
                        service.moveRules(from: from, to: to)
                    }
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    Button {
                        // '全部启用' L1433 域确证。
                        service.enableAll()
                    } label: {
                        Label("全部启用", systemImage: "checkmark.circle")
                    }
                    Button {
                        // '全部禁用' L1465 域确证。
                        service.disableAll()
                    } label: {
                        Label("全部禁用", systemImage: "xmark.circle")
                    }
                    Button {
                        // '导入/导出' L1401 域确证。
                        showImportExport = true
                    } label: {
                        Label("导入/导出", systemImage: "arrow.up.doc")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                Button {
                    // '添加规则' L1353 域确证。
                    editingRule = ReplaceRule(name: "", pattern: "",
                                              replacement: "")
                    showEditSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            if let rule = editingRule {
                ReplaceRuleEditView(
                    rule: Binding(
                        get: { editingRule ?? rule },
                        set: { editingRule = $0 }),
                    mode: service.hasRule(rule) ? .edit : .add,
                    onDismiss: {
                        showEditSheet = false
                        service.reload()
                    })
            }
        }
        .sheet(isPresented: $showImportExport) {
            ReplaceRuleImportExportView()
        }
        .alert(
            "删除规则",
            isPresented: Binding(
                get: { deleteTarget != nil },
                set: { if !$0 { deleteTarget = nil } })
        ) {
            Button("删除", role: .destructive) {
                if let target = deleteTarget {
                    // '将删除「' L1293 域确证：删除后重载。
                    service.deleteRule(target)
                }
            }
            Button("取消", role: .cancel) {
                deleteTarget = nil
            }
        } message: {
            if let target = deleteTarget {
                Text("确定要删除「\(target.name)」吗？")
            }
        }
    }

    /// 规则行（'编辑' L129 + 启用开关域确证）。
    @ViewBuilder
    private func ruleRow(_ rule: ReplaceRule) -> some View {
        HStack {
            Toggle(isOn: Binding(
                get: { rule.enabled ?? true },
                set: { enabled in
                    service.toggleRule(id: rule.id, enable: enabled)
                })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(rule.name.isEmpty ? "（未命名）" : rule.name)
                    Text(rule.pattern)
                        .font(.caption)
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                }
            }
            Menu {
                Button {
                    // '编辑' L129 域确证。
                    editingRule = rule
                    showEditSheet = true
                } label: {
                    Label("编辑", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    deleteTarget = rule
                } label: {
                    Label("删除", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// 列表视图模型桥（service 签名域还原桥；ReplaceRuleService 为
/// T-901-03 现有骨架 API，方法随其分册落地）。
@MainActor
final class ReplaceRuleListViewModel: ObservableObject {

    @Published private(set) var rules: [ReplaceRule] = []
    private let storage = ReplaceRuleService()

    var groups: [String] {
        let names = rules.map { $0.group ?? "" }
        return Array(Set(names)).sorted { lhs, rhs in
            if lhs.isEmpty != rhs.isEmpty {
                return rhs.isEmpty
            }
            return lhs < rhs
        }
    }

    func rules(in group: String) -> [ReplaceRule] {
        rules.filter { ($0.group ?? "") == group }
    }

    func hasRule(_ rule: ReplaceRule) -> Bool {
        rules.contains { $0.id == rule.id }
    }

    func reload() {
        rules = storage.loadRules()
    }

    func toggleRule(id: String, enable: Bool) {
        storage.toggleRule(id: id, enable: enable)
        reload()
    }

    func moveRules(from offsets: IndexSet, to target: Int) {
        storage.moveRules(from: offsets, to: target)
        reload()
    }

    func deleteRule(_ rule: ReplaceRule) {
        var updated = rules
        updated.removeAll { $0.id == rule.id }
        storage.replaceRules(updated)
        reload()
    }

    func enableAll() {
        storage.enableAll()
        reload()
    }

    func disableAll() {
        storage.disableAll()
        reload()
    }
}
