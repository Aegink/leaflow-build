// 原路径: ReadMain/Services/ReadAloud/HttpTtsWebSocket.swift。
// AnalyzeUrl 0x10008861c：message字节访问器、webSocketState及动作JSON解码。
import Foundation
import JavaScriptCore

struct HttpTtsWebSocketAction {
    let audio: Data?
    let messages: [HttpTtsWebSocketOutgoingMessage]
    let done: Bool
    let errorMessage: String?
    let stateJSON: String?

    static func evaluate(frame: HttpTtsWebSocketFrame, script: String, stateJSON: String?,
                         source: HttpTts, text: String, speed: Int,
                         runtimeStore: HttpTtsRuntimeStore? = nil) throws -> HttpTtsWebSocketAction {
        guard let context = JSContext() else { throw HttpTtsWebSocketError.scriptFailed("无法创建脚本上下文") }
        context.exceptionHandler = { _, _ in }
        context.setObject(text, forKeyedSubscript: "speakText" as NSString)
        context.setObject(speed, forKeyedSubscript: "speakSpeed" as NSString)
        context.setObject(["speakText": text, "speakSpeed": speed] as [String: Any], forKeyedSubscript: "java" as NSString)
        if let runtimeStore {
            JsBridgeTemplates.registerHttpTtsSourceBridge(in: context, source: source, runtimeStore: runtimeStore)
        } else {
            context.setObject(["id": source.id, "name": source.name] as [String: Any], forKeyedSubscript: "source" as NSString)
        }
        if let library = source.jsLib, !library.isEmpty {
            context.evaluateScript(library)
            if let error = context.exception { throw HttpTtsWebSocketError.scriptFailed(error.toString()) }
        }
        let message = JSValue(newObjectIn: context)!
        message.setValue(frame.messageType, forProperty: "type")
        message.setValue(frame.text ?? "", forProperty: "text")
        message.setValue(frame.data.count, forProperty: "length")
        message.setValue(frame.data.count, forProperty: "count")
        let byteAt: @convention(block) (Int) -> Int = { frame.byteAt($0) }
        let uint16: @convention(block) (Int) -> Int = { frame.uint16BE(at: $0) }
        let utf8: @convention(block) (Int, Int) -> String = { frame.utf8(at: $0, count: $1) ?? "" }
        let base64: @convention(block) (Int, Int) -> String = { frame.base64(at: $0, count: $1) ?? "" }
        message.setValue(byteAt, forProperty: "byteAt")
        message.setValue(uint16, forProperty: "uint16BE")
        message.setValue(utf8, forProperty: "utf8")
        message.setValue(base64, forProperty: "base64")
        context.setObject(message, forKeyedSubscript: "message" as NSString)
        let state = stateJSON.flatMap { $0.data(using: .utf8) }
            .flatMap { try? JSONSerialization.jsonObject(with: $0) } ?? [:]
        context.setObject(state, forKeyedSubscript: "webSocketState" as NSString)
        context.exception = nil
        let value = context.evaluateScript(script)
        if let error = context.exception { throw HttpTtsWebSocketError.scriptFailed(error.toString()) }
        guard let value, !value.isNull, !value.isUndefined else {
            return .init(audio: nil, messages: [], done: false, errorMessage: nil, stateJSON: stateJSON)
        }
        guard value.isObject, let fields = value.toDictionary() as? [String: Any] else {
            throw HttpTtsWebSocketError.scriptFailed("onMessage必须返回对象、null或undefined")
        }
        var audio: Data?
        if let raw = fields["audio"], !(raw is NSNull) {
            guard let text = raw as? String, let decoded = HttpTtsWebSocketConfiguration.decodeBase64(text) else {
                throw HttpTtsWebSocketError.scriptFailed("onMessage返回了无效的音频Base64")
            }
            audio = decoded
        }
        let updatedState = fields["state"] ?? context.objectForKeyedSubscript("webSocketState")?.toObject()
        let encodedState: String?
        if let updatedState, JSONSerialization.isValidJSONObject(updatedState) {
            encodedState = String(decoding: try JSONSerialization.data(withJSONObject: updatedState, options: [.sortedKeys]), as: UTF8.self)
        } else { encodedState = stateJSON }
        return .init(audio: audio, messages: try HttpTtsWebSocketConfiguration.decodeMessages(fields["send"]),
            done: fields["done"] as? Bool ?? false, errorMessage: fields["error"] as? String, stateJSON: encodedState)
    }
}
