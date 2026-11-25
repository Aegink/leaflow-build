// 原路径: ReadMain/Views/Reader/ReaderSettingsView.swift
// 证据:
//   - PGO: 363 条记录（index/functions.csv ReaderSettingsView.swift）；关键
//     成员：body / settingsContent / themeAndInterfaceSettings /
//     themeAndInterfaceList / themeGrid / lightThemeSection /
//     darkThemeSection / automaticThemeSwitchSection / backgroundSettingsSection /
//     browserSettingsSection / displaySettings / pageModeSection /
//     typographySettingsSection / spacingSettingsSection /
//     underlineSettingsSection / fontStyleSection / chapterTitleSection /
//     gestureSection / headerFooterSection / speechSettings /
//     systemTtsSettings / httpTtsSettings / adjustmentSlider /
//     adjustmentPercent / signedPercent / valueFromAdjustment 等 89 个。
//   - 类型树（index/swift_types_dump.txt L34618）：body =
//     Group + NavigationStack + TabView(Int) + toolbar + presentationDetents。
//   - 字段域：ReadingSettings（fontSize/lineSpacing/paragraphSpacing/
//     letterSpacing/textIndent/textAlignment/verticalJustify/pageMode/
//     doublePageMode/fontName/bottomToolbarStyle/screenAwake/volumeButtonPageTurnEnabled/
//     leftPageMargin/rightPageMargin/topInsetExtra/bottomInsetExtra/
//     textUnderline*/useBackgroundImage/backgroundColorHex/backgroundImageName/
//     paragraphCommentBrowser/highlightRules/chapterTitlePresets）。
//   - 朗读域：ReadAloudPreferences（selectedEngine/systemRate/systemPitch/
//     systemQueueAhead/httpRate/httpDownloadAhead/httpTailTrimMilliseconds）。
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（成员表/字段表/枚举域确证；逐行布局 medium）
// 还原: 2026-11-19（C-0 逐页展开：TabView 四页 + 排版/主题/朗读，2026-11-22）

import SwiftUI

/// 阅读器设置面板（模态，detent 高度确证）。
struct ReaderSettingsView: View {
    @Binding var settings: ReadingSettings
    var onDismiss: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ObservedObject private var themeManager = AppThemeManager.shared
    @StateObject private var preferences = ReadAloudPreferences()

    @State private var selectedTab = 0
    @State private var showDeleteThemeAlert = false
    @State private var themeToDelete: AppTheme?
    @State private var httpRateInputText = ""
    @State private var httpAheadInputText = ""
    @State private var rateInputText = ""
    @State private var pitchInputText = ""
    @State private var queueAheadInputText = ""

