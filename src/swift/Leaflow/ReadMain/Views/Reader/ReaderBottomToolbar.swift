// 原路径: ReadMain/Views/Reader/ReaderBottomToolbar.swift
// 证据:
//   - 类型树（index/swift_types_dump.txt）：
//     ReaderBottomToolbar L11216-11241（colorScheme/settings/chapterTitle/
//     displayedPageInChapter/chapterPageCount/safeAreaBottom/isSpeaking/
//     isPreparing/isPaused/isSettingsActive/slider 三绑定/11 回调）；
//     ReaderQuickSettingsPanel L11249-11261（settings/themeManager/
//     colorScheme/fontService/7 回调）；
//     ReaderSpacingSettingsPanel L11243-11247（settings/appThemeManager/onBack）。
//   - 事实：ReaderView.Body 包含 ReaderBottomToolbar 与
//     ReaderQuickSettingsPanel / ReaderSpacingSettingsPanel（类型树 L34734）。
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（字段表/回调表确证；布局细节 medium）
// 还原: 2026-11-22（C-0 逐页展开：底部工具栏 + 快捷面板）

import SwiftUI

/// 阅读底部工具栏（类型树 L11216-11241）。
struct ReaderBottomToolbar: View {

    @Environment(\.colorScheme) private var colorScheme
    var themeManager: ThemeManager = .shared
    @Bindable var settings: ReadingSettings

    let chapterTitle: String
    let displayedPageInChapter: Int
    let chapterPageCount: Int
    let safeAreaBottom: CGFloat
    let isSpeaking: Bool
    let isPreparing: Bool
    let isPaused: Bool
    let isSettingsActive: Bool

    @Binding var sliderValue: Double
    @Binding var sliderDraftValue: Double?
    @Binding var isSliderChanging: Bool
    let onSliderCommit: (Int) -> Void
    var onSliderDragging: ((Int) -> Void)?
    let onPrevChapter: () -> Void
    let onNextChapter: () -> Void
    let onChapterList: () -> Void
    let onToggleSpeech: () -> Void
    let onStopSpeech: () -> Void
    let onSearch: () -> Void
    let onSettings: () -> Void

    private var theme: ReaderTheme { themeManager.currentTheme }

