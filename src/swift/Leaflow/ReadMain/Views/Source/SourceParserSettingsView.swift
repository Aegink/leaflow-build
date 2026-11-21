// 原路径: ReadMain/Views/Source/SourceParserSettingsView.swift
// 证据:
//   - PGO: 53 条记录（index/task_functions.csv T-401-07 /
//     SourceParserSettingsView.swift；全部 pgo_only —— 无独立伪代码块，
//     按闭包签名族还原）。覆盖：sourceService getter / body 闭包族
//     （Section1：HStack(名称 + Spacer + appThemeText) + 添加 Button
//     (Label) + disabled ×2 / Section2：DynamicViewContent.onDelete + 行
//     (VStack(Text lineLimit) + Spacer + _ConditionalContent foregroundColor
//     启用/禁用双色) / Section3：padding + footer Text + TupleView<(font,
//     RuleTypeRow ×5)>；ImportSourceSheet（copiedFileImporter 多选 +
//     async 导入 + Result<[URL]> 闭包）；ExportSourceView sheet；
//     TupleView<(Button, Button)> 启用全部/禁用全部）
//   - CovMap: 行号映射（index/restoration_status.csv）
//   - IDA: 无独立伪代码（pgo_only 全家）
//   - 事实：规则类型行 ×5（RuleTypeRow TupleView 确证）；导入经
//     copiedFileImporter 多选（签名确证）；删除经 onDelete(IndexSet)；
//     sourceService getter（ivar 域确证）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: medium（pgo_only 签名族结构性还原；文案待真机对照）
// 还原: 2026-11-20

import SwiftUI
import UniformTypeIdentifiers

/// 解析设置视图（本地解析源管理）。
struct SourceParserSettingsView: View {

    /// 服务实例（ivar getter 签名确证）。
    private let sourceService = SourceService()

    @State private var sources: [BookSource] = []
    @State private var showImportSheet = false
    @State private var showExportSheet = false
    @State private var showImporter = false

