// T-1602：生产配置/消息脚本/合成器链，固定帧代替远端服务，独立偏好域。
import Foundation
import JavaScriptCore

enum HttpTtsWebSocketSampleSelfTest {
    static func run(emit: (String, [String], [String]) -> Void) async {
        let suite = "T1602.WebSocket." + UUID().uuidString
        guard let defaults = UserDefaults(suiteName: suite) else { return }
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = HttpTtsRuntimeStore(defaults: defaults)
        do {
            let config = try HttpTtsWebSocketConfiguration(javaScriptValue: ["url": "wss://sample.invalid/audio",
                "send": ["start", ["type": "binary", "data": "AQI="]], "onMessage": "({done:true})"])
            emit("tts_ws_config_original_defaults", ["12000", "30000", "16777216", "audio/mpeg", "true"],
                [String(config.connectTimeoutMilliseconds), String(config.receiveTimeoutMilliseconds),
                 String(config.maximumAudioBytes), config.audioContentType,
                 String(config.messages == [.text("start"), .binary(Data([1, 2]))])])
            let capped = try HttpTtsWebSocketConfiguration(javaScriptValue: ["url": "ws://sample.invalid/audio",
                "send": "x", "onMessage": "({done:true})", "maxAudioBytes": 100_000_000,
                "receiveTimeout": 0, "connectTimeout": -1])
            emit("tts_ws_config_limits", ["67108864", "1", "1"],
                [String(capped.maximumAudioBytes), String(capped.receiveTimeoutMilliseconds), String(capped.connectTimeoutMilliseconds)])
            var invalid = 0
            let invalidFields: [[String: Any]] = [
                ["url": "https://sample.invalid", "send": "x", "onMessage": "({})"],
                ["url": "wss://sample.invalid", "send": [], "onMessage": "({})"],
                ["url": "wss://sample.invalid", "send": "x"],
                ["url": "wss://sample.invalid", "send": ["type": "binary", "data": "!"], "onMessage": "({})"]]
            for fields in invalidFields {
                do { _ = try HttpTtsWebSocketConfiguration(javaScriptValue: fields) } catch { invalid += 1 }
            }
            emit("tts_ws_invalid_config_rejected", ["4"], [String(invalid)])
            let frame = HttpTtsWebSocketFrame(data: Data([1, 2, 65, 66]), isText: false)
            emit("tts_ws_frame_bounds", ["1", "258", "0", "QUI=", "AB", "true"],
                [String(frame.byteAt(0)), String(frame.uint16BE(at: 0)), String(frame.uint16BE(at: Int.max)),
                 frame.base64(at: 2, count: Int.max) ?? "", frame.utf8(at: 2, count: 2) ?? "",
                 String(frame.utf8(at: -1, count: 2) == nil)])
            let transport = SocketTransport(frames: [
                .init(data: Data("begin".utf8), isText: true), frame])
            let synth = HttpTtsSynthesizer(transport: ForbiddenHTTP(), webSocketTransport: transport, runtimeStore: store)
            var source = HttpTts(numericId: 1602002, name: "固定WebSocket",
                url: """
                @js:java.webSocket({url:'wss://sample.invalid/audio', headers:{'X-Mode':'socket'}, send:java.speakText,
                  onMessage:function(message, state) {
                    if(message.type === 'text') return {send:'next', state:{ready:true}};
                    if(!state.ready || message.count !== 4 || message.uint16BE(0) !== 258) throw new Error('state');
                    return {audio:message.base64(2,2), done:true};
                  }})
                """)
            let audio = try await synth.audioData(source: source, text: "请求正文", speechRate: 2)
            emit("tts_ws_real_request_script_chain", ["AB", "true", "socket", "true"],
                [String(decoding: audio, as: UTF8.self), String(transport.connection.sent == [.text("请求正文"), .text("next")]),
                 transport.request?.value(forHTTPHeaderField: "X-Mode") ?? "", String(transport.connection.closed)])
            let action = try HttpTtsWebSocketAction.evaluate(frame: frame, script: "null", stateJSON: "{\"x\":1}",
                source: source, text: "", speed: 1)
            emit("tts_ws_null_action_keeps_state", ["false", "true", "{\"x\":1}"],
                [String(action.done), String(action.audio == nil), action.stateJSON ?? ""])
            var badScript = false
            do { _ = try HttpTtsWebSocketAction.evaluate(frame: frame, script: "({audio:'!'})", stateJSON: nil,
                source: source, text: "", speed: 1) } catch { badScript = true }
            emit("tts_ws_invalid_audio_rejected", ["true"], [String(badScript)])
            var thrownAction = false
            do { _ = try HttpTtsWebSocketAction.evaluate(frame: frame, script: "throw Error('固定帧异常')", stateJSON: nil,
                source: source, text: "", speed: 1) } catch { thrownAction = true }
            emit("tts_ws_throwing_action_rejected_immediately", ["true"], [String(thrownAction)])
            var librarySource = source
            librarySource.jsLib = "throw Error('固定库异常')"
            var thrownLibrary = false
            do { _ = try HttpTtsWebSocketAction.evaluate(frame: frame, script: "({audio:'QUJD',done:true})", stateJSON: nil,
                source: librarySource, text: "", speed: 1) } catch { thrownLibrary = true }
            emit("tts_ws_throwing_library_rejects_valid_action", ["true"], [String(thrownLibrary)])
            func rejectedAction(_ script: String, limit: Int = 100) async -> [String] {
                let connection = SocketTransport(frames: [frame])
                let synthesizer = HttpTtsSynthesizer(transport: ForbiddenHTTP(), webSocketTransport: connection, runtimeStore: store)
                source.url = "@js:java.webSocket({url:'wss://sample.invalid/audio',send:'start',maxAudioBytes:\(limit),onMessage:\"\(script)\"})"
                var rejected = false
                do { _ = try await synthesizer.audioData(source: source, text: "x", speechRate: 1) }
                catch { rejected = true }
                return [String(rejected), String(connection.connection.closed)]
            }
            emit("tts_ws_source_error", ["true", "true"], await rejectedAction("({error:'fixed failure'})"))
            emit("tts_ws_empty_done_rejected", ["true", "true"], await rejectedAction("({done:true})"))
            emit("tts_ws_audio_limit_enforced", ["true", "true"], await rejectedAction("({audio:'QUJD',done:true})", limit: 2))
            let stalled = SocketTransport(frames: [])
            stalled.connection.waits = true
            let timeoutSynth = HttpTtsSynthesizer(transport: ForbiddenHTTP(), webSocketTransport: stalled, runtimeStore: store)
            source.url = "@js:java.webSocket({url:'wss://sample.invalid/audio',send:'start',receiveTimeout:5,onMessage:'({done:true})'})"
            var timeout = false
            do { _ = try await timeoutSynth.audioData(source: source, text: "x", speechRate: 1) } catch { timeout = true }
            emit("tts_ws_timeout_closes_connection", ["true", "true"], [String(timeout), String(stalled.connection.closed)])
            let cancelled = SocketTransport(frames: [])
            cancelled.connection.waits = true
            let cancelSynth = HttpTtsSynthesizer(transport: ForbiddenHTTP(), webSocketTransport: cancelled, runtimeStore: store)
            source.url = "@js:java.webSocket({url:'wss://sample.invalid/audio',send:'start',onMessage:'({done:true})'})"
            let task = Task { try await cancelSynth.audioData(source: source, text: "x", speechRate: 1) }
            for _ in 0..<100 where cancelled.request == nil { try await Task.sleep(nanoseconds: 1_000_000) }
            task.cancel()
            _ = try? await task.value
            emit("tts_ws_cancellation_closes_connection", ["true"], [String(cancelled.connection.closed)])
            emit("tts_ws_setup", ["成功"], ["成功"])
        } catch { emit("tts_ws_setup", ["成功"], [error.localizedDescription]) }
    }

