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
                [String(cold.fontSize), String(cold.lineSpacing), String(cold.paragraphSpacing), String(cold.textIndent),
                 String(cold.letterSpacing), ReadingSettings.alignmentName(cold.textAlignment), cold.fontName, String(cold.isBold)])
            emit("settings_cold_layout", ["0.0", "28.0", "12.0", "8.0", "pageCurl", "chatInput", "fiveMinutes", "true"],
                [String(cold.leftPageMargin), String(cold.rightPageMargin), String(cold.topInsetExtra), String(cold.bottomInsetExtra),
                 cold.pageMode.rawValue, cold.bottomToolbarStyle.rawValue, cold.screenAwake.rawValue, String(cold.volumeButtonPageTurnEnabled)])
            emit("settings_cold_underline_colors", ["true", "2.5", "-1.0", "#123456", "true", "fixed.jpg", "#445566", "#F0E0D0"],
                [String(cold.textUnderlineEnabled), String(cold.textUnderlineThicknessPt), String(cold.textUnderlineOffsetPt),
                 cold.textUnderlineColorHex, String(cold.textUnderlineDashed), cold.backgroundImageName, cold.textColorHex, cold.backgroundColorHex])
            emit("settings_structured_values_roundtrip", ["31.0", "29.0", "time", "true"],
                [String(cold.chapterTitleConfigLight?.fontSize ?? 0), String(cold.chapterTitleConfigDark?.fontSize ?? 0),
                 cold.layoutWidgets.first?.type ?? "", String(cold.paragraphCommentBrowser == .inline)])
            emit("settings_original_storage_names", ["24.5", "justified", "pageCurl", "true"],
                [String(defaults.double(forKey: "fontSize")), defaults.string(forKey: "textAlignment") ?? "",
                 defaults.string(forKey: "pageMode") ?? "", String(defaults.object(forKey: "reader_font_size") == nil)])
            let opaque = Data([0, 1, 255, 42])
            defaults.set(opaque, forKey: "customReaderThemes")
            defaults.set("secret-fixture", forKey: "remotePassword")
            defaults.set("not-a-setting", forKey: "unrelated")
            defaults.set("https://sample.invalid", forKey: "remoteBackendURL")
            defaults.set("kept-user", forKey: "remoteUsername")
            let snapshot = try ReadingSettingsBackup.export(from: defaults)
            let values = try JSONSerialization.jsonObject(with: snapshot) as! [String: Any]
            emit("settings_backup_original_schema", ["57", "true", "false", "false", "true"],
                [String(ReadingSettingsBackup.allKeys.count), String(values["fontSize"] as? Double == 24.5),
                 String(values["remotePassword"] != nil), String(values["unrelated"] != nil), String(values["reader_font_size"] == nil)])
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
                [String(restored.fontSize), String(restored.lineSpacing), String(restored.leftPageMargin), restored.pageMode.rawValue,
                 String(restored.chapterTitleConfigLight?.fontSize ?? 0), String(targetDefaults.data(forKey: "customReaderThemes") == opaque)])
            emit("settings_restore_reloads_live_instance", ["25.5", "13.0"], [String(existing.fontSize), String(existing.lineSpacing)])
            existing.save()
            emit("settings_restore_not_overwritten_by_old_instance", ["25.5"], [String(targetDefaults.double(forKey: "fontSize"))])
            cold.lineSpacing = 15
            cold.save()
            emit("settings_stale_instance_only_saves_changed_fields", ["25.5", "15.0"],
                [String(defaults.double(forKey: "fontSize")), String(defaults.double(forKey: "lineSpacing"))])
            try restore.importReadingSettings(from: Data(#"{"pageMargin":22,"leftPageMargin":7,"fontSize":"bad","remotePassword":"bad","textUnderlineUsesTextColor":true,"textUnderlineColorHex":"#AA0000"}"#.utf8))
            emit("settings_legacy_margin_selective_restore", ["7.0", "22.0", "25.5", "true"],
                [String(existing.leftPageMargin), String(existing.rightPageMargin), String(existing.fontSize), String(targetDefaults.object(forKey: "remotePassword") == nil)])
            emit("settings_underline_follow_text_removes_color", ["true", "true"],
                [String(targetDefaults.object(forKey: "textUnderlineColorHex") == nil), String(existing.textUnderlineUsesTextColor)])
            try restore.importReadingSettings(from: Data(#"{"reader_font_size":21,"reader_line_spacing":4,"reader_bottom_toolbar":"full","reader_screen_awake":"timed","reader_text_alignment":1}"#.utf8))
            emit("settings_legacy_rebuilt_backup_migration", ["21.0", "4.0", "chatInput", "tenMinutes", "center"],
                [String(existing.fontSize), String(existing.lineSpacing), existing.bottomToolbarStyle.rawValue, existing.screenAwake.rawValue,
                 ReadingSettings.alignmentName(existing.textAlignment)])
            let badTypes = Data(#"{"fontSize":true,"textIndent":2.5,"verticalJustify":"true","chapterTitleConfig":"%%%","readerBottomToolbarStyle":"unknown","unrelated":"bad"}"#.utf8)
            try restore.importReadingSettings(from: badTypes)
            emit("settings_invalid_members_preserve_existing", ["21.0", "0", "chatInput", "31.0"],
                [String(existing.fontSize), String(existing.textIndent), existing.bottomToolbarStyle.rawValue, String(existing.chapterTitleConfigLight?.fontSize ?? 0)])
            var rejected = false
            do { try restore.importReadingSettings(from: Data("[]".utf8)) } catch { rejected = true }
            emit("settings_invalid_top_level_rejected", ["true", "21.0"], [String(rejected), String(existing.fontSize)])
            let projected = try JSONDecoder().decode(ReadingSettings.self, from: JSONEncoder().encode(settings))
            emit("settings_codable_added_fields", ["pageCurl", "2.5", "12.0", "time"],
                [projected.pageMode.rawValue, String(projected.textUnderlineThicknessPt), String(projected.topInsetExtra), projected.layoutWidgets.first?.type ?? ""])
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
            emit("settings_all_original_keys_roundtrip", ["57", "true"], [String(complete.count), String(complete.isEqual(expected))])
            existing.save()
            let afterUnchangedSave = try JSONSerialization.jsonObject(with: ReadingSettingsBackup.export(from: targetDefaults)) as! NSDictionary
            emit("settings_untouched_original_blobs_preserved", ["true"], [String(afterUnchangedSave.isEqual(expected))])
        } catch { emit("settings_archive_real_reader_values", ["通过"], [error.localizedDescription]) }
    }
}
