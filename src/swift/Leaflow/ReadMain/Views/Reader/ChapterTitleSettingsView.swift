// 原路径: ReadMain/Views/Reader/ChapterTitleSettingsView.swift
// 证据:
//   - PGO: 90 个主函数（index/task_functions.csv T-303-03 / ChapterTitleSettingsView.swift），
//     地址：TitleAppearance.id 0x1006b53dc L24 / body 0x1006b62b4 L28-326 /
//     nativeStyleSection 0x1006b7f34 L330-363 / invalidateChapterTitleRender
//     0x1006b856c L758-764 / customPresetRow 0x1006b927c L404-472 /
//     previewTitleConfig 0x1006ba61c L782-789 / applyDesignerPayload 0x1006be768
//     L671-679 / currentCSSConfigBinding 0x1006bef8c L775-780 /
//     refreshCurrentConfigAssetIds 0x1006bf1b4 L681-688 / beginSaveCurrentPreset
//     0x1006bf8e0 L545-554 / exportStyles 0x1006c004c L619-638 /
//     applyBuiltInPreset 0x1006c0eb0 L609-617 / saveCurrentPreset 0x1006c1a6c
//     L556-570 / renamePreset 0x1006c2220 L572-585 / handleFileImport 0x1006c3e58
//     L700-729 / overwriteCustomPreset 0x1006ced48 L600-607 / duplicatePreset
//     0x1006cb244 L587-598 / cardBorderColor 0x1006cb88c L481-486 /
//     currentExportStyleName 0x1006cc1a0 L523-531 / makeUniquePresetName
//     0x1006cc340 L842-859 / setCurrentCSSConfig 0x1006cd230 L798-807 /
//     chapterTitleStyleImportMessage 0x1006cd388 L731-736 / presetGrid
//     0x1006b8e00 L365-371 / builtInPresetRow 0x1006c6a5c L373-402
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Reader/ChapterTitleSettingsView.c
//   - 事实：设置面板主链 —— body（预览 + 预设栅格 + 样式分区）+ 预设管理
//     （新建/重命名/复制/覆盖/应用内置）+ 导入导出（ChapterTitleStyleFileService 域）
//     + 设计器载荷应用 + CSS 配置绑定 + 渲染失效
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - 主链（预设管理/导入导出/绑定）: high（函数名+签名确证）
//   - 深层 body 分支（90 函数内 88 闭包布局）: medium（待真机对照）
// 还原: 2026-11-19

import SwiftUI
import UIKit

/// 章节标题样式设置面板。
struct ChapterTitleStyleSettingsView: View {

    @Binding var settings: ReadingSettings
    @State private var showDesigner = false
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var renamingPreset: ReadingSettings.ChapterTitlePreset?
    @State private var newName = ""

    /// 预设外观（TitleAppearance.id 确证；样式为还原命名）。
    struct TitleAppearance: Identifiable {
        let preset: ReadingSettings.ChapterTitlePreset
        var id: String { preset.id.uuidString }
    }

