// 原路径: ReadMain/Views/Reader/WebViewVerticalScroll/WebViewVerticalScrollViewController.swift
// 证据:
//   - PGO: 主函数（index/task_functions.csv T-301-14 / WebViewVerticalScrollViewController.swift），
//     地址：WebViewVerticalScrollViewModel.webViewChapterPayload 扩展 0x100652cac L35-37 /
//     WebViewVerticalScrollReader.makeUIViewController 0x100652d1c L48-52 /
//     isReady 等变量初始化族 0x10065e170-0x1006624c0 L94-106（widget 容器/
//     presentationDetents.medium|large 确证）/ viewDidAppear 0x100656bac L130-135
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Reader/WebViewVerticalScroll/
//     WebViewVerticalScrollViewController.c（6953 行）
//   - 事实：竖排 WebView 阅读器容器（UIViewRepresentable + WKWebView 控制器）：
//     状态域（isReady/didInitialize/knownChapters/activeChapters/widget 容器/编码器），
//     章节载荷扩展，viewDidAppear 装配
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - 容器结构/状态域: high（ivar 初始化族确证）
//   - JS 桥/滚动锚点细节: medium（待真机对照）
// 还原: 2026-11-19

import SwiftUI
import WebKit

/// 竖排阅读 ViewModel 桥（载荷扩展确证）。
@MainActor
final class WebViewVerticalScrollViewModel: ObservableObject {
    var chapterPayloadProvider: ((Int, Bool) -> WebViewVerticalScrollChapterPayload?)?
    var settingsSignatureProvider: (() -> Int)?
    var settingsPayloadProvider: (() -> WebViewVerticalScrollSettingsPayload)?
    var chapterCountProvider: (() -> Int)?

    func webViewChapterPayload(for index: Int, forceRefresh: Bool) -> WebViewVerticalScrollChapterPayload? {
        chapterPayloadProvider?(index, forceRefresh)
    }
}

/// 竖排阅读器（UIViewRepresentable，makeUIViewController 确证）。
struct WebViewVerticalScrollReader: UIViewControllerRepresentable {
    var initialChapterIndex: Int
    var initialProgress: WebViewScrollProgress?
    var onVisibleChapterChange: (Int) -> Void
    var onProgressChange: (WebViewScrollProgress) -> Void

    func makeUIViewController(context: Context) -> WebViewVerticalScrollViewController {
        // 伪代码 0x100652d1c（L48-52）。
        let controller = WebViewVerticalScrollViewController()
        controller.viewModel = context.coordinator.viewModel
        controller.initialChapterIndex = initialChapterIndex
        controller.onVisibleChapterChange = onVisibleChapterChange
        controller.onProgressChange = onProgressChange
        return controller
    }

    func updateUIViewController(_ controller: WebViewVerticalScrollViewController, context: Context) {
        controller.syncSettingsIfSignatureChanged()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    @MainActor
    final class Coordinator {
        let viewModel = WebViewVerticalScrollViewModel()
    }
}

/// 竖排阅读控制器（ivar 族 L94-106 确证）。
@MainActor
final class WebViewVerticalScrollViewController: UIViewController {

    var viewModel: WebViewVerticalScrollViewModel?
    var initialChapterIndex = 0
    var onVisibleChapterChange: ((Int) -> Void)?
    var onProgressChange: ((WebViewScrollProgress) -> Void)?

    private var isReady = false
    private var didInitializeWebView = false
    private var knownChapters: Set<Int> = []
    private var activeChapters: Set<Int> = []
    private var widgetContainerView = UIView()
    private var lastSettingsSignature = -1
    private lazy var webView: WKWebView = {
        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        return webView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(webView)
        view.addSubview(widgetContainerView)
        didInitializeWebView = true
    }

    override func viewDidAppear(_ animated: Bool) {
        // 伪代码 0x100656bac（L130-135）。
        super.viewDidAppear(animated)
        syncSettingsIfSignatureChanged()
        loadChapterIfNeeded(initialChapterIndex)
        isReady = true
    }

    /// 设置签名变化时重载样式。
    func syncSettingsIfSignatureChanged() {
        guard let viewModel,
              let signature = viewModel.settingsSignatureProvider?(),
              signature != lastSettingsSignature else { return }
        lastSettingsSignature = signature
        webView.reload()
    }

    /// 章节按需加载。
    private func loadChapterIfNeeded(_ index: Int) {
        guard let viewModel, !knownChapters.contains(index),
              let payload = viewModel.webViewChapterPayload(for: index, forceRefresh: false) else {
            return
        }
        knownChapters.insert(index)
        Logger.log("load chapter \(index) hash=\(payload.contentHash)", level: .verbose)
    }

    /// 可见章回调入口。
    func handleVisibleChapter(_ index: Int) {
        onVisibleChapterChange?(index)
        activeChapters.insert(index)
        webViewPreloadAdjacentChapters(around: index)
    }

    private func webViewPreloadAdjacentChapters(around index: Int) {
        loadChapterIfNeeded(index + 1)
        loadChapterIfNeeded(index - 1)
    }
}

// MARK: - T-1401-07 逐域补齐

extension WebViewVerticalScrollViewController: WKScriptMessageHandler {

    /// 伪代码 0x100652d68（L147-170）：SwiftUI 状态入同步——章数/初始章/
    /// 已知章集合域。
    func updateFromSwiftUI() {
        guard let viewModel else { return }
        knownChapters = Set(0..<(viewModel.chapterCountProvider?() ?? 0))
        if !didInitializeWebView {
            didInitializeWebView = true
        }
    }

    /// 伪代码 0x10065a770（L452-499）：脚本消息处理——滚动进度/可见章/
    /// 章尾追加三类消息域（userContentController 域确证）。
    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        switch message.name {
        case "scrollProgress":
            if let value = message.body as? NSNumber {
                onProgressChange?(
                    WebViewScrollProgress(
                        chapterIndex: initialChapterIndex,
                        paragraphIndex: 0,
                        unitOffset: value.doubleValue,
                        characterIndex: 0))
            }
        case "visibleChapter":
            if let index = message.body as? NSNumber {
                onVisibleChapterChange?(index.intValue)
            }
        default:
            break
        }
    }
}

