// 原路径: ReadMain/Views/Shared/AppThemeTextStyle.swift
// 证据:
//   - PGO: 21 条记录（index/task_functions.csv T-701-12 /
//     AppThemeTextStyle.swift；伪代码域 160 行）
//   - CovMap: 上述 L 区段（label 域 L20-140 / modifier 域 L9-30 /
//     tint 扩展 L171-173）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Shared/
//     AppThemeTextStyle.c（629 行）
//   - 块体确证（地址+行号域）：
//     AppThemeSettingsLabel.body 0x100b41xxx L130-139（Image(systemName:)
//     + AppThemeManager.accentColor(for:) 域 + themeColorScheme getter
//     + MainActor 执行器域 "Leaflow/AppThemeTextStyle.swift" 31,1,139）/
//     closure #1 0x100b41ef0 L136-139（AppThemeTextStyleModifier 域）/
//     AppThemeTextStyleModifier.body(content:)（0x 域 L9-30）/
//     View.appThemeTint(_:opacity:) 0x1004c0cf8 L171-173
//   - 字符串域：无用户字符串（诊断域 'Leaflow/AppThemeTextStyle.swift'
//     + 'Leaflow/ExploreBookDetailView.swift' 35,1,455 执行器报告）
//   - 事实：AppThemeTextLevel 三档（primary/secondary/tertiary，
//     AppTheme.textColor 0x100184498 块体分派交叉确证）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（三签名域 + accent 域确证）
// 还原: 2026-11-20

import SwiftUI

/// 主题文字级别（AppTheme.textColor 0x100184498 块体三档分派 +
/// appThemeText(_:opacity:) 引用域确证）。
enum AppThemeTextLevel: String, Codable, CaseIterable {
    case primary
    case secondary
    case tertiary

    /// 视觉字号档（settings 标签域）。
    var font: Font {
        switch self {
        case .primary: return .body
        case .secondary: return .subheadline
        case .tertiary: return .caption
        }
    }
}

/// 设置标签（init(_:systemImage:titleLevel:) 签名域 + body 域确证：
/// 图标走 accent 色，文字走主题文字色）。
struct AppThemeSettingsLabel: View {

    let title: String
    let systemImage: String
    var titleLevel: AppThemeTextLevel = .primary

    /// init(_:systemImage:titleLevel:)（签名域确证）。
    init(
        _ title: String, systemImage: String,
        titleLevel: AppThemeTextLevel = .primary
    ) {
        self.title = title
        self.systemImage = systemImage
        self.titleLevel = titleLevel
    }

    /// themeColorScheme getter（签名域确证）。
    @Environment(\.colorScheme) private var themeColorScheme

    var body: some View {
        // body 0x 域确证：Image(systemName:) + accentColor(for:)。
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .appThemeTint(.primary, opacity: 0.9)
            Text(title)
                .font(titleLevel.font)
                .appThemeText(titleLevel, opacity: 1.0)
        }
    }
}

/// 主题文字样式修饰器（body(content:) 域确证：文字色随明暗分派）。
struct AppThemeTextStyleModifier: ViewModifier {

    let level: AppThemeTextLevel
    let opacity: Double

    func body(content: Content) -> some View {
        content
            .foregroundStyle(
                AppThemeManager.shared.textColor(
                    level,
                    for: AppThemeManager.shared
                        .appAppearanceColorScheme)
            )
            .opacity(opacity)
    }
}

extension View {

    /// appThemeText(_:opacity:)（T-701 系列 40+ 视图引用域确证）。
    func appThemeText(
        _ level: AppThemeTextLevel, opacity: Double = 1.0
    ) -> some View {
        modifier(AppThemeTextStyleModifier(level: level, opacity: opacity))
    }

    /// appThemeTint(_:opacity:)（0x1004c0cf8 L171-173 域确证）。
    func appThemeTint(
        _ level: AppThemeTextLevel, opacity: Double = 1.0
    ) -> some View {
        foregroundStyle(
            AppThemeManager.shared.accentColor(
                for: AppThemeManager.shared.appAppearanceColorScheme))
            .opacity(opacity)
    }
}
