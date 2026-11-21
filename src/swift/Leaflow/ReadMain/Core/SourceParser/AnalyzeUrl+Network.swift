// 原路径: ReadMain/Core/SourceParser/AnalyzeUrl+Network.swift
// 证据:
//   - PGO: WebViewGate(init/maxConcurrent/gate/withPermit) / WKWebViewBridgeRunner(load/loadHTML/
//     sourceURL) / getHttpResponse(LL) / syncJavaBridgeResponse(LL) / needsWebViewFallback(LL) /
//     getStrResponse(skipWebView:) / decodeResponseData(LL)
//   - CovMap: WebViewGate.init L21 @0x100c63b24；maxConcurrent L24 @0x1000ac6bc；gate L25
//     @0x1000ac514；withPermit L27-38（10 个 ICF 副本 0x100042bd0…0x1000b8d98）；
//     load L62-65（3 副本）；loadHTML L67-70（3 副本）；sourceURL L72-87（3 副本 + closures）；
//     getStrResponse L354-416 @0x1000ae5f4；needsWebViewFallback L484-556 @0x1000b2f64；
//     syncJavaBridgeResponse L263-335 @0x1000aaa1c；getHttpResponse L587-671 @0x1000b0218；
//     decodeResponseData L697-750 @0x1000af840
//   - IDA: 上述地址的 Hex-Rays 伪代码 + 字符串常量表
//   - Cloudflare 特征：Just a moment / Please Wait... / __cf_bm / var nonce / var cpk /
//     ge_ua_p / ui-uam-box
//   - 编码判定串：charset= / content-type / Windows-1252 / content= / sourceRegex:
//   - 选择子：statusCode/localizedStringForStatusCode:/allHeaderFields/
//     cookiesWithResponseHeaderFields:forURL:/valueForHTTPHeaderField:/isMainThread
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - decodeResponseData/getHttpResponse: medium-high（特征串与选择子确证，顺序未逐行）
//   - WebViewGate/WKWebViewBridgeRunner: medium-high（闸门语义推断 2）
//   - syncJavaBridgeResponse: medium（sessionType 枚举未展开，见“仍不清楚”2）
// 还原: 2026-11-19

import Foundation
import WebKit

/// WebView 并发闸门（事实 13）。
final class WebViewGate {
    static let shared = WebViewGate()

    /// 伪代码 L24：并发上限。
    let maxConcurrent: Int

    private let semaphore: DispatchSemaphore

    init(maxConcurrent: Int = 4) {
        self.maxConcurrent = maxConcurrent
        self.semaphore = DispatchSemaphore(value: maxConcurrent)
    }

    /// 伪代码 L27-38：进入 WebView 前取闸门，退出释放（async 调用点 10 处）。
    func withPermit<T>(_ body: () async throws -> T) async rethrows -> T {
        semaphore.wait()
        defer { semaphore.signal() }
        return try await body()
    }
}

/// WKWebView 桥接执行器（事实 14）。
final class WKWebViewBridgeRunner {
    /// 伪代码 L62-65：加载 URL 并等待桥接。
    func load(url: String, headers: [String: String]?, javaScript: String) async -> String? {
        await WebViewGate.shared.withPermit {
            WebViewRuntime.load(url: url, headers: headers, javaScript: javaScript)
        }
    }

    /// 伪代码 L67-70：加载 HTML 片段。
    func loadHTML(url: String, html: String, webJs: String) async -> String? {
        await WebViewGate.shared.withPermit {
            WebViewRuntime.loadHTML(url: url, html: html, webJs: webJs)
        }
    }

    /// 伪代码 L72-87：从 WebView 结果中提取最终源码。
    func sourceURL(html: String?, url: String, javaScript: String) async -> String? {
        await WebViewGate.shared.withPermit {
            WebViewRuntime.sourceURL(html: html, url: url, javaScript: javaScript)
        }
    }
}

extension AnalyzeUrl {

    // MARK: - 响应解码

