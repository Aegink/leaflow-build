// 原路径: ReadMain/Views/Settings/CardBackgroundSettingsView.swift
// 证据:
//   - PGO: 129 条记录（index/task_functions.csv T-701-05 /
//     CardBackgroundSettingsView.swift；伪代码域 230 行）
//   - CovMap: 上述 L 区段（content 0x1009fa37c L42-115 /
//     livePreview 0x1009feb4c L177-241 / 编辑器域）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Settings/
//     CardBackgroundSettingsView.c（6200 行）
//   - 块体确证（地址+行号域 + 签名域）：
//     content 0x1009fa37c L42-115（编辑器元组域）/ livePreview
//     0x1009feb4c L177-241（AppThemeCardBackgroundSnapshotCache.
//     snapshot 交叉域）/ resolvedPreview(_:target:) / setLayout
//     (_:for:commit:) / layout(for:) / layoutBinding(for:commit:) /
//     assetEditor(_:target:) / backgroundColorBinding(for:) /
//     backgroundTransparencyEditor / borderColorBinding(for:) /
//     borderTransparencyEditor / borderWidthEditor /
//     cornerRadiusEditor / applyEdit() / commitDeferredChanges()
//   - 字符串域（位模式，scratch/t70105_card_strings.txt）：
//     '卡片背景' L229/L349 / '编辑模式' L778 / '置顶' L2468 /
//     '在线' L2481 / '未设置' L3742 / '更换' L3936 / '导入' L3941 /
//     '图片' L3956 / '移除' L4075 / '确定' L5752
//   - 事实：双 target 域（light/dark CardBackgroundImageTarget）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（content/livePreview 域 + 签名串确证）
// 还原: 2026-11-20

import SwiftUI

/// 卡片背景设置（content 0x1009fa37c L42-115 域确证：双 target 编辑域）。
struct CardBackgroundSettingsView: View {

    /// 背景 target（双档：亮色/深色，签名域确证）。
    enum CardBackgroundImageTarget: String, CaseIterable, Hashable {
        case light
        case dark

        var colorScheme: ColorScheme {
            self == .light ? .light : .dark
        }
    }

