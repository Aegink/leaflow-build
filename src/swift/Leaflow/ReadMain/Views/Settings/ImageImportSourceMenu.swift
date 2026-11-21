// 原路径: ReadMain/Views/Settings/ImageImportSourceMenu.swift
// 证据:
//   - PGO: 15 条记录（index/task_functions.csv T-701-06 /
//     ImageImportSourceMenu.swift；伪代码域 40 行）
//   - CovMap: 上述 L 区段（body/themeAccentColor 域）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Settings/
//     ImageImportSourceMenu.c（584 行）
//   - 块体确证（签名域）：
//     body getter（Menu 双项域）/ themeAccentColor getter
//   - 字符串域（位模式，scratch/t70106_menu_strings.txt）：
//     '从相册导入' L133 / '从文件导入' L174 / '移除全部' L1492
//   - 事实：三动作菜单（相册/文件/移除全部）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（双签名域 + 三动作字符串链确证）
// 还原: 2026-11-20

import SwiftUI

/// 图片导入来源菜单（body/themeAccentColor 签名域确证）。
struct ImageImportSourceMenu: View {

    var onPickFromPhotos: () -> Void = {}
    var onPickFromFiles: () -> Void = {}
    var onRemoveAll: () -> Void = {}
    var hasItems: Bool = false

    /// themeAccentColor getter（签名域确证）。
    private var themeAccentColor: Color {
        AppThemeManager.shared.accentColor(
            for: AppThemeManager.shared.appAppearanceColorScheme)
    }

    var body: some View {
        Menu {
            // '从相册导入' L133 域确证。
            Button {
                onPickFromPhotos()
            } label: {
                Label("从相册导入", systemImage: "photo.on.rectangle")
            }
            // '从文件导入' L174 域确证。
            Button {
                onPickFromFiles()
            } label: {
                Label("从文件导入", systemImage: "folder")
            }
            if hasItems {
                Divider()
                Button(role: .destructive) {
                    // '移除全部' L1492 域确证。
                    onRemoveAll()
                } label: {
                    Label("移除全部", systemImage: "trash")
                }
            }
        } label: {
            Image(systemName: "plus.circle")
                .foregroundStyle(themeAccentColor)
        }
    }
}
