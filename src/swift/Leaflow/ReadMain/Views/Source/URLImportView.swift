// 原路径: ReadMain/Views/Source/URLImportView.swift
// 证据:
//   - PGO: 23 条记录（index/task_functions.csv T-401-07 /
//     URLImportView.swift；2 个伪代码块）。关键地址：
//     body 0x100cf0b2c L17-77 / performImport 0x100cf2878 L79-112
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Source/URLImportView.c
//     （1239 行）
//   - 字符串确证（位模式/指针）："URL导入"（L98 标题位模式）/
//     "Leaflow/URLImportView.swift"（@ptr L1083，诊断域确证）/
//     LocalizedStringKey 插值域（performImport L79-112：literalCapacity 9 +
//     interpolationCount 1 + 0x85E5BCAFE54C5255 'URL 导…' 位模式确证）
//   - 事实：body 8.0 间距常量（0x4030000000000000 @L87 域确证）；
//     performImport 经 Task 派发（L18 行执行器断言确证），状态插值回传
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - 导入链: medium-high（签名 + 域串确证）
//   - 布局细节: medium（结构性还原，待真机对照）
// 还原: 2026-11-20

import SwiftUI

/// URL 导入视图（书源/替换规则混合识别，"源/替换规则）" 域交叉）。
struct URLImportView: View {

    /// 导入目标回调（识别结果回传）。
    var onImported: ((Int) -> Void)?

    @State private var urlText: String = ""
    @State private var isImporting = false
    @State private var statusText: String = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        // 伪代码 0x100cf0b2c（L17-77）：输入 + 导入按钮 + 状态行。
        NavigationStack {
            VStack(alignment: .leading, spacing: 8.0) {
                TextField(
                    "URL导入（https://…）",
                    text: $urlText)
                    .font(.system(.body, design: .monospaced))
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
                Button {
                    performImport()
                } label: {
                    if isImporting {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("URL导入", systemImage: "arrow.down.doc")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(urlText.isEmpty || isImporting)
                if !statusText.isEmpty {
                    Text(statusText)
                        .appThemeText(.caption, opacity: 0.7)
                        .textSelection(.enabled)
                }
                Spacer()
            }
            .padding(.all, 16.0)
            .navigationTitle("URL导入")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    // MARK: 导入

    /// performImport（0x100cf2878 L79-112）：Task 派发 + 远程拉取识别
    ///（状态插值 9 字面量 1 插值确证）。
    private func performImport() {
        let target = urlText.trimmingCharacters(in: .whitespaces)
        guard let url = URL(string: target),
              url.scheme == "http" || url.scheme == "https"
        else {
            statusText = "无效的登录 URL"
            return
        }
        isImporting = true
        statusText = ""
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let text = String(data: data, encoding: .utf8) ?? ""
                let count = await MainActor.run { () -> Int in
                    SourceService().importSources(from: text)
                }
                await MainActor.run {
                    isImporting = false
                    statusText = "URL 导入成功：\(count) 条"
                    onImported?(count)
                }
            } catch {
                await MainActor.run {
                    isImporting = false
                    statusText = "URL 导入失败：\(error.localizedDescription)"
                }
            }
        }
    }
}
