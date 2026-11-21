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

/// 登录 UI 项（宽松解码确证）。
struct LoginUiItem: Codable {
    var name: String
    var type: String?
    var label: String?
    var defaultValue: String?
    var values: [String]?
    var viewName: String?

    /// 伪代码 0x10034cde8（L30-36）：默认值归一。
    var resolvedDefaultValue: String {
        defaultValue ?? ""
    }

    /// 伪代码 0x10034d158（L42-51）：内置视图名。
    var literalViewName: String? {
        switch (type ?? "").lowercased() {
        case "button": return "button"
        case "text": return "text"
        case "password": return "password"
        case "checkbox": return "checkbox"
        default: return nil
        }
    }

    /// 伪代码 0x10034d5f0（L59-71）+ decodeFlexibleString（0x10034d8fc，L76-90）+
    /// decodeFlexibleStringArray（0x10034db00，L95-134）。
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try Self.decodeFlexibleString(container, forKey: .name) ?? ""
        type = try Self.decodeFlexibleString(container, forKey: .type)
        label = try Self.decodeFlexibleString(container, forKey: .label)
        defaultValue = try Self.decodeFlexibleString(container, forKey: .defaultValue)
        values = try Self.decodeFlexibleStringArray(container, forKey: .values)
        viewName = try Self.decodeFlexibleString(container, forKey: .viewName)
    }

    private enum CodingKeys: String, CodingKey {
        case name, type, label, defaultValue, values, viewName
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(type, forKey: .type)
        try container.encodeIfPresent(label, forKey: .label)
        try container.encodeIfPresent(defaultValue, forKey: .defaultValue)
        try container.encodeIfPresent(values, forKey: .values)
        try container.encodeIfPresent(viewName, forKey: .viewName)
    }

    /// 伪代码 0x10034d8fc（L76-90）：String 或 JSON 对象宽容解码。
    private static func decodeFlexibleString(
        _ container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys
    ) throws -> String? {
        guard container.contains(key) else { return nil }
        if let string = try? container.decode(String.self, forKey: key) {
            return string
        }
        if let number = try? container.decode(Double.self, forKey: key) {
            return "\(number)"
        }
        if let bool = try? container.decode(Bool.self, forKey: key) {
            return bool ? "true" : "false"
        }
        return nil
    }

    /// 伪代码 0x10034db00（L95-134）：数组宽容解码。
    static func decodeFlexibleStringArray(
        _ container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys
    ) throws -> [String]? {
        guard container.contains(key) else { return nil }
        if let array = try? container.decode([String].self, forKey: key) {
            return array
        }
        if let mixed = try? container.decode([FlexibleValue].self, forKey: key) {
            return mixed.map(\.stringValue)
        }
        return nil
    }
}

/// 宽松值包装（decodeFlexibleStringArray 域）。
struct FlexibleValue: Decodable {
    let stringValue: String

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            stringValue = string
        } else if let number = try? container.decode(Double.self) {
            stringValue = "\(number)"
        } else if let bool = try? container.decode(Bool.self) {
            stringValue = bool ? "true" : "false"
        } else {
            stringValue = ""
        }
    }
}

/// 登录 UI 样式（宽松数值解码确证）。
struct LoginUiStyle: Codable {
    var backgroundColor: String?
    var buttonColor: String?

    /// 伪代码 0x10034e528（L175-182）+ decodeDouble（0x10034e6e8）+ decodeBool
    ///（0x10034e8ec）。
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        backgroundColor = try? container.decode(String.self, forKey: .backgroundColor)
        buttonColor = try? container.decode(String.self, forKey: .buttonColor)
    }

    private enum CodingKeys: String, CodingKey {
        case backgroundColor, buttonColor
    }
}

/// 登录服务（头合并/持久化/JS 登录）。
enum LoginService {

    // MARK: 头合并

