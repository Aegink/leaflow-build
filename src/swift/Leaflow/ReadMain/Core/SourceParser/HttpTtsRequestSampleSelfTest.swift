// T-1602：真实合成器消费请求规则，替换网络为记录请求的传输器；偏好隔离。
import Foundation

enum HttpTtsRequestSampleSelfTest {
    static func run(emit: (String, [String], [String]) -> Void) async {
        let suite = "T1602.HttpTts." + UUID().uuidString
        guard let defaults = UserDefaults(suiteName: suite) else { return }
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = HttpTtsRuntimeStore(defaults: defaults)
        checkStore(store, defaults: defaults, emit: emit)
        let transport = RequestTransport()
        let synthesizer = HttpTtsSynthesizer(transport: transport,
            webSocketTransport: URLSessionHttpTtsWebSocketTransport(), runtimeStore: store)
        var source = HttpTts(numericId: 1602001, name: "固定HTTP朗读",
            url: "https://sample.invalid/audio?text={{encodeURIComponent(speakText)}}&speed={{speakSpeed}}")
        do {
            let data = try await synthesizer.audioData(source: source, text: "正文&问号?", speechRate: 3)
            let query = URLComponents(url: transport.requests.last!.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
            emit("tts_request_text_speed", ["正文&问号?", "30", "true"],
                [query.first { $0.name == "text" }?.value ?? "", query.first { $0.name == "speed" }?.value ?? "",
                 String(data == Data([0x49, 0x44, 0x33]))])
            source.url = #"https://sample.invalid/audio, {"method":"POST","body":{"text":"{{speakText}}","speed":{{speakSpeed}}},"headers":{"X-Mode":"rule"}}"#
            _ = try await synthesizer.audioData(source: source, text: "固定正文", speechRate: 2)
            let post = transport.requests.last!
            let body = try JSONSerialization.jsonObject(with: post.httpBody!) as? [String: Any]
            emit("tts_request_json_post", ["POST", "/audio", "固定正文", "20", "rule"],
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
            emit("tts_request_script_library_context", ["脚本正文-library", "40", "固定HTTP朗读"],
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
            transport.payload = Data([0x49, 0x44, 0x33])
            var contentRejected = 0
            for type in ["text/html; charset=UTF-8", "APPLICATION/JSON"] {
                transport.contentType = type
                do { _ = try await synthesizer.audioData(source: source, text: "正文", speechRate: 1) }
                catch { contentRejected += 1 }
            }
            emit("tts_response_default_rejects_html_json", ["2"], [String(contentRejected)])
            transport.contentType = "application/octet-stream"
            let binary = try await synthesizer.audioData(source: source, text: "正文", speechRate: 1)
            emit("tts_response_default_allows_other_types", ["true"], [String(binary == transport.payload)])
            transport.contentType = nil
            let missingType = try await synthesizer.audioData(source: source, text: "正文", speechRate: 1)
            emit("tts_response_missing_type_uses_default", ["true"], [String(missingType == transport.payload)])
            source.contentType = "audio/(mpeg|wav)"
            transport.contentType = "AUDIO/WAV; codec=pcm"
            let matched = try await synthesizer.audioData(source: source, text: "正文", speechRate: 1)
            emit("tts_response_regex_case_insensitive_partial", ["true"], [String(matched == transport.payload)])
            transport.contentType = "application/json"
            rejected = false
            do { _ = try await synthesizer.audioData(source: source, text: "正文", speechRate: 1) }
            catch { rejected = true }
            emit("tts_response_regex_mismatch_rejected", ["true"], [String(rejected)])
            source.contentType = "["
            rejected = false
            do { _ = try await synthesizer.audioData(source: source, text: "正文", speechRate: 1) }
            catch { rejected = true }
            emit("tts_response_invalid_regex_rejected", ["true"], [String(rejected)])
            source.contentType = nil
            source.url = "https://sample.invalid/audio?speed={{speakSpeed}}"
            transport.contentType = "audio/mpeg"
            var speeds: [String] = []
            for rate: Float in [0.5, 1, 1.59, 3] {
                _ = try await synthesizer.audioData(source: source, text: "正文", speechRate: rate)
                let items = URLComponents(url: transport.requests.last!.url!, resolvingAgainstBaseURL: false)?.queryItems
                speeds.append(items?.first { $0.name == "speed" }?.value ?? "")
            }
            emit("tts_request_original_speed_scale", ["5", "10", "15", "30"], speeds)
            let beforeInvalidRate = transport.requests.count
            var invalidRates = 0
            for rate: Float in [.nan, .infinity, .greatestFiniteMagnitude] {
                do { _ = try await synthesizer.audioData(source: source, text: "正文", speechRate: rate) }
                catch { invalidRates += 1 }
            }
            emit("tts_request_invalid_rate_no_send", ["3", "true"],
                [String(invalidRates), String(transport.requests.count == beforeInvalidRate)])
            emit("tts_request_setup", ["成功"], ["成功"])
        } catch { emit("tts_request_setup", ["成功"], [error.localizedDescription]) }
    }

    private final class RequestTransport: HttpTtsTransporting {
        var requests: [URLRequest] = []
        var status = 200
        var payload = Data([0x49, 0x44, 0x33])
        var contentType: String? = "audio/mpeg"
        func data(for request: URLRequest) async throws -> (Data, URLResponse) {
            requests.append(request)
            return (payload, HTTPURLResponse(url: request.url!, statusCode: status,
                httpVersion: "HTTP/1.1", headerFields: contentType.map { ["Content-Type": $0] } ?? [:])!)
        }
    }

    private static func checkStore(_ store: HttpTtsRuntimeStore, defaults: UserDefaults,
                                    emit: (String, [String], [String]) -> Void) {
        defaults.set(#"{"account":"original"}"#, forKey: "loginInfo_httpTts_21")
        defaults.set(#"{"Cookie":"original-cookie"}"#, forKey: "loginHeader_httpTts_21")
        defaults.set("original-variable", forKey: "sourceVariable_httpTts_21")
        emit("tts_store_original_keys", ["original", "original-cookie", "original-variable"],
            [store.loginInfoMap(sourceID: 21)["account"] ?? "", store.loginHeaderMap(sourceID: 21)["Cookie"] ?? "",
             store.sourceVariable(sourceID: 21) ?? ""])
        store.setValue("value", for: "same", sourceID: 21)
        store.setCacheValue("cache", for: "same", sourceID: 21)
        emit("tts_store_value_cache_separate", ["value", "cache", "value", "cache"],
            [store.value(for: "same", sourceID: 21) ?? "", store.cacheValue(for: "same", sourceID: 21) ?? "",
             defaults.string(forKey: "v_httpTts_21_same") ?? "", defaults.string(forKey: "ttsCache_21_same") ?? ""])
        defaults.set("legacy", forKey: "tts_login_info_22")
        emit("tts_store_legacy_migration", ["legacy", "legacy"],
            [store.loginInfo(sourceID: 22) ?? "", defaults.string(forKey: "loginInfo_httpTts_22") ?? ""])
        defaults.set("new", forKey: "loginInfo_httpTts_22")
        emit("tts_store_original_wins", ["new"], [store.loginInfo(sourceID: 22) ?? ""])
        store.clearAuthentication(sourceID: 21)
        emit("tts_store_clear_auth_preserves_variables", ["true", "true", "original-variable", "value"],
            [String(store.loginInfo(sourceID: 21) == nil), String(store.loginHeader(sourceID: 21) == nil),
             store.sourceVariable(sourceID: 21) ?? "", store.value(for: "same", sourceID: 21) ?? ""])
        store.setValue("other", for: "same", sourceID: 210)
        store.clearAll(sourceID: 21)
        emit("tts_store_clear_source_boundary", ["true", "true", "true", "other"],
            [String(store.sourceVariable(sourceID: 21) == nil), String(store.value(for: "same", sourceID: 21) == nil),
             String(store.cacheValue(for: "same", sourceID: 21) == nil), store.value(for: "same", sourceID: 210) ?? ""])
        store.clearAuthentication(sourceID: 22)
        emit("tts_store_removed_legacy_not_resurrected", ["true", "true"],
            [String(store.loginInfo(sourceID: 22) == nil), String(defaults.object(forKey: "tts_login_info_22") == nil)])
        defaults.set("keep", forKey: "unrelated")
        defaults.set("shared-legacy", forKey: "tts_cache_23_old")
        store.setValue(nil, for: "old", sourceID: 23)
        emit("tts_store_split_legacy_value_cache", ["true", "shared-legacy", "true"],
            [String(store.value(for: "old", sourceID: 23) == nil), store.cacheValue(for: "old", sourceID: 23) ?? "",
             String(defaults.object(forKey: "tts_cache_23_old") == nil)])
        store.clearAll()
        emit("tts_store_clear_all_scoped", ["true", "keep"],
            [String(store.value(for: "same", sourceID: 210) == nil), defaults.string(forKey: "unrelated") ?? ""])
    }
}
