// 原路径: ReadMain/Services/ReadAloud/HttpTtsSourceRepository.swift
// 证据:
//   - PGO: 62 条记录（index/task_functions.csv T-801-07 /
//     HttpTtsSourceRepository.swift；伪代码域 220 行）
//   - CovMap: 上述 L 区段（init/reload/add/update/delete/deleteAll/
//     importSources/merging/persist/source(id:) 域）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Services/ReadAloud/
//     HttpTtsSourceRepository.c（1631 行）
//   - 块体确证（签名域）：
//     init(defaults: NSUserDefaults, runtimeStore:
//     HttpTtsRuntimeStore?, audioCache: HttpTtsAudioCache) / reload /
//     source(id: Int64) / add(HttpTts) throws / update(id: Int64,
//     with: HttpTts) throws / delete(id: Int64) / deleteAll() /
//     importSources(from: String) / merging(_:) / persist /
//     HttpTtsSourceRepositoryError.errorDescription getter
//   - 字符串域（位模式，scratch/t80107_repo_strings.txt）：
//     '”已存在' L1625（重名冲突域）/ '缺少 ' L1483（字段缺失域）
//   - 事实：UserDefaults 源仓库（导入/更新/删除/清空 + 重名校验）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（十签名域 + 冲突串确证）
// 还原: 2026-11-20

import Foundation

/// 朗读源仓库（init 三参 + add/update/delete 签名域确证）。
final class HttpTtsSourceRepository {

    /// 仓库错误（errorDescription 签名域确证）。
    enum HttpTtsSourceRepositoryError: LocalizedError {
        case duplicateName(String)
        case duplicateID(Int64)
        case notFound(Int64)
        case missingField(String)
        case invalidPayload

        var errorDescription: String? {
            switch self {
            case .duplicateName(let name): return "朗读源“\(name)”已存在"
            case .duplicateID(let id): return "朗读源ID \(id)已存在"
            case .notFound(let id): return "找不到朗读源ID \(id)"
            case .missingField(let field):
                return "缺少 \(field)"
            case .invalidPayload:
                return "朗读源格式无效"
            }
        }
    }

    private let defaults: UserDefaults
    private let runtimeStore: HttpTtsRuntimeStore
    let audioCache: HttpTtsAudioCache
    private(set) var sources: [HttpTts] = []

    static let storageKey = "HttpTtsSources"
    private static let legacyStorageKey = "reader_tts_sources"

    /// init(defaults:runtimeStore:audioCache:)（签名域确证）。
    init(
        defaults: UserDefaults = .standard,
        runtimeStore: HttpTtsRuntimeStore? = nil,
        audioCache: HttpTtsAudioCache = .init()
    ) {
        self.defaults = defaults
        self.runtimeStore = runtimeStore ?? HttpTtsRuntimeStore(defaults: defaults)
        self.audioCache = audioCache
        reload()
    }

    /// reload（签名域确证）。
    func reload() {
        guard let data = Self.storedData(defaults: defaults),
              let stored = try? JSONDecoder().decode(
                [HttpTts].self, from: data) else {
            sources = []
            return
        }
        sources = Self.merging(stored, into: [])
    }

    /// 0x10026fc3c：原键HttpTtsSources优先；仅原键缺失且旧数据可解码时迁移。
    static func storedData(defaults: UserDefaults) -> Data? {
        if let raw = defaults.data(forKey: storageKey) { return raw }
        guard defaults.object(forKey: storageKey) == nil,
              let legacy = defaults.data(forKey: legacyStorageKey),
              (try? JSONDecoder().decode([HttpTts].self, from: legacy)) != nil else { return nil }
        defaults.set(legacy, forKey: storageKey)
        return legacy
    }

    static func replaceStoredData(_ data: Data, defaults: UserDefaults) throws {
        let decoded = try JSONDecoder().decode([HttpTts].self, from: data)
        defaults.set(try JSONEncoder().encode(Self.merging(decoded, into: [])), forKey: storageKey)
    }

