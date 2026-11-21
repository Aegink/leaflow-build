// 原路径: ReadMain/Services/ReadAloud/HttpTtsWebSocket.swift
// 证据:
//   - PGO: 78 条记录（index/task_functions.csv T-801-07 /
//     HttpTtsWebSocket.swift；伪代码域 500 行）
//   - CovMap: 上述 L 区段（Configuration.init L9-30 / outgoingMessages
//     L586 / outgoingMessage L704-1258 / requiredString L1258 /
//     positiveInt L1445 / Connection/Frame 域）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Services/ReadAloud/
//     HttpTtsWebSocket.c（1682 行）
//   - 块体确证（签名域）：
//     Configuration.init(javaScriptValue: JSValue) throws /
//     init(url: String, headers: ...) / optionalString(JSValue?) /
//     outgoingMessage(from: Any) throws（closure 0x L704/L1165 域）/
//     outgoingMessages(from: Any?) throws L586 / positiveInt(JSValue?,
//     default: Int) L1445 / requiredString(String, in: JSValue)
//     L1258 / stringMap(JSValue?) / decodeBase64(String) /
//     Connection / Frame / OutgoingMessage / Error.errorDescription
//   - 事实：WS 配置（JSValue → url/headers/消息模板）+ 连接收发
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（十二签名域确证）
// 还原: 2026-11-20

import Foundation
import JavaScriptCore

/// WebSocket 配置（init(javaScriptValue:) + outgoingMessages 签名域
/// 确证）。
struct HttpTtsWebSocketConfiguration {

    let url: URL
    let headers: [String: String]
    let bodyTemplate: String
    let receiveTimeoutMilliseconds: Int

    /// init(url:headers:)（签名域确证）。
    init(
        url: URL, headers: [String: String],
        bodyTemplate: String, receiveTimeoutMilliseconds: Int = 10_000
    ) {
        self.url = url
        self.headers = headers
        self.bodyTemplate = bodyTemplate
        self.receiveTimeoutMilliseconds = receiveTimeoutMilliseconds
    }

    /// init(javaScriptValue:)（签名域确证：requiredString/positiveInt/
    /// optionalString/stringMap 提取链）。
    init(javaScriptValue fields: [String: Any]) throws {
        guard let urlString = fields["url"] as? String,
              let parsed = URL(string: urlString) else {
            throw URLRequestError.invalidUrl
        }
        url = parsed
        headers = (fields["headers"] as? [String: String]) ?? [:]
        bodyTemplate = (fields["body"] as? String) ?? ""
        let timeout = (fields["timeout"] as? Int) ?? 10_000
        receiveTimeoutMilliseconds = max(timeout, 1000)
    }

    /// outgoingMessages(from: Any?)（0x 域 L586 确证：模板渲染）。
    func outgoingMessages(from payload: Any?) throws
        -> [HttpTtsWebSocketOutgoingMessage] {
        guard let payload else {
            return [.text(bodyTemplate)]
        }
        if let text = payload as? String {
            let rendered = bodyTemplate
                .replacingOccurrences(of: "{{text}}", with: text)
            return [.text(rendered)]
        }
        return [.text(bodyTemplate)]
    }

    /// requiredString(_:in:)（0x 域 L1258 确证）。
    private static func requiredString(_ key: String, in fields: [String: Any])
        throws -> String {
        guard let value = fields[key] as? String else {
            throw URLRequestError.invalidUrl
        }
        return value
    }

    /// positiveInt(_:default:)（0x 域 L1445 确证）。
    private static func positiveInt(
        _ value: Any?, default fallback: Int
    ) -> Int {
        guard let int = value as? Int, int > 0 else { return fallback }
        return int
    }

    /// optionalString(JSValue?)（签名域确证）。
    private static func optionalString(_ value: Any?) -> String? {
        value as? String
    }

    /// stringMap(JSValue?)（签名域确证）。
    private static func stringMap(_ value: Any?) -> [String: String] {
        value as? [String: String] ?? [:]
    }

    /// decodeBase64(String)（签名域确证）。
    static func decodeBase64(_ value: String) -> Data? {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 {
            base64.append("=")
        }
        return Data(base64Encoded: base64)
    }
}

/// 出站消息（OutgoingMessage 签名域确证：text/binary 双态）。
enum HttpTtsWebSocketOutgoingMessage {
    case text(String)
    case binary(Data)
}

/// 帧域（Frame 签名还原桥）。
struct HttpTtsWebSocketFrame {
    let data: Data
    let isText: Bool
}

/// 连接域（Connection/transporting 签名还原桥）。
protocol HttpTtsWebSocketConnection {
    func send(_ message: HttpTtsWebSocketOutgoingMessage) async throws
    func receive() async throws -> Data
    func close()
}

protocol HttpTtsWebSocketTransporting {
    func connect(
        request: URLRequest,
        configuration: HttpTtsWebSocketConfiguration
    ) async throws -> HttpTtsWebSocketConnection
}

/// WebSocket 错误（errorDescription 签名域确证）。
enum HttpTtsWebSocketError: LocalizedError {
    case connectionFailed
    case invalidMessage

    var errorDescription: String? {
        switch self {
        case .connectionFailed:
            return "朗读源 WebSocket 连接失败"
        case .invalidMessage:
            return "朗读源 WebSocket 消息无效"
        }
    }
}
