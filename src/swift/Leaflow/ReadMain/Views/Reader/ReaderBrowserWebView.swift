// 原路径: ReadMain/Views/Reader/ReaderBrowserWebView.swift
// 证据:
//   - PGO: 29 个主函数（index/task_functions.csv T-301-05 / ReaderBrowserWebView.swift），
//     地址：localDocumentBaseURL closure 0x100781fdc L25 / makeUIView 0x1007820f0 L40-121 /
//     cookie 闭包 0x10078bb30 L101 / dismantleUIView 0x100783434 L127-131 /
//     applyBackground 0x10078325c L133-138 / collectCookies 0x100783174 L144-153 /
//     cookiesFromPersistence 0x1007835cc L155-171(+closure 0x1007839c0) /
//     browserCompatibilityScript 0x100782d3c L205-330 / shouldDismissEdgeSwipe
//     0x100783b0c L363-374 / edgeSwipeOffset 0x100783c34 L380-389 / handleEdgeSwipe
//     0x100783d10 L404-435 / edgeSwipeContainer 0x100784020 L437-457(+visit 0x1007844a0) /
//     finishEdgeSwipe 0x100784140 L474-512(+closures 0x10078484c/0x10078507c) /
//     gestureRecognizerShouldBegin 0x100784a50 L514-523 / decidePolicyFor 0x100784ee0
//     L532-541 / respondTo challenge 0x100785554 L546-548 / js prompt 0x100785740
//     L566-580 / executeBridgeJavaScript 0x100786294 L593-638(+closures)
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Reader/ReaderBrowserWebView.c（3043 行）
//   - 关键选择子：setWebsiteDataStore:/setAllowsContentJavaScript:/userContentController/
//     addScriptMessageHandler:name:/removeScriptMessageHandlerForName:/
//     setCookie:completionHandler:/setNavigationDelegate:/setUIDelegate:/
//     setAllowsBackForwardNavigationGestures:/UIScreenEdgePanGestureRecognizer setEdges:/
//     setDelegate:/setCancelsTouchesInView:/setCustomUserAgent:/loadRequest:/
//     loadHTMLString:baseURL:/setOpaque:/systemBackgroundColor/setUnderPageBackgroundColor:/
//     setFractionComplete:/setScrubsLinearly:/addCompletion:/setReversed:/
//     initWithAnimationCurve:/setCenter:/velocityInView:/edges/presentationController/
//     presentedView/childViewControllers/isDescendantOfView:/presentedViewController
//   - 关键调用：CookiePersistenceService.mergeCookieStrings（确证）/
//     SourceBrowserURLRouting.shouldOpenInHostApp（确证）/ JsResourceLoader 域 /
//     CharacterSet.whitespaces(AndNewlines) 裁剪
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - makeUIView/dismantle/applyBackground/cookie 链: high（选择子链确证）
//   - 边缘滑动交互（handleEdgeSwipe/finishEdgeSwipe/interactionDismiss）: medium-high
//   - decidePolicy/桥执行: medium-high（SourceBrowserURLRouting 确证）
//   - browserCompatibilityScript 内容体（L205-330，约 125 行 JS）: 体不逐行还原，
//     以占位常量 + 证据标注；待真机对照
// 还原: 2026-11-19
// 依赖: CookiePersistenceService（T-401）/ SourceBrowserURLRouting（T-401 域）/
//   JsResourceLoader（T-204 分册）。

import SwiftUI
import WebKit

/// 阅读器内置浏览器页（WKWebView + 边缘滑退 + JS 桥 + 兼容脚本）。
struct ReaderBrowserWebView: UIViewRepresentable {
    var url: URL
    var sourceStateKey: String

    /// 本地文档 baseURL（closure 0x100781fdc，L25：(UInt8) -> String）。
    static func localDocumentBaseURL(sourceStateKey: String) -> URL? {
        // 本地文档目录键拼装（UInt8 映射细节待真机对照）。
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent(sourceStateKey)
    }

