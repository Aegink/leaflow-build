// 原路径: ReadMain/Services/CookiePersistenceService.swift
// 证据:
//   - PGO: 49 个主函数（index/task_functions.csv T-401-01 / CookiePersistenceService.swift），
//     地址：saveResponseCookies 0x1003043fc L181-216 / getCookies 0x100304ddc
//     L88-101 / cookieHost 0x100305130 L506-513 / removeCookies 0x100305360
//     L389-432 / bridgeCookieHeader 0x1003057bc L105-152 / mergeCookieStrings
//     0x100305d2c L617-632 / extractCookieValue 0x10030624c L572-582 /
//     applyLegadoRedirectCookies 0x100306534 L360-368 / loadFromDisk 0x100308908
//     L470-483 / saveCookies(for: BookSource) 0x100308b90 L71-84 /
//     domainMatches 0x1003092c8 L488-499 / cookieDomainPrecedes 0x100309948
//     L545-557 / cookieMap 0x10030a280 L588-599 / removeCookieNames 0x10030aa04
//     L154-177 / saveToDisk 0x10030b0ec L659-668 / persistBrowserCookies
//     0x10030b9cc L250-304 / legadoRequestCookieHeader 0x10030c500 L315-341 /
//     setCookieJarRequestProperty 0x10030c924 L378-386 / normalizedCookieCache
//     0x10030d524 L515-527 / domainForms 0x10030d9bc L529-536
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Services/CookiePersistenceService.c
//   - 事实：cookie 三级持久化（UserDefaults 域 + 磁盘）+ 域匹配（domainForms
//     两种形态确证）+ legado 兼容头（legadoRequestCookieHeader 确证）+
//     合并（mergeCookieStrings 供 ReaderBrowserWebView 消费）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - 持久化/合并/域匹配: high（选择子/字面量确证）
//   - legado 兼容细节: medium-high（桥确证）
// 还原: 2026-11-19

import Foundation

/// cookie 持久化服务（域 → 键值表 → UserDefaults/磁盘）。
final class CookiePersistenceService {

    static let shared = CookiePersistenceService()

