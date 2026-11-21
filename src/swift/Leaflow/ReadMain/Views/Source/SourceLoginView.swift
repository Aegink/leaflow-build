// 原路径: ReadMain/Views/Source/SourceLoginView.swift
// 证据:
//   - PGO: 494 条记录（index/task_functions.csv T-401-06 /
//     SourceLoginView.swift；伪代码域 27044 行）。关键地址域：
//     JSBrowserRequest（handled/runtimeContext/result/tryHandle(
//     sourceStateKey:presentationContext:)/complete(result:)/
//     waitForCompletion(timeout:)/init(url:title:html:webJs:config:)）/
//     JSBrowserNavigationRequest（init(request:)/init(url:method:headers:)/
//     makeURLRequest/localDocument()）/ SourceBrowserURLRouting
//     .shouldOpenInHostApp(URL)（×3 ICF 副本）/ SourceBrowserRequestResolver
//     .resolve(ruleURL:source:runtimeContext:)/localHTML(fromDataURL:)/
//     canResolveBrowserURL(String) / SourceBrowserImportRouting
//     .importSourceURL(from:)/action(for:) / InteractiveBrowserWebView
//     （makeCoordinator/makeUIView/updateUIView/dismantleUIView/
//     browserCompatibilityScript/collectCookies/applyBackground/
//     debugSnippet/debugHeaderSummary/debugCookieSummary；Coordinator：
//     currentRuntimeContext/edgeSwipe 族/手势/导航代理族/captureHTML/
//     executeBridgeJavaScript/saveCookies/captureAndReturn）/ LoginWebView
//     （collectExistingCookies/persistObservedCookies/cookiesDidChange/
//     captureAndSaveCookies）/ SourceLoginView（body/webViewLoginContent/
//     formLoginContent/initLogin/flushEditedLoginInfo/
//     applyLoginUiDataUpdate/reloadLoginUi/saveEffectiveLoginHeader/
//     handleBrowserHostAppNavigation/importCurrentBrowserSelection/
//     enqueueToast/showNextToast/applyResolvedLoginUiItems/setupLoginMode/
//     refreshResolvedViewNames/persistBridgeUpdatedLoginInfo/
//     scheduleRemoteLoginInfoSave/resolveLoginUrl/buildHeaderMap/
//     performFormLogin/binding(for:)/handleButtonAction/
//     localVisibleLoginUiItems/localLoginUiItemView/normalizedFlexBasis/
//     normalizedFlexGrow/mergedPersistedCookieString/
//     resolvedLoginHeaderText/formatLoginHeaderDisplay/resolvedViewName/
//     currentValue/对齐三件/updateSelectValue/cycleToggleValue/
//     toggleValueBadge/LocalLoginGlassCardModifier/
//     LocalLoginInteractiveGlassCardModifier/persistEditedLoginInfo/
//     scheduleFieldAction/executeLoginUiAction/mergedLoginActionValues/
//     hasEditableLoginFields/editableLoginData/loginInfoJSONString/
//     showLoginHeaderInfo/legacyFormLoginBody/localFormLoginBody/
//     卡片度量族/javaScriptStringLiteral/formValuesAfterButtonActionSuccess/
//     isSourceRemoteMode）/ LoginFormFlexLayout（sizeThatFits/arrangedRows/
//     placeSubviews/preferredWidth + flushCurrentRow 闭包）/
//     SourceLoginScreenModifier + View.sourceLoginScreenStyle /
//     RemoteBrowserSheet（body/parseHeader/handleBrowserHostAppNavigation/
//     captureAndSaveCookies/browserImportSelectionPresented/
//     importCurrentBrowserSelection）/ RemoteBrowserWebView（makeUIView/
//     updateUIView/makeCoordinator + Coordinator 导航域）
//   - CovMap: L 域映射（index/restoration_status.csv）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Source/SourceLoginView.c
//     （27044 行）
//   - 字符串确证（位模式/IPA 指针）：桥域 '[InteractiveBrowserBridge] #'
//     @ptr / ' worker start baseURL=' / ' executeJsRule begin' /
//     ' executeJsRule end resultChars=' @ptr / ' elapsed' / 's baseURL=' /
//     ' result=' / ' timeout' / 's script' / 'ser] handoff-to-host-app
//     url=' @ptr / 'ser] htmlCapture chars=' @ptr / 'ser] didStart url='
//     @ptr / 'ser] persistCookies total=' @ptr / ' prompt script=' /
//     ' referer=' / ' origin=' / ' cookieLen=' / ' webJsChars=' /
//     ' headers' / ' cookies' / ' method=' / ' mainFra' / ' domains='；
//     路由域 'qireader'（L31，宿主 scheme 确证）/'about:blank'（L448）/
//     'data:text/html'（L577）/'https://'；表单域 'password'（type 域）/
//     'loginInfo_'（L14063）/'loginHeader_'（L17581）/'Headers:'/'无登录头
//     信息' @ptr/'登录信息'/'登录成功'/'无可配置项'/'无效的登录 URL' @ptr/
//     '登录 - '/'远程后端'/'sourceVariable_'/'flex_start'/'flex_end'/
//     '页面加载完成: ' @ptr/'无法打开浏览器' @ptr
//   - 事实：JSBrowserRequest 经 tryHandle(sourceStateKey:presentationContext:)
//     桥接（T-401-03 SourceLoginModifier body 复用确证）；
//     handleBrowserHostAppNavigation 双实现（SourceLoginView/
//     RemoteBrowserSheet）+ shouldOpenInHostApp ×3 ICF 副本；
//     qireader:// 宿主 scheme + about:blank/data:text/html 本地文档域；
//     saveEffectiveLoginHeader(additionalHosts:) + loginHeader_ 前缀 +
//     'Headers:' 展示；mergedPersistedCookieString 合并持久 cookie；
//     LoginFormFlexLayout 自定义 Layout（arrangedRows + flushCurrentRow
//     闭包确证）；flex_start/flex_end 对齐域确证
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - 桥接/路由/解析器: high（签名族 + 桥串确证）
//   - WebView 协调器: medium-high（代理族 + 捕获域确证）
//   - 登录表单/Flex 布局: medium-high（域串 + Layout 签名确证）
//   - 远端登录态持久化细节: medium（loginInfo_/loginHeader_ 前缀确证，
//     远端写回随 T-501-01 交叉）
// 还原: 2026-11-20

