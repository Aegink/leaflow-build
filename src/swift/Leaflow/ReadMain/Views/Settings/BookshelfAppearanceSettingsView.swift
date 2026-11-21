// 原路径: ReadMain/Views/Settings/BookshelfAppearanceSettingsView.swift
// 证据:
//   - PGO: 76 条记录（index/task_functions.csv T-701-05 /
//     BookshelfAppearanceSettingsView.swift；伪代码域 150 行）
//   - CovMap: 上述 L 区段（body/settingsList 四 Section 域）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Settings/
//     BookshelfAppearanceSettingsView.c（2371 行）
//   - 块体确证（地址+行号域）：
//     tagSection 0x1009e11b4 L100-154（'文字颜色' L1788-1793 +
//     '显示标签' L2348 域）/ settingsList（headerSection/gridSection/
//     listCardSection/tagSection 四 Section 元组域）/ applyEdit +
//     setListCardHeight(CGFloat) + updateTheme((inout AppTheme)->Void)
//     签名域
//   - 字符串域（位模式，scratch/t70105_shelf_strings.txt）：
//     '网格列数' L257 / '卡片大小' L760 / '文字颜色' L1788/L1793 /
//     '显示标签' L2348
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（四 Section 域 + 字符串全链确证）
// 还原: 2026-11-20

import SwiftUI

/// 书架外观设置（settingsList 四 Section 元组域确证）。
struct BookshelfAppearanceSettingsView: View {

    @State private var headerStyle: BookshelfHeaderStyle = .classic
    @State private var gridColumns = 3
    @State private var listCardHeight: CGFloat = 140
    @State private var showsTags = true
    @State private var tagColorMode: BookshelfTagTextColorMode = .colored
    @State private var tagCustomColorHex = "007AFF"

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                settingsList
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .navigationTitle("书架外观")
        .onAppear {
            loadCurrentTheme()
        }
    }

    /// settingsList getter（四 Section 元组域确证）。
    @ViewBuilder
    private var settingsList: some View {
        headerSection
        gridSection
        listCardSection
        tagSection
    }

    // MARK: 头部域（headerSection 签名域确证）

    @ViewBuilder
    private var headerSection: some View {
        settingsCardRow(topGap: 16) {
            Picker(selection: $headerStyle) {
                ForEach(BookshelfHeaderStyle.allCases, id: \.self) {
                    style in
                    Text(style.displayName).tag(style)
                }
            } label: {
                AppThemeSettingsLabel(
                    title: "头部样式", systemImage: "rectangle.topthird")
            }
            .pickerStyle(.menu)
        }
    }

    // MARK: 网格域（'网格列数' L257 域确证）

    @ViewBuilder
    private var gridSection: some View {
        settingsCardRow(topGap: 12) {
            Picker(selection: $gridColumns) {
                ForEach(2...6, id: \.self) { count in
                    Text("\(count)").tag(count)
                }
            } label: {
                AppThemeSettingsLabel(
                    title: "网格列数", systemImage: "square.grid.2x2")
            }
            .pickerStyle(.menu)
            .onChange(of: gridColumns) { _ in
                applyEdit()
            }
        }
    }

    // MARK: 列表卡域（'卡片大小' L760 域确证）

    @ViewBuilder
    private var listCardSection: some View {
        settingsCardRow(topGap: 12) {
            VStack(alignment: .leading, spacing: 8) {
                AppThemeSettingsLabel(
                    title: "卡片大小", systemImage: "rectangle.split.1x2")
                Slider(
                    value: Binding(
                        get: { listCardHeight },
                        set: { setListCardHeight($0) }),
                    in: 88...240, step: 4)
                Text("\(Int(listCardHeight)) pt")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: 标签域（tagSection 0x1009e11b4 L100-154 + '文字颜色'
    // L1788 / '显示标签' L2348 域确证）

    @ViewBuilder
    private var tagSection: some View {
        settingsCardRow(topGap: 12) {
            Picker(selection: $tagColorMode) {
                ForEach(BookshelfTagTextColorMode.allCases, id: \.self) {
                    mode in
                    Text(mode.displayName).tag(mode)
                }
            } label: {
                AppThemeSettingsLabel(
                    title: "文字颜色", systemImage: "paintbrush.pointed")
            }
            .pickerStyle(.menu)
            .onChange(of: tagColorMode) { _ in
                applyEdit()
            }
        }
        if tagColorMode == .custom {
            settingsCardRow(topGap: 12) {
                ColorPicker(
                    "自定义色值",
                    selection: Binding(
                        get: {
                            Color(
                                hex: tagCustomColorHex)
                                ?? .accentColor
                        },
                        set: { color in
                            tagCustomColorHex =
                                UIColor(color).toHexComponents()
                                ?? "007AFF"
                            applyEdit()
                        }),
                    supportsOpacity: false)
            }
        }
        settingsCardRow(topGap: 12) {
            Toggle(isOn: $showsTags) {
                // '显示标签' L2348 域确证。
                Text("显示标签")
            }
            .onChange(of: showsTags) { _ in
                applyEdit()
            }
        }
    }

    // MARK: 应用域（applyEdit/setListCardHeight/updateTheme 签名域）

    /// setListCardHeight(_:)（签名域确证：钳制回写）。
    private func setListCardHeight(_ height: CGFloat) {
        listCardHeight = BookshelfListCardSizing.clampedHeight(height)
        applyEdit()
    }

    /// updateTheme((inout AppTheme) -> Void)（签名域确证）。
    private func updateTheme(_ mutation: (inout AppTheme) -> Void) {
        var theme = AppThemeManager.shared.currentTheme
        mutation(&theme)
        AppThemeManager.shared.updateTheme(theme)
    }

    /// applyEdit()（签名域确证：当前主题写回）。
    private func applyEdit() {
        updateTheme { theme in
            theme.bookshelfHeaderStyle = headerStyle
            theme.bookshelfGridColumnCount =
                BookshelfGridColumnSetting.sanitize(gridColumns)
            theme.bookshelfListCardHeight =
                BookshelfListCardSizing.clampedHeight(listCardHeight)
            theme.bookshelfShowsTags = showsTags
            theme.bookshelfTagTextColorMode = tagColorMode
            theme.bookshelfTagCustomTextColorHex =
                AppTheme.normalizedRGBHex(tagCustomColorHex) ?? "007AFF"
        }
    }

    private func loadCurrentTheme() {
        let theme = AppThemeManager.shared.currentTheme
        headerStyle = theme.bookshelfHeaderStyle
        gridColumns = theme.bookshelfGridColumnCount
        listCardHeight = theme.bookshelfListCardHeight
        showsTags = theme.bookshelfShowsTags
        tagColorMode = theme.bookshelfTagTextColorMode
        tagCustomColorHex = theme.bookshelfTagCustomTextColorHex
    }
}

private extension UIColor {
    /// hex 分量桥（ColorPicker 写回桥）。
    func toHexComponents() -> String? {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        else { return nil }
        return String(
            format: "%02X%02X%02X",
            Int(round(red * 255)), Int(round(green * 255)),
            Int(round(blue * 255)))
    }
}
