// 原路径: ReadMain/Views/Settings/CloudDriveSettingsView.swift
// 证据:
//   - PGO: 43 条记录（index/task_functions.csv T-701-05 /
//     CloudDriveSettingsView.swift；伪代码域 100 行）
//   - CovMap: 上述 L 区段（destinationsSection 0x100a13c6c L58-103 /
//     destinationRow 0x100a17b14 L126-149 / addSection 域）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Settings/
//     CloudDriveSettingsView.c（1736 行）
//   - 块体确证（地址+行号域）：
//     destinationsSection 0x100a13c6c L58-103（目的地区元组域）/
//     destinationRow(title:systemImage:subtitle:isActive:isEnabled:
//     onSelect:) 0x100a17b14 L126-149（行构造签名全参确证）/
//     addSection getter / SheetItem（id/config getter 签名域）/
//     isICloudAvailable getter / body（双 Section 元组域）
//   - 字符串域（位模式+指针，scratch/t70105_cloud_strings.txt）：
//     '备份目的地' L274 / '删除' L422/L1048 / '取消' L440 / '编辑'
//     L1105 / '」吗？' L1257 / 'iCloud 云盘' L698
//   - 事实：目的地区（iCloud + WebDAV 列表）+ 添加区；WebDAVConfig/
//     BackupDestination 引用归 T-901-03/04 分册（现骨架签名域）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（destinationRow 全参签名 + 字符串域确证）
// 还原: 2026-11-20

import SwiftUI

/// 网盘同步设置（destinationsSection 0x100a13c6c L58-103 域确证）。
struct CloudDriveSettingsView: View {

    /// 编辑弹层条目（SheetItem config/id getter 签名域确证）。
    struct SheetItem: Identifiable {
        let id: String
        let name: String
        let config: WebDAVConfig?
    }

    @State private var destinations: [(name: String, config: WebDAVConfig?)]
        = [("iCloud 云盘", nil)]
    @State private var editSheet: SheetItem?
    @State private var deleteTarget: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                destinationsSection
                addSection
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .navigationTitle("网盘同步")
        .sheet(item: $editSheet) { item in
            WebDAVEditView(existingConfig: item.config)
        }
        .alert(
            "删除目的地",
            isPresented: Binding(
                get: { deleteTarget != nil },
                set: { if !$0 { deleteTarget = nil } })
        ) {
            Button("删除", role: .destructive) {
                if let target = deleteTarget {
                    destinations.removeAll { $0.name == target }
                }
                deleteTarget = nil
            }
            Button("取消", role: .cancel) {
                deleteTarget = nil
            }
        } message: {
            if let target = deleteTarget {
                // '」吗？' L1257 域确证。
                Text("确定要删除「\(target)」吗？")
            }
        }
    }

    /// isICloudAvailable getter（签名域确证）。
    private var isICloudAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    /// destinationsSection（0x100a13c6c L58-103 域确证）。
    @ViewBuilder
    private var destinationsSection: some View {
        Text("备份目的地")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 16)
        ForEach(destinations, id: \.name) { destination in
            destinationRow(
                title: destination.name,
                systemImage: destination.config == nil
                    ? "icloud" : "externaldrive.connected.to.icloud",
                subtitle: destination.config?.url,
                isActive: destination.config == nil
                    ? isICloudAvailable : true,
                isEnabled: true,
                onSelect: {
                    // '编辑' L1105 域确证。
                    editSheet = SheetItem(
                        id: destination.name, name: destination.name,
                        config: destination.config)
                },
                onDelete: destination.config == nil ? nil : {
                    deleteTarget = destination.name
                })
        }
    }

    /// addSection（签名域确证）。
    @ViewBuilder
    private var addSection: some View {
        settingsCardRow(topGap: 12) {
            Button {
                editSheet = SheetItem(
                    id: UUID().uuidString, name: "新 WebDAV",
                    config: nil)
            } label: {
                HStack {
                    AppThemeSettingsLabel(
                        title: "添加 WebDAV", systemImage: "plus.circle")
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    /// destinationRow(title:systemImage:subtitle:isActive:isEnabled:
    /// onSelect:onDelete:)（0x100a17b14 L126-149 全参签名确证）。
    @ViewBuilder
    private func destinationRow(
        title: String, systemImage: String, subtitle: String?,
        isActive: Bool, isEnabled: Bool, onSelect: @escaping () -> Void,
        onDelete: (() -> Void)? = nil
    ) -> some View {
        settingsCardRow(topGap: 12, action: isEnabled ? onSelect : nil) {
            HStack {
                AppThemeSettingsLabel(
                    title: title, systemImage: systemImage)
                Spacer()
                if let subtitle {
                    Text(subtitle)
                        .lineLimit(1)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if isActive {
                    Text("在线")
                        .font(.caption)
                        .appThemeAccent()
                }
                if let onDelete {
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.borderless)
                }
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .opacity(isEnabled ? 1 : 0.5)
        }
    }
}