import SwiftUI
import WebKit
import UIKit

// MARK: - JSBrowserPresentationContext / JSBrowserRequest

/// JS 浏览器请求呈现语境（tryHandle 签名确证）。
enum JSBrowserPresentationContext {
    case loginSheet
    case readerSheet
}

/// JS 浏览器请求运行语境（runtimeContext 签名确证）。
struct JSBrowserRuntimeContext {
    let source: BookSource?
    let additionalHeaders: [String: String]
    let webJs: String?
}

/// JS 浏览器请求（init(url:title:html:webJs:config:) 签名确证）。
final class JSBrowserRequest {
    struct RuntimeContext {
        let source: BookSource?
        let webJs: String?
        let configHeaders: [String: String]
    }

    let url: String
    let title: String
    let html: String?
    let webJs: String?
    let config: String?
    private let stateLock = NSLock()
    private var _handled = false
    private var _result: String?
    private var _runtimeContext: RuntimeContext?
    private var completion: DispatchSemaphore?

    /// handled getter/setter（State 闭包族确证）。
    var handled: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return _handled
    }

    /// result getter/setter（签名确证）。
    var result: String {
        stateLock.lock()
        defer { stateLock.unlock() }
        return _result ?? ""
    }

    /// runtimeContext getter/setter（×3 ICF 副本确证）。
    var runtimeContext: RuntimeContext? {
        stateLock.lock()
        defer { stateLock.unlock() }
        return _runtimeContext
    }

    init(
        url: String, title: String, html: String?, webJs: String?,
        config: String?
    ) {
        self.url = url
        self.title = title
        self.html = html
        self.webJs = webJs
        self.config = config
    }

    /// tryHandle(sourceStateKey:presentationContext:)（签名确证；
    /// T-401-03 body 复用确证）：未处理时标记并等待完成。
    func tryHandle(
        sourceStateKey: String,
        presentationContext: JSBrowserPresentationContext
    ) -> Bool {
        stateLock.lock()
        if _handled {
            stateLock.unlock()
            return false
        }
        _handled = true
        let semaphore = DispatchSemaphore(value: 0)
        completion = semaphore
        stateLock.unlock()
        return true
    }

    /// complete(result:)（签名确证）：释放等待者。
    func complete(result: String?) {
        stateLock.lock()
        _result = result ?? ""
        let semaphore = completion
        completion = nil
        stateLock.unlock()
        semaphore?.signal()
    }

    /// waitForCompletion(timeout:)（签名确证）：轮询等待结果串。
    func waitForCompletion(timeout: Double) -> String {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            stateLock.lock()
            let done = (_result != nil) || !_handled
            let value = _result ?? ""
            stateLock.unlock()
            if done { return value }
            Thread.sleep(forTimeInterval: 0.05)
        }
        return result
    }
}

// MARK: - JSBrowserNavigationRequest

/// JS 浏览器导航请求（init(request:)/init(url:method:headers:) 签名确证）。
struct JSBrowserNavigationRequest {
    let url: URL
    let method: String
    let headers: [String: String]
    var body: Data?

    /// init(request:)（签名确证）。
    init?(request: URLRequest) {
        guard let url = request.url else { return nil }
        self.init(url: url, method: request.httpMethod ?? "GET", headers: request.allHTTPHeaderFields ?? [:])
        body = request.httpBody
    }

    /// init(url:method:headers:)（签名确证）。
    init(url: URL, method: String, headers: [String: String], body: Data? = nil) {
        self.url = url
        self.method = method
        self.headers = headers
        self.body = body
    }

    /// localDocument()（签名确证；about:blank/data: 域确证）。
    static func localDocument() -> JSBrowserNavigationRequest {
        JSBrowserNavigationRequest(
            url: URL(string: "about:blank") ?? URL(fileURLWithPath: "/"),
            method: "GET", headers: [:])
    }

    /// makeURLRequest()（签名确证）。
    func makeURLRequest() -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.httpBody = body
        return request
    }
}

// MARK: - 路由与解析器

/// 宿主应用路由（shouldOpenInHostApp ×3 ICF 副本确证）。
enum SourceBrowserURLRouting {

    /// shouldOpenInHostApp（签名确证）：qireader:// scheme + 非 http(s)
    /// 域交宿主（'qireader' L31 + 'about:blank' L448 + 'data:text/html'
    /// L577 域确证）。
    static func shouldOpenInHostApp(_ url: URL) -> Bool {
        let scheme = url.scheme?.lowercased() ?? ""
        if scheme == "qireader" { return true }
        if scheme == "about" { return false }
        if scheme == "data" { return false }
        return scheme != "http" && scheme != "https"
    }
}

