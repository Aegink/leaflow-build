// T-1602：分类偏好与实际导出/恢复边界；全部文件和UserDefaults使用隔离目录。
import Foundation

enum BackupSelectionSampleSelfTest {
    @MainActor
    static func run(emit: (String, [String], [String]) -> Void) async {
        let identifier = "backup-selection-" + UUID().uuidString
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(identifier)
        let defaults = UserDefaults(suiteName: identifier)!
        defer {
            defaults.removePersistentDomain(forName: identifier)
            try? FileManager.default.removeItem(at: root)
        }
        func names(_ values: Set<SyncCategory>) -> String { values.map(\.rawValue).sorted().joined(separator: ",") }
        do {
            let preferences = BackupSyncPreferences(defaults: defaults)
            emit("backup_categories_original_cases", ["bookshelf,bookmarks,readingStats,config,chapterRules,replaceRules,ttsSources,readingSettings,highlightRules,appearance,localBooks"],
                [SyncCategory.allCases.map(\.rawValue).joined(separator: ",")])
            emit("backup_categories_default_excludes_files", ["10", "false"],
                [String(preferences.selectedCategories.count), String(preferences.isEnabled(.localBooks))])
            preferences.setSelectedCategories([])
            emit("backup_categories_empty_survives_restart", ["0"],
                [String(BackupSyncPreferences(defaults: defaults).selectedCategories.count)])
            preferences.setEnabled(true, for: .localBooks)
            emit("backup_categories_single_selection", ["localBooks"], [names(BackupSyncPreferences(defaults: defaults).selectedCategories)])
            defaults.set(["bookshelf"], forKey: "BackupSyncKnownCategories")
            defaults.set([], forKey: "BackupSyncEnabledCategories")
            let upgraded = BackupSyncPreferences(defaults: defaults)
            emit("backup_categories_new_defaults_only", ["9", "false", "false"],
                [String(upgraded.selectedCategories.count), String(upgraded.isEnabled(.bookshelf)), String(upgraded.isEnabled(.localBooks))])
            defaults.removePersistentDomain(forName: identifier)
            defaults.set(["sources", "readingProgress", "settings"], forKey: "reader_sync_categories")
            emit("backup_categories_legacy_migration", ["bookshelf,config,readingSettings,readingStats,ttsSources"],
                [names(BackupSyncPreferences(defaults: defaults).selectedCategories)])
            defaults.removePersistentDomain(forName: identifier)
            defaults.set([], forKey: "reader_sync_categories")
            emit("backup_categories_legacy_empty", ["0"], [String(BackupSyncPreferences(defaults: defaults).selectedCategories.count)])

            let docs = root.appendingPathComponent("documents"), support = root.appendingPathComponent("support")
            try FileManager.default.createDirectory(at: docs.appendingPathComponent("bookshelf_data"), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
            let shelf = Data(#"[{"name":"固定备份书架","bookUrl":"/book","bookSourceUrl":"https://sample.invalid"}]"#.utf8)
            try shelf.write(to: docs.appendingPathComponent("bookshelf_data/bookshelf.json"))
            try Data(#"["固定分组"]"#.utf8).write(to: docs.appendingPathComponent("bookshelf_data/groups.json"))
            var source = BookSource(bookSourceUrl: "https://sample.invalid/backup", bookSourceName: "固定备份源")
            source.storageKind = .local
            try JSONEncoder().encode([source]).write(to: docs.appendingPathComponent("BookSources.json"))
            defaults.set(Data(#"[{"name":"目录样本"}]"#.utf8), forKey: "chapter_rules")
            try Data(#"[{"name":"替换样本"}]"#.utf8).write(to: support.appendingPathComponent("replace_rules.json"))
            let backup = BackupService(documentsDirectory: docs, applicationSupportDirectory: support, defaults: defaults)
            emit("backup_empty_selection_size", ["0"], [String(backup.estimateBackupSize(categories: []))])
            let configOnly = root.appendingPathComponent("config-only")
            try backup.exportDataTree(to: configOnly, categories: [.config], incremental: false)
            emit("backup_selected_config_only", ["booksources.json,manifest.json"],
                [try FileManager.default.contentsOfDirectory(atPath: configOnly.path).sorted().joined(separator: ",")])
            let manifest = try backup.decodeManifest(Data(contentsOf: configOnly.appendingPathComponent("manifest.json")))
            emit("backup_manifest_selected_categories", ["config", "1"],
                [(manifest["categories"] as? [String] ?? []).joined(), String((manifest["counts"] as? [String: Int])?["booksources.json"] ?? -1)])
            let rulesOnly = root.appendingPathComponent("rules-only")
            try backup.exportDataTree(to: rulesOnly, categories: [.chapterRules], incremental: false)
            emit("backup_chapter_replace_separation", ["chapter_rules.json,manifest.json"],
                [try FileManager.default.contentsOfDirectory(atPath: rulesOnly.path).sorted().joined(separator: ",")])
            let shelfOnly = root.appendingPathComponent("shelf-only")
            try backup.exportDataTree(to: shelfOnly, categories: [.bookshelf], incremental: false)
            emit("backup_shelf_storage_files", ["bookshelf.json,groups.json,manifest.json"],
                [try FileManager.default.contentsOfDirectory(atPath: shelfOnly.path).sorted().joined(separator: ",")])
            let empty = root.appendingPathComponent("empty-selection")
            try backup.exportDataTree(to: empty, categories: [], incremental: false)
            emit("backup_empty_selection_manifest_only", ["manifest.json"],
                [try FileManager.default.contentsOfDirectory(atPath: empty.path).joined()])

            let targetDocs = root.appendingPathComponent("restored-documents")
            let targetSupport = root.appendingPathComponent("restored-support")
            try FileManager.default.createDirectory(at: targetDocs, withIntermediateDirectories: true)
            let restore = BackupService(documentsDirectory: targetDocs, applicationSupportDirectory: targetSupport, defaults: defaults)
            try restore.importDataTree(from: configOnly, categories: [])
            emit("backup_unselected_restore_no_write", ["0"], [String(try FileManager.default.contentsOfDirectory(atPath: targetDocs.path).count)])
            try restore.importDataTree(from: configOnly, categories: [.config])
            let sources = SourceService(storageDirectory: targetDocs)
            await sources.loadLocalSources()
            emit("backup_restored_source_service_reads", ["固定备份源"], sources.bookSources.map(\.bookSourceName))
            try restore.importDataTree(from: shelfOnly, categories: [.bookshelf])
            emit("backup_restored_shelf_bytes", ["true"], [String(try Data(contentsOf: targetDocs.appendingPathComponent("bookshelf_data/bookshelf.json")) == shelf)])

            let localInput = root.appendingPathComponent("fixed.txt")
            try "固定备份正文".write(to: localInput, atomically: true, encoding: .utf8)
            let local = LocalBookService(storageDirectory: docs.appendingPathComponent("local_books"))
            guard let book = await local.importBook(from: localInput) else { throw AppError.emptyContent }
            try JSONEncoder().encode([book]).write(to: docs.appendingPathComponent("local_books_metadata.json"))
            let localTree = root.appendingPathComponent("local-tree")
            try backup.exportDataTree(to: localTree, categories: [.localBooks], incremental: false)
            let archive = root.appendingPathComponent("local.zip")
            try ZipUtility.createZip(from: localTree, to: archive)
            try await restore.restoreBackup(from: archive, categories: [.localBooks])
            let relocated = try JSONDecoder().decode([LocalBook].self,
                from: Data(contentsOf: targetDocs.appendingPathComponent("local_books_metadata.json")))[0]
            let restoredLocal = LocalBookService(storageDirectory: targetDocs.appendingPathComponent("local_books"))
            emit("backup_local_file_relocated_readable", ["true", "固定备份正文"],
                [String(relocated.filePath.hasPrefix(targetDocs.path)), restoredLocal.getChapterContent(book: relocated, chapterIndex: 0) ?? ""])
            try Data("{".utf8).write(to: configOnly.appendingPathComponent("booksources.json"))
            let before = try Data(contentsOf: targetDocs.appendingPathComponent("BookSources.json"))
            var rejected = false
            do { try restore.importDataTree(from: configOnly, categories: [.config]) } catch { rejected = true }
            emit("backup_invalid_json_preserves_destination", ["true", "true"], [String(rejected),
                String(try Data(contentsOf: targetDocs.appendingPathComponent("BookSources.json")) == before)])
        } catch { emit("backup_selected_config_only", ["通过"], [error.localizedDescription]) }
    }
}
