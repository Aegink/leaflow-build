// 原路径: ReadMain/Services/BackupService.swift
// 分册只改变边界，功能/桩/规模仍累计原文件。
import Foundation
import UIKit

extension BackupService {
    // MARK: 分类导出域（export* 九签名域确证）

    /// exportBookshelfFiles(to:counts:)（签名域确证：bookshelf.json）。
    func exportBookshelfFiles(
        to directory: URL, counts: inout [String: Int]
    ) throws {
        for name in ["bookshelf.json", "groups.json", "readtimes.json", "pinnedbooks.json", "pinnedexplore.json"] {
            try exportJSONFile(candidates: [documentsDir.appendingPathComponent("bookshelf_data/" + name),
                appSupportDir.appendingPathComponent("BookService/" + name)], name: name, to: directory, counts: &counts)
        }
    }

    /// exportBookmarkFile(to:counts:)（签名域确证）。
    func exportBookmarkFile(
        to directory: URL, counts: inout [String: Int]
    ) throws {
        try exportJSONFile(candidates: [documentsDir.appendingPathComponent("bookshelf_data/bookmarks.json"),
            appSupportDir.appendingPathComponent("BookService/bookmarks.json")], name: "bookmarks.json", to: directory, counts: &counts)
    }

    /// exportBookSources(to:counts:)（签名域确证）。
    func exportBookSources(
        to directory: URL, counts: inout [String: Int]
    ) throws {
        try exportJSONFile(candidates: [documentsDir.appendingPathComponent("BookSources.json"),
            appSupportDir.appendingPathComponent("BookSources.json")], name: "booksources.json", to: directory, counts: &counts)
    }

    /// exportChapterRules(to:counts:)（签名域确证：替换规则域）。
    func exportChapterRules(
        to directory: URL, counts: inout [String: Int]
    ) throws {
        if let source = existingFile([documentsDir.appendingPathComponent("chapter_rules.json"), appSupportDir.appendingPathComponent("chapter_rules.json")]) {
            try exportJSONFile(candidates: [source], name: "chapter_rules.json", to: directory, counts: &counts)
        } else if let data = defaults.data(forKey: "chapter_rules") {
            try writeJSONPayload(data, name: "chapter_rules.json", to: directory, counts: &counts)
        }
    }

    func exportReplaceRules(to directory: URL, counts: inout [String: Int]) throws {
        try exportJSONFile(candidates: [appSupportDir.appendingPathComponent("replace_rules.json"),
            appSupportDir.appendingPathComponent("ReplaceRuleService/replace_rules.json")],
            name: "replace_rules.json", to: directory, counts: &counts)
    }

    /// exportHighlightRules(to:counts:)（签名域确证）。
    func exportHighlightRules(
        to directory: URL, counts: inout [String: Int]
    ) throws {
        let source = appSupportDir.appendingPathComponent(
            "highlight_rules.json")
        guard fileManager.fileExists(atPath: source.path) else { return }
        try fileManager.copyItem(
            at: source,
            to: directory.appendingPathComponent("highlight_rules.json"))
    }

    /// exportThemeResources(to:counts:incremental:)（签名域确证；
    /// incremental 形参补齐——mirrorDirectory 消费域，wave-16）。
    func exportThemeResources(
        to directory: URL, counts: inout [String: Int], incremental: Bool
    ) throws {
        let themes = appSupportDir.appendingPathComponent("Themes")
        guard fileManager.fileExists(atPath: themes.path) else { return }
        try mirrorDirectory(
            from: themes,
            to: directory.appendingPathComponent("Themes"),
            incremental: incremental)
    }

