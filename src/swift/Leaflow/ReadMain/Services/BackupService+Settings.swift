// 原路径: ReadMain/Services/BackupService.swift
// 0x1002bcb84/0x1002c3808：57个阅读设置键、类型分组、Base64及旧pageMargin迁移。
import Foundation
import CoreFoundation

enum ReadingSettingsBackup {
    static let numberKeys = ["fontSize", "fontWeight", "lineSpacing", "paragraphSpacing", "leftPageMargin",
        "rightPageMargin", "letterSpacing", "textUnderlineThicknessPt", "textUnderlineOffsetPt", "brightness",
        "topInsetExtra", "bottomInsetExtra"]
    static let integerKeys = ["textIndent", "paragraphSeparatorLines", "searchThreadCount", "searchMaxPages", "chapterPreloadCount"]
    static let booleanKeys = ["isBold", "verticalJustify", "textUnderlineEnabled", "textUnderlineUsesTextColor",
        "fullScreenTap", "isSimplifiedChinese", "showStatusBar", "searchByGroup", "exactSearch", "showReviewButton",
        "showStatisticsTab", "paragraphCommentBrowserEdgeSwipeDismissEnabled", "useRemoteBackend",
        "widgetUseCustomFont", "readerUIFollowAppFont", "readerAutoDarkMode"]
    static let stringKeys = ["fontFamily", "textAlignment", "textUnderlinePattern", "textUnderlineMode", "textUnderlineColorHex",
        "textColor", "backgroundColor", "backgroundImage", "pageMode", "screenAwakeOption", "readerBottomToolbarStyle",
        "paragraphCommentBrowserDefaultPresentation", "mangaReadingMode", "remoteBackendURL", "remoteUsername", "layoutTemplate",
        "currentReaderThemeId", "readerDarkModePairId", "readerLightModeThemeId"]
    static let dataKeys = ["chapterTitleConfig", "chapterTitleCustomPresets", "layoutWidgetsV2", "customReaderThemes",
        "builtInReaderThemeOverrides"]
    static var allKeys: Set<String> { Set(numberKeys + integerKeys + booleanKeys + stringKeys + dataKeys) }

    static func export(from defaults: UserDefaults) throws -> Data {
        var values: [String: Any] = [:]
        for key in numberKeys { values[key] = defaults.double(forKey: key) }
        for key in integerKeys { values[key] = defaults.integer(forKey: key) }
        for key in booleanKeys { values[key] = defaults.bool(forKey: key) }
        if defaults.object(forKey: "textUnderlineUsesTextColor") == nil { values["textUnderlineUsesTextColor"] = true }
        for key in stringKeys { values[key] = defaults.string(forKey: key) }
        for key in dataKeys { values[key] = defaults.data(forKey: key)?.base64EncodedString() }
        return try JSONSerialization.data(withJSONObject: values, options: [.sortedKeys])
    }

    static func validatedValues(from data: Data) throws -> [String: Any] {
        guard var values = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AppError.parsing("阅读设置备份必须是JSON对象")
        }
        let originalInput = values
        // 旧重建包导出的reader_*格式只在读取时迁移，不再输出该格式。
        for (old, canonical) in legacyKeys where values[canonical] == nil { values[canonical] = values[old] }
        if originalInput["textAlignment"] == nil, let alignment = number(originalInput["reader_text_alignment"]).flatMap({ Int(exactly: $0.doubleValue) }) {
            values["textAlignment"] = [0: "left", 1: "center", 2: "right", 3: "justified", 4: "natural"][alignment]
        }
        if originalInput["readerBottomToolbarStyle"] == nil, let mode = values["reader_bottom_toolbar"] as? String {
            values["readerBottomToolbarStyle"] = ["minimal": "classic", "full": "chatInput"][mode] ?? mode
        }
        if originalInput["screenAwakeOption"] == nil, let awake = values["reader_screen_awake"] as? String {
            values["screenAwakeOption"] = ["timed": "tenMinutes", "alwaysOn": "never"][awake] ?? awake
        }
        if values["chapterTitleConfig"] == nil,
           values["reader_chapter_title_light"] != nil || values["reader_chapter_title_dark"] != nil {
            let pair = ["light": values["reader_chapter_title_light"] ?? NSNull(), "dark": values["reader_chapter_title_dark"] ?? NSNull()]
            values["chapterTitleConfig"] = try JSONSerialization.data(withJSONObject: pair, options: [.sortedKeys]).base64EncodedString()
        }
        var accepted: [String: Any] = [:]
        for key in stringKeys {
            guard let value = values[key] as? String else { continue }
            if key == "readerBottomToolbarStyle", !["classic", "chatInput"].contains(value) { continue }
            if key == "paragraphCommentBrowserDefaultPresentation", !["halfScreen", "fullScreen"].contains(value) { continue }
            accepted[key] = value
        }
        for key in numberKeys {
            if let value = number(values[key]), value.doubleValue.isFinite { accepted[key] = value.doubleValue }
        }
        for key in integerKeys {
            if let value = number(values[key]), let integer = Int(exactly: value.doubleValue) { accepted[key] = integer }
        }
        for key in booleanKeys {
            if let value = values[key] as? NSNumber, CFGetTypeID(value) == CFBooleanGetTypeID() { accepted[key] = value.boolValue }
        }
        for key in dataKeys {
            if let value = values[key] as? String, let decoded = Data(base64Encoded: value) { accepted[key] = decoded }
        }
        if let margin = number(values["pageMargin"]), margin.doubleValue.isFinite {
            // 原版以键存在性判断，不用旧键覆盖显式新字段。
            for key in ["leftPageMargin", "rightPageMargin"] where values[key] == nil { accepted[key] = margin.doubleValue }
        }
        return accepted
    }

    static func apply(_ values: [String: Any], to defaults: UserDefaults) {
        for (key, value) in values where allKeys.contains(key) { defaults.set(value, forKey: key) }
        if values["textUnderlineUsesTextColor"] as? Bool == true { defaults.removeObject(forKey: "textUnderlineColorHex") }
    }

    private static func number(_ value: Any?) -> NSNumber? {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
        return number
    }

    private static let legacyKeys = [
        "reader_font_size": "fontSize", "reader_line_spacing": "lineSpacing", "reader_paragraph_spacing": "paragraphSpacing",
        "reader_text_indent": "textIndent", "reader_letter_spacing": "letterSpacing", "reader_text_alignment": "textAlignment",
        "reader_vertical_justify": "verticalJustify", "reader_para_sep_lines": "paragraphSeparatorLines",
        "reader_custom_font": "fontFamily", "reader_bottom_toolbar": "readerBottomToolbarStyle", "reader_screen_awake": "screenAwakeOption",
        "reader_is_bold": "isBold", "reader_left_page_margin": "leftPageMargin", "reader_right_page_margin": "rightPageMargin",
        "reader_underline_color": "textUnderlineColorHex", "reader_text_color": "textColor", "reader_background_color": "backgroundColor",
        "reader_background_image": "backgroundImage", "reader_layout_template": "layoutTemplate"
    ]
}

extension BackupService {
    func exportReadingSettings() throws -> Data {
        ReadingSettings.prepareBackupDefaults(defaults)
        return try ReadingSettingsBackup.export(from: defaults)
    }

    func importReadingSettings(from data: Data) throws {
        let values = try ReadingSettingsBackup.validatedValues(from: data)
        ReadingSettingsBackup.apply(values, to: defaults)
        ReadingSettings.reloadLoadedInstances(using: defaults)
    }
}
