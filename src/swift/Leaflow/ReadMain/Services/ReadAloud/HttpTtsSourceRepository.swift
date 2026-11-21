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
        case duplicate
        case missingField(String)
        case invalidPayload

        var errorDescription: String? {
            switch self {
            case .duplicate:
                return "朗读源“已存在"
            case .missingField(let field):
                return "缺少 \(field)"
            case .invalidPayload:
                return "朗读源格式无效"
            }
        }
    }

    private let defaults: UserDefaults
    private let runtimeStore: HttpTtsRuntimeStore?
    private let audioCache: HttpTtsAudioCache
    private(set) var sources: [HttpTts] = []

    private static let storageKey = "reader_tts_sources"

    /// init(defaults:runtimeStore:audioCache:)（签名域确证）。
    init(
        defaults: UserDefaults = .standard,
        runtimeStore: HttpTtsRuntimeStore? = nil,
        audioCache: HttpTtsAudioCache = .init()
    ) {
        self.defaults = defaults
        self.runtimeStore = runtimeStore
        self.audioCache = audioCache
        reload()
    }

    /// reload（签名域确证）。
    func reload() {
        guard let data = defaults.data(forKey: Self.storageKey),
              let stored = try? JSONDecoder().decode(
                [HttpTts].self, from: data) else {
            sources = []
            return
        }
        sources = stored
    }

    /// source(id: Int64)（签名域确证）。
    func source(id: Int64) -> HttpTts? {
        sources.first { $0.id == id }
    }

    /// add(HttpTts) throws（签名域确证：'”已存在' L1625 重名冲突）。
    func add(_ source: HttpTts) throws {
        guard !source.name.isEmpty else {
            // '缺少 ' L1483 字段缺失域确证。
            throw HttpTtsSourceRepositoryError.missingField("名称")
        }
        guard !source.url.isEmpty else {
            throw HttpTtsSourceRepositoryError.missingField("URL")
        }
        guard sources.first(where: { $0.url == source.url }) == nil else {
            throw HttpTtsSourceRepositoryError.duplicate
        }
        sources.append(source)
        persist()
    }

    /// update(id:with:) throws（签名域确证）。
    func update(id: Int64, with source: HttpTts) throws {
        guard let index = sources.firstIndex(where: { $0.id == id }) else {
            throw HttpTtsSourceRepositoryError.invalidPayload
        }
        sources[index] = source
        persist()
    }

    /// delete(id: Int64)（签名域确证：运行时域 + 缓存联动清理）。
    func delete(id: Int64) {
        sources.removeAll { $0.id == id }
        audioCache.remove(sourceID: id)
        HttpTtsRateLimiterRegistry.shared.remove(sourceID: id)
        persist()
    }

    /// deleteAll（签名域确证）。
    func deleteAll() {
        sources.removeAll()
        audioCache.clear()
        persist()
    }

    /// importSources(from: String)（签名域确证：JSON 单条/列表双形态）。
    func importSources(from json: String) -> Int {
        guard let data = json.data(using: .utf8) else { return 0 }
        let decoder = JSONDecoder()
        var imported = 0
        if let single = try? decoder.decode(HttpTts.self, from: data) {
            if sources.first(where: { $0.url == single.url }) == nil {
                sources.append(single)
                imported = 1
            }
        } else if let list = try? decoder.decode(
            [HttpTts].self, from: data) {
            for source in list {
                if sources.first(where: { $0.url == source.url }) == nil {
                    sources.append(source)
                    imported += 1
                }
            }
        }
        if imported > 0 {
            persist()
        }
        return imported
    }

    /// merging(_:)（签名域确证：合并去重桥）。
    private func merging(_ incoming: [HttpTts]) -> [HttpTts] {
        var merged = sources
        for source in incoming
        where merged.first(where: { $0.url == source.url }) == nil {
            merged.append(source)
        }
        return merged
    }

    /// persist（签名域确证）。
    private func persist() {
        if let data = try? JSONEncoder().encode(sources) {
            defaults.set(data, forKey: Self.storageKey)
        }
    }
}
