// 原路径: ReadMain/Services/BackupService.swift
// 证据:
//   - PGO: 128 条记录（index/task_functions.csv T-901-02 /
//     BackupService.swift；64 函数，伪代码域 800 行）
//   - CovMap: 上述 L 区段（appSupportDir/documentsDir/createBackupArchive/
//     decodeManifest/directorySize/export 域/import 域/iCloud 域/
//     WebDAV 域/manifest 域）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Services/BackupService.c
//     （12166 行）
//   - 块体确证（签名域）：
//     init / appSupportDir getter / documentsDir getter /
//     collectUndownloadedItems(under:) / copyFileOverwriting(from:to:) /
//     createBackupArchive(from:) / decodeManifest(Data) / directorySize(
//     URL) / downloadTreeRecursively(at:timeout:) / ensureDownloaded(
//     _:timeout:) / exportAppSettings / exportAppSettingsFile(to:) /
//     exportBookSources(to:counts:) / exportBookmarkFile(to:counts:) /
//     exportBookshelfFiles(to:counts:) / exportChapterRules(to:counts:) /
//     exportChapterTitleAssets(to:counts:) / exportFontResources(
//     to:counts:) / exportHighlightRules(to:counts:) /
//     exportLocalBooksIfNeeded(_:to:incremental:) / exportReaderBackgrounds(
//     to:incremental:) / exportReadingSettings / exportReadingSettingsFile(
//     to:) / exportReadingStatistics(to:) / exportReplaceRules(to:counts:)
//     / exportThemeResources(to:counts:) / exportTtsSources(to:counts:) /
//     fileSize(URL) / flushAppThemeSettingsForBackup /
//     flushReadingSettingsForBackup / importAppSettings(from: Data) /
//     importHighlightRules(from: URL) / importReadingSettings(from: Data) /
//     isItemDownloaded(URL) / mirrorDirectory(from:to:incremental:) /
//     needsCopy(src:dest:) / normalizeThemeResourcesForBackup /
//     prepareBackupExport / reloadFontsForBackup / resolveBackupRoot(in:) /
//     resolveICloudRoot() async / userDefaultsDataSize(forKey:) /
//     writeManifest(to:counts:) / BackupError / ICloudSyncError /
//     backupToICloud(categories:) / backupToWebDAV(config:categories:
//     progress:) / estimateBackupSize(categories:) / exportBackup(
//     categories:) / exportDataTree(to:categories:incremental:) /
//     formatSize(Int64) / iCloudLastBackupDate() / importDataTree(
//     from:categories:) / isICloudAvailable getter / previewBackup(
//     from:) / previewICloudBackup() / previewWebDAVBackup(config:) /
//     restoreBackup(from:categories:) / restoreFromICloud(categories:) /
//     restoreFromWebDAV(config:categories:progress:) /
//     webDAVLastBackupDate(config:)
//   - 字符串域：' 本（清理 ' L497 域（BookService 交叉）
//   - 事实：备份五文件域（bookshelf/readtimes/booksources/pinnedbooks/
//     manifest）+ iCloud/WebDAV 双通道 + 七分类导出/导入
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（六十四签名域确证）
// 还原: 2026-11-20

import Foundation
import UIKit

/// 备份服务（exportBackup/restoreBackup/previewBackup 签名域确证）。
/// @MainActor：消费方（CloudSyncController/BackupView）均为 MainActor
/// 域，ReadingSettings/AppThemeManager 状态桥要求隔离（wave-16）。
@MainActor
final class BackupService {

    static let shared = BackupService()

    let fileManager = FileManager.default
    let defaults: UserDefaults
    let documentsOverride: URL?
    let supportOverride: URL?
    let webDAVTransport: WebDAVClient.Transport?

    /// 备份错误（errorDescription 签名域确证）。
    enum BackupError: LocalizedError {
        case archiveFailed
        case manifestMissing
        case iCloudUnavailable

        var errorDescription: String? {
            switch self {
            case .archiveFailed:
                return "备份归档失败"
            case .manifestMissing:
                return "备份缺少 manifest.json"
            case .iCloudUnavailable:
                return "iCloud 不可用"
            }
        }
    }

