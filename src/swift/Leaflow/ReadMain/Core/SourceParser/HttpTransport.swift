// 原路径: ReadMain/Core/SourceParser/HttpTransport.swift
// 证据:
//   - PGO: HttpRequestRouting.setProxy (0x1000bb90c L8-10) / proxy(from:) (0x1000e25e8 L12-14) / removeProperties (0x1000e2b88 L24-29) / setProperty (0x1000e2524 L31-35) 等 25 函数
//   - CovMap: 上述 L 区段
//   - IDA: 上述地址
//   - 键 qireader.legado.dns-ip；会话配置选择子族（T-203-02 同构）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: medium-high
// 还原: 2026-11-19


import Foundation

/// HTTP 请求路由（proxy/DNS 覆盖的 URLRequest 附属属性）。
enum HttpRequestRouting {

    private static var proxyStore: [String: String] = [:]
    private static let lock = NSLock()

    /// 伪代码 0x1000bb90c（L8-10）。
    static func setProxy(_ proxy: String, forKey key: String) {
        lock.lock()
        defer { lock.unlock() }
        proxyStore[ObjectIdentifier(request)] = proxy
    }

    /// 伪代码 0x1000e25e8（L12-14）。
    static func proxy(from request: URLRequest) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return proxyStore[ObjectIdentifier(request)]
    }

    /// 伪代码 0x1000e2524（L31-35）。
    static func setProperty(_ value: Any, forKey key: String, on request: inout URLRequest) {
        objc_setAssociatedObject(request, key, value, .OBJC_ASSOCIATION_RETAIN)
    }

    /// 伪代码 0x1000e2b88（L24-29）。
    static func removeProperties(from request: inout URLRequest) {
        objc_removeAssociatedObjects(request)
    }

    /// DNS 覆盖键（事实 2）。
    static let dnsIPKey = "qireader.legado.dns-ip"
}

/// URLSession 传输器（init 0x1000816e4 L94-97 / clearRoutedSessions
/// 0x1000e246c L99-112 / syncBridgeData 0x1000e4294 L149-190 域）。
final class URLSessionTransport {

    private let session: URLSession
    private var routedSessions: [ObjectIdentifier: URLSession] = [:]

    /// 伪代码 0x1000816e4（L94-97）：会话构造。
    init(configuration: URLSessionConfiguration = .default) {
        self.session = URLSession(configuration: configuration)
    }

    /// 伪代码 0x1000e246c（L99-112）：路由会话清理。
    func clearRoutedSessions() {
        for (_, routed) in routedSessions {
            routed.invalidateAndCancel()
        }
        routedSessions.removeAll()
    }

    /// 伪代码 0x1000e4294（L149-190）：桥数据同步——cookie/头域同步链。
    func syncBridgeData(
        from request: URLRequest, into target: URLRequest
    ) -> URLRequest {
        var synced = target
        if let cookies = HTTPCookie.cookies(
            withResponseHeaderFields:
                request.allHTTPHeaderFields ?? [:],
            for: request.url ?? URL(string: "https://localhost")!) {
            let existing = HTTPCookieStorage.shared.cookies(
                for: synced.url ?? URL(string: "https://localhost")!) ?? []
            for cookie in cookies {
                HTTPCookieStorage.shared.deleteCookie(cookie)
            }
            for cookie in cookies {
                HTTPCookieStorage.shared.setCookie(cookie)
            }
        }
        if let accept = request.value(forHTTPHeaderField: "Accept") {
            synced.setValue(accept, forHTTPHeaderField: "Accept")
        }
        if let referer = request.value(forHTTPHeaderField: "Referer") {
            synced.setValue(referer, forHTTPHeaderField: "Referer")
        }
        return synced
    }
}

