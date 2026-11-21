// 原路径: ReadMain/Core/ReadingSettings.swift
// 证据:
//   - PGO: 69 函数族 + T-1401-01 逐域补齐 35 域（needsRepagination varinit
//     0x10021f7bc / isBold.setter 0x100213b80 / ttsHighlightUIColor 0x100215484 /
//     textUIColor 0x1002155d4 / bgUIColor 0x100215820 / backgroundUIImage
//     0x100215894 / backgroundImagesDirectory 0x1002123e0 / setBackgroundImage
//     0x100215ab0 / compiledHighlightRules 0x100216b40 /
//     compiledHighlightLayoutRules 0x1002171a8 /
//     consumeHighlightLayoutAppearanceChangeIfNeeded 0x1002176ec /
//     highlightRulesLayoutSignature 0x1002171fc / ChapterTitlePreset.init(from:)
//     0x10021929c / activeChapterTitleConfig 0x10021a4fc /
//     loadStoredChapterTitleConfigs 0x10021a77c / loadScreenAwakeOption
//     0x10021f948 / loadVolumeButtonPageTurnEnabled 0x10021f8b0 /
//     loadDoublePageMode 0x10021f85c / flushPendingSave 0x1002204dc /
//     performReaderThemeApplication 0x100206dc4 / updateWidgetLayoutMetrics
//     0x100221e18 / applyLayoutTemplate 0x100221ef8 / getLayout 0x100222014 /
//     getContentAreaSize 0x100222130 / textFont 0x1002222d0 / textStrokeWidth
//     0x1002226c0 / textUnderlineUsesTextColor 0x1002227c0 /
//     textUnderlineUIColor 0x10022282c / textUnderlineDashPattern 0x100222884 /
//     fontWeightSwiftUI 0x1002229e8 / preferredReaderSystemFontName
//     0x1002224cc / preferredReaderSystemUIFont 0x1002120e8 / widgetFont
//     0x100222f5c / Color.init(hex:) 0x100211b5c / Color.toHex 0x100212000）
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Core/ReadingSettings.c（7775 行）
//   - 诊断串：readerDoublePageMode/screenAwakeOption/volumeButtonPageTurnEnabled/
//     chapterTitleConfig/stringForKey:/boolForKey:/dataForKey:/defaultManager/
//     URLsForDirectory:inDomains:(9,1)/ReaderBackgrounds/fileExistsAtPath:/
//     createDirectoryAtURL:/size/initWithSize:/imageWithActions:/uuidString/
//     UIImageJPEGRepresentation/Data.write/PingFang/两端对齐/居中/左对齐/
//     textUnderlineThicknessPt/textUnderlineOffsetPt/leftPageMargin/
//     letterSpacing/textAlignment/Leaflow/HighlightRule.swift
//   - 类型形态：ObservationRegistrar.access/willSet/didSet（isBold.setter
//     0x100213b80 / consumeHighlight 域）+ 引用偏移访问（v0[x20]）+ MainActor
//     executor 断言（0x10021f948 reportUnexpectedExecutor）→ @Observable
//     @MainActor final class。
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - 35 补齐域: high（地址+签名+键名字面量确证）
//   - 缓存偏移命名: medium（offsets 272/280/39-41/368-400/1056-1081 语义映射）
//   - DoublePageMode 档位/键名回退: medium（字面量移位归属确证，档位推断）
// 还原: 2026-11-19；T-1401-01 逐域补齐 2026-11-21

import Observation
import SwiftUI
import UIKit

// MARK: - 搜索模式

/// 搜索模式（伪代码 0x1002125f0，L10-24）。
enum SearchMode: String, CaseIterable, Codable {
    case all = "all"
    case titleOnly = "titleOnly"

    var label: String {
        self == .all ? "全文搜索" : "仅标题"
    }

    var description: String {
        self == .all ? "搜索书名、作者和正文" : "仅搜索书名和作者"
    }
}

/// 发现页排序模式（伪代码 0x100212818，L33-47）。
enum ExploreSectionRankingMode: String, CaseIterable, Codable {
    case defaultOrder = "default"
    case updatedFirst = "updated"

    var label: String {
        self == .defaultOrder ? "默认排序" : "最近更新"
    }

    var description: String {
        self == .defaultOrder ? "按书源原始顺序" : "按最近更新时间排序"
    }
}

/// 发现页缓存 TTL（伪代码 0x100212abc，L60-83）。
enum ExploreCacheTTLOption: String, CaseIterable, Codable {
    case fiveMinutes = "300"
    case thirtyMinutes = "1800"
    case oneHour = "3600"
    case sixHours = "21600"
    case oneDay = "86400"

    var label: String {
        switch self {
        case .fiveMinutes: return "5 分钟"
        case .thirtyMinutes: return "30 分钟"
        case .oneHour: return "1 小时"
        case .sixHours: return "6 小时"
        case .oneDay: return "1 天"
        }
    }

    /// 伪代码 0x100212c40（L73-83）。
    var seconds: Double {
        Double(rawValue) ?? 300.0
    }
}

/// 底部工具栏样式（伪代码 0x100213094，L90）。
enum ReaderBottomToolbarStyle: String, CaseIterable, Codable {
    case minimal = "minimal"
    case full = "full"

    var id: String { rawValue }
}

/// 屏幕常亮选项（伪代码 0x1002130c0，L120-140）。
enum ScreenAwakeOption: String, CaseIterable, Codable {
    case system = "system"
    case alwaysOn = "alwaysOn"
    case timed = "timed"

    var id: String { rawValue }

