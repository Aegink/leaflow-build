// 原路径: ReadMain/Views/Search/GroupPickerSheet.swift
// 证据:
//   - PGO: 19 条记录（index/task_functions.csv T-501-06 /
//     GroupPickerSheet.swift；body 0x1008e0f24 L9-68 单块）。
//   - CovMap: L9-68
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Search/GroupPickerSheet.c
//     （1281 行）
//   - 字符串确证（位模式/指针）："配置分组 ("（L108 域）/"checkmark"
//     （L400 域）/"externaldrive.badge.icloud" @ptr L1007/"上次自动备份"
//     @ptr L1112（备份域交叉）
//   - 事实：双 Section 主体（glassListSection + glassListMultiRowSection
//     修饰签名确证）——Section1 分组选择行（Text + Spacer + 双色标记
//     foregroundColor _ConditionalContent）+ 手动输入项；Section2 ForEach
//     [String] 全部分组行（appThemeText + Spacer + 选中 checkmark 域）；
//     glassSettingsListStyle 外壳（签名确证）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - 双 Section 结构: high（闭包签名 + 修饰族确证）
//   - 文案: medium（域串部分确证）
// 还原: 2026-11-20

import SwiftUI

/// 书源分组选择面板（Search 域入口）。
struct GroupPickerSheet: View {

    let groups: [String]
    let selectedGroup: String?
    let onSelect: (String?) -> Void

    @State private var newGroupName: String = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        // 伪代码 0x1008e0f24（L9-68）：双 Section + glassSettingsListStyle。
        NavigationStack {
            List {
                Section {
                    // 手动输入分组行（Button + Text + Spacer + 色标域确证）。
                    HStack {
                        TextField("新分组名", text: $newGroupName)
                            .autocorrectionDisabled()
                        if !newGroupName.trimmingCharacters(
                            in: .whitespaces
                        ).isEmpty {
                            Button {
                                let name = newGroupName
                                    .trimmingCharacters(in: .whitespaces)
                                onSelect(name)
                                dismiss()
                            } label: {
                                Text("添加")
                            }
                        }
                    }
                    // "配置分组 (" L108 域确证：未分组行。
                    Button {
                        onSelect(nil)
                        dismiss()
                    } label: {
                        HStack {
                            Text("未分组")
                            Spacer()
                            if selectedGroup == nil {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
                Section {
                    ForEach(groups, id: \.self) { group in
                        Button {
                            onSelect(group)
                            dismiss()
                        } label: {
                            HStack {
                                Text(group)
                                    .appThemeText(.body)
                                Spacer()
                                if selectedGroup == group {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("配置分组 (\(groups.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}