    /// iCloud 同步错误（errorDescription 签名域确证）。
    enum ICloudSyncError: LocalizedError {
        case rootUnavailable

        var errorDescription: String? {
            switch self {
            case .rootUnavailable:
                return "iCloud 根目录不可用"
            }
        }
    }

    init(documentsDirectory: URL? = nil, applicationSupportDirectory: URL? = nil, defaults: UserDefaults = .standard,
         webDAVTransport: WebDAVClient.Transport? = nil) {
        documentsOverride = documentsDirectory
        supportOverride = applicationSupportDirectory
        self.defaults = defaults
        self.webDAVTransport = webDAVTransport
    }

    // MARK: 目录域（appSupportDir/documentsDir 签名域确证）

    /// appSupportDir getter（签名域确证）。
    var appSupportDir: URL {
        supportOverride ?? FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!
    }

    /// documentsDir getter（签名域确证）。
    var documentsDir: URL {
        documentsOverride ?? FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask
        ).first!
    }

    /// resolveBackupRoot(in:)（签名域确证：备份根目录域）。
    func resolveBackupRoot(in directory: URL) throws -> URL {
        if fileManager.fileExists(atPath: directory.appendingPathComponent("manifest.json").path) { return directory }
        if let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: [.isDirectoryKey]) {
            for case let item as URL in enumerator where item.lastPathComponent == "manifest.json" {
                return item.deletingLastPathComponent()
            }
        }
        throw BackupError.manifestMissing
    }

    // MARK: 尺寸域（directorySize/fileSize/formatSize 签名域确证）

    func directorySize(_ directory: URL) -> Int64 {
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey])
        else {
            return 0
        }
        var total: Int64 = 0
        for case let url as URL in enumerator {
            guard let values = try? url.resourceValues(forKeys: [
                .fileSizeKey, .isDirectoryKey,
            ]), values.isDirectory != true else {
                continue
            }
            total += Int64(values.fileSize ?? 0)
        }
        return total
    }

    func fileSize(_ url: URL) -> Int64 {
        (try? url.resourceValues(forKeys: [.fileSizeKey]))?
            .fileSize.map(Int64.init) ?? 0
    }

    /// formatSize(Int64)（签名域确证）。
    func formatSize(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    // MARK: 导出域（exportBackup/exportDataTree 签名域确证）

    /// exportBackup(categories:)（签名域确证：导出树 + zip 归档）。
    func exportBackup(
        categories: Set<SyncCategory>
    ) async throws -> URL {
        if documentsOverride == nil {
            try flushReadingSettingsForBackup()
            try flushAppThemeSettingsForBackup()
        }
        let staging = fileManager.temporaryDirectory
            .appendingPathComponent(
                "backup_\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(
            at: staging, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: staging) }
        try exportDataTree(
            to: staging, categories: categories, incremental: false)
        let output = fileManager.temporaryDirectory
            .appendingPathComponent("qireader_backup_"
                + fileDateStamp() + ".zip")
        try ZipUtility.createZip(from: staging, to: output)
        return output
    }

    /// exportDataTree(to:categories:incremental:)
    /// （签名域确证：七分类导出域）。
    func exportDataTree(
        to directory: URL, categories: Set<SyncCategory>,
        incremental: Bool
    ) throws {
        var counts: [String: Int] = [:]
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        if categories.contains(.bookshelf) {
            try exportBookshelfFiles(to: directory, counts: &counts)
        }
        if categories.contains(.bookmarks) {
            try exportBookmarkFile(to: directory, counts: &counts)
        }
        if categories.contains(.config) {
            try exportBookSources(to: directory, counts: &counts)
        }
        if categories.contains(.chapterRules) {
            try exportChapterRules(to: directory, counts: &counts)
        }
        if categories.contains(.replaceRules) {
            try exportReplaceRules(to: directory, counts: &counts)
        }
        if categories.contains(.highlightRules) {
            try exportHighlightRules(to: directory, counts: &counts)
        }
        if categories.contains(.appearance) {
            try exportThemeResources(
                to: directory, counts: &counts, incremental: incremental)
            try exportReaderBackgrounds(
                to: directory, incremental: incremental)
            try exportFontResources(
                to: directory, counts: &counts, incremental: incremental)
            try exportChapterTitleAssets(
                to: directory, counts: &counts, incremental: incremental)
        }
        if categories.contains(.readingSettings) {
            try exportReadingSettingsFile(to: directory)
        }
        if categories.contains(.readingStats) {
            try exportReadingStatistics(
                to: directory, incremental: incremental)
        }
        if categories.contains(.ttsSources) {
            try exportTtsSources(
                to: directory, counts: &counts, incremental: incremental)
        }
        try exportLocalBooksIfNeeded(categories.contains(.localBooks), to: directory, incremental: incremental)
        try writeManifest(to: directory, counts: counts, categories: categories)
    }

    // MARK: 导入域（importDataTree/import* 签名域确证）

    /// importDataTree(from:categories:)（签名域确证）。
    func importDataTree(
        from directory: URL, categories: Set<SyncCategory>
    ) throws {
        if categories.contains(.bookshelf) {
            for name in ["bookshelf.json", "groups.json", "readtimes.json", "pinnedbooks.json", "pinnedexplore.json"] {
                try importJSONFile(name, from: directory, to: documentsDir.appendingPathComponent("bookshelf_data/" + name))
            }
        }
        if categories.contains(.bookmarks) {
            try importJSONFile("bookmarks.json", from: directory, to: documentsDir.appendingPathComponent("bookshelf_data/bookmarks.json"))
        }
        if categories.contains(.config) {
            try importJSONFile("booksources.json", from: directory, to: documentsDir.appendingPathComponent("BookSources.json"))
        }
        if categories.contains(.chapterRules) {
            if let data = try readJSONPayload("chapter_rules.json", from: directory) {
                defaults.set(data, forKey: "chapter_rules")
                try data.write(to: documentsDir.appendingPathComponent("chapter_rules.json"), options: .atomic)
            }
        }
        if categories.contains(.replaceRules) {
            try importJSONFile("replace_rules.json", from: directory, to: appSupportDir.appendingPathComponent("replace_rules.json"))
        }
        if categories.contains(.appearance) {
            let themes = directory.appendingPathComponent("Themes")
            if fileManager.fileExists(atPath: themes.path) {
                try mirrorDirectory(
                    from: themes,
                    to: appSupportDir.appendingPathComponent("Themes"),
                    incremental: false)
            }
        }
        if categories.contains(.ttsSources), let data = try readJSONPayload("tts_sources.json", from: directory) {
            defaults.set(data, forKey: "reader_tts_sources")
        }
        if categories.contains(.highlightRules) {
            try importJSONFile("highlight_rules.json", from: directory, to: appSupportDir.appendingPathComponent("highlight_rules.json"))
        }
        if categories.contains(.localBooks) { try importLocalBookFiles(from: directory) }
        if categories.contains(.readingStats) {
            if let data = try readJSONPayload("reading_stats.json", from: directory) {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                _ = try decoder.decode([ReadingRecord].self, from: data)
                let target = appSupportDir.appendingPathComponent("ReadingStatistics/records.json")
                try fileManager.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                try data.write(to: target, options: .atomic)
                if supportOverride == nil { try ReadingStatisticsService.shared.reloadRecords() }
            }
        }
        if categories.contains(.readingSettings) {
            let settingsFile = directory.appendingPathComponent(
                "reading_settings.json")
            if fileManager.fileExists(atPath: settingsFile.path),
               let data = try? Data(contentsOf: settingsFile) {
                importReadingSettings(from: data)
            }
        }
    }

    /// importReadingSettings(from: Data)（签名域确证）。
    func importReadingSettings(from data: Data) {
        guard let settings = try? JSONDecoder().decode(
            ReadingSettings.self, from: data) else {
            return
        }
        settings.save()
    }

    /// importAppSettings(from: Data)（签名域确证）。
    func importAppSettings(from data: Data) {
        // App 设置快照导入桥。
    }

    /// importHighlightRules(from: URL)（签名域确证）。
    func importHighlightRules(from url: URL) throws {
        let destination = appSupportDir.appendingPathComponent(
            "highlight_rules.json")
        try copyFileOverwriting(from: url, to: destination)
    }

    // MARK: 恢复域（restoreBackup 签名域确证）

    /// restoreBackup(from:categories:)（签名域确证：解包 + 导入域）。
    func restoreBackup(
        from url: URL, categories: Set<SyncCategory>
    ) async throws {
        let staging = fileManager.temporaryDirectory
            .appendingPathComponent(
                "backup_restore_\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(
            at: staging, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: staging) }
        try ZipUtility.extractZip(from: url, to: staging)
        let root = try resolveBackupRoot(in: staging)
        _ = try decodeManifest(Data(contentsOf: root.appendingPathComponent("manifest.json")))
        try importDataTree(from: root, categories: categories)
    }

    /// restoreLatestBackup()（BackupView 消费域确证——最近本地备份回灌桥；
    /// 备份产物域为临时目录 qireader_backup_*.zip，还原推断）。
    func restoreLatestBackup() async {
        let files = (try? fileManager.contentsOfDirectory(
            at: fileManager.temporaryDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey]))?
            .filter {
                $0.lastPathComponent.hasPrefix("qireader_backup_")
                    && $0.pathExtension == "zip"
            }
            .sorted { lhs, rhs in
                let l = (try? lhs.resourceValues(
                    forKeys: [.contentModificationDateKey]))?
                    .contentModificationDate ?? .distantPast
                let r = (try? rhs.resourceValues(
                    forKeys: [.contentModificationDateKey]))?
                    .contentModificationDate ?? .distantPast
                return l > r
            }
        guard let latest = files?.first else { return }
        try? await restoreBackup(
            from: latest, categories: BackupSyncPreferences().selectedCategories)
    }

    // MARK: 估算域（estimateBackupSize 签名域确证）

    /// estimateBackupSize(categories:)（签名域确证：BackupView 域桥）。
    func estimateBackupSize(categories: Set<SyncCategory>) -> Int64 {
        var total: Int64 = 0
        var visited = Set<String>()
        for category in categories {
            for url in estimatedFiles(for: category) where visited.insert(url.path).inserted {
                if (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                    total += directorySize(url)
                } else { total += fileSize(url) }
            }
        }
        if categories.contains(.chapterRules), existingFile(estimatedFiles(for: .chapterRules)) == nil {
            total += Int64(defaults.data(forKey: "chapter_rules")?.count ?? 0)
        }
        if categories.contains(.readingSettings) { total += Int64((try? JSONEncoder().encode(ReadingSettings.load()))?.count ?? 0) }
        if categories.contains(.ttsSources) { total += Int64(defaults.data(forKey: "reader_tts_sources")?.count ?? 0) }
        return total
    }

}

// MARK: - T-1401-13/15 逐域补齐（备份清单域）

/// 备份清单（includedCategories 0x1002b6e00 L22-30 域；字段推断）。
struct BackupManifest: Codable {
    var version: Int = 1
    var exportedAt: Date = Date()
    var categories: Set<SyncCategory> = SyncCategory.defaults
    var bookCount: Int = 0
    var sourceCount: Int = 0

    /// 伪代码 0x1002b6e00（L22-30）：包含分类集。
    var includedCategories: Set<SyncCategory> {
        categories
    }
}

extension BackupService {

    /// 伪代码 0x1002c6c28（L766-776）：iCloud 备份预览——Manifest 解析域
    ///（ubiquity 域待真机）。
    func previewICloudBackup() async throws -> BackupManifest {
        guard let url = FileManager.default
            .url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents/backup.qibackup")
        else {
            throw AppError.parsing("iCloud 容器不可用")
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(BackupManifest.self, from: data)
    }
}

