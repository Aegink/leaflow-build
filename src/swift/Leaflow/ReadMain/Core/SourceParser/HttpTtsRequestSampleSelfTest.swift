// T-1602：真实合成器消费请求规则，替换网络为记录请求的传输器；偏好隔离。
import Foundation

enum HttpTtsRequestSampleSelfTest {
    static func run(emit: (String, [String], [String]) -> Void) async {
        let suite = "T1602.HttpTts." + UUID().uuidString
        guard let defaults = UserDefaults(suiteName: suite) else { return }
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = HttpTtsRuntimeStore(defaults: defaults)
        let transport = RequestTransport()
        let synthesizer = HttpTtsSynthesizer(transport: transport,
            webSocketTransport: TtsWebSocketTransportStub(), runtimeStore: store)
        var source = HttpTts(numericId: 1602001, name: "固定HTTP朗读",
            url: "https://sample.invalid/audio?text={{encodeURIComponent(speakText)}}&speed={{speakSpeed}}")
        do {
            let data = try await synthesizer.audioData(source: source, text: "正文&问号?", speechRate: 3)
            let query = URLComponents(url: transport.requests.last!.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
            emit("tts_request_text_speed", ["正文&问号?", "3", "true"],
                [query.first { $0.name == "text" }?.value ?? "", query.first { $0.name == "speed" }?.value ?? "",
                 String(data == Data([0x49, 0x44, 0x33]))])
            source.url = #"https://sample.invalid/audio, {"method":"POST","body":{"text":"{{speakText}}","speed":{{speakSpeed}}},"headers":{"X-Mode":"rule"}}"#
            _ = try await synthesizer.audioData(source: source, text: "固定正文", speechRate: 2)
            let post = transport.requests.last!
            let body = try JSONSerialization.jsonObject(with: post.httpBody!) as? [String: Any]
            emit("tts_request_json_post", ["POST", "/audio", "固定正文", "2", "rule"],
                [post.httpMethod ?? "", post.url?.path ?? "", body?["text"] as? String ?? "",
                 String((body?["speed"] as? NSNumber)?.intValue ?? -1), post.value(forHTTPHeaderField: "X-Mode") ?? ""])
            source.header = #"{"X-Login":"base","User-Agent":"FixedAgent"}"#
            store.setLoginHeaderMap(["x-login": "stored"], sourceID: source.id)
            _ = try await synthesizer.audioData(source: source, text: "正文", speechRate: 1)
            emit("tts_request_login_header_merge", ["stored", "FixedAgent", "rule"],
                [transport.requests.last!.value(forHTTPHeaderField: "X-Login") ?? "",
                 transport.requests.last!.value(forHTTPHeaderField: "User-Agent") ?? "",
                 transport.requests.last!.value(forHTTPHeaderField: "X-Mode") ?? ""])
            source.jsLib = "function requestText() { return encodeURIComponent(java.speakText + '-library'); }"
            source.url = "@js:'https://sample.invalid/audio?text=' + requestText() + '&speed=' + java.speakSpeed"
            source.header = "@js:({'X-Source':source.name})"
            _ = try await synthesizer.audioData(source: source, text: "脚本正文", speechRate: 4)
            let scriptQuery = URLComponents(url: transport.requests.last!.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
            emit("tts_request_script_library_context", ["脚本正文-library", "4", "固定HTTP朗读"],
                [scriptQuery.first { $0.name == "text" }?.value ?? "", scriptQuery.first { $0.name == "speed" }?.value ?? "",
                 transport.requests.last!.value(forHTTPHeaderField: "X-Source") ?? ""])
            source.jsLib = nil
            source.header = nil
            source.url = "https://sample.invalid/audio?isolation={{typeof requestText === 'undefined' ? 'isolated' : 'leaked'}}"
            _ = try await synthesizer.audioData(source: source, text: "正文", speechRate: 1)
            emit("tts_request_script_isolation", ["true"],
                [String(transport.requests.last!.url!.absoluteString.contains("isolation=isolated"))])
            source.url = "@js:throw new Error('fixed')"
            let before = transport.requests.count
            do { _ = try await synthesizer.audioData(source: source, text: "正文", speechRate: 1) }
            catch { }
            emit("tts_request_script_failure_no_send", [String(before)], [String(transport.requests.count)])
            source.url = #"https://sample.invalid/audio,{"method":broken}"#
            do { _ = try await synthesizer.audioData(source: source, text: "正文", speechRate: 1) }
            catch { }
            emit("tts_request_invalid_config_no_send", [String(before)], [String(transport.requests.count)])
            source.url = "relative-only"
            do { _ = try await synthesizer.audioData(source: source, text: "正文", speechRate: 1) }
            catch { }
            emit("tts_request_invalid_url_no_send", [String(before)], [String(transport.requests.count)])
            source.url = "https://sample.invalid/audio"
            source.enabledCookieJar = false
            _ = try await synthesizer.audioData(source: source, text: "正文", speechRate: .nan)
            emit("tts_request_disabled_cookie_jar", ["false"], [String(transport.requests.last!.httpShouldHandleCookies)])
            transport.status = 500
            var rejected = false
            do { _ = try await synthesizer.audioData(source: source, text: "正文", speechRate: 1) }
            catch { rejected = true }
            emit("tts_request_http_error_rejected", ["true"], [String(rejected)])
            transport.status = 200
            transport.payload = Data()
            rejected = false
            do { _ = try await synthesizer.audioData(source: source, text: "正文", speechRate: 1) }
            catch { rejected = true }
            emit("tts_request_empty_audio_rejected", ["true"], [String(rejected)])
            emit("tts_request_setup", ["成功"], ["成功"])
        } catch { emit("tts_request_setup", ["成功"], [error.localizedDescription]) }
    }

    private final class RequestTransport: HttpTtsTransporting {
        var requests: [URLRequest] = []
        var status = 200
        var payload = Data([0x49, 0x44, 0x33])
        func data(for request: URLRequest) async throws -> (Data, URLResponse) {
            requests.append(request)
            return (payload, HTTPURLResponse(url: request.url!, statusCode: status,
                httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "audio/mpeg"])!)
        }
    }
}
