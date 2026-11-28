// T-1602：原版57键、旧格式迁移及真实设置对象/备份归档往返，全部使用隔离UserDefaults。
import Foundation
import UIKit

enum ReadingSettingsSampleSelfTest {
    @MainActor
    static func run(emit: (String, [String], [String]) -> Void) async {
        let identifier = "settings-sample-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: identifier)!
        let targetDefaults = UserDefaults(suiteName: identifier + "-restored")!
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(identifier)
        defer {
            defaults.removePersistentDomain(forName: identifier)
            targetDefaults.removePersistentDomain(forName: identifier + "-restored")
            try? FileManager.default.removeItem(at: root)
        }
        do {
            let settings = ReadingSettings.load(from: defaults)
            settings.fontSize = 24.5
            settings.lineSpacing = 13
            settings.paragraphSpacing = 9
            settings.textIndent = 0
            settings.letterSpacing = -0.5
            settings.textAlignment = .justified
            settings.leftPageMargin = 0
            settings.rightPageMargin = 28
            settings.topInsetExtra = 12
            settings.bottomInsetExtra = 8
            settings.fontName = "CustomFixture"
            settings.fontWeight = .semibold
            settings.pageMode = .curl
            settings.bottomToolbarStyle = .full
            settings.screenAwake = .fiveMinutes
            settings.volumeButtonPageTurnEnabled = true
            settings.textUnderlineEnabled = true
            settings.textUnderlineThicknessPt = 2.5
            settings.textUnderlineOffsetPt = -1
            settings.textUnderlineColorHex = "#123456"
            settings.textUnderlineDashed = true
            settings.backgroundImageName = "fixed.jpg"
            settings.useBackgroundImage = true
            settings.textColorHex = "#445566"
            settings.backgroundColorHex = "#F0E0D0"
            settings.paragraphCommentBrowser = .inline
            settings.layoutWidgets = [LayoutWidget(type: "time", alignment: .trailing, showOnFirstPage: false)]
            settings.chapterTitleConfigLight = ChapterTitleConfig(fontName: "CustomFixture", fontSize: 31, textAlignment: .left, useBold: false)
            settings.chapterTitleConfigDark = ChapterTitleConfig(fontName: "System", fontSize: 29, textAlignment: .center, useBold: true)
            settings.save()
            let cold = ReadingSettings.load(from: defaults)
            emit("settings_cold_typography", ["24.5", "13.0", "9.0", "0", "-0.5", "justified", "CustomFixture", "true"],
                [String(describing: cold.fontSize), String(describing: cold.lineSpacing), String(describing: cold.paragraphSpacing), String(describing: cold.textIndent),
                 String(describing: cold.letterSpacing), ReadingSettings.alignmentName(cold.textAlignment), cold.fontName, String(describing: cold.isBold)])
            emit("settings_cold_layout", ["0.0", "28.0", "12.0", "8.0", "pageCurl", "chatInput", "fiveMinutes", "true"],
                [String(describing: cold.leftPageMargin), String(describing: cold.rightPageMargin), String(describing: cold.topInsetExtra), String(describing: cold.bottomInsetExtra),
                 cold.pageMode.rawValue, cold.bottomToolbarStyle.rawValue, cold.screenAwake.rawValue, String(describing: cold.volumeButtonPageTurnEnabled)])
            emit("settings_cold_underline_colors", ["true", "2.5", "-1.0", "#123456", "true", "fixed.jpg", "#445566", "#F0E0D0"],
                [String(describing: cold.textUnderlineEnabled), String(describing: cold.textUnderlineThicknessPt), String(describing: cold.textUnderlineOffsetPt),
                 cold.textUnderlineColorHex, String(describing: cold.textUnderlineDashed), cold.backgroundImageName, cold.textColorHex, cold.backgroundColorHex])
            emit("settings_structured_values_roundtrip", ["31.0", "29.0", "time", "true"],
                [String(describing: cold.chapterTitleConfigLight?.fontSize ?? 0), String(describing: cold.chapterTitleConfigDark?.fontSize ?? 0),
                 cold.layoutWidgets.first?.type ?? "", String(describing: cold.paragraphCommentBrowser == .inline)])
            emit("settings_original_storage_names", ["24.5", "justified", "pageCurl", "true"],
                [String(describing: defaults.double(forKey: "fontSize")), defaults.string(forKey: "textAlignment") ?? "",
                 defaults.string(forKey: "pageMode") ?? "", String(describing: defaults.object(forKey: "reader_font_size") == nil)])
            let opaque = Data([0, 1, 255, 42])
            defaults.set(opaque, forKey: "customReaderThemes")
            defaults.set("secret-fixture", forKey: "remotePassword")
            defaults.set("not-a-setting", forKey: "unrelated")
            defaults.set("https://sample.invalid", forKey: "remoteBackendURL")
            defaults.set("kept-user", forKey: "remoteUsername")
            let snapshot = try ReadingSettingsBackup.export(from: defaults)
            let values = try JSONSerialization.jsonObject(with: snapshot) as! [String: Any]
            emit("settings_backup_original_schema", ["57", "true", "false", "false", "true"],
                [String(describing: ReadingSettingsBackup.allKeys.count), String(describing: values["fontSize"] as? Double == 24.5),
                 String(describing: values["remotePassword"] != nil), String(describing: values["unrelated"] != nil), String(describing: values["reader_font_size"] == nil)])
            emit("settings_backup_binary_base64", ["AAH/Kg=="], [values["customReaderThemes"] as? String ?? ""])
            let backup = BackupService(documentsDirectory: root.appendingPathComponent("documents"),
                                       applicationSupportDirectory: root.appendingPathComponent("support"), defaults: defaults)
            let restore = BackupService(documentsDirectory: root.appendingPathComponent("target-documents"),
                                        applicationSupportDirectory: root.appendingPathComponent("target-support"), defaults: targetDefaults)
            let existing = ReadingSettings.load(from: targetDefaults)
            existing.fontSize = 18
            existing.save()
            settings.fontSize = 25.5
            let archive = try await backup.exportBackup(categories: [.readingSettings])
            defer { try? FileManager.default.removeItem(at: archive) }
            try await restore.restoreBackup(from: archive, categories: [.readingSettings])
            let restored = ReadingSettings.load(from: targetDefaults)
            emit("settings_archive_real_reader_values", ["25.5", "13.0", "0.0", "pageCurl", "31.0", "true"],
                [String(describing: restored.fontSize), String(describing: restored.lineSpacing), String(describing: restored.leftPageMargin), restored.pageMode.rawValue,
                 String(describing: restored.chapterTitleConfigLight?.fontSize ?? 0), String(describing: targetDefaults.data(forKey: "customReaderThemes") == opaque)])
            emit("settings_restore_reloads_live_instance", ["25.5", "13.0"], [String(describing: existing.fontSize), String(describing: existing.lineSpacing)])
            existing.save()
            emit("settings_restore_not_overwritten_by_old_instance", ["25.5"], [String(describing: targetDefaults.double(forKey: "fontSize"))])
            cold.lineSpacing = 15
            cold.save()
            emit("settings_stale_instance_only_saves_changed_fields", ["25.5", "15.0"],
                [String(describing: defaults.double(forKey: "fontSize")), String(describing: defaults.double(forKey: "lineSpacing"))])
            try restore.importReadingSettings(from: Data(##"{"pageMargin":22,"leftPageMargin":7,"fontSize":"bad","remotePassword":"bad","textUnderlineUsesTextColor":true,"textUnderlineColorHex":"#AA0000"}"##.utf8))
            emit("settings_legacy_margin_selective_restore", ["7.0", "22.0", "25.5", "true"],
                [String(describing: existing.leftPageMargin), String(describing: existing.rightPageMargin), String(describing: existing.fontSize), String(describing: targetDefaults.object(forKey: "remotePassword") == nil)])
            emit("settings_underline_follow_text_removes_color", ["true", "true"],
                [String(describing: targetDefaults.object(forKey: "textUnderlineColorHex") == nil), String(describing: existing.textUnderlineUsesTextColor)])
            try restore.importReadingSettings(from: Data(#"{"reader_font_size":21,"reader_line_spacing":4,"reader_bottom_toolbar":"full","reader_screen_awake":"timed","reader_text_alignment":1}"#.utf8))
            emit("settings_legacy_rebuilt_backup_migration", ["21.0", "4.0", "chatInput", "tenMinutes", "center"],
                [String(describing: existing.fontSize), String(describing: existing.lineSpacing), existing.bottomToolbarStyle.rawValue, existing.screenAwake.rawValue,
                 ReadingSettings.alignmentName(existing.textAlignment)])
            let badTypes = Data(#"{"fontSize":true,"textIndent":2.5,"textAlignment":true,"verticalJustify":"true","chapterTitleConfig":"%%%","readerBottomToolbarStyle":"unknown","unrelated":"bad"}"#.utf8)
            try restore.importReadingSettings(from: badTypes)
            emit("settings_invalid_members_preserve_existing", ["21.0", "0", "chatInput", "31.0", "center"],
                [String(describing: existing.fontSize), String(describing: existing.textIndent), existing.bottomToolbarStyle.rawValue,
                 String(describing: existing.chapterTitleConfigLight?.fontSize ?? 0), ReadingSettings.alignmentName(existing.textAlignment)])
            var rejected = false
            do { try restore.importReadingSettings(from: Data("[]".utf8)) } catch { rejected = true }
            emit("settings_invalid_top_level_rejected", ["true", "21.0"], [String(describing: rejected), String(describing: existing.fontSize)])
            let projected = try JSONDecoder().decode(ReadingSettings.self, from: JSONEncoder().encode(settings))
            emit("settings_codable_added_fields", ["pageCurl", "2.5", "12.0", "time"],
                [projected.pageMode.rawValue, String(describing: projected.textUnderlineThicknessPt), String(describing: projected.topInsetExtra), projected.layoutWidgets.first?.type ?? ""])
            defaults.set("horizontalScroll", forKey: "pageMode")
            let unimplementedMode = ReadingSettings.load(from: defaults)
            unimplementedMode.paragraphSpacing = 10
            unimplementedMode.save()
            emit("settings_unknown_mode_survives_unrelated_save", ["horizontalScroll"], [defaults.string(forKey: "pageMode") ?? ""])
            let allFields = Data(#"""
            {"fontSize":23,"fontFamily":"FixedFont","isBold":true,"fontWeight":0.5,"lineSpacing":11,"paragraphSpacing":7,
             "leftPageMargin":12,"rightPageMargin":16,"textIndent":2,"letterSpacing":0.5,"textAlignment":"justified",
             "verticalJustify":true,"paragraphSeparatorLines":2,"textUnderlineEnabled":true,"textUnderlineThicknessPt":1.5,
             "textUnderlineOffsetPt":-2,"textUnderlinePattern":"dot","textUnderlineMode":"textOnly","textUnderlineUsesTextColor":false,
             "textUnderlineColorHex":"#123456","textColor":"#222222","backgroundColor":"#EEEEEE","backgroundImage":"sample.jpg",
             "pageMode":"horizontalScroll","fullScreenTap":true,"isSimplifiedChinese":false,"brightness":0.4,
             "screenAwakeOption":"thirtyMinutes","showStatusBar":false,"readerBottomToolbarStyle":"chatInput","searchThreadCount":8,
             "searchByGroup":true,"exactSearch":false,"searchMaxPages":5,"chapterPreloadCount":3,"showReviewButton":true,
             "showStatisticsTab":false,"paragraphCommentBrowserDefaultPresentation":"halfScreen","paragraphCommentBrowserEdgeSwipeDismissEnabled":true,
             "mangaReadingMode":"webtoon","useRemoteBackend":false,"remoteBackendURL":"https://sample.invalid","remoteUsername":"fixed",
             "chapterTitleConfig":"e30=","chapterTitleCustomPresets":"W10=","layoutWidgetsV2":"W10=","widgetUseCustomFont":true,
             "readerUIFollowAppFont":false,"layoutTemplate":"compact","topInsetExtra":6,"bottomInsetExtra":10,"customReaderThemes":"W10=",
             "builtInReaderThemeOverrides":"e30=","currentReaderThemeId":"light-id","readerDarkModePairId":"dark-id",
             "readerLightModeThemeId":"light-id","readerAutoDarkMode":true}
            """#.utf8)
            try restore.importReadingSettings(from: allFields)
            let complete = try JSONSerialization.jsonObject(with: ReadingSettingsBackup.export(from: targetDefaults)) as! NSDictionary
            let expected = try JSONSerialization.jsonObject(with: allFields) as! NSDictionary
            emit("settings_all_original_keys_roundtrip", ["57", "true"], [String(describing: complete.count), String(describing: complete.isEqual(expected))])
            existing.save()
            let afterUnchangedSave = try JSONSerialization.jsonObject(with: ReadingSettingsBackup.export(from: targetDefaults)) as! NSDictionary
            emit("settings_untouched_original_blobs_preserved", ["true"], [String(describing: afterUnchangedSave.isEqual(expected))])
            let legacyToolbar = try JSONDecoder().decode(ReaderBottomToolbarStyle.self, from: Data("\"full\"".utf8))
            emit("settings_legacy_theme_toolbar_decode", ["chatInput", "\"chatInput\""],
                [legacyToolbar.rawValue, String(decoding: try JSONEncoder().encode(legacyToolbar), as: UTF8.self)])
        } catch { emit("settings_archive_real_reader_values", ["通过"], [error.localizedDescription]) }
    }
}
