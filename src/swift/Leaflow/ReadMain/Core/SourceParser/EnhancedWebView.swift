// 原路径: ReadMain/Core/SourceParser/EnhancedWebView.swift
// 证据:
//   - PGO: isCompleted 初始化 (0x1000dd970 L19) / WebViewConfig.timeout (0x1000dd720 L60) / waitForLoad (0x1000ddffc L63) / init(url:html:javaScript:) (0x1000dd5c0 L99-111) / getResponse() (0x1000dd9ac L122-130) / getSourceUrl() (0x1000de06c L133-140)
//   - CovMap: 上述 L 区段
//   - IDA: 上述地址
//   - 选择子 setApplicationNameForUserAgent:/initWithFrame:configuration:/loadHTMLString:baseURL:/loadRequest:/request/response/allHeaderFields
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: medium-high（async 求值链确证）
// 还原: 2026-11-19


import Foundation
import WebKit

/// 增强 WebView（带超时与响应归一）。
final class EnhancedWebView {

    struct WebViewConfig {
        /// 伪代码 L60。
        var timeout: Double = 60.0
        /// 伪代码 L63。
        var waitForLoad = true
        var headers: [String: String] = [:]
        var userAgent: String?
    }

    struct WebViewResponse {
        var body: String
        var code: Int
        var url: String
        var headers: [String: String]
    }

    private let wkWebView: WKWebView
    private var isCompleted = false
    let config: WebViewConfig

    /// 伪代码 0x1000dd5c0（L99-111）。url/html/javaScript 默认 nil
    /// （WebViewPool.preWarm 空构造消费域确证，wave-16）。
    init(
        url: String? = nil, html: String? = nil, javaScript: String? = nil,
        config: WebViewConfig = WebViewConfig()
    ) {
        self.config = config
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = WKWebsiteDataStore.nonPersistent()
        if let userAgent = config.userAgent {
            configuration.applicationNameForUserAgent = userAgent
        }
        wkWebView = WKWebView(frame: .zero, configuration: configuration)
        if let html {
            wkWebView.loadHTMLString(html, baseURL: nil)
        } else if let url, let target = URL(string: url) {
            wkWebView.load(URLRequest(url: target))
        }
    }

    /// 伪代码 0x1000dd9ac（L122-130，CheckedContinuation）。
    func getResponse() async throws -> WebViewResponse {
        try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                let deadline = Date().addingTimeInterval(self.config.timeout)
                while !self.isCompleted, Date() < deadline {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                }
                let body = (try? await self.wkWebView.evaluateJavaScript(
                    "document.documentElement.outerHTML"
                )) as? String ?? ""
                let currentURL = self.wkWebView.url?.absoluteString ?? ""
                continuation.resume(
                    returning: WebViewResponse(
                        body: body, code: 200, url: currentURL, headers: self.config.headers
                    )
                )
            }
        }
    }

    /// 伪代码 0x1000de06c（L133-140）。
    func getSourceUrl() async throws -> String {
        let response = try await getResponse()
        return response.url
    }
}

extension EnhancedWebView {

    /// 伪代码 0x1000de210（L143-150）：覆写 URL（重定向拦截域）。
    func getOverrideUrl() -> String? {
        overrideUrlStorage
    }

    /// 伪代码 0x1000dfd88（L262-276）：底层 WKWebView 访问（评估域）。
    func webView() -> WKWebView? {
        underlyingWebView
    }
}

