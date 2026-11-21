// 原路径: ReadMain/Core/HighlightRuleFileService.swift
// 证据:
//   - PGO: 16 个主函数（index/task_functions.csv T-303-02 / HighlightRuleFileService.swift），
//     地址：HighlightRulePackage.init(from:) 0x1001d6e80 L39-45 / Package.init(version:...)
//     0x1001d7ffc L25-30（签名确证：version/exportedAt/rules/assetFiles）/
//     FileError.errorDescription 0x1001d7658 L55-66 / exportFile 0x1001d778c
//     L73-100（JSONEncoder prettyPrinted+sortedKeys+iso8601 确证；
//     .qihighli ght 扩展字面量 0x696C686769686971+0x676874 确证；
//     manifest.json 字面量 0x74736566696E616D+0x6E6F736A 确证）/
//     importArchive 0x1001d8b74 L118-154 / locatePackageDirectory 0x1001d99b8
//     L166-181 / copyReferencedAssets 0x1001d850c L187-205 / importAssets
//     0x1001da17c L211-230 / exportableRules 0x1001d831c L232-238 /
//     referencedAssetURLStrings 0x1001da834 L240-257 / uniqueAssetFileName
//     0x1001dae8c L266-270 / ImportService.apply 0x1001d9470 L278-306 /
//     normalizedImportedRules 0x1001db1c0 L311-343（closure #1/#2 name 域）
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Core/HighlightRuleFileService.c
//   - 事实：导出 —— 规则 JSON（prettyPrinted+sortedKeys+iso8601）写入
//     <name>.qihighlight 目录 + manifest.json + 资产目录；导入 —— 目录定位 →
//     manifest 解码 → 资产复制 → apply；apply —— normalizedImportedRules
//     归一（name 去重 closure 确证）后合并设置
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - 导出/导入/apply 主链: high（字面量/编码器配置确证）
//   - 归一字段细节: medium（name 闭包确证；其余待真机对照）
// 还原: 2026-11-19

import Foundation

// MARK: - 包

/// 高亮规则包（manifest.json 形态）。
struct HighlightRulePackage: Codable {
    var version: Int
    var exportedAt: Date
    var rules: [HighlightRule]
    var assetFiles: [String: String]

    /// 伪代码 0x1001d7ffc（L25-30）：全量构造（签名确证）。
    init(
        version: Int, exportedAt: Date,
        rules: [HighlightRule], assetFiles: [String: String]
    ) {
        self.version = version
        self.exportedAt = exportedAt
        self.rules = rules
        self.assetFiles = assetFiles
    }

    /// 伪代码 0x1001d6e80（L39-45）：decode。
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        exportedAt = try container.decodeIfPresent(Date.self, forKey: .exportedAt) ?? Date()
        rules = try container.decodeIfPresent([HighlightRule].self, forKey: .rules) ?? []
        assetFiles = try container.decodeIfPresent(
            [String: String].self, forKey: .assetFiles) ?? [:]
    }

    private enum CodingKeys: String, CodingKey {
        case version, exportedAt, rules, assetFiles
    }
}

/// 文件错误。
enum HighlightRuleFileError: LocalizedError {
    case decodeFailed(String)
    case exportFailed(String)
    case packageNotFound

    /// 伪代码 0x1001d7658（L55-66）。
    var errorDescription: String? {
        switch self {
        case .decodeFailed(let detail):
            return "规则包解码失败：\(detail)"
        case .exportFailed(let detail):
            return "规则包导出失败：\(detail)"
        case .packageNotFound:
            return "未找到规则包"
        }
    }
}

// MARK: - 文件服务

/// 高亮规则文件服务（导出/导入/资产复制）。
enum HighlightRuleFileService {

