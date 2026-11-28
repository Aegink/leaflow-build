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
    /// 页面模式（PageMode 档——ReaderDoublePagePolicy 消费域确证，
    /// wave-16 补成员；默认 horizontal）。
    var pageMode: PageMode = .horizontal
    var fontName: String = "System"
    var bottomToolbarStyle: ReaderBottomToolbarStyle = .minimal
    var screenAwake: ScreenAwakeOption = .system {
        didSet {
            if screenAwake != oldValue, screenAwakeApplicationActive { applyScreenAwakeSetting() }
        }
    }
    var searchMode: SearchMode = .all
    var exploreRanking: ExploreSectionRankingMode = .defaultOrder
    var exploreCacheTTL: ExploreCacheTTLOption = .thirtyMinutes

    /// 伪代码 0x10021f7bc（L158）：UserDefaults 布尔初始化
    /// （键名域与相邻 load* 块字面量交错，回退键推断）。
    var needsRepagination = false

    /// 字重原始值（sub_100213AB0 读取域；UIFont.Weight 阈值链消费）。
    /// 原版保存fontWeight，并以UIFontWeightMedium阈值投影isBold。
    var fontWeight: UIFont.Weight = .regular {
        didSet {
            invalidateTypographyCaches()
            typographyRevision += 1
        }
    }

    /// 伪代码 0x100213b80（L196）：写路径清排版缓存（Dictionary.removeAll 域）
    /// + 修订计数递增（offset 46）。
    var isBold: Bool {
        get { fontWeight.rawValue >= UIFont.Weight.medium.rawValue }
        set {
            if newValue && !isBold { fontWeight = .medium }
            else if !newValue && isBold { fontWeight = .regular }
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
    var textUnderlineEnabled = false
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

    /// 段评浮层呈现态（ReaderSettingsView Binding 消费域确证，
    /// wave-16 补成员；默认模态——还原推断）。
    var paragraphCommentBrowser: ParagraphCommentBrowserPresentation = .modal

    /// 自定义章节标题预设（ChapterTitleSettingsView 编辑域确证，
    /// wave-16 补成员）。
    var customChapterTitlePresets: [ChapterTitlePreset] = []

    // MARK: 非持久化缓存域（伪代码偏移语义映射）

    /// 编译规则缓存（offset 400，0x100216b40 写回域）。
    var compiledRulesCache: [CompiledHighlightRule]?
    /// 布局档编译缓存（签名键控，0x1002171a8 域）。
    var compiledLayoutRulesBySignature: [Int: [CompiledHighlightRule]] = [:]
    /// 布局签名与变化计数（offsets 368/376/384/392，0x1002176ec 域）。
    var lastHighlightLayoutSignature: Int = 0
    var appearanceChangeCount: Int = 0
    var layoutChangeCount: Int = 0
    var pendingHighlightRebuild: Bool = false
    /// 排版缓存修订计数（isBold.setter offset 46 域）。
    var typographyRevision: Int = 0
    /// 亮/暗 TTS 高亮色缓存（offsets 272/280，0x100215484 域）。
    var ttsHighlightLightColorCache: UIColor?
    var ttsHighlightDarkColorCache: UIColor?
    /// 正文色缓存（offset 27*8，0x1002155d4 域）。
    var textUIColorCache: UIColor?
    /// 背景图缓存（offsets 39/40/41，0x100215894 域）。
    var cachedBackgroundImage: UIImage?
    var cachedBackgroundFilename: String?
    /// Widget 度量缓存（offsets 1056-1081，0x100221e18 域）。
    var widgetMetrics: ReaderWidgetLayoutMetrics = ReaderWidgetLayoutMetrics(
        pageBounds: .zero, windowSafeAreaFrame: .zero, userInterfaceIdiom: .phone)
    /// Widget 字体缓存（offset 1136 数组域，0x100222f5c）。
    var widgetFontCache: UIFont?
    /// 挂起保存标志与防抖任务（flushPendingSave implicit closure #36 in init 域）。
    var hasPendingSave: Bool = false
    var pendingSaveTask: DispatchWorkItem?

    @ObservationIgnored var persistenceDefaults: UserDefaults = .standard
    @ObservationIgnored var persistedValues: [String: Any]?
    @ObservationIgnored var screenAwakeExpirationTask: Task<Void, Never>?
    @ObservationIgnored var screenAwakeApplicationActive = false
    @ObservationIgnored var screenAwakeGeneration = 0
    @ObservationIgnored var setScreenIdleTimerDisabled: (Bool) -> Void = { UIApplication.shared.isIdleTimerDisabled = $0 }
    @ObservationIgnored var waitForScreenAwakeExpiration: (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    var cachedLayout: ReaderLayoutResult?

    init(defaults: UserDefaults = .standard) {
        persistenceDefaults = defaults
        needsRepagination = defaults.bool(forKey: "readerNeedsRepagination")
    }

    // MARK: 缓存失效域

    /// 排版缓存失效（isBold.setter / applyLayoutTemplate 消费域；
    /// Dictionary.removeAll 域语义）。
    func invalidateTypographyCaches() {
        textUIColorCache = nil
        ttsHighlightLightColorCache = nil
        ttsHighlightDarkColorCache = nil
        widgetFontCache = nil
    }

    /// invalidateTypographyCachesBridge（ReaderViewModel+WebViewVerticalScroll
    /// 消费域确证——私有缓存失效域的跨域桥，wave-16）。
    func invalidateTypographyCachesBridge() {
        invalidateTypographyCaches()
    }
}