    /// 伪代码 0x1000af840（L697-750）：响应体解码（事实 15）。
    /// charset= → content-type → Windows-1252 → 默认 utf8（顺序见推断 4）。
    static func decodeResponseData(_ data: Data, contentType: String?) -> String {
        if let contentType, let range = contentType.range(of: "charset=") {
            let charset = String(contentType[range.upperBound...])
                .trimmingCharacters(in: .whitespaces)
                .lowercased()
            if charset.contains("gbk") || charset.contains("gb2312") {
                let encoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(
                    CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
                ))
                if let text = String(data: data, encoding: encoding) {
                    return text
                }
            } else if charset.contains("windows-1252") || charset.contains("iso-8859") {
                if let text = String(data: data, encoding: .isoLatin1) {
                    return text
                }
            }
        }
        if let text = String(data: data, encoding: .utf8) {
            return text
        }
        return String(decoding: data, as: UTF8.self)
    }

    /// 伪代码 0x1000b2f64（L484-556）：WebView 降级判定（Cloudflare 特征 + sourceRegex）。
    static func needsWebViewFallback(_ body: String, sourceRegex: String?) -> Bool {
        let cloudflareMarkers = [
            "Just a moment", "Please Wait...", "__cf_bm",
            "var nonce", "var cpk", "ge_ua_p", "ui-uam-box",
        ]
        for marker in cloudflareMarkers where body.contains(marker) {
            return true
        }
        if let sourceRegex, !sourceRegex.isEmpty,
           let regex = try? NSRegularExpression(pattern: sourceRegex) {
            let range = NSRange(body.startIndex..<body.endIndex, in: body)
            if regex.firstMatch(in: body, options: [], range: range) != nil {
                return true
            }
        }
        return false
    }

    // MARK: - HTTP 响应

    /// 伪代码 0x1000b0218（L587-671）：HTTP 响应归一。
    static func getHttpResponse(_ response: URLResponse?, data: Data, error: Error?) -> StrResponse {
        guard let http = response as? HTTPURLResponse else {
            return StrResponse(
                body: "", code: 0, message: error?.localizedDescription ?? "no response",
                headers: [:]
            )
        }
        let message = HTTPURLResponse.localizedString(
            forStatusCode: http.statusCode
        )
        let headers = (http.allHeaderFields as? [String: String]) ?? [:]
        let body = decodeResponseData(data, contentType: headers["content-type"] ?? headers["Content-Type"])
        return StrResponse(
            body: body,
            code: http.statusCode,
            message: message,
            headers: headers
        )
    }

    /// 伪代码 0x1000aaa1c（L263-335）：java 桥同步响应（sessionType 见读后记“仍不清楚”2）。
    func syncJavaBridgeResponse(sessionType: Int) -> StrResponse? {
        guard let session = Self.ephemeralSession() else { return nil }
        guard let request = buildRequest() else { return nil }
        let semaphore = DispatchSemaphore(value: 0)
        var result: StrResponse?
        let task = session.dataTask(with: request) { data, response, error in
            result = Self.getHttpResponse(response, data: data ?? Data(), error: error)
            semaphore.signal()
        }
        task.resume()
        _ = semaphore.wait(timeout: .now() + Self.userTimeout + 5)
        return result
    }

    /// 伪代码 0x1000ae5f4（L354-416）：字符串响应主入口（async throws）。
    func getStrResponse(skipWebView: Bool) async throws -> StrResponse {
        let response = syncJavaBridgeResponse(sessionType: 0)
        if let response, !Self.needsWebViewFallback(response.body, sourceRegex: nil) {
            return response
        }
        guard !skipWebView else {
            return response ?? StrResponse(body: "", code: 0, message: "", headers: [:])
        }
        // WebView 降级路径。
        let runner = WKWebViewBridgeRunner()
        let body = await runner.load(url: url, headers: headers, javaScript: "")
        return StrResponse(
            body: body ?? "",
            code: 200,
            message: "webview",
            headers: headers
        )
    }
}

// MARK: - 响应结构

/// 字符串响应（AnalyzeUrl 域）。
struct StrResponse {
    var body: String
    var code: Int
    var message: String
    var headers: [String: String]
}

// MARK: - 静态支撑

extension AnalyzeUrl {

    /// 伪代码 L290-325：ephemeral session 配置
    /// （setTimeoutIntervalForRequest/ForResource/HTTPMaximumConnectionsPerHost/
    /// WaitsForConnectivity/URLCache/RequestCachePolicy/HTTPShouldSetCookies/
    /// HTTPCookieAcceptPolicy/HTTPCookieStorage）。
    private static var cachedSession: URLSession?

    static func ephemeralSession() -> URLSession? {
        if let cachedSession {
            return cachedSession
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = userTimeout
        configuration.timeoutIntervalForResource = userTimeout * 3
        configuration.httpMaximumConnectionsPerHost = 8
        configuration.waitsForConnectivity = false
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpCookieStorage = nil
        let session = URLSession(configuration: configuration)
        cachedSession = session
        return session
    }
}

// MARK: - T-1401-12 逐域补齐（Set-Cookie 域）

extension AnalyzeUrl {

    /// 伪代码 0x1000abf1c（L678-693）：Set-Cookie 头持久化——响应头逐条
    /// HTTPCookieStorage 域。
    func saveSetCookieHeaders(from response: HTTPURLResponse) {
        guard let fields = response.allHeaderFields as? [String: String],
            let url = response.url else { return }
        let cookies = HTTPCookie.cookies(
            withResponseHeaderFields: fields, for: url)
        for cookie in cookies {
            HTTPCookieStorage.shared.setCookie(cookie)
        }
        Logger.log(
            "[cookie] saved \(cookies.count) from \(url.host ?? "-")",
            level: 7)
    }

    /// 伪代码 0x1000ab960（L844-872）：响应数据解码——gzip/deflate/br 三态
    /// + 字符集域（head 阶段记录的 charset 消费）。
    func decodeHttpData(_ data: Data, charset: String?) -> String {
        let encoding = charset.flatMap {
            String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(
                CFStringConvertIANACharSetNameToEncoding($0 as CFString)))
        } ?? .utf8
        if data.starts(with: [0x1F, 0x8B]) {
            let decompressed = (try? (data as NSData).decompressed(
                using: .zlib)) as Data?
            if let decoded = decompressed.flatMap({
                String(data: $0, encoding: encoding)
            }) ?? String(data: data, encoding: encoding) {
                return decoded
            }
        }
        return String(data: data, encoding: encoding)
            ?? String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1)
            ?? ""
    }
}