    /// 伪代码 0x10021316c（L122-130）。
    var title: String {
        switch self {
        case .system: return "跟随系统"
        case .alwaysOn: return "始终常亮"
        case .timed: return "定时"
        }
    }

    /// 伪代码 0x100213258（L132-140）。
    var duration: Duration? {
        self == .timed ? Duration.seconds(600) : nil
    }
}



// MARK: - 阅读设置

/// 阅读设置模型（@Observable 类：ObservationRegistrar + 引用偏移域确证）。
@Observable
@MainActor
final class ReadingSettings: Codable {
    // MARK: 持久化设置域

    var fontSize: CGFloat = 17.0
    var lineSpacing: CGFloat = 8.0
    var paragraphSpacing: CGFloat = 4.0
    var textIndent: Int = 2
    var letterSpacing: CGFloat = 0.0
    var textAlignment: NSTextAlignment = .left
    var verticalJustify: Bool = false
    var paragraphSeparatorLines: Int = 1
    /// 双页模式（loadDoublePageMode 域；键 readerDoublePageMode 20 字符确证）。
    var doublePageMode: DoublePageMode = .off
    var fontName: String = "System"
    var bottomToolbarStyle: ReaderBottomToolbarStyle = .minimal
    var screenAwake: ScreenAwakeOption = .system
    var searchMode: SearchMode = .all
    var exploreRanking: ExploreSectionRankingMode = .defaultOrder
    var exploreCacheTTL: ExploreCacheTTLOption = .thirtyMinutes

    /// 伪代码 0x10021f7bc（L158）：UserDefaults 布尔初始化
    /// （键名域与相邻 load* 块字面量交错，回退键推断）。
    var needsRepagination: Bool =
        UserDefaults.standard.bool(forKey: "readerNeedsRepagination")

    /// 字重原始值（sub_100213AB0 读取域；UIFont.Weight 阈值链消费）。
    /// 非持久化域；持久化投影 isBold（flushPendingSave
    /// setBool(UIFontWeightMedium ≤ weight) 确证）。
    var fontWeight: UIFont.Weight = .regular

    /// 伪代码 0x100213b80（L196）：写路径清排版缓存（Dictionary.removeAll 域）
    /// + 修订计数递增（offset 46）。
    var isBold: Bool = false {
        didSet {
            invalidateTypographyCaches()
            typographyRevision += 1
        }
    }

    /// 音量键翻页（0x10021f8b0 块体；键名 27 字符字面量移位归属确证）。
    var volumeButtonPageTurnEnabled: Bool = false

    /// 页边距（flushPendingSave "leftPageMargin"/"rightPageMargin" 键域）。
    var leftPageMargin: CGFloat = 16.0
    var rightPageMargin: CGFloat = 16.0

    /// 下划线域（flushPendingSave "textUnderlineThicknessPt"/
    /// "textUnderlineOffsetPt" 键域）。
    var textUnderlineThicknessPt: CGFloat = 1.0
    var textUnderlineOffsetPt: CGFloat = 2.0
    /// 下划线色（textUnderlineUsesTextColor/textUnderlineUIColor 构造域；
    /// sub_100214A18 读取域）。空串 = 用正文色。
    var textUnderlineColorHex: String = ""
    /// 下划线虚线档（textUnderlineDashPattern 尾调域；推断）。
    var textUnderlineDashed: Bool = false

    /// 背景域：useBackgroundImage（sub_100215790）/ 色调 hex
    ///（sub_100215670 → bgUIColor 解析）/ 图片文件名（backgroundUIImage 加载）。
    var useBackgroundImage: Bool = false
    var backgroundColorHex: String = ""
    var backgroundImageName: String = ""

    /// 正文色 hex（textUIColor 构造域 sub_100215024；空串回退系统 label）。
    var textColorHex: String = ""

    /// TTS 高亮色 hex（ttsHighlightUIColor 构造域 sub_100215204/10021536C；
    /// 空串回退 systemYellow，推断）。
    var ttsHighlightColorHex: String = ""

    /// 用户高亮规则集（0x100216b40 域；内置经 mergedWithBuiltinRules 合并）。
    var highlightRules: [HighlightRule] = []
    /// 高亮规则启用位（sub_1002274B8 读取域）。
    var highlightRulesEnabled: Bool = true

    /// 章节标题双档配置（loadStoredChapterTitleConfigs "chapterTitleConfig"
    /// 18 字符键确证；JSON 双档）。
    var chapterTitleConfigLight: ChapterTitleConfig?
    var chapterTitleConfigDark: ChapterTitleConfig?

    /// 自定义章节标题预设（ChapterTitlePreset 桥升级为真实存储域）。
    var chapterTitlePresets: [ChapterTitlePreset] = []
    var currentChapterTitlePresetId: UUID?

    /// 布局模板（applyLayoutTemplate 0x100221ef8 域；档位推断）。
    var layoutTemplate: ReaderLayoutTemplate = .standard
    /// 布局 widgets 集（applyLayoutTemplate 写入域）。
    var layoutWidgets: [LayoutWidget] = []
    /// 上下留白增量（calculateLayout 全参链域）。
    var topInsetExtra: CGFloat = 0.0
    var bottomInsetExtra: CGFloat = 0.0

    // MARK: 非持久化缓存域（伪代码偏移语义映射）

