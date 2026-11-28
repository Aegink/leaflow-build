// T-1602：原配置行解析、默认选择与真实loginUrl动作，隔离状态和缓存。
import Foundation

enum HttpTtsConfigurationActionSelfTest {
    static var fixture: HttpTts {
        HttpTts(numericId: 1602005, name: "固定配置源", url: "https://sample.invalid/tts",
            loginUrl: "function saveConfig(){var info=source.getLoginInfoMap();info.status=result.account+'-saved';source.putLoginInfo(JSON.stringify(info));java.toast('配置已执行');}",
            loginUi: #"[{"name":"account","type":"text","viewName":"'账号'","default":""},{"name":"voice","type":"select","chars":["A","B"],"default":"B"},{"name":"switch","type":"toggle","chars":["on","off"],"default":"off"},{"name":"status","type":"text"},{"name":"apply","type":"button","viewName":"'执行配置'","action":"saveConfig()"}]"#)
    }

    static func run(emit: (String, [String], [String]) -> Void) {
        let suite = "tts-config-action-\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = HttpTtsRuntimeStore(defaults: defaults), cache = HttpTtsAudioCache()
        var source = fixture
        do {
            let rows = try TtsRowUi.parse(source.loginUi!)
            emit("tts_config_rows_original_fields", ["5", "账号", "B", "saveConfig()"],
                [String(rows.count), rows[0].displayName, rows[1].defaultValue ?? "", rows[4].action ?? ""])
            let initial = TtsRowUi.selections(rows: rows, stored: ["account": "", "voice": "", "switch": "on", "foreign": "keep"])
            emit("tts_config_selection_defaults_and_preservation", ["", "B", "on", "keep", "false"],
                [initial["account"] ?? "缺失", initial["voice"] ?? "", initial["switch"] ?? "", initial["foreign"] ?? "", String(initial["apply"] != nil)])
            let message = try LoginCheckExecutor.executeTTSConfigurationAction("saveConfig()", source: source,
                values: ["account": "fixed"], runtimeStore: store, audioCache: cache)
            emit("tts_config_action_login_script_and_result", ["配置已执行", "fixed", "fixed-saved"],
                [message ?? "", store.loginInfoMap(sourceID: source.id)["account"] ?? "", store.loginInfoMap(sourceID: source.id)["status"] ?? ""])
            let cold = HttpTtsRuntimeStore(defaults: defaults)
            emit("tts_config_action_state_cold_read", ["fixed-saved"], [cold.loginInfoMap(sourceID: source.id)["status"] ?? ""])
            let other = HttpTts(numericId: 999, name: "其他源", url: source.url)
            cache.insert(Data([1]), source: source, text: "正文", speechRate: 1)
            cache.insert(Data([2]), source: other, text: "正文", speechRate: 1)
            _ = try LoginCheckExecutor.executeTTSConfigurationAction("java.clearTtsCache()", source: source,
                values: [:], runtimeStore: store, audioCache: cache)
            emit("tts_config_action_clear_cache_scoped", ["1", "true"],
                [String(cache.count), String(cache.data(source: other, text: "正文", speechRate: 1) != nil)])
            source.jsLib = "function libraryValue(){return 'library';}"
            let library = try LoginCheckExecutor.executeTTSConfigurationAction("java.toast(libraryValue())", source: source,
                values: [:], runtimeStore: store, audioCache: cache)
            emit("tts_config_action_library_context", ["library"], [library ?? ""])
            var rejected = false
            do { _ = try LoginCheckExecutor.executeTTSConfigurationAction("throw Error('拒绝')", source: source,
                values: [:], runtimeStore: store, audioCache: cache) } catch { rejected = true }
            emit("tts_config_action_exception_surfaces", ["true"], [String(rejected)])
            source.jsLib = "throw Error('库拒绝')"
            rejected = false
            do { _ = try LoginCheckExecutor.executeTTSConfigurationAction("source.put('should-not-write','bad')", source: source,
                values: [:], runtimeStore: store, audioCache: cache) } catch { rejected = true }
            emit("tts_config_action_library_failure_no_action", ["true", "true"],
                [String(rejected), String(store.value(for: "should-not-write", sourceID: source.id) == nil)])
            source.jsLib = nil
            let isolation = try LoginCheckExecutor.executeTTSConfigurationAction("java.toast(typeof libraryValue)", source: source,
                values: [:], runtimeStore: store, audioCache: cache)
            emit("tts_config_action_context_isolation", ["undefined"], [isolation ?? ""])
            emit("tts_config_action_setup", ["成功"], ["成功"])
        } catch { emit("tts_config_action_setup", ["成功"], [error.localizedDescription]) }
    }
}
