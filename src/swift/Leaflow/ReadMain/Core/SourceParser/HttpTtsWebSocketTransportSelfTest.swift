// T-1602：CI回环服务验证URLSessionWebSocketTask真实握手、头与文本/二进制链。
import Foundation

enum HttpTtsWebSocketTransportSelfTest {
    static func run(emit: (String, [String], [String]) -> Void) async {
        let suite = "T1602.WebSocketLoopback." + UUID().uuidString
        guard let defaults = UserDefaults(suiteName: suite) else { return }
        defer { defaults.removePersistentDomain(forName: suite) }
        do {
            guard let raw = ProcessInfo.processInfo.environment["T1602_WS_PORT"],
                  let port = Int(raw), (1...65535).contains(port),
                  let url = URL(string: "ws://127.0.0.1:\(port)/audio") else {
                throw HttpTtsWebSocketError.invalidConfiguration("缺少CI回环服务端口")
            }
            let configuration = HttpTtsWebSocketConfiguration(url: url, headers: ["X-T1602": "fixed"], bodyTemplate: "start")
            var request = URLRequest(url: url)
            request.setValue("fixed", forHTTPHeaderField: "X-T1602")
            let transport = URLSessionHttpTtsWebSocketTransport()
            let connection = try await transport.connect(request: request, configuration: configuration)
            defer { connection.close() }
            try await connection.send(.text("固定回环正文"))
            let text = try await connection.receive()
            try await connection.send(.binary(Data([0, 1, 2, 255])))
            let binary = try await connection.receive()
            connection.close()
            emit("tts_ws_urlsession_real_frames", ["true", "固定回环正文", "false", "AAEC/w=="],
                [String(text.isText), text.text ?? "", String(binary.isText), binary.data.base64EncodedString()])
            let source = HttpTts(numericId: 1602003, name: "回环WebSocket", url:
                "@js:java.webSocket({url:'\(url.absoluteString)',headers:{'X-T1602':'fixed'},send:['start',{type:'binary',data:'QUJD'}],onMessage:function(message){return message.type==='binary'?{audio:message.base64(0,message.count),done:true}:null;}})")
            let synth = HttpTtsSynthesizer(transport: URLSession.shared, webSocketTransport: transport,
                runtimeStore: HttpTtsRuntimeStore(defaults: defaults))
            let audio = try await synth.audioData(source: source, text: "固定正文", speechRate: 1)
            emit("tts_ws_urlsession_real_synthesis", ["ABC"], [String(decoding: audio, as: UTF8.self)])
            emit("tts_ws_urlsession_setup", ["成功"], ["成功"])
        } catch { emit("tts_ws_urlsession_setup", ["成功"], [error.localizedDescription]) }
    }
}
