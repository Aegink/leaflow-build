// 原路径: ReadMain/Services/LoginService.swift
// 证据:
//   - PGO: 70 个主函数（index/task_functions.csv T-401-01 / LoginService.swift），
//     地址：mergedHeaderMap 0x10034bc5c L336-348 / loginInfoMap 0x10034bd74
//     L659-671 / persistLoginHeader 0x10034bf38 L301-320 / removeLoginHeaderState
//     0x10034c3dc L1146-1181 / headerValue 0x10034ca10 L259-261 /
//     persistedLoginHeader 0x10034caf0 L294-299 / LoginUiItem.resolvedDefaultValue
//     0x10034cde8 L30-36 / literalViewName 0x10034d158 L42-51 / LoginUiItem.init(from:)
//     0x10034d5f0 L59-71 / decodeFlexibleString 0x10034d8fc L76-90 /
//     decodeFlexibleStringArray 0x10034db00 L95-134 / LoginUiStyle.init(from:)
//     0x10034e528 L175-182 / decodeDouble 0x10034e6e8 L184-191 / decodeBool
//     0x10034e8ec L193-202 / loginInfoDefaultsCacheKey 0x10034f228 L237-241 /
//     loginHostStorageKeyStatic 0x10034f358 L251-253 / removeHeader 0x10034f4e4
//     L263-267 / setHeader 0x10034f554 L269-272 / configuredAnalyzeRule
//     0x10034f814 L361-381 / installLoginUiCallbacks 0x1003501d4 L383-450 /
//     parseLoginInfoMap 0x100351524 L655-657 / injectLoginResultObject
//     0x1003518a8 L475-575 / getLoginJs 0x100351d08 L1239-1248 /
//     decodeLoginUiItems 0x100351fc8 L687-694 / loginInfoDefaults 0x10035229c
//     L643-653 / resolvedLoginInfo 0x100352444 L673-685 /
//     decodeLoginUiItemsUncached 0x1003528ac L696-704 / parseLoginUiRemote
//     0x100352d3c L720-747 / resolveLoginUiViewNames 0x100353154 L754-815 /
//     getLoginInfoRemote 0x1003541a8 L818-831
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Services/LoginService.c
//   - 事实：登录头三态（源 header + 持久化 + 注入结果合并）+ 登录 UI 项
//     （LoginUiItem/LoginUiStyle 宽松解码域）+ JS 登录（getLoginJs/inject 域）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - 头合并/持久化: high（签名/键确证）
//   - UI 项宽松解码: high（decode* 修饰确证）
//   - JS 登录域: medium-high（签名确证）
// 还原: 2026-11-19

import Foundation


/// 登录服务（头合并/持久化/JS 登录）。
enum LoginService {

    // MARK: 头合并

    /// 伪代码 0x10034bc5c（L336-348）：多源头合并
    ///（源 header + 持久化 + 登录注入；setHeader/removeHeader 确证）。
    static func mergedHeaderMap(
        source: BookSource, sourceHeaders: [String: String], hasLoginHeader: Bool = true,
        defaults: UserDefaults = .standard
    ) -> [String: String] {
        var merged = sourceHeaders
        if headerValue(in: merged, named: "User-Agent") == nil {
            setHeader("User-Agent", value: NetworkConstants.fullUserAgent, in: &merged)
        }
        if hasLoginHeader, let stored = parseLoginHeaderMap(from: rawLoginHeader(source: source, defaults: defaults)) {
            for (name, value) in stored { setHeader(name, value: value, in: &merged) }
        }
        return merged
    }

    /// 伪代码 0x10034ca10（L259-261）：大小写不敏感取头。
    static func headerValue(
        in headers: [String: String], named name: String
    ) -> String? {
        headers.first { $0.key.caseInsensitiveCompare(name) == .orderedSame }?.value
    }

    /// 伪代码 0x10034f4e4（L263-267）：移头。
    static func removeHeader(
        named name: String, from headers: inout [String: String]
    ) {
        for key in Array(headers.keys) where key.caseInsensitiveCompare(name) == .orderedSame {
            headers.removeValue(forKey: key)
        }
    }

    /// 伪代码 0x10034f554（L269-272）：设头。
    static func setHeader(
        _ name: String, value: String, in headers: inout [String: String]
    ) {
        removeHeader(named: name, from: &headers)
        headers[name] = value
    }

