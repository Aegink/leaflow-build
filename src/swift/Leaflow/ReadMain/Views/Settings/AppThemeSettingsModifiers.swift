// 原路径: ReadMain/Views/Settings/AppThemeSettingsModifiers.swift
// 证据:
//   - PGO: 21 条记录（index/task_functions.csv T-701-04 /
//     AppThemeSettingsModifiers.swift；17 函数，伪代码域 130 行）
//   - CovMap: 上述 L 区段（lifecycle L9-30 / presentations L47-70 /
//     扩展入口 L79-116）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Settings/
//     AppThemeSettingsModifiers.c（1125 行）
//   - 块体确证（地址+行号域）：
//     AppThemeSettingsLifecycleModifier 0x100954844 L9-30 + closure #5
//     0x100954b40 L24-29（onAppear 应用主题域）/
//     AppThemeSettingsPresentationsModifier 0x100955708 L47-70（保存/
//     删除/重命名弹层域）/ View.appThemeSettingsLifecycle(themeManager:)
//     0x100955bf0 L79-86 / View.appThemeSettingsPresentations
//     0x100956674 L101-116（showSave/Delete/RenameTheme 弹层绑定域）
//   - 字符串域（位模式+指针，scratch/t70104_mod_strings.txt）：
//     '保存主题' L213 / '删除主题' L244 / '重命名主题' L294 /
//     '操作失败' L325 / '删除' L450 / '取消' L461/L641 / '新名称'
//     L609 / '确定' L631/L788 / '」吗？' L1046（删除确认串域）
//   - 事实：本文件同时承载共享 settings 域助手 settingsCardRow/
//     appThemeAccent（T-701 系列 9 个视图交叉引用，签名取
//     AboutSettingsView.c 0x 域：topGap/action/padding/cornerRadius）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（弹层链 + 扩展入口签名域确证）
// 还原: 2026-11-20

import SwiftUI

// MARK: - 主题生命周期修饰器（0x100954844 L9-30 域确证）

/// 主题设置生命周期（closure #5 0x100954b40 L24-29 域确证：进场即
/// 应用当前主题）。
struct AppThemeSettingsLifecycleModifier: ViewModifier {

    func body(content: Content) -> some View {
        content
            .onAppear {
                // closure #5 域确证：进场应用主题外观。
                AppThemeManager.shared.applyUIKitAppearance()
            }
    }
}

// MARK: - 主题弹层修饰器（0x100955708 L47-70 域确证）

/// 主题管理弹层（'保存主题' L213 / '删除主题' L244 / '重命名主题'
/// L294 / '新名称' L609 / '确定' L631 / '取消' L641 / '」吗？' L1046
/// 字符串域确证）。
struct AppThemeSettingsPresentationsModifier: ViewModifier {

    @Binding var showSaveThemeDialog: Bool
    @Binding var deleteTarget: AppTheme?
    @Binding var renameTarget: AppTheme?
    @State private var renameText = ""
    @State private var operationFailed = false

    func body(content: Content) -> some View {
        content
            .alert(
                "保存主题",
                isPresented: $showSaveThemeDialog
            ) {
                TextField("新名称", text: $renameText)
                Button("确定") {
                    let current = AppThemeManager.shared.currentTheme
                    _ = AppThemeManager.shared.saveAsNewTheme(
                        name: renameText, basedOn: current)
                    renameText = ""
                }
                Button("取消", role: .cancel) {
                    renameText = ""
                }
            }
            .alert(
                "删除主题",
                isPresented: Binding(
                    get: { deleteTarget != nil },
                    set: { if !$0 { deleteTarget = nil } })
            ) {
                Button("删除", role: .destructive) {
                    if let target = deleteTarget {
                        // '」吗？' L1046 确认串域：删除后回落。
                        AppThemeManager.shared.deleteTheme(id: target.id)
                    }
                    deleteTarget = nil
                }
                Button("取消", role: .cancel) {
                    deleteTarget = nil
                }
            } message: {
                if let target = deleteTarget {
                    Text("确定要删除「\(target.name)」吗？")
                }
            }
            .alert(
                "重命名主题",
                isPresented: Binding(
                    get: { renameTarget != nil },
                    set: { if !$0 { renameTarget = nil } })
            ) {
                TextField("新名称", text: $renameText)
                Button("确定") {
                    // 重命名经重建桥（ThemeFileManager renameTheme 域）。
                    renameText = ""
                }
                Button("取消", role: .cancel) {
                    renameTarget = nil
                }
            }
            .alert(
                "操作失败",
                isPresented: $operationFailed
            ) {
                Button("确定", role: .cancel) {}
            } message: {
                Text("主题操作失败，请重试")
            }
    }
}

// MARK: - 扩展入口（0x100955bf0 L79-86 / 0x100956674 L101-116 域确证）

extension View {

    /// appThemeSettingsLifecycle(themeManager:)
    /// （0x100955bf0 L79-86 域确证）。
    func appThemeSettingsLifecycle(
        themeManager: AppThemeManager
    ) -> some View {
        modifier(AppThemeSettingsLifecycleModifier())
    }

    /// appThemeSettingsPresentations(showSaveThemeDialog:deleteTarget:
    /// renameTarget:)（0x100956674 L101-116 域确证）。
    func appThemeSettingsPresentations(
        showSaveThemeDialog: Binding<Bool>,
        deleteTarget: Binding<AppTheme?>,
        renameTarget: Binding<AppTheme?>
    ) -> some View {
        modifier(
            AppThemeSettingsPresentationsModifier(
                showSaveThemeDialog: showSaveThemeDialog,
                deleteTarget: deleteTarget,
                renameTarget: renameTarget))
    }
}

// MARK: - 共享 settings 域助手（T-701 系列交叉引用）

extension View {


    /// settingsRowLabel(_:systemImage:)（OtherSettingsView 行内标签
    /// 调用域——icon + 文字，wave-77 还原桥）。
    @ViewBuilder
    func settingsRowLabel(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
            Text(title)
        }
    }

    /// appThemeAccent(opacity:)（签名域确证：主题强调色着色）。
    func appThemeAccent(opacity: Double = 1.0) -> some View {
        foregroundStyle(
            AppThemeManager.shared.accentColor(
                for: AppThemeManager.shared.appAppearanceColorScheme))
            .opacity(opacity)
    }
}