    /// 编译规则缓存（offset 400，0x100216b40 写回域）。
    private var compiledRulesCache: [CompiledHighlightRule]?
    /// 布局档编译缓存（签名键控，0x1002171a8 域）。
    private var compiledLayoutRulesBySignature: [Int: [CompiledHighlightRule]] = [:]
    /// 布局签名与变化计数（offsets 368/376/384/392，0x1002176ec 域）。
    private var lastHighlightLayoutSignature: Int = 0
    private var appearanceChangeCount: Int = 0
    private var layoutChangeCount: Int = 0
    private var pendingHighlightRebuild: Bool = false
    /// 排版缓存修订计数（isBold.setter offset 46 域）。
    private var typographyRevision: Int = 0
    /// 亮/暗 TTS 高亮色缓存（offsets 272/280，0x100215484 域）。
    private var ttsHighlightLightColorCache: UIColor?
    private var ttsHighlightDarkColorCache: UIColor?
    /// 正文色缓存（offset 27*8，0x1002155d4 域）。
    private var textUIColorCache: UIColor?
    /// 背景图缓存（offsets 39/40/41，0x100215894 域）。
    private var cachedBackgroundImage: UIImage?
    private var cachedBackgroundFilename: String?
    /// Widget 度量缓存（offsets 1056-1081，0x100221e18 域）。
    private var widgetMetrics: ReaderWidgetLayoutMetrics = ReaderWidgetLayoutMetrics(
        pageBounds: .zero, windowSafeAreaFrame: .zero, userInterfaceIdiom: .phone)
    /// Widget 字体缓存（offset 1136 数组域，0x100222f5c）。
    private var widgetFontCache: UIFont?
    /// 挂起保存标志与防抖任务（flushPendingSave implicit closure #36 in init 域）。
    private var hasPendingSave: Bool = false
    private var pendingSaveTask: DispatchWorkItem?

    enum CodingKeys: String, CodingKey {
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
    }

    init() {}

    /// 伪代码 0x10021929c（L871-885）对应预设解码域在 ChapterTitlePreset。

    init(from decoder: Decoder) throws {
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
        bottomToolbarStyle = try container.decodeIfPresent(
            ReaderBottomToolbarStyle.self, forKey: .bottomToolbarStyle) ?? .minimal
        screenAwake = try container.decodeIfPresent(
            ScreenAwakeOption.self, forKey: .screenAwake) ?? .system
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
    }

    // MARK: 静态加载域

    /// 从 UserDefaults 加载。
    static func load() -> ReadingSettings {
        let defaults = UserDefaults.standard
        let settings = ReadingSettings()
        if defaults.object(forKey: CodingKeys.fontSize.rawValue) != nil {
            settings.fontSize = CGFloat(
                defaults.double(forKey: CodingKeys.fontSize.rawValue))
        }
        if defaults.object(forKey: CodingKeys.lineSpacing.rawValue) != nil {
            settings.lineSpacing = CGFloat(
                defaults.double(forKey: CodingKeys.lineSpacing.rawValue))
        }
        settings.doublePageMode = loadDoublePageMode(from: defaults)
        settings.screenAwake = loadScreenAwakeOption(from: defaults)
        settings.volumeButtonPageTurnEnabled =
            loadVolumeButtonPageTurnEnabled(from: defaults)
        settings.fontName = defaults.string(forKey: CodingKeys.fontName.rawValue)
            ?? "System"
        let pair = loadStoredChapterTitleConfigs(from: defaults)
        settings.chapterTitleConfigLight = pair.light
        settings.chapterTitleConfigDark = pair.dark
        return settings
    }

    /// 伪代码 0x10021f948（L1297-1304）：screenAwakeOption 键（17 字符字面量
    /// 移位归属确证）；原始值域钳制分支（2≤x≤5）暗示更宽档位空间，记入仍不清楚。
    static func loadScreenAwakeOption(from defaults: UserDefaults) -> ScreenAwakeOption {
        let raw = defaults.string(forKey: "screenAwakeOption") ?? ""
        return ScreenAwakeOption(rawValue: raw) ?? .system
    }

    /// 伪代码 0x10021f8b0（L1306-1308）：volumeButtonPageTurnEnabled 键
    /// （27 字符字面量确证）。
    static func loadVolumeButtonPageTurnEnabled(from defaults: UserDefaults) -> Bool {
        defaults.bool(forKey: "volumeButtonPageTurnEnabled")
    }

    /// 伪代码 0x10021f85c（L1310-1317）：readerDoublePageMode 键（20 字符
    /// 字面量确证，移位归属还原）。
    static func loadDoublePageMode(from defaults: UserDefaults) -> DoublePageMode {
        DoublePageMode(rawValue: defaults.string(forKey: "readerDoublePageMode") ?? "")
            ?? .off
    }

    /// 伪代码 0x10021a77c（L946-964）：chapterTitleConfig 键（18 字符确证）→
    /// JSONDecoder 双档解码；无数据回退默认档。
    static func loadStoredChapterTitleConfigs(
        from defaults: UserDefaults
    ) -> (light: ChapterTitleConfig, dark: ChapterTitleConfig) {
        struct Pair: Codable {
            var light: ChapterTitleConfig
            var dark: ChapterTitleConfig
        }
        let fallback = ChapterTitleConfig(
            fontName: "System", fontSize: 22, textAlignment: .center, useBold: true)
        guard let data = defaults.data(forKey: "chapterTitleConfig"),
              let pair = try? JSONDecoder().decode(Pair.self, from: data) else {
            return (fallback, fallback)
        }
        return (pair.light, pair.dark)
    }

    /// 静态可写标志（getLayout/getContentAreaSize 分支域
    /// implicit closure #1 in canWritePersistentDefaults.getter 确证）。
    static var canWritePersistentDefaults: Bool { true }

