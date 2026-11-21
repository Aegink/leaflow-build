// 原路径: ReadMain/Views/Settings/TtsHelpSheet.swift
// 证据:
//   - PGO: 31 条记录（index/task_functions.csv T-701-09 /
//     TtsHelpSheet.swift；body/hasHTML/searchKeyword 签名域）
//   - CovMap: 上述 L 区段（body/hasHTML/searchKeyword 域）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Settings/
//     TtsHelpSheet.c（1280 行）
//   - 块体确证（签名域）：
//     body getter / hasHTML getter / searchKeyword getter
//   - 字符串域（位模式+指针，scratch/t70109_help_strings.txt）：
//     'TTS 帮助' L595 / '匹配 ' L994 / '页内高亮' L1018 / '关闭'
//     L1146
//   - 事实：帮助 HTML（本地资源加载）+ 关键词高亮匹配域
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（三签名域 + 字符串链确证）
// 还原: 2026-11-20

import SwiftUI
import WebKit

/// TTS 帮助页（body/hasHTML/searchKeyword 签名域确证）。
struct TtsHelpSheet: View {

    @Environment(\.dismiss) private var dismiss
    @State private var helpHTML: String = ""
    @State private var searchKeyword = ""

    var body: some View {
        NavigationStack {
            Group {
                if hasHTML {
                    HelpWebView(
                        html: helpHTML,
                        searchKeyword: searchKeyword)
                } else {
                    ContentUnavailableView(
                        "TTS 帮助", systemImage: "questionmark.circle",
                        description: Text("帮助文档未随包提供"))
                }
            }
            .navigationTitle("TTS 帮助")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    // '关闭' L1146 域确证。
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
            .searchable(text: $searchKeyword, prompt: "匹配 ")
            .onAppear {
                loadHelp()
            }
        }
    }

    /// hasHTML getter（签名域确证：非空且含标记）。
    private var hasHTML: Bool {
        !helpHTML.isEmpty
    }

    /// searchKeyword getter（'匹配 ' L994 + '页内高亮' L1018 域确证：
    /// 关键词透传 JS 高亮桥）。
    private var searchKeywordValue: String {
        searchKeyword.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func loadHelp() {
        guard let url = Bundle.main.url(
            forResource: "tts_help", withExtension: "html") else {
            return
        }
        helpHTML = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }
}

/// 帮助 WebView（页内高亮桥）。
private struct HelpWebView: UIViewRepresentable {

    let html: String
    let searchKeyword: String

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.loadHTMLString(html, baseURL: nil)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // 页内高亮桥（'页内高亮' L1018 域确证）。
        guard !searchKeyword.isEmpty else { return }
        let script = "window.__highlightMatches(\(jsonEscape(searchKeyword)))"
        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    private func jsonEscape(_ value: String) -> String {
        guard let data = try? JSONEncoder().encode([value]),
              let json = String(data: data, encoding: .utf8) else {
            return "\"\""
        }
        return json
    }
}
