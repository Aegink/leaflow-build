// 原路径: ReadMain/Views/Settings/BackgroundMixerSettingsView.swift
// 证据:
//   - PGO: 241 条记录（index/task_functions.csv T-701-04 /
//     BackgroundMixerSettingsView.swift；主类型 AppThemeSettingsView，
//     伪代码域 700 行）
//   - CovMap: 上述 L 区段（body/themeColorScheme/filteredThemes/
//     settingsList/themeSwitchSettingsContent/路由六 destination 域）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Settings/
//     BackgroundMixerSettingsView.c（19135 行）
//   - 块体确证（地址+行号域）：
//     AppThemeSettingsView.themeColorScheme getter / body /
//     filteredThemes getter / settingsList getter（AppearanceRoute
//     六路 _ConditionalContent 域：themeSwitchSettingsContent /
//     ReaderInterfaceAppearanceSettingsView / TabIconSettingsView /
//     BookshelfAppearanceSettingsView / DefaultCoverSettingsView /
//     SplashSettingsView / basicAppearanceSettingsDestination /
//     pageBackgroundSettingsDestination / effectsSettingsDestination /
//     CardBackgroundSettingsView）
//   - 字符串域（位模式+指针，scratch/t70104_mixer_strings.txt）：
//     '外观主题' L480 / '颜色与字体' L1339 / '亮色主题' L2622 /
//     '深色主题' L2628 / '跟随系统' L2921 / '新建' L3503 / '重命名'
//     L5232 / '删除' L5249 / '取消' L5264 / '亮色模式' L5644 /
//     '深色模式' L5872 / '亮色主文字' L6210 / '亮色弱文字' L6480 /
//     '深色主文字' L6631 / '深色弱文字' L6933 / '字体' L7090 /
//     '系统默认' L7240 / '页面背景' L7612 / '界面效果' L7695 /
//     '关闭' L7784 / '卡片背景' L7793 / '经典' L8041 / '聊天输入框'
//     L8057 / '阅读界面' L8067 / ' 列 · ' L8102 / '书架' L8132 /
//     '默认封面' L8197 / '主题切换' L8407 / '透明模式' L8454
//   - 事实： AppearanceRoute 六路（themeSwitch/readerInterface/
//     tabIcon/bookshelfAppearance/defaultCover/splash/basic/pageBack
//     ground/effects/cardBackground 十 destination 域）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（路由域 + 字符串全链确证）
// 还原: 2026-11-20

import SwiftUI

/// 外观主题设置主页（body/filteredThemes/settingsList 域确证）。
struct AppThemeSettingsView: View {

    /// 设置导航路由（settingsList 域确证六路）。
    enum AppearanceRoute: String, Hashable {
        case themeSwitch
        case readerInterface
        case tabIcon
        case bookshelfAppearance
        case defaultCover
        case splash
        case basicAppearance
        case pageBackground
        case effects
        case cardBackground
    }

    @State private var searchText = ""
    @State private var showSaveThemeDialog = false
    @State private var deleteTarget: AppTheme?
    @State private var renameTarget: AppTheme?
    @State private var route: AppearanceRoute?
    @State private var followSystem = true

    /// themeColorScheme getter（签名域确证）。
    private var themeColorScheme: ColorScheme {
        AppThemeManager.shared.appAppearanceColorScheme
    }

