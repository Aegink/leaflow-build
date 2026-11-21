// 原路径: ReadMain/Views/Source/ExportSourceView.swift
// 证据:
//   - PGO: 35 条记录（index/task_functions.csv T-401-04 /
//     ExportSourceView.swift；18 个伪代码块 + 17 pgo_only）。关键地址：
//     body 0x100ba2644 L17-104 / body 闭包 0x100ba3510 L19-89 /
//     onAppear Task 0x100ba3c1c L21-27 / 预览文本 0x100ba411c L38-38 /
//     按钮组 0x100ba4504 L57-86 / 复制反馈 0x100ba56a4 L58-64 / 工具栏
//     0x100ba5ad8 L79-82 / 关闭 0x100ba5e20 L92-96 / onDisappear 清理
//     0x100ba5fdc L94-94 / generateExport 闭包3 0x100ba635c L110-122 /
//     闭包4 0x100ba6ba8 L124-134 / cleanupTempFile 0x100ba6078 L137-141 /
//     shareSourcesDirectly 0x100ba6d04 L171-197 / 完成闭包 0x100ba3c80
//     L179-181
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Source/ExportSourceView.c
//     （2147 行）
//   - 字符串确证（IPA 指针/位模式）："info.circle" / "doc.text" /
//     "将导出 " + N + " 个配置" / "格式化输出" / "正在生成..." / "已复制" /
//     "配置文件_" / ".json"（位串 0x6E6F736A2EAAB8E4 '个.json' 域）/
//     "Leaflow/ExportSourceView.swift"（0x10127BD20，诊断域确证）/
//     "导出配置文件"（0x10127BD40，标题确证）
//   - 事实：JSONEncoder outputFormatting = [.prettyPrinted, .sortedKeys]
//     （SetAlgebra.init + 两 getter 确证）；String(data:encoding:.utf8) +
//     Data.write 写临时目录（FileManager.default.temporaryDirectory +
//     appendingPathComponent 确证）；ShareLink + UIActivityViewController
//     双出口（rootViewController 经 connectedScenes/windows 链确证）；
//     Data.count → jsonSize 状态；onChange(of: prettyPrint) 重算确证
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - 导出/分享/临时文件链: high（伪代码块体确证）
//   - 视图树形状: medium（结构性还原；布局细节待真机）
// 还原: 2026-11-20

import SwiftUI
import UIKit

/// 书源批量导出视图。
struct ExportSourceView: View {

    let sources: [BookSource]

    // PGO 变量初始化表达式确证：_prettyPrint/_exportText/_previewText/
    // _copied/_isGenerating/_jsonSize。
    @State private var prettyPrint = true
    @State private var exportText: String = ""
    @State private var previewText: String = ""
    @State private var copied = false
    @State private var isGenerating = false
    @State private var jsonSize: String = ""

