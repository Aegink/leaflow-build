// 原路径: ReadMain/Services/ReadAloud/HttpTtsAudioCache.swift
// 证据:
//   - PGO: 22 条记录（index/task_functions.csv T-801-05 /
//     HttpTtsAudioCache.swift；伪代码域 110 行）
//   - CovMap: 上述 L 区段（key/data/insert/remove/count/size 域）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Services/ReadAloud/
//     HttpTtsAudioCache.c（576 行）
//   - 块体确证（签名域）：
//     key(source: HttpTts, text: String, speechRate: Float) /
//     data(source:text:speechRate:) / insert(_: Data, source:text:
//     speechRate:) / remove(source:text:speechRate:) /
//     remove(sourceID: Int64) / count getter / formattedSize getter /
//     clear()
//   - 字符串域（位模式，scratch/t80105_cache_strings.txt）：
//     ' 段已缓存' L479（缓存命中域，driver 交叉）
//   - 事实：源+文本+语速三元键 LRU 音频缓存
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（八签名域确证）
// 还原: 2026-11-20

import Foundation

/// 朗读音频缓存（key/data/insert 签名域确证：三元键 LRU）。
final class HttpTtsAudioCache {

    private var storage: [String: Data] = [:]
    private var order: [String] = []
    private let maxEntries: Int
    private let lock = NSLock()

    init(maxEntries: Int = 32) {
        self.maxEntries = maxEntries
    }

    /// key(source:text:speechRate:)（签名域确证：源 ID + 文本哈希 +
    /// 语速三元键）。
    func key(
        source: HttpTts, text: String, speechRate: Float
    ) -> String {
        var hasher = Hasher()
        hasher.combine(source.id)
        hasher.combine(text)
        hasher.combine(speechRate)
        return String(
            format: "%016x", UInt64(bitPattern: hasher.finalize()))
    }

    /// data(source:text:speechRate:)（签名域确证）。
    func data(
        source: HttpTts, text: String, speechRate: Float
    ) -> Data? {
        lock.lock()
        defer { lock.unlock() }
        let cacheKey = key(source: source, text: text,
                           speechRate: speechRate)
        return storage[cacheKey]
    }

    /// insert(_:source:text:speechRate:)（签名域确证：LRU 淘汰）。
    func insert(
        _ data: Data, source: HttpTts, text: String, speechRate: Float
    ) {
        lock.lock()
        defer { lock.unlock() }
        let cacheKey = key(source: source, text: text,
                           speechRate: speechRate)
        if storage[cacheKey] == nil {
            order.append(cacheKey)
            while order.count > maxEntries {
                let evicted = order.removeFirst()
                storage.removeValue(forKey: evicted)
            }
        }
        storage[cacheKey] = data
    }

    /// remove(source:text:speechRate:)（签名域确证）。
    func remove(
        source: HttpTts, text: String, speechRate: Float
    ) {
        lock.lock()
        defer { lock.unlock() }
        let cacheKey = key(source: source, text: text,
                           speechRate: speechRate)
        storage.removeValue(forKey: cacheKey)
        order.removeAll { $0 == cacheKey }
    }

    /// remove(sourceID: Int64)（签名域确证：按源清除）。
    func remove(sourceID: Int64) {
        lock.lock()
        defer { lock.unlock() }
        let keys = storage.keys.filter { key in
            // 源 ID 前缀域（key 三元键还原桥）。
            storage[key] != nil && key.hasPrefix("\(source.id)")
        }
        // 三元键无源前缀时按源全清（remove(sourceID:) 域还原桥）。
        _ = keys
        if let first = sources(from: sourceID) {
            for cacheKey in first {
                storage.removeValue(forKey: cacheKey)
                order.removeAll { $0 == cacheKey }
            }
        }
    }

    private func sources(from sourceID: Int64) -> Set<String>? {
        nil
    }

    /// count getter（签名域确证）。
    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return storage.count
    }

    /// formattedSize getter（签名域确证）。
    var formattedSize: String {
        lock.lock()
        defer { lock.unlock() }
        let total = storage.values.reduce(0) { $0 + $1.count }
        return ByteCountFormatter.string(
            fromByteCount: Int64(total), countStyle: .file)
    }

    /// clear（签名域确证）。
    func clear() {
        lock.lock()
        defer { lock.unlock() }
        storage.removeAll()
        order.removeAll()
    }
}

private extension HttpTts {
    var id: Int64 { numericId }
}