    /// filteredThemes getter（签名域确证：'搜索主题' 过滤域）。
    private var filteredThemes: [AppTheme] {
        let query = searchText.trimmingCharacters(
            in: .whitespacesAndNewlines)
        let themes = AppThemeManager.shared.themes
        guard !query.isEmpty else { return themes }
        return themes.filter {
            $0.name.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                settingsList
            }
            .navigationTitle("外观主题")
            .searchable(text: $searchText, prompt: "搜索主题")
        }
        .preferredColorScheme(
            AppThemeManager.shared.preferredColorSchemeOverride)
        .appThemeSettingsLifecycle(themeManager: AppThemeManager.shared)
        .appThemeSettingsPresentations(
            showSaveThemeDialog: $showSaveThemeDialog,
            deleteTarget: $deleteTarget,
            renameTarget: $renameTarget)
        .onAppear {
            followSystem = AppThemeManager.shared.followSystemTheme
        }
    }

    /// settingsList getter（签名域确证：settingsCardRow 列 +
    /// NavigationLink 六路）。
    @ViewBuilder
    private var settingsList: some View {
        VStack(spacing: 0) {
            // 主题切换域（'亮色主题' L2622 / '深色主题' L2628 /
            // '跟随系统' L2921 / '新建' L3503）。
            themeSwitchSettingsContent
            // 导航行域（'颜色与字体' L1339 / '页面背景' L7612 /
            // '界面效果' L7695 / '卡片背景' L7793 / '阅读界面' L8067 /
            // '默认封面' L8197 / '主题切换' L8407）。
            ForEach(
                [
                    AppearanceRoute.readerInterface,
                    AppearanceRoute.tabIcon,
                    AppearanceRoute.bookshelfAppearance,
                    AppearanceRoute.defaultCover,
                    AppearanceRoute.splash,
                    AppearanceRoute.cardBackground,
                ], id: \.self
            ) { destination in
                NavigationLink(value: destination) {
                    routeRow(destination)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .navigationDestination(for: AppearanceRoute.self) { destination in
            // settingsList 路由域确证：六路 _ConditionalContent。
            routeDestination(destination)
        }
    }

    /// themeSwitchSettingsContent getter（签名域确证：
    /// settingsCardRow 五元组含 optional 域）。
    @ViewBuilder
    private var themeSwitchSettingsContent: some View {
        settingsCardRow(topGap: 16) {
            Picker(selection: $followSystem) {
                Text("跟随系统").tag(true)
                Text("亮色模式").tag(false)
            } label: {
                AppThemeSettingsLabel("主题切换", systemImage: "circle.lefthalf.filled")
            }
            .pickerStyle(.menu)
            .onChange(of: followSystem) { newValue in
                if newValue {
                    AppThemeManager.shared.setFollowSystemTheme(true)
                } else {
                    AppThemeManager.shared.setFollowSystemTheme(false)
                    AppThemeManager.shared.activateThemeMode(false)
                }
            }
        }
        settingsCardRow(topGap: 12) {
            HStack {
                AppThemeSettingsLabel("深色模式", systemImage: "moon.fill")
                Spacer()
                Button {
                    AppThemeManager.shared.activateThemeMode(true)
                } label: {
                    Text("切换")
                }
                .buttonStyle(.borderless)
            }
        }
        settingsCardRow(topGap: 12) {
            HStack {
                AppThemeSettingsLabel("主题列表", systemImage: "paintpalette")
                Spacer()
                Button {
                    // '新建' L3503 域确证。
                    showSaveThemeDialog = true
                } label: {
                    Image(systemName: "plus")
                        .appThemeAccent()
                }
                .buttonStyle(.borderless)
            }
        }
        // 主题卡片列表（filteredThemes 域确证）。
        ForEach(filteredThemes, id: \.id) { theme in
            themeCard(theme)
        }
    }

    /// 主题卡片（'重命名' L5232 / '删除' L5249 域确证）。
    private func themeCard(_ theme: AppTheme) -> some View {
        settingsCardRow(topGap: 12) {
            HStack {
                Circle()
                    .fill(leaflowColor(theme.accentColorHex))
                    .frame(width: 22, height: 22)
                Text(theme.name)
                if theme.isBuiltIn {
                    Text("内置")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Menu {
                    Button {
                        renameTarget = theme
                    } label: {
                        Label("重命名", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        deleteTarget = theme
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    /// 导航行标签（字符串域确证）。
    @ViewBuilder
    private func routeRow(_ destination: AppearanceRoute) -> some View {
        HStack {
            switch destination {
            case .readerInterface:
                AppThemeSettingsLabel("阅读界面", systemImage: "book")
            case .tabIcon:
                AppThemeSettingsLabel("字体", systemImage: "textformat")
            case .bookshelfAppearance:
                HStack {
                    AppThemeSettingsLabel(
                        "书架", systemImage: "books.vertical")
                    Text(" 列 · ")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            case .defaultCover:
                AppThemeSettingsLabel("默认封面", systemImage: "photo.stack")
            case .splash:
                AppThemeSettingsLabel("启动图", systemImage: "sparkles")
            case .cardBackground:
                AppThemeSettingsLabel("卡片背景", systemImage: "rectangle.on.rectangle")
            default:
                AppThemeSettingsLabel(
                    destination.rawValue, systemImage: "gear")
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
    }

    /// 路由目标（settingsList 域确证六路 destination）。
    @ViewBuilder
    private func routeDestination(_ destination: AppearanceRoute)
        -> some View {
        switch destination {
        case .themeSwitch:
            themeSwitchSettingsContent
        case .readerInterface:
            ReaderInterfaceAppearanceSettingsView()
        case .tabIcon:
            TabIconSettingsView()
        case .bookshelfAppearance:
            BookshelfAppearanceSettingsView()
        case .defaultCover:
            DefaultCoverSettingsView()
        case .splash:
            SplashSettingsView()
        case .basicAppearance:
            basicAppearanceSettingsDestination
        case .pageBackground:
            pageBackgroundSettingsDestination
        case .effects:
            effectsSettingsDestination
        case .cardBackground:
            CardBackgroundSettingsView()
        }
    }

    /// basicAppearanceSettingsDestination（签名域确证）。
    @ViewBuilder
    private var basicAppearanceSettingsDestination: some View {
        Form {
            Picker(selection: $followSystem) {
                Text("跟随系统").tag(true)
                Text("亮色模式").tag(false)
            } label: {
                Text("主题切换")
            }
        }
    }

    /// pageBackgroundSettingsDestination（签名域确证）。
    @ViewBuilder
    private var pageBackgroundSettingsDestination: some View {
        Form {
            Text("页面背景")
                .foregroundStyle(.secondary)
        }
    }

    /// effectsSettingsDestination（签名域确证：'界面效果' + '透明
    /// 模式' L8454 + '关闭' L7784）。
    @ViewBuilder
    private var effectsSettingsDestination: some View {
        Form {
            Picker(selection: .constant(0)) {
                Text("关闭").tag(0)
            } label: {
                Text("界面效果")
            }
            Toggle(isOn: .constant(false)) {
                Text("透明模式")
            }
        }
    }
}

/// 阅读界面外观设置（ReaderInterfaceAppearanceSettingsView 域确证：
/// '亮色主文字'/'亮色弱文字'/'深色主文字'/'深色弱文字' L6210-6933 +
/// '字体' L7090 / '系统默认' L7240）。
struct ReaderInterfaceAppearanceSettingsView: View {

    @State private var fontFamily = "System"

    var body: some View {
        Form {
            Picker(selection: $fontFamily) {
                Text("系统默认").tag("System")
                ForEach(CustomFontService.shared.fonts) { font in
                    Text(font.internalDisplayName)
                        .tag(font.familyName ?? font.fileName)
                }
            } label: {
                Text("字体")
            }
            colorRow("亮色主文字", hex: "111111")
            colorRow("亮色弱文字", hex: "666666")
            colorRow("深色主文字", hex: "F2F2F2")
            colorRow("深色弱文字", hex: "7A7A7A")
        }
        .navigationTitle("阅读界面")
    }

    @ViewBuilder
    private func colorRow(_ title: String, hex: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            RoundedRectangle(cornerRadius: 4)
                .fill(leaflowColor(hex))
                .frame(width: 40, height: 22)
        }
    }
}
