// 原路径: ReadMain/Views/Shared/BrowserPageView.swift
// 证据:
//   - PGO: 94 个主函数（index/task_functions.csv T-101-06 / BrowserPageView.swift），
//     地址：currentPageURL 0x100b4684c L42-44 / displayTitle 0x100b469b4 L46-49 /
//     browserBackgroundColor 0x100b46ba0 L61-64 / body 0x100b4720c L66-116
//     (+closure #1 0x100b47ce8 / closure #2 0x100b495ec / closure #3 0x100b49678) /
//     bottomChrome 0x100b48f1c L139-152 / handleKeyboardPresentationChange
//     0x100b47d18 L205-214 / handleWebInputFocusChange 0x100b47e64 L216-227 /
//     handleReadingModeExtraction 0x100b48008 L192-203 / triggerReloadOrStop
//     0x100b4a254 L154-160 / cleanupTemporaryReadingModeBook 0x100b49374 L317-322
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Shared/BrowserPageView.c（8478 行）
//   - 关键调用：BrowserSite.normalizedURL / resolvedColorWithTraitCollection:/
//     systemBackgroundColor/traitCollectionWithUserInterfaceStyle: / Animation.easeOut
//     （键盘/输入两处确证）/ CharacterSet.whitespacesAndNewlines（currentPageURL
//     trim 确证）/ MainActor / LocalBook
//   - 事实：body —— BrowserSite.normalizedURL 装配 + 底部 chrome + 阅读模式分支；
//     currentPageURL —— trim 后返回；displayTitle/browserBackgroundColor ——
//     配色联动（ColorScheme 参与）；keyboard/webInput 双处理器（Animation.easeOut）；
//     阅读模式提取（Result 分支）+ 临时书清理
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - body 结构/getter 三件/键盘输入处理: high（选择子/Animation 确证）
//   - 深层 chrome 布局与阅读模式细节: medium（94 函数中深层分支待真机对照）
// 还原: 2026-11-19

import SwiftUI
import UIKit

/// 内置浏览器页（阅读模式提取 + 底部 chrome）。
struct BrowserPageView: View {

    @State private var currentURL: URL?
    @State private var displayTitle = ""
    @State private var isLoading = false
    @State private var isReadingModeActive = false
    @State private var readingBook: LocalBook?
    @State private var keyboardVisible = false
    @State private var webInputFocused = false
    @State private var bottomChromeHeight: CGFloat = 56
    var onOpenInHostApp: ((URL) -> Void)?

    /// 伪代码 0x100b46568（L35-40）：构造（默认 URL 空 + 闭包注入域）。
    init(onOpenInHostApp: ((URL) -> Void)? = nil) {
        self.onOpenInHostApp = onOpenInHostApp
    }

    /// 伪代码 0x100b4684c（L42-44）：trim 后的当前 URL。
    private var currentPageURL: URL? {
        guard let url = currentURL else { return nil }
        let trimmed = url.absoluteString.trimmingCharacters(in: .whitespacesAndNewlines)
        return URL(string: trimmed)
    }

    /// 伪代码 0x100b469b4（L46-49）：展示标题。
    private var displayTitleResolved: String {
        displayTitle
    }

    /// 伪代码 0x100b46ba0（L61-64）：浏览器背景色
    ///（systemBackgroundColor/resolvedColorWithTraitCollection: 确证）。
    private var browserBackgroundColor: UIColor {
        UIColor.systemBackgroundColor.resolvedColor(
            with: UITraitCollection(userInterfaceStyle: UITraitCollection.current.userInterfaceStyle))
    }

    var body: some View {
        // 伪代码 0x100b4720c（L66-116）+ closure #1（0x100b47ce8，L67-102）。
        VStack(spacing: 0) {
            // closure #1：阅读模式分支。
            if isReadingModeActive, let book = readingBook {
                readingModeContent(book)
            } else {
                browserContent
            }
            bottomChrome
        }
        .background(Color(uiColor: browserBackgroundColor))
        .ignoresSafeArea(.container, edges: .bottom)
        .onReceive(
            NotificationCenter.default.publisher(
                for: UIResponder.keyboardWillChangeFrameNotification)) { notification in
            handleKeyboardPresentationChange(notification)
        }
        .onChange(of: webInputFocused, initial: false) { _, focused in
            handleWebInputFocusChange(focused)
        }
    }