    // MARK: 章节标题配置域

    /// 当前预设（currentChapterTitlePresetId + 自定义/内置双源）。
    var currentChapterTitlePreset: ChapterTitlePreset? {
        chapterTitlePresets.first { $0.id == currentChapterTitlePresetId }
            ?? ChapterTitlePreset.builtIns.first
    }

    /// 伪代码 0x10021a4fc（L908-920）：当前预设亮/暗档配置合并基础字体域
    ///（struct 拷贝域；fontName/fontSize/textAlignment/useBold 四字段确证）。
    var activeChapterTitleConfig: ChapterTitleConfig {
        let preset = currentChapterTitlePreset
        let config = currentAppearanceIsDark
            ? (preset?.darkConfig ?? preset?.lightConfig)
            : (preset?.lightConfig ?? chapterTitleConfigLight)
        if let config {
            return ChapterTitleConfig(
                fontName: config.fontName.isEmpty ? fontName : config.fontName,
                fontSize: config.fontSize > 0 ? config.fontSize : fontSize,
                textAlignment: config.textAlignment,
                useBold: config.useBold || isBold)
        }
        return ChapterTitleConfig(
            fontName: fontName, fontSize: fontSize,
            textAlignment: textAlignment, useBold: isBold)
    }

    /// 当前配置桥（ChapterTitleSettingsView 消费域；亮档读写）。
    var currentChapterTitleConfig: ChapterTitleConfig {
        get {
            chapterTitleConfigLight ?? ChapterTitleConfig(
                fontName: fontName, fontSize: fontSize,
                textAlignment: textAlignment, useBold: isBold)
        }
        set { chapterTitleConfigLight = newValue }
    }

    // MARK: 高亮规则编译域

    /// 伪代码 0x100216b40（L574-592）：未启用 → 空并清缓存（offset 400）；
    /// 缓存命中直接返回；否则 mergedWithBuiltinRules 合并 +
    /// HighlightRuleImportService.normalizedImportedRules 域归一化 + 逐条
    /// NSRegularExpression 编译 + 回填缓存。
    var compiledHighlightRules: [CompiledHighlightRule] {
        guard highlightRulesEnabled else {
            compiledRulesCache = []
            return []
        }
        if let cached = compiledRulesCache { return cached }
        let merged = HighlightRule.mergedWithBuiltinRules(highlightRules)
        let compiled = HighlightRuleImportService.normalizedImportedRules(merged)
            .map { rule in
                CompiledHighlightRule(
                    rule: rule,
                    regex: try? NSRegularExpression(pattern: rule.regex))
            }
        compiledRulesCache = compiled
        return compiled
    }

    /// 伪代码 0x1002171a8（L594-609）：规则集 + 启用位 + 暗色位 →
    /// highlightRulesLayoutSignature 签名键控缓存；未命中重编译并回填。
    var compiledHighlightLayoutRules: [CompiledHighlightRule] {
        let signature = Self.highlightRulesLayoutSignature(
            highlightRules: highlightRules,
            highlightRulesEnabled: highlightRulesEnabled,
            isDark: currentAppearanceIsDark)
        if let cached = compiledLayoutRulesBySignature[signature] {
            return cached
        }
        let compiled = HighlightRule.mergedWithBuiltinRules(highlightRules)
            .map { rule in
                CompiledHighlightRule(
                    rule: rule,
                    regex: try? NSRegularExpression(pattern: rule.regex))
            }
        compiledLayoutRulesBySignature[signature] = compiled
        return compiled
    }

    /// 伪代码 0x1002176ec（L619-627）：清编译缓存（offset 400）→ 亮/暗双档
    /// 签名对比；同 → appearanceChangeCount++（offset 368），异 →
    /// layoutChangeCount++（offset 376）；记录 lastSignature（offset 384）
    /// 并复位标志（offset 392）；返回是否发生外观变化。
    @discardableResult
    func consumeHighlightLayoutAppearanceChangeIfNeeded() -> Bool {
        compiledRulesCache = nil
        let lightSignature = Self.highlightRulesLayoutSignature(
            highlightRules: highlightRules,
            highlightRulesEnabled: highlightRulesEnabled,
            isDark: false)
        let darkSignature = Self.highlightRulesLayoutSignature(
            highlightRules: highlightRules,
            highlightRulesEnabled: highlightRulesEnabled,
            isDark: true)
        let appearanceOnly = lightSignature == darkSignature
        if appearanceOnly {
            appearanceChangeCount += 1
        } else {
            layoutChangeCount += 1
        }
        lastHighlightLayoutSignature = appearanceOnly ? lightSignature : darkSignature
        pendingHighlightRebuild = false
        return !appearanceOnly
    }

    /// 伪代码 0x1002171fc（L655-665）：Hasher 起始 + 逐规则 392 字节 Layout 域
    ///（trim whitespacesAndNewlines + 空模板/零高度过滤 + fontWeight 域合并）；
    /// 未启用 → 空（仅保留 isDark 位）。
    static func highlightRulesLayoutSignature(
        highlightRules: [HighlightRule],
        highlightRulesEnabled: Bool,
        isDark: Bool
    ) -> Int {
        var hasher = Hasher()
        hasher.combine(highlightRulesEnabled)
        hasher.combine(isDark)
        guard highlightRulesEnabled else { return hasher.finalize() }
        for rule in highlightRules {
            let css = (isDark ? rule.darkStyleCSS : rule.lightStyleCSS)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            hasher.combine(css)
            hasher.combine(rule.fontWeight ?? 0)
            hasher.combine(rule.fontSize)
            hasher.combine(rule.crossPageQuotes)
            hasher.combine(rule.noCrossParagraph)
        }
        return hasher.finalize()
    }

