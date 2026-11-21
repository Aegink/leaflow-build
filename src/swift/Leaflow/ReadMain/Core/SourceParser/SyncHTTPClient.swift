// 原路径: ReadMain/Core/SourceParser/SyncHTTPClient.swift
// 证据:
//   - PGO: execute(request:policy:) (0x10016d4fc L39-78) / executeForBytes (0x10016de70 L99-110) / executeResult (0x10016cfc8 L131-156) / makeRequest (0x10016d1e4 L167-187)
//   - CovMap: 上述 L 区段
//   - IDA: 上述地址
//   - 选择子 statusCode/localizedStringForStatusCode:/allHeaderFields
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: medium-high（同步执行链确证；policy 见读后记推断 1）
// 还原: 2026-11-19


import Foundation

/// 同步 HTTP 客户端（java 桥的串行执行体）。
enum SyncHTTPClient {

    enum RequestPolicy {
        case useCache
        case reloadIgnoringCache
    }

    struct HTTPResult {
        var body: Data
        var code: Int
        var message: String
        var headers: [String: String]
    }

    /// 伪代码 0x10016d1e4（L167-187）。
    static func makeRequest(
        url: URL, method: String, headers: [String: String], body: Data?, timeout: Double
    ) -> URLRequest {
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = method.uppercased()
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.httpBody = body
        return request
    }

    /// 伪代码 0x10016d4fc（L39-78）。
    static func execute(request: URLRequest, policy: RequestPolicy) -> HTTPResult {
        var adjusted = request
        if policy == .reloadIgnoringCache {
            adjusted.cachePolicy = .reloadIgnoringLocalCacheData
        }
        let semaphore = DispatchSemaphore(value: 0)
        var result = HTTPResult(body: Data(), code: 0, message: "", headers: [:])
        let task = URLSession.shared.dataTask(with: adjusted) { data, response, error in
            let http = response as? HTTPURLResponse
            result = HTTPResult(
                body: data ?? Data(),
                code: http?.statusCode ?? 0,
                message: http.map { HTTPURLResponse.localizedString(forStatusCode: $0.statusCode) } ?? "",
                headers: (http?.allHeaderFields as? [String: String]) ?? [:]
            )
            semaphore.signal()
        }
        task.resume()
        semaphore.wait()
        return result
    }

    /// 伪代码 0x10016de70（L99-110）。
    static func executeForBytes(request: URLRequest, timeout: Double) -> [UInt8] {
        var adjusted = request
        adjusted.timeoutInterval = timeout
        let result = execute(request: adjusted, policy: .useCache)
        return Array(result.body)
    }

    /// 伪代码 0x10016cfc8（L131-156）。
    static func executeResult(request: URLRequest, sessionType: Int) -> HTTPResult {
        execute(request: request, policy: .useCache)
    }
}