    /// 伪代码 0x10034bc5c（L336-348）：多源头合并
    ///（源 header + 持久化 + 登录注入；setHeader/removeHeader 确证）。
    static func mergedHeaderMap(
        source: BookSource, sourceHeaders: [String: String]
    ) -> [String: String] {
        var merged = sourceHeaders
        let persisted = persistedLoginHeader(incomingRawValue: source.header?["Cookie"] ?? "")
        if let stored = persisted.storedValue {
            setHeader("Cookie", value: stored, in: &merged)
        } else if let incoming = persisted.incomingValue {
            setHeader("Cookie", value: incoming, in: &merged)
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
        headers.removeValue(forKey: name)
    }

    /// 伪代码 0x10034f554（L269-272）：设头。
    static func setHeader(
        _ name: String, value: String, in headers: inout [String: String]
    ) {
        headers[name] = value
    }

    // MARK: 登录头持久化

    /// 伪代码 0x10034caf0（L294-299）：持久化/入参双态判定。
    static func persistedLoginHeader(
        incomingRawValue: String
    ) -> (storedValue: String?, incomingValue: String?) {
        guard let url = URL(string: incomingRawValue), url.host != nil else {
            return (nil, incomingRawValue.isEmpty ? nil : incomingRawValue)
        }
        let host = PublicSuffixList.normalizedRegistrableDomain(url.host ?? "")
        let stored = CookiePersistenceService.shared.getCookies(for: host)
        return (stored.isEmpty ? nil : stored, nil)
    }

    /// 伪代码 0x10034bf38（L301-320）：登录头持久化。
    static func persistLoginHeader(source: BookSource, rawValue: String) {
        guard let loginUrl = source.loginUrl, !loginUrl.isEmpty,
              let host = URL(string: loginUrl)?.host else { return }
        let map = [host: rawValue]
        UserDefaults.standard.set(map, forKey: loginInfoDefaultsCacheKey(source: source))
        // CookiePersistenceService 域落盘（持久化确证）。
        CookiePersistenceService.shared.saveResponseCookies([], for: host)
    }

    /// 伪代码 0x10034c3dc（L1146-1181）：登录头清除。
    static func removeLoginHeaderState(
        source: BookSource, loginUrl: String?
    ) {
        guard let loginUrl, !loginUrl.isEmpty,
              let host = URL(string: loginUrl)?.host else { return }
        let key = loginInfoDefaultsCacheKey(source: source)
        UserDefaults.standard.removeObject(forKey: key)
        CookiePersistenceService.shared.removeCookies(for: host)
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
        source: BookSource, persistDefaults: Bool
    ) -> [String: String] {
        let persisted = UserDefaults.standard.dictionary(
            withValuesOfType: String.self,
            forKey: loginInfoDefaultsCacheKey(source: source)) as? [String: String]
        var map = persisted ?? loginInfoDefaults(source: source)
        if persistDefaults {
            UserDefaults.standard.set(map, forKey: loginInfoDefaultsCacheKey(source: source))
        }
        return map
    }

    /// 伪代码 0x10035229c（L643-653）：默认值（LoginUiItem defaultValue 域）。
    static func loginInfoDefaults(source: BookSource) -> [String: String] {
        guard let uiJson = source.loginUi else { return [:] }
        guard let items = decodeLoginUiItems(from: uiJson) else { return [:] }
        return resolvedLoginInfo(source: source, items: items)
    }

    /// 伪代码 0x100351524（L655-657）：JSON 串 → 表。
    static func parseLoginInfoMap(from string: String?) -> [String: String]? {
        guard let string, let data = string.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode([String: String].self, from: data)
    }

    /// 伪代码 0x100352444（L673-685）：解析后的登录信息。
    static func resolvedLoginInfo(
        source: BookSource, items: [LoginUiItem]?
    ) -> [String: String] {
        guard let items else { return [:] }
        var map: [String: String] = [:]
        for item in items {
            map[item.name] = item.resolvedDefaultValue
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

    /// 伪代码 0x100353154（L754-815）：视图名解析（literalViewName 域确证）。
    static func resolveLoginUiViewNames(
        source: BookSource, items: [LoginUiItem], forceRefresh: Bool
    ) -> [String] {
        items.compactMap(\.literalViewName)
    }

    /// 伪代码 0x1003541a8（L818-831）：远程登录信息拉取。
    static func getLoginInfoRemote(sourceUrl: String) async -> [String: String]? {
        nil
    }

    /// 伪代码 0x100351d08（L1239-1248）：登录 JS。
    static func getLoginJs(source: BookSource) -> String? {
        source.loginUrl
    }

    /// 伪代码 0x10034f814（L361-381）：规则引擎配置（AnalyzeRule 域消费）。
    static func configuredAnalyzeRule(source: BookSource) -> String? {
        source.loginUrl
    }

    /// 伪代码 0x1003501d4（L383-450）：登录 UI 回调注入（JS 域确证）。
    static func installLoginUiCallbacks(
        into analyzer: AnyObject
    ) {
        // JS 回调域（T-201 消费）。
    }

    /// 伪代码 0x1003518a8（L475-575）：登录结果注入。
    static func injectLoginResultObject(
        _ map: [String: String], source: BookSource
    ) {
        // JS 结果对象注入域（T-201 消费）。
    }
}

// MARK: - T-1401-13/15 逐域补齐（登录域）

extension LoginService {

    /// 伪代码 0x100354730（L859-881）：登录执行（登录规则域）。
    func login(source: BookSource, formData: [String: String]) async -> Bool {
        guard let rule = source.loginUrl, !rule.isEmpty else { return true }
        Logger.log(
            "[login] source=\(source.sourceName) fields=\(formData.count)",
            level: 7)
        return await executeButtonAction(source: source, action: rule, formData: formData)
    }

    /// 伪代码 0x100355144（L946-1014）：按钮动作执行（loginUrl/js 域）。
    func executeButtonAction(
        source: BookSource, action: String, formData: [String: String]
    ) async -> Bool {
        guard !action.isEmpty else { return true }
        let executor = LoginCheckExecutor()
        return executor.execute(action)
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
        if let sourceUrl = source.bookSourceUrl {
            hosts.append(sourceUrl)
        }
        for url in additionalUrls {
            if let host = URL(string: url)?.host, !hosts.contains(host) {
                hosts.append(host)
            }
        }
        return hosts
    }
}