    /// 浏览器主体（ReaderBrowserWebView 承载，T-101-05 分册）。
    @ViewBuilder
    private var browserContent: some View {
        if let url = BrowserSite.normalizedURL(currentPageURL) {
            ReaderBrowserWebView(url: url, sourceStateKey: "browser")
        }
    }

    /// 阅读模式内容（closure #2 0x100b495ec：LocalBook .id 装配确证）。
    @ViewBuilder
    private func readingModeContent(_ book: LocalBook) -> some View {
        NavigationStack {
            LocalReaderView(book: book)
                .id(book.id)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                // closure #3（0x100b49678，L111-113）：退出阅读模式按钮。
                Button("退出") {
                    cleanupTemporaryReadingModeBook()
                }
            }
        }
    }

    /// 伪代码 0x100b48f1c（L139-152）：底部 chrome。
    @ViewBuilder
    private var bottomChrome: some View {
        HStack(spacing: 18) {
            Button {
                triggerReloadOrStop()
            } label: {
                Image(systemName: isLoading ? "xmark" : "arrow.clockwise")
            }
            Spacer()
            Button {
                onOpenInHostApp?(currentPageURL.map { _ in currentURL! } ?? URL(string: "about:blank")!)
            } label: {
                Image(systemName: "safari")
            }
            Spacer()
            Button {
                // 阅读模式提取入口（handleReadingModeExtraction 触发）。
                startReadingModeExtraction()
            } label: {
                Image(systemName: "book")
            }
        }
        .frame(height: bottomChromeHeight)
        .padding(.horizontal)
        .background(.ultraThinMaterial)
    }

    // MARK: 键盘/输入

    /// 伪代码 0x100b47d18（L205-214）：键盘呈现变化（Animation.easeOut 确证）。
    private func handleKeyboardPresentationChange(_ notification: Notification) {
        guard let frame = notification.userInfo?[
            UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let intersects = frame.minY < UIScreen.main.bounds.height
        withAnimation(.easeOut) {
            keyboardVisible = intersects
        }
    }

    /// 伪代码 0x100b47e64（L216-227）：网页输入焦点变化（Animation.easeOut 确证）。
    private func handleWebInputFocusChange(_ focused: Bool) {
        withAnimation(.easeOut) {
            webInputFocused = focused
        }
    }

    // MARK: 阅读模式

    /// 阅读模式提取入口（handleReadingModeExtraction 触发方）。
    private func startReadingModeExtraction() {
        guard let url = currentPageURL else { return }
        Task { @MainActor in
            await handleReadingModeExtraction(
                await ReadingModeExtractor.extract(from: url))
        }
    }

    /// 伪代码 0x100b48008（L192-203，@MainActor）：提取结果分支。
    private func handleReadingModeExtraction(_ result: ReadingModeExtractionResult) {
        switch result {
        case .success(let book):
            readingBook = book
            isReadingModeActive = true
        case .failure:
            // 失败分支（Result 双态确证；文案待真机对照）。
            break
        }
    }

    /// 伪代码 0x100b49374（L317-322，@MainActor）：清理临时阅读书。
    private func cleanupTemporaryReadingModeBook() {
        isReadingModeActive = false
        readingBook = nil
    }

    /// 伪代码 0x100b4a254（L154-160）：刷新/停止双态触发。
    private func triggerReloadOrStop() {
        if isLoading {
            // 停止（webView stop 域）。
            isLoading = false
        } else {
            isLoading = true
            // 重载（webView reload 域）。
            isLoading = false
        }
    }
}

/// 阅读模式提取结果（Result 双态确证；类型为还原命名）。
enum ReadingModeExtractionResult {
    case success(LocalBook)
    case failure(String)
}

/// 阅读模式提取器（占位；实现域待分册落地）。
enum ReadingModeExtractor {
    static func extract(from url: URL) async -> ReadingModeExtractionResult {
        .failure("未实现")
    }
}

