// 原路径: ReadMain/Views/Settings/SplashSettingsView.swift
// 证据:
//   - PGO: 82 条记录（index/task_functions.csv T-701-08 /
//     SplashSettingsView.swift；伪代码域 140 行）
//   - CovMap: 上述 L 区段（editorList 五 Section 域）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Settings/
//     SplashSettingsView.c（2865 行）
//   - 块体确证（签名域）：
//     content / editorList（enabledSection + TupleView(durationSection
//     + rotationSection)? + splashGridSection(isDark:) 双档）/
//     addSection(isDark:) / applyEdit() / displayedDuration getter /
//     durationSection / enabledSection / rotationSection
//   - 字符串域（位模式，scratch/t70108_splash_strings.txt）：
//     '轮换方式' L955（SplashRotation 域 '顺序'/'随机' AppTheme.c
//     L102-107 交叉）/ '停留时长' L484 / '%.2f 秒' L496 /
//     '移除全部' L2184
//   - 事实：启动图亮暗双池 + 时长 + 轮换方式（SplashRotation）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（九签名域 + 字符串链确证）
// 还原: 2026-11-20

import SwiftUI
import PhotosUI

/// 启动图设置（editorList 五 Section 域确证）。
struct SplashSettingsView: View {

    @State private var splashEnabled = false
    @State private var splashDuration: Double = 2.0
    @State private var splashRotation: SplashRotation = .ordered
    @State private var lightSplashDatas: [Data] = []
    @State private var darkSplashDatas: [Data] = []
    @State private var pickerTargetIsDark = false
    @State private var pickerShown = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                editorList
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .navigationTitle("启动图")
        .onAppear {
            loadFromTheme()
        }
    }

    /// content getter（签名域确证）。
    @ViewBuilder
    private var content: some View {
        editorList
    }

    /// editorList getter（五 Section 元组域确证）。
    @ViewBuilder
    private var editorList: some View {
        enabledSection
        if splashEnabled {
            durationSection
            rotationSection
            splashGridSection(isDark: false)
            addSection(isDark: false)
            splashGridSection(isDark: true)
            addSection(isDark: true)
        }
    }

    /// enabledSection getter（签名域确证）。
    @ViewBuilder
    private var enabledSection: some View {
        settingsCardRow(topGap: 16) {
            Toggle(isOn: $splashEnabled) {
                AppThemeSettingsLabel(
                    title: "启用启动图", systemImage: "sparkles")
            }
            .onChange(of: splashEnabled) { _ in
                applyEdit()
            }
        }
    }

    /// durationSection getter（'停留时长' L484 域确证）。
    @ViewBuilder
    private var durationSection: some View {
        settingsCardRow(topGap: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("停留时长")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(
                    value: $splashDuration, in: 0.5...6, step: 0.5
                ) { editing in
                    if !editing {
                        applyEdit()
                    }
                }
                // '%.2f 秒' L496 域确证。
                Text(String(format: "%.2f 秒", displayedDuration))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// rotationSection getter（'轮换方式' L955 域确证）。
    @ViewBuilder
    private var rotationSection: some View {
        settingsCardRow(topGap: 12) {
            Picker(selection: $splashRotation) {
                ForEach(SplashRotation.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            } label: {
                Text("轮换方式")
            }
            .pickerStyle(.menu)
            .onChange(of: splashRotation) { _ in
                applyEdit()
            }
        }
    }

    /// splashGridSection(isDark:)（签名域确证）。
    @ViewBuilder
    private func splashGridSection(isDark: Bool) -> some View {
        Text(isDark ? "深色" : "亮色")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 16)
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 64))], spacing: 10
        ) {
            let datas = isDark ? darkSplashDatas : lightSplashDatas
            ForEach(datas.indices, id: \.self) { index in
                splashItem(data: datas[index], index: index,
                           isDark: isDark)
            }
        }
    }

    /// addSection(isDark:)（签名域确证）。
    @ViewBuilder
    private func addSection(isDark: Bool) -> some View {
        settingsCardRow(topGap: 12) {
            Button {
                pickerTargetIsDark = isDark
                pickerShown = true
            } label: {
                HStack {
                    AppThemeSettingsLabel(
                        title: "选择图片", systemImage: "plus.circle")
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .photosPicker(
            isPresented: $pickerShown,
            selection: splashPhotoPickerBinding,
            matching: .images)
    }

    /// 启动图格（'移除全部' L2184 域确证）。
    @ViewBuilder
    private func splashItem(data: Data, index: Int, isDark: Bool)
        -> some View {
        ZStack(alignment: .topTrailing) {
            if let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 64, height: 96)
                    .cornerRadius(8)
                    .clipped()
            }
            Button {
                removeSplash(at: index, isDark: isDark)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.white, .black.opacity(0.6))
            }
        }
    }

    /// displayedDuration getter（签名域确证）。
    private var displayedDuration: Double {
        max(splashDuration, 0.5)
    }

    private var splashPhotoPickerBinding: Binding<PhotosPickerItem?> {
        Binding(
            get: { nil },
            set: { item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(
                        type: Data.self) {
                        appendSplash(data: data)
                    }
                }
            })
    }

    private func appendSplash(data: Data) {
        if pickerTargetIsDark {
            darkSplashDatas.append(data)
        } else {
            lightSplashDatas.append(data)
        }
        applyEdit()
    }

    private func removeSplash(at index: Int, isDark: Bool) {
        if isDark {
            darkSplashDatas.remove(at: index)
        } else {
            lightSplashDatas.remove(at: index)
        }
        applyEdit()
    }

    /// applyEdit()（签名域确证：主题启动域写回 + 落盘桥）。
    private func applyEdit() {
        var theme = AppThemeManager.shared.currentTheme
        theme.splashEnabled = splashEnabled
        theme.splashDuration = displayedDuration
        theme.splashRotation = splashRotation
        AppThemeManager.shared.updateTheme(theme)
        ThemeFileManager.persistSplashDatas(
            themeID: theme.id,
            light: lightSplashDatas, dark: darkSplashDatas)
    }

    private func loadFromTheme() {
        let theme = AppThemeManager.shared.currentTheme
        splashEnabled = theme.splashEnabled
        splashDuration = theme.splashDuration
        splashRotation = theme.splashRotation
        lightSplashDatas = theme.splashImageDatas(for: .light)
        darkSplashDatas = theme.splashImageDatas(for: .dark)
    }
}

private extension ThemeFileManager {
    /// 启动图落盘桥（splashImageFiles 域还原桥）。
    static func persistSplashDatas(
        themeID: String, light: [Data], dark: [Data]
    ) {
        let dir = themeDir(for: themeID)
            .appendingPathComponent("splash", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true)
        for (index, data) in light.enumerated() {
            try? data.write(
                to: dir.appendingPathComponent("splash_\(index).png"),
                options: .atomic)
        }
        for (index, data) in dark.enumerated() {
            try? data.write(
                to: dir.appendingPathComponent(
                    "dark_splash_\(index).png"),
                options: .atomic)
        }
    }
}
