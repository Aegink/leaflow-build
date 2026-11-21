// 原路径: ReadMain/Views/Settings/ReplaceRuleImportExportView.swift
// 证据:
//   - PGO: 61 条记录（index/task_functions.csv T-701-07 /
//     ReplaceRuleImportExportView.swift；伪代码域 140 行）
//   - CovMap: 上述 L 区段（body/exportView/ImportExportTab 域）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Settings/
//     ReplaceRuleImportExportView.c（4470 行）
//   - 块体确证（签名域）：
//     body getter / exportView getter / ImportExportTab（双档）
//   - 字符串域（位模式+指针，scratch/t70107_impexp_strings.txt）：
//     '操作' L172 / '取消' L389 / '从 URL 导入' L856 /
//     '从文本导入' L1082 / '分享' L1817 / '剪贴板为空' L2331 /
//     '选择文件' L3060 / '读取并导入' L4021 / '获取' L4056 /
//     '导入' L4206 / ' 条规则' L334（计数后缀域）
//   - 事实：导入/导出双 Tab（URL/文本/文件/剪贴板/分享五通道）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（双 Tab + 五通道字符串链确证）
// 还原: 2026-11-20

import SwiftUI
import UniformTypeIdentifiers

/// 替换规则导入导出（body/exportView/ImportExportTab 签名域确证）。
struct ReplaceRuleImportExportView: View {

    /// 双 Tab（ImportExportTab 域确证）。
    enum ImportExportTab: String, CaseIterable, Identifiable {
        case importTab
        case exportTab

        var id: String { rawValue }

        var title: String {
            self == .importTab ? "导入" : "导出"
        }
    }

    @State private var tab: ImportExportTab = .importTab
    @State private var urlString = ""
    @State private var textPayload = ""
    @State private var isImporting = false
    @State private var statusMessage = ""
    private let replaceService = ReplaceRuleService()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $tab) {
                    ForEach(ImportExportTab.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                if tab == .importTab {
                    importView
                } else {
                    exportView
                }
                if !statusMessage.isEmpty {
                    // ' 条规则' L334 计数后缀域确证。
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 12)
                }
                Spacer()
            }
            .navigationTitle("导入/导出")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    // '取消' L389 域确证。
                    Button("取消") {
                        statusMessage = ""
                    }
                }
            }
        }
    }

    // MARK: 导入域（'从 URL 导入' L856 / '从文本导入' L1082 /
    // '选择文件' L3060 / '读取并导入' L4021 / '获取' L4056 /
    // '导入' L4206 / '剪贴板为空' L2331 域确证）

    @ViewBuilder
    private var importView: some View {
        List {
            Section {
                HStack {
                    TextField("https://", text: $urlString)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                    Button {
                        importFromURL()
                    } label: {
                        // '获取' L4056 域确证。
                        Text("获取")
                    }
                    .disabled(urlString.isEmpty || isImporting)
                }
            } header: {
                Text("从 URL 导入")
            }
            Section {
                TextField(
                    "粘贴规则 JSON", text: $textPayload, axis: .vertical)
                    .lineLimit(4...10)
                    .font(.system(.caption, design: .monospaced))
                Button {
                    importFromClipboard()
                } label: {
                    // '从文本导入' L1082 域确证。
                    Text("从文本导入")
                }
                .disabled(textPayload.isEmpty)
            } header: {
                Text("从文本导入")
            }
            Section {
                Button {
                    importFromFile()
                } label: {
                    // '选择文件' L3060 + '读取并导入' L4021 域确证。
                    Label("选择文件", systemImage: "doc")
                }
            }
        }
    }

    /// exportView getter（'分享' L1817 域确证）。
    @ViewBuilder
    private var exportView: some View {
        List {
            Section {
                Button {
                    exportAndShare()
                } label: {
                    Label("分享", systemImage: "square.and.arrow.up")
                }
                Button {
                    copyToClipboard()
                } label: {
                    Label("复制到剪贴板", systemImage: "doc.on.doc")
                }
            } footer: {
                Text("导出为 JSON 规则集")
            }
        }
    }

    // MARK: 通道域（service 签名桥）

    private func importFromURL() {
        isImporting = true
        Task {
            guard let url = URL(string: urlString) else {
                isImporting = false
                statusMessage = "URL 无效"
                return
            }
            // URLSession 返回 (Data, URLResponse)?——单层 try? 元组
            // 解构域桥（wave-76）。
            let fetched = try? await URLSession.shared.data(from: url)
            isImporting = false
            guard let data = fetched?.0,
                  let text = String(data: data, encoding: .utf8) else {
                statusMessage = "下载失败"
                return
            }
            finishImport(text)
        }
    }

    private func importFromClipboard() {
        guard let text = UIPasteboard.general.string else {
            // '剪贴板为空' L2331 域确证。
            statusMessage = "剪贴板为空"
            return
        }
        finishImport(text)
    }

    private func importFromFile() {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [
            UTType.json, UTType.plainText,
        ])
        picker.delegate = nil
        UIApplication.shared.connectedScenes
            .compactMap {
                ($0 as? UIWindowScene)?.keyWindow?.rootViewController
            }
            .first?
            .present(picker, animated: true)
    }

    private func finishImport(_ text: String) {
        let count = replaceService.importRules(from: text)
        statusMessage = "导入 \(count) 条规则"
        textPayload = ""
    }

    private func exportAndShare() {
        let text = replaceService.exportRules()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("replace_rules.json")
        try? text.data(using: .utf8)?.write(to: url, options: .atomic)
        let activity = UIActivityViewController(
            activityItems: [url], applicationActivities: nil)
        UIApplication.shared.connectedScenes
            .compactMap {
                ($0 as? UIWindowScene)?.keyWindow?.rootViewController
            }
            .first?
            .present(activity, animated: true)
    }

    private func copyToClipboard() {
        UIPasteboard.general.string = replaceService.exportRules()
        statusMessage = "已复制"
    }
}