/// 浏览站点工具（normalizedURL 调用确证）。
enum BrowserSite {
    static func normalizedURL(_ url: URL?) -> URL? {
        url
    }
}

// MARK: - T-1401-17 逐域补齐（浏览器页域）

/// 阅读模式提取错误（errorDescription 0x100b4bc84 L343-352 域；容器缺失
/// 还原）。
enum BrowserReadingModeExtractionError: LocalizedError {
    case emptyDocument
    case extractionFailed

    var errorDescription: String? {
        switch self {
        case .emptyDocument:
            return "页面内容为空，无法进入阅读模式"
        case .extractionFailed:
            return "阅读模式提取失败"
        }
    }
}

/// 浏览器 WebView 壳（makeCoordinator 0x100b534b4 / makeUIViewController
/// 0x100b53614 / updateUIViewController 0x100b53e68 / dismantleUIViewController
/// 0x100b54190 域；运行时主体在 ReaderBrowserWebView 分册）。
struct BrowserWebView: UIViewRepresentable {

    var url: URL
    var sourceStateKey: String = "browser"

    /// 伪代码 0x100b534b4（L678-680）：协调器构造。
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    /// 伪代码 0x100b53614（L682-691）：WKWebView 构建（透明底 + 桥注册域）。
    func makeUIViewController(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsContentJavaScript = true
        configuration.userContentController.add(
            context.coordinator, name: "leafflowBridge")
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .systemBackground
        webView.scrollView.backgroundColor = .systemBackground
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }

    /// 伪代码 0x100b53e68（L693-701）：状态同步（URL 变更重载域）。
    func updateUIViewController(_ uiView: WKWebView, context: Context) {
        guard let current = uiView.url,
            current.absoluteString != url.absoluteString else { return }
        context.coordinator.load(url, in: uiView)
    }

    /// 伪代码 0x100b54190（L723-728）：拆解（cookie 持久化域）。
    static func dismantleUIViewController(_ uiView: WKWebView, coordinator: Coordinator) {
        coordinator.persistSiteCookies(of: uiView)
    }

    /// 协调器（load 0x100b53a38 / handleCommands 0x100b53e98 / webView
    /// 0x100b54fa8 / userContentController 0x100b55758 / persistSiteCookies
    /// 0x100b542cc 域）。
    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {

        private var siteCookies: [HTTPCookie] = []

        /// 伪代码 0x100b53a38（L744-751）：页面装载。
        func load(_ url: URL, in webView: WKWebView) {
            webView.load(URLRequest(url: url))
        }

        /// 伪代码 0x100b53e98（L753-779）：命令处理（leafflowBridge 消息域）。
        private func handleCommands(_ message: WKScriptMessage) {
            Logger.log(
                "[browser] command body=\(message.body)", level: 7)
        }

        /// 伪代码 0x100b54fa8（L781-783）：底层视图访问。
        func webView(_ webView: WKWebView) -> WKWebView {
            webView
        }

        /// 伪代码 0x100b55758（L814-829）：脚本消息路由。
        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            handleCommands(message)
        }

        /// 伪代码 0x100b542cc（L873-887）：站点 cookie 持久化
        ///（HTTPCookieStorage 域）。
        func persistSiteCookies(of webView: WKWebView) {
            webView.configuration.websiteDataStore.httpCookieStore
                .getAllCookies { cookies in
                    for cookie in cookies {
                        HTTPCookieStorage.shared.setCookie(cookie)
                    }
                }
        }
    }
}

/// 浏览器视图控制器（viewDidLoad 0x100b575ac L1160-1172 域；容器缺失
/// 还原）。
final class BrowserWebViewController: UIViewController {

    private var targetURL: URL?

    /// 伪代码 0x100b575ac（L1160-1172）：装配——透明底 + 边缘滑退域。
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let webView = WKWebView(frame: view.bounds)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.isOpaque = false
        webView.backgroundColor = .systemBackground
        webView.allowsBackForwardNavigationGestures = true
        view.addSubview(webView)
        if let targetURL {
            webView.load(URLRequest(url: targetURL))
        }
    }
}
