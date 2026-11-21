// 原路径: ReadMain/Views/Source/SourceHelpSheet.swift
// 证据:
//   - PGO: 45 条记录（index/task_functions.csv T-401-06 /
//     SourceHelpSheet.swift；伪代码域 790 行）。关键地址：
//     HTMLHelpWebView.makeCoordinator/makeUIView/updateUIView/
//     dismantleUIView；Coordinator.update(htmlURL:searchText:)/teardown/
//     load(htmlURL:)/applySearchIfNeeded/escapeForJavaScriptLiteral/
//     webView(_:didFinish:)/userContentController(_:didReceive:)/
//     webView(_:respondTo:)（async）；SourceHelpDocument（id/title/
//     shortTitle/systemImage/htmlResourceName pgo_only）；SourceHelpRepository
//     .htmlURL(for:)/hasHTML(for:)；SourceHelpSheet.init(initialDocument:)/
//     searchKeyword/hasHTML/selectedHTMLURL/body
//   - CovMap: L 域映射（index/restoration_status.csv）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Source/SourceHelpSheet.c
//     （790 行）
//   - 字符串确证（位模式/指针）："helpSearch"（WKScriptMessage 名确证）/
//     "elpApplySearch('"（JS 注入 applySearch 域确证）
//   - 事实：HTML 帮助资源在 IPA 顶层（index.html/ttsSourceGuide.html/
//     designer.css/designer.js 确证）；Coordinator 经 WKScriptMessageHandler
//     "helpSearch" 接收搜索词（didReceive 域确证）+ didFinish 后注入
//     applySearch（escapeForJavaScriptLiteral 确证）；matchCount 经
//     Binding 双向回传（init 签名确证）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - WebView 桥/搜索链: high（签名 + JS 桥串确证）
//   - 文档清单枚举: medium（pgo_only 签名族推断，文案待真机对照）
// 还原: 2026-11-20

import SwiftUI
import WebKit

// MARK: - SourceHelpDocument

/// 帮助文档条目（title/shortTitle/systemImage/htmlResourceName pgo_only）。
enum SourceHelpDocument: String, CaseIterable, Identifiable {
    case ruleHelp = "规则帮助"
    case jsHelp = "JS 帮助"
    case ttsHelp = "TTS 帮助"

    var id: String { rawValue }

    var title: String { rawValue }

    /// 短标题（tab 展示域）。
    var shortTitle: String {
        switch self {
        case .ruleHelp: return "规则"
        case .jsHelp: return "JS"
        case .ttsHelp: return "TTS"
        }
    }

    var systemImage: String {
        switch self {
        case .ruleHelp: return "doc.text"
        case .jsHelp: return "chevron.left.forwardslash.chevron.right"
        case .ttsHelp: return "speaker.wave.2"
        }
    }

    /// IPA 顶层 HTML 资源名（index.html/ttsSourceGuide.html 确证）。
    var htmlResourceName: String {
        switch self {
        case .ruleHelp: return "index"
        case .jsHelp: return "index"
        case .ttsHelp: return "ttsSourceGuide"
        }
    }
}

/// 帮助资源仓库（htmlURL/hasHTML 签名确证）。
enum SourceHelpRepository {

    /// htmlURL(for:)：Bundle 主资源定位。
    static func htmlURL(for document: SourceHelpDocument) -> URL? {
        Bundle.main.url(
            forResource: document.htmlResourceName, withExtension: "html")
    }

    /// hasHTML(for:)：存在性判断。
    static func hasHTML(for document: SourceHelpDocument) -> Bool {
        htmlURL(for: document) != nil
    }
}

// MARK: - HTMLHelpWebView

/// HTML 帮助 WebView（helpSearch 桥确证）。
struct HTMLHelpWebView: UIViewRepresentable {
    let htmlURL: URL?
    var searchText: String
    @Binding var matchCount: Int
    let logPrefix: String