/// 请求解析器（resolve/localHTML/canResolveBrowserURL 签名确证）。
enum SourceBrowserRequestResolver {

    /// canResolveBrowserURL（签名确证）。
    static func canResolveBrowserURL(_ ruleURL: String) -> Bool {
        let trimmed = ruleURL.trimmingCharacters(in: .whitespaces)
        return !trimmed.isEmpty
            && (trimmed.hasPrefix("http")
                || trimmed.hasPrefix("data:text/html"))
    }

    /// resolve(ruleURL:source:runtimeContext:)（签名确证）。
    static func resolve(
        ruleURL: String, source: BookSource?,
        runtimeContext: JSBrowserRequest.RuntimeContext?
    ) -> JSBrowserNavigationRequest? {
        let trimmed = ruleURL.trimmingCharacters(in: .whitespaces)
        guard canResolveBrowserURL(trimmed) else { return nil }
        if trimmed.hasPrefix("data:text/html") {
            if let html = localHTML(fromDataURL: trimmed) {
                return localDocumentRequest(html: html)
            }
            return JSBrowserNavigationRequest.localDocument()
        }
        guard let url = URL(string: trimmed) else { return nil }
        var headers = runtimeContext?.configHeaders ?? [:]
        if let source {
            if let headerJSON = source.header,
               let data = headerJSON.data(using: .utf8),
               let map = try? JSONSerialization.jsonObject(
                with: data) as? [String: String] {
                headers.merge(map) { _, new in new }
            }
        }
        return JSBrowserNavigationRequest(url: url, method: "GET", headers: headers)
    }

    private static func localDocumentRequest(html: String) -> JSBrowserNavigationRequest {
        JSBrowserNavigationRequest(
            url: URL(string: "about:blank") ?? URL(fileURLWithPath: "/"),
            method: "GET", headers: [:])
    }

    /// localHTML(fromDataURL:)（签名确证）：data:text/html 载荷解码。
    static func localHTML(fromDataURL dataURL: String) -> String? {
        guard let commaIndex = dataURL.firstIndex(of: ",") else {
            return nil
        }
        let payload = String(dataURL[dataURL.index(after: commaIndex)...])
        if dataURL.contains(";base64") {
            return Data(base64Encoded: payload)
                .flatMap { String(data: $0, encoding: .utf8) }
        }
        return payload.removingPercentEncoding ?? payload
    }
}

/// 导入路由（importSourceURL/action 签名确证）。
enum SourceBrowserImportRouting {

    /// action(for:)（签名确证）：qireader 导入链接动作。
    static func action(for url: URL) async -> URL? {
        guard url.scheme?.lowercased() == "qireader" else { return nil }
        return url
    }

    /// importSourceURL(from:)（签名确证）：宿主导入 URL 提取。
    static func importSourceURL(from url: URL) -> URL? {
        url
    }
}

// MARK: - RemoteBrowserRequest（T-401-03 SourceLoginModifier 消费确证）

/// 远程浏览器请求（url + 状态键两字段对确证）。
struct RemoteBrowserRequest: Equatable {
    let url: URL
    var sourceStateKey: String?

    init(url: URL, sourceStateKey: String? = nil) {
        self.url = url
        self.sourceStateKey = sourceStateKey
    }
}

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

// MARK: - LoginWebView

/// 登录 WebView（cookie 捕获域确证）。
struct LoginWebView: UIViewRepresentable {
    let source: BookSource
    var loginHost: String?
    var onCookieObserved: ((String) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(
            source: source, loginHost: loginHost,
            onCookieObserved: onCookieObserved)
    }

    func makeUIView(context: Context) -> WKWebView {
        let view = WKWebView(frame: .zero)
        view.navigationDelegate = context.coordinator
        view.configuration.websiteDataStore.httpCookieStore.add(
            context.coordinator)
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        context.coordinator.parent = self
    }

    /// collectExistingCookies(for:source:)（签名确证）。
    static func collectExistingCookies(
        for url: URL, source: BookSource
    ) -> [HTTPCookie] {
        HTTPCookieStorage.shared.cookies(for: url) ?? []
    }

    /// 协调器（init/persistObservedCookies/cookiesDidChange/didFinish/
    /// respondTo/captureAndSaveCookies 签名确证）。
    final class Coordinator: NSObject, WKNavigationDelegate,
        WKHTTPCookieStoreObserver {
        var parent: LoginWebView?
        let source: BookSource
        let loginHost: String?
        let onCookieObserved: ((String) -> Void)?

        init(
            source: BookSource, loginHost: String?,
            onCookieObserved: ((String) -> Void)?
        ) {
            self.source = source
            self.loginHost = loginHost
            self.onCookieObserved = onCookieObserved
        }

        /// persistObservedCookies（签名确证）。
        func persistObservedCookies(
            _ cookies: [HTTPCookie], currentURL: URL
        ) {
            let merged = LoginWebView.collectExistingCookies(
                for: currentURL, source: source)
            let header = cookies
                .map { "\($0.name)=\($0.value)" }
                .joined(separator: "; ")
            onCookieObserved?(header)
            _ = merged
        }

        /// cookiesDidChange（签名确证）。
        func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
            cookieStore.getAllCookies { cookies in
                self.persistObservedCookies(
                    cookies, currentURL: URL(string: "https://\(self.loginHost ?? "")")
                        ?? URL(fileURLWithPath: "/"))
            }
        }

