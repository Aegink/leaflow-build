// 原路径: ReadMain/Core/SourceParser/BackstageWebView.swift
// 证据:
//   - PGO: WebViewPool(availableWebViews/maxPoolSize/init/makeConfiguration/acquire/scheduleRefill) + BackstageWebView 主体（43 函数）
//   - CovMap: availableWebViews L13 @0x1000c2064；maxPoolSize L16 @0x1000c1fac；init L21-34 @0x1000c4c44；makeConfiguration L37-43 @0x1000c225c；acquire L54-65 @0x1000c22e4；scheduleRefill L68-82 @0x1000c2460
//   - IDA: 上述地址
//   - 30 条字面量：nonPersistentDataStore/setWebsiteDataStore:/setPreferences:/setUserContentController:/loadHTMLString:baseURL:/stopLoading/setNavigationDelegate:/setCustomUserAgent:/httpCookieStore/getAllCookies:/addUserScript:/addScriptMessageHandler:name:/removeScriptMessageHandlerForName:；诊断 WebView加载超时/无法获取页面内容
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: medium-high（池链确证；消息处理细节见读后记仍不清楚 1）
// 还原: 2026-11-19


import Foundation
import WebKit

/// 后台 WebView 池（T-207）。
final class WebViewPool {

    /// 伪代码 L13/L16。
    private var availableWebViews: [EnhancedWebView] = []
    let maxPoolSize: Int

    private let lock = NSLock()

    init(maxPoolSize: Int = 4) {
        self.maxPoolSize = maxPoolSize
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.drain()
        }
    }

    /// 伪代码 0x1000c225c（L37-43）：nonPersistent 配置。
    /// internal：BackstageWebView.init 消费域（wave-16）。
    func makeConfiguration() -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = WKWebsiteDataStore.nonPersistent()
        configuration.applicationNameForUserAgent = "qireader"
        return configuration
    }

    /// 伪代码 0x1000c22e4（L54-65）。
    func acquire() -> EnhancedWebView {
        lock.lock()
        if let pooled = availableWebViews.popLast() {
            lock.unlock()
            return pooled
        }
        lock.unlock()
        return EnhancedWebView(url: nil, html: nil, javaScript: nil)
    }

    /// 伪代码 0x1000c2460（L68-82）。
    func scheduleRefill(_ webView: EnhancedWebView) {
        lock.lock()
        if availableWebViews.count < maxPoolSize {
            availableWebViews.append(webView)
        }
        lock.unlock()
    }

    func drain() {
        lock.lock()
        defer { lock.unlock() }
        availableWebViews.removeAll()
    }

    static let shared = WebViewPool()
}

/// 后台 WebView（getStrResponse 的 WebView 降级执行体）。
final class BackstageWebView: NSObject {

    let webView: WKWebView
    private var isCompleted = false

    /// 诊断串（事实 2）。
    static let timeoutMessage = "WebView加载超时"
    static let emptyContentMessage = "无法获取页面内容"

    override init() {
        webView = WKWebView(frame: .zero, configuration: WebViewPool.shared.makeConfiguration())
        webView.configuration.userContentController.add(self, name: "qireader")
    }

    /// 加载 URL（选择子 loadRequest:/stopLoading/setNavigationDelegate:）。
    func load(url: String, timeout: Double) async -> String? {
        guard let target = URL(string: url) else { return nil }
        let request = URLRequest(url: target, timeoutInterval: timeout)
        webView.load(request)
        let deadline = Date().addingTimeInterval(timeout)
        while !isCompleted, Date() < deadline {
            await Task.yield()
        }
        if !isCompleted {
            webView.stopLoading()
            Logger.log(Self.timeoutMessage, level: .warning)
            return nil
        }
        return (try? await webView.evaluateJavaScript("document.body.innerHTML")) as? String
    }
}

extension BackstageWebView: WKScriptMessageHandler {
    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        isCompleted = true
    }
}

// MARK: - T-1401-13 逐域补齐（WebView 池域）

extension WebViewPool {

    /// 伪代码 0x1000c28a4（L85-96）：归还池（容量上限域）。
    func release(_ webView: EnhancedWebView) {
        lock.lock()
        defer { lock.unlock() }
        guard availableWebViews.count < maxPoolSize else { return }
        availableWebViews.append(webView)
    }

    /// 伪代码 0x1000c2940（L100-104）：预热补充（池下限域）。
    func preWarm() {
        lock.lock()
        defer { lock.unlock() }
        while availableWebViews.count < maxPoolSize {
            availableWebViews.append(EnhancedWebView())
        }
    }
}

extension WebViewError {

    /// 伪代码 0x1000c559c（L394-407）：错误文案（超时/加载失败双档域）。
    var errorDescription: String? {
        switch self {
        case .timeout(let url):
            return "后台页面加载超时：\(url)"
        case .loadFailed(let url):
            return "后台页面加载失败：\(url)"
        }
    }
}

/// 后台 WebView 错误（errorDescription 0x1000c559c 域容器；T-1401-13）。
enum WebViewError: LocalizedError {
    case timeout(String)
    case loadFailed(String)
}
