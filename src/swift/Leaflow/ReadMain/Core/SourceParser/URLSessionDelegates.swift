// 原路径: ReadMain/Core/SourceParser/URLSessionDelegates.swift
// 证据:
//   - PGO: LegadoCookieJarTaskRegistry.unregister/contains (0x1000e7624/0x10016fe48 L12-18) / Set closure (0x100156690) 等 25 函数
//   - CovMap: 上述 L 区段
//   - IDA: 上述地址
//   - 选择子 protectionSpace/authenticationMethod/serverTrust/initWithTrust:
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: medium-high（TLS/cookie 注册链确证；校验策略见读后记仍不清楚 1）
// 还原: 2026-11-19


import Foundation

/// Legado cookie jar 任务注册表（推断 2）。
enum LegadoCookieJarTaskRegistry {

    private static var activeTasks: Set<ObjectIdentifier> = []
    private static let lock = NSLock()

    /// 伪代码 0x1000e7624（L12-14）。
    static func unregister(_ task: URLSessionTask) {
        lock.lock()
        defer { lock.unlock() }
        activeTasks.remove(ObjectIdentifier(task))
    }

    /// 伪代码 0x10016fe48（L16-18）。
    static func contains(_ task: URLSessionTask) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return activeTasks.contains(ObjectIdentifier(task))
    }

    static func register(_ task: URLSessionTask) {
        lock.lock()
        defer { lock.unlock() }
        activeTasks.insert(ObjectIdentifier(task))
    }
}

/// 会话代理（TLS + cookie）。
final class URLSessionDelegates: NSObject, URLSessionDataDelegate, URLSessionTaskDelegate {

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge
    ) -> URLSession.AuthChallengeDisposition {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
            let trust = challenge.protectionSpace.serverTrust
        else {
            return .performDefaultHandling
        }
        let credential = URLCredential(trust: trust)
        return .useCredential(credential)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        LegadoCookieJarTaskRegistry.unregister(task)
    }
}

// MARK: - T-1401-12 逐域补齐（响应载体域）

/// Java 响应载体（description 0x10016ee9c / statusCode 0x10016ef9c /
/// statusMessage 0x10016f028 / headers 0x10016f098 / url 0x1000ec394 /
/// toString 0x10016f230 / raw 0x10016f2e8 域）。
final class JavaResponse {

    let data: Data
    let response: URLResponse?
    let request: URLRequest?

    init(data: Data, response: URLResponse?, request: URLRequest? = nil) {
        self.data = data
        self.response = response
        self.request = request
    }

    /// 伪代码 0x10016ef9c（L163）：状态码。
    func statusCode() -> Int {
        (response as? HTTPURLResponse)?.statusCode ?? 0
    }

    /// 伪代码 0x10016f028（L164）：状态文案。
    func statusMessage() -> String {
        let code = statusCode()
        guard code != 0 else { return "Unknown" }
        return HTTPURLResponse.localizedString(
            forStatusCode: code)
    }

    /// 伪代码 0x10016f098（L165）：响应头域。
    func headers() -> [String: String] {
        (response as? HTTPURLResponse)?.allHeaderFields
            .reduce(into: [:]) { result, pair in
                result["\(pair.key)"] = "\(pair.value)"
            } ?? [:]
    }

    /// 伪代码 0x1000ec394（L166）：请求 URL。
    func url() -> String {
        request?.url?.absoluteString
            ?? (response as? HTTPURLResponse)?.url?.absoluteString
            ?? ""
    }

    /// 伪代码 0x10016f230（L167-169）：调试串（code + 长度域）。
    func toString() -> String {
        "JavaResponse(code=\(statusCode()), bytes=\(data.count))"
    }

    /// 伪代码 0x10016f2e8（L173-175）：原始体域。
    func raw() -> Data {
        data
    }
}

extension JavaResponse: CustomStringConvertible {

    /// 伪代码 0x10016ee9c（L141）：description getter。
    var description: String {
        toString()
    }
}

/// Java 原始响应（init 0x10016f3a0 L197-203 / request 0x10016f3e0 /
/// code 0x10016f400 / toString 0x10016f87c / description 0x10016f8d4 域）。
final class JavaRawResponse {

    let data: Data
    let response: URLResponse?
    let sourceRequest: URLRequest?

    /// 伪代码 0x10016f3a0（L197-203）：三参构造域。
    init(data: Data, response: URLResponse?, request: URLRequest?) {
        self.data = data
        self.response = response
        self.sourceRequest = request
    }

    /// 伪代码 0x10016f3e0（L205-207）：请求描述域。
    func request() -> URLRequest? {
        sourceRequest
    }

    /// 伪代码 0x10016f400（L209）：状态码。
    func code() -> Int {
        (response as? HTTPURLResponse)?.statusCode ?? 0
    }

    /// 伪代码 0x10016f87c（L220-222）：调试串。
    func toString() -> String {
        "JavaRawResponse(code=\(code()), bytes=\(data.count))"
    }
}

extension JavaRawResponse: CustomStringConvertible {

    /// 伪代码 0x10016f8d4（L224）：description getter。
    var description: String {
        toString()
    }
}

/// Java 原始请求（init 0x10016f8ec L237-240 / url 0x10016f90c 域）。
final class JavaRawRequest {

    let url: URL
    let method: String
    let headers: [String: String]
    let body: Data?

    /// 伪代码 0x10016f8ec（L237-240）：四参构造域。
    init(url: URL, method: String, headers: [String: String], body: Data?) {
        self.url = url
        self.method = method
        self.headers = headers
        self.body = body
    }

    /// 伪代码 0x10016f90c（L242）：URL 域。
    func url() -> String {
        url.absoluteString
    }
}

// MARK: - T-1401-12 逐域补齐（TLS 域）

extension URLSessionDelegates {

    /// 伪代码 0x10016e060（L26-37）：信任所有服务器质询（诊断串域确证；
    /// kSecTrustResultProceed 桥）。
    func handleTrustAllServerTrustChallenge(
        _ challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod
            == NSURLAuthenticationMethodServerTrust,
            let trust = challenge.protectionSpace.serverTrust
        else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        Logger.log(
            "[tls] trust-all host=\(challenge.protectionSpace.host)",
            level: .warning, module: .network)
        completionHandler(.useCredential, URLCredential(trust: trust))
    }
}

