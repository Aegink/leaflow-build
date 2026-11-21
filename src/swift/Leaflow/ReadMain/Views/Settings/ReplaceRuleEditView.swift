// 原路径: ReadMain/Views/Settings/ReplaceRuleEditView.swift
// 证据:
//   - PGO: 90 条记录（index/task_functions.csv T-701-07 /
//     ReplaceRuleEditView.swift；伪代码域 160 行）
//   - CovMap: 上述 L 区段（body/existingGroups/isAdding/
//     replaceService/runTest/save 域）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Settings/
//     ReplaceRuleEditView.c（4049 行）
//   - 块体确证（签名域）：
//     body getter / existingGroups getter / isAdding getter /
//     replaceService getter / runTest() / save() / Mode（id getter
//     签名域，作用域分档）
//   - 字符串域（位模式+指针，scratch/t70107_edit_strings.txt）：
//     '基本信息' L358 / '替换规则' L384 / '作用域' L406 / '测试'
//     L473 / '规则名称' L628 / '启用' L653 / '匹配内容' L836 /
//     '替换为' L1109 / '规则分组' L1487 / '未分组' L2075 /
//     '取消' L2863 / '保存' L3159
//   - 事实：编辑域六段（基本信息/作用域/匹配/替换/分组/测试）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（七签名域 + 字符串全链确证）
// 还原: 2026-11-20

import SwiftUI

/// 替换规则编辑页（body/existingGroups/isAdding 签名域确证）。
struct ReplaceRuleEditView: View {

    /// 编辑模式（Mode id getter 签名域确证：新增/编辑双档）。
    enum Mode: String, Identifiable {
        case add
        case edit

        var id: String { rawValue }
    }

    @Binding var rule: ReplaceRule
    var mode: Mode = .add
    var onDismiss: () -> Void = {}

    @State private var testInput = ""
    @State private var testOutput = ""
    private let replaceService = ReplaceRuleService()

    var body: some View {
        NavigationStack {
            Form {
                basicSection
                scopeSection
                matchSection
                replaceSection
                groupSection
                testSection
            }
            .navigationTitle(
                mode == .add ? "添加规则" : "编辑规则")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    // '取消' L2863 域确证。
                    Button("取消") {
                        onDismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    // '保存' L3159 域确证。
                    Button("保存") {
                        save()
                    }
                }
            }
        }
    }

    // MARK: 基本信息（'基本信息' L358 / '规则名称' L628 / '启用'
    // L653 域确证）

    @ViewBuilder
    private var basicSection: some View {
        Section("基本信息") {
            TextField("规则名称", text: $rule.name)
            Toggle(isOn: Binding(
                get: { rule.enabled ?? true },
                set: { rule.enabled = $0 })) {
                Text("启用")
            }
        }
    }

    // MARK: 作用域（'作用域' L406 域确证）

    @ViewBuilder
    private var scopeSection: some View {
        Section("作用域") {
            TextField("作用域（书名正则，留空为全局）",
                      text: Binding(
                        get: { rule.scope ?? "" },
                        set: { rule.scope = $0.isEmpty ? nil : $0 }))
            Toggle(isOn: Binding(
                get: { rule.scopeTitle ?? false },
                set: { rule.scopeTitle = $0 })) {
                Text("作用于标题")
            }
            Toggle(isOn: Binding(
                get: { rule.scopeContent ?? true },
                set: { rule.scopeContent = $0 })) {
                Text("作用于正文")
            }
            TextField("排除范围（正则）",
                      text: Binding(
                        get: { rule.excludeScope ?? "" },
                        set: { rule.excludeScope =
                            $0.isEmpty ? nil : $0 }))
        }
    }

    // MARK: 匹配/替换（'匹配内容' L836 / '替换为' L1109 域确证）

    @ViewBuilder
    private var matchSection: some View {
        Section("替换规则") {
            TextField("匹配内容（正则）", text: $rule.pattern)
                .font(.system(.body, design: .monospaced))
        }
    }

    @ViewBuilder
    private var replaceSection: some View {
        Section("替换为") {
            TextField("替换为", text: $rule.replacement)
                .font(.system(.body, design: .monospaced))
            Toggle(isOn: Binding(
                get: { rule.isRegex ?? true },
                set: { rule.isRegex = $0 })) {
                Text("正则模式")
            }
        }
    }

    // MARK: 分组（'规则分组' L1487 / '未分组' L2075 / '新分组名称'
    // L451 域确证）

    @ViewBuilder
    private var groupSection: some View {
        Section("规则分组") {
            Picker(selection: Binding(
                get: { rule.group ?? "" },
                set: { rule.group = $0.isEmpty ? nil : $0 })) {
                Text("未分组").tag("")
                ForEach(existingGroups, id: \.self) { group in
                    Text(group).tag(group)
                }
            } label: {
                Text("规则分组")
            }
        }
    }

    // MARK: 测试（'测试' L473 域确证）

    @ViewBuilder
    private var testSection: some View {
        Section("测试") {
            TextField("测试文本", text: $testInput, axis: .vertical)
                .lineLimit(3...6)
                .font(.system(.body, design: .monospaced))
            Button {
                runTest()
            } label: {
                Text("测试")
            }
            if !testOutput.isEmpty {
                Text(testOutput)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// existingGroups getter（签名域确证：现规则组去重排序）。
    private var existingGroups: [String] {
        let groups = replaceService.loadRules()
            .compactMap(\.group)
        return Array(Set(groups)).sorted()
    }

    /// isAdding getter（签名域确证）。
    private var isAdding: Bool {
        mode == .add
    }

    /// replaceService getter（签名域确证）。
    private var replaceServiceView: ReplaceRuleService {
        replaceService
    }

    /// runTest()（签名域确证：testRule 单测）。
    private func runTest() {
        let output = replaceService.testRule(rule, on: testInput)
        testOutput = output ?? "（无匹配）"
    }

    /// save()（签名域确证：新增/更新分派）。
    private func save() {
        if isAdding {
            replaceService.addRule(rule)
        } else {
            replaceService.updateRule(rule)
        }
        onDismiss()
    }
}
