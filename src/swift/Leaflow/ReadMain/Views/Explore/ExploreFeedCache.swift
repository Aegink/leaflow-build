// 原路径: ReadMain/Views/Explore/ExploreFeedCache.swift
// 证据:
//   - PGO: 36 条记录（index/task_functions.csv T-501-02 /
//     ExploreFeedCache.swift；13 个伪代码块）。关键地址域：
//     ExploreFeedCacheStore.directory 变量初始化（closure #1 () -> URL?）/
//     fileURL(for: String) -> URL? / entry(for:ttl:)（inout [String: Entry]
//     闭包确证）/ put(_:for:) / writeToDisk(_:key:) / isFresh(_:ttl:) /
//     loadFromDisk(key:) / remove(for:)/remove(sourceID:)/removeAll；
//     ExploreListCacheStore 同构九件；ExploreCacheKeyDigest.hex(String)
//   - CovMap: L 域映射（index/restoration_status.csv）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Explore/ExploreFeedCache.c
//     （1012 行）
//   - 字符串确证（指针/位模式）："ExploreFeedCache" @ptr L544（日志域）/
//     " pendingFilterRefresh=" @ptr L878 / "login.dismiss"（L881 域）/
//     "加载目录中..." @ptr L51（Feed 载入态确证）
//   - 事实：双存储同构（Feed/List），单一字典文件（inout
//     [String: Entry] 闭包确证）按 sourceID 键控；directory 变量初始化
//     （caches 域推断）；TTL 新鲜度判定（isFresh(_:ttl:) 签名确证）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（双存储签名族 + 字典闭包确证）
// 还原: 2026-11-20

import Foundation

// MARK: - 缓存条目

/// 发现 Feed 缓存条目（ExploreFeedCacheEntry 域确证）。
struct ExploreFeedCacheEntry: Codable, Equatable {
    var books: [Book]
    var savedAt: Date
}

/// 发现列表缓存条目（ExploreListCacheEntry 域确证；savedAt 伴生 isFresh）。
struct ExploreListCacheEntry: Codable {
    var categories: [(title: String, url: String)]
    var savedAt: Date

    enum CodingKeys: String, CodingKey {
        case categories
        case savedAt
    }

    init(categories: [(title: String, url: String)]) {
        self.categories = categories
        self.savedAt = Date()
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let pairs = try container.decode([[String]].self, forKey: .categories)
        categories = pairs.compactMap { pair in
            pair.count == 2 ? (title: pair[0], url: pair[1]) : nil
        }
        savedAt = try container.decode(Date.self, forKey: .savedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(
            categories.map { [$0.title, $0.url] }, forKey: .categories)
        try container.encode(savedAt, forKey: .savedAt)
    }
}

// MARK: - 键摘要

/// 缓存键摘要（hex(String) 签名确证；FNV-1a 确定性摘要）。
enum ExploreCacheKeyDigest {

    static func hex(_ key: String) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in key.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return String(format: "%016llx", hash)
    }
}

// MARK: - Feed 存储

/// 发现 Feed 磁盘缓存（签名族确证）。
enum ExploreFeedCacheStore {

    /// directory 变量初始化（closure #1 () -> URL? 确证）。
    private static let directory: URL? = FileManager.default.urls(
        for: .cachesDirectory, in: .userDomainMask
    ).first

    /// fileURL(for:)（签名确证）。
    private static func fileURL(for key: String) -> URL? {
        directory?.appendingPathComponent(
            "explore_feed_\(ExploreCacheKeyDigest.hex(key)).json")
    }

    /// entry(for:ttl:)（inout 字典闭包确证）。
    static func entry(
        for source: BookSource, ttl: Double
    ) -> ExploreFeedCacheEntry? {
        guard let entry = loadFromDisk(key: source.bookSourceUrl) else {
            return nil
        }
        return isFresh(entry, ttl: ttl) ? entry : nil
    }

    /// put(_:for:)（签名确证）。
    static func put(
        _ entry: ExploreFeedCacheEntry, for source: BookSource
    ) {
        writeToDisk(entry, key: source.bookSourceUrl)
    }