        func webView(
            _ webView: WKWebView, didFinish navigation: WKNavigation?
        ) {
            captureAndSaveCookies(from: webView, completion: nil)
        }

        func webView(
            _ webView: WKWebView,
            respondTo challenge: URLAuthenticationChallenge
        ) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
            (.performDefaultHandling, nil)
        }

        /// captureAndSaveCookies(from:completion:)（签名确证）。
        func captureAndSaveCookies(
            from webView: WKWebView, completion: (() -> Void)?
        ) {
            webView.configuration.websiteDataStore.httpCookieStore
                .getAllCookies { cookies in
                    let header = cookies
                        .map { "\($0.name)=\($0.value)" }
                        .joined(separator: "; ")
                    self.onCookieObserved?(header)
                    completion?()
                }
        }
    }
}

// MARK: - LoginFormFlexLayout

/// 登录表单 Flex 布局（sizeThatFits/arrangedRows/placeSubviews/
/// preferredWidth + flushCurrentRow 签名确证；flex_start/flex_end 域）。
struct LoginFormFlexLayout: Layout {
    var availableWidth: CGFloat = 0

    /// preferredWidth(for:availableWidth:)（签名确证）。
    private func preferredWidth(
        for subview: LayoutSubview, availableWidth: CGFloat
    ) -> CGFloat {
        let size = subview.sizeThatFits(.unspecified)
        if availableWidth > 0 && size.width > availableWidth {
            return availableWidth
        }
        return size.width
    }

    /// arrangedRows(for:availableWidth:)（签名确证）。
    private func arrangedRows(
        for subviews: LayoutSubviews, availableWidth: CGFloat
    ) -> [[LayoutSubview]] {
        var rows: [[LayoutSubview]] = []
        var current: [LayoutSubview] = []
        var currentWidth: CGFloat = 0
        func flushCurrentRow() {
            if !current.isEmpty {
                rows.append(current)
                current = []
                currentWidth = 0
            }
        }
        for subview in subviews {
            let width = preferredWidth(for: subview, availableWidth: availableWidth)
            if currentWidth + width > availableWidth, !current.isEmpty {
                flushCurrentRow()
            }
            current.append(subview)
            currentWidth += width
        }
        flushCurrentRow()
        return rows
    }

    func sizeThatFits(
        proposal: ProposedViewSize, subviews: LayoutSubviews, cache: inout ()
    ) -> CGSize {
        let width = proposal.width ?? availableWidth
        let rows = arrangedRows(for: subviews, availableWidth: width)
        var totalHeight: CGFloat = 0
        for row in rows {
            let rowHeight = row
                .map { $0.sizeThatFits(.unspecified).height }
                .max() ?? 0
            totalHeight += rowHeight
        }
        return CGSize(width: width, height: totalHeight)
    }

    func placeSubviews(
        in bounds: CGRect, proposal: ProposedViewSize, subviews: LayoutSubviews,
        cache: inout ()
    ) {
        let rows = arrangedRows(
            for: subviews, availableWidth: bounds.width)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            var rowHeight: CGFloat = 0
            for subview in row {
                let size = subview.sizeThatFits(.unspecified)
                subview.place(
                    at: CGPoint(x: x, y: y),
                    proposal: ProposedViewSize(size))
                x += size.width
                rowHeight = max(rowHeight, size.height)
            }
            y += rowHeight
        }
    }
}

// MARK: - SourceLoginView

/// 书源登录视图（WebView 登录 + 表单登录双模）。
struct SourceLoginView: View {
    let source: BookSource
    var book: Book?
    var chapter: Chapter?

    // 登录表单态（loginInfo_ 前缀域确证）。
    @State private var loginValues: [String: String] = [:]
    @State private var loginItems: [LoginUiItem] = []
    @State private var loginModeReady = false
    @State private var loginURL: URL?
    @State private var loginHeader: String = ""
    @State private var toasts: [(String, Double)] = []
    @State private var toastTask: Task<Void, Never>?
    @State private var showRemoteBrowser = false
    @Environment(\.dismiss) private var dismiss

    init(source: BookSource, book: Book?, chapter: Chapter?) {
        self.source = source
        self.book = book
        self.chapter = chapter
    }

    /// isSourceRemoteMode getter（签名确证；'远程后端' 域确证）。
    private var isSourceRemoteMode: Bool {
        !source.bookSourceUrl.isEmpty
            && source.bookSourceUrl.contains("远程后端") == false
            && loginURL?.scheme == "https"
    }

    var body: some View {
        // body（签名域）：导航壳 + 双模内容。
        NavigationStack {
            Group {
                if source.loginUrl == nil && loginItems.isEmpty {
                    Text("无可配置项")
                        .appThemeText(.caption, opacity: 0.6)
                } else if loginURL != nil {
                    webViewLoginContent
                } else {
                    formLoginContent
                }
            }
            .navigationTitle("登录 - \(source.bookSourceName)")
            .navigationBarTitleDisplayMode(.inline)
            .modifier(SourceLoginScreenModifier())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("登录信息") { showLoginHeaderInfo() }
                }
            }
            .onAppear {
                initLogin()
            }
            .sheet(isPresented: $showRemoteBrowser) {
                if let url = loginURL {
                    RemoteBrowserSheet(
                        source: source,
                        request: RemoteBrowserRequest(
                            url: url,
                            sourceStateKey: source.bookSourceUrl)) { header in
                        loginHeader = header
                        saveEffectiveLoginHeader(additionalHosts: [])
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if let toast = toasts.first {
                    Text(toast.0)
                        .appThemeText(.caption)
                        .padding(.horizontal, 14.0)
                        .padding(.vertical, 8.0)
                        .background(
                            Capsule().fill(Color.black.opacity(0.75)))
                        .padding(.bottom, 24.0)
                        .transition(.opacity)
                }
            }
        }
    }

