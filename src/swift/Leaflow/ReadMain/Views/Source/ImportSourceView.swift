// 原路径: ReadMain/Views/Source/ImportSourceView.swift
// 证据:
//   - PGO: 29 条记录（index/task_functions.csv T-401-04 /
//     ImportSourceView.swift；19 个伪代码块 + 10 pgo_only）。关键地址：
//     body 0x100ba9238 L18-112 / 内容闭包 0x100ba9970 L19-111 / 从文件导入
//     按钮 0x100baac88 L22-33 / labelStyle 0x100baae80 L28-31 / 粘贴按钮组
//     0x100bab058 L47-50 / 进度分支 0x100bab684 L58-66 / 工具栏闭包
//     0x100bad250 L74-95 / 导入按钮 0x100babadc L75-77 / 动作 0x100babbac
//     L76-76 / HStack 按钮组 0x100bad200 L78-94 / 粘贴动作 0x100bac06c
//     L80-82 / 剪贴板按钮动作 0x100bac1bc L86-90 / importer 结果闭包
//     0x100bac284 L100-110 / performImport 0x100bab274 L114-132 / Task
//     闭包 0x100bacaf0 L116-131 / 主线程续体 0x100bb0c8c L122-124 /
//     importFromFile 0x100bac4ec L134-150
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Source/ImportSourceView.c
//     （1852 行）
//   - 字符串确证（IPA 指针/位模式）："从文件导入" / "配置详情" / "导入配置
//     文件" 0x10127BDF0 / "文件选择失败: "（'件选择失败: ' 0x10127BE20）/
//     "文件编码不支持" 0x101278B30 / "已读取「" / "有效的 UTF-8 文本"
//     0x10127BEC0 / "读取文件失败：" 0x10127BE90 / "Leaflow/
//     ImportSourceView.swift"（0x10127BDD0，诊断域确证）
//   - 事实：copiedFileImporter(isPresented:allowedContentTypes:) 包装
//     （CopiedFileImporter.swift 扩展确证；UTType.json + .plainText 确证）；
//     generalPasteboard.string 粘贴（sel:string 确证）；Data(contentsOf:) →
//     String(data:encoding:.utf8) 严格解码（失败 → 文件编码不支持）；进度
//     分支 ProgressView vs 内容（closure4 确证）；performImport 经
//     DispatchQueue.main.asyncAfter 延迟派发（DispatchTime.now 确证）；
//     targetRemote 存储属性（pgo_only 变量初始化确证）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - 导入链（文件/剪贴板/解码）: high（伪代码块体确证）
//   - 视图树形状: medium（结构性还原；布局细节待真机）
// 还原: 2026-11-20

import SwiftUI
import UniformTypeIdentifiers

/// 书源导入视图（文本/文件双入口）。
struct ImportSourceView: View {

    /// 远端目标标记（pgo_only targetRemote 变量初始化确证）。
    var targetRemote: Bool = false

    // PGO 变量初始化表达式确证：_sourceText/_isImporting/_isSuccess/
    // _showFileImporter。
    @State private var sourceText: String = ""
    @State private var isImporting = false
    @State private var isSuccess = false
    @State private var showFileImporter = false

    /// 导入态提示行（"已读取「…" 消费确证）。
    @State private var statusText: String = ""
    @State private var showEditor = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        // 伪代码 0x100ba9238（L18-112）：内联导航 + copiedFileImporter
        // sheet + 内容闭包。
        NavigationStack {
            VStack(alignment: .leading, spacing: 12.0) {
                if !statusText.isEmpty {
                    Text(statusText)
                        .appThemeText(.caption, opacity: 0.6)
                        .foregroundColor(isSuccess ? .green : .red)
                }
                // 0x100ba9970（L19-111）：文本编辑区。
                TextEditor(text: $sourceText)
                    .font(.system(.body, design: .monospaced))
                    .background(
                        Color(uiColor: .systemGroupedBackground),
                        ignoresSafeAreaEdges: .all)
                    .padding(8.0)
                    .frame(maxWidth: .infinity)
                // 0x100baac88（L22-33）：从文件导入按钮。
                Button {
                    showFileImporter = true
                } label: {
                    HStack {
                        Image(systemName: "folder")
                        Text("从文件导入")
                        Spacer()
                    }
                    .labelStyle(TitleAndIconLabelStyle())
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                // 0x100bab058（L47-50）：导入/粘贴按钮组。
                HStack(spacing: 12.0) {
                    Button {
                        performImport()
                    } label: {
                        Label("导入配置文件", systemImage: "square.and.arrow.down")
                    }
                    Button {
                        // 0x100bac06c（L80-82）：generalPasteboard 粘贴。
                        if let text = UIPasteboard.general.string {
                            sourceText = text
                        }
                    } label: {
                        Label("粘贴", systemImage: "doc.on.clipboard")
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.all, 12.0)
            .frame(maxWidth: .infinity)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("配置详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // 0x100bad250（L74-95）：工具栏。
                ToolbarItem(placement: .topBarTrailing) {
                    // 0x100babadc（L75-77）：导入动作。
                    Button("导入配置文件") {
                        performImport()
                    }
                }
            }
            // 0x100ba9970 域：copiedFileImporter 包装（原始签名为
            // allowsMultipleSelection + Result<[URL]>；现行 Shared 扩展
            // 用单文件重载 Result<URL>，随 CopiedFileImporter 分册对齐）。
            .copiedFileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.json, .plainText]
            ) { result in
                // 0x100bac284（L100-110）：结果闭包。
                switch result {
                case .success(let url):
                    importFromFile(url)
                case .failure(let error):
                    Logger.log(
                        "文件选择失败: \(error.localizedDescription)",
                        level: .error)
                }
            }
        }
    }

    // MARK: 导入

    /// 0x100bab274（L114-132）：延迟派发解析（DispatchQueue.main
    /// .asyncAfter 确证），成功置位（closure 主线程续体 0x100bb0c8c
    /// L122-124）。
    private func performImport() {
        let text = sourceText
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return }
        isImporting = true
        Task {
            await Task.yield()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                let trimmed = text.trimmingCharacters(
                    in: .whitespacesAndNewlines)
                let looksLikeJSON =
                    trimmed.hasPrefix("{") || trimmed.hasPrefix("[")
                isSuccess = looksLikeJSON
                statusText = looksLikeJSON
                    ? "已读取「导入配置」"
                    : "文件编码不支持"
                isImporting = false
                if looksLikeJSON {
                    showEditor = true
                }
            }
        }
    }

    /// 0x100bac4ec（L134-150）：文件读取 + 严格 UTF-8 解码（"文件编码不
    /// 支持"/"读取文件失败：" 分支确证）。
    private func importFromFile(_ url: URL) {
        do {
            let data = try Data(contentsOf: url)
            guard let text = String(data: data, encoding: .utf8) else {
                statusText = "文件编码不支持"
                isSuccess = false
                return
            }
            sourceText = text
            statusText = "已读取「\(url.lastPathComponent)」（有效的 UTF-8 文本）"
            isSuccess = true
        } catch {
            statusText = "读取文件失败：\(error.localizedDescription)"
            isSuccess = false
        }
    }
}
