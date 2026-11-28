// 原路径: ReadMain/Services/ReadAloud/HttpTtsRuntimeStore.swift
// 证据:
//   - PGO: 26 条记录（index/task_functions.csv T-801-06 /
//     HttpTtsRuntimeStore.swift；伪代码域 180 行）
//   - CovMap: 上述 L 区段（loginInfo L9-11 / sourceVariable L109-111 /
//     cacheKey/loginHeaderKey/loginInfoKey/sourceVariableKey 域）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Services/ReadAloud/
//     HttpTtsRuntimeStore.c（525 行）
//   - 块体确证（签名域）：
//     loginInfo(sourceID: Int64) -> String? / sourceVariable(sourceID:)
//     -> String? / cacheKey(_: String, sourceID: Int64) /
//     loginHeaderKey(Int64) / loginInfoKey(Int64) /
//     sourceVariableKey(Int64) / set(_: String?, forKey: String) /
//     setMap(_: ...) / decodeMap(String?) / loginInfoMap(sourceID:) /
//     setCacheValue(_:for:sourceID:) / setLoginHeader(_:sourceID:) /
//     setLoginHeaderMap(_:...) / setLoginInfo(_:sourceID:) /
//     setLoginInfoMap(_:...) / setSourceVariable(_:sourceID:) /
//     setValue(_:for:sourceID:) / value(for:sourceID:)
//   - 0x10026cb08/0x10026d104/0x10026d170及0x10026d20c确证原版键，
//     value与cache分域；旧重建键仅在缺失时迁入。
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（十七签名域确证）
// 还原: 2026-11-20

import Foundation

/// 朗读源运行时存储（loginInfo/sourceVariable 签名域确证：
/// UserDefaults 键域桥）。
final class HttpTtsRuntimeStore {

    static let shared = HttpTtsRuntimeStore()

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    /// loginInfo(sourceID:)（0x 域 L9-11 确证）。
    func loginInfo(sourceID: Int64) -> String? {
        read(Self.loginInfoKey(sourceID), legacy: "tts_login_info_\(sourceID)")
    }

    /// setLoginInfo(_:sourceID:)（签名域确证）。
    func setLoginInfo(_ value: String?, sourceID: Int64) {
        set(value, forKey: Self.loginInfoKey(sourceID))
        defaults.removeObject(forKey: "tts_login_info_\(sourceID)")
    }

    /// loginInfoMap(sourceID:)（签名域确证：JSON map 解码）。
    func loginInfoMap(sourceID: Int64) -> [String: String] {
        decodeMap(loginInfo(sourceID: sourceID))
    }

    /// setLoginInfoMap(_:)（签名域确证）。
    func setLoginInfoMap(_ map: [String: String], sourceID: Int64) {
        setMap(map) { encoded in
            setLoginInfo(encoded, sourceID: sourceID)
        }
    }

    /// loginHeader(sourceID:)（loginHeaderKey 域确证）。
    func loginHeader(sourceID: Int64) -> String? {
        read(Self.loginHeaderKey(sourceID), legacy: "tts_login_header_\(sourceID)")
    }

    /// setLoginHeader(_:sourceID:)（签名域确证）。
    func setLoginHeader(_ value: String?, sourceID: Int64) {
        set(value, forKey: Self.loginHeaderKey(sourceID))
        defaults.removeObject(forKey: "tts_login_header_\(sourceID)")
    }

    /// setLoginHeaderMap(_:)（签名域确证）。
    func setLoginHeaderMap(
        _ map: [String: String], sourceID: Int64
    ) {
        setMap(map) { encoded in
            setLoginHeader(encoded, sourceID: sourceID)
        }
    }

    /// sourceVariable(sourceID:)（0x 域 L109-111 确证）。
    func sourceVariable(sourceID: Int64) -> String? {
        read(Self.sourceVariableKey(sourceID), legacy: "tts_source_variable_\(sourceID)")
    }

    /// setSourceVariable(_:sourceID:)（签名域确证）。
    func setSourceVariable(_ value: String?, sourceID: Int64) {
        set(value, forKey: Self.sourceVariableKey(sourceID))
        defaults.removeObject(forKey: "tts_source_variable_\(sourceID)")
    }

    /// value(for:sourceID:)（签名域确证：cache_<sourceID>_<key> 键）。
    func value(for key: String, sourceID: Int64) -> String? {
        migrateLegacyValue(key, sourceID: sourceID)
        return defaults.string(forKey: "v_httpTts_\(sourceID)_\(key)")
    }

    /// setValue(_:for:sourceID:)（签名域确证）。
    func setValue(_ value: String?, for key: String, sourceID: Int64) {
        migrateLegacyValue(key, sourceID: sourceID)
        set(value, forKey: "v_httpTts_\(sourceID)_\(key)")
    }

