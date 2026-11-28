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
    let messages: [HttpTtsWebSocketOutgoingMessage]
    let onMessageScript: String
    let connectTimeoutMilliseconds: Int
    let maximumAudioBytes: Int
    let audioContentType: String

    /// init(url:headers:)（签名域确证）。
    init(
        url: URL, headers: [String: String],
        bodyTemplate: String, receiveTimeoutMilliseconds: Int = 10_000
    ) {
        self.url = url
        self.headers = headers
        self.bodyTemplate = bodyTemplate
        self.receiveTimeoutMilliseconds = receiveTimeoutMilliseconds
        messages = [.text(bodyTemplate)]
        onMessageScript = "({audio: message.base64(0, message.length), done: true})"
        connectTimeoutMilliseconds = 12_000
        maximumAudioBytes = 16 * 1024 * 1024
        audioContentType = "audio/mpeg"
    }

    /// init(javaScriptValue:)（签名域确证：requiredString/positiveInt/
    /// optionalString/stringMap 提取链）。
    init(javaScriptValue fields: [String: Any]) throws {
        let urlString = try Self.requiredString("url", in: fields)
        guard let parsed = URL(string: urlString), ["ws", "wss"].contains(parsed.scheme?.lowercased() ?? ""),
              parsed.host?.isEmpty == false else { throw HttpTtsWebSocketError.invalidURL }
        url = parsed
        headers = (fields["headers"] as? [String: String]) ?? [:]
        bodyTemplate = ""
        messages = try Self.decodeMessages(fields["send"])
        guard !messages.isEmpty else { throw HttpTtsWebSocketError.invalidConfiguration("send至少需要一条消息") }
        onMessageScript = try Self.requiredString("onMessage", in: fields)
        connectTimeoutMilliseconds = Self.positiveInt(fields["connectTimeout"], default: 12_000)
        receiveTimeoutMilliseconds = Self.positiveInt(fields["receiveTimeout"], default: 30_000)
        maximumAudioBytes = min(Self.positiveInt(fields["maxAudioBytes"], default: 16 * 1024 * 1024), 64 * 1024 * 1024)
        audioContentType = fields["contentType"] as? String ?? "audio/mpeg"
    }

    /// 0x1002862a4：函数回调序列化为(message, webSocketState)调用表达式。
    init(javaScriptValue value: JSValue) throws {
        guard value.isObject, !value.isNull, !value.isUndefined,
              var fields = value.toDictionary() as? [String: Any] else {
            throw HttpTtsWebSocketError.invalidConfiguration("java.webSocket参数必须是对象")
        }
        guard let handler = value.forProperty("onMessage"), !handler.isNull, !handler.isUndefined else {
            throw HttpTtsWebSocketError.invalidConfiguration("缺少onMessage处理器")
        }
        if handler.isString { fields["onMessage"] = handler.toString() }
        else {
            let context = value.context!
            let isFunction = context.evaluateScript("(function(value) { return typeof value === 'function'; })")
                ?.call(withArguments: [handler])?.toBool() == true
            guard isFunction, let script = handler.toString() else {
                throw HttpTtsWebSocketError.invalidConfiguration("onMessage必须是函数或表达式字符串")
            }
            fields["onMessage"] = "(" + script + ")(message, webSocketState)"
        }
        try self.init(javaScriptValue: fields)
    }

    static func decodeMessages(_ payload: Any?) throws -> [HttpTtsWebSocketOutgoingMessage] {
        guard let payload, !(payload is NSNull) else { return [] }
        let values = payload as? [Any] ?? [payload]
        return try values.map { value in
            if let text = value as? String { return .text(text) }
            guard let map = value as? [String: Any] else {
                throw HttpTtsWebSocketError.invalidMessage
            }
            let type = (map["type"] as? String ?? "text").lowercased()
            let data = map["data"] as? String ?? ""
            if type == "text" { return .text(data) }
            guard type == "binary", let decoded = decodeBase64(data) else {
                throw HttpTtsWebSocketError.invalidMessage
            }
            return .binary(decoded)
        }
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
        guard let value = fields[key] as? String, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw HttpTtsWebSocketError.invalidConfiguration("缺少\(key)")
        }
        return value
    }

    /// positiveInt(_:default:)（0x 域 L1445 确证）。
    private static func positiveInt(
        _ value: Any?, default fallback: Int
    ) -> Int {
        guard let number = value as? NSNumber, number.doubleValue.isFinite else { return fallback }
        return max(1, min(Int(Int32.max), number.intValue))
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
enum HttpTtsWebSocketOutgoingMessage: Equatable {
    case text(String)
    case binary(Data)
}

/// 帧域（Frame 签名还原桥）。
/// 消费端 evaluateTtsWebSocketMessage 需 _ws* 桥成员（byteAt/uint16BE/utf8/base64/
/// stateJSON/messageType/text/messageCount，AnalyzeUrl.swift 事实 8）；以下成员
/// 基于 data/isText 实实现，偏移/编码语义为还原推断（待 T-801 真机交叉核清）。
struct HttpTtsWebSocketFrame {
    let data: Data
    let isText: Bool

    /// 文本帧完整 UTF-8 内容（非文本帧为 nil）。
    var text: String? {
        guard isText else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// 帧类型（_wsMessageType 桥：text/binary）。
    var messageType: String {
        isText ? "text" : "binary"
    }

    /// 帧内消息计数（_wsMessageCount 桥：帧缓冲字节数）。
    var messageCount: Int {
        data.count
    }

    /// 帧状态 JSON（_wsStateJSON 桥）。
    var stateJSON: String {
        let type = isText ? "text" : "binary"
        return "{\"type\":\"\(type)\",\"length\":\(data.count)}"
    }

    /// 帧内偏移字节（_wsByteAt 桥；越界回 0）。
    func byteAt(_ index: Int) -> Int {
        guard index >= 0, index < data.count else { return 0 }
        return Int(data[data.startIndex + index])
    }

    /// 大端 16 位读取（_wsUInt16BE 桥；越界回 0）。
    func uint16BE(at offset: Int) -> Int {
        guard offset >= 0, offset < data.count - 1 else { return 0 }
        let high = byteAt(offset)
        let low = byteAt(offset + 1)
        return high << 8 | low
    }

    /// UTF-8 切片解码（_wsUtf8 桥；越界或解码失败为 nil）。
    func utf8(at offset: Int, count: Int) -> String? {
        guard let chunk = slice(offset: offset, count: count) else { return nil }
        return String(data: chunk, encoding: .utf8)
    }

    /// Base64 切片编码（_wsBase64 桥）。
    func base64(at offset: Int, count: Int) -> String? {
        guard let chunk = slice(offset: offset, count: count) else { return nil }
        return chunk.base64EncodedString()
    }

    /// 帧内切片（offset..offset+count，截断到帧尾）。
    private func slice(offset: Int, count: Int) -> Data? {
        guard offset >= 0, count >= 0, offset < data.count else { return nil }
        let end = offset + min(count, data.count - offset)
        guard end > offset else { return nil }
        return data.subdata(in: (data.startIndex + offset)..<(data.startIndex + end))
    }
}

/// 连接域（Connection/transporting 签名还原桥）。
protocol HttpTtsWebSocketConnection {
    func send(_ message: HttpTtsWebSocketOutgoingMessage) async throws
    func receive() async throws -> HttpTtsWebSocketFrame
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
    case invalidConfiguration(String)
    case invalidURL
    case scriptFailed(String)
    case sourceReported(String)
    case audioTooLarge(Int)
    case receiveTimeout
    case connectionClosedBeforeCompletion
    case noAudioReceived

    var errorDescription: String? {
        switch self {
        case .connectionFailed:
            return "朗读源 WebSocket 连接失败"
        case .invalidMessage:
            return "朗读源 WebSocket 消息无效"
        case .invalidConfiguration(let message): return "朗读源WebSocket配置无效：\(message)"
        case .invalidURL: return "WebSocket URL必须使用ws或wss"
        case .scriptFailed(let message): return "WebSocket消息脚本失败：\(message)"
        case .sourceReported(let message): return message
        case .audioTooLarge(let limit): return "WebSocket音频超过\(limit)字节限制"
        case .receiveTimeout: return "WebSocket接收超时"
        case .connectionClosedBeforeCompletion: return "WebSocket在完成前关闭"
        case .noAudioReceived: return "WebSocket没有返回音频"
        }
    }
}
