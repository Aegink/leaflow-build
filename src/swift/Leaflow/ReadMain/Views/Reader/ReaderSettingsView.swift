// 原路径: ReadMain/Views/Reader/ReaderSettingsView.swift
// 证据:
//   - PGO: 主函数（index/task_functions.csv T-301-09 / ReaderSettingsView.swift），
//     地址：body 0x1007d4d88 L54-68（+NavigationStack 闭包 0x1007d5310 L55-63 /
//     settingsContent 闭包 0x1007d5dcc L57-59 / toolbar 闭包 0x1007d78a8 L86-103 /
//     Button 闭包 0x1007d79f0 L87-92 / frame 闭包 0x1007d8040 L94-102）/
//     themeAndInterfaceSettings 0x1007d7314 L108-151
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Reader/ReaderSettingsView.c（25602 行）
//   - 事实：body = NavigationStack + settingsContent + toolbar(Button 完成键) +
//     presentationDetents(.height)（L94-102 确证）；
//     themeAndInterfaceSettings（L108-151）：Edge.Set.all + SafeAreaRegions.all 确证
//   状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - body 结构/装饰链: high（builder opaque 描述确证）
//   - 深层分区（25602 行内其余分区）: structural（按主链还原，细节待真机对照）
// 还原: 2026-11-19

import SwiftUI

/// 阅读器设置面板（模态，detent 高度确证）。
struct ReaderSettingsView: View {
    @Binding var settings: ReadingSettings
    var onDismiss: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        // 伪代码 0x1007d4d88（L54-68）。
        NavigationStack {
            settingsContent
                .ignoresSafeArea(.all, edges: .all)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("完成") {
                            onDismiss()
                            dismiss()
                        }
                    }
                }
                .presentationDetents([.height(420)])
        }
    }

    /// 设置内容主链（settingsContent 闭包 0x1007d5dcc 确证）。
    @ViewBuilder
    private var settingsContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                themeAndInterfaceSettings
                LayoutSettingsSection(settings: $settings)
            }
            .padding(.horizontal)
        }
        .navigationTitle("阅读设置")
    }

    /// 伪代码 0x1007d7314（L108-151）：主题与界面分区
    ///（Edge.Set.all + SafeAreaRegions.all 确证）。
    private var themeAndInterfaceSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("主题与界面")
                .appThemeText(.headline)
            ReaderBrowserSettingsView(
                presentation: Binding(
                    get: { settings.paragraphCommentBrowser },
                    set: { settings.paragraphCommentBrowser = $0 }))
            // T-1601-E2：工具栏图标设置入口（ReaderToolbarIconSettingsView
            // 此前零引用）。
            NavigationLink {
                ReaderToolbarIconSettingsView()
            } label: {
                HStack {
                    Label("工具栏图标", systemImage: "wrench.and.screwdriver")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.all)
        .safeAreaPadding(.all)
    }
}