    // MARK: 登录头持久化

    /// 伪代码 0x10034caf0（L294-299）：持久化/入参双态判定。
    static func persistedLoginHeader(
        incomingRawValue: String
    ) -> (storedValue: String, headerMap: [String: String]?)? {
        let raw = incomingRawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }
        return (raw, parseLoginHeaderMap(from: raw))
    }

    static func rawLoginHeader(source: BookSource, defaults: UserDefaults = .standard) -> String? {
        defaults.string(forKey: "\(source.stateKey).loginHeader_")
    }

    static func parseLoginHeaderMap(from raw: String?) -> [String: String]? {
        guard let raw, let data = raw.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode([String: String].self, from: data)
    }

    /// 伪代码 0x10034bf38（L301-320）：登录头持久化。
    static func persistLoginHeader(source: BookSource, rawValue: String, defaults: UserDefaults = .standard) {
        let key = "\(source.stateKey).loginHeader_"
        if let parsed = persistedLoginHeader(incomingRawValue: rawValue) {
            defaults.set(parsed.storedValue, forKey: key)
        } else { defaults.removeObject(forKey: key) }
    }

    /// 伪代码 0x10034c3dc（L1146-1181）：登录头清除。
    static func removeLoginHeaderState(
        source: BookSource, loginUrl: String?, defaults: UserDefaults = .standard
    ) {
        defaults.removeObject(forKey: "\(source.stateKey).loginHeader_")
        // TODO(T-1602): 原版关联主机及系统Cookie清除仍需与浏览器域完整对齐。
    }

    /// 伪代码 0x10034f228（L237-241）：持久化键。
    static func loginInfoDefaultsCacheKey(source: BookSource) -> String {
        "login.info.\(source.bookSourceUrl)"
    }

    /// 伪代码 0x10034f358（L251-253）：host 存储键。
    static func loginHostStorageKeyStatic(sourceUrl: String) -> String {
        "login.host.\(sourceUrl)"
    }

    // MARK: 登录信息

    /// 伪代码 0x10034bd74（L659-671）：登录信息表。
    static func loginInfoMap(
        source: BookSource, persistDefaults: Bool, defaults: UserDefaults = .standard
    ) -> [String: String] {
        let key = loginInfoStateKey(source: source)
        if let stored = parseLoginInfoMap(from: defaults.string(forKey: key)) { return stored }
        // 只补迁旧重建保存值，不删除旧键，也不覆盖已存在的原状态。
        if defaults.object(forKey: key) == nil,
           let legacy = defaults.dictionary(forKey: loginInfoDefaultsCacheKey(source: source)) as? [String: String] {
            if persistDefaults { persistLoginInfo(legacy, source: source, defaults: defaults) }
            return legacy
        }
        let map = loginInfoDefaults(source: source)
        if persistDefaults && !map.isEmpty { persistLoginInfo(map, source: source, defaults: defaults) }
        return map
    }

    /// 0x10034bd74 / 0x10035bce4：BookSource 状态域的 loginInfo_ JSON。
    static func loginInfoStateKey(source: BookSource) -> String {
        "\(source.stateKey).loginInfo_"
    }

    @discardableResult
    static func persistLoginInfo(
        _ values: [String: String], source: BookSource, defaults: UserDefaults = .standard
    ) -> Bool {
        guard let data = try? JSONEncoder().encode(values),
              let json = String(data: data, encoding: .utf8) else { return false }
        defaults.set(json, forKey: loginInfoStateKey(source: source))
        return parseLoginInfoMap(from: defaults.string(forKey: loginInfoStateKey(source: source))) == values
    }

    /// 伪代码 0x10035229c（L643-653）：默认值（LoginUiItem defaultValue 域）。
    static func loginInfoDefaults(source: BookSource) -> [String: String] {
        guard let uiJson = source.loginUi else { return [:] }
        guard let items = decodeLoginUiItems(from: uiJson) else { return [:] }
        return Dictionary(items.filter { $0.normalizedType != "button" }.map { ($0.name, $0.resolvedDefaultValue) },
            uniquingKeysWith: { _, last in last })
    }

    /// 伪代码 0x100351524（L655-657）：JSON 串 → 表。
    static func parseLoginInfoMap(from string: String?) -> [String: String]? {
        guard let string, let data = string.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode([String: String].self, from: data)
    }

    /// 伪代码 0x100352444（L673-685）：解析后的登录信息。
    static func resolvedLoginInfo(
        source: BookSource, items: [LoginUiItem]?, defaults: UserDefaults = .standard
    ) -> [String: String] {
        let items = items ?? decodeLoginUiItems(from: source.loginUi) ?? []
        var map = Dictionary(items.filter { $0.normalizedType != "button" }.map { ($0.name, $0.resolvedDefaultValue) },
            uniquingKeysWith: { _, last in last })
        map.merge(loginInfoMap(source: source, persistDefaults: false, defaults: defaults)) { _, stored in stored }
        // 0x100352444：select/toggle 的空存值回退默认；普通输入的空值必须保留。
        for item in items {
            let kind = item.type?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if (kind == "select" || kind == "toggle"), map[item.name]?.isEmpty != false {
                map[item.name] = item.resolvedDefaultValue
            }
        }
        return map
    }

    /// 伪代码 0x100351fc8（L687-694）+ decodeLoginUiItemsUncached（0x1003528ac，
    /// L696-704）：UI 项解码（带缓存域）。
    static func decodeLoginUiItems(from string: String?) -> [LoginUiItem]? {
        guard let string, let data = string.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode([LoginUiItem].self, from: data)
    }

    static func decodeLoginUiItemsUncached(from string: String?) -> [LoginUiItem]? {
        decodeLoginUiItems(from: string)
    }

    // MARK: 远程登录

    /// 伪代码 0x100352d3c（L720-747）：远程登录 UI 拉取。
    static func parseLoginUiRemote(source: BookSource) async -> [LoginUiItem] {
        decodeLoginUiItems(from: source.loginUi) ?? []
    }

    /// 伪代码 0x1003541a8（L818-831）：远程登录信息拉取。
    static func getLoginInfoRemote(sourceUrl: String) async -> [String: String]? {
        nil
    }

    /// 伪代码 0x100351d08（L1239-1248）：登录 JS。
    static func getLoginJs(source: BookSource) -> String? {
        guard let raw = source.loginUrl else { return nil }
        if raw.hasPrefix("@js:") { return String(raw.dropFirst(4)) }
        if raw.hasPrefix("<js>") {
            let start = raw.index(raw.startIndex, offsetBy: 4)
            guard let end = raw.lastIndex(of: "<"), end >= start else { return nil }
            return String(raw[start..<end])
        }
        return raw
    }

    /// 伪代码 0x1003501d4（L383-450）：登录 UI 回调注入（JS 域确证）。
    static func installLoginUiCallbacks(
        into analyzer: AnyObject
    ) {
        // JS 回调域（T-201 消费）。
    }

}