    // MARK: 颜色域

    /// 暗色外观判定（缓存分档条件；推断——块体条件域与 getContentAreaSize
    /// 调用交错）。
    private var currentAppearanceIsDark: Bool {
        UITraitCollection.current.userInterfaceStyle == .dark
    }

    /// 伪代码 0x100215484（L381-393）：亮/暗双缓存（offsets 272/280）；未命中
    /// 经主题高亮色域构造（sub_100215204 亮 / sub_10021536C 暗）后回填。
    var ttsHighlightUIColor: UIColor {
        let hex = ttsHighlightColorHex
        if currentAppearanceIsDark {
            if let cached = ttsHighlightDarkColorCache { return cached }
            let color = hex.isEmpty ? .systemYellow : UIColor(leaflowColor(hex))
            ttsHighlightDarkColorCache = color
            return color
        }
        if let cached = ttsHighlightLightColorCache { return cached }
        let color = hex.isEmpty ? .systemYellow : UIColor(leaflowColor(hex))
        ttsHighlightLightColorCache = color
        return color
    }

    /// 伪代码 0x1002155d4（L395-400）：缓存命中（offset 27*8）直接返回；未命中
    /// 经主题文字色域构造（sub_100215024）回填；空 hex 回退系统 label。
    var textUIColor: UIColor {
        if let cached = textUIColorCache { return cached }
        let color = textColorHex.isEmpty
            ? .label
            : UIColor(leaflowColor(textColorHex))
        textUIColorCache = color
        return color
    }

    /// 伪代码 0x100215820（L401-406）：背景图启用且 hex 非空 → 解析构造
    ///（sub_100215790/sub_100215670 读取域）；否则 nil。
    var bgUIColor: UIColor? {
        guard useBackgroundImage, !backgroundColorHex.isEmpty else { return nil }
        return UIColor(leaflowColor(backgroundColorHex))
    }

    /// 伪代码 0x100215894（L437-447）：文件名缓存命中（offsets 39/40/41）直接
    /// 返回；否则 backgroundImagesDirectory + appendingPathComponent 加载
    /// Data(contentsOf:) → UIImage(data:) 并回填缓存。
    var backgroundUIImage: UIImage? {
        guard useBackgroundImage, !backgroundImageName.isEmpty else { return nil }
        if cachedBackgroundFilename == backgroundImageName,
            let cached = cachedBackgroundImage {
            return cached
        }
        guard let directory = try? Self.backgroundImagesDirectory else {
            return nil
        }
        let url = directory.appendingPathComponent(backgroundImageName)
        guard let data = try? Data(contentsOf: url),
            let image = UIImage(data: data) else {
            return nil
        }
        cachedBackgroundImage = image
        cachedBackgroundFilename = backgroundImageName
        return image
    }