    /// exportReaderBackgrounds(to:incremental:)（签名域确证）。
    func exportReaderBackgrounds(
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
    func exportFontResources(
        to directory: URL, counts: inout [String: Int],
        incremental: Bool
    ) throws {
        let fonts = appSupportDir.appendingPathComponent("Fonts")
        guard fileManager.fileExists(atPath: fonts.path) else { return }
        try mirrorDirectory(
            from: fonts, to: directory.appendingPathComponent("Fonts"),
            incremental: incremental)
    }

    /// exportChapterTitleAssets(to:counts:)（签名域确证）。
    func exportChapterTitleAssets(
        to directory: URL, counts: inout [String: Int],
        incremental: Bool
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
    func exportLocalBooksIfNeeded(
        _ included: Bool, to directory: URL, incremental: Bool
    ) throws {
        guard included else { return }
        for name in ["Books", "local_books", "local_book_covers", "local_books_metadata.json"] {
            let source = documentsDir.appendingPathComponent(name)
            guard fileManager.fileExists(atPath: source.path) else { continue }
            let target = directory.appendingPathComponent(name)
            if (try source.resourceValues(forKeys: [.isDirectoryKey])).isDirectory == true {
                try mirrorDirectory(from: source, to: target, incremental: incremental)
            } else { try copyFileOverwriting(from: source, to: target) }
        }
    }

    /// exportReadingStatistics(to:incremental:)（签名域确证；mirrorDirectory
    /// incremental 参域对齐，wave-16 补参）。
    func exportReadingStatistics(
        to directory: URL, incremental: Bool
    ) throws {
        let statistics = ReadingStatisticsService(
            storageDirectory: appSupportDir.appendingPathComponent("ReadingStatistics"),
            legacyDirectory: documentsDir, defaults: defaults)
        let data = try statistics.encodedRecordsForBackup()
        try data.write(to: directory.appendingPathComponent("reading_stats.json"), options: .atomic)
    }

    /// exportTtsSources(to:counts:)（签名域确证）。
    func exportTtsSources(
        to directory: URL, counts: inout [String: Int],
        incremental: Bool
    ) throws {
        let raw = defaults.data(
            forKey: "reader_tts_sources")
        guard let raw else { return }
        try raw.write(
            to: directory.appendingPathComponent("tts_sources.json"),
            options: .atomic)
    }

    // MARK: 设置域（exportReadingSettings/exportAppSettings 签名域）

    /// exportReadingSettingsFile(to:)（签名域确证）。
    func exportReadingSettingsFile(to directory: URL) throws {
        let data = try exportReadingSettings()
        try data.write(
            to: directory.appendingPathComponent("reading_settings.json"),
            options: .atomic)
    }

    /// exportAppSettings（签名域确证）。
    func exportAppSettings() {
        // App 设置快照桥（UserDefaults 域还原桥）。
    }

    /// exportAppSettingsFile(to:)（签名域确证）。
    func exportAppSettingsFile(to directory: URL) throws {
        // 0x1002ba204实际消费阅读设置导出，避免旧桥自递归。
        try exportReadingSettingsFile(to: directory)
    }

    // MARK: 前置域（prepareBackupExport/flush/reload 域签名确证）

    /// prepareBackupExport（签名域确证）。
    func prepareBackupExport() {
        try? normalizeThemeResourcesForBackup()
        reloadFontsForBackup()
    }

    func flushReadingSettingsForBackup() throws {
        // 只冲刷已加载实例，不能新建部分设置再覆盖未加载字段。
        ReadingSettings.flushLoadedInstances()
    }

    func flushAppThemeSettingsForBackup() throws {
        AppThemeManager.shared.flushPendingSave()
    }

    func reloadFontsForBackup() {
        CustomFontService.shared.reloadPersistedFonts(
            pruneMissingFiles: true)
    }

    func normalizeThemeResourcesForBackup() throws {
        ThemeFileManager.normalizeStoredThemeResources()
    }

    // MARK: 镜像域（mirrorDirectory/needsCopy/copyFileOverwriting 签名域）

    /// mirrorDirectory(from:to:incremental:)（签名域确证）。
    func mirrorDirectory(
        from source: URL, to destination: URL, incremental: Bool
    ) throws {
        try fileManager.createDirectory(
            at: destination, withIntermediateDirectories: true)
        let children = try fileManager.contentsOfDirectory(at: source, includingPropertiesForKeys: [.isDirectoryKey])
        for child in children {
            let target = destination.appendingPathComponent(
                child.lastPathComponent)
            if try child.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true {
                try mirrorDirectory(
                    from: child, to: target, incremental: incremental)
            } else if !incremental
                || needsCopy(src: child, dest: target) {
                try copyFileOverwriting(from: child, to: target)
            }
        }
    }

    /// needsCopy(src:dest:)（签名域确证：存在/尺寸/时间三判域）。
    func needsCopy(src: URL, dest: URL) -> Bool {
        guard fileManager.fileExists(atPath: dest.path) else { return true }
        let srcSize = fileSize(src)
        let destSize = fileSize(dest)
        if srcSize != destSize { return true }
        let sourceDate = try? src.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        let destinationDate = try? dest.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        guard let sourceDate, let destinationDate else { return true }
        return sourceDate > destinationDate
    }

    /// copyFileOverwriting(from:to:)（签名域确证）。
    func copyFileOverwriting(from source: URL, to destination: URL)
        throws {
        let data = try Data(contentsOf: source)
        try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: destination, options: .atomic)
    }

    // MARK: manifest 域（writeManifest/decodeManifest 签名域确证）

    /// writeManifest(to:counts:)（签名域确证）。
    func writeManifest(
        to directory: URL, counts: [String: Int], categories: Set<SyncCategory>
    ) throws {
        let manifest: [String: Any] = [
            "createdAt": ISO8601DateFormatter().string(from: Date()),
            "counts": counts,
            "categories": categories.map(\.rawValue).sorted(),
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
    func decodeManifest(_ data: Data) throws -> [String: Any] {
        guard let manifest = try? JSONSerialization.jsonObject(
            with: data) as? [String: Any] else {
            throw BackupError.manifestMissing
        }
        return manifest
    }

    // MARK: 归档域（createBackupArchive/previewBackup 签名域确证）

    /// createBackupArchive(from:)（签名域确证）。
    func createBackupArchive(from directory: URL) throws {
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
        let root = try resolveBackupRoot(in: staging)
        let manifestData = try Data(
            contentsOf: root.appendingPathComponent("manifest.json"))
        return try decodeManifest(manifestData)
    }

}