    private final class ForbiddenHTTP: HttpTtsTransporting {
        func data(for request: URLRequest) async throws -> (Data, URLResponse) { throw HttpTtsWebSocketError.invalidURL }
    }
    private final class SocketTransport: HttpTtsWebSocketTransporting {
        let connection: SocketConnection
        var request: URLRequest?
        init(frames: [HttpTtsWebSocketFrame]) { connection = SocketConnection(frames: frames) }
        func connect(request: URLRequest, configuration: HttpTtsWebSocketConfiguration) async throws -> HttpTtsWebSocketConnection {
            self.request = request
            return connection
        }
    }
    private final class SocketConnection: HttpTtsWebSocketConnection {
        var frames: [HttpTtsWebSocketFrame]
        var sent: [HttpTtsWebSocketOutgoingMessage] = []
        var waits = false
        private let lock = NSLock()
        private var isClosed = false
        var closed: Bool { lock.lock(); defer { lock.unlock() }; return isClosed }
        init(frames: [HttpTtsWebSocketFrame]) { self.frames = frames }
        func send(_ message: HttpTtsWebSocketOutgoingMessage) async throws { sent.append(message) }
        func receive() async throws -> HttpTtsWebSocketFrame {
            while waits && !closed { try await Task.sleep(nanoseconds: 1_000_000) }
            guard !closed, !frames.isEmpty else { throw HttpTtsWebSocketError.connectionClosedBeforeCompletion }
            return frames.removeFirst()
        }
        func close() { lock.lock(); isClosed = true; lock.unlock() }
    }
}
