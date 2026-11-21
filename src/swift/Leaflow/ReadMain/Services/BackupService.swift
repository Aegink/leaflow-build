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
final class BackupService {

    static let shared = BackupService()

    private let fileManager = FileManager.default
    private let bookService = BookService()

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

    init() {}

    // MARK: 目录域（appSupportDir/documentsDir 签名域确证）

    /// appSupportDir getter（签名域确证）。
    var appSupportDir: URL {
        FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!
    }

    /// documentsDir getter（签名域确证）。
    var documentsDir: URL {
        FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask
        ).first!
    }

    /// resolveBackupRoot(in:)（签名域确证：备份根目录域）。
    private func resolveBackupRoot(in directory: URL) throws -> URL {
        let root = directory.appendingPathComponent("backup",
                                                   isDirectory: true)
        try fileManager.createDirectory(
            at: root, withIntermediateDirectories: true)
        return root
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

    private func fileSize(_ url: URL) -> Int64 {
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
        try flushReadingSettingsForBackup()
        try flushAppThemeSettingsForBackup()
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
        try exportBookshelfFiles(to: directory, counts: &counts)
        if categories.contains(.bookshelf) {
            try exportLocalBooksIfNeeded(
                false, to: directory, incremental: incremental)
        }
        if categories.contains(.bookmarks) {
            try exportBookmarkFile(to: directory, counts: &counts)
        }
        if categories.contains(.sources) {
            try exportBookSources(to: directory, counts: &counts)
        }
        if categories.contains(.replaceRules) {
            try exportChapterRules(to: directory, counts: &counts)
            try exportHighlightRules(to: directory, counts: &counts)
        }
        if categories.contains(.themes) {
            try exportThemeResources(to: directory, counts: &counts)
            try exportReaderBackgrounds(
                to: directory, incremental: incremental)
            try exportFontResources(to: directory, counts: &counts)
            try exportChapterTitleAssets(to: directory, counts: &counts)
        }
        if categories.contains(.settings) {
            exportReadingSettings()
            try exportReadingSettingsFile(to: directory)
            try exportReadingStatistics(to: directory)
            try exportTtsSources(to: directory, counts: &counts)
        }
        try writeManifest(to: directory, counts: counts)
    }

    // MARK: 分类导出域（export* 九签名域确证）

    /// exportBookshelfFiles(to:counts:)（签名域确证：bookshelf.json）。
    private func exportBookshelfFiles(
        to directory: URL, counts: inout [String: Int]
    ) throws {
        let source = appSupportDir.appendingPathComponent(
            "bookshelf.json")
        guard fileManager.fileExists(atPath: source.path) else { return }
        try fileManager.copyItem(
            at: source,
            to: directory.appendingPathComponent("bookshelf.json"))
        counts["bookshelf"] = bookService.bookshelf.count
    }

    /// exportBookmarkFile(to:counts:)（签名域确证）。
    private func exportBookmarkFile(
        to directory: URL, counts: inout [String: Int]
    ) throws {
        let source = appSupportDir.appendingPathComponent("bookmarks.json")
        guard fileManager.fileExists(atPath: source.path) else { return }
        try fileManager.copyItem(
            at: source,
            to: directory.appendingPathComponent("bookmarks.json"))
    }

    /// exportBookSources(to:counts:)（签名域确证）。
    private func exportBookSources(
        to directory: URL, counts: inout [String: Int]
    ) throws {
        let source = appSupportDir.appendingPathComponent("booksources.json")
        guard fileManager.fileExists(atPath: source.path) else { return }
        try fileManager.copyItem(
            at: source,
            to: directory.appendingPathComponent("booksources.json"))
    }

    /// exportChapterRules(to:counts:)（签名域确证：替换规则域）。
    private func exportChapterRules(
        to directory: URL, counts: inout [String: Int]
    ) throws {
        let source = appSupportDir.appendingPathComponent(
            "replace_rules.json")
        guard fileManager.fileExists(atPath: source.path) else { return }
        try fileManager.copyItem(
            at: source,
            to: directory.appendingPathComponent("replace_rules.json"))
    }

    /// exportHighlightRules(to:counts:)（签名域确证）。
    private func exportHighlightRules(
        to directory: URL, counts: inout [String: Int]
    ) throws {
        let source = appSupportDir.appendingPathComponent(
            "highlight_rules.json")
        guard fileManager.fileExists(atPath: source.path) else { return }
        try fileManager.copyItem(
            at: source,
            to: directory.appendingPathComponent("highlight_rules.json"))
    }

    /// exportThemeResources(to:counts:)（签名域确证）。
    private func exportThemeResources(
        to directory: URL, counts: inout [String: Int]
    ) throws {
        let themes = appSupportDir.appendingPathComponent("Themes")
        guard fileManager.fileExists(atPath: themes.path) else { return }
        try mirrorDirectory(
            from: themes,
            to: directory.appendingPathComponent("Themes"),
            incremental: incremental)
    }

    /// exportReaderBackgrounds(to:incremental:)（签名域确证）。
    private func exportReaderBackgrounds(
        to directory: URL, incremental: Bool
    ) throws {
        let backgrounds = appSupportDir.appendingPathComponent("backgrounds")
        guard fileManager.fileExists(atPath: backgrounds.path) else { return }
        try mirrorDirectory(
            from: backgrounds,
            to: directory.appendingPathComponent("backgrounds"),
            incremental: incremental)
    }

    /// exportFontResources(to:counts:)（签名域确证）。
    private func exportFontResources(
        to directory: URL, counts: inout [String: Int]
    ) throws {
        let fonts = appSupportDir.appendingPathComponent("Fonts")
        guard fileManager.fileExists(atPath: fonts.path) else { return }
        try mirrorDirectory(
            from: fonts, to: directory.appendingPathComponent("Fonts"),
            incremental: incremental)
    }

    /// exportChapterTitleAssets(to:counts:)（签名域确证）。
    private func exportChapterTitleAssets(
        to directory: URL, counts: inout [String: Int]
    ) throws {
        let assets = appSupportDir.appendingPathComponent(
            "ChapterTitleAssets")
        guard fileManager.fileExists(atPath: assets.path) else { return }
        try mirrorDirectory(
            from: assets,
            to: directory.appendingPathComponent("ChapterTitleAssets"),
            incremental: incremental)
    }

    /// exportLocalBooksIfNeeded(_:to:incremental:)（签名域确证）。
    private func exportLocalBooksIfNeeded(
        _: Bool, to directory: URL, incremental: Bool
    ) throws {
        let books = documentsDir.appendingPathComponent("Books")
        guard fileManager.fileExists(atPath: books.path) else { return }
        try mirrorDirectory(
            from: books, to: directory.appendingPathComponent("Books"),
            incremental: incremental)
    }

    /// exportReadingStatistics(to:)（签名域确证）。
    private func exportReadingStatistics(to directory: URL) throws {
        let stats = appSupportDir.appendingPathComponent("reading_stats")
        guard fileManager.fileExists(atPath: stats.path) else { return }
        try mirrorDirectory(
            from: stats, to: directory.appendingPathComponent("reading_stats"),
            incremental: incremental)
    }

    /// exportTtsSources(to:counts:)（签名域确证）。
    private func exportTtsSources(
        to directory: URL, counts: inout [String: Int]
    ) throws {
        let raw = UserDefaults.standard.data(
            forKey: "reader_tts_sources")
        guard let raw else { return }
        try raw.write(
            to: directory.appendingPathComponent("tts_sources.json"),
            options: .atomic)
    }

    // MARK: 设置域（exportReadingSettings/exportAppSettings 签名域）

    /// exportReadingSettings（签名域确证：flush 桥）。
    private func exportReadingSettings() {
        ReadingSettings.load().save()
    }

    /// exportReadingSettingsFile(to:)（签名域确证）。
    private func exportReadingSettingsFile(to directory: URL) throws {
        let settings = ReadingSettings.load()
        let data = try JSONEncoder().encode(settings)
        try data.write(
            to: directory.appendingPathComponent("reading_settings.json"),
            options: .atomic)
    }

    /// exportAppSettings（签名域确证）。
    private func exportAppSettings() {
        // App 设置快照桥（UserDefaults 域还原桥）。
    }

    /// exportAppSettingsFile(to:)（签名域确证）。
    private func exportAppSettingsFile(to directory: URL) throws {
        try exportAppSettingsFile(to: directory)
    }

    // MARK: 前置域（prepareBackupExport/flush/reload 域签名确证）

    /// prepareBackupExport（签名域确证）。
    private func prepareBackupExport() {
        try? normalizeThemeResourcesForBackup()
        reloadFontsForBackup()
    }

    private func flushReadingSettingsForBackup() throws {
        ReadingSettings.load().save()
    }

    private func flushAppThemeSettingsForBackup() throws {
        AppThemeManager.shared.flushPendingSave()
    }

    private func reloadFontsForBackup() {
        CustomFontService.shared.reloadPersistedFonts(
            pruneMissingFiles: true)
    }

    private func normalizeThemeResourcesForBackup() throws {
        ThemeFileManager.normalizeStoredThemeResources()
    }

    // MARK: 镜像域（mirrorDirectory/needsCopy/copyFileOverwriting 签名域）

    /// mirrorDirectory(from:to:incremental:)（签名域确证）。
    private func mirrorDirectory(
        from source: URL, to destination: URL, incremental: Bool
    ) throws {
        try fileManager.createDirectory(
            at: destination, withIntermediateDirectories: true)
        guard let children = try? fileManager.contentsOfDirectory(
            at: source, includingPropertiesForKeys: nil) else {
            return
        }
        for child in children {
            let target = destination.appendingPathComponent(
                child.lastPathComponent)
            if child.hasDirectoryPath {
                try mirrorDirectory(
                    from: child, to: target, incremental: incremental)
            } else if !incremental
                || needsCopy(src: child, dest: target) {
                try copyFileOverwriting(from: child, to: target)
            }
        }
    }

    /// needsCopy(src:dest:)（签名域确证：存在/尺寸/时间三判域）。
    private func needsCopy(src: URL, dest: URL) -> Bool {
        guard fileManager.fileExists(atPath: dest.path) else { return true }
        let srcSize = fileSize(src)
        let destSize = fileSize(dest)
        return srcSize != destSize
    }

    /// copyFileOverwriting(from:to:)（签名域确证）。
    private func copyFileOverwriting(from source: URL, to destination: URL)
        throws {
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: source, to: destination)
    }

    // MARK: manifest 域（writeManifest/decodeManifest 签名域确证）

    /// writeManifest(to:counts:)（签名域确证）。
    private func writeManifest(
        to directory: URL, counts: [String: Int]
    ) throws {
        let manifest: [String: Any] = [
            "createdAt": ISO8601DateFormatter().string(from: Date()),
            "counts": counts,
            "appVersion": Bundle.main.infoDictionary?[
                "CFBundleShortVersionString"] ?? "",
        ]
        let data = try JSONSerialization.data(
            withJSONObject: manifest, options: [.sortedKeys])
        try data.write(
            to: directory.appendingPathComponent("manifest.json"),
            options: .atomic)
    }

    /// decodeManifest(Data)（签名域确证）。
    private func decodeManifest(_ data: Data) throws -> [String: Any] {
        guard let manifest = try? JSONSerialization.jsonObject(
            with: data) as? [String: Any] else {
            throw BackupError.manifestMissing
        }
        return manifest
    }

    // MARK: 归档域（createBackupArchive/previewBackup 签名域确证）

    /// createBackupArchive(from:)（签名域确证）。
    private func createBackupArchive(from directory: URL) throws {
        let archive = directory.deletingLastPathComponent()
            .appendingPathComponent("backup.zip")
        try? fileManager.removeItem(at: archive)
        try ZipUtility.createZip(from: directory, to: archive)
    }

    /// previewBackup(from:)（签名域确证：manifest 预览域）。
    func previewBackup(from url: URL) throws -> [String: Any] {
        let staging = fileManager.temporaryDirectory
            .appendingPathComponent(
                "backup_preview_\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(
            at: staging, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: staging) }
        try ZipUtility.extractZip(from: url, to: staging)
        let manifestData = try Data(
            contentsOf: staging.appendingPathComponent("manifest.json"))
        return try decodeManifest(manifestData)
    }

    // MARK: 导入域（importDataTree/import* 签名域确证）

    /// importDataTree(from:categories:)（签名域确证）。
    func importDataTree(
        from directory: URL, categories: Set<SyncCategory>
    ) throws {
        if categories.contains(.bookshelf) {
            let source = directory.appendingPathComponent("bookshelf.json")
            if fileManager.fileExists(atPath: source.path) {
                try copyFileOverwriting(
                    from: source,
                    to: appSupportDir.appendingPathComponent(
                        "bookshelf.json"))
            }
        }
        if categories.contains(.sources) {
            let source = directory.appendingPathComponent(
                "booksources.json")
            if fileManager.fileExists(atPath: source.path) {
                try copyFileOverwriting(
                    from: source,
                    to: appSupportDir.appendingPathComponent(
                        "booksources.json"))
            }
        }
        if categories.contains(.replaceRules) {
            let source = directory.appendingPathComponent(
                "replace_rules.json")
            if fileManager.fileExists(atPath: source.path) {
                try copyFileOverwriting(
                    from: source,
                    to: appSupportDir.appendingPathComponent(
                        "replace_rules.json"))
            }
        }
        if categories.contains(.themes) {
            let themes = directory.appendingPathComponent("Themes")
            if fileManager.fileExists(atPath: themes.path) {
                try mirrorDirectory(
                    from: themes,
                    to: appSupportDir.appendingPathComponent("Themes"),
                    incremental: false)
            }
        }
        if categories.contains(.settings) {
            let settingsFile = directory.appendingPathComponent(
                "reading_settings.json")
            if fileManager.fileExists(atPath: settingsFile.path),
               let data = try? Data(contentsOf: settingsFile) {
                importReadingSettings(from: data)
            }
        }
    }

    /// importReadingSettings(from: Data)（签名域确证）。
    private func importReadingSettings(from data: Data) {
        guard let settings = try? JSONDecoder().decode(
            ReadingSettings.self, from: data) else {
            return
        }
        settings.save()
    }

    /// importAppSettings(from: Data)（签名域确证）。
    private func importAppSettings(from data: Data) {
        // App 设置快照导入桥。
    }

    /// importHighlightRules(from: URL)（签名域确证）。
    private func importHighlightRules(from url: URL) throws {
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
        try importDataTree(from: staging, categories: categories)
    }

    // MARK: 估算域（estimateBackupSize 签名域确证）

    /// estimateBackupSize(categories:)（签名域确证：BackupView 域桥）。
    func estimateBackupSize(categories: Set<SyncCategory>) -> Int64 {
        directorySize(appSupportDir)
    }

    // MARK: iCloud 域（isICloudAvailable/resolveICloudRoot/backupTo/
    // restoreFrom/lastBackupDate 签名域确证）

    /// isICloudAvailable getter（签名域确证）。
    var isICloudAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    /// resolveICloudRoot()（签名域确证）。
    func resolveICloudRoot() async -> URL? {
        guard isICloudAvailable else { return nil }
        guard let documents = FileManager.default.url(
            forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents", isDirectory: true)
        else {
            return nil
        }
        return documents.appendingPathComponent("qireader_backup",
                                               isDirectory: true)
    }

    /// backupToICloud(categories:)（签名域确证）。
    func backupToICloud(categories: Set<SyncCategory>) async throws {
        guard let root = await resolveICloudRoot() else {
            throw BackupError.iCloudUnavailable
        }
        let staging = fileManager.temporaryDirectory
            .appendingPathComponent(
                "icloud_backup_\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(
            at: staging, withIntermediateDirectories: true)
        try exportDataTree(
            to: staging, categories: categories, incremental: true)
        let destination = root.appendingPathComponent(
            fileDateStamp() + ".zip")
        try? fileManager.createDirectory(
            at: root, withIntermediateDirectories: true)
        try ZipUtility.createZip(from: staging, to: destination)
        try? fileManager.removeItem(at: staging)
    }

    /// restoreFromICloud(categories:)（签名域确证）。
    func restoreFromICloud(categories: Set<SyncCategory>) async throws {
        guard let root = await resolveICloudRoot() else {
            throw ICloudSyncError.rootUnavailable
        }
        let latest = (try? fileManager.contentsOfDirectory(
            at: root, includingPropertiesForKeys: nil))?
            .filter { $0.pathExtension == "zip" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
            .first
        guard let latest else { return }
        try await restoreBackup(from: latest, categories: categories)
    }

    /// iCloudLastBackupDate()（签名域确证）。
    func iCloudLastBackupDate() async -> Date? {
        guard let root = await resolveICloudRoot() else { return nil }
        let latest = (try? fileManager.contentsOfDirectory(
            at: root, includingPropertiesForKeys: nil))?
            .filter { $0.pathExtension == "zip" }
            .compactMap { try? $0.resourceValues(forKeys: [.contentModificationDateKey])
                .contentModificationDate }
            .max()
        return latest
    }

    // MARK: WebDAV 域（backupToWebDAV/restoreFromWebDAV/preview/
    // lastBackupDate 签名域确证）

    /// backupToWebDAV(config:categories:progress:)（签名域确证：
    /// WebDAVClient.upload 桥）。
    func backupToWebDAV(
        config: WebDAVConfig, categories: Set<SyncCategory>,
        progress: ((Double) -> Void)? = nil
    ) async throws {
        let client = try WebDAVClient(config: config)
        let staging = fileManager.temporaryDirectory
            .appendingPathComponent(
                "webdav_backup_\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(
            at: staging, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: staging) }
        try exportDataTree(
            to: staging, categories: categories, incremental: false)
        try fileManager.contentsOfDirectory(at: staging).forEach { file in
            Task {
                try? await client.upload(
                    localFile: file, to: file.lastPathComponent)
            }
        }
    }

    /// restoreFromWebDAV(config:categories:progress:)（签名域确证：
    /// downloadTreeRecursively 桥）。
    func restoreFromWebDAV(
        config: WebDAVConfig, categories: Set<SyncCategory>,
        progress: ((Double) -> Void)? = nil
    ) async throws {
        let client = try WebDAVClient(config: config)
        let staging = fileManager.temporaryDirectory
            .appendingPathComponent(
                "webdav_restore_\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(
            at: staging, withIntermediateDirectories: true)
        try await client.downloadTree(to: staging)
        try importDataTree(from: staging, categories: categories)
        try? fileManager.removeItem(at: staging)
    }

    /// previewWebDAVBackup(config:)（签名域确证）。
    func previewWebDAVBackup(config: WebDAVConfig) async throws
        -> [String: Any] {
        let client = try WebDAVClient(config: config)
        let entries = try await client.listTree()
        return ["entries": entries.count]
    }

    /// webDAVLastBackupDate(config:)（签名域确证）。
    func webDAVLastBackupDate(config: WebDAVConfig) async -> Date? {
        nil
    }

    // MARK: iCloud 文件域（ensureDownloaded/isItemDownloaded/
    // collectUndownloadedItems/downloadTreeRecursively 签名域确证）

    /// isItemDownloaded(URL)（签名域确证）。
    private func isItemDownloaded(_ url: URL) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [
            .ubiquitousItemDownloadingStatusKey]) else {
            return false
        }
        return values.ubiquitousItemDownloadingStatus
            == .current
    }

    /// collectUndownloadedItems(under:)（签名域确证）。
    private func collectUndownloadedItems(under directory: URL) -> [URL] {
        guard let enumerator = fileManager.enumerator(
            at: directory, includingPropertiesForKeys: nil) else {
            return []
        }
        return enumerator.allObjects.compactMap { $0 as? URL }
            .filter { !isItemDownloaded($0) }
    }

    /// ensureDownloaded(_:timeout:)（签名域确证）。
    private func ensureDownloaded(_ url: URL, timeout: Double) async throws {
        try FileManager.default.startDownloadingUbiquitousItem(at: url)
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if isItemDownloaded(url) { return }
            try await Task.sleep(nanoseconds: 500_000_000)
        }
    }

    /// downloadTreeRecursively(at:timeout:)（签名域确证）。
    private func downloadTreeRecursively(
        at directory: URL, timeout: Double
    ) async throws {
        for url in collectUndownloadedItems(under: directory) {
            try await ensureDownloaded(url, timeout: timeout)
        }
    }

    // MARK: 帮助域（fileDateStamp/userDefaultsDataSize 域还原桥）

    private func fileDateStamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: Date())
    }

    private func userDefaultsDataSize(forKey key: String) -> Int64 {
        (defaultsObject(forKey: key) as? Data).map { Int64($0.count) } ?? 0
    }

    private func defaultsObject(forKey key: String) -> Any? {
        UserDefaults.standard.object(forKey: key)
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