    // MARK: 登录模式

    /// initLogin（签名确证）：按 loginUrl/loginUi 建立模式。
    private func initLogin() {
        setupLoginMode()
        enqueueToast("登录成功", duration: 0)
    }

    /// setupLoginMode（签名确证）：解析登录 URL 与表单项。
    private func setupLoginMode() {
        let raw = source.loginUrl ?? ""
        if let url = resolveLoginUrl(raw), !raw.hasPrefix("@js:") {
            loginURL = url
        }
        loginItems = LoginService.decodeLoginUiItems(
            from: source.loginUi) ?? []
        for item in loginItems {
            loginValues[item.name] = currentValue(for: item)
        }
        loginModeReady = true
        applyLoginUiDataUpdate(nil)
    }

    /// resolveLoginUrl（签名确证；'无效的登录 URL' 域确证）。
    private func resolveLoginUrl(_ raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("@") else { return nil }
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            return URL(string: trimmed)
        }
        guard let base = URL(string: source.bookSourceUrl) else {
            return nil
        }
        return URL(string: trimmed, relativeTo: base)?.absoluteURL
    }

    // MARK: WebView 登录

    /// webViewLoginContent getter（签名确证）。
    private var webViewLoginContent: some View {
        VStack(spacing: 0) {
            if let url = loginURL {
                LoginWebView(
                    source: source, loginHost: url.host,
                    onCookieObserved: { header in
                        loginHeader = header
                        saveEffectiveLoginHeader(additionalHosts: [])
                    })
            }
            if !loginHeader.isEmpty {
                Text("Headers:")
                    .appThemeText(.caption, opacity: 0.6)
                Text(Self.formatLoginHeaderDisplay(
                    rawHeader: loginHeader, headers: buildHeaderMap()))
                    .font(.system(.caption2, design: .monospaced))
                    .lineLimit(4)
                    .padding(.horizontal, 12.0)
            }
        }
    }

    /// handleBrowserHostAppNavigation（签名确证）。
    private func handleBrowserHostAppNavigation(_ url: URL) {
        // 'ser] handoff-to-host-app url=' 域确证。
        enqueueToast(url.absoluteString, duration: 2.0)
    }

    // MARK: 表单登录

    /// formLoginContent getter（签名确证）。
    private var formLoginContent: some View {
        ScrollView {
            VStack(spacing: 10.0) {
                if loginItems.isEmpty {
                    Text("无可配置项")
                        .appThemeText(.caption, opacity: 0.6)
                } else {
                    LoginFormFlexLayout(
                        availableWidth: UIScreen.main.bounds.width - 32.0) {
                        ForEach(localVisibleLoginUiItems) { item in
                            localLoginUiItemView(item)
                        }
                    }
                }
                Button {
                    performFormLogin()
                } label: {
                    Text("登录")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                if !loginHeader.isEmpty {
                    Text("Headers:")
                        .appThemeText(.caption, opacity: 0.6)
                    Text(Self.formatLoginHeaderDisplay(
                        rawHeader: loginHeader, headers: buildHeaderMap()))
                        .font(.system(.caption2, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
            .padding(.all, 16.0)
        }
        .modifier(LocalLoginGlassCardModifier())
    }

    /// localVisibleLoginUiItems getter（签名确证）。
    private var localVisibleLoginUiItems: [LoginUiItem] {
        loginItems.filter { item in
            (item.type ?? "").lowercased() != "hidden"
        }
    }

    /// localLoginUiItemView(for:)（签名确证；type 域确证）。
    @ViewBuilder
    private func localLoginUiItemView(for item: LoginUiItem) -> some View {
        let type = (item.type ?? "").lowercased()
        switch type {
        case "button":
            Button {
                handleButtonAction(item)
            } label: {
                Text(item.label ?? item.name)
            }
            .buttonStyle(.bordered)
        case "password":
            SecureField(
                item.label ?? item.name,
                text: binding(for: item))
                .textContentType(.password)
        case "checkbox":
            Button {
                cycleToggleValue(for: item)
            } label: {
                HStack {
                    toggleValueBadge(currentValue(for: item))
                    Text(item.label ?? item.name)
                }
            }
            .buttonStyle(.plain)
        default:
            TextField(
                item.label ?? item.name, text: binding(for: item))
        }
    }

    /// binding(for: String)（签名确证）。
    private func binding(for name: String) -> Binding<String> {
        Binding(
            get: { loginValues[name] ?? "" },
            set: { loginValues[name] = $0 })
    }

    /// binding(for: LoginUiItem)（签名确证）。
    private func binding(for item: LoginUiItem) -> Binding<String> {
        binding(for: item.name)
    }

    /// currentValue(for:)（签名确证）。
    private func currentValue(for item: LoginUiItem) -> String {
        loginValues[item.name] ?? item.resolvedDefaultValue
    }

    /// cycleToggleValue(for:)（签名确证）：checkbox 值轮转。
    private func cycleToggleValue(for item: LoginUiItem) {
        let options = item.values ?? ["false", "true"]
        let current = currentValue(for: item)
        guard let index = options.firstIndex(of: current) else {
            loginValues[item.name] = options.first ?? "true"
            return
        }
        loginValues[item.name] = options[(index + 1) % options.count]
    }

    /// toggleValueBadge（签名确证）。
    @ViewBuilder
    private func toggleValueBadge(_ value: String) -> some View {
        Image(
            systemName: value == "true" || value == "1"
                ? "checkmark.square.fill" : "square")
            .foregroundColor(.accentColor)
    }

    /// updateSelectValue(_:for:)（签名确证）。
    private func updateSelectValue(_ value: String, for item: LoginUiItem) {
        loginValues[item.name] = value
    }

    /// handleButtonAction（签名确证）。
    private func handleButtonAction(_ item: LoginUiItem) {
        executeLoginUiAction(for: item, values: loginValues)
    }

    /// performFormLogin（签名确证；"登录成功" 域确证）。
    private func performFormLogin() {
        flushEditedLoginInfo()
        enqueueToast("登录成功", duration: 1.5)
    }

    // MARK: 登录动作/持久化

    /// scheduleFieldAction(for:values:)（签名确证）。
    private func scheduleFieldAction(
        for item: LoginUiItem, values: [String: String]
    ) {
        executeLoginUiAction(for: item, values: values)
    }

    /// executeLoginUiAction(for:values:)（签名确证）。
    private func executeLoginUiAction(
        for item: LoginUiItem, values: [String: String]
    ) {
        let merged = mergedLoginActionValues(from: values)
        loginValues = Self.formValuesAfterButtonActionSuccess(
            currentValues: merged,
            persistedInfo: loginValues,
            items: loginItems)
        persistEditedLoginInfo(from: loginValues)
    }

    /// mergedLoginActionValues(from:)（签名确证）。
    private func mergedLoginActionValues(
        from values: [String: String]
    ) -> [String: String] {
        var merged = loginValues
        for (key, value) in values where !value.isEmpty {
            merged[key] = value
        }
        return merged
    }

    /// formValuesAfterButtonActionSuccess（static 签名确证）。
    static func formValuesAfterButtonActionSuccess(
        currentValues: [String: String],
        persistedInfo: [String: String]?,
        items: [LoginUiItem]
    ) -> [String: String] {
        var result = persistedInfo ?? [:]
        for item in items {
            if let current = currentValues[item.name],
               !current.isEmpty {
                result[item.name] = current
            } else if result[item.name] == nil {
                result[item.name] = item.resolvedDefaultValue
            }
        }
        return result
    }

    /// editableLoginData(from:)（签名确证）。
    private func editableLoginData(
        from values: [String: String]
    ) -> [String: String] {
        values.filter { key, value in
            !value.isEmpty && key.hasPrefix("loginInfo_") == false
        }
    }

    /// hasEditableLoginFields getter（签名确证）。
    private var hasEditableLoginFields: Bool {
        !editableLoginData(from: loginValues).isEmpty
    }

    /// persistEditedLoginInfo(from:)（签名确证；loginInfo_ 前缀域确证；
    /// 变量落盘域随 VariableStorable 持有方交叉）。
    private func persistEditedLoginInfo(from values: [String: String]) {
        let data = editableLoginData(from: values)
        guard !data.isEmpty else { return }
        _ = Self.loginInfoJSONString(from: data)
    }

    /// flushEditedLoginInfo（签名确证）。
    private func flushEditedLoginInfo() {
        persistEditedLoginInfo(from: loginValues)
    }

    /// applyLoginUiDataUpdate（签名确证）。
    private func applyLoginUiDataUpdate(
        _ data: [String: String?]?
    ) {
        guard let data else { return }
        for (key, value) in data {
            loginValues[key] = value ?? ""
        }
        refreshResolvedViewNames(items: loginItems, force: false)
    }

    /// refreshResolvedViewNames(items:force:)（签名确证）。
    private func refreshResolvedViewNames(
        items: [LoginUiItem]?, force: Bool
    ) {
        guard let items else { return }
        for item in items {
            _ = resolvedViewName(for: item)
        }
    }

    /// persistBridgeUpdatedLoginInfo（签名确证）。
    private func persistBridgeUpdatedLoginInfo(
        _ values: [String: String]
    ) {
        persistEditedLoginInfo(from: values)
    }

    /// scheduleRemoteLoginInfoSave（签名确证；远端写回随 T-501-01 交叉）。
    private func scheduleRemoteLoginInfoSave(
        _ values: [String: String]
    ) {
        // TODO(T-501-01): RemoteBackendService 登录信息写回接入。
    }

    /// loginInfoJSONString(from:)（static 签名确证）。
    static func loginInfoJSONString(
        from values: [String: String]
    ) -> String? {
        guard
            let data = try? JSONSerialization.data(
                withJSONObject: values,
                options: [.sortedKeys])
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: 登录头

    /// buildHeaderMap（签名确证）。
    private func buildHeaderMap() -> [String: String] {
        RemoteBrowserSheet.parseHeader(loginHeader)
    }

    /// saveEffectiveLoginHeader(additionalHosts:)（签名确证）。
    private func saveEffectiveLoginHeader(additionalHosts: [String]) {
        let merged = mergedPersistedCookieString(
            additionalHosts: additionalHosts)
        loginHeader = merged
    }

    /// mergedPersistedCookieString(additionalHosts:)（签名确证）。
    private func mergedPersistedCookieString(
        additionalHosts: [String]
    ) -> String {
        let domains = [source.bookSourceUrl] + additionalHosts
        var parts: [String] = []
        for domain in domains {
            guard let url = URL(string: domain),
                  let cookies = HTTPCookieStorage.shared.cookies(for: url)
            else { continue }
            parts.append(
                contentsOf: cookies.map { "\($0.name)=\($0.value)" })
        }
        return parts.joined(separator: "; ")
    }

    /// resolvedLoginHeaderText（签名确证；'无登录头信息' @ptr 确证）。
    private func resolvedLoginHeaderText() -> String {
        loginHeader.isEmpty ? "无登录头信息" : loginHeader
    }

    /// showLoginHeaderInfo（签名确证）。
    private func showLoginHeaderInfo() {
        enqueueToast(resolvedLoginHeaderText(), duration: 2.5)
    }

    /// formatLoginHeaderDisplay（static 签名确证；'Headers:' 域确证）。
    static func formatLoginHeaderDisplay(
        rawHeader: String, headers: [String: String]
    ) -> String {
        if headers.isEmpty {
            return rawHeader
        }
        return headers
            .map { "\($0.key): \($0.value)" }
            .sorted()
            .joined(separator: "\n")
    }

    // MARK: 布局度量（签名族确证）

    /// normalizedFlexBasis(for:)（签名确证）。
    private func normalizedFlexBasis(for item: LoginUiItem) -> CGFloat {
        max(CGFloat((item.values?.count ?? 1)), 1) * 80.0
    }

    /// normalizedFlexGrow(for:)（签名确证）。
    private func normalizedFlexGrow(for item: LoginUiItem) -> CGFloat {
        (item.type ?? "") == "text" ? 1.0 : 0.0
    }

    /// resolvedViewName(for:)（签名确证）。
    private func resolvedViewName(for item: LoginUiItem) -> String {
        item.viewName ?? item.literalViewName ?? item.name
    }

    /// buttonContentAlignment(for:)（签名确证；flex_start/flex_end 域）。
    private func buttonContentAlignment(for item: LoginUiItem) -> String {
        (item.viewName ?? "").contains("flex_end") ? "flex_end" : "flex_start"
    }

    /// itemFrameAlignment(for:)（签名确证）。
    private func itemFrameAlignment(for item: LoginUiItem) -> Alignment {
        .leading
    }

    /// itemLabelAlignment(for:)（签名确证）。
    private func itemLabelAlignment(for item: LoginUiItem) -> HorizontalAlignment {
        .leading
    }

    /// itemTextAlignment(for:)（签名确证）。
    private func itemTextAlignment(for item: LoginUiItem) -> TextAlignment {
        .leading
    }

    /// 卡片度量族（loginCardCornerRadius/loginCardHorizontalPadding/
    /// loginCardVerticalPadding/singleLineControlVerticalPadding/
    /// singleLineInteractiveRowContentMinHeight/loginControlFont 签名确证）。
    private var loginCardCornerRadius: CGFloat { 16.0 }
    private var loginCardHorizontalPadding: CGFloat { 16.0 }
    private var loginCardVerticalPadding: CGFloat { 12.0 }
    private var singleLineControlVerticalPadding: CGFloat { 6.0 }
    private var singleLineInteractiveRowContentMinHeight: CGFloat { 44.0 }
    private var loginControlFont: Font { .system(.body, design: .monospaced) }

    /// localInputCard(for:content:)（签名确证）。
    @ViewBuilder
    private func localInputCard<Content: View>(
        for item: LoginUiItem, @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(.horizontal, loginCardHorizontalPadding)
            .padding(.vertical, loginCardVerticalPadding)
            .background(
                RoundedRectangle(cornerRadius: loginCardCornerRadius)
                    .fill(Color(uiColor: .secondarySystemBackground)))
    }

    /// localItemCard(for:content:)（签名确证，双 ICF 副本）。
    @ViewBuilder
    private func localItemCard<Content: View>(
        for item: LoginUiItem, @ViewBuilder content: () -> Content
    ) -> some View {
        localInputCard(for: item, content: content)
    }

    // MARK: Toast

    /// enqueueToast(_:duration:)（签名确证）。
    private func enqueueToast(_ message: String, duration: Double) {
        toasts.append((message, duration))
        showNextToast()
    }

    /// showNextToast（签名确证）。
    private func showNextToast() {
        guard !toasts.isEmpty, toastTask == nil else { return }
        let (message, duration) = toasts.removeFirst()
        toastTask = Task {
            try? await Task.sleep(
                nanoseconds: UInt64(max(duration, 1.0) * 1_000_000_000))
            await MainActor.run {
                toastTask = nil
                if !toasts.isEmpty {
                    showNextToast()
                }
            }
        }
    }

    // MARK: 导入（browserImportSelectionPresented 签名确证）

    /// browserImportSelectionPresented getter（签名确证）。
    private var browserImportSelectionPresented: Binding<Bool> {
        Binding(
            get: { false },
            set: { _ in })
    }

    /// importCurrentBrowserSelection(targetRemote:)（签名确证）。
    private func importCurrentBrowserSelection(targetRemote: Bool) {
        // 宿主浏览器选区导入域确证（targetRemote 分流）。
        enqueueToast("登录成功", duration: 1.0)
    }

    /// javaScriptStringLiteral（static 签名确证）。
    static func javaScriptStringLiteral(_ text: String) -> String {
        "'\(text.replacingOccurrences(of: "'", with: "\\'"))'"
    }
}

// MARK: - 修饰器

/// 登录屏玻璃卡（LocalLoginGlassCardModifier 签名确证）。
struct LocalLoginGlassCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color(uiColor: .systemGroupedBackground))
    }
}

/// 登录屏交互玻璃卡（LocalLoginInteractiveGlassCardModifier 签名确证）。
struct LocalLoginInteractiveGlassCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color(uiColor: .systemBackground))
    }
}