    var body: some View {
        VStack(spacing: 8.0) {
            chapterHeader
            pageSlider
            controlRow
        }
        .padding(.horizontal, 16.0)
        .padding(.top, 10.0)
        .padding(.bottom, max(8.0, safeAreaBottom))
        .background(
            AppThemeSurface.fill(
                opacity: 0.96, followsAppearance: true))
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 18.0, topTrailingRadius: 18.0))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(height: 0.5)
        }
    }

    /// 章节标题 + 本章页序（类型树字段消费）。
    private var chapterHeader: some View {
        HStack(spacing: 8.0) {
            Button(action: onChapterList) {
                HStack(spacing: 4.0) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 13.0))
                    Text(chapterTitle.isEmpty ? "目录" : chapterTitle)
                        .appThemeText(.caption, opacity: 0.8)
                        .lineLimit(1)
                }
            }
            .buttonStyle(.plain)
            Spacer()
            Text(pageLabel)
                .appThemeText(.caption, opacity: 0.55)
        }
    }

    private var pageLabel: String {
        let total = max(1, chapterPageCount)
        let current = min(max(0, displayedPageInChapter) + 1, total)
        return "\(current)/\(total)"
    }

    /// 章节内页滑条（slider 三绑定域）。
    private var pageSlider: some View {
        Slider(
            value: Binding(
                get: { sliderDraftValue ?? sliderValue },
                set: { newValue in
                    sliderDraftValue = newValue
                    isSliderChanging = true
                    onSliderDragging?(Int(newValue))
                }),
            // SwiftUI步进滑杆不接受0...0；零页/单页保留显示，但禁止交互。
            in: 0...Double(max(1, chapterPageCount - 1)),
            step: 1.0,
            onEditingChanged: { editing in
                if editing {
                    isSliderChanging = true
                } else {
                    isSliderChanging = false
                    sliderValue = sliderDraftValue ?? sliderValue
                    onSliderCommit(Int(sliderValue))
                    sliderDraftValue = nil
                }
            })
            .tint(Color(hex: theme.textColorHex))
            .disabled(chapterPageCount <= 1)
            .accessibilityLabel("章节进度")
    }

    /// 控制行（上一章/朗读/搜索/设置/下一章）。
    private var controlRow: some View {
        HStack(spacing: 0.0) {
            controlButton(
                icon: "chevron.left.to.line", title: "上一章",
                action: onPrevChapter)
            controlButton(
                icon: speechIcon, title: speechTitle,
                action: onToggleSpeech)
            if isSpeaking || isPaused || isPreparing {
                controlButton(
                    icon: "stop.circle", title: "停止",
                    action: onStopSpeech)
            }
            controlButton(
                icon: "magnifyingglass", title: "搜索",
                action: onSearch)
            controlButton(
                icon: "textformat", title: "设置",
                isActive: isSettingsActive,
                action: onSettings)
            controlButton(
                icon: "chevron.right.to.line", title: "下一章",
                action: onNextChapter)
        }
    }

    private var speechIcon: String {
        if isPreparing { return "hourglass" }
        if isPaused { return "play.circle" }
        return isSpeaking ? "speaker.wave.2.fill" : "speaker.wave.2"
    }

    private var speechTitle: String {
        if isPreparing { return "准备中" }
        if isPaused { return "继续" }
        return isSpeaking ? "暂停" : "朗读"
    }

    private func controlButton(
        icon: String, title: String, isActive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 3.0) {
                Image(systemName: icon)
                    .font(.system(size: 16.0))
                    .foregroundStyle(
                        isActive
                            ? AnyShapeStyle(
                                AppThemeManager.shared.accentColor(
                                    for: colorScheme))
                            : AnyShapeStyle(Color.primary))
                    .frame(height: 20.0)
                Text(title)
                    .appThemeText(.caption, opacity: 0.6)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// 阅读快捷设置面板（类型树 L11249-11261）。
struct ReaderQuickSettingsPanel: View {

    @Bindable var settings: ReadingSettings
    var themeManager: ThemeManager = .shared
    @Environment(\.colorScheme) private var colorScheme
    var fontService: CustomFontService = .shared

    let onDisplay: () -> Void
    let onSpacing: () -> Void
    let onSpeech: () -> Void
    let onHighlight: () -> Void
    let onBrowser: () -> Void
    let onChapterTitle: () -> Void
    let onMore: () -> Void

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 64.0), spacing: 6.0)],
            spacing: 6.0) {
            entry("显示", "sun.max", onDisplay)
            entry("排版", "textformat.size", onSpacing)
            entry("朗读", "speaker.wave.2", onSpeech)
            entry("高亮", "highlighter", onHighlight)
            entry("评论", "text.bubble", onBrowser)
            entry("标题", "character.textbox", onChapterTitle)
            entry("更多", "ellipsis", onMore)
        }
        .padding(.horizontal, 10.0)
        .padding(.vertical, 8.0)
    }

    private func entry(
        _ title: String, _ icon: String, _ action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4.0) {
                Image(systemName: icon)
                    .font(.system(size: 17.0))
                    .foregroundStyle(
                        AppThemeManager.shared.accentColor(
                            for: colorScheme))
                    .frame(height: 20.0)
                Text(title)
                    .appThemeText(.caption, opacity: 0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6.0)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// 阅读间距快捷面板（类型树 L11243-11247）。
struct ReaderSpacingSettingsPanel: View {

    @Bindable var settings: ReadingSettings
    var appThemeManager: AppThemeManager = .shared
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 12.0) {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)
                Text("排版")
                    .appThemeText(.headline)
                Spacer()
            }
            sliderRow("字号", $settings.fontSize, 12.0...30.0, 0.5)
            sliderRow("行距", $settings.lineSpacing, 0.0...24.0, 1.0)
            sliderRow("段距", $settings.paragraphSpacing, 0.0...20.0, 1.0)
            Stepper(
                "首行缩进 \(settings.textIndent) 字",
                value: $settings.textIndent, in: 0...8)
        }
        .padding(.all, 14.0)
        .background(
            AppThemeSurface.fill(
                opacity: 0.96, followsAppearance: true))
        .clipShape(RoundedRectangle(cornerRadius: 18.0))
    }

    private func sliderRow(
        _ title: String, _ value: Binding<CGFloat>,
        _ range: ClosedRange<Double>, _ step: Double
    ) -> some View {
        HStack(spacing: 10.0) {
            Text(title)
                .frame(width: 34.0, alignment: .leading)
                .appThemeText(.caption, opacity: 0.7)
            Slider(
                value: Binding(
                    get: { Double(value.wrappedValue) },
                    set: { value.wrappedValue = CGFloat($0) }),
                in: range, step: step)
            Text(String(format: "%.1f", Double(value.wrappedValue)))
                .appThemeText(.caption, opacity: 0.6)
                .frame(width: 34.0, alignment: .trailing)
        }
    }
}
