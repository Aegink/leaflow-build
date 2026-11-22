// 原路径: ReadMain/Views/MainTabView.swift
// 证据:
//   - PGO: 33 条记录（index/task_functions.csv T-701-03 /
//     MainTabView.swift；20 函数，伪代码域 230 行）
//   - CovMap: 上述 L 区段（signature L30-39 / body L41-50 /
//     selectedTabRoot L54-61 / tabLabel L72-77 / 双 TabView 域
//     L89-160）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/MainTabView.c（1152
//     行，20 块索引 0x100cf8c1c-0x100cfd5e4）
//   - 块体确证（地址+行号域）：
//     tabAppearanceSignature 0x100cf8c1c L30-39（AppThemeUpdateImpact
//     域 + ':' 0x3A join L169 + 组件 'dark' 0x6461726B L82-84 /
//     'light' 0x746867696C L88-89 + 'textHidden'
//     0x6464694874786574/'textVisible' 0x6973695674786574 L98-105 +
//     tabIconSize round L131 + 'classic' 0x63697373616C63/'modern'
//     0x6E7265646F6D L140-148 + 'statistics' 0x6974736974617473/
//     'static' 0x7369746174536F6E L155-163）/ body 0x100cf9184
//     L41-50（SidebarAdaptableTabViewStyle + tabBarMinimizeBehavior
//     条件域）/ selectedTabRoot closure 0x100cf963c L54-61
//     （TabView(selection:) + TupleView）/ tabLabel closure #1
//     0x100cfa26c L72-74（Text(name) 域）/ 五 Tab 域：BookshelfView/
//     ExploreView/ReadingStatsView/SettingsView/SearchView
//     （nativeSearchTabView closure #1/#3/#5/#7/#9 域）
//   - 事实：AppTab 五档（bookshelf/explore/statistics/settings/
//     search，statistics 经 handleStatisticsVisibilityChange 条件域）；
//     统计页可隐藏（TupleView 第三 tag optional 域）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（签名串五组件 + 双 TabView 结构块体确证）
// 还原: 2026-11-20

import SwiftUI

/// 主界面 Tab 选择（'statistics' 0x6974736974617473 L157 域确证
/// statistics 档；五档经 nativeSearchTabView buildBlock 五元组）。
enum AppTab: String, Hashable, CaseIterable {
    case bookshelf
    case explore
    case statistics
    case settings
    case search
}

/// 主 Tab 视图（body 0x100cf9184 L41-50 域确证：SidebarAdaptable
/// 风格 + 滚动收起条件域）。
struct MainTabView: View {

    /// 默认 Tab（冒烟域：CI 传 -smokeSettings 直启设置页；
    /// -smokeSources 也需先选设置 Tab，由 SettingsView.onAppear 追加
    /// 书源管理路由——T-1601-E1 验收入口）。
    @State private var selection: AppTab = {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-smokeSettings")
            || arguments.contains("-smokeSources") {
            return .settings
        }
        return .bookshelf
    }()
    @State private var showStatisticsTab = true
    @Environment(\.colorScheme) private var systemColorScheme

    /// tabAppearanceSignature getter（0x100cf8c1c L30-39 块体确证：
    /// 五组件 ':' join）。
    private var tabAppearanceSignature: String {
        let theme = AppThemeManager.shared.currentTheme
        let impact = AppThemeUpdateImpact(
            previous: theme, updated: theme)
        let scheme: String =
            AppThemeManager.shared.effectiveColorScheme(
                for: systemColorScheme) == .dark ? "dark" : "light"
        let textVisibility: String =
            AppThemeManager.shared.isTabTextHidden
            ? "textHidden" : "textVisible"
        let iconSize = String(
            Int(AppThemeManager.shared.tabIconSize.rounded()))
        let barStyle: String =
            AppThemeManager.shared.useClassicTabBar
            ? "classic" : "modern"
        let statistics: String =
            showStatisticsTab ? "statistics" : "static"
        return [
            scheme, textVisibility, iconSize, barStyle, statistics,
        ].joined(separator: ":")
    }

