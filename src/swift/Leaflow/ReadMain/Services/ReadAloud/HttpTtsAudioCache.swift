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
//   - 类型表5012：按源ID分组；0x100264654实际块为SHA256键构造。
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（八签名域确证）
// 还原: 2026-11-20

import Foundation
import CryptoKit

/// 朗读音频缓存：原版分源存储，更新源配置后旧键不会命中。
final class HttpTtsAudioCache {

    private var storage: [Int64: [String: Data]] = [:]
    private let lock = NSLock()

    /// 0x100264654：源ID|更新时间|URL|语速|正文，经UTF-8和SHA256转小写十六进制。
    func key(
        source: HttpTts, text: String, speechRate: Float
    ) -> String {
        let value = "\(source.id)|\(source.lastUpdateTime ?? 0)|\(source.url)|\(speechRate)|\(text)"
        return SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    /// data(source:text:speechRate:)（签名域确证）。
    func data(
        source: HttpTts, text: String, speechRate: Float
    ) -> Data? {
        lock.lock()
        defer { lock.unlock() }
        let cacheKey = key(source: source, text: text,
                           speechRate: speechRate)
        return storage[source.id]?[cacheKey]
    }

    /// insert(_:source:text:speechRate:)：锁内写入所属源的缓存字典。
    func insert(
        _ data: Data, source: HttpTts, text: String, speechRate: Float
    ) {
        lock.lock()
        defer { lock.unlock() }
        let cacheKey = key(source: source, text: text,
                           speechRate: speechRate)
        storage[source.id, default: [:]][cacheKey] = data
    }

    /// remove(source:text:speechRate:)（签名域确证）。
    func remove(
        source: HttpTts, text: String, speechRate: Float
    ) {
        lock.lock()
        defer { lock.unlock() }
        let cacheKey = key(source: source, text: text,
                           speechRate: speechRate)
        storage[source.id]?.removeValue(forKey: cacheKey)
        if storage[source.id]?.isEmpty == true { storage.removeValue(forKey: source.id) }
    }

    /// remove(sourceID: Int64)（签名域确证：按源清除）。
    func remove(sourceID: Int64) {
        lock.lock()
        defer { lock.unlock() }
        storage.removeValue(forKey: sourceID)
    }

    /// count getter（签名域确证）。
    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return storage.values.reduce(0) { $0 + $1.count }
    }

    /// formattedSize getter（签名域确证）。
    var formattedSize: String {
        lock.lock()
        defer { lock.unlock() }
        let total = storage.values.reduce(0) { total, source in total + source.values.reduce(0) { $0 + $1.count } }
        return ByteCountFormatter.string(
            fromByteCount: Int64(total), countStyle: .file)
    }

    /// clear（签名域确证）。
    func clear() {
        lock.lock()
        defer { lock.unlock() }
        storage.removeAll()
    }
}


