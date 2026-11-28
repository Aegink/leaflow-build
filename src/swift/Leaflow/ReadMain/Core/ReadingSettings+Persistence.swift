// 原路径: ReadMain/Core/ReadingSettings.swift
// 类型表3428的defaults及0x1002204dc保存域；与0x1002bcb84/0x1002c3808原版备份键互证。
import SwiftUI
import UIKit
import CoreFoundation

extension ReadingSettings {
    // 旧重建包键只作读取回退；新写入使用原版键。
    static let originalKeys: [CodingKeys: String] = [
        .fontSize: "fontSize", .lineSpacing: "lineSpacing", .paragraphSpacing: "paragraphSpacing",
        .textIndent: "textIndent", .letterSpacing: "letterSpacing", .textAlignment: "textAlignment",
        .verticalJustify: "verticalJustify", .paragraphSeparatorLines: "paragraphSeparatorLines",
        .fontName: "fontFamily", .bottomToolbarStyle: "readerBottomToolbarStyle", .screenAwake: "screenAwakeOption",
        .isBold: "isBold", .volumeButtonPageTurnEnabled: "volumeButtonPageTurnEnabled",
        .leftPageMargin: "leftPageMargin", .rightPageMargin: "rightPageMargin", .textUnderlineColorHex: "textUnderlineColorHex",
        .textColorHex: "textColor", .backgroundColorHex: "backgroundColor", .backgroundImageName: "backgroundImage",
        .layoutTemplate: "layoutTemplate", .layoutWidgets: "layoutWidgetsV2", .customChapterTitlePresets: "chapterTitleCustomPresets",
        .paragraphCommentBrowser: "paragraphCommentBrowserDefaultPresentation"
    ]
    private static let dataProperties: Set<CodingKeys> = [.highlightRules, .chapterTitleConfigLight, .chapterTitleConfigDark,
        .chapterTitlePresets, .customChapterTitlePresets, .layoutWidgets]
    private static let loadedInstances = NSHashTable<ReadingSettings>.weakObjects()

    static func load(from defaults: UserDefaults = .standard) -> ReadingSettings {
        let settings = ReadingSettings(defaults: defaults)
        settings.loadPersistentValues()
        loadedInstances.add(settings)
        return settings
    }

