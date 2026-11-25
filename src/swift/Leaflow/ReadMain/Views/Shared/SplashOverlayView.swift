// 原路径: ReadMain/Views/Shared/SplashOverlayView.swift
// 证据:
//   - PGO: 8 个主函数（index/task_functions.csv T-101-06 / SplashOverlayView.swift），
//     地址：init duration 闭包 0x100b6ec60 L27-27 / body 0x100b6e1b0 L31-46
//     （+closure #1 0x100b6e50c ignoresSafeArea / scaledToFill 闭包 ×2）/
//     closure #2 0x100b6e5cc L45 / startTimerIfNeeded 0x100b6e7e4 L50-57
//     （+async closure）/ resolveSplash 0x100b6da78 L62-85
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Shared/SplashOverlayView.c（696 行）
//   - 事实：resolveSplash —— SplashOverlayTheme.splashImageDatas(for:)（确证）解析启动图 +
//     时长；body —— 全屏图（scaledToFill + ignoresSafeArea）+ 定时消失；
//     startTimerIfNeeded —— async 延迟关闭
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（resolve 链/scaledToFill/定时确证）
// 还原: 2026-11-19

import SwiftUI
import UIKit

/// 启动图覆盖层（主题启动图 + 定时消失）。
struct SplashOverlayView: View {

    @State private var splash: (image: UIImage, duration: Double)?
    @State private var isVisible = false

    init() {
        // 伪代码 0x100b6ec60（L27-27）：初始时长闭包（resolveSplash duration 参与）。
    }

    var body: some View {
        // 伪代码 0x100b6e1b0（L31-46）+ closure #1（0x100b6e50c）。
        ZStack {
            if isVisible, let splash {
                Image(uiImage: splash.image)
                    .resizable()
                    .scaledToFill() // scaledToFill 闭包 ×2 确证
                    .ignoresSafeArea(.all, edges: .all)
                    .transition(.opacity)
            }
        }
        .onAppear {
            startTimerIfNeeded()
        }
    }

    /// 伪代码 0x100b6e7e4（L50-57）+ async closure：装配 + 定时。
    private func startTimerIfNeeded() {
        guard splash == nil else { return }
        guard let resolved = Self.resolveSplash() else { return }
        splash = resolved
        isVisible = true
        Task {
            try? await Task.sleep(
                nanoseconds: UInt64(resolved.duration * 1_000_000_000))
            isVisible = false
        }
    }

    /// 伪代码 0x100b6da78（L62-85）：SplashOverlayTheme.splashImageDatas(for:)（确证）
    /// 解析启动图与时长。
    @MainActor
    static func resolveSplash() -> (image: UIImage, duration: Double)? {
        let manager = AppThemeManager.shared
        let theme = manager.currentTheme
        guard theme.splashEnabled,
              let data = SplashOverlayTheme.splashImageDatas(
                for: manager.activeThemeModeIsDark ? .dark : .light).first,
              let image = UIImage(data: data) else { return nil }
        return (image, max(0.5, min(6, theme.splashDuration)))
    }
}

/// 主题启动图数据源（resolveSplash 调用确证；实现域 T-701）。
enum SplashOverlayTheme {
    enum SplashVariant {
        case light
        case dark
    }

    @MainActor
    static func splashImageDatas(for variant: SplashVariant) -> [Data] {
        AppThemeManager.shared.currentTheme.splashImageDatas(
            for: variant == .dark ? .dark : .light)
    }
}

extension View {
    /// splashOverlay()（LeaflowApp body 消费域确证，wave-16 补桥）——
    /// SplashOverlayView 叠加层挂点。
    func splashOverlay() -> some View {
        overlay(SplashOverlayView())
    }
}