    var body: some View {
        // 闭包签名族：三 Section Form。
        List {
            // Section1：标题行 + 添加按钮（disabled ×2 域确证）。
            Section {
                HStack {
                    Text("本地解析源")
                    Spacer()
                    Text("\(sources.count)")
                        .appThemeText(.caption, opacity: 0.6)
                }
                Button {
                    showImportSheet = true
                } label: {
                    Label("从剪贴板导入", systemImage: "doc.on.clipboard")
                }
                .disabled(isRunning)
                Button {
                    showImporter = true
                } label: {
                    Label("导入配置文件", systemImage: "folder")
                }
                .disabled(isRunning)
            }
            // Section2：源列表 + onDelete（签名确证）。
            Section {
                ForEach(sources, id: \.bookSourceUrl) { source in
                    // 行：VStack(名称 lineLimit) + Spacer + 双色标记
                    //（_ConditionalContent foregroundColor 确证）。
                    HStack {
                        VStack(alignment: .leading, spacing: 2.0) {
                            Text(source.bookSourceName)
                                .lineLimit(1)
                            Text(source.bookSourceUrl)
                                .appThemeText(.caption, opacity: 0.5)
                                .lineLimit(1)
                        }
                        Spacer()
                        Image(
                            systemName: source.enabled
                                ? "checkmark.circle.fill" : "xmark.circle"
                        )
                        .foregroundColor(source.enabled ? .green : .secondary)
                    }
                }
                .onDelete { indexSet in
                    deleteSources(at: indexSet)
                }
            }
            // Section3：规则类型行 ×5 + footer（TupleView<font, RuleTypeRow ×5>
            // 签名确证）。
            Section {
                Text("支持规则类型")
                    .font(.caption)
                RuleTypeRow(title: "搜索规则", supported: true)
                RuleTypeRow(title: "详情规则", supported: true)
                RuleTypeRow(title: "目录规则", supported: true)
                RuleTypeRow(title: "正文规则", supported: true)
                RuleTypeRow(title: "发现规则", supported: true)
            } footer: {
                Text("本地解析源与远程后端互斥；启用后按本地规则解析。")
                    .appThemeText(.caption, opacity: 0.6)
                    .padding(.vertical, 4.0)
            }
        }
        .navigationTitle("解析设置")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // TupleView<(Button, Button)> 启用全部/禁用全部（签名确证）。
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("启用全部") {
                    toggleAll(enabled: true)
                }
                Button("禁用全部") {
                    toggleAll(enabled: false)
                }
            }
        }
        .sheet(isPresented: $showImportSheet) {
            // closure #2 ImportSourceSheet（copiedFileImporter 多选确证）。
            ImportSourceSheet { text in
                await importText(text)
            }
        }
        .sheet(isPresented: $showExportSheet) {
            // closure #3 ExportSourceView（签名确证）。
            ExportSourceView(sources: sources)
        }
        .copiedFileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.json, .plainText]
        ) { result in
            // closure #3 (Result<[URL]>)（签名确证）。
            switch result {
            case .success(let urls):
                Task {
                    for url in urls {
                        await importFile(url)
                    }
                }
            case .failure(let error):
                Logger.log(
                    "件选择失败: \(error.localizedDescription)", level: .error)
            }
        }
        .onAppear {
            sources = sourceService.bookSources.filter { $0.enabled }
        }
    }

    private var isRunning: Bool { false }

    // MARK: 动作

    /// 文本导入（importSources(from:) 真身确证）。
    private func importText(_ text: String) async {
        let count = await MainActor.run {
            SourceService().importSources(from: text)
        }
        await MainActor.run {
            sources = SourceService().bookSources.filter { $0.enabled }
            Logger.log("导入 \(count) 条", level: .info)
        }
    }

    /// 文件导入（Data(contentsOf:) 域确证）。
    private func importFile(_ url: URL) async {
        if let text = try? String(contentsOf: url, encoding: .utf8) {
            await importText(text)
        }
    }

    /// 删除（onDelete(IndexSet) 签名确证）。
    private func deleteSources(at offsets: IndexSet) {
        for index in offsets {
            let source = sources[index]
            _ = SourceService().updateSource(
                oldUrl: source.bookSourceUrl, source: source)
        }
        sources.remove(atOffsets: offsets)
    }

    /// 全部启用/禁用（TupleView<(Button, Button)> 域确证）。
    private func toggleAll(enabled: Bool) {
        _ = SourceService().batchToggleSources(
            urls: Set(sources.map(\.bookSourceUrl)), enable: enabled)
        sources = SourceService().bookSources.filter { $0.enabled }
    }
}

/// 规则类型行（RuleTypeRow.body 签名确证）。
struct RuleTypeRow: View {
    let title: String
    let supported: Bool

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(supported ? "支持" : "不支持")
                .appThemeText(.caption)
                .foregroundColor(supported ? .green : .secondary)
        }
    }
}

/// 导入面板（ImportSourceSheet.body 签名确证；copiedFileImporter 多选）。
struct ImportSourceSheet: View {
    let onImport: (String) async -> Void

    @State private var pasteText: String = ""
    @State private var showImporter = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 12.0) {
                TextEditor(text: $pasteText)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 200.0)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .cornerRadius(8, antialiased: true)
                Button {
                    Task {
                        await onImport(pasteText)
                        dismiss()
                    }
                } label: {
                    Label("文本导入", systemImage: "doc.plaintext")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    pasteText.trimmingCharacters(
                        in: .whitespacesAndNewlines).isEmpty)
                Button {
                    if let text = UIPasteboard.general.string {
                        pasteText = text
                    }
                } label: {
                    Label("粘贴", systemImage: "doc.on.clipboard")
                }
                Button {
                    showImporter = true
                } label: {
                    Label("导入配置文件", systemImage: "folder")
                }
                Spacer(minLength: 0)
            }
            .padding(.all, 16.0)
            .navigationTitle("导入")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                }
            }
            // copiedFileImporter（签名确证；现行 Shared 扩展单文件重载，
            // Result<[URL]> 多选随 CopiedFileImporter 分册对齐）。
            .copiedFileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.json, .plainText]
            ) { result in
                switch result {
                case .success(let url):
                    Task {
                        if let text = try? String(
                            contentsOf: url, encoding: .utf8) {
                            await onImport(text)
                        }
                        dismiss()
                    }
                case .failure:
                    break
                }
            }
        }
    }
}