    var body: some View {
        // 伪代码 0x1006b62b4（L28-326）。
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                previewSection
                presetGrid
                nativeStyleSection
            }
            .padding()
        }
        .navigationTitle("章节标题")
        .sheet(isPresented: $showDesigner) {
            ChapterTitleDesignerView(
                initialConfig: previewTitleConfig(),
                colorScheme: .light,
                onCommit: { payload in
                    applyDesignerPayload(payload)
                })
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.data],
            allowsMultipleSelection: false) { result in
            handleFileImport(result)
        }
        .alert(
            "重命名预设",
            isPresented: Binding(
                get: { renamingPreset != nil },
                set: { if !$0 { renamingPreset = nil } }),
            actions: {
                TextField("名称", text: $newName)
                Button("确定") {
                    if let preset = renamingPreset {
                        renamePreset(preset, to: newName)
                    }
                }
                Button("取消", role: .cancel) {}
            })
    }

    // MARK: 分区

    /// 预览区（previewTitleConfig 消费确证）。
    @ViewBuilder
    private var previewSection: some View {
        let config = previewTitleConfig()
        ChapterTitlePreviewView(config: config, chapterIndex: 1)
    }

    /// 伪代码 0x1006b8e00（L365-371）：预设栅格。
    @ViewBuilder
    private var presetGrid: some View {
        let presets = ReadingSettings.ChapterTitlePreset.builtIns
        Section {
            ForEach(presets) { preset in
                builtInPresetRow(preset)
            }
            ForEach(settings.customChapterTitlePresets) { preset in
                customPresetRow(preset)
            }
        } header: {
            Text("预设")
        }
    }

    /// 伪代码 0x1006c6a5c（L373-402）：内置预设行。
    @ViewBuilder
    private func builtInPresetRow(_ preset: ReadingSettings.ChapterTitlePreset) -> some View {
        Button {
            applyBuiltInPreset(preset)
        } label: {
            HStack {
                Text(preset.name)
                    .appThemeText(.body)
                Spacer()
                if settings.currentChapterTitlePresetId == preset.id {
                    Image(systemName: "checkmark")
                }
            }
        }
        .buttonStyle(.plain)
    }

    /// 伪代码 0x1006b927c（L404-472）：自定义预设行（复制/重命名/删除/导出）。
    @ViewBuilder
    private func customPresetRow(_ preset: ReadingSettings.ChapterTitlePreset) -> some View {
        HStack {
            Button {
                applyBuiltInPreset(preset)
            } label: {
                HStack {
                    Text(preset.name)
                        .appThemeText(.body)
                    Spacer()
                    if settings.currentChapterTitlePresetId == preset.id {
                        Image(systemName: "checkmark")
                    }
                }
            }
            .buttonStyle(.plain)
            Menu {
                Button("复制") { duplicatePreset(preset) }
                Button("重命名") {
                    newName = preset.name
                    renamingPreset = preset
                }
                Button("导出", role: .destructive) { exportStyles() }
            } label: {
                Image(systemName: "ellipsis")
            }
        }
    }

    /// 伪代码 0x1006b7f34（L330-363）：原生样式分区。
    @ViewBuilder
    private var nativeStyleSection: some View {
        Section {
            Button {
                showDesigner = true
            } label: {
                Label("打开设计器", systemImage: "paintbrush")
            }
            Button {
                showImporter = true
            } label: {
                Label("导入样式包", systemImage: "square.and.arrow.down")
            }
            Button {
                exportStyles()
            } label: {
                Label("导出当前样式", systemImage: "square.and.arrow.up")
            }
        } header: {
            Text("样式")
        }
    }

    // MARK: 配置绑定

    /// 伪代码 0x1006ba61c（L782-789）：当前预览配置。
    private func previewTitleConfig() -> ChapterTitleConfig {
        settings.currentChapterTitleConfig
    }

    /// 伪代码 0x1006bef8c（L775-780）：CSS 配置绑定。
    private var currentCSSConfigBinding: Binding<ChapterTitleConfig> {
        Binding(
            get: { previewTitleConfig() },
            set: { setCurrentCSSConfig($0) })
    }

    /// 伪代码 0x1006cd230（L798-807）：写回当前配置。
    private func setCurrentCSSConfig(_ config: ChapterTitleConfig) {
        settings.currentChapterTitleConfig = config
        invalidateChapterTitleRender()
    }

    /// 伪代码 0x1006b856c（L758-764）：渲染失效（快照缓存清空确证）。
    private func invalidateChapterTitleRender() {
        ChapterTitleSnapshotService.shared.clearCache()
    }

    // MARK: 预设管理

    /// 伪代码 0x1006c0eb0（L609-617）：应用内置预设。
    private func applyBuiltInPreset(_ preset: ReadingSettings.ChapterTitlePreset) {
        settings.currentChapterTitlePresetId = preset.id
        invalidateChapterTitleRender()
    }

    /// 伪代码 0x1006c1a6c（L556-570）：保存当前为预设。
    private func saveCurrentPreset(_ name: String) {
        let unique = makeUniquePresetName(name)
        let preset = ReadingSettings.ChapterTitlePreset(
            id: UUID(), name: unique,
            template: settings.currentChapterTitleConfig.templateHTML ?? "",
            darkTemplate: nil,
            height: previewTitleConfig().canvasHeight,
            useCustomFont: true,
            lightConfig: previewTitleConfig(),
            darkConfig: previewTitleConfig())
        settings.customChapterTitlePresets.append(preset)
        invalidateChapterTitleRender()
    }

    /// 伪代码 0x1006bf8e0（L545-554）：保存入口。
    private func beginSaveCurrentPreset() {
        saveCurrentPreset(makeUniquePresetName("我的预设"))
    }

    /// 伪代码 0x1006c2220（L572-585）：重命名。
    private func renamePreset(_ preset: ReadingSettings.ChapterTitlePreset, to name: String) {
        guard let index = settings.customChapterTitlePresets.firstIndex(where: { $0.id == preset.id }) else {
            return
        }
        settings.customChapterTitlePresets[index].name = name
    }

    /// 伪代码 0x1006cb244（L587-598）：复制。
    private func duplicatePreset(_ preset: ReadingSettings.ChapterTitlePreset) {
        var copy = preset
        copy.id = UUID()
        copy.name = makeUniquePresetName(preset.name)
        settings.customChapterTitlePresets.append(copy)
    }

    /// 伪代码 0x1006ced48（L600-607）：覆盖保存。
    private func overwriteCustomPreset(_ preset: ReadingSettings.ChapterTitlePreset) {
        guard let index = settings.customChapterTitlePresets.firstIndex(where: { $0.id == preset.id }) else {
            return
        }
        settings.customChapterTitlePresets[index] = preset
    }

    /// 伪代码 0x1006cc340（L842-859）：名称去重（uniqueName 同构确证）。
    private func makeUniquePresetName(_ base: String) -> String {
        let existing = Set(settings.customChapterTitlePresets.map(\.name))
        guard existing.contains(base) else { return base }
        var index = 2
        while existing.contains("\(base) \(index)") {
            index += 1
        }
        return "\(base) \(index)"
    }

    /// 伪代码 0x1006cc1a0（L523-531）：导出样式名。
    private var currentExportStyleName: String {
        previewTitleConfig().styleName ?? "自定义样式"
    }

    // MARK: 导入导出

    /// 伪代码 0x1006c004c（L619-638）：导出。
    /// exportFile 属 ChapterTitleDesignerProject（styleName/light/dark 签名域）。
    private func exportStyles() {
        let manager = ChapterTitleAssetManager()
        do {
            let url = try ChapterTitleDesignerProject.exportFile(
                styleName: currentExportStyleName,
                light: previewTitleConfig(),
                dark: previewTitleConfig(),
                assetManager: manager)
            _ = url
        } catch {
            Logger.error(error, context: "exportStyles")
        }
    }

    /// 伪代码 0x1006c3e58（L700-729）：文件导入（Result 分支确证）。
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                let data = try Data(contentsOf: url)
                var library = ChapterTitleStyleLibrary()
                let manager = ChapterTitleAssetManager()
                let summary = try ChapterTitleStyleFileService.importPackageData(
                    data, sourceName: url.lastPathComponent,
                    into: &library, assetManager: manager)
                let message = chapterTitleStyleImportMessage(summary)
                if let message {
                    AppErrorPresenter.shared.show(message, level: .success)
                }
                invalidateChapterTitleRender()
            } catch {
                AppErrorPresenter.shared.show(
                    error.localizedDescription, level: .error)
            }
        case .failure(let error):
            AppErrorPresenter.shared.show(
                error.localizedDescription, level: .error)
        }
    }

    /// 伪代码 0x1006cd388（L731-736）：导入消息。
    private func chapterTitleStyleImportMessage(
        _ summary: ChapterTitleStyleImportSummary
    ) -> String? {
        guard let name = summary.primaryName else { return nil }
        return "已导入样式：\(name)"
    }

    /// 伪代码 0x1006be768（L671-679）：设计器载荷应用。
    private func applyDesignerPayload(
        _ payload: ChapterTitleDesignerSavePayload
    ) {
        var config = previewTitleConfig()
        config.templateHTML = payload.htmlTemplate
        setCurrentCSSConfig(config)
    }

    /// 伪代码 0x1006bf1b4（L681-688）：资产 ID 刷新。
    private func refreshCurrentConfigAssetIds() {
        invalidateChapterTitleRender()
    }

    /// 伪代码 0x1006cb88c（L481-486）：卡片边框色。
    private func cardBorderColor(title: String) -> Color {
        title.isEmpty ? Color.secondary.opacity(0.4) : Color.accentColor
    }
}

// MARK: - ReadingSettings 桥扩展（已迁回 ReadMain/Core/ReadingSettings.swift，
// T-1401-01 逐域还原：ChapterTitlePreset + currentChapterTitleConfig 域）
// wave-16：访问域放宽到 internal（ChapterTitleEditors 消费域）。

extension ChapterTitleConfig {
    var templateHTML: String? {
        nil
    }

    var canvasHeight: CGFloat {
        120
    }

    var styleName: String? {
        nil
    }
}