    var body: some View {
        // body 0x100cf9184 域确证：双 TabView 条件 + chrome 修饰。
        Group {
            if AppThemeManager.shared.useClassicTabBar {
                nativeClassicTabView
            } else {
                // tabBarMinimizeBehavior iOS 26 域——iOS 18 SDK 无该
                // API，修饰暂挂（真机核清项）。
                nativeSearchTabView
            }
        }
        .id(tabAppearanceSignature)
        .modifier(
            MainTabThemeLifecycleModifier()
        )
        .modifier(
            MainTabChromeModifier(
                statisticsVisibility: $showStatisticsTab)
        )
        .modifier(MainTabMiniPlayerModifier())
    }

    /// selectedTabRoot getter（0x100cf963c L54-61 域确证：
    /// TabView(selection:) Binding 域）。
    private var selectedTabRoot: some View {
        TabView(selection: $selection) {
            nativeSearchTabView
        }
    }

    /// nativeSearchTabView getter（buildBlock 五元组域确证：
    /// BookshelfView/ExploreView/ReadingStatsView/SettingsView/
    /// SearchView 五 Tab）。
    private var nativeSearchTabView: some View {
        TabView(selection: $selection) {
            ForEach(visibleTabs, id: \.self) { tab in
                tabContent(for: tab)
                    .tabItem {
                        tabLabel(
                            iconPage(for: tab), name: tabName(for: tab),
                            appTab: tab)
                    }
                    .tag(tab)
            }
        }
    }

    /// nativeClassicTabView getter（TupleView 五元组 + 第三 tag
    /// optional 域确证：statistics 条件）。
    private var nativeClassicTabView: some View {
        TabView(selection: $selection) {
            ForEach(visibleTabs, id: \.self) { tab in
                tabContent(for: tab)
                    .tabItem {
                        tabLabel(
                            iconPage(for: tab), name: tabName(for: tab),
                            appTab: tab)
                    }
                    .tag(tab)
            }
        }
    }

    private var visibleTabs: [AppTab] {
        AppTab.allCases.filter { tab in
            tab != .statistics || showStatisticsTab
        }
    }

    @ViewBuilder
    private func tabContent(for tab: AppTab) -> some View {
        // 五 Tab 根视图域（closure #1/#3/#5/#7/#9 确证）。
        switch tab {
        case .bookshelf:
            BookshelfView()
        case .explore:
            ExploreView()
        case .statistics:
            ReadingStatsView()
        case .settings:
            SettingsView(navigationPath: nil)
        case .search:
            SearchView()
        }
    }

    private func iconPage(for tab: AppTab) -> TabPage {
        switch tab {
        case .bookshelf: return .bookshelf
        case .explore: return .explore
        case .statistics: return .statistics
        case .settings: return .settings
        case .search: return .search
        }
    }

    private func tabName(for tab: AppTab) -> String {
        switch tab {
        case .bookshelf: return "书架"
        case .explore: return "发现"
        case .statistics: return "统计"
        case .settings: return "我的"
        case .search: return "搜索"
        }
    }

    /// themeColorScheme getter（签名域确证）。
    private var themeColorScheme: ColorScheme {
        AppThemeManager.shared.effectiveColorScheme(
            for: systemColorScheme)
    }

    /// tabLabel(_:name:appTab:)（0x100cfa26c L72-74 域确证：
    /// Text(name) + Image 图标域；textHidden 时隐藏文字）。
    private func tabLabel(
        _ page: TabPage, name: String, appTab: AppTab
    ) -> some View {
        let isSelected = selection == appTab
        let scheme = themeColorScheme
        let icon = isSelected
            ? AppThemeManager.shared.selectedTabIcon(
                for: page, colorScheme: scheme)
            : AppThemeManager.shared.tabIcon(
                for: page, colorScheme: scheme)
        return Label {
            // closure #1 0x100cfa26c 域确证：Text(name)。
            if AppThemeManager.shared.isTabTextHidden {
                Text(name).hidden()
            } else {
                Text(name)
            }
        } icon: {
            // closure #2 域确证：tabImage(size:displayScale:)。
            icon.tabImage(
                size: AppThemeManager.shared.tabIconSize,
                displayScale: 1)
        }
    }
}
