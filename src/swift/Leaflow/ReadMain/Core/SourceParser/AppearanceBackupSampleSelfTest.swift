// T-1602：原版字体清单、背景与章节标题资源，经真实ZIP备份恢复后消费。
import Foundation

enum AppearanceBackupSampleSelfTest {
    @MainActor
    static func run(emit: (String, [String], [String]) -> Void) async {
        let identifier = "appearance-sample-" + UUID().uuidString
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(identifier)
        let defaults = UserDefaults(suiteName: identifier)!
        let targetDefaults = UserDefaults(suiteName: identifier + "-target")!
        defer {
            defaults.removePersistentDomain(forName: identifier)
            targetDefaults.removePersistentDomain(forName: identifier + "-target")
            try? FileManager.default.removeItem(at: root)
        }
        do {
            let docs = root.appendingPathComponent("docs"), support = root.appendingPathComponent("support")
            let caches = root.appendingPathComponent("caches")
            let fontData = Data([0, 1, 2, 255, 0, 6])
            let imageData = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jM3sAAAAASUVORK5CYII=")!
            let metadata = Data(#"[{"id":"font-fixed","fileName":"fixed.ttf","originalFileName":"原文件.ttf","postScriptName":"Fixed-Regular","displayName":"固定字体"}]"#.utf8)
            let decoded = try JSONDecoder().decode([CustomFontService.FontInfo].self, from: metadata)
            emit("appearance_font_original_metadata", ["固定字体", "Fixed-Regular", "原文件.ttf"],
                [decoded[0].displayName, decoded[0].postScriptName ?? "", decoded[0].importDisplayFileName])
            emit("appearance_font_selection_uses_postscript", ["Fixed-Regular"], [decoded[0].name])
            let encoded = try JSONSerialization.jsonObject(with: JSONEncoder().encode(decoded[0])) as! [String: Any]
            emit("appearance_font_original_encoded_keys", ["displayName,fileName,id,originalFileName,postScriptName"], [encoded.keys.sorted().joined(separator: ",")])
            try FileManager.default.createDirectory(at: support.appendingPathComponent("Fonts/CustomFonts"), withIntermediateDirectories: true)
            try fontData.write(to: support.appendingPathComponent("Fonts/CustomFonts/fixed.ttf"))
            defaults.set(metadata, forKey: "reader_custom_fonts")
            let fonts = CustomFontService(documentsDirectory: docs, applicationSupportDirectory: support, defaults: defaults, registerFonts: false)
            let invalidURL = root.appendingPathComponent("invalid.ttf")
            try Data("not a font".utf8).write(to: invalidURL)
            let countBefore = fonts.fonts.count
            let importResult = fonts.importFontFromLocalFile(invalidURL)
            let invalidRejected: Bool
            if case .failure(.invalidFont) = importResult { invalidRejected = true } else { invalidRejected = false }
            emit("appearance_invalid_font_not_imported", ["true", "true"],
                [String(invalidRejected), String(fonts.fonts.count == countBefore)])
            emit("appearance_font_legacy_path_migrates", ["true", "true"],
                [String(fonts.fontsDirectory == docs.appendingPathComponent("CustomFonts", isDirectory: true)),
                 String(try Data(contentsOf: fonts.fontsDirectory.appendingPathComponent("fixed.ttf")) == fontData)])
            defaults.set(Data("[]".utf8), forKey: "importedCustomFonts")
            emit("appearance_font_reload_reads_before_prune", ["0"], [String(fonts.reloadPersistedFonts(pruneMissingFiles: true).count)])
            defaults.set(metadata, forKey: "importedCustomFonts")
            _ = fonts.reloadPersistedFonts(pruneMissingFiles: false)
            try FileManager.default.createDirectory(at: support.appendingPathComponent("ReaderBackgrounds"), withIntermediateDirectories: true)
            try imageData.write(to: support.appendingPathComponent("ReaderBackgrounds/background.png"))
            let backgrounds = try ReadingSettings.backgroundImagesDirectory(documents: docs, legacySupport: support)
            emit("appearance_background_legacy_path_migrates", ["true", "true"],
                [String(backgrounds.path.hasPrefix(docs.path)), String(try Data(contentsOf: backgrounds.appendingPathComponent("background.png")) == imageData)])
            try FileManager.default.createDirectory(at: caches.appendingPathComponent("chapter_title_assets"), withIntermediateDirectories: true)
            try imageData.write(to: caches.appendingPathComponent("chapter_title_assets/fixed-title.png"))
            let titles = ChapterTitleAssetManager(applicationSupportDirectory: support, legacyCachesDirectory: caches)
            emit("appearance_title_legacy_cache_migrates", ["true"],
                [String(titles.localURL(for: "fixed-title")?.path.hasPrefix(support.appendingPathComponent("ChapterTitleAssets").path) == true)])
            try FileManager.default.createDirectory(at: support.appendingPathComponent("Themes/fixed/icons"), withIntermediateDirectories: true)
            try imageData.write(to: support.appendingPathComponent("Themes/fixed/icons/tab.png"))
            try Data(#"{"id":"fixed","name":"固定主题"}"#.utf8).write(to: support.appendingPathComponent("Themes/fixed/theme.json"))
            let backup = BackupService(documentsDirectory: docs, applicationSupportDirectory: support, defaults: defaults)
            let tree = root.appendingPathComponent("tree")
            try backup.exportDataTree(to: tree, categories: [.appearance], incremental: false)
            emit("appearance_archive_original_paths", ["chapter_title_assets,custom_fonts,custom_fonts_meta.json,manifest.json,reader_backgrounds,themes"],
                [try FileManager.default.contentsOfDirectory(atPath: tree.path).sorted().joined(separator: ",")])
            try backup.exportDataTree(to: tree, categories: [.appearance], incremental: true)
            emit("appearance_incremental_existing_fonts", ["true"],
                [String(try Data(contentsOf: tree.appendingPathComponent("custom_fonts/fixed.ttf")) == fontData)])
            let archive = root.appendingPathComponent("appearance.zip")
            try ZipUtility.createZip(from: tree, to: archive)
            let targetDocs = root.appendingPathComponent("target-docs"), targetSupport = root.appendingPathComponent("target-support")
            let restore = BackupService(documentsDirectory: targetDocs, applicationSupportDirectory: targetSupport, defaults: targetDefaults)
            try await restore.restoreBackup(from: archive, categories: [.appearance])
            let restoredFonts = CustomFontService(documentsDirectory: targetDocs, applicationSupportDirectory: targetSupport,
                                                 defaults: targetDefaults, registerFonts: false)
            emit("appearance_restored_font_service", ["固定字体", "true"],
                [restoredFonts.fonts.first?.displayName ?? "", String(try Data(contentsOf: restoredFonts.fontsDirectory.appendingPathComponent("fixed.ttf")) == fontData)])
            let restoredBackgrounds = try ReadingSettings.backgroundImagesDirectory(documents: targetDocs, legacySupport: targetSupport)
            let restoredTitles = ChapterTitleAssetManager(applicationSupportDirectory: targetSupport, legacyCachesDirectory: root.appendingPathComponent("empty-cache"))
            emit("appearance_restored_image_consumers", ["true", "true", "true"],
                [String(try Data(contentsOf: restoredBackgrounds.appendingPathComponent("background.png")) == imageData),
                 String(try restoredTitles.packagedAsset(for: "fixed-title").data == imageData),
                 String(try Data(contentsOf: targetSupport.appendingPathComponent("Themes/fixed/icons/tab.png")) == imageData)])
            try Data(#"[{"id":"bad","fileName":"../outside.ttf"}]"#.utf8).write(to: tree.appendingPathComponent("custom_fonts_meta.json"))
            let before = targetDefaults.data(forKey: "importedCustomFonts")
            var rejected = false
            do { try restore.importDataTree(from: tree, categories: [.appearance]) } catch { rejected = true }
            emit("appearance_invalid_font_metadata_rejected", ["true", "true"],
                [String(rejected), String(targetDefaults.data(forKey: "importedCustomFonts") == before)])
        } catch { emit("appearance_restored_image_consumers", ["通过"], [error.localizedDescription]) }
    }
}
