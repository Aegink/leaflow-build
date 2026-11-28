// T-1602：原loginUi求值和首次default字段持久化；通过请求准备消费，隔离存储。
import Foundation

enum HttpTtsConfigurationSelfTest {
    static func run(emit: (String, [String], [String]) -> Void) {
        let suite = "tts-config-\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = HttpTtsRuntimeStore(defaults: defaults)
        let evaluator = HttpTtsLoginConfigurationEvaluator(store: store)
        var source = HttpTts(numericId: 80, name: "配置源", url: "https://sample.invalid/tts")
        func rows(_ json: String?) -> [[String: Any]] { LegadoJSONLiteral.parse(json) as? [[String: Any]] ?? [] }
        do {
            let plain = try evaluator.evaluate(#" [{"name":"key","default":"a,]b"}] "#, source: source)
            emit("tts_configuration_static_json_literal", ["key", "a,]b"],
                [rows(plain).first?["name"] as? String ?? "", rows(plain).first?["default"] as? String ?? ""])
            var invalid = 0
            for input in ["[{\"name\":\"key\"},]", "plain-text", "@js:undefined", "@js:null", "@js:''", "@js:throw Error('固定错误')"] {
                do { _ = try evaluator.evaluate(input, source: source) } catch { invalid += 1 }
            }
            emit("tts_configuration_invalid_and_empty_rejected", ["6"], [String(invalid)])
            store.setValue("保存值", for: "saved", sourceID: 80)
            source.jsLib = "function initial(){return source.get('saved');}"
            let script = try evaluator.evaluate("@js:JSON.stringify([{name:'voice',default:initial()}])", source: source)
            emit("tts_configuration_script_library_and_source", ["保存值"], [rows(script).first?["default"] as? String ?? ""])
            let tagged = try evaluator.evaluate("<js>JSON.stringify([{name:'tag',default:source.getKey()}])</js>", source: source)
            emit("tts_configuration_js_tag", ["httpTts_80"], [rows(tagged).first?["default"] as? String ?? ""])
            source.jsLib = nil
            let isolated = try evaluator.evaluate("@js:JSON.stringify([{name:'isolation',default:typeof initial}])", source: source)
            emit("tts_configuration_context_isolation", ["undefined"], [rows(isolated).first?["default"] as? String ?? ""])
            source.header = #"{"X-Rule":"request-only"}"#
            source.loginUi = #"[{"name":"voice","type":"select","chars":["first"],"default":"chosen"},{"name":"empty","chars":["placeholder"]},{"name":"button","type":"button","default":"ignored"},{"name":"","default":"ignored"},{"name":"duplicate","default":"old"},{"name":"duplicate","default":"last"},{"name":"legacy","defaultValue":"not-original"}]"#
            try evaluator.prepareDefaultsIfNeeded(for: source, store: store)
            let map = store.loginInfoMap(sourceID: 80)
            emit("tts_configuration_original_defaults_fields", ["chosen", "", "last", "", "false", "false"],
                [map["voice"] ?? "缺失", map["empty"] ?? "缺失", map["duplicate"] ?? "缺失", map["legacy"] ?? "缺失",
                 String(map["button"] != nil), String(map[""] != nil)])
            emit("tts_configuration_does_not_copy_request_header", ["true"], [String(store.loginHeader(sourceID: 80) == nil)])
            store.setLoginInfoMap(["voice": ""], sourceID: 80)
            try evaluator.prepareDefaultsIfNeeded(for: source, store: store)
            emit("tts_configuration_existing_info_never_overwritten", ["1", ""],
                [String(store.loginInfoMap(sourceID: 80).count), store.loginInfoMap(sourceID: 80)["voice"] ?? "缺失"])
            store.setLoginInfo("malformed", sourceID: 80)
            try evaluator.prepareDefaultsIfNeeded(for: source, store: store)
            emit("tts_configuration_existing_raw_preserved", ["malformed"], [store.loginInfo(sourceID: 80) ?? ""])
            source.numericId = 81
            source.loginUi = #"[{"name":"action","type":"button"}]"#
            try evaluator.prepareDefaultsIfNeeded(for: source, store: store)
            emit("tts_configuration_button_only_no_storage", ["true"], [String(store.loginInfo(sourceID: 81) == nil)])
            source.numericId = 82
            source.loginUi = "@js:JSON.stringify([{name:'voice',default:'initial'}])"
            source.url = "https://sample.invalid/audio?voice={{source.getLoginInfoMap().get('voice')}}"
            let request = try HttpTtsSynthesizer.makeRequest(source: source, text: "正文", speed: 10, store: store)
            emit("tts_configuration_request_prepares_defaults", ["initial", "true"],
                [store.loginInfoMap(sourceID: 82)["voice"] ?? "", String(request.url?.absoluteString.contains("voice=initial") == true)])
            source.numericId = 83
            source.jsLib = "throw Error('bad library')"
            var failed = false
            do { _ = try HttpTtsSynthesizer.makeRequest(source: source, text: "正文", speed: 10, store: store) }
            catch { failed = true }
            emit("tts_configuration_failure_no_default_write", ["true", "true"],
                [String(failed), String(store.loginInfo(sourceID: 83) == nil)])
            emit("tts_configuration_setup", ["成功"], ["成功"])
        } catch { emit("tts_configuration_setup", ["成功"], [error.localizedDescription]) }
    }
}