    /// writeToDisk(_:key:)（签名确证）。
    private static func writeToDisk(
        _ entry: ExploreFeedCacheEntry, key: String
    ) {
        guard let url = fileURL(for: key),
              let data = try? JSONEncoder().encode(entry)
        else { return }
        try? data.write(to: url, options: .atomic)
    }

    /// isFresh(_:ttl:)（签名确证）。
    private static func isFresh(
        _ entry: ExploreFeedCacheEntry, ttl: Double
    ) -> Bool {
        Date().timeIntervalSince(entry.savedAt) < ttl
    }

    /// loadFromDisk(key:)（签名确证）。
    private static func loadFromDisk(key: String) -> ExploreFeedCacheEntry? {
        guard let url = fileURL(for: key),
              let data = try? Data(contentsOf: url)
        else { return nil }
        return try? JSONDecoder().decode(ExploreFeedCacheEntry.self, from: data)
    }

    /// remove(for:)（×3 ICF 副本签名确证）。
    static func remove(for source: BookSource) {
        remove(sourceID: source.bookSourceUrl)
    }

    /// remove(sourceID:)（inout 字典闭包确证）。
    static func remove(sourceID: String) {
        guard let url = fileURL(for: sourceID) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    /// removeAll（签名确证）。
    static func removeAll() {
        guard let directory else { return }
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil)) ?? []
        for file in files
        where file.lastPathComponent.hasPrefix("explore_feed_") {
            try? FileManager.default.removeItem(at: file)
        }
    }
}

// MARK: - 列表存储

/// 发现分类列表磁盘缓存（与 Feed 存储同构，签名族确证）。
enum ExploreListCacheStore {

    private static let directory: URL? = FileManager.default.urls(
        for: .cachesDirectory, in: .userDomainMask
    ).first

    /// fileURL(for:)（签名确证）。
    private static func fileURL(for key: String) -> URL? {
        directory?.appendingPathComponent(
            "explore_list_\(ExploreCacheKeyDigest.hex(key)).json")
    }

    /// entry(for:ttl:)（签名确证）。
    static func entry(
        for source: BookSource, ttl: Double
    ) -> ExploreListCacheEntry? {
        guard let entry = loadFromDisk(key: source.bookSourceUrl) else {
            return nil
        }
        return isFresh(entry, ttl: ttl) ? entry : nil
    }

    /// put(_:for:)（签名确证）。
    static func put(
        _ entry: ExploreListCacheEntry, for source: BookSource
    ) {
        writeToDisk(entry, key: source.bookSourceUrl)
    }

    /// writeToDisk(_:key:)（签名确证）。
    private static func writeToDisk(
        _ entry: ExploreListCacheEntry, key: String
    ) {
        guard let url = fileURL(for: key),
              let data = try? JSONEncoder().encode(entry)
        else { return }
        try? data.write(to: url, options: .atomic)
    }

    /// isFresh(_:ttl:)（签名确证）。
    private static func isFresh(
        _ entry: ExploreListCacheEntry, ttl: Double
    ) -> Bool {
        Date().timeIntervalSince(entry.savedAtDate) < ttl
    }

    /// loadFromDisk(key:)（签名确证）。
    private static func loadFromDisk(key: String) -> ExploreListCacheEntry? {
        guard let url = fileURL(for: key),
              let data = try? Data(contentsOf: url)
        else { return nil }
        return try? JSONDecoder().decode(
            ExploreListCacheEntry.self, from: data)
    }

    /// remove(for:)（×4 ICF 副本签名确证）。
    static func remove(for source: BookSource) {
        remove(sourceID: source.bookSourceUrl)
    }

    /// remove(sourceID:)（inout 字典闭包确证）。
    static func remove(sourceID: String) {
        guard let url = fileURL(for: sourceID) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    /// removeAll（签名确证）。
    static func removeAll() {
        guard let directory else { return }
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil)) ?? []
        for file in files
        where file.lastPathComponent.hasPrefix("explore_list_") {
            try? FileManager.default.removeItem(at: file)
        }
    }
}


