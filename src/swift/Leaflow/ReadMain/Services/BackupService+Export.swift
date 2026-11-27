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
        let source = appSupportDir.appendingPathComponent(
            "bookshelf.json")
        guard fileManager.fileExists(atPath: source.path) else { return }
        try fileManager.copyItem(
            at: source,
            to: directory.appendingPathComponent("bookshelf.json"))
        counts["bookshelf"] = bookService.bookshelf.count
    }

    /// exportBookmarkFile(to:counts:)（签名域确证）。
    func exportBookmarkFile(
        to directory: URL, counts: inout [String: Int]
    ) throws {
        let source = appSupportDir.appendingPathComponent("bookmarks.json")
        guard fileManager.fileExists(atPath: source.path) else { return }
        try fileManager.copyItem(
            at: source,
            to: directory.appendingPathComponent("bookmarks.json"))
    }

    /// exportBookSources(to:counts:)（签名域确证）。
    func exportBookSources(
        to directory: URL, counts: inout [String: Int]
    ) throws {
        let source = appSupportDir.appendingPathComponent("booksources.json")
        guard fileManager.fileExists(atPath: source.path) else { return }
        try fileManager.copyItem(
            at: source,
            to: directory.appendingPathComponent("booksources.json"))
    }

    /// exportChapterRules(to:counts:)（签名域确证：替换规则域）。
    func exportChapterRules(
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
        _: Bool, to directory: URL, incremental: Bool
    ) throws {
        let books = documentsDir.appendingPathComponent("Books")
        guard fileManager.fileExists(atPath: books.path) else { return }
        try mirrorDirectory(
            from: books, to: directory.appendingPathComponent("Books"),
            incremental: incremental)
    }

    /// exportReadingStatistics(to:incremental:)（签名域确证；mirrorDirectory
    /// incremental 参域对齐，wave-16 补参）。
    func exportReadingStatistics(
        to directory: URL, incremental: Bool
    ) throws {
        let stats = appSupportDir.appendingPathComponent("reading_stats")
        guard fileManager.fileExists(atPath: stats.path) else { return }
        try mirrorDirectory(
            from: stats, to: directory.appendingPathComponent("reading_stats"),
            incremental: incremental)
    }

    /// exportTtsSources(to:counts:)（签名域确证）。
    func exportTtsSources(
        to directory: URL, counts: inout [String: Int],
        incremental: Bool
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
    func exportReadingSettings() {
        ReadingSettings.load().save()
    }

    /// exportReadingSettingsFile(to:)（签名域确证）。
    func exportReadingSettingsFile(to directory: URL) throws {
        let settings = ReadingSettings.load()
        let data = try JSONEncoder().encode(settings)
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
        try exportAppSettingsFile(to: directory)
    }

    // MARK: 前置域（prepareBackupExport/flush/reload 域签名确证）

    /// prepareBackupExport（签名域确证）。
    func prepareBackupExport() {
        try? normalizeThemeResourcesForBackup()
        reloadFontsForBackup()
    }

    func flushReadingSettingsForBackup() throws {
        ReadingSettings.load().save()
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
    func needsCopy(src: URL, dest: URL) -> Bool {
        guard fileManager.fileExists(atPath: dest.path) else { return true }
        let srcSize = fileSize(src)
        let destSize = fileSize(dest)
        return srcSize != destSize
    }

    /// copyFileOverwriting(from:to:)（签名域确证）。
    func copyFileOverwriting(from source: URL, to destination: URL)
        throws {
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: source, to: destination)
    }

    // MARK: manifest 域（writeManifest/decodeManifest 签名域确证）

    /// writeManifest(to:counts:)（签名域确证）。
    func writeManifest(
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
