// 原路径: ReadMain/Views/Reader/PayActionWebView.swift
// 证据:
//   - PGO: 6 个主函数（index/task_functions.csv T-301-05 / PayActionWebView.swift），
//     地址：makeUIView 0x10077c334 L9-44 / cookie 闭包 0x100781728 L38 /
//     updateUIView 0x10077d518 L46 / dismantleUIView 0x10077d5a8 L48-50 /
//     collectCookies(for:) 0x10077c98c L62-102 / Substring 闭包 0x100781d20 L83
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Reader/PayActionWebView.c（1125 行）
//   - 关键选择子：WKWebsiteDataStore.nonPersistentDataStore/setWebsiteDataStore:/
//     setAllowsContentJavaScript:/setDefaultWebpagePreferences:/httpCookieStore/
//     setCookie:completionHandler:/initWithFrame:configuration:/setNavigationDelegate:/
//     setAllowsBackForwardNavigationGestures:/setCustomUserAgent:/loadRequest:/
//     sharedHTTPCookieStorage/cookiesForURL:/standardUserDefaults/stringForKey:/
//     JSONObjectWithData:options:error:（utf8）
//   - 关键调用：JsResourceLoader.injectJsoupBridge（静态确证）；
//     CharacterSet.whitespaces 裁剪 + String._fromSubstring
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（选择子/存储域/cookie 链确证；JS 注入体属 T-204 分册）
// 还原: 2026-11-19

import SwiftUI
import WebKit

/// 支付动作页（非持久 WKWebView + cookie 注入 + jsoup 桥）。
struct PayActionWebView: UIViewRepresentable {
    var url: URL

    func makeUIView(context: Context) -> WKWebView {
        // 伪代码 0x10077c334（L9-44）：非持久存储 + 允许 JS + cookie 预注入。
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        // JS 启用走 WKWebpagePreferences.allowsContentJavaScript（iOS 14+ 域）。
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = preferences

        let cookies = collectCookies(for: url)
        let cookieStore = configuration.websiteDataStore.httpCookieStore
        for cookie in cookies {
            cookieStore.setCookie(cookie, completionHandler: nil)
        }

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = false
        // jsoup 桥注入（JsResourceLoader.injectJsoupBridge 静态确证）。
        JsResourceLoader.injectJsoupBridge(into: configuration)
        webView.customUserAgent = context.coordinator.userAgent
        webView.load(URLRequest(url: url))
        return webView
    }

    /// 伪代码 0x10077d518（L46）：无状态更新。
    func updateUIView(_ webView: WKWebView, context: Context) {
        _ = webView
        _ = context
    }

    /// 伪代码 0x10077d5a8（L48-50）：销毁清理。
    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.stopLoading()
        _ = coordinator
    }

    /// 伪代码 0x10077c98c（L62-102）。
    /// 共享 HTTPCookieStorage.cookiesForURL(url)；
    /// UserDefaults stringForKey（utf8 JSON 反序列化为 cookie 数组）；
    /// 两次 cookiesForURL 合并（L773-782）。
    private func collectCookies(for url: URL) -> [HTTPCookie] {
        var cookies = HTTPCookieStorage.shared.cookies(for: url) ?? []
        if let stored = UserDefaults.standard.string(forKey: "payCookies") {
            // HTTPCookie 非 Decodable——经 properties 字典域编解码桥（还原推断：
            // 写入侧为 [[String: String]] properties JSON）。
            if let data = stored.data(using: .utf8),
               let decoded = try? JSONDecoder().decode(
                   [[String: String]].self, from: data) {
                // properties 键域为 HTTPCookiePropertyKey——String 桥转换
                // （wave-16）。
                let restored = decoded.compactMap { props -> HTTPCookie? in
                    let keyed = Dictionary(
                        uniqueKeysWithValues: props.map {
                            (HTTPCookiePropertyKey($0.key), $0.value)
                        })
                    return HTTPCookie(properties: keyed)
                }
                cookies.append(contentsOf: restored)
            }
        }
        let merged = HTTPCookieStorage.shared.cookies(for: url) ?? []
        cookies.append(contentsOf: merged.filter { stored in
            !cookies.contains(where: { $0.name == stored.name })
        })
        return cookies
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    /// 导航协调器（UA 常量体待真机对照）。
    final class Coordinator: NSObject, WKNavigationDelegate {
        var userAgent: String = ""
    }
}
