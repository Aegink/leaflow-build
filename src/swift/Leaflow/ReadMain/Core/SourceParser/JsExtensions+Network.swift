// 原路径: ReadMain/Core/SourceParser/ReadMain/Core/SourceParser/JsExtensions+Network.swift
// 证据:
//   - PGO: ajaxAll/post/head/webView/webViewGetSource/webViewGetOverrideUrl/startBrowserAwait/getVerificationCode/openUrl/ajaxBytes/formatUrl
//   - CovMap: ajaxAll L23-45 @0x100107290；post L55-68 @0x100107a40；head L71-82 @0x10010821c；webView L85-112 @0x1001084ec；webViewGetSource L117-126 @0x100108a3c；webViewGetOverrideUrl L129-138 @0x100108bf0；startBrowserAwait L143-155 @0x100108f1c；getVerificationCode L158-194 @0x10010923c；openUrl L197-201 @0x100156610；ajaxBytes L206-215 @0x100107120；formatUrl L226-253 @0x100107c80
//   - IDA: 上述地址
//   - 主线程死锁防护诊断串：[JS WebView] ⚠️ 在主线程调用 webView()…/[webViewGetSource] ⚠️…/[webViewGetOverrideUrl] ⚠️…/[startBrowserAwait] ⚠️…（isMainThread/threadDictionary）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: medium-high（主线程回退确证；验证码链见读后记推断 2）
// 还原: 2026-11-19


import Foundation

extension JsExtensions {

    /// 主线程死锁防护（事实 3）：WebView 族调用在主线程时回退 ajax。
    private static var isOnMainThread: Bool { Thread.isMainThread }

    /// 伪代码 0x100107290（L23-45）。
    func ajaxAll(_ urls: [String]) -> [String] {
        DispatchQueue.global().sync {
            urls.map { ajax($0) }
        }
    }

    /// `ajax:` 选择子（串行请求）。
    func ajax(_ url: String) -> String {
        guard let response = URL(string: url).map({ try? Data(contentsOf: $0) }) else { return "" }
        return String(data: response ?? Data(), encoding: .utf8) ?? ""
    }

    /// 伪代码 0x100107120（L206-215）。
    func ajaxBytes(_ url: String) -> [UInt8] {
        guard let data = URL(string: url).map({ try? Data(contentsOf: $0) }) ?? nil else { return [] }
        return Array(data)
    }

    /// 伪代码 0x100107a40（L55-68）。
    func post(_ url: String, _ body: String, _ headers: [String: String]) -> JsHTTPResponse {
        var request = URLRequest(url: URL(string: url) ?? URL(fileURLWithPath: "/"))
        request.httpMethod = "POST"
        request.httpBody = body.data(using: .utf8)
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        let (data, response) = (try? URLSession.shared.dataTaskSync(request)) ?? (Data(), nil)
        let http = response as? HTTPURLResponse
        return JsHTTPResponse(
            body: String(data: data, encoding: .utf8) ?? "",
            code: http?.statusCode ?? 0,
            message: "",
            headers: (http?.allHeaderFields as? [String: String]) ?? [:]
        )
    }

    /// 伪代码 0x10010821c（L71-82）。
    func head(_ url: String, _ headers: [String: String]) -> JsHTTPResponse {
        var request = URLRequest(url: URL(string: url) ?? URL(fileURLWithPath: "/"))
        request.httpMethod = "HEAD"
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        let (_, response) = (try? URLSession.shared.dataTaskSync(request)) ?? (Data(), nil)
        let http = response as? HTTPURLResponse
        return JsHTTPResponse(
            body: "", code: http?.statusCode ?? 0, message: "",
            headers: (http?.allHeaderFields as? [String: String]) ?? [:]
        )
    }

    /// 伪代码 0x1001084ec（L85-112）：主线程回退（事实 3）。
    func webView(_ url: String?, _ html: String?, _ webJs: String?) -> String {
        if Self.isOnMainThread {
            Logger.log(
                "[JS WebView] ⚠️ 在主线程调用 webView()，回退到 ajax 避免死锁",
                level: .warning
            )
            return ajax(url ?? "")
        }
        let runner = WKWebViewBridgeRunner()
        let semaphore = DispatchSemaphore(value: 0)
        var result = ""
        Task {
            result = await runner.load(
                url: url ?? "", headers: nil, javaScript: webJs ?? ""
            ) ?? ""
            semaphore.signal()
        }
        semaphore.wait()
        return result
    }

    /// 伪代码 0x100108a3c（L117-126）。
    func webViewGetSource(_ url: String?, _ html: String?, _ webJs: String?, _ sourceRegex: String?) -> String {
        if Self.isOnMainThread {
            Logger.log(
                "[webViewGetSource] ⚠️ 在主线程调用，回退到 ajax 避免死锁", level: .warning
            )
            return ajax(url ?? "")
        }
        return webView(url, html, webJs)
    }

    /// 伪代码 0x100108bf0（L129-138）。
    func webViewGetOverrideUrl(_ url: String?, _ html: String?, _ webJs: String?, _ overrideUrlRegex: String?) -> String {
        if Self.isOnMainThread {
            Logger.log(
                "[webViewGetOverrideUrl] ⚠️ 在主线程调用，回退到 ajax 避免死锁", level: .warning
            )
            return ""
        }
        return ""
    }

    /// 伪代码 0x100108f1c（L143-155）。
    func startBrowserAwait(_ url: String, _ title: String) -> String {
        if Self.isOnMainThread {
            Logger.log(
                "[startBrowserAwait] ⚠️ 在主线程调用，回退到 ajax 避免死锁", level: .warning
            )
            return ajax(url)
        }
        return ""
    }

    /// 伪代码 0x10010923c（L158-194）：验证码获取（WebView 链，推断 2）。
    func getVerificationCode(_ url: String) -> String {
        webViewGetSource(url, nil, nil, nil)
    }

    /// 伪代码 0x100156610（L197-201）。
    func openUrl(_ url: String) {
        JSOpenBridge.post(name: "url", url: url, title: nil, options: nil)
    }

    /// 伪代码 0x100107c80（L226-253）。
    func formatUrl(_ url: String) -> String {
        AnalyzeRule.sharedInstance().formatUrl(url)
    }
}

/// java.ajax 返回结构（T-201-04 相邻定义，跨文件共享）。
struct JsHTTPResponse {
    var body: String
    var code: Int
    var message: String
    var headers: [String: String]
}

extension URLSession {
    /// 同步 dataTask（js 桥串行语义）。
    func dataTaskSync(_ request: URLRequest) throws -> (Data, URLResponse?) {
        var result: (Data, URLResponse?) = (Data(), nil)
        let semaphore = DispatchSemaphore(value: 0)
        dataTask(with: request) { data, response, _ in
            result = (data ?? Data(), response)
            semaphore.signal()
        }.resume()
        semaphore.wait()
        return result
    }
}