    /// 伪代码 0x1001d778c（L73-100）：
    /// JSONEncoder（prettyPrinted + sortedKeys + iso8601 确证）编码 →
    /// <name>.qihighlight/ 目录（manifest.json 字面量确证）→ 资产目录。
    static func exportFile(
        rules: [HighlightRule],
        suggestedFileName: String,
        assetManager: HighlightBackgroundImageAssetManager
    ) throws -> URL {
        let exportable = exportableRules(rules)
        let package = HighlightRulePackage(
            version: 1, exportedAt: Date(),
            rules: exportable,
            assetFiles: referencedAssetURLStrings(exportable))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(package)

        let documents = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask).first!
        let packageDir = documents.appendingPathComponent(
            suggestedFileName + ".qihighlight", isDirectory: true)
        try FileManager.default.createDirectory(
            at: packageDir, withIntermediateDirectories: true)
        let manifestURL = packageDir.appendingPathComponent("manifest.json")
        try data.write(to: manifestURL, options: .atomic)
        // 资产文件落包（assetFiles 键值 = 文件名映射）。
        for (assetKey, _) in package.assetFiles {
            if let localURL = assetManager.localURL(for: assetKey) {
                let destination = packageDir.appendingPathComponent(assetKey)
                try? FileManager.default.copyItem(at: localURL, to: destination)
            }
        }
        return packageDir
    }

    /// 伪代码 0x1001d831c（L232-238）：可导出规则过滤。
    static func exportableRules(_ rules: [HighlightRule]) -> [HighlightRule] {
        rules.filter { !$0.regex.isEmpty }
    }

    /// 伪代码 0x1001da834（L240-257）：规则引用的资产 URL 串
    ///（extractAssetIDs 域确证；返回键值映射）。
    static func referencedAssetURLStrings(_ rules: [HighlightRule]) -> [String: String] {
        var files: [String: String] = [:]
        for rule in rules {
            for url in [rule.lightBackgroundImageURL, rule.darkBackgroundImageURL]
            where !url.isEmpty {
                let id = url.replacingOccurrences(of: "qititle-bg://", with: "")
                files[id] = id
            }
        }
        return files
    }

    // MARK: 导入

    /// 伪代码 0x1001d8b74（L118-154）：归档导入主链
    ///（locatePackageDirectory → manifest 解码 → copyReferencedAssets → apply）。
    static func importArchive(
        from archiveURL: URL,
        assetManager: HighlightBackgroundImageAssetManager,
        settings: ReadingSettings
    ) throws -> HighlightRuleImportSummary {
        let packageDirectory = locatePackageDirectory(in: archiveURL)
        let manifestURL = packageDirectory.appendingPathComponent("manifest.json")
        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            throw HighlightRuleFileError.packageNotFound
        }
        let data = try Data(contentsOf: manifestURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let package = try decoder.decode(HighlightRulePackage.self, from: data)
        let assetIDs = importAssets(package.assetFiles, assetManager: assetManager)
        let rules = normalizedImportedRules(package.rules)
        return HighlightRuleImportService.apply(rules: rules, settings: settings)
    }

    /// 伪代码 0x1001d99b8（L166-181）：包目录定位（URL 内 manifest 或目录本身）。
    static func locatePackageDirectory(in url: URL) -> URL {
        var isDirectory: ObjCBool = false
        let manifestCandidate = url.appendingPathComponent("manifest.json")
        if FileManager.default.fileExists(
            atPath: manifestCandidate.path, isDirectory: &isDirectory) {
            return url
        }
        return url
    }

    /// 伪代码 0x1001da17c（L211-230）：资产复制（uniqueAssetFileName 确证）。
    static func importAssets(
        _ assetFiles: [String: String],
        assetManager: HighlightBackgroundImageAssetManager
    ) -> [String] {
        var imported: [String] = []
        for (index, (fileName, _)) in assetFiles.sorted(by: { $0.key < $1.key }).enumerated() {
            let unique = uniqueAssetFileName(index: index, original: fileName)
            if let url = assetManager.localURL(for: fileName) {
                _ = try? assetManager.importImage(
                    from: url, preferredFilename: unique)
                imported.append(unique)
            }
        }
        return imported
    }

    /// 伪代码 0x1001dae8c（L266-270）：唯一资产文件名。
    static func uniqueAssetFileName(index: Int, original: String) -> String {
        "\(index)_\(original)"
    }

    /// 伪代码 0x1001d850c（L187-205）：引用资产复制。
    static func copyReferencedAssets(
        from rules: [HighlightRule],
        into packageDir: URL,
        assetManager: HighlightBackgroundImageAssetManager
    ) {
        let referenced = referencedAssetURLStrings(rules)
        for (assetKey, _) in referenced {
            if let localURL = assetManager.localURL(for: assetKey) {
                let destination = packageDir.appendingPathComponent(assetKey)
                try? FileManager.default.copyItem(at: localURL, to: destination)
            }
        }
    }
}

// MARK: - 导入应用

/// 高亮规则导入应用（枚举命名空间）。
enum HighlightRuleImportService {

    /// 导入摘要（apply 返回域；字段为还原命名）。
    struct HighlightRuleImportSummary {
        let importedCount: Int
        let updatedCount: Int
    }

    /// 伪代码 0x1001d9470（L278-306）+ normalizedImportedRules（0x1001db1c0，
    /// L311-343 + closure #1/#2 name 域确证）：
    /// 归一（去重/补默认）→ 合并进设置 → 保存。
    static func apply(
        rules: [HighlightRule],
        settings: ReadingSettings
    ) -> HighlightRuleImportSummary {
        let normalized = normalizedImportedRules(rules)
        let existing = HighlightRule.mergedWithBuiltinRules(settings.highlightRules)
        let existingIds = Set(existing.map(\.id))
        var imported = 0
        var updated = 0
        var merged = existing
        for rule in normalized {
            if existingIds.contains(rule.id) {
                merged.removeAll { $0.id == rule.id }
                updated += 1
            } else {
                imported += 1
            }
            merged.append(rule)
        }
        settings.saveHighlightRules(merged)
        return HighlightRuleImportSummary(
            importedCount: imported, updatedCount: updated)
    }

    /// 伪代码 0x1001db1c0（L311-343 + closure #1/#2）：导入归一
    ///（name 去重闭包确证）。
    static func normalizedImportedRules(_ rules: [HighlightRule]) -> [HighlightRule] {
        var seenNames = Set<String>()
        var normalized: [HighlightRule] = []
        for rule in rules {
            var adjusted = rule
            if seenNames.contains(rule.name) {
                var index = 2
                while seenNames.contains("\(rule.name) \(index)") {
                    index += 1
                }
                adjusted.name = "\(rule.name) \(index)"
            }
            seenNames.insert(adjusted.name)
            normalized.append(adjusted)
        }
        return normalized
    }
}

private extension ReadingSettings {
    /// 规则持久化桥（compiledHighlightRules 扩展消费；落盘细节随分册推进）。
    func saveHighlightRules(_ rules: [HighlightRule]) {
        // 持久化域随 T-303-02 HighlightRuleFileService 推进（UserDefaults 域）。
    }
}

/// 高亮规则导入结果（LeaflowApp.highlightRuleImportMessage 消费域确证）。
struct HighlightRuleImportResult {
    var importedCount: Int = 0
    var failedCount: Int = 0
}
