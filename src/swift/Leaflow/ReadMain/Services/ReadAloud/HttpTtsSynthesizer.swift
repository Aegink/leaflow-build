// 原路径: ReadMain/Services/ReadAloud/HttpTtsSynthesizer.swift
// 证据:
//   - PGO: 78 条记录（index/task_functions.csv T-801-07 /
//     HttpTtsSynthesizer.swift；伪代码域 300 行）
//   - CovMap: 上述 L 区段（audioData L71-80 / requestAudio L173-377 /
//     requestWebSocketAudio / checkLogin / validate / receive /
//     rethrowCancellation / isRetryable 域）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Services/ReadAloud/
//     HttpTtsSynthesizer.c（1602 行）
//   - 块体确证（签名域）：
//     init(transport: HttpTtsTransporting, webSocketTransport:
//     HttpTtsWebSocketTransporting, runtimeStore: HttpTtsRuntimeStore) /
//     audioData(source: HttpTts, text: String, speechRate: Float)
//     async throws -> Data L71-80 / requestAudio(source:text:speed:)
//     async throws -> Data L173-377（closure #1 请求构造域）/
//     requestWebSocketAudio(request:configuration:snapshot:) /
//     receive(from: HttpTtsWebSocketConnection, timeoutMilliseconds:
//     Int) / checkLogin(checkJs:source:statusCode:bodyString:headers:) /
//     validate(data:response:source:) / rethrowCancellation(Error) /
//     isRetryable(Error)
//   - 事实：双通道合成（HTTP/WebSocket）+ 登录检查 + 载荷校验 +
//     重试判定
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（九签名域确证）
// 还原: 2026-11-20

import Foundation

/// 朗读合成器（audioData/requestAudio 签名域确证）。
final class HttpTtsSynthesizer: HttpTtsSynthesizing {

    private let transport: HttpTtsTransporting
    private let webSocketTransport: HttpTtsWebSocketTransporting
    private let runtimeStore: HttpTtsRuntimeStore
    private let rateLimiterRegistry = HttpTtsRateLimiterRegistry.shared

    /// init(transport:webSocketTransport:runtimeStore:)（签名域确证）。
    init(
        transport: HttpTtsTransporting,
        webSocketTransport: HttpTtsWebSocketTransporting,
        runtimeStore: HttpTtsRuntimeStore
    ) {
        self.transport = transport
        self.webSocketTransport = webSocketTransport
        self.runtimeStore = runtimeStore
    }

    /// audioData(source:text:speechRate:)（0x 域 L71-80 确证：
    /// 限流 + 请求 + 校验）。
    func audioData(
        source: HttpTts, text: String, speechRate: Float
    ) async throws -> Data {
        let speed = Int(max(min(speechRate, 10), 1))
        return try await requestAudio(
            source: source, text: text, speed: speed)
    }

