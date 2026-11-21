// 原路径: ReadMain/Views/Settings/TabIconSettingsView.swift
// 证据:
//   - PGO: 130 条记录（index/task_functions.csv T-701-09 /
//     TabIconSettingsView.swift；伪代码域 200 行）
//   - CovMap: 上述 L 区段（editorList 三 Section + 四态行域）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Settings/
//     TabIconSettingsView.c（3247 行）
//   - 块体确证（签名域）：
//     content / editorList（tabBarDisplaySection + iconSizeSection +
//     ForEach 域）/ currentIcon(tab:isSelected:isDark:) /
//     hasOwnCustomIcon(tab:isSelected:isDark:) / iconPreview(tab:
//     isSelected:isDark:) / iconRow(tab:isSelected:isDark:label:) /
//     loadIcon(for:isSelected:isDark:) / loadTabIconData(from:) /
//     resetIcon(tab:isSelected:isDark:) / setIconData(_:for:isSelected:
//     isDark:) / handleIconFileImport(_: Result) / applyEdit()
//   - 字符串域（位模式，scratch/t70109_tab_strings.txt）：
//     '保存' L142 / '经典底栏' L664 / '未选中' L1209 / '选中' L1331 /
//     '深色未选中' L1413 / '深色选中' L1495 / '选择图片' L1853 /
//     '确定' L2585
//   - 事实：Tab 图标四态（选中/未选中 × 亮/暗）自定义域
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（十二签名域 + 四态字符串链确证）
// 还原: 2026-11-20

import SwiftUI

/// Tab 图标设置（editorList 三 Section 域确证：显示 + 尺寸 + 四态编辑）。
struct TabIconSettingsView: View {

