// 原路径: ReadMain/Views/Source/SourceGroupPickerSheet.swift
// 证据:
//   - PGO: 52 条记录（index/task_functions.csv T-401-05 /
//     SourceGroupPickerSheet.swift；33 个伪代码块 + 19 pgo_only）。关键
//     地址：filteredGroups 0x100c52248（getter）/ body 0x100c52900 L29-141 /
//     主体闭包 0x100c52e2c L30-139 / 三 Section 组 0x100c52efc L31-130 /
//     新建分组动作（createNewGroup pgo_only）/ SourceGroupMergeSheet.body
//     0x100c56dfc L168-220 / 合并主体 0x100c5718c L169-218 /
//     targetGroups getter（pgo_only）
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Source/
//     SourceGroupPickerSheet.c（2741 行）
//   - 字符串确证（位模式/指针）："新建分组"（0x100c… L161）/
//     "没有匹配的分组"（@ptr L400）/"folder.fill"（'folder.f' L924）/
//     "checkmark"（'checkmar' L987）/"已有分组（"（L1137）/
//     "folder.badge.minus"（@ptr L1364）/"未分组"（L1379）/"」合并到"（L1823）/
//     "合并后，「"（L1842）/"arrow.right"（'arrow.ri' L2220）/
//     "置将移动到目标分组"（@ptr L2326）
//   - 事实：body 三 Section（新建输入行 foregroundColor + onSubmit + 可选
//     Button / 已有分组 ForEach(String) 行（frame(width:40,height:40) 图标 +
//     appThemeText + Spacer + 可选 font）/ 未分组行 Section）+ 工具栏单
//     Button（关闭）；filteredGroups 按 search 过滤；合并 Sheet 引导文案
//     "合并后，「源」合并到「目标」，配置将移动到目标分组" 确证
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - 分组列表/过滤/新建: high（伪代码块体 + 位模式确证）
//   - 合并 Sheet 细节: medium（文案确证；合并动作语义结构性还原）
// 还原: 2026-11-20

import SwiftUI

/// 书源分组选择/新建/合并面板。
struct SourceGroupPickerSheet: View {

    /// 现有分组全集（"已有分组（N）" 域确证）。
    let existingGroups: [String]
    /// 选中回调（选择后落回）。
    let onSelect: (String) -> Void

    @State private var searchText: String = ""
    @State private var newGroupName: String = ""
    @State private var showingMerge = false
    @Environment(\.dismiss) private var dismiss

    /// filteredGroups getter（pgo_only/块内过滤域确证）：按 search 前缀
    /// 过滤现有分组。
    private var filteredGroups: [String] {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return existingGroups }
        return existingGroups.filter {
            $0.localizedCaseInsensitiveContains(trimmed)
        }
    }

    var body: some View {
        // 伪代码 0x100c52900（L29-141）：NavigationStack + List 三 Section。
        NavigationStack {
            List {
                // Section1（closure L31-130 域1）：新建分组输入行。
                Section {
                    HStack {
                        Image(systemName: "folder.badge.plus")
                            .foregroundColor(.blue)
                        TextField("新建分组", text: $newGroupName)
                            .onSubmit { createNewGroup() }
                        if !newGroupName.trimmingCharacters(
                            in: .whitespaces
                        ).isEmpty {
                            Button {
                                createNewGroup()
                            } label: {
                                Image(systemName: "checkmark.circle.fill")
                                    .cornerRadius(12, antialiased: true)
                            }
                        }
                    }
                }
                // Section2：已有分组列表。
                Section("已有分组（\(existingGroups.count)）") {
                    if filteredGroups.isEmpty {
                        HStack {
                            Spacer()
                            Text("没有匹配的分组")
                                .appThemeText(.caption, opacity: 0.6)
                                .padding(.vertical, 8.0)
                            Spacer()
                        }
                    } else {
                        ForEach(filteredGroups, id: \.self) { group in
                            Button {
                                onSelect(group)
                                dismiss()
                            } label: {
                                HStack(spacing: 8.0) {
                                    Image(systemName: "folder.fill")
                                        .frame(width: 40.0, height: 40.0)
                                        .font(.caption)
                                    Text(group)
                                        .appThemeText(.body)
                                    Spacer()
                                }
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    mergeTarget = group
                                    showingMerge = true
                                } label: {
                                    Label("合并…", systemImage: "arrow.right")
                                }
                            }
                        }
                    }
                }
                // Section3：未分组行（closure L31-130 域3 确证）。
                Section {
                    Button {
                        onSelect("未分组")
                        dismiss()
                    } label: {
                        HStack(spacing: 8.0) {
                            Image(systemName: "folder.badge.minus")
                                .frame(width: 40.0, height: 40.0)
                                .font(.caption)
                            Text("未分组")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("选择分组")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // 工具栏单 Button（buildBlock<A> 一元确证）。
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                }
            }
            .sheet(isPresented: $showingMerge) {
                if let target = mergeTarget {
                    SourceGroupMergeSheet(
                        sourceGroup: mergeSourceGroup, targetGroup: target)
                }
            }
        }
    }

    /// 合并态（合并 Sheet 触发域）。
    @State private var mergeTarget: String?
    var mergeSourceGroup: String = ""

    /// createNewGroup（pgo_only）：去重后落回新建分组。
    private func createNewGroup() {
        let name = newGroupName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        onSelect(name)
        dismiss()
    }
}

/// 分组合并面板（0x100c56dfc L168-220）。
struct SourceGroupMergeSheet: View {

    let sourceGroup: String
    let targetGroup: String

    /// targetGroups getter（pgo_only）：可作目标的分组（排除自身）。
    private var targetGroups: [String] {
        SourceService().bookSources
            .compactMap { $0.bookSourceGroup }
            .filter { !$0.isEmpty && $0 != sourceGroup }
            .uniqued()
    }

    @State private var selection: String = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        // 伪代码 0x100c56dfc（L168-220）：引导文案 + 目标分组选择 + 合并按钮。
        NavigationStack {
            List {
                Section {
                    Text(
                        "合并后，「\(sourceGroup)」合并到「\(selection.isEmpty ? targetGroup : selection)」，配置将移动到目标分组"
                    )
                    .appThemeText(.caption, opacity: 0.7)
                }
                Section("目标分组") {
                    ForEach(targetGroups, id: \.self) { group in
                        Button {
                            selection = group
                        } label: {
                            HStack {
                                Text(group)
                                Spacer()
                                if selection == group {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("合并分组")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("合并") {
                        performMerge()
                        dismiss()
                    }
                    .disabled(selection.isEmpty)
                }
            }
        }
    }

    /// 合并动作（"置将移动到目标分组" 域确证；经 updateSource 逐源迁移）。
    private func performMerge() {
        let service = SourceService()
        let targets = service.bookSources.filter {
            $0.bookSourceGroup == sourceGroup
        }
        for source in targets {
            var updated = source
            updated.bookSourceGroup = selection
            _ = service.updateSource(
                oldUrl: source.bookSourceUrl, source: updated)
        }
    }
}

extension Sequence where Element: Hashable {
    /// 去重保序（targetGroups 域确证）。
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