    /// 临时导出文件（cleanupTempFile 消费确证）。
    @State private var tempFileURL: URL?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        // 伪代码 0x100ba2644（L17-104）：ScrollView(.vertical) + 居中 +
        // systemGroupedBackground + AppThemeManager 字体域。
        NavigationStack {
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 16.0) {
                    // 0x100ba3510（L19-89）：说明区。
                    Label {
                        Text("将导出 \(sources.count) 个配置")
                            .appThemeText(.body)
                    } icon: {
                        Image(systemName: "info.circle")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    // 0x100ba3c1c（L21-27）：生成 Task。
                    if isGenerating {
                        Text("正在生成...")
                            .appThemeText(.caption, opacity: 0.6)
                    } else {
                        // 0x100ba411c（L38-38）：等宽预览。
                        Text(previewText.isEmpty ? exportText : previewText)
                            .font(.system(.caption, design: .monospaced))
                            .lineLimit(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.all, 8.0)
                        if !jsonSize.isEmpty {
                            Text(jsonSize)
                                .appThemeText(.caption, opacity: 0.6)
                        }
                        // 0x100ba4504（L57-86）：分享 + 复制按钮组。
                        ShareLink(item: shareItem()) {
                            Label("分享", systemImage: "doc.text")
                        }
                        .buttonStyle(.borderedProminent)
                        Button {
                            copyToPasteboard()
                        } label: {
                            // 0x100ba56a4（L58-64）：复制反馈。
                            Label(
                                copied ? "已复制" : "复制",
                                systemImage: copied
                                    ? "checkmark.circle" : "doc.on.doc")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(exportText.isEmpty)
                        Toggle("格式化输出", isOn: $prettyPrint)
                    }
                }
                .padding(.all, 12.0)
                .frame(maxWidth: .infinity)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("导出配置文件")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // 0x100ba5ad8（L79-82）+ 0x100ba5e20（L92-96）。
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") {
                        cleanupTempFile()
                        dismiss()
                    }
                }
            }
            .onAppear {
                // 0x100ba3c1c（L21-27）：派发生成。
                Task { await generateExport() }
            }
            .onChange(of: prettyPrint) { _ in
                Task { await generateExport() }
            }
            .onDisappear {
                // 0x100ba5fdc（L94-94）。
                cleanupTempFile()
            }
        }
    }

    // MARK: 导出

    /// generateExport() async（闭包1 @(Bool, [BookSource]) 读态 →
    /// 闭包3 0x100ba635c（L110-122）后台编码落盘 → 闭包4 0x100ba6ba8
    /// （L124-134）MainActor 写回状态；闭包2 为派发壳）。
    private func generateExport() async {
        let (pretty, list) = await MainActor.run {
            (prettyPrint, sources)
        }
        isGenerating = true
        defer { isGenerating = false }
        let triple: (String, String, URL?) = await Task.detached(
            priority: .userInitiated
        ) {
            let encoder = JSONEncoder()
            if pretty {
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            }
            guard let data = try? encoder.encode(list) else {
                return ("", "", nil)
            }
            let json = String(data: data, encoding: .utf8) ?? ""
            let url = Self.writeTempJSONFile(data: data, sources: list)
            return (json, "\(data.count) 字节", url)
        }.value
        await MainActor.run {
            exportText = triple.0
            jsonSize = triple.1
            tempFileURL = triple.2
        }
    }

    /// pgo_only static exportFileName(for:)（"配置文件_" + 时间戳 + ".json"
    /// 位串确证）。
    static func exportFileName(for sources: [BookSource]) -> String {
        let stamp = Int(Date().timeIntervalSince1970)
        return "配置文件_\(stamp).json"
    }

    /// pgo_only static writeTempJSONFile(data:sources:) -> URL?
    ///（temporaryDirectory + appendingPathComponent 确证）。
    static func writeTempJSONFile(
        data: Data, sources: [BookSource]
    ) -> URL? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(exportFileName(for: sources))
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    /// 0x100ba6078（L137-141）：临时文件清理。
    private func cleanupTempFile() {
        if let url = tempFileURL {
            try? FileManager.default.removeItem(at: url)
            tempFileURL = nil
        }
    }

    /// 复制（"已复制" 反馈 0x100ba56a4 确证）。
    private func copyToPasteboard() {
        UIPasteboard.general.string = exportText
        copied = true
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            copied = false
        }
    }

    private func shareItem() -> URL {
        if let url = tempFileURL { return url }
        // exportFileName 为静态域——Self 限定（wave-16）。
        return FileManager.default.temporaryDirectory
            .appendingPathComponent(Self.exportFileName(for: sources))
    }
}

// MARK: - 直接分享

extension ExportSourceView {

    /// 0x100ba6d04（L171-197）：静态直接分享——编码 → 临时文件 →
    /// rootViewController 顶出 UIActivityViewController（完成闭包
    /// 0x100ba3c80 L179-181 清理）。
    static func shareSourcesDirectly(_ sources: [BookSource]) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(sources) else { return }
        guard let url = writeTempJSONFile(data: data, sources: sources) else {
            return
        }
        // scenes → keyWindow 域分步解构（多行闭包解析歧义消解，wave-16）。
        let keyWindow = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .compactMap { scene in scene.windows.first { $0.isKeyWindow } }
            .first
        guard let root = keyWindow?.rootViewController else {
            try? FileManager.default.removeItem(at: url)
            return
        }
        let controller = UIActivityViewController(
            activityItems: [url], applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in
            try? FileManager.default.removeItem(at: url)
        }
        if let popover = controller.popoverPresentationController {
            popover.sourceView = root.view
            popover.sourceRect = root.view.bounds
        }
        root.present(controller, animated: true)
    }
}
