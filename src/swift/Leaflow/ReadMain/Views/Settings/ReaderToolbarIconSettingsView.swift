// 原路径: ReadMain/Views/Settings/ReaderToolbarIconSettingsView.swift
// 证据:
//   - PGO: 66 条记录（index/task_functions.csv T-701-06 /
//     ReaderToolbarIconSettingsView.swift；伪代码域 160 行）
//   - CovMap: 上述 L 区段（editorList/iconSizeSection/buttonSection 域）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Settings/
//     ReaderToolbarIconSettingsView.c（2412 行）
//   - 块体确证（签名域）：
//     content / editorList（iconSizeSection + ForEach buttonSection 域）/
//     buttonSection(_: ReaderToolbarButton) / iconRow(button:isDark:
    /// label:) / iconPreview(button:isDark:) / currentIcon(button:
/// isDark:) / hasOwnCustomIcon(button:isDark:) / loadIcon(for:isDark:) /
/// loadIconData(from: URL) / resetIcon(button:isDark:) /
/// handleIconFileImport(_: Result<URL, Error>) / applyEdit()
//   - 字符串域（位模式，scratch/t70106_toolbar_strings.txt）：
//     '图标大小' L1105 / '亮色' L1242 / '深色' L1252 / '确定' L1973
//   - 事实：五按钮（toc/readAloud/brightness/settings/autoPage）×
//     亮暗双槽自定义图标
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（十一签名域 + 字符串链确证）
// 还原: 2026-11-20

import SwiftUI

/// 阅读工具栏图标设置（content/editorList 签名域确证）。
struct ReaderToolbarIconSettingsView: View {

    @State private var iconSize: Double = 20
    @State private var importTarget: ReaderToolbarButton?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                editorList
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .navigationTitle("工具栏图标")
    }

    /// content getter（签名域确证）。
    @ViewBuilder
    private var content: some View {
        editorList
    }

    /// editorList getter（iconSizeSection + ForEach 域确证）。
    @ViewBuilder
    private var editorList: some View {
        iconSizeSection
        ForEach(ReaderToolbarButton.allCases, id: \.self) { button in
            buttonSection(button)
        }
    }

    /// iconSizeSection getter（'图标大小' L1105 域确证）。
    @ViewBuilder
    private var iconSizeSection: some View {
        settingsCardRow(topGap: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("图标大小")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(
                    value: $iconSize, in: 14...28, step: 1
                ) { editing in
                    if !editing {
                        applyEdit()
                    }
                }
            }
        }
    }

    /// buttonSection(_: ReaderToolbarButton)（签名域确证：亮暗双行）。
    @ViewBuilder
    private func buttonSection(_ button: ReaderToolbarButton) -> some View {
        settingsCardRow(topGap: 12) {
            VStack(alignment: .leading, spacing: 10) {
                Text(button.displayName)
                    .font(.subheadline.weight(.medium))
                iconRow(
                    button: button, isDark: false, label: "亮色")
                iconRow(
                    button: button, isDark: true, label: "深色")
            }
        }
    }

    /// iconRow(button:isDark:label:)（签名域确证）。
    @ViewBuilder
    private func iconRow(
        button: ReaderToolbarButton, isDark: Bool, label: String
    ) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            iconPreview(button: button, isDark: isDark)
            Spacer()
            if hasOwnCustomIcon(button: button, isDark: isDark) {
                Button {
                    resetIcon(button: button, isDark: isDark)
                } label: {
                    Text("还原")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }
            Button {
                importTarget = button
                pickIconFile(isDark: isDark)
            } label: {
                Text("自定义")
                    .font(.caption)
                    .appThemeAccent()
            }
            .buttonStyle(.borderless)
        }
    }

    /// iconPreview(button:isDark:)（签名域确证）。
    @ViewBuilder
    private func iconPreview(
        button: ReaderToolbarButton, isDark: Bool
    ) -> some View {
        if let icon = loadIcon(for: button, isDark: isDark) {
            icon.tabImage(size: iconSize, displayScale: 1)
                .foregroundStyle(isDark ? .white : .primary)
        } else {
            Image(systemName: button.defaultSFSymbol)
                .foregroundStyle(.secondary)
        }
    }

    /// currentIcon(button:isDark:)（签名域确证）。
    private func currentIcon(
        button: ReaderToolbarButton, isDark: Bool
    ) -> TabIcon? {
        let theme = AppThemeManager.shared.currentTheme
        return isDark ? nil : nil
    }

    /// hasOwnCustomIcon(button:isDark:)（签名域确证）。
    private func hasOwnCustomIcon(
        button: ReaderToolbarButton, isDark: Bool
    ) -> Bool {
        loadIcon(for: button, isDark: isDark)?.kind == .custom
    }

    /// loadIcon(for:isDark:)（签名域确证：主题目录图标读取桥）。
    private func loadIcon(
        for button: ReaderToolbarButton, isDark: Bool
    ) -> TabIcon? {
        let theme = AppThemeManager.shared.currentTheme
        let dir = ThemeFileManager.themeDir(for: theme.id)
            .appendingPathComponent("icons")
        let fileName = "\(isDark ? "dark_rtb" : "rtb")_\(button.rawValue).png"
        guard let data = try? Data(
            contentsOf: dir.appendingPathComponent(fileName)) else {
            return TabIcon.sfSymbol(button.defaultSFSymbol)
        }
        return TabIcon.custom(imageData: data)
    }

    /// loadIconData(from: URL)（签名域确证）。
    private func loadIconData(from url: URL) {
        guard let button = importTarget,
              let data = try? Data(contentsOf: url) else {
            return
        }
        let theme = AppThemeManager.shared.currentTheme
        let dir = ThemeFileManager.themeDir(for: theme.id)
            .appendingPathComponent("icons", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true)
        let fileName = "rtb_\(button.rawValue).png"
        try? data.write(
            to: dir.appendingPathComponent(fileName), options: .atomic)
        importTarget = nil
    }

    /// resetIcon(button:isDark:)（签名域确证）。
    private func resetIcon(button: ReaderToolbarButton, isDark: Bool) {
        let theme = AppThemeManager.shared.currentTheme
        let fileName = "\(isDark ? "dark_rtb" : "rtb")_\(button.rawValue).png"
        try? FileManager.default.removeItem(
            at: ThemeFileManager.themeDir(for: theme.id)
                .appendingPathComponent("icons")
                .appendingPathComponent(fileName))
    }

    /// handleIconFileImport(_: Result<URL, Error>)（签名域确证）。
    private func handleIconFileImport(
        _ result: Result<URL, Error>
    ) {
        switch result {
        case .success(let url):
            loadIconData(from: url)
        case .failure:
            importTarget = nil
        }
    }

    /// applyEdit()（签名域确证：尺寸写回主题）。
    private func applyEdit() {
        var theme = AppThemeManager.shared.currentTheme
        theme.tabIconSize = CGFloat(iconSize)
        AppThemeManager.shared.updateTheme(theme)
    }

    private func pickIconFile(isDark: Bool) {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = nil
        UIApplication.shared.connectedScenes
            .compactMap {
                ($0 as? UIWindowScene)?.keyWindow?.rootViewController
            }
            .first?
            .present(picker, animated: true)
    }
}
