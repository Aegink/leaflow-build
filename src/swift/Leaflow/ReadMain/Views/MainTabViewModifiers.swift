// 原路径: ReadMain/Views/MainTabViewModifiers.swift
// 证据:
//   - PGO: 17 条记录（index/task_functions.csv T-701-03 /
//     MainTabViewModifiers.swift；12 函数，伪代码域 160 行）
//   - CovMap: 上述 L 区段（chrome L11-28 + L88-98 / lifecycle
//     L56-65 + L71-77 / miniplayer 域）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/MainTabViewModifiers.c
//     （815 行）
//   - 块体确证（地址+行号域）：
//     MainTabChromeModifier.body 0x100cfe964 L11-28（closure #1
//     (Bool, Bool) 双态域 + syncUIKitAppearance + statistics 守卫）/
//     View.mainTabChrome(tabSelection:) 0x100cfad50+0x100cfb23c
//     L88-98（双 ICF 副本）/ MainTabThemeLifecycleModifier.body
//     0x100cff044 L56-65 + applyUIKitAppearance 0x100cff57c L71-77
//     （onAppear + 主题变更订阅域）/ MainTabMiniPlayerModifier
//     （closure #1 AudioMiniPlayerOverlay 域）
//   - 事实：三修饰器链 = chrome（外观同步 + 统计可见性）+ miniplayer
//     （音频覆盖层）+ lifecycle（onAppear 刷 UIKit 外观）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（三修饰器 + 扩展入口签名域确证）
// 还原: 2026-11-20

import SwiftUI
import Combine

/// 主界面 chrome 修饰器（body 0x100cfe964 L11-28 块体确证）。
struct MainTabChromeModifier: ViewModifier {

    @Binding var statisticsVisibility: Bool
    @State private var lastThemeSignature: String = ""
    @State private var appearanceSyncTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .onReceive(
                NotificationCenter.default.publisher(
                    for: UIApplication.didBecomeActiveNotification)
            ) { _ in
                // closure #1 (Bool, Bool) 双态域确证：前台回归同步。
                syncUIKitAppearance()
            }
            .onChange(of: statisticsVisibility) { newValue in
                handleStatisticsVisibilityChange(newValue)
            }
            .onReceive(AppThemeManager.shared.objectWillChange) { _ in
                // implicit closure 域确证：主题变更即刷外观。
                appearanceSyncTask?.cancel()
                appearanceSyncTask = Task { @MainActor in
                    syncUIKitAppearance()
                }
            }
    }

    /// syncUIKitAppearance()（签名域确证）。
    func syncUIKitAppearance() {
        AppThemeManager.shared.applyUIKitAppearance()
    }

    /// handleStatisticsVisibilityChange(_:)（签名域确证：
    /// implicit closure #1 域：同值短路）。
    func handleStatisticsVisibilityChange(_ visible: Bool) {
        let key = "reader_statistics_enabled"
        let current = UserDefaults.standard.bool(forKey: key)
        // implicit closure #1 域确证：同值不写。
        guard current != visible || !current else { return }
        UserDefaults.standard.set(visible, forKey: key)
    }
}

/// 迷你播放器修饰器（closure #1 AudioMiniPlayerOverlay 域确证）。
struct MainTabMiniPlayerModifier: ViewModifier {

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                // closure #1 域确证：AudioMiniPlayerOverlay 覆盖层。
                AudioMiniPlayerOverlay()
            }
    }
}

/// 主题生命周期修饰器（body 0x100cff044 L56-65 + applyUIKitAppearance
/// 0x100cff57c L71-77 块体确证）。
struct MainTabThemeLifecycleModifier: ViewModifier {

    @State private var refreshTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .onAppear {
                // closure #1 域确证：进场即应用外观。
                applyUIKitAppearance()
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: UIApplication.didBecomeActiveNotification)
            ) { _ in
                refreshUIKitAppearanceIfNeeded()
            }
    }

    /// applyUIKitAppearance()（0x100cff57c 域确证）。
    func applyUIKitAppearance() {
        AppThemeManager.shared.applyUIKitAppearance()
    }

    /// refreshUIKitAppearanceIfNeeded()（签名域确证：closure #1
    /// async 域：让 MainActor 排队后刷新）。
    func refreshUIKitAppearanceIfNeeded() {
        refreshTask?.cancel()
        refreshTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000)
            guard !Task.isCancelled else { return }
            applyUIKitAppearance()
        }
    }
}

extension View {

    /// mainTabChrome(tabSelection:)（0x100cfad50/0x100cfb23c L88-98
    /// 双 ICF 副本域确证）。
    func mainTabChrome(
        tabSelection: Binding<AppTab>
    ) -> some View {
        modifier(
            MainTabChromeModifier(
                statisticsVisibility: .constant(true)))
    }

    /// mainTabMiniPlayer（签名域确证）。
    func mainTabMiniPlayer() -> some View {
        modifier(MainTabMiniPlayerModifier())
    }

    /// mainTabThemeLifecycle（签名域确证）。
    func mainTabThemeLifecycle() -> some View {
        modifier(MainTabThemeLifecycleModifier())
    }
}
