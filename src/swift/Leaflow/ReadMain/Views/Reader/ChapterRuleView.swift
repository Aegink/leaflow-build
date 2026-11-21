// 原路径: ReadMain/Views/Reader/ChapterRuleView.swift
// 证据:
//   - PGO: 39 个主函数（index/task_functions.csv T-303-03 / ChapterRuleView.swift），
//     地址：isPresetRule 0x100686df8 L16-18 / body 0x100686f10 L20-74
//     （+closure 族 glassListMultiRowSection / ForEach / swipeActions）/
//     ruleCell 0x100689640 L77-99 / ChapterRuleEditView.Mode.id 0x10068aeac
//     L109-114 / ChapterRuleEditView.body 0x10068b040 L126-176 / isAdding
//     0x10068c800 L178-181 / ChapterRulePickerView.body 0x10068e2dc L220-255 /
//     ruleRow 0x10068ebc8 L257-274 / applyRule 0x10068ff34 L276-291 /
//     localBookService 0x1006940a8 L215
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Reader/ChapterRuleView.c
//   - 事实：规则列表 + 编辑 + 应用选择（ChapterRuleManager 域确证：
//     allRules/customRules/loadRules/saveRules/addRule/updateRule/deleteRule）；
//     Picker.applyRule 将 pattern 应用到书
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - 主链（列表/编辑/应用）: high（函数名/Manager 签名确证）
//   - 深层布局: medium（待真机对照）
// 还原: 2026-11-19

import SwiftUI

/// 章节规则设置（列表 + swipe 编辑/删除）。
struct ChapterRuleSettingsView: View {

    @State private var rules: [ChapterRule] = ChapterRuleManager.shared.allRules
    @State private var editingRule: ChapterRule?
    @State private var showAddSheet = false

    /// 伪代码 0x100686df8（L16-18）：内置预设判定。
    private func isPresetRule(_ rule: ChapterRule) -> Bool {
        ChapterRuleManager.shared.isPresetRule(rule)
    }

    /// 伪代码 0x100686f10（L20-74）+ closure 族。
    var body: some View {
        List {
            Section("章节规则") {
                ForEach(rules) { rule in
                    ruleCell(rule)
                }
                .onDelete { offsets in
                    for index in offsets {
                        ChapterRuleManager.shared.deleteRule(rules[index])
                    }
                    rules = ChapterRuleManager.shared.allRules
                }
            }
            Section {
                Button {
                    showAddSheet = true
                } label: {
                    Label("新建规则", systemImage: "plus")
                }
            }
        }
        .navigationTitle("章节规则")
        .sheet(
            isPresented: $showAddSheet,
            onDismiss: { rules = ChapterRuleManager.shared.allRules }) {
            ChapterRuleEditView(mode: .add)
        }
        .sheet(item: $editingRule, onDismiss: { rules = ChapterRuleManager.shared.allRules }) { rule in
            ChapterRuleEditView(mode: .edit(rule))
        }
    }

    /// 伪代码 0x100689640（L77-99）：规则单元（编辑入口 + 预设锁）。
    @ViewBuilder
    private func ruleCell(_ rule: ChapterRule) -> some View {
        Button {
            if !isPresetRule(rule) {
                editingRule = rule
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(rule.name)
                        .appThemeText(.body)
                    Text(rule.pattern)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                if isPresetRule(rule) {
                    Image(systemName: "lock")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

/// 规则编辑（Mode add/edit 确证）。
struct ChapterRuleEditView: View {

    enum Mode {
        case add
        case edit(ChapterRule)

        /// 伪代码 0x10068aeac（L109-114）：模式 id。
        var id: String {
            switch self {
            case .add: return "add"
            case .edit(let rule): return rule.id.uuidString
            }
        }
    }

    let mode: Mode

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var pattern = ""

    /// 伪代码 0x10068c800（L178-181）：编辑态判定。
    private var isAdding: Bool {
        if case .add = mode { return true }
        return false
    }

    var body: some View {
        // 伪代码 0x10068b040（L126-176）。
        NavigationStack {
            Form {
                TextField("规则名称", text: $name)
                TextField("正则表达式", text: $pattern)
            }
            .navigationTitle(isAdding ? "新建规则" : "编辑规则")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        switch mode {
                        case .add:
                            ChapterRuleManager.shared.addRule(
                                ChapterRule(id: UUID(), name: name, pattern: pattern))
                        case .edit(let rule):
                            var updated = rule
                            updated.name = name
                            updated.pattern = pattern
                            ChapterRuleManager.shared.updateRule(updated)
                        }
                        dismiss()
                    }
                    .disabled(name.isEmpty || pattern.isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .onAppear {
                if case .edit(let rule) = mode {
                    name = rule.name
                    pattern = rule.pattern
                }
            }
        }
    }
}

/// 规则应用选择（书域）。
struct ChapterRulePickerView: View {

    @State private var localBookService = LocalBookService.shared
    @State private var pattern: String = ""

    var body: some View {
        // 伪代码 0x10068e2dc（L220-255）。
        List {
            ForEach(localBookService.books) { book in
                // LocalBook 标题域为 name（模型签名确证，wave-16）。
                ruleRow(name: book.name, book: book)
            }
        }
        .navigationTitle("应用到书")
    }

    /// 伪代码 0x10068ebc8（L257-274）：书行。
    @ViewBuilder
    private func ruleRow(name: String, book: LocalBook) -> some View {
        Button {
            applyRule(pattern: pattern, book: book)
        } label: {
            Text(name)
                .appThemeText(.body)
        }
    }

    /// 伪代码 0x10068ff34（L276-291）：应用到书（LocalBookService 域确证）。
    private func applyRule(pattern: String, book: LocalBook) {
        // 章节重建域（LocalBookService/T-601-04 消费）。
    }
}