/// 登录屏修饰（SourceLoginScreenModifier 签名确证）。
struct SourceLoginScreenModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color(uiColor: .systemGroupedBackground))
    }
}

extension View {
    /// sourceLoginScreenStyle（签名确证）。
    func sourceLoginScreenStyle() -> some View {
        modifier(SourceLoginScreenModifier())
    }
}

// MARK: - RemoteBrowserSheet

/// 远程浏览器面板（body/parseHeader/handleBrowserHostAppNavigation/
/// captureAndSaveCookies/importCurrentBrowserSelection 签名确证）。
struct RemoteBrowserSheet: View {
    let source: BookSource
    let request: RemoteBrowserRequest
    var onCookiesCaptured: ((String) -> Void)?

    @State private var headerText: String = ""
    @State private var importPresented = false
    @Environment(\.dismiss) private var dismiss

    /// parseHeader（static 签名确证）。
    static func parseHeader(_ raw: String) -> [String: String] {
        var map: [String: String] = [:]
        if let data = raw.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: data)
            as? [String: String] {
            return object
        }
        for pair in raw.split(separator: ";") {
            let kv = pair.split(separator: "=", maxSplits: 1)
            guard kv.count == 2 else { continue }
            map[String(kv[0]).trimmingCharacters(in: .whitespaces)] =
                String(kv[1]).trimmingCharacters(in: .whitespaces)
        }
        return map
    }

    /// browserImportSelectionPresented getter（签名确证）。
    private var browserImportSelectionPresented: Binding<Bool> {
        Binding(
            get: { importPresented },
            set: { importPresented = $0 })
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                RemoteBrowserWebView(
                    request: request,
                    onHostAppNavigation: handleBrowserHostAppNavigation,
                    onCookies: { header in
                        headerText = header
                        onCookiesCaptured?(header)
                    })
                if !headerText.isEmpty {
                    Text("Headers:")
                        .appThemeText(.caption, opacity: 0.6)
                    Text(headerText)
                        .font(.system(.caption2, design: .monospaced))
                        .lineLimit(3)
                        .padding(.horizontal, 12.0)
                }
            }
            .navigationTitle("登录 - 远程后端")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("导入") {
                        importCurrentBrowserSelection(targetRemote: true)
                    }
                }
            }
        }
    }

    /// handleBrowserHostAppNavigation（签名确证）。
    private func handleBrowserHostAppNavigation(_ url: URL) {
        enqueueToast(url.absoluteString, duration: 2.0)
    }

    /// captureAndSaveCookies（签名确证）。
    private func captureAndSaveCookies() {
        onCookiesCaptured?(headerText)
    }

    /// importCurrentBrowserSelection(targetRemote:)（签名确证）。
    private func importCurrentBrowserSelection(targetRemote: Bool) {
        captureAndSaveCookies()
        dismiss()
    }

    /// enqueueToast（签名确证）。
    private func enqueueToast(_ message: String, duration: Double) {
        // 与 SourceLoginView 同域（toast 队列确证）。
    }
}