    @State private var selectedTarget: CardBackgroundImageTarget = .light
    @State private var editMode = false
    @State private var cornerRadius: Double = 16
    @State private var backgroundOpacity: Double = 1.0
    @State private var borderOpacity: Double = 0.0
    @State private var borderWidth: Double = 0.0

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                content
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .navigationTitle("卡片背景")
        .onAppear {
            loadFromTheme()
        }
    }

    /// content（0x1009fa37c L42-115 域确证：target 切换 + 预览 +
    /// 编辑器元组）。
    @ViewBuilder
    private var content: some View {
        // settingsCardRow 为内容包裹函数（AppThemeSettingsModifiers 域）——
        // Picker 作为其 label 闭包（wave-16）。
        settingsCardRow(topGap: 16) {
            Picker(selection: $selectedTarget) {
                Text("亮色").tag(CardBackgroundImageTarget.light)
                Text("深色").tag(CardBackgroundImageTarget.dark)
            } label: {
                // '卡片背景' L229/L349 域确证。
                AppThemeSettingsLabel(
                    "卡片背景", systemImage: "rectangle.on.rectangle")
            }
            .pickerStyle(.segmented)
        }

        livePreview

        // '编辑模式' L778 域确证。
        settingsCardRow(topGap: 12) {
            Toggle(isOn: $editMode) {
                Text("编辑模式")
            }
        }

        if editMode {
            assetEditor(currentCard, target: selectedTarget)
            backgroundTransparencyEditor
            borderTransparencyEditor
            borderWidthEditor
            cornerRadiusEditor
            commitRow
        }
    }

    /// livePreview（0x1009feb4c L177-241 域确证：快照缓存预览）。
    @ViewBuilder
    private var livePreview: some View {
        settingsCardRow(topGap: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("实时预览")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let image = resolvedPreview(
                    currentCard, target: selectedTarget) {
                    // T-1601-C0：共享背景图视图（类型树 L11161-11166）。
                    AppThemeCardBackgroundImageView(
                        image: image,
                        layout: currentCard.lightLayout,
                        imageMode: currentCard.lightImageMode,
                        cacheIdentifier: nil)
                        .frame(height: 120)
                        .cornerRadius(currentCard.clampedCornerRadius)
                        .clipped()
                } else {
                    RoundedRectangle(cornerRadius: currentCard
                        .clampedCornerRadius)
                        .fill(
                            currentCard.backgroundColor(
                                for: selectedTarget.colorScheme))
                        .frame(height: 120)
                        .overlay(
                            Text("未设置")
                                // '未设置' L3742 域确证。
                                .foregroundStyle(.secondary))
                }
            }
        }
    }

    /// assetEditor(_:target:)（签名域确证：'更换'/'导入'/'图片'/'移除'
    /// L3936-4075 域确证）。
    @ViewBuilder
    private func assetEditor(
        _ card: AppThemeCardBackground,
        target: CardBackgroundImageTarget
    ) -> some View {
        settingsCardRow(topGap: 12) {
            HStack {
                AppThemeSettingsLabel(
                    "图片", systemImage: "photo")
                Spacer()
                if card.hasBackgroundImage {
                    Button {
                        // '更换' L3936 域确证。
                        pickImage(for: target)
                    } label: {
                        Text("更换")
                    }
                    .buttonStyle(.borderless)
                    Button(role: .destructive) {
                        // '移除' L4075 域确证。
                        removeImage(for: target)
                    } label: {
                        Text("移除")
                    }
                    .buttonStyle(.borderless)
                } else {
                    Button {
                        // '导入' L3941 域确证。
                        pickImage(for: target)
                    } label: {
                        Text("导入")
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
    }

    /// backgroundTransparencyEditor（签名域确证）。
    @ViewBuilder
    private var backgroundTransparencyEditor: some View {
        settingsCardRow(topGap: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("背景透明度")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(
                    value: $backgroundOpacity, in: 0...1, step: 0.05)
                    .onChange(of: backgroundOpacity) { _ in
                        applyEdit()
                    }
            }
        }
    }

    /// borderTransparencyEditor（签名域确证）。
    @ViewBuilder
    private var borderTransparencyEditor: some View {
        settingsCardRow(topGap: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("边框透明度")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(value: $borderOpacity, in: 0...1, step: 0.05)
                    .onChange(of: borderOpacity) { _ in
                        applyEdit()
                    }
            }
        }
    }

    /// borderWidthEditor（签名域确证）。
    @ViewBuilder
    private var borderWidthEditor: some View {
        settingsCardRow(topGap: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("边框宽度")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(value: $borderWidth, in: 0...8, step: 0.5)
                    .onChange(of: borderWidth) { _ in
                        applyEdit()
                    }
            }
        }
    }

    /// cornerRadiusEditor（签名域确证）。
    @ViewBuilder
    private var cornerRadiusEditor: some View {
        settingsCardRow(topGap: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("圆角")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(value: $cornerRadius, in: 0...32, step: 1)
                    .onChange(of: cornerRadius) { _ in
                        applyEdit()
                    }
            }
        }
    }

    /// 提交行（'确定' L5752 域确证）。
    @ViewBuilder
    private var commitRow: some View {
        settingsCardRow(topGap: 12) {
            HStack {
                Spacer()
                Button {
                    commitDeferredChanges()
                } label: {
                    Text("确定")
                        .appThemeAccent()
                }
                Spacer()
            }
        }
    }

    // MARK: 状态域（resolvedPreview/setLayout/layoutBinding 签名域）

    private var currentCard: AppThemeCardBackground {
        AppThemeManager.shared.currentTheme.cardBackground
    }

    /// resolvedPreview(_:target:)（签名域确证：快照缓存取图）。
    private func resolvedPreview(
        _ card: AppThemeCardBackground,
        target: CardBackgroundImageTarget
    ) -> UIImage? {
        guard let data = card.imageData(for: target.colorScheme),
              let source = UIImage(data: data) else {
            return nil
        }
        return AppThemeCardBackgroundSnapshotCache(
            countLimit: 8, totalCostLimit: 96 * 1024 * 1024
        ).snapshot(
            sourceImage: source, layout: card.layout(
                for: target.colorScheme),
            imageMode: card.imageMode(for: target.colorScheme),
            cacheIdentifier: "preview_\(target.rawValue)",
            size: CGSize(width: 240, height: 120),
            displayScale: UIScreen.main.scale)
    }

    /// layout(for:)（签名域确证）。
    private func layout(for target: CardBackgroundImageTarget)
        -> HighlightBackgroundImageLayout {
        currentCard.layout(for: target.colorScheme)
    }

    /// layoutBinding(for:commit:)（签名域确证）。
    private func layoutBinding(
        for target: CardBackgroundImageTarget, commit: Bool
    ) -> Binding<HighlightBackgroundImageLayout> {
        Binding(
            get: { layout(for: target) },
            set: { layout in
                setLayout(layout, for: target, commit: commit)
            })
    }

    /// setLayout(_:for:commit:)（签名域确证：写回当前主题卡片域）。
    private func setLayout(
        _ layout: HighlightBackgroundImageLayout,
        for target: CardBackgroundImageTarget, commit: Bool
    ) {
        var theme = AppThemeManager.shared.currentTheme
        var card = theme.cardBackground
        if target == .light {
            card.lightLayout = layout
        } else {
            card.darkLayout = layout
        }
        theme.cardBackground = card
        AppThemeManager.shared.updateTheme(theme)
    }

    /// backgroundColorBinding(for:)（签名域确证）。
    private func backgroundColorBinding(
        for target: CardBackgroundImageTarget
    ) -> Binding<Color> {
        Binding(
            get: {
                currentCard.backgroundColor(for: target.colorScheme)
            },
            set: { color in
                let hex = UIColor(color).toHexComponents() ?? "FFFFFF"
                updateCard { card in
                    if target == .light {
                        card.lightBackgroundColorHex = hex
                    } else {
                        card.darkBackgroundColorHex = hex
                    }
                }
            })
    }

    /// borderColorBinding(for:)（签名域确证）。
    private func borderColorBinding(
        for target: CardBackgroundImageTarget
    ) -> Binding<Color> {
        Binding(
            get: {
                currentCard.borderColor(for: target.colorScheme)
            },
            set: { color in
                let hex = UIColor(color).toHexComponents() ?? "E5E5EA"
                updateCard { card in
                    if target == .light {
                        card.lightBorderColorHex = hex
                    } else {
                        card.darkBorderColorHex = hex
                    }
                }
            })
    }

    /// applyEdit()（签名域确证：编辑器标量写回）。
    private func applyEdit() {
        updateCard { card in
            card.cornerRadius = CGFloat(cornerRadius)
            card.backgroundOpacity = backgroundOpacity
            card.borderOpacity = borderOpacity
            card.borderWidth = CGFloat(borderWidth)
        }
    }

    /// commitDeferredChanges()（签名域确证：延迟写回提交）。
    private func commitDeferredChanges() {
        applyEdit()
    }

    private func updateCard(_ mutation: (inout AppThemeCardBackground) -> Void) {
        var theme = AppThemeManager.shared.currentTheme
        mutation(&theme.cardBackground)
        AppThemeManager.shared.updateTheme(theme)
    }

    private func loadFromTheme() {
        let card = currentCard
        cornerRadius = Double(card.cornerRadius)
        backgroundOpacity = card.backgroundOpacity
        borderOpacity = card.borderOpacity
        borderWidth = Double(card.borderWidth)
    }

    private func pickImage(for target: CardBackgroundImageTarget) {
        // PhotosPicker 桥（'导入'/'更换' 域还原桥；数据写回当前主题）。
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }
            .first?
            .present(picker, animated: true)
    }

    private func removeImage(for target: CardBackgroundImageTarget) {
        updateCard { card in
            if target == .light {
                card.backgroundImageData = nil
            } else {
                card.darkBackgroundImageData = nil
            }
        }
    }
}