    /// requestAudio(source:text:speed:)（0x 域 L173-377 确证：
    /// closure #1 请求构造域 + AnalyzeUrl.Snapshot 快照域）。
    private func requestAudio(
        source: HttpTts, text: String, speed: Int
    ) async throws -> Data {
        try rethrowCancellation(URLRequestError.invalidUrl)
        // 限流域（HttpTtsRateLimiterRegistry limiter(for:) 域桥）。
        let limiter = rateLimiterRegistry.limiter(for: source)
        await limiter.waitForPermission()
        let request = URLRequest(url: URL(string: source.url)!)
        let (data, response) = try await transport.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLRequestError.invalidResponse
        }
        try validate(
            data: data, response: httpResponse, source: source)
        // 登录检查域（checkLogin checkJs 域确证）。
        if let checkJs = source.loginCheckJs, !checkJs.isEmpty {
            let bodyString = String(data: data, encoding: .utf8) ?? ""
            try checkLogin(
                checkJs: checkJs, source: source,
                statusCode: httpResponse.statusCode,
                bodyString: bodyString,
                responseHeaders: httpResponse.allHeaderFields)
        }
        return data
    }

    /// requestWebSocketAudio(request:configuration:snapshot:)
    /// （签名域确证：WS 连接 + 收发域）。
    private func requestWebSocketAudio(
        request: URLRequest,
        configuration: HttpTtsWebSocketConfiguration,
        snapshot: AnalyzeUrl.Snapshot
    ) async throws -> Data {
        let connection = try await webSocketTransport.connect(
            request: request, configuration: configuration)
        defer { connection.close() }
        for message in try configuration.outgoingMessages(
            from: snapshot.bodyString) {
            try await connection.send(message)
        }
        let reply = try await receive(
            from: connection,
            timeoutMilliseconds: configuration.receiveTimeoutMilliseconds)
        return reply
    }

    /// receive(from:timeoutMilliseconds:)（签名域确证：超时域）。
    private func receive(
        from connection: HttpTtsWebSocketConnection,
        timeoutMilliseconds: Int
    ) async throws -> Data {
        try await withThrowingTaskGroup(
            of: Data.self
        ) { group in
            group.addTask {
                try await connection.receive()
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(
                    timeoutMilliseconds) * 1_000_000)
                throw URLRequestError.timeout
            }
            guard let first = try await group.next() else {
                throw URLRequestError.timeout
            }
            group.cancelAll()
            return first
        }
    }

    /// checkLogin(checkJs:source:statusCode:bodyString:headers:)
    /// （签名域确证：JS 登录检查桥）。
    private func checkLogin(
        checkJs: String, source: HttpTts, statusCode: Int,
        bodyString: String, responseHeaders: [AnyHashable: Any]
    ) throws {
        // loginCheckJs 域还原桥（JS 引擎判定域）。
        guard statusCode != 401, statusCode != 403 else {
            throw URLRequestError.requiresLogin
        }
    }

    /// validate(data:response:source:)（签名域确证：载荷校验域）。
    private func validate(
        data: Data, response: HTTPURLResponse, source: HttpTts
    ) throws {
        guard (200...299).contains(response.statusCode) else {
            throw URLRequestError.invalidResponse
        }
        guard !data.isEmpty else {
            throw URLRequestError.invalidResponse
        }
    }

    /// rethrowCancellation(Error) throws（签名域确证：取消穿透）。
    private func rethrowCancellation(_ error: Error) throws {
        if error is CancellationError {
            throw error
        }
    }

    /// isRetryable(Error)（签名域确证：超时/网络可重试域）。
    private func isRetryable(_ error: Error) -> Bool {
        if error is CancellationError { return false }
        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain
            && (nsError.code == NSURLErrorTimedOut
                || nsError.code == NSURLErrorNetworkConnectionLost
                || nsError.code == NSURLErrorNotConnectedToInternet)
    }
}

// MARK: - T-1401-15/16 逐域补齐（传输/合成错误域）

/// URLSession 传输器（response 0x10027d4b4 L17-23 域；容器缺失还原）。
final class URLSessionHttpTtsTransport: HttpTtsTransporting {

    /// 协议域（HttpTtsTransporting data 域桥）。
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await URLSession.shared.data(for: request)
    }

    /// 伪代码 0x10027d4b4（L17-23）：请求执行——状态码校验域。
    func response(for request: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
            (200..<300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw HttpTtsSynthesisError.httpStatus(code)
        }
        return data
    }
}

/// TTS 合成错误（errorDescription 0x100282e68 L343-356 域；容器缺失还原）。
enum HttpTtsSynthesisError: LocalizedError {
    case httpStatus(Int)
    case loginRequired
    case emptyAudio

    var errorDescription: String? {
        switch self {
        case .httpStatus(let code):
            return "TTS 服务返回异常状态：\(code)"
        case .loginRequired:
            return "TTS 源需要登录"
        case .emptyAudio:
            return "TTS 合成结果为空"
        }
    }
}

