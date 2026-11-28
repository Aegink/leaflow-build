// T-1602：生产合成器执行原响应脚本、二进制替换和失败边界；网络/持久化隔离。
import Foundation

enum HttpTtsLoginCheckSelfTest {
    static func run(emit: (String, [String], [String]) -> Void) async {
        let suite = "tts-login-check-\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = HttpTtsRuntimeStore(defaults: defaults)
        let transport = LoginCheckTransport()
        let synth = HttpTtsSynthesizer(transport: transport, webSocketTransport: URLSessionHttpTtsWebSocketTransport(), runtimeStore: store)
        var source = HttpTts(numericId: 70, name: "响应样本", url: "https://sample.invalid/audio", contentType: "audio/.*")
        do {
            source.loginCheckJs = "if(result.code()===200 && result.header('Content-Type').indexOf('json')>=0) { java.setResponseBase64(JSON.parse(result.body().string()).audio,'audio/wav'); } result"
            let audio = try await synth.audioData(source: source, text: "固定正文", speechRate: 2)
            emit("tts_logincheck_json_base64_becomes_audio", ["AAEC/w==", "1"],
                [audio.base64EncodedString(), String(transport.count)])
            source.loginCheckJs = "source.put('response',[result.code(),result.body().bytes(),result.headers('X-FiXeD'),result.message(),speakText,speakSpeed,java.getHeaderMap()['X-Request']].join('|'));java.setResponseBase64('QUJD');result"
            source.header = #"{"X-Request":"request"}"#
            let defaultFormat = try await synth.audioData(source: source, text: "正文", speechRate: 3)
            emit("tts_logincheck_response_context", ["ABC", "200|{\"audio\":\"AAEC/w==\"}|fixed||正文|30|request"],
                [String(decoding: defaultFormat, as: UTF8.self), store.value(for: "response", sourceID: 70) ?? ""])
            source.jsLib = "function extractAudio(r){return JSON.parse(r.body().string()).audio;}"
            source.loginCheckJs = "java.setResponseBase64(extractAudio(result),'audio/mpeg');result"
            emit("tts_logincheck_jslib_is_consumed", ["AAEC/w=="],
                [try await synth.audioData(source: source, text: "正文", speechRate: 1).base64EncodedString()])
            source.jsLib = nil
            source.loginCheckJs = "source.put('codec',java.base64Decode(java.base64Encode('汉字'))); java.setResponseBase64('AAEC_w','audio/wav');result"
            let urlSafe = try await synth.audioData(source: source, text: "正文", speechRate: 1)
            emit("tts_logincheck_urlsafe_and_text_codec", ["AAEC/w==", "汉字"],
                [urlSafe.base64EncodedString(), store.value(for: "codec", sourceID: 70) ?? ""])
            source.loginCheckJs = "throw new Error('固定异常')"
            var rejected = false
            do { _ = try await synth.audioData(source: source, text: "正文", speechRate: 1) } catch { rejected = true }
            emit("tts_logincheck_exception_no_audio", ["true"], [String(rejected)])
            source.loginCheckJs = "java.setResponseBase64('invalid***','audio/wav');result"
            rejected = false
            do { _ = try await synth.audioData(source: source, text: "正文", speechRate: 1) } catch { rejected = true }
            emit("tts_logincheck_bad_base64_keeps_rejected_json", ["true"], [String(rejected)])
            source.loginCheckJs = "java.setResponseBase64('','audio/wav');result"
            rejected = false
            do { _ = try await synth.audioData(source: source, text: "正文", speechRate: 1) } catch { rejected = true }
            emit("tts_logincheck_empty_replacement_rejected", ["true"], [String(rejected)])
            transport.status = 403
            source.loginCheckJs = "if(result.code()===403){source.put('status','403');java.setResponseBase64('QUJD','audio/wav');}result"
            let recovered = try await synth.audioData(source: source, text: "正文", speechRate: 1)
            emit("tts_logincheck_runs_before_status_validation", ["ABC", "403"],
                [String(decoding: recovered, as: UTF8.self), store.value(for: "status", sourceID: 70) ?? ""])
            transport.status = 200
            transport.type = "audio/mpeg"
            transport.payload = Data([0, 255, 128, 2])
            source.loginCheckJs = "source.put('isolated',typeof extractAudio); result"
            let unchanged = try await synth.audioData(source: source, text: "正文", speechRate: 1)
            emit("tts_logincheck_original_binary_and_context_isolation", ["AP+AAg==", "undefined"],
                [unchanged.base64EncodedString(), store.value(for: "isolated", sourceID: 70) ?? ""])
            source.loginCheckJs = "throw Error('音频响应也必须拒绝')"
            var exceptionText = ""
            do { _ = try await synth.audioData(source: source, text: "正文", speechRate: 1) }
            catch { exceptionText = error.localizedDescription }
            emit("tts_logincheck_valid_audio_script_exception_rejected", ["true"],
                [String(exceptionText.contains("音频响应也必须拒绝"))])
            source.loginCheckJs = "result"
            source.jsLib = "if(typeof result!=='undefined'){throw Error('响应库失败');}"
            exceptionText = ""
            do { _ = try await synth.audioData(source: source, text: "正文", speechRate: 1) }
            catch { exceptionText = error.localizedDescription }
            emit("tts_logincheck_valid_audio_library_exception_rejected", ["true"],
                [String(exceptionText.contains("响应库失败"))])
            source.jsLib = nil
            source.loginCheckJs = "java.setResponseBase64('QUJD','text/html'); result"
            rejected = false
            do { _ = try await synth.audioData(source: source, text: "正文", speechRate: 1) } catch { rejected = true }
            emit("tts_logincheck_replacement_type_still_validated", ["true"], [String(rejected)])
            try verifyRetry(store: store, emit: emit)
            try await verifyRealRetry(store: store, emit: emit)
            emit("tts_logincheck_setup", ["成功"], ["成功"])
        } catch { emit("tts_logincheck_setup", ["成功"], [error.localizedDescription]) }
    }

