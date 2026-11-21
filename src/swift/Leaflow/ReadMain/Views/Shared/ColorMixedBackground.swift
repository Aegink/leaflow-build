// 原路径: ReadMain/Views/Shared/ColorMixedBackground.swift
// 证据:
//   - PGO: 14 条记录（index/task_functions.csv T-701-12 /
//     ColorMixedBackground.swift；伪代码域 110 行）
//   - CovMap: 上述 L 区段（bg/primaryColor/gradientColors/intensity/
//     liquidGlass 域）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Shared/
//     ColorMixedBackground.c（889 行）
//   - 块体确证（签名域）：
//     bg getter / primaryColor getter / gradientColors getter /
//     intensity getter / currentBackgroundImage getter /
//     currentBackgroundOpacity getter / backgroundImageView
//     (_: UIImage, opacity: Double) / liquidGlassBackground getter
//   - 字符串域：无用户字符串（纯视图域）
//   - 事实：Tab 背景合成视图（纯色/渐变/图三态 + 强度域）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（八签名域确证）
// 还原: 2026-11-20

import SwiftUI

/// 主题背景合成视图（bg/primaryColor/gradientColors 签名域确证）。
struct ColorMixedBackground: View {

    @Environment(\.colorScheme) private var colorScheme

    /// bg getter（签名域确证：当前 Tab 背景委托）。
    private var bg: TabBackground {
        AppThemeManager.shared.background(for: .bookshelf)
    }

    /// primaryColor getter（签名域确证：明暗主色分派）。
    private var primaryColor: Color {
        colorScheme == .dark
            ? bg.darkPrimaryColor
            : bg.lightPrimaryColor
    }

    /// gradientColors getter（签名域确证：主/次色渐变域）。
    private var gradientColors: [Color] {
        colorScheme == .dark
            ? [bg.darkPrimaryColor, bg.darkSecondaryColor]
            : [bg.lightPrimaryColor, bg.lightSecondaryColor]
    }

    /// intensity getter（签名域确证：glowIntensity 委托）。
    private var intensity: Double {
        AppThemeManager.shared.glowIntensity
    }

    /// currentBackgroundImage getter（签名域确证：明暗图分派）。
    private var currentBackgroundImage: UIImage? {
        colorScheme == .dark
            ? bg.decodedDarkBackgroundImage()
            : bg.decodedBackgroundImage()
    }

    /// currentBackgroundOpacity getter（签名域确证）。
    private var currentBackgroundOpacity: Double {
        colorScheme == .dark
            ? bg.darkBackgroundImageOpacity
            : bg.backgroundImageOpacity
    }

    var body: some View {
        // 合成域：图 → 渐变 → 纯色三态（backgroundImageView 域确证）。
        ZStack {
            if let image = currentBackgroundImage {
                backgroundImageView(image, opacity: currentBackgroundOpacity)
            } else {
                LinearGradient(
                    colors: gradientColors,
                    startPoint: .top,
                    endPoint: .bottom)
            }
        }
        .ignoresSafeArea()
    }

    /// backgroundImageView(_:opacity:)（签名域确证：图 + 主色叠加）。
    @ViewBuilder
    private func backgroundImageView(
        _ image: UIImage, opacity: Double
    ) -> some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .opacity(opacity)
            .overlay(
                primaryColor.opacity(1 - opacity))
    }

    /// liquidGlassBackground getter（签名域确证：毛玻璃态桥）。
    private var liquidGlassBackground: some View {
        LinearGradient(
            colors: gradientColors,
            startPoint: .top,
            endPoint: .bottom)
            .opacity(intensity)
    }
}