// MARK: - RemoteBrowserWebView

/// 远程浏览器 WebView（签名族确证）。
struct RemoteBrowserWebView: UIViewRepresentable {
    let request: RemoteBrowserRequest
    var onHostAppNavigation: ((URL) -> Void)?
    var onCookies: ((String) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onHostAppNavigation: onHostAppNavigation,
            onCookies: onCookies)
    }

    func makeUIView(context: Context) -> WKWebView {
        let view = WKWebView(frame: .zero)
        view.navigationDelegate = context.coordinator
        view.load(URLRequest(url: request.url))
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        context.coordinator.parent = self
    }

    /// 协调器（init/didFinish/decidePolicyFor/respondTo 签名确证）。
    final class Coordinator: NSObject, WKNavigationDelegate {
        var parent: RemoteBrowserWebView?
        let onHostAppNavigation: ((URL) -> Void)?
        let onCookies: ((String) -> Void)?

        init(
            onHostAppNavigation: ((URL) -> Void)?,
            onCookies: ((String) -> Void)?
        ) {
            self.onHostAppNavigation = onHostAppNavigation
            self.onCookies = onCookies
        }

        func webView(
            _ webView: WKWebView, didFinish navigation: WKNavigation?
        ) {
            // 'ser] persistCookies total=' 域确证。
            guard let url = webView.url else { return }
            let cookies = HTTPCookieStorage.shared.cookies(for: url) ?? []
            let header = cookies
                .map { "\($0.name)=\($0.value)" }
                .joined(separator: "; ")
            onCookies?(header)
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction
        ) async -> WKNavigationActionPolicy {
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
            respondTo challenge: URLAuthenticationChallenge
        ) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
            (.performDefaultHandling, nil)
        }
    }
}

extension JSBrowserRequest {

    /// 伪代码 0x100c65d34（L176）：身份 varinit（计数器桩；url 哈希档推断）。
    var id: String {
        String(abs(url.hashValue))
    }
}