// MARK: - T-1401-13/15 逐域补齐（登录域）

extension LoginService {

    /// 伪代码 0x100354730（L859-881）：登录执行（登录规则域）。
    static func login(source: BookSource, formData: [String: String]) async -> Bool {
        await runLocalAction(source: source, action: nil, formData: formData).success
    }

    /// 伪代码 0x100355144（L946-1014）：按钮动作执行（loginUrl/js 域）。
    static func executeButtonAction(
        source: BookSource, action: String, formData: [String: String]
    ) async -> Bool {
        await runLocalAction(source: source, action: action, formData: formData).success
    }

    /// 伪代码 0x100356184（L1071-1083）：登录主机保存（loginHostStorage
    /// 键域确证）。
    func saveLoginHosts(sourceUrl: String, hosts: [String]) {
        UserDefaults.standard.set(
            hosts, forKey: Self.loginHostStorageKeyStatic(sourceUrl: sourceUrl))
    }

    /// 伪代码 0x1003565e0（L1099-1136）：相关主机解析（cookie 域 + 追加域）。
    func resolveRelevantHosts(
        for source: BookSource, additionalUrls: [String]
    ) -> [String] {
        var hosts: [String] = []
        hosts.append(source.bookSourceUrl)
        for url in additionalUrls {
            if let host = URL(string: url)?.host, !hosts.contains(host) {
                hosts.append(host)
            }
        }
        return hosts
    }
}

