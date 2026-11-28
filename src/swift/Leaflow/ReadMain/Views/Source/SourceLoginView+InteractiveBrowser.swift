// 原路径: ReadMain/Views/Source/SourceLoginView.swift
import SwiftUI
import WebKit
import UIKit

// MARK: - InteractiveBrowserWebView

/// 交互浏览器 WebView（签名族确证）。
struct InteractiveBrowserWebView: UIViewRepresentable {
    let source: BookSource
    let targetURL: URL
    let request: JSBrowserRequest?
    var onHostAppNavigation: ((URL) -> Void)?
    var onComplete: ((String?) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(
            source: source, targetURL: targetURL, request: request,
            onHostAppNavigation: onHostAppNavigation,
            onComplete: onComplete)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let controller = WKUserContentController()
        // '[InteractiveBrowserBridge] #' 桥域确证。
        controller.add(context.coordinator, name: "interactiveBridge")
        configuration.userContentController = controller
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        view.allowsBackForwardNavigationGestures = true
        Coordinator.applyBackground(to: view)
        if let request = request, let url = URL(string: request.url) {
            view.load(Self.buildURLRequest(url: url, source: source))
        } else {
            view.load(URLRequest(url: targetURL))
        }
        return view
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.navigationDelegate = nil
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        context.coordinator.parent = self
    }