    private let defaults = UserDefaults.standard
    private let fileManager = FileManager.default
    /// 磁盘缓存目录（loadFromDisk/saveToDisk 确证）。
    private var storageDirectory: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return caches.appendingPathComponent("cookie_persistence", isDirectory: true)
    }
    /// UserDefaults 键前缀。
    private let keyPrefix = "cookie.host."

    init() {
        try? fileManager.createDirectory(
            at: storageDirectory, withIntermediateDirectories: true)
        loadFromDisk()
    }

    // MARK: 读写

    /// 伪代码 0x100304ddc（L88-101）：串形式读。
    func getCookies(for host: String) -> String {
        let map = cookieMap(from: defaults.dictionary(
            withValuesOfType: String.self, forKey: keyPrefix + host) ?? [:])
        return map.map { "\($0.key)=\($0.value)" }
            .sorted()
            .joined(separator: "; ")
    }

    /// 伪代码 0x1003043fc（L181-216）：响应 cookie 保存。
    func saveResponseCookies(_ cookies: [HTTPCookie], for host: String) {
        var map = defaults.dictionary(
            withValuesOfType: String.self,
            forKey: keyPrefix + host) as? [String: String] ?? [:]
        for cookie in cookies {
            map[cookie.name] = cookie.value
        }
        defaults.set(map, forKey: keyPrefix + host)
        saveToDisk()
    }

    /// 伪代码 0x10030aa04（L154-177）：按名删除。
    private func removeCookieNames(_ names: Set<String>, for host: String) {
        var map = defaults.dictionary(
            withValuesOfType: String.self,
            forKey: keyPrefix + host) as? [String: String] ?? [:]
        for name in names {
            map.removeValue(forKey: name)
        }
        defaults.set(map, forKey: keyPrefix + host)
        saveToDisk()
    }

    /// 伪代码 0x100305360（L389-432）：按 host 全删。
    func removeCookies(for host: String) {
        defaults.removeObject(forKey: keyPrefix + host)
        let forms = domainForms(host)
        for form in forms where form != host {
            defaults.removeObject(forKey: keyPrefix + form)
        }
        saveToDisk()
    }

    /// 伪代码 0x100308b90（L71-84）：书源 cookie 保存。
    func saveCookies(for source: BookSource) {
        // source.header 里的 Cookie 串合并（legado 域确证）。
        let header = LoginService.mergedHeaderMap(source: source, sourceHeaders: [source.header ?? ""])
        if let cookieHeader = header["Cookie"] {
            let map = cookieMap(from: cookieHeader)
            defaults.set(map, forKey: keyPrefix + source.bookSourceUrl)
            saveToDisk()
        }
    }

    // MARK: 桥

    /// 伪代码 0x1003057bc（L105-152）：WebView → 请求桥接。
    func bridgeCookieHeader(for host: String) -> String {
        let persisted = getCookies(for: host)
        if persisted.isEmpty {
            return ""
        }
        return persisted
    }

    /// 伪代码 0x10030c500（L315-341）：legado 请求头（Cookie 串确证）。
    func legadoRequestCookieHeader(
        requestHost: String?, source: BookSource
    ) -> String {
        var merged: [String: String] = [:]
        if let requestHost {
            for part in getCookies(for: requestHost).split(separator: ";") {
                let pair = part.split(separator: "=", maxSplits: 1)
                if pair.count == 2 {
                    merged[String(pair[0])] = String(pair[1])
                }
            }
        }
        let sourceCookies = source.header?["Cookie"] ?? ""
        for part in sourceCookies.split(separator: ";") {
            let pair = part.split(separator: "=", maxSplits: 1)
            if pair.count == 2 {
                merged[String(pair[0])] = String(pair[1])
            }
        }
        return merged.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: "; ")
    }

    /// 伪代码 0x100306534（L360-368）：legado 重定向 cookie 注入。
    func applyLegadoRedirectCookies(to request: inout URLRequest) {
        guard let host = request.url?.host else { return }
        let header = bridgeCookieHeader(for: host)
        if !header.isEmpty {
            request.setValue(header, forHTTPHeaderField: "Cookie")
        }
    }

    /// 伪代码 0x10030b9cc（L250-304）：浏览器 cookie 持久化。
    func persistBrowserCookies(
        _ cookies: [HTTPCookie], currentURL: URL?
    ) {
        let host = currentURL?.host ?? ""
        guard !host.isEmpty else { return }
        saveResponseCookies(cookies, for: host)
    }

    // MARK: 合并

    /// 伪代码 0x100305d2c（L617-632）：多串合并
    ///（ReaderBrowserWebView/T-304-05 消费确证）。
    static func mergeCookieStrings(_ strings: [String]) -> String {
        var merged: [String: String] = [:]
        for string in strings {
            for part in string.split(separator: ";") {
                let pair = part.split(separator: "=", maxSplits: 1)
                if pair.count == 2 {
                    let name = pair[0].trimmingCharacters(in: .whitespaces)
                    merged[name] = String(pair[1])
                }
            }
        }
        return merged.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: "; ")
    }

    /// 伪代码 0x10030624c（L572-582）：键取值。
    static func extractCookieValue(from string: String, key: String) -> String? {
        for part in string.split(separator: ";") {
            let pair = part.split(separator: "=", maxSplits: 1)
            if pair.count == 2,
               pair[0].trimmingCharacters(in: .whitespaces) == key {
                return String(pair[1])
            }
        }
        return nil
    }

    // MARK: 域

    /// 伪代码 0x100305130（L506-513）：URL → host。
    static func cookieHost(from url: String) -> String? {
        URL(string: url)?.host
    }

    /// 伪代码 0x1003092c8（L488-499）：域匹配（domainForms 两种形态确证）。
    static func domainMatches(_ host: String, _ domain: String) -> Bool {
        host == domain || host.hasSuffix("." + domain)
    }

    /// 伪代码 0x10030d9bc（L529-536）：host 两种形态。
    static func domainForms(_ host: String) -> [String] {
        [host, "." + host]
    }

    /// 伪代码 0x10030a280（L588-599）：串 → 键值表。
    private func cookieMap(from string: String) -> [String: String] {
        var map: [String: String] = [:]
        for part in string.split(separator: ";") {
            let pair = part.split(separator: "=", maxSplits: 1)
            if pair.count == 2 {
                map[String(pair[0])] = String(pair[1])
            }
        }
        return map
    }

    /// 伪代码 0x10030d524（L515-527）：表归一。
    private static func normalizedCookieCache(
        _ map: [String: String]
    ) -> [String: String] {
        map.filter { !$0.key.isEmpty && !$0.value.isEmpty }
    }

    // MARK: 磁盘

    /// 伪代码 0x10030b0ec（L659-668）：磁盘写。
    private func saveToDisk() {
        let all = defaults.dictionaryRepresentation()
            .filter { $0.key.hasPrefix(keyPrefix) }
        guard JSONSerialization.isValidJSONObject(all) else { return }
        let url = storageDirectory.appendingPathComponent("cookies.json")
        try? JSONSerialization.write(
            JSONSerialization.jsonObject(with: try! JSONSerialization.data(withJSONObject: all)),
            to: url, options: [.atomic])
    }

    /// 伪代码 0x100308908（L470-483）：磁盘读。
    private func loadFromDisk() {
        let url = storageDirectory.appendingPathComponent("cookies.json")
        guard let data = try? Data(contentsOf: url),
              let all = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }
        for (key, value) in all where key.hasPrefix(keyPrefix) {
            defaults.set(value, forKey: key)
        }
    }
}

extension UserDefaults {
    /// String 值字典读取（cookie 表域）。
    func dictionary(
        withValuesOfType type: String.Type, forKey key: String
    ) -> [String: String]? {
        dictionary(forKey: key) as? [String: String]
    }
}

extension CookiePersistenceService {

    /// 伪代码 0x10030db38（L635-657）：IDN 备用域——punycode 前缀域
    ///（xn-- 域确证推断）。
    static func alternateIDNDomain(for host: String) -> String? {
        guard host.hasPrefix("xn--") || host.contains(".xn--") else {
            return nil
        }
        return host
    }
}

