// 原路径: ReadMain/Views/Settings/DefaultCoverSettingsView.swift
// 证据:
//   - PGO: 92 条记录（index/task_functions.csv T-701-06 /
//     DefaultCoverSettingsView.swift；伪代码域 180 行）
//   - CovMap: 上述 L 区段（editorList 七 Section 域）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Settings/
//     DefaultCoverSettingsView.c（2352 行）
//   - 块体确证（签名域）：
//     editorList（七 Section 元组：forceDefaultCoverSection/
//     coverCornerRadiusSection/tabPageDefaultCoverSection/
//     coverGridSection/addSection/darkCoverGridSection/
//     darkAddSection）/ coverItem(data:index:isDark:) /
//     coverPhotoPickerBinding / applyEdit / content
//   - 字符串域（位模式，scratch/t70106_cover_strings.txt）：
//     '保存' L142 / '图标大小' L1105（圆角域交叉）/ '亮色' L1242 /
//     '深色' L1252 / '选择图片' L1609 / '确定' L1973
//   - 事实：亮/暗双封面网格 + 强制默认开关 + 圆角档
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（七 Section 域 + 字符串全链确证）
// 还原: 2026-11-20

import SwiftUI
import PhotosUI

/// 默认封面设置（editorList 七 Section 域确证）。
struct DefaultCoverSettingsView: View {