    /// 伪代码 0x100215ab0（L460-482）：nil → 清缓存与存储名（sub_1002156CC(0)
    /// 域）；否则 1200pt 上限缩放（UIGraphicsImageRenderer size 域）→
    /// UUID.jpeg 命名（uuidString 域）→ JPEG 0.85 写入背景目录 → 回填缓存并
    /// 触发刷新（sub_1002157C4(1) 域）。
    func setBackgroundImage(_ image: UIImage?) {
        guard let image else {
            cachedBackgroundImage = nil
            cachedBackgroundFilename = nil
            backgroundImageName = ""
            return
        }
        let size = image.size
        let scale = size.width > 0 ? min(1.0, 1200.0 / size.width) : 1.0
        let scaledSize = CGSize(width: size.width * scale, height: size.height * scale)
        let rendered = UIGraphicsImageRenderer(size: scaledSize).image { _ in
            image.draw(in: CGRect(origin: .zero, size: scaledSize))
        }
        let filename = UUID().uuidString + ".jpg"
        guard let directory = try? Self.backgroundImagesDirectory else { return }
        let url = directory.appendingPathComponent(filename)
        guard let data = rendered.jpegData(compressionQuality: 0.85) else { return }
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            return
        }
        cachedBackgroundImage = rendered
        cachedBackgroundFilename = filename
        backgroundImageName = filename
    }

    /// 伪代码 0x1002123e0（L450-457）：Application Support
    ///（URLsForDirectory:9/inDomains:1 确证）+ ReaderBackgrounds 子目录；
    /// 不存在则 createDirectoryAtURL withIntermediateDirectories 创建
    ///（_convertNSErrorToError 域确证 throws）。
    static var backgroundImagesDirectory: URL {
        get throws {
            let fileManager = FileManager.default
            guard let base = fileManager.urls(
                for: .applicationSupportDirectory, in: .userDomainMask).first
            else {
                throw CocoaError(.fileNoSuchFile)
            }
            let directory = base.appendingPathComponent(
                "ReaderBackgrounds", isDirectory: true)
            if !fileManager.fileExists(atPath: directory.path) {
                try fileManager.createDirectory(
                    at: directory, withIntermediateDirectories: true)
            }
            return directory
        }
    }

    /// 伪代码 0x10022282c（L1655-1660）：下划线色 hex 非空 → Color(hex:) 桥；
    /// 空 → 正文色域（与 textUnderlineUsesTextColor 互补）。
    var textUnderlineUIColor: UIColor {
        textUnderlineColorHex.isEmpty
            ? textUIColor
            : UIColor(leaflowColor(textUnderlineColorHex))
    }

    /// 伪代码 0x1002227c0（L1651-1653）：未设下划线色 → 用正文色。
    var textUnderlineUsesTextColor: Bool {
        textUnderlineColorHex.isEmpty
    }

    /// 伪代码 0x100222884（L1670-1682）：尾调合并域（sub_1001FBA90）；
    /// 虚线档返回 dash 数组，实线档 nil（dash 值推断）。
    var textUnderlineDashPattern: [NSNumber]? {
        textUnderlineDashed ? [NSNumber(value: 3.0), NSNumber(value: 3.0)] : nil
    }

    // MARK: 字体域

    /// 伪代码 0x1002222d0（L1620-1637）：System（0x6D6574737953 确证）→
    /// 系统字体；自定义 → Font.custom(_:size:)，权重 ≥ semibold 叠加 .bold()。
    var textFont: Font {
        if fontName == "System" {
            return .system(size: fontSize, weight: fontWeightSwiftUI)
        }
        let custom = Font.custom(fontName, size: fontSize)
        if fontWeight.rawValue >= UIFont.Weight.semibold.rawValue {
            return custom.bold()
        }
        return custom
    }

    /// 伪代码 0x1002226c0（L1644-1649）：System 或零权重 → 0；否则
    /// weight / -0.62 * 5.0（负值描边 = 填充+描边，NSAttributedString 语义）。
    var textStrokeWidth: CGFloat {
        guard fontName != "System" else { return 0 }
        return fontWeight.rawValue > 0 ? fontWeight.rawValue / -0.62 * 5.0 : 0
    }

    /// 伪代码 0x1002229e8（L1705-1716）：UIFont.Weight 阈值链
    ///（ultraLight→black 逐档比较）→ SwiftUI Font.Weight 镜像。
    var fontWeightSwiftUI: Font.Weight {
        switch fontWeight {
        case .ultraLight: return .ultraLight
        case .thin: return .thin
        case .light: return .light
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        case .heavy: return .heavy
        case .black: return .black
        @unknown default: return .regular
        }
    }

    /// 伪代码 0x1002224cc（L1732-1752）：PingFang 前缀（0x676E6146676E6950
    /// 确证）+ "-" + 权重名拼接；权重阈值链逐档回退。
    static func preferredReaderSystemFontName(
        weight: UIFont.Weight, prefersSimplifiedChinese: Bool
    ) -> String {
        let suffix: String
        switch weight {
        case .ultraLight: suffix = "UltraLight"
        case .thin: suffix = "Thin"
        case .light: suffix = "Light"
        case .regular: suffix = "Regular"
        case .medium: suffix = "Medium"
        case .semibold: suffix = "Semibold"
        case .bold: suffix = "Bold"
        case .heavy: suffix = "Heavy"
        case .black: suffix = "Black"
        @unknown default: suffix = "Regular"
        }
        let family = prefersSimplifiedChinese ? "PingFangSC" : "PingFangTC"
        return "\(family)-\(suffix)"
    }

    /// 伪代码 0x1002120e8（L1758-1767）：preferredReaderSystemFontName 链
    /// → UIFont(name:size:)；未命中回退 systemFont。
    static func preferredReaderSystemUIFont(
        ofSize size: CGFloat, weight: UIFont.Weight, prefersSimplifiedChinese: Bool
    ) -> UIFont {
        let name = preferredReaderSystemFontName(
            weight: weight, prefersSimplifiedChinese: prefersSimplifiedChinese)
        return UIFont(name: name, size: size)
            ?? .systemFont(ofSize: size, weight: weight)
    }

    /// 伪代码 0x100222f5c（L1799-1809）：fontName == "System" → systemFont；
    /// 否则 UIFont(name:) 并缓存（offset 1136 域）；未命中回退系统字体。
    func widgetFont(size: CGFloat) -> UIFont {
        if fontName == "System" {
            return .systemFont(ofSize: size, weight: fontWeight)
        }
        if let cached = widgetFontCache, cached.fontName == fontName,
            abs(cached.pointSize - size) < 0.5 {
            return cached
        }
        let font = UIFont(name: fontName, size: size)
            ?? .systemFont(ofSize: size, weight: fontWeight)
        widgetFontCache = font
        return font
    }

    // MARK: 布局域

    /// 伪代码 0x100221ef8（L1555-1565）：模板写入（sub_100227F80 域）→
    /// ReaderLayoutCalculator.calculateLayout 全参链重排并缓存结果
    ///（0xA8 LayoutResult memcpy 域确证）。
    func applyLayoutTemplate(_ template: ReaderLayoutTemplate) {
        layoutTemplate = template
        let bounds = ReaderLayoutCalculator.resolveWindowMetrics()?.bounds
            ?? UIScreen.main.bounds
        cachedLayout = try? getLayout(
            isFirstPage: true, screenBounds: bounds, chapterTitle: "")
    }

    /// 最近一次布局结果缓存（applyLayoutTemplate/getLayout 写入域）。
    private var cachedLayout: ReaderLayoutResult?

    /// 伪代码 0x100222014（L1568-1580）：canWritePersistentDefaults 为真 →
    /// 用窗口度量缓存；否则走 getContentAreaSize 摘要链。
    /// 注：仓库现行 calculateLayout 签名以 safeAreaFrame 取代
    /// chapterTitle/fontFamily 两参（T-302 还原形态），语义等价合并。
    func getLayout(
        isFirstPage: Bool, screenBounds: CGRect?, chapterTitle: String
    ) throws -> ReaderLayoutResult {
        let resolvedBounds = Self.canWritePersistentDefaults
            ? (ReaderLayoutCalculator.resolveWindowMetrics()?.bounds ?? screenBounds)
            : screenBounds
        guard let bounds = resolvedBounds else {
            throw CocoaError(.fileReadUnknown)
        }
        _ = chapterTitle
        return ReaderLayoutCalculator.calculateLayout(
            isFirstPage: isFirstPage,
            chapterTitleConfig: activeChapterTitleConfig,
            leftPageMargin: leftPageMargin,
            rightPageMargin: rightPageMargin,
            topInsetExtra: topInsetExtra,
            bottomInsetExtra: bottomInsetExtra,
            screenBounds: bounds,
            safeAreaFrame: screenBounds ?? bounds)
    }

    /// 伪代码 0x100222130（L1583-1594）：getLayout 链 → contentRect 尺寸。
    func getContentAreaSize(
        isFirstPage: Bool, chapterTitle: String
    ) throws -> CGSize {
        let layout = try getLayout(
            isFirstPage: isFirstPage,
            screenBounds: ReaderLayoutCalculator.resolveWindowMetrics()?.bounds,
            chapterTitle: chapterTitle)
        return layout.contentRect.size
    }

    /// 伪代码 0x100221e18（L1546-1552）：ReaderWidgetLayoutMetrics
    ///（pageBounds:windowSafeAreaFrame:userInterfaceIdiom: 确证）构建缓存
    ///（offsets 1056-1081）；未变化 / pad 档（offset 1081 == 4 分支）→ false；
    /// 变化 → 触发布局刷新（sub_100221EA0）→ true。
    @discardableResult
    func updateWidgetLayoutMetrics(from view: UIView) -> Bool {
        guard let window = view.window else { return false }
        let metrics = ReaderWidgetLayoutMetrics(
            pageBounds: view.bounds,
            windowSafeAreaFrame: window.safeAreaLayoutGuide.layoutFrame,
            userInterfaceIdiom: UIDevice.current.userInterfaceIdiom)
        guard metrics.pageBounds != widgetMetrics.pageBounds
            || metrics.safeAreaFrame != widgetMetrics.safeAreaFrame else {
            return false
        }
        if metrics.isPad { return false }
        widgetMetrics = metrics
        return true
    }

    // MARK: 主题应用域

    /// 伪代码 0x100206dc4（L1521-1533）：Color.init(hex:) 双 hex 域（亮/暗）→
    /// ThemeManager.normalizedDarkChapterTitleConfig(from:) +
    /// ThemeManager.applyInterfaceSettings(from:to:) 链。
    func performReaderThemeApplication(
        forceRepagination: Bool, _ completion: () -> Void
    ) {
        ThemeManager.shared.normalizedDarkChapterTitleConfig(from: self)
        ThemeManager.shared.applyInterfaceSettings(
            from: self, to: self, forceRepagination: forceRepagination)
        completion()
    }

    // MARK: 保存域

    /// 挂起保存调度（flushPendingSave implicit closure #36 in init 防抖域；
    /// 延迟间隔推断）。
    func schedulePendingSave(after interval: TimeInterval = 0.5) {
        pendingSaveTask?.cancel()
        hasPendingSave = true
        let task = DispatchWorkItem { [weak self] in
            self?.flushPendingSave()
        }
        pendingSaveTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + interval, execute: task)
    }

    /// 伪代码 0x1002204dc（L1367-1372）：挂起标志未置位 → Logger.log 早退；
    /// 否则全键写回 UserDefaults（leftPageMargin/letterSpacing/textAlignment/
    /// textUnderlineThicknessPt/textUnderlineOffsetPt 键域 +
    /// setBool(UIFontWeightMedium ≤ weight) isBold 投影），尾调 performSave()。
    func flushPendingSave() {
        guard hasPendingSave else {
            Logger.log(
                "无挂起的设置保存", level: .warning,
                module: .general, file: "ReadingSettings", line: 1370)
            return
        }
        let defaults = UserDefaults.standard
        defaults.set(Double(leftPageMargin), forKey: "leftPageMargin")
        defaults.set(Double(rightPageMargin), forKey: "rightPageMargin")
        defaults.set(Double(letterSpacing), forKey: "letterSpacing")
        defaults.set(textAlignment.rawValue, forKey: "textAlignment")
        defaults.set(
            Double(textUnderlineThicknessPt), forKey: "textUnderlineThicknessPt")
        defaults.set(
            Double(textUnderlineOffsetPt), forKey: "textUnderlineOffsetPt")
        defaults.set(
            fontWeight.rawValue >= UIFont.Weight.medium.rawValue,
            forKey: "reader_is_bold")
        hasPendingSave = false
        performSave()
    }

    /// performSave 尾调域（flushPendingSave → performSave）：
    /// Codable 快照持久化桥（BackupService.exportReadingSettings 消费）。
    private func performSave() {
        save()
    }

    /// 保存到 UserDefaults。
    func save() {
        let defaults = UserDefaults.standard
        defaults.set(Double(fontSize), forKey: CodingKeys.fontSize.rawValue)
        defaults.set(Double(lineSpacing), forKey: CodingKeys.lineSpacing.rawValue)
        defaults.set(
            Double(paragraphSpacing), forKey: CodingKeys.paragraphSpacing.rawValue)
        defaults.set(textIndent, forKey: CodingKeys.textIndent.rawValue)
        defaults.set(
            Double(letterSpacing), forKey: CodingKeys.letterSpacing.rawValue)
        defaults.set(doublePageMode.rawValue, forKey: "readerDoublePageMode")
        defaults.set(fontName, forKey: CodingKeys.fontName.rawValue)
    }

    // MARK: 缓存失效域

    /// 排版缓存失效（isBold.setter / applyLayoutTemplate 消费域；
    /// Dictionary.removeAll 域语义）。
    private func invalidateTypographyCaches() {
        textUIColorCache = nil
        ttsHighlightLightColorCache = nil
        ttsHighlightDarkColorCache = nil
        widgetFontCache = nil
    }
}

