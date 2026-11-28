// 原路径: ReadMain/Core/ReadingSettings.swift
// 分册只改变边界，函数、规模与桩仍计入原始文件。
import SwiftUI
import UIKit

extension ReadingSettings {
    enum CodingKeys: String, CodingKey, CaseIterable {
        case fontSize = "reader_font_size"
        case lineSpacing = "reader_line_spacing"
        case paragraphSpacing = "reader_paragraph_spacing"
        case textIndent = "reader_text_indent"
        case letterSpacing = "reader_letter_spacing"
        case textAlignment = "reader_text_alignment"
        case verticalJustify = "reader_vertical_justify"
        case paragraphSeparatorLines = "reader_para_sep_lines"
        case doublePageMode = "readerDoublePageMode"
        case fontName = "reader_custom_font"
        case bottomToolbarStyle = "reader_bottom_toolbar"
        case screenAwake = "reader_screen_awake"
        case searchMode = "reader_search_mode"
        case exploreRanking = "reader_explore_ranking"
        case exploreCacheTTL = "reader_explore_cache_ttl"
        case isBold = "reader_is_bold"
        case volumeButtonPageTurnEnabled = "reader_volume_page_turn"
        case leftPageMargin = "reader_left_page_margin"
        case rightPageMargin = "reader_right_page_margin"
        case textUnderlineColorHex = "reader_underline_color"
        case textColorHex = "reader_text_color"
        case backgroundColorHex = "reader_background_color"
        case backgroundImageName = "reader_background_image"
        case highlightRules = "reader_highlight_rules"
        case highlightRulesEnabled = "reader_highlight_rules_enabled"
        case chapterTitleConfigLight = "reader_chapter_title_light"
        case chapterTitleConfigDark = "reader_chapter_title_dark"
        case layoutTemplate = "reader_layout_template"
        case pageMode, fontWeight, textUnderlineEnabled, textUnderlineThicknessPt, textUnderlineOffsetPt
        case textUnderlineDashed, useBackgroundImage, ttsHighlightColorHex
        case chapterTitlePresets, currentChapterTitlePresetId, customChapterTitlePresets
        case layoutWidgets, topInsetExtra, bottomInsetExtra, paragraphCommentBrowser
    }

    /// 伪代码 0x10021929c（L871-885）对应预设解码域在 ChapterTitlePreset。

