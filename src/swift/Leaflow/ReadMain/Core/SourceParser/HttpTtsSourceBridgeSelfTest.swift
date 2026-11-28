// T-1602：原版源桥的真实JS调用、持久化、隔离与请求/WS消费。
import Foundation
import JavaScriptCore

enum HttpTtsSourceBridgeSelfTest {
    static func run(emit: (String, [String], [String]) -> Void) {
        let suite = "tts-source-bridge-\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = HttpTtsRuntimeStore(defaults: defaults)
        var source = HttpTts(numericId: 42, name: "带'引号\n名称", url: "https://sample.invalid/tts", loginUrl: "login()")
        func context(_ source: HttpTts, removal: Bool = true, merge: Bool = true) -> JSContext {
            let context = JSContext()!
            context.exceptionHandler = { _, _ in }
            JsBridgeTemplates.registerHttpTtsSourceBridge(in: context, source: source, runtimeStore: store,
                mergePersistedLoginHeader: merge, includeRemovalHooks: removal)
            return context
        }
        func evaluate(_ context: JSContext, _ script: String) throws -> String {
            context.exception = nil
            let value = context.evaluateScript(script)
            if let error = context.exception { throw AppError.parsing(error.toString()) }
            return value?.toString() ?? "undefined"
        }
        do {
            let js = context(source)
            emit("tts_bridge_source_key_and_name", ["httpTts_42|httpTts_42|login()", source.name],
                [try evaluate(js, "[source.getKey(),source.bookSourceUrl,source.loginUrl].join('|')"),
                 try evaluate(js, "source.bookSourceName")])
            emit("tts_bridge_login_info_real_map", ["true", "甲|true", "甲"],
                [try evaluate(js, #"source.putLoginInfo('{"account":"甲"}')"#),
                 try evaluate(js, "[source.getLoginInfoMap().get('account'),source.getLoginInfoMap().get('missing')===null].join('|')"),
                 store.loginInfoMap(sourceID: 42)["account"] ?? ""])
            emit("tts_bridge_variable_property_aliases", ["第二次|第二次", "第二次"],
                [try evaluate(js, "source.variable='第一次'; source.putVariable('第二次'); [source.variable,source.getVariable()].join('|')"),
                 store.sourceVariable(sourceID: 42) ?? ""])
            emit("tts_bridge_value_cache_domains", ["value|cache|value|cache", "value", "cache"],
                [try evaluate(js, "[source.put('same','value'),cache.putFile('same','cache'),source.get('same'),cache.getFile('same')].join('|')"),
                 store.value(for: "same", sourceID: 42) ?? "", store.cacheValue(for: "same", sourceID: 42) ?? ""])
            let cold = context(source)
            emit("tts_bridge_persistence_across_contexts", ["甲|第二次|value|cache"],
                [try evaluate(cold, "[source.getLoginInfoMap().get('account'),source.variable,source.get('same'),cache.get('same')].join('|')")])
            var other = source
            other.numericId = 420
            emit("tts_bridge_other_source_isolation", ["|||"],
                [try evaluate(context(other), "[source.getLoginInfo(),source.variable,source.get('same'),cache.get('same')].join('|')")])
            emit("tts_bridge_cache_delete_not_value", ["|value"],
                [try evaluate(js, "cache.delete('same'); [cache.get('same'),source.get('same')].join('|')")])
            emit("tts_bridge_null_removes_variable_login", ["|", "true", "true"],
                [try evaluate(js, "source.variable=null;source.putLoginInfo(undefined);[source.variable,source.getLoginInfo()].join('|')"),
                 String(store.sourceVariable(sourceID: 42) == nil), String(store.loginInfo(sourceID: 42) == nil)])
            emit("tts_bridge_header_map_and_removal", ["fixed|true", "true"],
                [try evaluate(js, #"source.putLoginHeader('  {"X-Fixed":"fixed"}  '); [source.getLoginHeaderMap().get('X-Fixed'),source.getLoginHeaderMap().get('absent')===null].join('|')"#),
                 try evaluate(js, "source.removeLoginHeader();source.getLoginHeader()==='' ")])
            emit("tts_bridge_optional_removal_hooks", ["undefined|undefined", "function|function"],
                [try evaluate(context(source, removal: false), "[typeof source.removeLoginInfo,typeof source.removeLoginHeader].join('|')"),
                 try evaluate(context(source), "[typeof source.removeLoginInfo,typeof source.removeLoginHeader].join('|')")])
            let rawContext = context(source, merge: false)
            emit("tts_bridge_header_normalization_policy", ["  raw  ", "raw", "true"],
                [try evaluate(rawContext, "source.putLoginHeader('  raw  ');source.getLoginHeader()"),
                 try evaluate(js, "source.putLoginHeader('  raw  ');source.getLoginHeader()"),
                 try evaluate(js, "source.putLoginHeader('   ');source.getLoginHeader()==='' ")])
            source.jsLib = #"source.putLoginHeader('{"X-Fixed":"from-library"}');source.variable='request';cache.put('body','cached');"#
            source.url = "https://sample.invalid/tts?key={{source.getKey()}}&value={{source.variable}}&cache={{cache.get('body')}}"
            let request = try HttpTtsSynthesizer.makeRequest(source: source, text: "正文", speed: 1, store: store)
            let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
            emit("tts_bridge_request_consumes_state", ["httpTts_42", "request", "cached", "from-library"],
                [query.first { $0.name == "key" }?.value ?? "", query.first { $0.name == "value" }?.value ?? "",
                 query.first { $0.name == "cache" }?.value ?? "", request.value(forHTTPHeaderField: "X-Fixed") ?? ""])
            source.jsLib = nil
            let action = try HttpTtsWebSocketAction.evaluate(frame: .init(data: Data("frame".utf8), isText: true),
                script: "source.put('ws','saved');({audio:'QUJD',done:source.variable==='request'})",
                stateJSON: nil, source: source, text: "正文", speed: 1, runtimeStore: store)
            emit("tts_bridge_websocket_shared_state", ["ABC", "true", "saved"],
                [String(decoding: action.audio ?? Data(), as: UTF8.self), String(action.done), store.value(for: "ws", sourceID: 42) ?? ""])
            emit("tts_bridge_setup", ["成功"], ["成功"])
        } catch { emit("tts_bridge_setup", ["成功"], [error.localizedDescription]) }
    }
}
