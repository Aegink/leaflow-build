// 原路径: ReadMain/Views/Source/ImportSourceView.swift
// 0x100ba9238 L18-112：文件、文本、结果、进度与工具栏。
// 0x100bab274 / 0x100bacaf0 L114-132：异步导入，成功回调后延迟关闭。
// 0x100bac4ec L134-150：严格 UTF-8 文件读取。类型表13446-13457确证
// sourceService / targetRemote / onSuccess，不含重建版曾添加的 showEditor。
import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct ImportSourceView: View {
    @ObservedObject var sourceService: SourceService
    var targetRemote: Bool
    let onSuccess: () -> Void

    @State private var sourceText = ""
    @State private var isImporting = false
    @State private var resultMessage: String?
    @State private var isSuccess = false
    @State private var showFileImporter = false
    @Environment(\.dismiss) private var dismiss

    init(
        sourceService: SourceService = .shared,
        targetRemote: Bool = false, onSuccess: @escaping () -> Void = {}
    ) {
        self.sourceService = sourceService
        self.targetRemote = targetRemote
        self.onSuccess = onSuccess
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    showFileImporter = true
                } label: {
                    Label("从文件导入", systemImage: "folder")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.borderless)
                .disabled(isImporting)

                TextEditor(text: $sourceText)
                    .font(.system(.body, design: .monospaced))
                    .accessibilityLabel("配置文本")
                    .accessibilityIdentifier("source-import-text")
                    .disabled(isImporting)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if let resultMessage {
                    Text(resultMessage)
                        .foregroundStyle(isSuccess ? Color.green : Color.red)
                        .font(.footnote)
                        .textSelection(.enabled)
                        .accessibilityIdentifier("source-import-result")
                }
                Button(action: performImport) {
                    if isImporting {
                        ProgressView()
                    } else {
                        Text("导入").fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isImporting || sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("source-import-submit")
            }
            .padding(12)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("导入配置文件")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                        .disabled(isImporting)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("粘贴") {
                        if let text = UIPasteboard.general.string { sourceText = text }
                    }
                    .disabled(isImporting)
                }
            }
            .interactiveDismissDisabled(isImporting)
            .copiedFileImporter(
                isPresented: $showFileImporter, allowedContentTypes: [.json, .plainText]
            ) { result in
                switch result {
                case .success(let url): importFromFile(url)
                case .failure(let error):
                    isSuccess = false
                    resultMessage = "文件选择失败：\(error.localizedDescription)"
                }
            }
        }
    }

    private func performImport() {
        guard !isImporting else { return }
        isImporting = true
        resultMessage = nil
        let text = sourceText
        Task { @MainActor in
            let count = await sourceService.importSourcesAsync(
                from: text, storageKind: targetRemote ? .remote : .local)
            isSuccess = count >= 0
            guard isSuccess else {
                isImporting = false
                resultMessage = sourceService.lastImportError ?? "导入失败"
                return
            }
            resultMessage = "导入成功：\(count) 条新增配置"
            onSuccess()
            // 0x100bacaf0 L122-124：成功回调后等待1秒再关闭，期间不接受重复提交。
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            dismiss()
        }
    }

    private func importFromFile(_ url: URL) {
        do {
            let data = try Data(contentsOf: url)
            guard let text = String(data: data, encoding: .utf8) else {
                isSuccess = false
                resultMessage = "文件编码不支持"
                return
            }
            sourceText = text
            resultMessage = "已读取「\(url.lastPathComponent)」（有效的 UTF-8 文本）"
            isSuccess = true
        } catch {
            isSuccess = false
            resultMessage = "读取文件失败：\(error.localizedDescription)"
        }
    }
}