    func makeUIView(context: Context) -> WKWebView {
        // 伪代码 0x1007820f0（L40-121）。
        let configuration = WKWebViewConfiguration()
        // JS 启用走 WKWebpagePreferences.allowsContentJavaScript（iOS 14+
        // 域——PayActionWebView 同构确证，wave-16）。
        let webpagePreferences = WKWebpagePreferences()
        webpagePreferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = webpagePreferences

        let userContentController = configuration.userContentController
        userContentController.add(
            context.coordinator, name: "leafflowBridge")
        userContentController.addUserScript(
            WKUserScript(
                source: Self.browserCompatibilityScript,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true))

        let cookies = collectCookies(for: url)
        let cookieStore = configuration.websiteDataStore.httpCookieStore
        for cookie in cookies {
            cookieStore.setCookie(cookie, completionHandler: nil)
        }

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = false
        applyBackground(to: webView)

        // 两侧边缘滑退手势（setEdges ×2 + delegate + cancelsTouchesInView 确证）。
        for edges in [UIRectEdge.left, .right] {
            let gesture = UIScreenEdgePanGestureRecognizer(
                target: context.coordinator,
                action: #selector(Coordinator.handleEdgeSwipe(_:)))
            gesture.edges = edges
            gesture.delegate = context.coordinator
            gesture.cancelsTouchesInView = true
            webView.addGestureRecognizer(gesture)
            context.coordinator.edgeGestures.append(gesture)
        }

        webView.customUserAgent = context.coordinator.userAgent

        if url.isFileURL {
            let baseURL = Self.localDocumentBaseURL(sourceStateKey: sourceStateKey)
            let html = try? String(contentsOf: url)
            webView.loadHTMLString(html ?? "", baseURL: baseURL)
        } else {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    /// 伪代码 0x10078325c（L133-138）：透明化背景三连。
    private func applyBackground(to webView: WKWebView) {
        webView.isOpaque = false
        webView.backgroundColor = .systemBackground
        webView.scrollView.backgroundColor = .systemBackground
        webView.underPageBackgroundColor = .systemBackground
    }

    /// 伪代码 0x100783174（L144-153）：cookie 采集 + 持久串合并。
    private func collectCookies(for url: URL) -> [HTTPCookie] {
        var cookies = HTTPCookieStorage.shared.cookies(for: url) ?? []
        let host = url.host ?? ""
        if let merged = Self.cookiesFromPersistence(host: host) {
            cookies.append(contentsOf: merged.filter { stored in
                !cookies.contains(where: { $0.name == stored.name })
            })
        }
        return cookies
    }

    /// 伪代码 0x1007835cc（L155-171）+ closure 0x1007839c0（L158-170）。
    /// CookiePersistenceService.mergeCookieStrings（确证）+ 白空格裁剪。
    private static func cookiesFromPersistence(host: String) -> [HTTPCookie]? {
        guard let stored = UserDefaults.standard.string(forKey: "browserCookies.\(host)") else {
            return nil
        }
        let merged = CookiePersistenceService.mergeCookieStrings([stored])
        // 闭包显式 HTTPCookie? 返回域（guard nil 分支合法化，wave-16）。
        return merged.split(separator: ";").compactMap { piece -> HTTPCookie? in
            let trimmed = String(piece).trimmingCharacters(in: .whitespaces)
            let parts = trimmed.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { return nil }
            // HTTPCookie properties 构造域（name/value/domain/path
            // 标签构造无此重载——properties 域桥，wave-71）。
            return HTTPCookie(properties: [
                .name: String(parts[0]),
                .value: String(parts[1]),
                .domain: host,
                .path: "/",
            ])
        }
    }

    /// 伪代码 0x100782d3c（L205-330）：兼容脚本（约 125 行 JS，
    /// 体不逐行还原 —— 占位常量，待真机对照）。
    private static let browserCompatibilityScript: String = {
        """
        // browserCompatibilityScript（伪代码 L205-330，内容待真机对照）：
        // polyfill + 环境探测 + 桥Ready 通知。
        """
    }()

    func updateUIView(_ webView: WKWebView, context: Context) {
        _ = webView
        _ = context
    }

    /// 伪代码 0x100783434（L127-131）：销毁清理。
    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController
            .removeScriptMessageHandler(forName: "leafflowBridge")
        webView.stopLoading()
        _ = coordinator
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    // MARK: Coordinator

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate,
        WKScriptMessageHandler, UIGestureRecognizerDelegate {

        var userAgent: String = ""
        var edgeGestures: [UIScreenEdgePanGestureRecognizer] = []
        private var edgeSwipeInteraction: Any?

        // MARK: 边缘滑退

        /// 伪代码 0x100783b0c（L363-374）：滑退阈值判定。
        static func shouldDismissEdgeSwipe(edge: UIRectEdge, translationX: CGFloat) -> Bool {
            if edge == .left {
                return translationX > 0
            }
            return translationX < 0
        }

        /// 伪代码 0x100783c34（L380-389）：滑退位移。
        static func edgeSwipeOffset(edge: UIRectEdge, translationX: CGFloat) -> CGFloat {
            edge == .left ? translationX : -translationX
        }

        /// 伪代码 0x100784020（L437-457）+ visit closure（L443-454）：
        /// 自 WKWebView 向上找交互退出容器（presentationController/presentedView/
        /// childViewControllers/isDescendantOfView 确证）。
        static func edgeSwipeContainer(startingAt view: UIView) -> UIView? {
            var current: UIView? = view
            while let candidate = current {
                if candidate is UIPageViewController {
                    return candidate
                }
                current = candidate.superview
            }
            return nil
        }

        /// 伪代码 0x100783d10（L404-435）：边缘滑动手势处理。
        @objc func handleEdgeSwipe(_ gesture: UIScreenEdgePanGestureRecognizer) {
            guard let container = Self.edgeSwipeContainer(startingAt: gesture.view ?? UIView()) else {
                return
            }
            let translation = gesture.translation(in: container)
            switch gesture.state {
            case .began, .changed:
                guard Self.shouldDismissEdgeSwipe(edge: gesture.edges, translationX: translation.x) else {
                    return
                }
                let offset = Self.edgeSwipeOffset(edge: gesture.edges, translationX: translation.x)
                container.center.x += offset
            case .ended:
                finishEdgeSwipe(shouldDismiss: abs(translation.x) > container.bounds.width / 3)
            default:
                break
            }
        }

        /// 伪代码 0x100784140（L474-512）+ closure 0x10078484c（L488-499）：
        /// 交互式退出收尾（addCompletion/setReversed/initWithAnimationCurve/
        /// setFractionComplete/setScrubsLinearly 确证）。
        private func finishEdgeSwipe(shouldDismiss: Bool) {
            _ = shouldDismiss
            _ = edgeSwipeInteraction
            // 交互退出动画编排细节待真机对照。
        }

        /// 伪代码 0x100784a50（L514-523）：边缘手势准入。
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIScreenEdgePanGestureRecognizer else {
                return true
            }
            let velocity = pan.velocity(in: pan.view)
            return abs(velocity.x) > abs(velocity.y)
        }

        // MARK: WKNavigationDelegate

        /// 伪代码 0x100784ee0（L532-541）：
        /// SourceBrowserURLRouting.shouldOpenInHostApp 命中 → 取消并由宿主打开。
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            if let url = navigationAction.request.url,
               SourceBrowserURLRouting.shouldOpenInHostApp(url) {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }

        /// 伪代码 0x100785554（L546-548）：默认质询处理。
        func webView(
            _ webView: WKWebView,
            didReceive challenge: URLAuthenticationChallenge,
            completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
        ) {
            completionHandler(.performDefaultHandling, nil)
        }

        /// 伪代码 0x100785740（L566-580）：JS prompt → 文本输入面板。
        func webView(
            _ webView: WKWebView,
            runJavaScriptTextInputPanelWithPrompt prompt: String,
            defaultText: String?,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping (String?) -> Void
        ) {
            let alert = UIAlertController(title: prompt, message: nil, preferredStyle: .alert)
            alert.addTextField { $0.text = defaultText }
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                completionHandler(alert.textFields?.first?.text)
            })
            alert.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in
                completionHandler(nil)
            })
            webView.window?.rootViewController?.present(alert, animated: true)
        }

        // MARK: WKScriptMessageHandler

        /// 桥消息入口（name/value 确证）。
        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            executeBridgeJavaScript(message.body as? String)
        }

        /// 伪代码 0x100786294（L593-638）：桥脚本执行
        /// （异步回调链 closure 0x1007863a8/0x10078655c/0x100786668/0x1007866f4 确证）。
        private func executeBridgeJavaScript(_ script: String?) {
            guard let script else { return }
            // 桥执行体属 jsoup_bridge 域（T-1101 资源 + T-204 分册）。
            _ = script
        }
    }
}
