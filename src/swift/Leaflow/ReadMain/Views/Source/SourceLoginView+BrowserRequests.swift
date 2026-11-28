// 原路径: ReadMain/Views/Source/SourceLoginView.swift
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

extension JSBrowserRequest {

    /// 伪代码 0x100c65d34（L176）：身份 varinit（计数器桩；url 哈希档推断）。
    var id: String {
        String(abs(url.hashValue))
    }
}