    private static func verifyRetry(store: HttpTtsRuntimeStore, emit: (String, [String], [String]) -> Void) throws {
        let source = HttpTts(numericId: 71, name: "重试源",
            url: "@js:'https://sample.invalid/'+(source.get('path')||'old')+'?text='+encodeURIComponent(speakText)")
        let request = try HttpTtsSynthesizer.makeRequest(source: source, text: "重试正文", speed: 2, store: store)
        let response = HTTPURLResponse(url: request.url!, statusCode: 403, httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "text/html"])!
        var requests: [URLRequest] = []
        let retry = try LoginCheckExecutor.executeTTS(checkJs:
            "source.put('path','new');source.putLoginHeader('{\"X-Login\":\"new\"}');java.initUrl();result=java.getResponse();source.put('retry-status',String(result.code()));result",
            source: source, response: response, responseData: Data("denied".utf8), request: request,
            runtimeStore: store, speakText: "重试正文", speakSpeed: 2, send: { request in
                requests.append(request)
                return (Data([1, 2, 3]), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1",
                    headerFields: ["Content-Type": "audio/wav"])!)
            })
        emit("tts_logincheck_retry_reparses_persisted_configuration", ["1", "/new", "new", "200", "AQID"],
            [String(requests.count), requests.first?.url?.path ?? "", requests.first?.value(forHTTPHeaderField: "X-Login") ?? "",
             store.value(for: "retry-status", sourceID: 71) ?? "", retry?.data.base64EncodedString() ?? ""])
        let query = requests.first?.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false)?.queryItems }
        emit("tts_logincheck_retry_preserves_speak_text", ["重试正文"], [query?.first { $0.name == "text" }?.value ?? ""])
        var failed = false
        do {
            _ = try LoginCheckExecutor.executeTTS(checkJs: "java.getResponse();result", source: source,
                response: response, responseData: Data(), request: request, runtimeStore: store,
                speakText: "", speakSpeed: 1, send: { _ in throw URLError(.notConnectedToInternet) })
        } catch { failed = true }
        emit("tts_logincheck_retry_network_error_not_swallowed", ["true"], [String(failed)])
        let chained = try LoginCheckExecutor.executeTTS(checkJs:
            "result=java.getResponse();java.setResponseBase64(JSON.parse(result.body().string()).audio,'audio/wav');result",
            source: source, response: response, responseData: Data(), request: request, runtimeStore: store,
            speakText: "", speakSpeed: 1, send: { request in
                (Data(#"{"audio":"QUJD"}"#.utf8), HTTPURLResponse(url: request.url!, statusCode: 200,
                    httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!)
            })
        emit("tts_logincheck_retry_then_base64_replacement", ["ABC", "audio/wav"],
            [String(decoding: chained?.data ?? Data(), as: UTF8.self), chained?.httpResponse?.value(forHTTPHeaderField: "Content-Type") ?? ""])
    }

    private static func verifyRealRetry(store: HttpTtsRuntimeStore, emit: (String, [String], [String]) -> Void) async throws {
        guard let raw = ProcessInfo.processInfo.environment["T1602_WS_PORT"], let port = Int(raw), (1...65535).contains(port) else {
            throw AppError.parsing("缺少重试回环端口")
        }
        let source = HttpTts(numericId: 72, name: "真实重试", url: "http://127.0.0.1:\(port)/preview.wav",
            contentType: "audio/.*", header: #"{"X-T1602":"fixed"}"#,
            loginCheckJs: "if(result.code()===403){java.initUrl();result=java.getResponse();}result")
        let initial = LoginCheckTransport()
        initial.status = 403
        let synth = HttpTtsSynthesizer(transport: initial, webSocketTransport: URLSessionHttpTtsWebSocketTransport(), runtimeStore: store)
        let audio = try await synth.audioData(source: source, text: "固定正文", speechRate: 1)
        emit("tts_logincheck_real_http_retry_returns_wav", ["1", "RIFF", "4844"],
            [String(initial.count), String(decoding: audio.prefix(4), as: UTF8.self), String(audio.count)])
    }
}

private final class LoginCheckTransport: HttpTtsTransporting {
    var count = 0
    var status = 200
    var type = "application/json"
    var payload = Data(#"{"audio":"AAEC/w=="}"#.utf8)
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        count += 1
        return (payload, HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": type, "X-Fixed": "fixed"])!)
    }
}