    private static func buildURLRequest(
        url: URL, source: BookSource
    ) -> URLRequest {
        var request = URLRequest(url: url)
        if let headerJSON = source.header,
           let data = headerJSON.data(using: .utf8),
           let map = try? JSONSerialization.jsonObject(with: data)
            as? [String: String] {
            for (key, value) in map {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        return request
    }

    /// 协调器（代理族 + 捕获/桥接/边滑签名确证）。
    final class Coordinator: NSObject, WKNavigationDelegate,
        WKScriptMessageHandler, UIGestureRecognizerDelegate {
        var parent: InteractiveBrowserWebView?
        let source: BookSource
        let targetURL: URL
        let request: JSBrowserRequest?
        let onHostAppNavigation: ((URL) -> Void)?
        let onComplete: ((String?) -> Void)?
        private var capturedHTML: String?

        init(
            source: BookSource, targetURL: URL, request: JSBrowserRequest?,
            onHostAppNavigation: ((URL) -> Void)?,
            onComplete: ((String?) -> Void)?
        ) {
            self.source = source
            self.targetURL = targetURL
            self.request = request
            self.onHostAppNavigation = onHostAppNavigation
            self.onComplete = onComplete
        }

        /// currentRuntimeContext getter（签名确证）。
        var currentRuntimeContext: JSBrowserRequest.RuntimeContext? {
            request?.runtimeContext
        }

        /// applyBackground（签名确证）。
        static func applyBackground(to view: WKWebView) {
            view.backgroundColor = .systemBackground
            view.isOpaque = true
            view.scrollView.backgroundColor = .systemBackground
        }

        /// browserCompatibilityScript getter（签名确证）。
        static var browserCompatibilityScript: String {
            """
            window.onerror = function(m){ console.log('[bridge] ' + m); };
            """
        }

        /// debugSnippet（签名确证）。
        static func debugSnippet(
            _ text: String, maxLength: Int = 120
        ) -> String {
            String(text.prefix(maxLength))
        }

        /// debugHeaderSummary（签名确证；' headers' 域确证）。
        static func debugHeaderSummary(_ headers: [String: String]) -> String {
            " headers=\(headers.count)"
        }

        /// debugCookieSummary（签名确证；' cookies' 域确证）。
        static func debugCookieSummary(_ cookies: [HTTPCookie]) -> String {
            " cookies=\(cookies.count)"
        }

        /// collectCookies(for:source:)（签名确证）。
        static func collectCookies(
            for url: URL, source: BookSource
        ) -> [HTTPCookie] {
            HTTPCookieStorage.shared.cookies(for: url) ?? []
        }

        // MARK: 边滑（edgeSwipe 族签名确证）

        static func shouldDismissEdgeSwipe(
            edge: UIRectEdge, translationX: CGFloat
        ) -> Bool {
            edge == .left && translationX > 40
        }

        static func edgeSwipeOffset(
            edge: UIRectEdge, translationX: CGFloat
        ) -> CGFloat {
            max(translationX, 0)
        }

        static func edgeSwipeProgress(
            edge: UIRectEdge, translationX: CGFloat, containerWidth: CGFloat
        ) -> CGFloat {
            guard containerWidth > 0 else { return 0 }
            return min(max(translationX / containerWidth, 0), 1)
        }

        func handleEdgeSwipe(_ recognizer: UIScreenEdgePanGestureRecognizer) {
            // beginEdgeSwipe/finishEdgeSwipe 签名确证（宿主导航回滑）。
        }

        static func edgeSwipeContainer(startingAt view: UIView) -> UIView? {
            view
        }

        func gestureRecognizerShouldBegin(
            _ gestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }

        // MARK: WKNavigationDelegate（代理族签名确证）

        func webView(
            _ webView: WKWebView,
            didStartProvisionalNavigation navigation: WKNavigation?
        ) {
            // 'ser] didStart url=' 域确证。
        }

        func webView(
            _ webView: WKWebView,
            didReceiveServerRedirectForProvisionalNavigation
            navigation: WKNavigation?
        ) {}

        func webView(
            _ webView: WKWebView, didFinish navigation: WKNavigation?
        ) {
            // '页面加载完成: ' 域确证 + 挂 webJs。
            if let webJs = request?.webJs, !webJs.isEmpty {
                executeBridgeJavaScript(webJs, in: webView)
            }
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction
        ) async -> WKNavigationActionPolicy {
            // 'ser] handoff-to-host-app url=' 域确证。
            guard let url = navigationAction.request.url else {
                return .allow
            }
            if SourceBrowserURLRouting.shouldOpenInHostApp(url) {
                onHostAppNavigation?(url)
                return .cancel
            }
            return .allow
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationResponse: WKNavigationResponse
        ) async -> WKNavigationResponsePolicy {
            .allow
        }

        func webView(
            _ webView: WKWebView, didFail navigation: WKNavigation?,
            withError error: Error
        ) {
            // '无法打开浏览器' 域确证。
            onComplete?(nil)
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation?,
            withError error: Error
        ) {
            onComplete?(nil)
        }

        func webView(
            _ webView: WKWebView,
            respondTo challenge: URLAuthenticationChallenge
        ) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
            (.performDefaultHandling, nil)
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard message.name == "interactiveBridge" else { return }
            if let payload = message.body as? String {
                capturedHTML = payload
            }
        }

        func webView(
            _ webView: WKWebView,
            runJavaScriptTextInputPanelWithPrompt prompt: String,
            defaultText: String?, initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping (String?) -> Void
        ) {
            // ' prompt script=' 域确证：脚本 prompt 直接回默认值。
            completionHandler(defaultText)
        }

        // MARK: 捕获与桥接

        /// captureHTML(from:)（签名确证；'ser] htmlCapture chars=' 域）。
        func captureHTML(from webView: WKWebView) {
            webView.evaluateJavaScript(
                "document.documentElement.outerHTML"
            ) { value, _ in
                if let html = value as? String {
                    self.capturedHTML = html
                }
            }
        }

        /// executeBridgeJavaScript(_:in:)（签名确证；
        /// ' executeJsRule begin'/' end resultChars=' 域）。
        func executeBridgeJavaScript(_ script: String, in webView: WKWebView) {
            webView.evaluateJavaScript(script) { value, _ in
                if let text = value as? String {
                    self.request?.complete(result: text)
                }
            }
        }

        /// saveCookies(from:)（签名确证；'ser] persistCookies total=' 域）。
        func saveCookies(from webView: WKWebView) {
            let url = webView.url ?? targetURL
            let cookies = Self.collectCookies(for: url, source: source)
            for cookie in cookies {
                HTTPCookieStorage.shared.setCookie(cookie)
            }
        }

        /// captureAndReturn(from:)（签名确证）。
        func captureAndReturn(from webView: WKWebView) {
            captureHTML(from: webView)
            saveCookies(from: webView)
            onComplete?(capturedHTML)
        }
    }
}