    private func loadPersistentValues() {
        let defaults = persistenceDefaults
        func object(_ key: CodingKeys) -> Any? {
            defaults.object(forKey: Self.originalKeys[key] ?? key.rawValue) ?? defaults.object(forKey: key.rawValue)
        }
        func scalar<T>(_ key: CodingKeys, _ fallback: T) -> T { object(key) as? T ?? fallback }
        func number(_ key: CodingKeys, _ fallback: CGFloat) -> CGFloat {
            guard let value = object(key) as? NSNumber, CFGetTypeID(value) != CFBooleanGetTypeID(), value.doubleValue.isFinite else { return fallback }
            return CGFloat(value.doubleValue)
        }
        func decode<T: Decodable>(_ key: CodingKeys, _ type: T.Type) -> T? {
            guard let data = object(key) as? Data else { return nil }
            return try? JSONDecoder().decode(type, from: data)
        }
        fontSize = number(.fontSize, fontSize)
        lineSpacing = number(.lineSpacing, lineSpacing)
        paragraphSpacing = number(.paragraphSpacing, paragraphSpacing)
        textIndent = scalar(.textIndent, textIndent)
        letterSpacing = number(.letterSpacing, letterSpacing)
        if let alignment = object(.textAlignment) as? String {
            textAlignment = Self.alignment(from: alignment) ?? textAlignment
        } else if let raw = object(.textAlignment) as? Int { textAlignment = NSTextAlignment(rawValue: raw) ?? textAlignment }
        verticalJustify = scalar(.verticalJustify, verticalJustify)
        paragraphSeparatorLines = scalar(.paragraphSeparatorLines, paragraphSeparatorLines)
        doublePageMode = Self.loadDoublePageMode(from: defaults)
        let mode = scalar(.pageMode, pageMode.rawValue)
        pageMode = PageMode(rawValue: mode) ?? (mode == "curl" ? .curl : mode == "scroll" ? .scroll : .horizontal)
        fontName = scalar(.fontName, fontName)
        let toolbar = scalar(.bottomToolbarStyle, bottomToolbarStyle.rawValue)
        bottomToolbarStyle = ReaderBottomToolbarStyle(rawValue: toolbar) ?? (toolbar == "full" ? .full : .minimal)
        screenAwake = Self.loadScreenAwakeOption(from: defaults)
        searchMode = SearchMode(rawValue: scalar(.searchMode, searchMode.rawValue)) ?? searchMode
        exploreRanking = ExploreSectionRankingMode(rawValue: scalar(.exploreRanking, exploreRanking.rawValue)) ?? exploreRanking
        exploreCacheTTL = ExploreCacheTTLOption(rawValue: scalar(.exploreCacheTTL, exploreCacheTTL.rawValue)) ?? exploreCacheTTL
        isBold = scalar(.isBold, isBold)
        fontWeight = UIFont.Weight(rawValue: number(.fontWeight, isBold ? UIFont.Weight.medium.rawValue : 0))
        volumeButtonPageTurnEnabled = Self.loadVolumeButtonPageTurnEnabled(from: defaults)
        let oldMargin = (defaults.object(forKey: "pageMargin") as? NSNumber).map { CGFloat($0.doubleValue) }
        leftPageMargin = number(.leftPageMargin, oldMargin ?? leftPageMargin)
        rightPageMargin = number(.rightPageMargin, oldMargin ?? rightPageMargin)
        textUnderlineEnabled = scalar(.textUnderlineEnabled, textUnderlineEnabled)
        textUnderlineThicknessPt = number(.textUnderlineThicknessPt, textUnderlineThicknessPt)
        textUnderlineOffsetPt = number(.textUnderlineOffsetPt, textUnderlineOffsetPt)
        textUnderlineColorHex = scalar(.textUnderlineColorHex, textUnderlineColorHex)
        if defaults.object(forKey: "textUnderlineUsesTextColor") as? Bool == true { textUnderlineColorHex = "" }
        textUnderlineDashed = defaults.string(forKey: "textUnderlinePattern").map { $0 != "solid" }
            ?? scalar(.textUnderlineDashed, textUnderlineDashed)
        textColorHex = scalar(.textColorHex, textColorHex)
        backgroundColorHex = scalar(.backgroundColorHex, backgroundColorHex)
        backgroundImageName = scalar(.backgroundImageName, backgroundImageName)
        useBackgroundImage = scalar(.useBackgroundImage, !backgroundImageName.isEmpty)
        ttsHighlightColorHex = scalar(.ttsHighlightColorHex, ttsHighlightColorHex)
        highlightRules = decode(.highlightRules, [HighlightRule].self) ?? []
        highlightRulesEnabled = scalar(.highlightRulesEnabled, true)
        let pair = Self.loadStoredChapterTitleConfigs(from: defaults)
        chapterTitleConfigLight = pair.light
        chapterTitleConfigDark = pair.dark
        if defaults.data(forKey: "chapterTitleConfig") == nil {
            chapterTitleConfigLight = decode(.chapterTitleConfigLight, ChapterTitleConfig.self) ?? pair.light
            chapterTitleConfigDark = decode(.chapterTitleConfigDark, ChapterTitleConfig.self) ?? pair.dark
        }
        chapterTitlePresets = decode(.chapterTitlePresets, [ChapterTitlePreset].self) ?? []
        customChapterTitlePresets = decode(.customChapterTitlePresets, [ChapterTitlePreset].self) ?? []
        currentChapterTitlePresetId = (object(.currentChapterTitlePresetId) as? String).flatMap(UUID.init(uuidString:))
        layoutWidgets = decode(.layoutWidgets, [LayoutWidget].self) ?? []
        layoutTemplate = ReaderLayoutTemplate(rawValue: scalar(.layoutTemplate, layoutTemplate.rawValue)) ?? layoutTemplate
        topInsetExtra = number(.topInsetExtra, topInsetExtra)
        bottomInsetExtra = number(.bottomInsetExtra, bottomInsetExtra)
        let browser = scalar(.paragraphCommentBrowser, "fullScreen")
        paragraphCommentBrowser = browser == "halfScreen" || browser == "inline" ? .inline : .modal
        persistedValues = persistentValues()
        invalidateTypographyCaches()
        compiledRulesCache = nil
        compiledLayoutRulesBySignature.removeAll()
        cachedBackgroundImage = nil
        cachedBackgroundFilename = nil
        cachedLayout = nil
    }

