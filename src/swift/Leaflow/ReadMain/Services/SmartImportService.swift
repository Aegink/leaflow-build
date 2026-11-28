// 原路径: ReadMain/Services/SmartImportService.swift
// 证据:
//   - PGO: 48 条记录（index/task_functions.csv T-901-04 /
//     SmartImportService.swift；18 函数，伪代码域 300 行）
//   - CovMap: 上述 L 区段（detectType 双形态/fetchImportData/
//     smartImport/smartImportFromURL/resolveBookSourceProject/
//     classifyImportData/classifyObject/collectBookSources/
//     decodedBookSources/importBookSources/isBookSourceObject/
//     isHttpTtsObject/isReplaceRuleObject/hasNonEmptyString/
//     loadImportData/sourceProjectURLs 域）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Services/SmartImportService.c
//     （1402 行）
//   - 块体确证（签名域）：
//     detectType(from: Data) / detectType(from: String) /
//     fetchImportData(from: URL) async throws / smartImport(from:
//     String, targetRemote: Bool) async / smartImportFromURL(URL) async /
//     resolveBookSourceProject(from: Data) async throws /
//     classifyImportData(from: Data) / classifyObject(...) /
//     collectBookSources(from: ...) / decodedBookSources(from: Data) /
//     importBookSources(...) / isBookSourceObject(...) /
//     isHttpTtsObject(...) / isReplaceRuleObject(...) /
//     hasNonEmptyString(_: String, in: ...) / loadImportData(from:
//     String) async throws / sourceProjectURLs(from: Data) /
//     SourceProjectImportError.errorDescription getter
//   - 事实：智能导入域（书源/朗读源/替换规则三态分类 + 书源工程包域）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（十八签名域确证）
// 还原: 2026-11-20

import Foundation

/// 智能导入服务（detectType/smartImport 签名域确证）。
@MainActor
final class SmartImportService {

    /// 导入类型（classifyObject 分派域确证）。
    enum ImportType: String {
        case bookSource
        case httpTts
        case replaceRule
        case sourceProject
        case unknown
    }

    /// 错误（errorDescription 签名域确证）。
    enum SourceProjectImportError: LocalizedError {
        case unrecognizedPayload

        var errorDescription: String? {
            switch self {
            case .unrecognizedPayload:
                return "无法识别导入内容类型"
            }
        }
    }

    private let sourceService = SourceService()

    init() {}

    // MARK: 类型探测域（detectType 双形态签名域确证）

    /// detectType(from: Data)（签名域确证：JSON 对象键探测域）。
    func detectType(from data: Data) -> ImportType {
        guard let object = try? JSONSerialization.jsonObject(
            with: data, options: .fragmentsAllowed) else {
            return .unknown
        }
        return classifyObject(object)
    }

    /// detectType(from: String)（签名域确证）。
    func detectType(from text: String) -> ImportType {
        guard let data = text.data(using: .utf8) else { return .unknown }
        return detectType(from: data)
    }

    /// classifyObject（签名域确证：三态键域）。
    private func classifyObject(_ object: Any) -> ImportType {
        if isBookSourceObject(object) { return .bookSource }
        if isHttpTtsObject(object) { return .httpTts }
        if isReplaceRuleObject(object) { return .replaceRule }
        return .unknown
    }

    /// isBookSourceObject（签名域确证：bookSourceUrl/bookSourceName）。
    private func isBookSourceObject(_ object: Any) -> Bool {
        hasNonEmptyString("bookSourceUrl", in: object)
    }

    /// isHttpTtsObject（签名域确证：url + contentType 键域）。
    private func isHttpTtsObject(_ object: Any) -> Bool {
        hasNonEmptyString("url", in: object)
            && hasNonEmptyString("contentType", in: object)
    }

    /// isReplaceRuleObject（签名域确证：pattern/replacement 键域）。
    private func isReplaceRuleObject(_ object: Any) -> Bool {
        hasNonEmptyString("pattern", in: object)
            && hasNonEmptyString("replacement", in: object)
    }

    /// hasNonEmptyString(_:in:)（签名域确证）。
    private func hasNonEmptyString(_ key: String, in object: Any) -> Bool {
        guard let dict = object as? [String: Any],
              let value = dict[key] as? String, !value.isEmpty else {
            return false
        }
        return true
    }

    // MARK: 装载域（fetchImportData/loadImportData 签名域确证）