    /// setCacheValue(_:for:sourceID:)（签名域确证：value 别名）。
    func setCacheValue(
        _ value: String?, for key: String, sourceID: Int64
    ) {
        migrateLegacyValue(key, sourceID: sourceID)
        set(value, forKey: cacheKey(key, sourceID: sourceID))
    }

    func cacheValue(for key: String, sourceID: Int64) -> String? {
        migrateLegacyValue(key, sourceID: sourceID)
        return defaults.string(forKey: cacheKey(key, sourceID: sourceID))
    }

    /// 旧版误把两域合并，迁移先补缺失域，之后分别更新或清除。
    private func migrateLegacyValue(_ key: String, sourceID: Int64) {
        let legacy = "tts_cache_\(sourceID)_\(key)"
        guard let value = defaults.string(forKey: legacy) else { return }
        for target in ["v_httpTts_\(sourceID)_\(key)", cacheKey(key, sourceID: sourceID)]
            where defaults.object(forKey: target) == nil {
            defaults.set(value, forKey: target)
        }
        defaults.removeObject(forKey: legacy)
    }

    // MARK: 键域（cacheKey/loginHeaderKey/loginInfoKey/sourceVariableKey
    // 签名域确证）

    /// cacheKey(_:sourceID:)（签名域确证）。
    func cacheKey(_ key: String, sourceID: Int64) -> String {
        "ttsCache_\(sourceID)_\(key)"
    }

    /// loginHeaderKey(Int64)（签名域确证）。
    static func loginHeaderKey(_ sourceID: Int64) -> String {
        "loginHeader_httpTts_\(sourceID)"
    }

    /// loginInfoKey(Int64)（签名域确证）。
    static func loginInfoKey(_ sourceID: Int64) -> String {
        "loginInfo_httpTts_\(sourceID)"
    }

    /// sourceVariableKey(Int64)（0x 域 L494 确证）。
    static func sourceVariableKey(_ sourceID: Int64) -> String {
        "sourceVariable_httpTts_\(sourceID)"
    }

    // MARK: 内部域（set/decodeMap/setMap 签名域确证）

    private func set(_ value: String?, forKey key: String) {
        defaults.set(value, forKey: key)
    }

    private func read(_ key: String, legacy: String) -> String? {
        if let value = defaults.string(forKey: key) { return value }
        guard let value = defaults.string(forKey: legacy) else { return nil }
        defaults.set(value, forKey: key)
        return value
    }

    /// decodeMap(String?)（签名域确证：JSON map 解码域）。
    private func decodeMap(_ json: String?) -> [String: String] {
        guard let json, let data = json.data(using: .utf8),
              let map = try? JSONDecoder().decode(
                [String: String].self, from: data) else {
            return [:]
        }
        return map
    }

    /// setMap(_:)（签名域确证：JSON 编码写入桥）。
    private func setMap(
        _ map: [String: String], write: (String) -> Void
    ) {
        guard let data = try? JSONEncoder().encode(map),
              let json = String(data: data, encoding: .utf8) else {
            return
        }
        write(json)
    }
}

// MARK: - T-1401-15/16 逐域补齐（运行时存储域）

extension HttpTtsRuntimeStore {

    /// 伪代码 0x1000f27f4（L32-34）：登录头映射读取。
    func loginHeaderMap(sourceID: Int64) -> [String: String] {
        decodeMap(loginHeader(sourceID: sourceID))
    }

    /// 伪代码 0x10026d320（L68-71）：认证清除（登录信息 + 头域）。
    func clearAuthentication(sourceID: Int64) {
        setLoginInfo(nil, sourceID: sourceID)
        setLoginHeader(nil, sourceID: sourceID)
    }

    /// 0x10026d320实际块：认证、变量及该源value/cache前缀清除，保留其他源。
    func clearAll(sourceID: Int64) {
        clearAuthentication(sourceID: sourceID)
        setSourceVariable(nil, sourceID: sourceID)
        let prefixes = ["v_httpTts_\(sourceID)_", "ttsCache_\(sourceID)_", "tts_cache_\(sourceID)_"]
        for key in defaults.dictionaryRepresentation().keys where prefixes.contains(where: { key.hasPrefix($0) }) {
            defaults.removeObject(forKey: key)
        }
    }

    /// 伪代码 0x10026cb74（L73-85）：全量清除——已知源注册表遍历域
    ///（UserDefaults 键前缀扫描域）。
    func clearAll() {
        let prefixes = ["loginInfo_httpTts_", "loginHeader_httpTts_", "sourceVariable_httpTts_",
            "v_httpTts_", "ttsCache_", "tts_login_info_", "tts_login_header_", "tts_source_variable_", "tts_cache_"]
        for key in defaults.dictionaryRepresentation().keys where prefixes.contains(where: { key.hasPrefix($0) }) {
            defaults.removeObject(forKey: key)
        }
        defaults.removeObject(forKey: "httptts_known_source_ids")
    }

}