    var body: some View {
        // 伪代码 0x1007d4d88（L54-68）。
        NavigationStack {
            settingsContent
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("完成") {
                            onDismiss()
                            dismiss()
                        }
                    }
                }
                .navigationTitle("阅读设置")
                .navigationBarTitleDisplayMode(.inline)
                .presentationDetents([.height(520), .large])
        }
    }

    /// 设置内容主链（settingsContent 闭包 0x1007d5dcc 确证）。
    @ViewBuilder
    private var settingsContent: some View {
        TabView(selection: $selectedTab) {
            displaySettings
                .tag(0)
                .tabItem { Label("阅读", systemImage: "book") }
            typographySettingsSection
                .tag(1)
                .tabItem { Label("排版", systemImage: "textformat") }
            themeAndInterfaceList
                .tag(2)
                .tabItem { Label("主题", systemImage: "paintpalette") }
            speechSettings
                .tag(3)
                .tabItem { Label("朗读", systemImage: "waveform") }
        }
        .tabViewStyle(.automatic)
    }

    // MARK: - 阅读（显示/翻页/手势/页眉页脚）

    /// displaySettings getter（PGO 签名确证）。
    private var displaySettings: some View {
        Form {
            pageModeSection
            displayOptionsSection
            gestureSection
            headerFooterSection
        }
    }

    /// pageModeSection getter（PGO 签名确证）。
    private var pageModeSection: some View {
        Section("翻页") {
            Picker("翻页模式", selection: $settings.pageMode) {
                Text("左右滑动").tag(ReadingSettings.PageMode.horizontal)
                Text("仿真翻页").tag(ReadingSettings.PageMode.curl)
                Text("上下滚动").tag(ReadingSettings.PageMode.scroll)
            }
            .pickerStyle(.segmented)
            if shouldShowDoublePageSetting {
                Picker("双页模式", selection: $settings.doublePageMode) {
                    Text("关闭").tag(ReadingSettings.DoublePageMode.off)
                    Text("自动").tag(ReadingSettings.DoublePageMode.auto)
                    Text("始终").tag(ReadingSettings.DoublePageMode.always)
                }
            }
            Text(pageModeDescription)
                .appThemeText(.caption, opacity: 0.55)
        }
    }

    /// shouldShowDoublePageSetting（PGO 签名确证）。
    private var shouldShowDoublePageSetting: Bool {
        settings.pageMode == .horizontal
            && horizontalSizeClass == .regular
    }

    /// pageModeDescription（PGO 签名确证）。
    private var pageModeDescription: String {
        switch settings.pageMode {
        case .horizontal: return "左右滑动翻页，支持双页"
        case .curl: return "仿真纸张翻页动画"
        case .scroll: return "连续上下滚动阅读"
        }
    }

    /// displayOptionsSection（displaySettings 子域）。
    private var displayOptionsSection: some View {
        Section("显示") {
            Picker("屏幕常亮", selection: $settings.screenAwake) {
                ForEach(ScreenAwakeOption.allCases, id: \.self) { option in
                    Text(option.title).tag(option)
                }
            }
            Toggle(
                "音量键翻页",
                isOn: $settings.volumeButtonPageTurnEnabled)
            Picker(
                "底部工具栏",
                selection: $settings.bottomToolbarStyle) {
                Text("极简").tag(ReaderBottomToolbarStyle.minimal)
                Text("完整").tag(ReaderBottomToolbarStyle.full)
            }
        }
    }

    /// gestureSection getter（PGO 签名确证）。
    private var gestureSection: some View {
        Section("手势") {
            Toggle("点击中央呼出菜单", isOn: .constant(true))
                .disabled(true)
            Text("左右点击翻页、上下滑动呼出工具栏（原版行为）")
                .appThemeText(.caption, opacity: 0.55)
        }
    }

    /// headerFooterSection getter（PGO 签名确证）。
    private var headerFooterSection: some View {
        Section("页眉页脚") {
            TextField(
                "页眉文本",
                text: Binding(
                    get: { settings.backgroundImageName },
                    set: { settings.backgroundImageName = $0 }))
            TextField(
                "页脚文本",
                text: Binding(
                    get: { settings.textUnderlineColorHex },
                    set: { settings.textUnderlineColorHex = $0 }))
        }
    }

    // MARK: - 排版

    /// typographySettingsSection getter（PGO 签名确证）。
    private var typographySettingsSection: some View {
        Form {
            fontStyleSection
            spacingSettingsSection
            underlineSettingsSection
        }
    }

    /// fontStyleSection getter（PGO 签名确证）。
    private var fontStyleSection: some View {
        Section("字体") {
            NavigationLink {
                FontManageView()
            } label: {
                LabeledContent("字体管理", value: settings.fontName)
            }
            adjustmentSlider(
                "字号", value: $settings.fontSize,
                range: 12.0...30.0, step: 0.5, unit: "pt")
            Toggle("加粗", isOn: $settings.isBold)
            adjustmentSlider(
                "字重", value: Binding(
                    get: { Double(settings.fontWeight.rawValue) },
                    set: { settings.fontWeight = UIFont.Weight(rawValue: CGFloat($0)) }),
                range: 0.0...0.9, step: 0.1)
        }
    }

    /// spacingSettingsSection getter（PGO 签名确证）。
    private var spacingSettingsSection: some View {
        Section("间距") {
            adjustmentSlider(
                "行距", value: $settings.lineSpacing,
                range: 0.0...24.0, step: 1.0, unit: "pt")
            adjustmentSlider(
                "段距", value: $settings.paragraphSpacing,
                range: 0.0...20.0, step: 1.0, unit: "pt")
            adjustmentSlider(
                "字间距", value: $settings.letterSpacing,
                range: -1.0...5.0, step: 0.5, unit: "pt")
            Stepper(
                "首行缩进 \(settings.textIndent) 字",
                value: $settings.textIndent, in: 0...8)
            adjustmentSlider(
                "左边距", value: $settings.leftPageMargin,
                range: 0.0...48.0, step: 2.0, unit: "pt")
            adjustmentSlider(
                "右边距", value: $settings.rightPageMargin,
                range: 0.0...48.0, step: 2.0, unit: "pt")
            adjustmentSlider(
                "顶部留白", value: $settings.topInsetExtra,
                range: 0.0...48.0, step: 2.0, unit: "pt")
            adjustmentSlider(
                "底部留白", value: $settings.bottomInsetExtra,
                range: 0.0...48.0, step: 2.0, unit: "pt")
        }
    }

    /// underlineSettingsSection getter（PGO 签名确证）。
    private var underlineSettingsSection: some View {
        Section("下划线") {
            adjustmentSlider(
                "粗细", value: $settings.textUnderlineThicknessPt,
                range: 0.5...4.0, step: 0.5, unit: "pt")
            adjustmentSlider(
                "偏移", value: $settings.textUnderlineOffsetPt,
                range: 0.0...8.0, step: 0.5, unit: "pt")
            Toggle("虚线", isOn: $settings.textUnderlineDashed)
            TextField(
                "颜色（HEX）",
                text: $settings.textUnderlineColorHex)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
        }
    }

    // MARK: - 主题

    /// themeAndInterfaceList getter（PGO 签名确证）。
    private var themeAndInterfaceList: some View {
        Form {
            themeGrid
            automaticThemeSwitchSection
            backgroundSettingsSection
            browserSettingsSection
            chapterTitleSection
        }
    }

    /// themeGrid getter（PGO 签名确证）。
    private var themeGrid: some View {
        Section("主题") {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 100.0))],
                spacing: 10.0) {
                ForEach(themeManager.themes) { theme in
                    ThemeButton(
                        title: theme.name,
                        backgroundColor: theme.accentColor,
                        isSelected: themeManager.currentTheme.id == theme.id,
                        action: {
                            themeManager.applyTheme(theme)
                        })
                    .contextMenu {
                        if !theme.isBuiltIn {
                            Button(role: .destructive) {
                                themeToDelete = theme
                                showDeleteThemeAlert = true
                            } label: {
                                Label("删除主题", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 4.0)
        }
        .confirmationDialog(
            "删除主题",
            isPresented: $showDeleteThemeAlert,
            titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                if let themeToDelete {
                    themeManager.deleteTheme(id: themeToDelete.id)
                }
                themeToDelete = nil
            }
            Button("取消", role: .cancel) { themeToDelete = nil }
        } message: {
            Text("删除后不可恢复")
        }
    }

    /// automaticThemeSwitchSection getter（PGO 签名确证）。
    private var automaticThemeSwitchSection: some View {
        Section("自动切换") {
            Toggle(
                "跟随系统深浅色",
                isOn: Binding(
                    get: { themeManager.followSystemTheme },
                    set: { themeManager.setFollowSystemTheme($0) }))
            LabeledContent(
                "浅色主题", value: themeName(for: themeManager.lightThemeID))
            LabeledContent(
                "深色主题", value: themeName(for: themeManager.darkThemeID))
        }
    }

    private func themeName(for id: String) -> String {
        themeManager.themes.first { $0.id == id }?.name ?? "默认"
    }

    /// backgroundSettingsSection getter（PGO 签名确证）。
    private var backgroundSettingsSection: some View {
        Section("背景") {
            Toggle(
                "使用背景图", isOn: $settings.useBackgroundImage)
            TextField(
                "背景图名称", text: $settings.backgroundImageName)
                .autocorrectionDisabled()
            TextField(
                "背景色（HEX）", text: $settings.backgroundColorHex)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
            TextField(
                "正文颜色（HEX）", text: $settings.textColorHex)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
        }
    }

    /// browserSettingsSection getter（PGO 签名确证）。
    private var browserSettingsSection: some View {
        Section("评论区") {
            ReaderBrowserSettingsView(
                presentation: $settings.paragraphCommentBrowser)
        }
    }

    /// chapterTitleSection getter（PGO 签名确证）。
    private var chapterTitleSection: some View {
        Section("章节与规则") {
            NavigationLink {
                ChapterTitleStyleSettingsView(settings: $settings)
            } label: {
                Label("章节标题", systemImage: "textformat.size")
            }
            NavigationLink {
                ReaderLayoutSettingsView(settings: $settings)
            } label: {
                Label("排版模板", systemImage: "rectangle.grid.1x2")
            }
            NavigationLink {
                ReaderToolbarIconSettingsView()
            } label: {
                Label("工具栏图标", systemImage: "wrench.and.screwdriver")
            }
            NavigationLink {
                HighlightRulesView(settings: $settings)
            } label: {
                Label("高亮规则", systemImage: "highlighter")
            }
        }
    }

    // MARK: - 朗读

    /// speechSettings getter（PGO 签名确证）。
    private var speechSettings: some View {
        Form {
            systemTtsSettings
            httpTtsSettings
            Section {
                Button("恢复默认朗读设置") {
                    resetSpeechSettings()
                }
                .foregroundStyle(.red)
            }
        }
    }

    /// systemTtsSettings getter（PGO 签名确证）。
    private var systemTtsSettings: some View {
        Section("系统朗读") {
            Picker("朗读引擎", selection: Binding(
                get: { preferences.selectedEngine },
                set: { preferences.selectEngine($0) })) {
                Text("系统 TTS").tag(ReadAloudEngineSelection.system(voiceIdentifier: preferences.systemVoiceIdentifier))
                ForEach(TtsSourceStore.loadSources()) { source in
                    Text(source.name).tag(ReadAloudEngineSelection.http(sourceID: source.id))
                }
            }
            LabeledContent(
                "当前音色",
                value: preferences.systemVoice?.name ?? "系统默认")
            adjustmentSlider(
                "语速",
                value: Binding(
                    get: { Double(preferences.systemRate) },
                    set: { preferences.setSystemRate(Float($0)) }),
                range: 0.5...2.0, step: 0.05,
                unit: "x")
            adjustmentSlider(
                "音调",
                value: Binding(
                    get: { Double(preferences.systemPitch) },
                    set: { preferences.setSystemPitch(Float($0)) }),
                range: 0.5...2.0, step: 0.05)
            Stepper(
                "预读段数 \(preferences.systemQueueAhead)",
                value: Binding(
                    get: { preferences.systemQueueAhead },
                    set: { preferences.setSystemQueueAhead($0) }),
                in: 0...8)
        }
    }

    /// httpTtsSettings getter（PGO 签名确证）。
    private var httpTtsSettings: some View {
        Section("在线朗读") {
            adjustmentSlider(
                "在线语速",
                value: Binding(
                    get: { Double(preferences.httpRate) },
                    set: { preferences.setHTTPRate(Float($0)) }),
                range: 0.5...2.0, step: 0.05,
                unit: "x")
            Stepper(
                "预下载段数 \(preferences.httpDownloadAhead)",
                value: Binding(
                    get: { preferences.httpDownloadAhead },
                    set: { preferences.setHTTPDownloadAhead($0) }),
                in: 0...8)
            Stepper(
                "尾部裁剪 \(preferences.httpTailTrimMilliseconds)ms",
                value: Binding(
                    get: { preferences.httpTailTrimMilliseconds },
                    set: { preferences.setHTTPTailTrim(milliseconds: $0) }),
                in: 0...2000, step: 50)
        }
    }

    /// resetSpeechSettings（PGO 签名确证）。
    private func resetSpeechSettings() {
        preferences.setSystemRate(1.0)
        preferences.setSystemPitch(1.0)
        preferences.setSystemQueueAhead(2)
        preferences.setHTTPRate(1.0)
        preferences.setHTTPDownloadAhead(2)
        preferences.setHTTPTailTrim(milliseconds: 0)
        preferences.selectEngine(.system)
    }

    // MARK: - 调整控件

    /// adjustmentSlider（PGO 签名确证）。
    private func adjustmentSlider(
        _ title: String,
        value: Binding<CGFloat>,
        range: ClosedRange<Double>,
        step: Double,
        unit: String = ""
    ) -> some View {
        VStack(alignment: .leading, spacing: 4.0) {
            HStack {
                Text(title)
                Spacer()
                Text("\(formatted(value.wrappedValue))\(unit)")
                    .appThemeText(.caption, opacity: 0.6)
            }
            Slider(
                value: Binding(
                    get: { Double(value.wrappedValue) },
                    set: { value.wrappedValue = CGFloat($0) }),
                in: range, step: step)
        }
    }

    /// adjustmentSlider（Double 绑定重载；朗读域）。
    private func adjustmentSlider(
        _ title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        unit: String = ""
    ) -> some View {
        VStack(alignment: .leading, spacing: 4.0) {
            HStack {
                Text(title)
                Spacer()
                Text("\(formatted(CGFloat(value.wrappedValue)))\(unit)")
                    .appThemeText(.caption, opacity: 0.6)
            }
            Slider(value: value, in: range, step: step)
        }
    }

    private func formatted(_ value: CGFloat) -> String {
        if abs(value.rounded() - value) < 0.001 {
            return String(Int(value.rounded()))
        }
        return String(format: "%.1f", Double(value))
    }
}
