// 原路径: ReadMain/Services/BackupService.swift
// 分类边界与当前重建服务存储域对齐，测试可注入隔离目录。
import Foundation

extension BackupService {
    /// 所选分类的JSON全部读完并校验后才写入，后面的损坏文件不能造成前半恢复。
    func validateImportData(from directory: URL, categories: Set<SyncCategory>) throws {
        let names: [SyncCategory: [String]] = [
            .bookshelf: ["bookshelf.json", "groups.json", "readtimes.json", "pinnedbooks.json", "pinnedexplore.json"],
            .bookmarks: ["bookmarks.json"], .config: ["booksources.json"], .chapterRules: ["chapter_rules.json"],
            .replaceRules: ["replace_rules.json"], .highlightRules: ["highlight_rules.json"],
            .ttsSources: ["tts_sources.json"], .readingStats: ["reading_stats.json"],
            .readingSettings: ["reading_settings.json"], .localBooks: ["local_books_metadata.json"]]
        for category in categories {
            for name in names[category] ?? [] {
                guard let data = try readJSONPayload(name, from: directory) else { continue }
                switch category {
                case .readingStats:
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    _ = try decoder.decode([ReadingRecord].self, from: data)
                case .readingSettings: _ = try ReadingSettingsBackup.validatedValues(from: data)
                case .localBooks: _ = try JSONDecoder().decode([LocalBook].self, from: data)
                default: break
                }
            }
        }
        if categories.contains(.appearance), let metadata = try readJSONPayload("custom_fonts_meta.json", from: directory) {
            _ = try JSONDecoder().decode([CustomFontService.FontInfo].self, from: metadata)
        }
    }

    func estimatedFiles(for category: SyncCategory) -> [URL] {
        switch category {
        case .bookshelf:
            return ["bookshelf.json", "groups.json", "readtimes.json", "pinnedbooks.json", "pinnedexplore.json"]
                .compactMap { existingFile([documentsDir.appendingPathComponent("bookshelf_data/" + $0), appSupportDir.appendingPathComponent("BookService/" + $0)]) }
        case .bookmarks: return [documentsDir.appendingPathComponent("bookshelf_data/bookmarks.json")]
        case .config: return [documentsDir.appendingPathComponent("BookSources.json")]
        case .chapterRules: return [documentsDir.appendingPathComponent("chapter_rules.json")]
        case .replaceRules: return [appSupportDir.appendingPathComponent("replace_rules.json")]
        case .readingStats:
            let canonical = appSupportDir.appendingPathComponent("ReadingStatistics/records.json")
            if fileManager.fileExists(atPath: canonical.path) { return [canonical] }
            return ((try? fileManager.contentsOfDirectory(at: documentsDir, includingPropertiesForKeys: nil)) ?? [])
                .filter { $0.lastPathComponent.hasPrefix("reading_stats_") && $0.pathExtension == "json" }
        case .highlightRules: return [appSupportDir.appendingPathComponent("highlight_rules.json")]
        case .appearance: return ["Themes", "AppThemes", "ChapterTitleAssets"].map { appSupportDir.appendingPathComponent($0) }
            + [documentsDir.appendingPathComponent("CustomFonts"), documentsDir.appendingPathComponent("ReaderBackgrounds")]
        case .localBooks: return ["Books", "local_books", "local_book_covers", "local_books_metadata.json"].map { documentsDir.appendingPathComponent($0) }
        case .readingSettings, .ttsSources: return []
        }
    }

    func existingFile(_ candidates: [URL]) -> URL? {
        candidates.first { fileManager.fileExists(atPath: $0.path) }
    }

    func writeJSONPayload(_ data: Data, name: String, to directory: URL, counts: inout [String: Int]) throws {
        let object = try JSONSerialization.jsonObject(with: data)
        counts[name] = (object as? [Any])?.count ?? (object as? [String: Any])?.count ?? 1
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: directory.appendingPathComponent(name), options: .atomic)
    }

    func exportJSONFile(candidates: [URL], name: String, to directory: URL, counts: inout [String: Int]) throws {
        guard let source = existingFile(candidates) else { return }
        try writeJSONPayload(Data(contentsOf: source), name: name, to: directory, counts: &counts)
    }

    func readJSONPayload(_ name: String, from directory: URL) throws -> Data? {
        let url = directory.appendingPathComponent(name)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        _ = try JSONSerialization.jsonObject(with: data)
        return data
    }

    func importJSONFile(_ name: String, from directory: URL, to destination: URL) throws {
        guard let data = try readJSONPayload(name, from: directory) else { return }
        try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: destination, options: .atomic)
    }

    func importLocalBookFiles(from directory: URL) throws {
        // 先校验元数据再写文件；绝对路径按导入后的文件名重定位，不能保留旧设备沙盒路径。
        let metadata = try readJSONPayload("local_books_metadata.json", from: directory)
        var books = try metadata.map { try JSONDecoder().decode([LocalBook].self, from: $0) }
        if var relocated = books {
            for index in relocated.indices {
                let fileName = relocated[index].fileURL.lastPathComponent
                guard !fileName.isEmpty else { throw BackupError.archiveFailed }
                relocated[index].filePath = documentsDir.appendingPathComponent("local_books").appendingPathComponent(fileName).path
            }
            books = relocated
        }
        for name in ["Books", "local_books", "local_book_covers"] {
            let source = directory.appendingPathComponent(name)
            guard fileManager.fileExists(atPath: source.path) else { continue }
            try mirrorDirectory(from: source, to: documentsDir.appendingPathComponent(name), incremental: false)
        }
        if let books {
            try fileManager.createDirectory(at: documentsDir, withIntermediateDirectories: true)
            try JSONEncoder().encode(books).write(to: documentsDir.appendingPathComponent("local_books_metadata.json"), options: .atomic)
        }
    }

    /// 0x1002c0ec8：归档名与消费方目录分别映射，字体清单必须与文件一起恢复。
    func importAppearanceResources(from directory: URL) throws {
        let resources: [([String], URL)] = [
            (["themes", "Themes"], appSupportDir.appendingPathComponent("Themes")),
            (["reader_backgrounds", "backgrounds"], documentsDir.appendingPathComponent("ReaderBackgrounds")),
            (["chapter_title_assets", "ChapterTitleAssets"], appSupportDir.appendingPathComponent("ChapterTitleAssets")),
            (["custom_fonts", "Fonts/CustomFonts"], documentsDir.appendingPathComponent("CustomFonts"))]
        for (names, target) in resources {
            if let source = existingFile(names.map { directory.appendingPathComponent($0) }) {
                try mirrorDirectory(from: source, to: target, incremental: false)
            }
        }
        if let metadata = try readJSONPayload("custom_fonts_meta.json", from: directory) {
            let fonts = try JSONDecoder().decode([CustomFontService.FontInfo].self, from: metadata)
            defaults.set(try JSONEncoder().encode(fonts), forKey: CustomFontService.fontListDefaultsKey)
        }
        if documentsOverride == nil && supportOverride == nil {
            CustomFontService.shared.reloadPersistedFonts(pruneMissingFiles: true)
        }
    }
}