    private func persistentValues() -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(self),
              let encoded = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        var values: [String: Any] = [:]
        for key in CodingKeys.allCases {
            guard let value = encoded[key.rawValue], !(value is NSNull) else { continue }
            let storedKey = Self.originalKeys[key] ?? key.rawValue
            if Self.dataProperties.contains(key) {
                values[storedKey] = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys, .fragmentsAllowed])
            } else { values[storedKey] = value }
        }
        values["textAlignment"] = Self.alignmentName(textAlignment)
        values["textUnderlinePattern"] = textUnderlineDashed ? "dash" : "solid"
        values["textUnderlineUsesTextColor"] = textUnderlineColorHex.isEmpty
        values["paragraphCommentBrowserDefaultPresentation"] = paragraphCommentBrowser == .inline ? "halfScreen" : "fullScreen"
        values["chapterTitleConfig"] = try? encoder.encode(TitlePair(light: chapterTitleConfigLight, dark: chapterTitleConfigDark))
        return values
    }

    func save() {
        let values = persistentValues()
        let keys = Set(values.keys).union(persistedValues?.keys ?? Dictionary<String, Any>().keys)
        for key in keys {
            let before = persistedValues?[key] as? NSObject
            let after = values[key] as? NSObject
            if persistedValues != nil, before == after { continue }
            if let value = values[key] { persistenceDefaults.set(value, forKey: key) }
            else { persistenceDefaults.removeObject(forKey: key) }
        }
        if values["textUnderlineUsesTextColor"] as? Bool == true,
           persistedValues == nil || persistedValues?["textUnderlineUsesTextColor"] as? Bool != true {
            persistenceDefaults.removeObject(forKey: "textUnderlineColorHex")
        }
        persistedValues = values
        hasPendingSave = false
        pendingSaveTask?.cancel()
        pendingSaveTask = nil
    }

    func schedulePendingSave(after interval: TimeInterval = 0.5) {
        pendingSaveTask?.cancel()
        hasPendingSave = true
        let task = DispatchWorkItem { [weak self] in self?.flushPendingSave() }
        pendingSaveTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + interval, execute: task)
    }

    func flushPendingSave() { save() }
    private func performSave() { save() }
    static var canWritePersistentDefaults: Bool { true }

    static func flushLoadedInstances() {
        for settings in loadedInstances.allObjects { settings.save() }
    }

    static func prepareBackupDefaults(_ defaults: UserDefaults) {
        for settings in loadedInstances.allObjects where settings.persistenceDefaults === defaults { settings.save() }
        let settings = load(from: defaults)
        for (key, value) in settings.persistentValues() where defaults.object(forKey: key) == nil {
            defaults.set(value, forKey: key)
        }
    }

    static func reloadLoadedInstances(using defaults: UserDefaults) {
        for settings in loadedInstances.allObjects where settings.persistenceDefaults === defaults {
            settings.pendingSaveTask?.cancel()
            settings.pendingSaveTask = nil
            settings.hasPendingSave = false
            settings.loadPersistentValues()
            settings.needsRepagination = true
            settings.typographyRevision += 1
        }
    }

    static func loadScreenAwakeOption(from defaults: UserDefaults) -> ScreenAwakeOption {
        let raw = defaults.string(forKey: "screenAwakeOption") ?? defaults.string(forKey: CodingKeys.screenAwake.rawValue) ?? ""
        return ScreenAwakeOption(rawValue: raw) ?? (raw == "alwaysOn" ? .never : raw == "timed" ? .tenMinutes : .system)
    }

    static func loadVolumeButtonPageTurnEnabled(from defaults: UserDefaults) -> Bool {
        (defaults.object(forKey: "volumeButtonPageTurnEnabled") ?? defaults.object(forKey: CodingKeys.volumeButtonPageTurnEnabled.rawValue)) as? Bool ?? false
    }

    static func loadDoublePageMode(from defaults: UserDefaults) -> DoublePageMode {
        DoublePageMode(rawValue: defaults.string(forKey: "readerDoublePageMode") ?? "") ?? .off
    }

    private struct TitlePair: Codable { var light: ChapterTitleConfig?; var dark: ChapterTitleConfig? }

    static func loadStoredChapterTitleConfigs(from defaults: UserDefaults) -> (light: ChapterTitleConfig, dark: ChapterTitleConfig) {
        let fallback = ChapterTitleConfig(fontName: "System", fontSize: 22, textAlignment: .center, useBold: true)
        guard let data = defaults.data(forKey: "chapterTitleConfig"), let pair = try? JSONDecoder().decode(TitlePair.self, from: data) else {
            return (fallback, fallback)
        }
        return (pair.light ?? fallback, pair.dark ?? pair.light ?? fallback)
    }

    static func alignment(from value: String) -> NSTextAlignment? {
        ["left": .left, "center": .center, "justified": .justified, "right": .right, "natural": .natural][value]
    }

    static func alignmentName(_ alignment: NSTextAlignment) -> String {
        switch alignment {
        case .center: return "center"
        case .justified: return "justified"
        case .right: return "right"
        case .natural: return "natural"
        default: return "left"
        }
    }
}