    @State private var forceDefaultCover = false
    @State private var coverCornerRadius: Double = 12
    @State private var lightCoverDatas: [Data] = []
    @State private var darkCoverDatas: [Data] = []
    @State private var lightPickerShown = false
    @State private var darkPickerShown = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                editorList
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .navigationTitle("默认封面")
        .onAppear {
            loadFromTheme()
        }
    }

    /// editorList getter（七 Section 元组域确证）。
    @ViewBuilder
    private var editorList: some View {
        forceDefaultCoverSection
        coverCornerRadiusSection
        tabPageDefaultCoverSection
        coverGridSection
        addSection
        darkCoverGridSection
        darkAddSection
    }

    /// forceDefaultCoverSection（签名域确证）。
    @ViewBuilder
    private var forceDefaultCoverSection: some View {
        settingsCardRow(topGap: 16) {
            Toggle(isOn: $forceDefaultCover) {
                AppThemeSettingsLabel(
                    "强制默认封面",
                    systemImage: "photo.on.rectangle.angled")
            }
            .onChange(of: forceDefaultCover) { _ in
                applyEdit()
            }
        }
    }

    /// coverCornerRadiusSection（签名域确证）。
    @ViewBuilder
    private var coverCornerRadiusSection: some View {
        settingsCardRow(topGap: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("圆角")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(value: $coverCornerRadius, in: 0...32, step: 1)
                    .onChange(of: coverCornerRadius) { _ in
                        applyEdit()
                    }
            }
        }
    }

    /// tabPageDefaultCoverSection（签名域确证）。
    @ViewBuilder
    private var tabPageDefaultCoverSection: some View {
        settingsCardRow(topGap: 12) {
            HStack {
                AppThemeSettingsLabel(
                    "封面池", systemImage: "photo.stack")
                Spacer()
                Text("\(lightCoverDatas.count + darkCoverDatas.count) 张")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// coverGridSection（签名域确证：亮色网格）。
    @ViewBuilder
    private var coverGridSection: some View {
        Text("亮色")
            // '亮色' L1242 域确证。
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 16)
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 72))], spacing: 10
        ) {
            ForEach(lightCoverDatas.indices, id: \.self) { index in
                coverItem(
                    data: lightCoverDatas[index], index: index,
                    isDark: false)
            }
        }
    }

    /// addSection（签名域确证）。
    @ViewBuilder
    private var addSection: some View {
        settingsCardRow(topGap: 12) {
            Button {
                lightPickerShown = true
            } label: {
                HStack {
                    AppThemeSettingsLabel(
                        "选择图片", systemImage: "plus.circle")
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .photosPicker(
            isPresented: $lightPickerShown,
            selection: coverPhotoPickerBinding,
            matching: .images)
    }

    /// darkCoverGridSection（签名域确证：深色网格）。
    @ViewBuilder
    private var darkCoverGridSection: some View {
        Text("深色")
            // '深色' L1252 域确证。
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 16)
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 72))], spacing: 10
        ) {
            ForEach(darkCoverDatas.indices, id: \.self) { index in
                coverItem(
                    data: darkCoverDatas[index], index: index,
                    isDark: true)
            }
        }
    }

    /// darkAddSection（签名域确证）。
    @ViewBuilder
    private var darkAddSection: some View {
        settingsCardRow(topGap: 12) {
            Button {
                darkPickerShown = true
            } label: {
                HStack {
                    AppThemeSettingsLabel(
                        "选择图片", systemImage: "plus.circle")
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .photosPicker(
            isPresented: $darkPickerShown,
            selection: coverPhotoPickerBinding,
            matching: .images)
    }

    /// coverItem(data:index:isDark:)（签名域确证：可删除封面格）。
    @ViewBuilder
    private func coverItem(
        data: Data, index: Int, isDark: Bool
    ) -> some View {
        ZStack(alignment: .topTrailing) {
            if let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 72, height: 96)
                    .cornerRadius(8)
                    .clipped()
            }
            Button {
                removeCover(at: index, isDark: isDark)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.white, .black.opacity(0.6))
            }
        }
    }

    /// coverPhotoPickerBinding getter（签名域确证）。
    private var coverPhotoPickerBinding: Binding<PhotosPickerItem?> {
        Binding(
            get: { nil },
            set: { item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(
                        type: Data.self) {
                        appendCover(data: data)
                    }
                }
            })
    }

    private func appendCover(data: Data) {
        if lightPickerShown {
            lightCoverDatas.append(data)
        } else if darkPickerShown {
            darkCoverDatas.append(data)
        }
        applyEdit()
    }

    private func removeCover(at index: Int, isDark: Bool) {
        if isDark {
            darkCoverDatas.remove(at: index)
        } else {
            lightCoverDatas.remove(at: index)
        }
        applyEdit()
    }

    /// applyEdit()（签名域确证：主题封面域写回）。
    private func applyEdit() {
        var theme = AppThemeManager.shared.currentTheme
        theme.forceDefaultCover = forceDefaultCover
        theme.coverCornerRadius = AppTheme.clampedCoverCornerRadius(
            CGFloat(coverCornerRadius))
        AppThemeManager.shared.updateTheme(theme)
        ThemeFileManager.persistCoverDatas(
            themeID: theme.id,
            light: lightCoverDatas, dark: darkCoverDatas)
    }

    private func loadFromTheme() {
        let theme = AppThemeManager.shared.currentTheme
        forceDefaultCover = theme.forceDefaultCover
        coverCornerRadius = Double(theme.coverCornerRadius)
        lightCoverDatas = theme.coverImageDatas(for: .light)
        darkCoverDatas = theme.coverImageDatas(for: .dark)
    }
}

private extension ThemeFileManager {
    /// 封面数据落盘桥（'保存' L142 / '确定' L1973 域还原桥）。
    static func persistCoverDatas(
        themeID: String, light: [Data], dark: [Data]
    ) {
        let coversDir = themeDir(for: themeID)
            .appendingPathComponent("covers", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: coversDir, withIntermediateDirectories: true)
        for (index, data) in light.enumerated() {
            try? data.write(
                to: coversDir.appendingPathComponent("cover_\(index).png"),
                options: .atomic)
        }
        for (index, data) in dark.enumerated() {
            try? data.write(
                to: coversDir.appendingPathComponent(
                    "dark_cover_\(index).png"),
                options: .atomic)
        }
    }
}