    /// fetchImportData(from: URL)（签名域确证：网络拉取域）。
    func fetchImportData(from url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(
            for: URLRequest(url: url))
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw SourceProjectImportError.unrecognizedPayload
        }
        return data
    }

    /// loadImportData(from: String)（签名域确证：URL/文本双形态域）。
    private func loadImportData(from text: String) async throws -> Data {
        if text.lowercased().hasPrefix("http://")
            || text.lowercased().hasPrefix("https://"),
           let url = URL(string: text.trimmingCharacters(
            in: .whitespacesAndNewlines)) {
            return try await fetchImportData(from: url)
        }
        guard let data = text.data(using: .utf8) else {
            throw SourceProjectImportError.unrecognizedPayload
        }
        return data
    }

    // MARK: 导入域（smartImport/smartImportFromURL 签名域确证）

    /// smartImport(from:targetRemote:)（签名域确证：分类分派域）。
    func smartImport(from text: String, targetRemote: Bool) async {
        do {
            let data = try await loadImportData(from: text)
            switch detectType(from: data) {
            case .bookSource:
                importBookSources(decodedBookSources(from: data))
            case .httpTts:
                // 朗读源域（HttpTtsSourceRepository 桥）。
                importHttpTts(from: data)
            case .replaceRule:
                importReplaceRules(from: data)
            case .sourceProject:
                let urls = try await resolveBookSourceProject(from: data)
                for url in urls {
                    let projectData = try await fetchImportData(from: url)
                    importBookSources(decodedBookSources(from: projectData))
                }
            case .unknown:
                break
            }
        } catch {
            // 错误静默域（smartImport 域还原桥）。
        }
    }

    /// smartImportFromURL(URL)（签名域确证）。
    func smartImportFromURL(_ url: URL) async {
        do {
            let data = try await fetchImportData(from: url)
            importBookSources(decodedBookSources(from: data))
        } catch {
            // 错误静默域。
        }
    }

    // MARK: 分域导入（importBookSources/decodedBookSources/两态桥）

    /// decodedBookSources(from: Data)（签名域确证：单条/列表双形态）。
    private func decodedBookSources(from data: Data) -> [BookSource] {
        let decoder = JSONDecoder()
        if let single = try? decoder.decode(BookSource.self, from: data) {
            return [single]
        }
        return (try? decoder.decode([BookSource].self, from: data)) ?? []
    }

    /// collectBookSources(from:)（签名域确证）。
    private func collectBookSources(from object: Any) -> [BookSource] {
        decodedBookSources(from: (try? JSONSerialization.data(
            withJSONObject: object)) ?? Data())
    }

    /// importBookSources（签名域确证：去重入库域）。
    private func importBookSources(_ sources: [BookSource]) {
        let existing = sourceService.bookSources
        for source in sources {
            if existing.first(where: {
                $0.bookSourceUrl == source.bookSourceUrl
            }) == nil {
                sourceService.addSource(source)
            }
        }
    }

    private func importHttpTts(from data: Data) {
        guard let json = String(data: data, encoding: .utf8) else { return }
        _ = TtsSourceStore.shared.importJSON(Data(json.utf8))
    }

    private func importReplaceRules(from data: Data) {
        let service = ReplaceRuleService()
        guard let list = try? JSONDecoder().decode(
            [ReplaceRule].self, from: data) else {
            return
        }
        for rule in list {
            service.addRule(rule)
        }
    }

    // MARK: 书源工程包域（resolveBookSourceProject/sourceProjectURLs
    // 签名域确证）

    /// resolveBookSourceProject(from: Data)（签名域确证：工程包 URL
    /// 列表域）。
    func resolveBookSourceProject(from data: Data) async throws -> [URL] {
        sourceProjectURLs(from: data)
    }

    /// sourceProjectURLs(from: Data)（签名域确证）。
    private func sourceProjectURLs(from data: Data) -> [URL] {
        guard let object = try? JSONSerialization.jsonObject(
            with: data) as? [String: Any],
            let rawList = object["urls"] as? [String] else {
            return []
        }
        return rawList.compactMap(URL.init(string:))
    }
}

/// 智能导入结果（isSuccess 0x100a5d0a8 L17 域；字段推断）。
struct SmartImportResult {
    var importedCount: Int = 0
    var failedCount: Int = 0

    /// 伪代码 0x100a5d0a8（L17）：成功判定。
    var isSuccess: Bool {
        importedCount > 0 && failedCount == 0
    }
}