// MARK: - 章节标题预设


extension ReadingSettings {

    /// 双页模式（loadDoublePageMode 0x10021f85c 返回类型确证；档位推断）。
    enum DoublePageMode: String, Codable, CaseIterable {
        case off
        case auto
        case always
    }
}

extension ReadingSettings {

    /// 章节标题预设（ChapterTitleSettingsView 消费域 + init(from:) 域还原；
    /// 原桥扩展自 Views/Reader/ChapterTitleSettingsView.swift 迁回本文件）。
    struct ChapterTitlePreset: Codable, Identifiable, Equatable {
        var id: UUID
        var name: String
        var template: String
        var darkTemplate: String?
        var height: CGFloat
        var useCustomFont: Bool
        var lightConfig: ChapterTitleConfig?
        var darkConfig: ChapterTitleConfig?

        init(
            id: UUID, name: String, template: String, darkTemplate: String?,
            height: CGFloat, useCustomFont: Bool,
            lightConfig: ChapterTitleConfig?, darkConfig: ChapterTitleConfig?
        ) {
            self.id = id
            self.name = name
            self.template = template
            self.darkTemplate = darkTemplate
            self.height = height
            self.useCustomFont = useCustomFont
            self.lightConfig = lightConfig
            self.darkConfig = darkConfig
        }