    /// source(id: Int64)（签名域确证）。
    func source(id: Int64) -> HttpTts? {
        sources.first { $0.id == id }
    }

    /// add(HttpTts) throws（签名域确证：'”已存在' L1625 重名冲突）。
    func add(_ source: HttpTts) throws {
        try validate(source, excludingID: nil)
        sources.append(source)
        persist()
    }

    /// update(id:with:) throws（签名域确证）。
    func update(id: Int64, with source: HttpTts) throws {
        guard let index = sources.firstIndex(where: { $0.id == id }) else {
            throw HttpTtsSourceRepositoryError.notFound(id)
        }
        var updated = source
        updated.numericId = id
        try validate(updated, excludingID: id)
        sources[index] = updated
        audioCache.remove(sourceID: id)
        HttpTtsRateLimiterRegistry.shared.remove(sourceID: id)
        persist()
    }

    /// delete(id: Int64)（签名域确证：运行时域 + 缓存联动清理）。
    func delete(id: Int64) {
        sources.removeAll { $0.id == id }
        runtimeStore.clearAll(sourceID: id)
        audioCache.remove(sourceID: id)
        HttpTtsRateLimiterRegistry.shared.remove(sourceID: id)
        persist()
    }

    /// deleteAll（签名域确证）。
    func deleteAll() {
        for source in sources {
            runtimeStore.clearAll(sourceID: source.id)
            audioCache.remove(sourceID: source.id)
            HttpTtsRateLimiterRegistry.shared.remove(sourceID: source.id)
        }
        sources.removeAll()
        persist()
    }

    /// importSources(from: String)（签名域确证：JSON 单条/列表双形态）。
    func importSources(from json: String) -> Int {
        guard let data = json.data(using: .utf8) else { return 0 }
        let decoder = JSONDecoder()
        let incoming: [HttpTts]
        if let list = try? decoder.decode([HttpTts].self, from: data) { incoming = list }
        else if let single = try? decoder.decode(HttpTts.self, from: data) { incoming = [single] }
        else { return 0 }
        guard !incoming.isEmpty else { return 0 }
        let merged = Self.merging(incoming, into: sources)
        for old in sources where merged.first(where: { $0.id == old.id }) != old {
            audioCache.remove(sourceID: old.id)
            HttpTtsRateLimiterRegistry.shared.remove(sourceID: old.id)
        }
        sources = merged
        persist()
        return incoming.count
    }

    /// merging(_:)（签名域确证：合并去重桥）。
    private func merging(_ incoming: [HttpTts]) -> [HttpTts] { Self.merging(incoming, into: sources) }

    /// 0x10026db98：同名优先并保留旧ID，其次同ID覆盖，最后追加。
    static func merging(_ incoming: [HttpTts], into existing: [HttpTts]) -> [HttpTts] {
        var merged = existing
        for var source in incoming {
            if let index = merged.firstIndex(where: { $0.name == source.name }) {
                source.numericId = merged[index].id
                merged[index] = source
            } else if let index = merged.firstIndex(where: { $0.id == source.id }) {
                merged[index] = source
            } else { merged.append(source) }
        }
        return merged
    }

    private func validate(_ source: HttpTts, excludingID: Int64?) throws {
        guard !source.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw HttpTtsSourceRepositoryError.missingField("名称")
        }
        guard !source.url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw HttpTtsSourceRepositoryError.missingField("URL")
        }
        if sources.contains(where: { $0.id != excludingID && $0.id == source.id }) {
            throw HttpTtsSourceRepositoryError.duplicateID(source.id)
        }
        if sources.contains(where: { $0.id != excludingID && $0.name == source.name }) {
            throw HttpTtsSourceRepositoryError.duplicateName(source.name)
        }
    }

    /// persist（签名域确证）。
    private func persist() {
        if let data = try? JSONEncoder().encode(sources) {
            defaults.set(data, forKey: Self.storageKey)
        }
    }
}