    convenience init(from decoder: Decoder) throws {
        self.init()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fontSize = try container.decodeIfPresent(
            CGFloat.self, forKey: .fontSize) ?? 17.0
        lineSpacing = try container.decodeIfPresent(
            CGFloat.self, forKey: .lineSpacing) ?? 8.0
        paragraphSpacing = try container.decodeIfPresent(
            CGFloat.self, forKey: .paragraphSpacing) ?? 4.0
        textIndent = try container.decodeIfPresent(
            Int.self, forKey: .textIndent) ?? 2
        letterSpacing = try container.decodeIfPresent(
            CGFloat.self, forKey: .letterSpacing) ?? 0.0
        let alignmentRaw = try container.decodeIfPresent(
            Int.self, forKey: .textAlignment) ?? 0
        textAlignment = NSTextAlignment(rawValue: alignmentRaw) ?? .left
        verticalJustify = try container.decodeIfPresent(
            Bool.self, forKey: .verticalJustify) ?? false
        paragraphSeparatorLines = try container.decodeIfPresent(
            Int.self, forKey: .paragraphSeparatorLines) ?? 1
        doublePageMode = try container.decodeIfPresent(
            DoublePageMode.self, forKey: .doublePageMode) ?? .off
        fontName = try container.decodeIfPresent(
            String.self, forKey: .fontName) ?? "System"
        let toolbar = try container.decodeIfPresent(String.self, forKey: .bottomToolbarStyle) ?? "classic"
        bottomToolbarStyle = ReaderBottomToolbarStyle(rawValue: toolbar) ?? (toolbar == "full" ? .full : .minimal)
        let awake = try container.decodeIfPresent(String.self, forKey: .screenAwake) ?? "system"
        screenAwake = ScreenAwakeOption(rawValue: awake) ?? (awake == "alwaysOn" ? .never : awake == "timed" ? .tenMinutes : .system)
        searchMode = try container.decodeIfPresent(
            SearchMode.self, forKey: .searchMode) ?? .all
        exploreRanking = try container.decodeIfPresent(
            ExploreSectionRankingMode.self, forKey: .exploreRanking) ?? .defaultOrder
        exploreCacheTTL = try container.decodeIfPresent(
            ExploreCacheTTLOption.self, forKey: .exploreCacheTTL) ?? .thirtyMinutes
        isBold = try container.decodeIfPresent(Bool.self, forKey: .isBold) ?? false
        volumeButtonPageTurnEnabled = try container.decodeIfPresent(
            Bool.self, forKey: .volumeButtonPageTurnEnabled) ?? false
        leftPageMargin = try container.decodeIfPresent(
            CGFloat.self, forKey: .leftPageMargin) ?? 16.0
        rightPageMargin = try container.decodeIfPresent(
            CGFloat.self, forKey: .rightPageMargin) ?? 16.0
        textUnderlineColorHex = try container.decodeIfPresent(
            String.self, forKey: .textUnderlineColorHex) ?? ""
        textColorHex = try container.decodeIfPresent(
            String.self, forKey: .textColorHex) ?? ""
        backgroundColorHex = try container.decodeIfPresent(
            String.self, forKey: .backgroundColorHex) ?? ""
        backgroundImageName = try container.decodeIfPresent(
            String.self, forKey: .backgroundImageName) ?? ""
        highlightRules = try container.decodeIfPresent(
            [HighlightRule].self, forKey: .highlightRules) ?? []
        highlightRulesEnabled = try container.decodeIfPresent(
            Bool.self, forKey: .highlightRulesEnabled) ?? true
        chapterTitleConfigLight = try container.decodeIfPresent(
            ChapterTitleConfig.self, forKey: .chapterTitleConfigLight)
        chapterTitleConfigDark = try container.decodeIfPresent(
            ChapterTitleConfig.self, forKey: .chapterTitleConfigDark)
        layoutTemplate = try container.decodeIfPresent(
            ReaderLayoutTemplate.self, forKey: .layoutTemplate) ?? .standard
        let mode = try container.decodeIfPresent(String.self, forKey: .pageMode) ?? "slide"
        pageMode = PageMode(rawValue: mode) ?? (mode == "curl" ? .curl : mode == "scroll" ? .scroll : .horizontal)
        fontWeight = UIFont.Weight(rawValue: try container.decodeIfPresent(CGFloat.self, forKey: .fontWeight) ?? (isBold ? UIFont.Weight.medium.rawValue : 0))
        textUnderlineEnabled = try container.decodeIfPresent(Bool.self, forKey: .textUnderlineEnabled) ?? false
        textUnderlineThicknessPt = try container.decodeIfPresent(CGFloat.self, forKey: .textUnderlineThicknessPt) ?? 1
        textUnderlineOffsetPt = try container.decodeIfPresent(CGFloat.self, forKey: .textUnderlineOffsetPt) ?? 2
        textUnderlineDashed = try container.decodeIfPresent(Bool.self, forKey: .textUnderlineDashed) ?? false
        useBackgroundImage = try container.decodeIfPresent(Bool.self, forKey: .useBackgroundImage) ?? false
        ttsHighlightColorHex = try container.decodeIfPresent(String.self, forKey: .ttsHighlightColorHex) ?? ""
        chapterTitlePresets = try container.decodeIfPresent([ChapterTitlePreset].self, forKey: .chapterTitlePresets) ?? []
        customChapterTitlePresets = try container.decodeIfPresent([ChapterTitlePreset].self, forKey: .customChapterTitlePresets) ?? []
        currentChapterTitlePresetId = try container.decodeIfPresent(UUID.self, forKey: .currentChapterTitlePresetId)
        layoutWidgets = try container.decodeIfPresent([LayoutWidget].self, forKey: .layoutWidgets) ?? []
        topInsetExtra = try container.decodeIfPresent(CGFloat.self, forKey: .topInsetExtra) ?? 0
        bottomInsetExtra = try container.decodeIfPresent(CGFloat.self, forKey: .bottomInsetExtra) ?? 0
        paragraphCommentBrowser = try container.decodeIfPresent(ParagraphCommentBrowserPresentation.self, forKey: .paragraphCommentBrowser) ?? .modal
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(fontSize, forKey: .fontSize)
        try container.encode(lineSpacing, forKey: .lineSpacing)
        try container.encode(paragraphSpacing, forKey: .paragraphSpacing)
        try container.encode(textIndent, forKey: .textIndent)
        try container.encode(letterSpacing, forKey: .letterSpacing)
        try container.encode(textAlignment.rawValue, forKey: .textAlignment)
        try container.encode(verticalJustify, forKey: .verticalJustify)
        try container.encode(paragraphSeparatorLines, forKey: .paragraphSeparatorLines)
        try container.encode(doublePageMode, forKey: .doublePageMode)
        try container.encode(fontName, forKey: .fontName)
        try container.encode(bottomToolbarStyle, forKey: .bottomToolbarStyle)
        try container.encode(screenAwake, forKey: .screenAwake)
        try container.encode(searchMode, forKey: .searchMode)
        try container.encode(exploreRanking, forKey: .exploreRanking)
        try container.encode(exploreCacheTTL, forKey: .exploreCacheTTL)
        try container.encode(isBold, forKey: .isBold)
        try container.encode(volumeButtonPageTurnEnabled, forKey: .volumeButtonPageTurnEnabled)
        try container.encode(leftPageMargin, forKey: .leftPageMargin)
        try container.encode(rightPageMargin, forKey: .rightPageMargin)
        try container.encode(textUnderlineColorHex, forKey: .textUnderlineColorHex)
        try container.encode(textColorHex, forKey: .textColorHex)
        try container.encode(backgroundColorHex, forKey: .backgroundColorHex)
        try container.encode(backgroundImageName, forKey: .backgroundImageName)
        try container.encode(highlightRules, forKey: .highlightRules)
        try container.encode(highlightRulesEnabled, forKey: .highlightRulesEnabled)
        try container.encode(chapterTitleConfigLight, forKey: .chapterTitleConfigLight)
        try container.encode(chapterTitleConfigDark, forKey: .chapterTitleConfigDark)
        try container.encode(layoutTemplate, forKey: .layoutTemplate)
        try container.encode(pageMode, forKey: .pageMode)
        try container.encode(fontWeight.rawValue, forKey: .fontWeight)
        try container.encode(textUnderlineEnabled, forKey: .textUnderlineEnabled)
        try container.encode(textUnderlineThicknessPt, forKey: .textUnderlineThicknessPt)
        try container.encode(textUnderlineOffsetPt, forKey: .textUnderlineOffsetPt)
        try container.encode(textUnderlineDashed, forKey: .textUnderlineDashed)
        try container.encode(useBackgroundImage, forKey: .useBackgroundImage)
        try container.encode(ttsHighlightColorHex, forKey: .ttsHighlightColorHex)
        try container.encode(chapterTitlePresets, forKey: .chapterTitlePresets)
        try container.encode(customChapterTitlePresets, forKey: .customChapterTitlePresets)
        try container.encodeIfPresent(currentChapterTitlePresetId, forKey: .currentChapterTitlePresetId)
        try container.encode(layoutWidgets, forKey: .layoutWidgets)
        try container.encode(topInsetExtra, forKey: .topInsetExtra)
        try container.encode(bottomInsetExtra, forKey: .bottomInsetExtra)
        try container.encode(paragraphCommentBrowser, forKey: .paragraphCommentBrowser)
    }

}