        /// 伪代码 0x10021929c（L871-885）：UUID id 解码失败 → 新建 UUID；
        /// name/template decode，darkTemplate decodeIfPresent；height 缺省
        /// 120.0（0x405E000000000000 确证）；useCustomFont 缺省 false；
        /// 亮/暗档 decodeIfPresent 缺省回退（块尾 v86 拷贝域）。
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = (try? container.decode(UUID.self, forKey: .id)) ?? UUID()
            name = try container.decode(String.self, forKey: .name)
            template = try container.decode(String.self, forKey: .template)
            darkTemplate = try container.decodeIfPresent(
                String.self, forKey: .darkTemplate)
            height = try container.decodeIfPresent(
                CGFloat.self, forKey: .height) ?? 120.0
            useCustomFont = try container.decodeIfPresent(
                Bool.self, forKey: .useCustomFont) ?? false
            lightConfig = try container.decodeIfPresent(
                ChapterTitleConfig.self, forKey: .lightConfig)
            darkConfig = try container.decodeIfPresent(
                ChapterTitleConfig.self, forKey: .darkConfig)
        }

        enum CodingKeys: String, CodingKey {
            case id
            case name
            case template
            case darkTemplate
            case height
            case useCustomFont
            case lightConfig
            case darkConfig
        }

        /// 内置预设（builtin 判定域确证；集合内容待真机对照）。
        static let builtIns: [ChapterTitlePreset] = [
            ChapterTitlePreset(
                id: UUID(), name: "经典", template: "<div>{{chapterNumber}} {{chapterName}}</div>",
                darkTemplate: nil, height: 120, useCustomFont: false,
                lightConfig: nil, darkConfig: nil),
            ChapterTitlePreset(
                id: UUID(), name: "居中", template: "<div class='center'>{{chapterName}}</div>",
                darkTemplate: nil, height: 120, useCustomFont: false,
                lightConfig: nil, darkConfig: nil),
        ]
    }
}

// MARK: - Color hex 桥

extension Color {

    /// 伪代码 0x100211b5c（L1815-1837）：hex 解析（trim 非字母数字 +
    /// NSScanner scanHexLongLong 确证；8/6/3 位域；3 位短格式 ×17 展开；
    /// 非法回退近黑 1/255）。原桥 leaflowColor 依赖本初始化器。
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(
            in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat
        switch cleaned.count {
        case 8:  // AARRGGBB（BYTE2 域确证：取 16-23 位红通道，透明度舍弃）
            red = CGFloat((value >> 16) & 0xFF) / 255.0
            green = CGFloat((value >> 8) & 0xFF) / 255.0
            blue = CGFloat(value & 0xFF) / 255.0
        case 6:
            red = CGFloat((value >> 16) & 0xFF) / 255.0
            green = CGFloat((value >> 8) & 0xFF) / 255.0
            blue = CGFloat(value & 0xFF) / 255.0
        case 3:
            red = CGFloat((value >> 8) & 0xF) * 17.0 / 255.0
            green = CGFloat((value >> 4) & 0xF) * 17.0 / 255.0
            blue = CGFloat(value & 0xF) * 17.0 / 255.0
        default:
            red = 1.0 / 255.0
            green = 1.0 / 255.0
            blue = 1.0 / 255.0
        }
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: 1)
    }

    /// 伪代码 0x100212000（L1839-1847）：UIColor 桥 → CGColor RGBA 分量 →
    /// "#RRGGBB"（块体与 preferredReaderSystemUIFont 域交错，按语义还原）。
    func toHex() -> String {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        UIColor(self).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return String(
            format: "#%02X%02X%02X",
            Int(round(red * 255)), Int(round(green * 255)), Int(round(blue * 255)))
    }
}