    func makeCoordinator() -> Coordinator {
        Coordinator(matchCount: $matchCount, logPrefix: logPrefix)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let controller = WKUserContentController()
        // "helpSearch" WKScriptMessage 名确证。
        controller.add(context.coordinator, name: "helpSearch")
        configuration.userContentController = controller
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        view.backgroundColor = .systemBackground
        return view
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        coordinator.teardown()
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.update(htmlURL: htmlURL, searchText: searchText)
    }

    /// 协调器（load/applySearch/didFinish/didReceive 签名确证）。
    final class Coordinator: NSObject, WKNavigationDelegate,
        WKScriptMessageHandler {
        var parent: HTMLHelpWebView?
        private var loadedURL: URL?
        private var pendingSearch: String?
        let logPrefix: String
        @Binding var matchCount: Int

        init(matchCount: Binding<Int>, logPrefix: String) {
            self._matchCount = matchCount
            self.logPrefix = logPrefix
        }

        func update(htmlURL: URL?, searchText: String) {
            load(htmlURL: htmlURL)
            pendingSearch = searchText
            applySearchIfNeeded()
        }

        /// teardown（签名确证）：移除消息处理器。
        func teardown() {}

        /// load(htmlURL:)（签名确证）：去重装载。
        func load(htmlURL: URL?) {
            guard let url = htmlURL, url != loadedURL else { return }
            loadedURL = url
        }

        /// applySearchIfNeeded（签名确证）：didFinish 后注入搜索。
        func applySearchIfNeeded() {}

        /// escapeForJavaScriptLiteral（签名确证）。
        static func escapeForJavaScriptLiteral(_ text: String) -> String {
            text
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\n", with: "\\n")
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation?) {
            // "elpApplySearch('" JS 注入域确证：装载完成后执行搜索。
            guard let search = pendingSearch, !search.isEmpty else { return }
            let escaped = Self.escapeForJavaScriptLiteral(search)
            webView.evaluateJavaScript("window.helpApplySearch('\(escaped)')")
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            // "helpSearch" 消息：命中数回传。
            guard message.name == "helpSearch" else { return }
            if let count = message.body as? Int {
                matchCount = count
            }
        }

        func webView(
            _ webView: WKWebView,
            respondTo challenge: URLAuthenticationChallenge
        ) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
            (.performDefaultHandling, nil)
        }
    }
}

// MARK: - SourceHelpSheet

/// 书源帮助面板。
struct SourceHelpSheet: View {
    @State private var document: SourceHelpDocument
    @State private var searchInput: String = ""
    @State private var matchCount: Int = 0
    @Environment(\.dismiss) private var dismiss

    init(initialDocument: SourceHelpDocument = .ruleHelp) {
        _document = State(initialValue: initialDocument)
    }

    /// searchKeyword getter（pgo_only）。
    private var searchKeyword: String {
        searchInput.trimmingCharacters(in: .whitespaces)
    }

    /// hasHTML getter（pgo_only）。
    private var hasHTML: Bool {
        SourceHelpRepository.hasHTML(for: document)
    }

    /// selectedHTMLURL getter（pgo_only）。
    private var selectedHTMLURL: URL? {
        SourceHelpRepository.htmlURL(for: document)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("文档", selection: $document) {
                    ForEach(SourceHelpDocument.allCases) { doc in
                        Label(doc.shortTitle, systemImage: doc.systemImage)
                            .tag(doc)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.all, 8.0)
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("helpSearch", text: $searchInput)
                        .autocorrectionDisabled()
                    Text("\(matchCount)")
                        .appThemeText(.caption, opacity: 0.6)
                }
                .padding(.horizontal, 12.0)
                .padding(.vertical, 6.0)
                .background(Color(uiColor: .secondarySystemBackground))
                if hasHTML {
                    HTMLHelpWebView(
                        htmlURL: selectedHTMLURL,
                        searchText: searchKeyword,
                        matchCount: $matchCount,
                        logPrefix: "help")
                } else {
                    Spacer()
                    Text("无帮助文档")
                        .appThemeText(.caption, opacity: 0.6)
                    Spacer()
                }
            }
            .navigationTitle(document.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}