    @State private var iconSize: Double = 22
    @State private var useClassicTabBar = false
    @State private var importTarget: (tab: TabPage, isSelected: Bool,
                                      isDark: Bool)?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                editorList
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .navigationTitle("底部图标")
        .onAppear {
            let theme = AppThemeManager.shared.currentTheme
            iconSize = Double(theme.tabIconSize ?? 22)
            useClassicTabBar = theme.useClassicTabBar
        }
    }

    /// content getter（签名域确证）。
    @ViewBuilder
    private var content: some View {
        editorList
    }

    /// editorList getter（三 Section 域确证）。
    @ViewBuilder
    private var editorList: some View {
        tabBarDisplaySection
        iconSizeSection
        ForEach(TabPage.allCases, id: \.self) { page in
            tabSection(page)
        }
    }

    /// tabBarDisplaySection getter（'经典底栏' L664 域确证）。
    @ViewBuilder
    private var tabBarDisplaySection: some View {
        settingsCardRow(topGap: 16) {
            Toggle(isOn: $useClassicTabBar) {
                AppThemeSettingsLabel(
                    title: "经典底栏", systemImage: "menubar.rectangle")
            }
            .onChange(of: useClassicTabBar) { _ in
                applyEdit()
            }
        }
    }

    /// iconSizeSection getter（签名域确证）。
    @ViewBuilder
    private var iconSizeSection: some View {
        settingsCardRow(topGap: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("图标大小")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(
                    value: $iconSize, in: 16...30, step: 1
                ) { editing in
                    if !editing {
                        applyEdit()
                    }
                }
            }
        }
    }

    /// 四态行组（'选中' L1331 / '未选中' L1209 / '深色选中' L1495 /
    /// '深色未选中' L1413 域确证）。
    @ViewBuilder
    private func tabSection(_ page: TabPage) -> some View {
        settingsCardRow(topGap: 12) {
            VStack(alignment: .leading, spacing: 10) {
                Text(page.displayName)
                    .font(.subheadline.weight(.medium))
                iconRow(
                    tab: page, isSelected: true, isDark: false,
                    label: "选中")
                iconRow(
                    tab: page, isSelected: false, isDark: false,
                    label: "未选中")
                iconRow(
                    tab: page, isSelected: true, isDark: true,
                    label: "深色选中")
                iconRow(
                    tab: page, isSelected: false, isDark: true,
                    label: "深色未选中")
            }
        }
    }

    /// iconRow(tab:isSelected:isDark:label:)（签名域确证）。
    @ViewBuilder
    private func iconRow(
        tab: TabPage, isSelected: Bool, isDark: Bool, label: String
    ) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            iconPreview(tab: tab, isSelected: isSelected, isDark: isDark)
            Spacer()
            if hasOwnCustomIcon(
                tab: tab, isSelected: isSelected, isDark: isDark) {
                Button {
                    resetIcon(tab: tab, isSelected: isSelected,
                              isDark: isDark)
                } label: {
                    Text("还原")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }
            Button {
                importTarget = (tab, isSelected, isDark)
                pickIconFile()
            } label: {
                Text("自定义")
                    .font(.caption)
                    .appThemeAccent()
            }
            .buttonStyle(.borderless)
        }
    }

    /// iconPreview(tab:isSelected:isDark:)（签名域确证）。
    @ViewBuilder
    private func iconPreview(
        tab: TabPage, isSelected: Bool, isDark: Bool
    ) -> some View {
        if let icon = loadIcon(
            for: tab, isSelected: isSelected, isDark: isDark) {
            icon.tabImage(size: iconSize, displayScale: 1)
        } else {
            Image(systemName: tab.defaultSFSymbol)
        }
    }

    /// currentIcon(tab:isSelected:isDark:)（签名域确证）。
    private func currentIcon(
        tab: TabPage, isSelected: Bool, isDark: Bool
    ) -> TabIcon? {
        loadIcon(for: tab, isSelected: isSelected, isDark: isDark)
    }

    /// hasOwnCustomIcon(tab:isSelected:isDark:)（签名域确证）。
    private func hasOwnCustomIcon(
        tab: TabPage, isSelected: Bool, isDark: Bool
    ) -> Bool {
        loadIcon(for: tab, isSelected: isSelected, isDark: isDark)?
            .kind == .custom
    }

    /// loadIcon(for:isSelected:isDark:)（签名域确证：主题图标域读取）。
    private func loadIcon(
        for tab: TabPage, isSelected: Bool, isDark: Bool
    ) -> TabIcon? {
        let theme = AppThemeManager.shared.currentTheme
        let set: TabIconSet = {
            if isDark {
                if isSelected {
                    return theme.darkSelectedTabIcons
                        ?? theme.selectedTabIcons
                        ?? theme.darkTabIcons ?? theme.tabIcons
                }
                return theme.darkTabIcons ?? theme.tabIcons
            }
            if isSelected {
                return theme.selectedTabIcons ?? theme.tabIcons
            }
            return theme.tabIcons
        }()
        return set[tab]
    }

    /// setIconData(_:for:isSelected:isDark:)（签名域确证：写回主题）。
    private func setIconData(
        _ data: Data?, for tab: TabPage, isSelected: Bool,
        isDark: Bool
    ) {
        var theme = AppThemeManager.shared.currentTheme
        let icon = data.map { TabIcon.custom(imageData: $0) }
        if isDark {
            if isSelected {
                var set = theme.darkSelectedTabIcons
                    ?? theme.selectedTabIcons ?? TabIconSet()
                set[tab] = icon
                theme.darkSelectedTabIcons = set
            } else {
                var set = theme.darkTabIcons ?? TabIconSet()
                set[tab] = icon
                theme.darkTabIcons = set
            }
        } else {
            if isSelected {
                var set = theme.selectedTabIcons ?? TabIconSet()
                set[tab] = icon
                theme.selectedTabIcons = set
            } else {
                var set = theme.tabIcons
                set[tab] = icon
                theme.tabIcons = set
            }
        }
        AppThemeManager.shared.updateTheme(theme)
    }

    /// resetIcon(tab:isSelected:isDark:)（签名域确证）。
    private func resetIcon(
        tab: TabPage, isSelected: Bool, isDark: Bool
    ) {
        setIconData(nil, for: tab, isSelected: isSelected,
                    isDark: isDark)
    }

    /// loadTabIconData(from:)（签名域确证）。
    private func loadTabIconData(from url: URL) {
        guard let target = importTarget,
              let data = try? Data(contentsOf: url) else {
            return
        }
        setIconData(
            data, for: target.tab, isSelected: target.isSelected,
            isDark: target.isDark)
        importTarget = nil
    }

    /// handleIconFileImport(_: Result<URL, Error>)（签名域确证）。
    private func handleIconFileImport(
        _ result: Result<URL, Error>
    ) {
        switch result {
        case .success(let url):
            loadTabIconData(from: url)
        case .failure:
            importTarget = nil
        }
    }

    /// applyEdit()（签名域确证：尺寸/底栏写回）。
    private func applyEdit() {
        var theme = AppThemeManager.shared.currentTheme
        theme.tabIconSize = CGFloat(iconSize)
        theme.useClassicTabBar = useClassicTabBar
        AppThemeManager.shared.updateTheme(theme)
    }

    private func pickIconFile() {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        UIApplication.shared.connectedScenes
            .compactMap {
                ($0 as? UIWindowScene)?.keyWindow?.rootViewController
            }
            .first?
            .present(picker, animated: true)
    }
}
