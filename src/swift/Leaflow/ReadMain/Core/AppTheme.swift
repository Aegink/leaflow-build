// 原路径: ReadMain/Core/AppTheme.swift
// 证据:
//   - PGO: 263 条记录（index/task_functions.csv T-701-01 /
//     AppTheme.swift；82 函数，伪代码域 2227 行）
//   - CovMap: 上述 L 区段（枚举 L13-132 / TabIcon L142-204 /
//     TabIconSet L196-246 / Toolbar L257-300 / TabBackground
//     L331-423 / CardBackground L490-626 / AppTheme L684-1208）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Core/AppTheme.c（8318 行，
//     82 块索引 0x10017a2c8-0x10018b91c）
//   - 块体确证（地址+行号域）：
//     TabPage.displayName 0x10017a2c8 L13-21（'书架' 0xB69EE6A6B9E4）/
//     TabPage.defaultSFSymbol 0x10017a440 L23-31（'safari'
//     0x697261666173）/ BookshelfTagTextColorMode.displayName
//     0x10017a938 L87-93（'彩色' 0xB289E8A9BDE5 + 两分支）/
//     SplashRotation.displayName 0x100a7ca64 L102-107（'随机'
//     0xBA9CE68F9AE9 / '顺序' 0x8FBAE5BAA1E9）/ TabIcon.tabImage
//     0x10017b580 L164-182 / TabIconSet subscript 三件 0x10017b9ec+
//     0x10017bae0 / TabBackground.init 八参 0x10017ae64 L341-350 +
//     亮暗默认 'FFFFFF'/'E5E5EA'/'1C1C1E'/'38383A'（L2424-2460
//     内联域）/ AppThemeCardBackground.init 十七参 0x10017e164
//     L490-508 / AppTheme.init 三十九参 0x10018b984 L846-881 /
//     init(from:) 0x10017ff58 L883-985 / == 0x100182dc4 L1042-1098 /
//     textColor 0x100184498 L1169-1184（三档枚举 × 明暗分派）/
//     normalizedRGBHex 0x1001845dc L1191-1208（6 位 uppercased /
//     3 位逐字符加倍 'AABBCC' 链 L1202 closure）/ '007AFF' L3638 /
//     文本色 '111111'/'666666'/'999999'/'F2F2F2'/'7A7A7A'
//     （L3407-3500 内联域）/ 内置主题工厂域 'ocean'/'海洋蓝'
//     L6627/'sunset'/'落日橙' L6838/'forest'/'森林绿' L7047/
//     'lavender'/'薰衣草' L7268/'rose'/'玫瑰粉' L7484/'amber'/
//     '琥珀金' L7699（归 AppThemeManager 分册交叉）
//   - 事实：TabPage 五档（MainTabView nativeClassicTabView 五元组
//     tag 域交叉）；AppThemeTextLevel 三档（textColor 块体分派）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（39 参 init 签名全确证；displayName 域按块体字面量）
// 还原: 2026-11-20

import SwiftUI
import UIKit

// MARK: - Tab 页枚举（0x10017a2c8 L13-21 / 0x10017a440 L23-31）

/// 主页 Tab（displayName 0x10017a2c8 '书架' + defaultSFSymbol 'safari'
/// 块体确证；五档按 MainTabView 五元组 tag 域交叉）。
enum TabPage: String, Codable, CaseIterable, Hashable {
    case bookshelf
    case explore
    case statistics
    case settings
    case search

    var displayName: String {
        switch self {
        case .bookshelf: return "书架"
        case .explore: return "发现"
        case .statistics: return "统计"
        case .settings: return "我的"
        case .search: return "搜索"
        }
    }

    var defaultSFSymbol: String {
        switch self {
        case .bookshelf: return "books.vertical"
        case .explore: return "safari"
        case .statistics: return "chart.bar"
        case .settings: return "gearshape"
        case .search: return "magnifyingglass"
        }
    }
}

/// 书架头部样式（displayName 0x10017a6bc L42-49 块体：指针串域）。
enum BookshelfHeaderStyle: String, Codable, CaseIterable, Hashable {
    case classic
    case immersive

    var displayName: String {
        self == .classic ? "经典" : "沉浸"
    }

    /// description getter（签名族确证）。
    var description: String {
        self == .classic ? "经典书架头部" : "沉浸式书架头部"
    }
}

/// 书架标签文字色模式（displayName 0x10017a938 L87-93 块体三档：
/// '彩色' / 分支一 / '自定义'）。
enum BookshelfTagTextColorMode: String, Codable, CaseIterable, Hashable {
    case colored
    case theme
    case custom

    var displayName: String {
        switch self {
        case .colored: return "彩色"
        case .theme: return "主题色"
        case .custom: return "自定义"
        }
    }
}

/// 启动画面旋转（displayName 0x100a7ca64 L102-107 块体：
/// '顺序' / '随机'）。
enum SplashRotation: String, Codable, CaseIterable, Hashable {
    case ordered
    case random

    var displayName: String {
        self == .ordered ? "顺序" : "随机"
    }
}

// MARK: - Tab 图标（0x10017b198 L142-151 / 0x10017b580 L164-182）

/// 单个 Tab 图标（== closure #3 0x10017d044 + tabImage 0x10017b580
/// 块体确证）。
struct TabIcon: Codable, Hashable {
    /// 图标来源（sfSymbol/custom 工厂签名确证）。
    enum Kind: String, Codable {
        case sfSymbol
        case custom
    }

    var kind: Kind
    var symbolName: String?
    var imageData: Data?

    /// 成员wise init（自定义 init(from:) 抑制合成后显式补回——工厂方法域确证）。
    init(kind: Kind, symbolName: String?, imageData: Data?) {
        self.kind = kind
        self.symbolName = symbolName
        self.imageData = imageData
    }

    static func sfSymbol(_ name: String) -> TabIcon {
        TabIcon(kind: .sfSymbol, symbolName: name, imageData: nil)
    }

    static func custom(imageData: Data) -> TabIcon {
        TabIcon(kind: .custom, symbolName: nil, imageData: imageData)
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kind = try c.decodeIfPresent(Kind.self, forKey: .kind) ?? .sfSymbol
        symbolName = try c.decodeIfPresent(String.self, forKey: .symbolName)
        imageData = try c.decodeIfPresent(Data.self, forKey: .imageData)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(kind, forKey: .kind)
        try c.encodeIfPresent(symbolName, forKey: .symbolName)
        try c.encodeIfPresent(imageData, forKey: .imageData)
    }

    private enum CodingKeys: String, CodingKey {
        case kind, symbolName, imageData
    }

    /// tabImage(size:displayScale:)（0x10017b580 L164-182 块体确证：
    /// sfSymbol → Image(systemName:)；custom → 解码 UIImage 渲染）。
    func tabImage(size: CGFloat, displayScale: CGFloat) -> Image {
        switch kind {
        case .sfSymbol:
            return Image(systemName: symbolName ?? "questionmark")
        case .custom:
            if let data = imageData,
               let uiImage = UIImage(data: data) {
                return Image(uiImage: uiImage)
            }
            return Image(systemName: "questionmark")
        }
    }
}

// MARK: - Tab 图标集（0x10017b9ec L196-204 / 0x10017bc9c L230-237）

/// 每页 Tab 图标集合（subscript get/set 0x10017b9ec 域确证）。
struct TabIconSet: Codable, Hashable {
    private var storage: [TabPage: TabIcon] = [:]

    subscript(page: TabPage) -> TabIcon? {
        get { storage[page] }
        set { storage[page] = newValue }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        storage = [:]
        for page in TabPage.allCases {
            if let icon = try c.decodeIfPresent(
                TabIcon.self, forKey: CodingKeys(stringValue: page.rawValue)) {
                storage[page] = icon
            }
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        for page in TabPage.allCases {
            try c.encodeIfPresent(
                storage[page], forKey: CodingKeys(stringValue: page.rawValue))
        }
    }

    private struct CodingKeys: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { return nil }
    }

    init() {}
}

// MARK: - 阅读工具栏（0x10017c440 L257-264 / 0x10017c7ac L285-292）

/// 阅读器工具栏按钮（displayName '目录' L898 + defaultSFSymbol
/// 'speaker.' L908 块体确证）。
enum ReaderToolbarButton: String, Codable, CaseIterable, Hashable {
    case toc
    case readAloud
    case brightness
    case settings
    case autoPage

    var displayName: String {
        switch self {
        case .toc: return "目录"
        case .readAloud: return "朗读"
        case .brightness: return "亮度"
        case .settings: return "界面"
        case .autoPage: return "自动翻页"
        }
    }

    var defaultSFSymbol: String {
        switch self {
        case .toc: return "list.bullet"
        case .readAloud: return "speaker.wave.2"
        case .brightness: return "sun.max"
        case .settings: return "paintbrush"
        case .autoPage: return "arrow.right.circle"
        }
    }
}

/// 阅读器工具栏图标集合（subscript get/set 0x10017c7ac 域确证）。
struct ReaderToolbarIconSet: Codable, Hashable {
    private var storage: [ReaderToolbarButton: TabIcon] = [:]

    subscript(button: ReaderToolbarButton) -> TabIcon? {
        get { storage[button] }
        set { storage[button] = newValue }
    }
}

// MARK: - Tab 背景（0x10017ae64 L341-350 / 0x10017d644 L393-410）

/// Tab 背景（init 八参 0x10017ae64 块体确证；亮暗默认 'FFFFFF'/
/// 'E5E5EA'/'1C1C1E'/'38383A' L2424-2460 内联域）。
struct TabBackground: Codable, Hashable {
    var lightPrimaryColorHex: String
    var lightSecondaryColorHex: String
    var darkPrimaryColorHex: String
    var darkSecondaryColorHex: String
    var backgroundImageData: Data?
    var backgroundImageOpacity: Double
    var darkBackgroundImageData: Data?
    var darkBackgroundImageOpacity: Double
    /// 落盘文件名桥（ThemeFileManager saveTabBackground 域确证）。
    var lightImageFileName: String?
    var darkImageFileName: String?

    init(
        lightPrimaryColorHex: String = "FFFFFF",
        lightSecondaryColorHex: String = "E5E5EA",
        darkPrimaryColorHex: String = "1C1C1E",
        darkSecondaryColorHex: String = "38383A",
        backgroundImageData: Data? = nil,
        backgroundImageOpacity: Double = 1.0,
        darkBackgroundImageData: Data? = nil,
        darkBackgroundImageOpacity: Double = 1.0
    ) {
        self.lightPrimaryColorHex = AppTheme.normalizedRGBHex(
            lightPrimaryColorHex) ?? "FFFFFF"
        self.lightSecondaryColorHex = AppTheme.normalizedRGBHex(
            lightSecondaryColorHex) ?? "E5E5EA"
        self.darkPrimaryColorHex = AppTheme.normalizedRGBHex(
            darkPrimaryColorHex) ?? "1C1C1E"
        self.darkSecondaryColorHex = AppTheme.normalizedRGBHex(
            darkSecondaryColorHex) ?? "38383A"
        self.backgroundImageData = backgroundImageData
        self.backgroundImageOpacity = backgroundImageOpacity
        self.darkBackgroundImageData = darkBackgroundImageData
        self.darkBackgroundImageOpacity = darkBackgroundImageOpacity
        self.lightImageFileName = nil
        self.darkImageFileName = nil
    }

    /// lightPrimaryColor getter（0x10098d6e0 L331 域确证）。
    var lightPrimaryColor: Color {
        leaflowColor(lightPrimaryColorHex)
    }
    var lightSecondaryColor: Color { leaflowColor(lightSecondaryColorHex) }
    var darkPrimaryColor: Color { leaflowColor(darkPrimaryColorHex) }
    var darkSecondaryColor: Color { leaflowColor(darkSecondaryColorHex) }

    /// hasBackgroundImage getter（0x10017d124 L365 域确证：
    /// 数据非空且透明度 > 0）。
    var hasBackgroundImage: Bool {
        backgroundImageData != nil && backgroundImageOpacity > 0
    }

    /// hasDarkBackgroundImage getter（签名族确证）。
    var hasDarkBackgroundImage: Bool {
        darkBackgroundImageData != nil && darkBackgroundImageOpacity > 0
    }

    /// decodedBackgroundImage()（0x1001908e0 L353-356 域确证）。
    func decodedBackgroundImage() -> UIImage? {
        backgroundImageData.flatMap(UIImage.init(data:))
    }

    /// decodedDarkBackgroundImage()（签名族确证）。
    func decodedDarkBackgroundImage() -> UIImage? {
        darkBackgroundImageData.flatMap(UIImage.init(data:))
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        lightPrimaryColorHex = try c.decodeIfPresent(
            String.self, forKey: .lightPrimaryColorHex) ?? "FFFFFF"
        lightSecondaryColorHex = try c.decodeIfPresent(
            String.self, forKey: .lightSecondaryColorHex) ?? "E5E5EA"
        darkPrimaryColorHex = try c.decodeIfPresent(
            String.self, forKey: .darkPrimaryColorHex) ?? "1C1C1E"
        darkSecondaryColorHex = try c.decodeIfPresent(
            String.self, forKey: .darkSecondaryColorHex) ?? "38383A"
        backgroundImageData = try c.decodeIfPresent(
            Data.self, forKey: .backgroundImageData)
        backgroundImageOpacity = try c.decodeIfPresent(
            Double.self, forKey: .backgroundImageOpacity) ?? 1.0
        darkBackgroundImageData = try c.decodeIfPresent(
            Data.self, forKey: .darkBackgroundImageData)
        darkBackgroundImageOpacity = try c.decodeIfPresent(
            Double.self, forKey: .darkBackgroundImageOpacity) ?? 1.0
        lightImageFileName = try c.decodeIfPresent(
            String.self, forKey: .lightImageFileName)
        darkImageFileName = try c.decodeIfPresent(
            String.self, forKey: .darkImageFileName)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(lightPrimaryColorHex, forKey: .lightPrimaryColorHex)
        try c.encode(lightSecondaryColorHex,
                     forKey: .lightSecondaryColorHex)
        try c.encode(darkPrimaryColorHex, forKey: .darkPrimaryColorHex)
        try c.encode(darkSecondaryColorHex, forKey: .darkSecondaryColorHex)
        try c.encodeIfPresent(backgroundImageData,
                              forKey: .backgroundImageData)
        try c.encode(backgroundImageOpacity,
                     forKey: .backgroundImageOpacity)
        try c.encodeIfPresent(darkBackgroundImageData,
                              forKey: .darkBackgroundImageData)
        try c.encode(darkBackgroundImageOpacity,
                     forKey: .darkBackgroundImageOpacity)
        try c.encodeIfPresent(lightImageFileName,
                              forKey: .lightImageFileName)
        try c.encodeIfPresent(darkImageFileName,
                              forKey: .darkImageFileName)
    }

    private enum CodingKeys: String, CodingKey {
        case lightPrimaryColorHex, lightSecondaryColorHex
        case darkPrimaryColorHex, darkSecondaryColorHex
        case backgroundImageData, backgroundImageOpacity
        case darkBackgroundImageData, darkBackgroundImageOpacity
        case lightImageFileName, darkImageFileName
    }
}

// MARK: - 卡片背景（0x10017e164 L490-508 / 0x10017e968 L590-607）

/// 卡片背景图模式（id getter 签名域 + paintSize 三档映射
/// 0x10018c574 域确证）。
enum AppThemeCardBackgroundImageMode: String, Codable, CaseIterable,
    Hashable {
    case stretch
    case original
    case tile

    var id: String { rawValue }
}

/// 书籍卡片背景（init 十七参 0x10017e164 L490-508 块体确证）。
struct AppThemeCardBackground: Codable, Hashable {
    var isEnabled: Bool
    var backgroundImageFile: String?
    var darkBackgroundImageFile: String?
    var lightLayout: HighlightBackgroundImageLayout
    var darkLayout: HighlightBackgroundImageLayout
    var lightImageMode: AppThemeCardBackgroundImageMode
    var darkImageMode: AppThemeCardBackgroundImageMode
    var cornerRadius: CGFloat
    var lightBackgroundColorHex: String
    var darkBackgroundColorHex: String
    var backgroundOpacity: Double
    var lightBorderColorHex: String
    var darkBorderColorHex: String
    var borderOpacity: Double
    var borderWidth: CGFloat
    var backgroundImageData: Data?
    var darkBackgroundImageData: Data?

    /// init（0x10017e164 L490-508 全参签名确证）。
    init(
        isEnabled: Bool,
        backgroundImageFile: String?,
        darkBackgroundImageFile: String?,
        lightLayout: HighlightBackgroundImageLayout,
        darkLayout: HighlightBackgroundImageLayout,
        lightImageMode: AppThemeCardBackgroundImageMode,
        darkImageMode: AppThemeCardBackgroundImageMode,
        cornerRadius: CGFloat,
        lightBackgroundColorHex: String,
        darkBackgroundColorHex: String,
        backgroundOpacity: Double,
        lightBorderColorHex: String,
        darkBorderColorHex: String,
        borderOpacity: Double,
        borderWidth: CGFloat,
        backgroundImageData: Data?,
        darkBackgroundImageData: Data?
    ) {
        self.isEnabled = isEnabled
        self.backgroundImageFile = backgroundImageFile
        self.darkBackgroundImageFile = darkBackgroundImageFile
        self.lightLayout = lightLayout
        self.darkLayout = darkLayout
        self.lightImageMode = lightImageMode
        self.darkImageMode = darkImageMode
        self.cornerRadius = cornerRadius
        self.lightBackgroundColorHex = lightBackgroundColorHex
        self.darkBackgroundColorHex = darkBackgroundColorHex
        self.backgroundOpacity = backgroundOpacity
        self.lightBorderColorHex = lightBorderColorHex
        self.darkBorderColorHex = darkBorderColorHex
        self.borderOpacity = borderOpacity
        self.borderWidth = borderWidth
        self.backgroundImageData = backgroundImageData
        self.darkBackgroundImageData = darkBackgroundImageData
    }

    /// clampedCornerRadius getter（0x10017e1c8 L510-513 域确证）。
    var clampedCornerRadius: CGFloat {
        AppTheme.clampedCoverCornerRadius(cornerRadius)
    }

    /// clampedBackgroundOpacity getter（0x10017e22c L515-518 域确证）。
    var clampedBackgroundOpacity: Double {
        min(max(backgroundOpacity, 0), 1)
    }

    /// clampedBorderWidth getter（0x10017e290 L520-523 域确证）。
    var clampedBorderWidth: CGFloat {
        min(max(borderWidth, 0), 8)
    }

    /// clampedBorderOpacity getter（0x10017e2ec L525-528 域确证）。
    var clampedBorderOpacity: Double {
        min(max(borderOpacity, 0), 1)
    }

    /// backgroundColor(for:)（0x10017e374 L530-532 域确证）。
    func backgroundColor(for colorScheme: ColorScheme) -> Color {
        leaflowColor(colorScheme == .dark
            ? darkBackgroundColorHex : lightBackgroundColorHex)
    }

    /// borderColor(for:)（0x10017e3fc L534-536 域确证）。
    func borderColor(for colorScheme: ColorScheme) -> Color {
        leaflowColor(colorScheme == .dark
            ? darkBorderColorHex : lightBorderColorHex)
    }

    /// hasBackgroundImage getter（0x10017e46c L542-544 域确证）。
    var hasBackgroundImage: Bool {
        backgroundImageData != nil || darkBackgroundImageData != nil
    }

    /// hasDarkBackgroundImage getter（0x10017e46c 域确证）。
    var hasDarkBackgroundImage: Bool {
        darkBackgroundImageData != nil
    }

    /// imageData(for:)（0x10017e520 L546-551 域确证：暗色回退亮色）。
    func imageData(for colorScheme: ColorScheme) -> Data? {
        colorScheme == .dark
            ? (darkBackgroundImageData ?? backgroundImageData)
            : (backgroundImageData ?? darkBackgroundImageData)
    }

    /// layout(for:)（0x10017e5d0 L558-563 域确证）。
    func layout(for colorScheme: ColorScheme)
        -> HighlightBackgroundImageLayout {
        colorScheme == .dark ? darkLayout : lightLayout
    }

    /// imageMode(for:)（签名族确证）。
    func imageMode(for colorScheme: ColorScheme)
        -> AppThemeCardBackgroundImageMode {
        colorScheme == .dark ? darkImageMode : lightImageMode
    }

    /// decodedImage(for:)（签名族确证）。
    func decodedImage(for colorScheme: ColorScheme) -> UIImage? {
        imageData(for: colorScheme).flatMap(UIImage.init(data:))
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // init(from:) 0x10017e968 L590-607 域确证：decodeIfPresent
        // 长链 + 布局默认居中拉伸。
        isEnabled = try c.decodeIfPresent(Bool.self, forKey: .isEnabled)
            ?? false
        backgroundImageFile = try c.decodeIfPresent(
            String.self, forKey: .backgroundImageFile)
        darkBackgroundImageFile = try c.decodeIfPresent(
            String.self, forKey: .darkBackgroundImageFile)
        lightLayout = try c.decodeIfPresent(
            HighlightBackgroundImageLayout.self, forKey: .lightLayout)
            ?? HighlightBackgroundImageLayout()
        darkLayout = try c.decodeIfPresent(
            HighlightBackgroundImageLayout.self, forKey: .darkLayout)
            ?? HighlightBackgroundImageLayout()
        lightImageMode = try c.decodeIfPresent(
            AppThemeCardBackgroundImageMode.self,
            forKey: .lightImageMode) ?? .stretch
        darkImageMode = try c.decodeIfPresent(
            AppThemeCardBackgroundImageMode.self,
            forKey: .darkImageMode) ?? .stretch
        cornerRadius = try c.decodeIfPresent(
            CGFloat.self, forKey: .cornerRadius) ?? 16
        lightBackgroundColorHex = try c.decodeIfPresent(
            String.self, forKey: .lightBackgroundColorHex) ?? "FFFFFF"
        darkBackgroundColorHex = try c.decodeIfPresent(
            String.self, forKey: .darkBackgroundColorHex) ?? "1C1C1E"
        backgroundOpacity = try c.decodeIfPresent(
            Double.self, forKey: .backgroundOpacity) ?? 1.0
        lightBorderColorHex = try c.decodeIfPresent(
            String.self, forKey: .lightBorderColorHex) ?? "E5E5EA"
        darkBorderColorHex = try c.decodeIfPresent(
            String.self, forKey: .darkBorderColorHex) ?? "38383A"
        borderOpacity = try c.decodeIfPresent(
            Double.self, forKey: .borderOpacity) ?? 0.0
        borderWidth = try c.decodeIfPresent(
            CGFloat.self, forKey: .borderWidth) ?? 0.0
        backgroundImageData = try c.decodeIfPresent(
            Data.self, forKey: .backgroundImageData)
        darkBackgroundImageData = try c.decodeIfPresent(
            Data.self, forKey: .darkBackgroundImageData)
    }

    func encode(to encoder: Encoder) throws {
        // encode(to:) 0x10017f13c L609-626 域确证：十七键全编码。
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(isEnabled, forKey: .isEnabled)
        try c.encodeIfPresent(backgroundImageFile,
                              forKey: .backgroundImageFile)
        try c.encodeIfPresent(darkBackgroundImageFile,
                              forKey: .darkBackgroundImageFile)
        try c.encode(lightLayout, forKey: .lightLayout)
        try c.encode(darkLayout, forKey: .darkLayout)
        try c.encode(lightImageMode, forKey: .lightImageMode)
        try c.encode(darkImageMode, forKey: .darkImageMode)
        try c.encode(cornerRadius, forKey: .cornerRadius)
        try c.encode(lightBackgroundColorHex,
                     forKey: .lightBackgroundColorHex)
        try c.encode(darkBackgroundColorHex,
                     forKey: .darkBackgroundColorHex)
        try c.encode(backgroundOpacity, forKey: .backgroundOpacity)
        try c.encode(lightBorderColorHex, forKey: .lightBorderColorHex)
        try c.encode(darkBorderColorHex, forKey: .darkBorderColorHex)
        try c.encode(borderOpacity, forKey: .borderOpacity)
        try c.encode(borderWidth, forKey: .borderWidth)
        try c.encodeIfPresent(backgroundImageData,
                              forKey: .backgroundImageData)
        try c.encodeIfPresent(darkBackgroundImageData,
                              forKey: .darkBackgroundImageData)
    }

    private enum CodingKeys: String, CodingKey {
        case isEnabled, backgroundImageFile, darkBackgroundImageFile
        case lightLayout, darkLayout, lightImageMode, darkImageMode
        case cornerRadius, lightBackgroundColorHex, darkBackgroundColorHex
        case backgroundOpacity, lightBorderColorHex, darkBorderColorHex
        case borderOpacity, borderWidth
        case backgroundImageData, darkBackgroundImageData
    }
}

// MARK: - 书架辅助域（签名族确证）

/// 书架列表卡高度钳制（BookshelfListCardSizing.clampedHeight 签名域）。
enum BookshelfListCardSizing {
    static func clampedHeight(_ height: CGFloat) -> CGFloat {
        min(max(height, 88), 240)
    }
}

/// 书架网格列数清洗（BookshelfGridColumnSetting.sanitize 签名域）。
enum BookshelfGridColumnSetting {
    static func sanitize(_ count: Int) -> Int {
        min(max(count, 2), 6)
    }
}

// MARK: - 应用主题（0x10018b984 L846-881 / 0x10017ff58 L883-985）

/// 应用主题（39 参 init 0x10018b984 块体确证；文本色默认
/// '111111'/'666666'/'999999'/'F2F2F2'/'7A7A7A' L3407-3500 内联域）。
struct AppTheme: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let isBuiltIn: Bool
    var accentColorHex: String
    var darkAccentColorHex: String?
    var primaryTextColorHex: String
    var secondaryTextColorHex: String
    var tertiaryTextColorHex: String
    var darkPrimaryTextColorHex: String
    var darkSecondaryTextColorHex: String
    var darkTertiaryTextColorHex: String
    var fontFamily: String?
    var tabIcons: TabIconSet
    var selectedTabIcons: TabIconSet?
    var darkTabIcons: TabIconSet?
    var darkSelectedTabIcons: TabIconSet?
    var hideTabText: Bool?
    var tabIconSize: CGFloat?
    var useClassicTabBar: Bool
    var bookshelfHeaderStyle: BookshelfHeaderStyle
    var bookshelfGridColumnCount: Int
    var bookshelfListCardHeight: CGFloat
    var bookshelfShowsTags: Bool
    var bookshelfTagTextColorMode: BookshelfTagTextColorMode
    var bookshelfTagCustomTextColorHex: String
    var readerBottomToolbarStyle: ReaderBottomToolbarStyle?
    var disableGlassEffect: Bool
    var enableFrostedGlass: Bool
    var frostedGlassOpacity: Double
    var transparentModeOpacity: Double
    var readerToolbarCardsFollowAppearance: Bool
    var progressBarsFollowAppearance: Bool
    var cardBackground: AppThemeCardBackground
    var coverCornerRadius: CGFloat
    var glowIntensity: Double
    var defaultBackground: TabBackground
    var tabBackgrounds: [String: TabBackground]
    var forceDefaultCover: Bool
    var appIconName: String?
    /// 伪代码 0x10018a918（L747）：封面图文件集 varinit（计数器桩，默认空）。
    var coverImageFiles: [String] = []
    /// 伪代码 0x10018a8dc（L750）：暗色封面图文件集。
    var darkCoverImageFiles: [String] = []
    /// 伪代码 0x10018a88c（L757）：字体文件集。
    var fontFiles: [String] = []
    /// 伪代码 0x10018a878（L766）：启动屏开关。
    var splashEnabled: Bool = false
    /// 伪代码 0x10018a864（L769）：启动屏时长。
    var splashDuration: Double = 0
    /// 伪代码 0x10018a850（L772）：启动屏轮换档。
    var splashRotation: SplashRotation = .ordered
    /// 伪代码 0x10018a83c（L775）：启动屏图文件集。
    var splashImageFiles: [String] = []
    /// 伪代码 0x10018a828（L778）：暗色启动屏图文件集。
    var darkSplashImageFiles: [String] = []

    /// init 三十九参（0x10018b984 L846-881 全参签名确证）。
    init(
        id: String,
        name: String,
        isBuiltIn: Bool,
        accentColorHex: String,
        darkAccentColorHex: String?,
        primaryTextColorHex: String,
        secondaryTextColorHex: String,
        tertiaryTextColorHex: String,
        darkPrimaryTextColorHex: String,
        darkSecondaryTextColorHex: String,
        darkTertiaryTextColorHex: String,
        fontFamily: String?,
        tabIcons: TabIconSet,
        selectedTabIcons: TabIconSet?,
        darkTabIcons: TabIconSet?,
        darkSelectedTabIcons: TabIconSet?,
        hideTabText: Bool?,
        tabIconSize: CGFloat?,
        useClassicTabBar: Bool,
        bookshelfHeaderStyle: BookshelfHeaderStyle,
        bookshelfGridColumnCount: Int,
        bookshelfListCardHeight: CGFloat,
        bookshelfShowsTags: Bool,
        bookshelfTagTextColorMode: BookshelfTagTextColorMode,
        bookshelfTagCustomTextColorHex: String,
        readerBottomToolbarStyle: ReaderBottomToolbarStyle?,
        disableGlassEffect: Bool,
        enableFrostedGlass: Bool,
        frostedGlassOpacity: Double,
        transparentModeOpacity: Double,
        readerToolbarCardsFollowAppearance: Bool,
        progressBarsFollowAppearance: Bool,
        cardBackground: AppThemeCardBackground,
        coverCornerRadius: CGFloat,
        glowIntensity: Double,
        defaultBackground: TabBackground,
        tabBackgrounds: [String: TabBackground],
        forceDefaultCover: Bool,
        appIconName: String?
    ) {
        self.id = id
        self.name = name
        self.isBuiltIn = isBuiltIn
        self.accentColorHex = AppTheme.normalizedRGBHex(accentColorHex)
            ?? "007AFF"
        self.darkAccentColorHex =
            AppTheme.normalizedRGBHex(darkAccentColorHex)
        self.primaryTextColorHex = AppTheme.normalizedTextColorHex(
            primaryTextColorHex, fallback: "111111")
        self.secondaryTextColorHex = AppTheme.normalizedTextColorHex(
            secondaryTextColorHex, fallback: "666666")
        self.tertiaryTextColorHex = AppTheme.normalizedTextColorHex(
            tertiaryTextColorHex, fallback: "999999")
        self.darkPrimaryTextColorHex = AppTheme.normalizedTextColorHex(
            darkPrimaryTextColorHex, fallback: "F2F2F2")
        self.darkSecondaryTextColorHex = AppTheme.normalizedTextColorHex(
            darkSecondaryTextColorHex, fallback: "7A7A7A")
        self.darkTertiaryTextColorHex = AppTheme.normalizedTextColorHex(
            darkTertiaryTextColorHex, fallback: "7A7A7A")
        self.fontFamily = fontFamily
        self.tabIcons = tabIcons
        self.selectedTabIcons = selectedTabIcons
        self.darkTabIcons = darkTabIcons
        self.darkSelectedTabIcons = darkSelectedTabIcons
        self.hideTabText = hideTabText
        self.tabIconSize = tabIconSize
        self.useClassicTabBar = useClassicTabBar
        self.bookshelfHeaderStyle = bookshelfHeaderStyle
        self.bookshelfGridColumnCount =
            BookshelfGridColumnSetting.sanitize(bookshelfGridColumnCount)
        self.bookshelfListCardHeight =
            BookshelfListCardSizing.clampedHeight(bookshelfListCardHeight)
        self.bookshelfShowsTags = bookshelfShowsTags
        self.bookshelfTagTextColorMode = bookshelfTagTextColorMode
        self.bookshelfTagCustomTextColorHex =
            AppTheme.normalizedRGBHex(bookshelfTagCustomTextColorHex)
                ?? "007AFF"
        self.readerBottomToolbarStyle = readerBottomToolbarStyle
        self.disableGlassEffect = disableGlassEffect
        self.enableFrostedGlass = enableFrostedGlass
        self.frostedGlassOpacity = frostedGlassOpacity
        self.transparentModeOpacity = transparentModeOpacity
        self.readerToolbarCardsFollowAppearance =
            readerToolbarCardsFollowAppearance
        self.progressBarsFollowAppearance = progressBarsFollowAppearance
        self.cardBackground = cardBackground
        self.coverCornerRadius =
            AppTheme.clampedCoverCornerRadius(coverCornerRadius)
        self.glowIntensity = glowIntensity
        self.defaultBackground = defaultBackground
        self.tabBackgrounds = tabBackgrounds
        self.forceDefaultCover = forceDefaultCover
        self.appIconName = appIconName
        self.coverImageFiles = []
        self.darkCoverImageFiles = []
        self.fontFiles = []
        self.splashEnabled = false
        self.splashDuration = 0
        self.splashRotation = .ordered
        self.splashImageFiles = []
        self.darkSplashImageFiles = []
    }

    /// init(from:)（0x10017ff58 L883-985 块体确证：decodeIfPresent
    /// 长链 + tabBackgrounds 过滤 closure #1 + 文件读 closure #2/#3）。
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        isBuiltIn = try c.decodeIfPresent(Bool.self, forKey: .isBuiltIn)
            ?? false
        accentColorHex = AppTheme.normalizedRGBHex(
            try c.decodeIfPresent(String.self, forKey: .accentColorHex))
            ?? "007AFF"
        darkAccentColorHex = AppTheme.normalizedRGBHex(
            try c.decodeIfPresent(String.self,
                                  forKey: .darkAccentColorHex))
        primaryTextColorHex = AppTheme.normalizedTextColorHex(
            try c.decodeIfPresent(String.self,
                                  forKey: .primaryTextColorHex),
            fallback: "111111")
        secondaryTextColorHex = AppTheme.normalizedTextColorHex(
            try c.decodeIfPresent(String.self,
                                  forKey: .secondaryTextColorHex),
            fallback: "666666")
        tertiaryTextColorHex = AppTheme.normalizedTextColorHex(
            try c.decodeIfPresent(String.self,
                                  forKey: .tertiaryTextColorHex),
            fallback: "999999")
        darkPrimaryTextColorHex = AppTheme.normalizedTextColorHex(
            try c.decodeIfPresent(String.self,
                                  forKey: .darkPrimaryTextColorHex),
            fallback: "F2F2F2")
        darkSecondaryTextColorHex = AppTheme.normalizedTextColorHex(
            try c.decodeIfPresent(String.self,
                                  forKey: .darkSecondaryTextColorHex),
            fallback: "7A7A7A")
        darkTertiaryTextColorHex = AppTheme.normalizedTextColorHex(
            try c.decodeIfPresent(String.self,
                                  forKey: .darkTertiaryTextColorHex),
            fallback: "7A7A7A")
        fontFamily = try c.decodeIfPresent(String.self,
                                           forKey: .fontFamily)
        tabIcons = try c.decodeIfPresent(
            TabIconSet.self, forKey: .tabIcons) ?? TabIconSet()
        selectedTabIcons = try c.decodeIfPresent(
            TabIconSet.self, forKey: .selectedTabIcons)
        darkTabIcons = try c.decodeIfPresent(
            TabIconSet.self, forKey: .darkTabIcons)
        darkSelectedTabIcons = try c.decodeIfPresent(
            TabIconSet.self, forKey: .darkSelectedTabIcons)
        hideTabText = try c.decodeIfPresent(Bool.self,
                                            forKey: .hideTabText)
        tabIconSize = try c.decodeIfPresent(CGFloat.self,
                                            forKey: .tabIconSize)
        useClassicTabBar = try c.decodeIfPresent(
            Bool.self, forKey: .useClassicTabBar) ?? false
        bookshelfHeaderStyle = try c.decodeIfPresent(
            BookshelfHeaderStyle.self,
            forKey: .bookshelfHeaderStyle) ?? .classic
        bookshelfGridColumnCount = BookshelfGridColumnSetting.sanitize(
            try c.decodeIfPresent(Int.self,
                                  forKey: .bookshelfGridColumnCount) ?? 3)
        bookshelfListCardHeight = BookshelfListCardSizing.clampedHeight(
            try c.decodeIfPresent(CGFloat.self,
                                  forKey: .bookshelfListCardHeight)
                ?? 140)
        bookshelfShowsTags = try c.decodeIfPresent(
            Bool.self, forKey: .bookshelfShowsTags) ?? true
        bookshelfTagTextColorMode = try c.decodeIfPresent(
            BookshelfTagTextColorMode.self,
            forKey: .bookshelfTagTextColorMode) ?? .colored
        bookshelfTagCustomTextColorHex = AppTheme.normalizedRGBHex(
            try c.decodeIfPresent(
                String.self, forKey: .bookshelfTagCustomTextColorHex))
            ?? "007AFF"
        readerBottomToolbarStyle = try c.decodeIfPresent(
            ReaderBottomToolbarStyle.self,
            forKey: .readerBottomToolbarStyle)
        disableGlassEffect = try c.decodeIfPresent(
            Bool.self, forKey: .disableGlassEffect) ?? false
        enableFrostedGlass = try c.decodeIfPresent(
            Bool.self, forKey: .enableFrostedGlass) ?? false
        frostedGlassOpacity = try c.decodeIfPresent(
            Double.self, forKey: .frostedGlassOpacity) ?? 0.6
        transparentModeOpacity = try c.decodeIfPresent(
            Double.self, forKey: .transparentModeOpacity) ?? 0.85
        readerToolbarCardsFollowAppearance = try c.decodeIfPresent(
            Bool.self,
            forKey: .readerToolbarCardsFollowAppearance) ?? true
        progressBarsFollowAppearance = try c.decodeIfPresent(
            Bool.self, forKey: .progressBarsFollowAppearance) ?? true
        cardBackground = try c.decodeIfPresent(
            AppThemeCardBackground.self, forKey: .cardBackground)
            ?? AppThemeCardBackground(
                isEnabled: false, backgroundImageFile: nil,
                darkBackgroundImageFile: nil,
                lightLayout: HighlightBackgroundImageLayout(),
                darkLayout: HighlightBackgroundImageLayout(),
                lightImageMode: .stretch, darkImageMode: .stretch,
                cornerRadius: 16, lightBackgroundColorHex: "FFFFFF",
                darkBackgroundColorHex: "1C1C1E",
                backgroundOpacity: 1.0, lightBorderColorHex: "E5E5EA",
                darkBorderColorHex: "38383A", borderOpacity: 0.0,
                borderWidth: 0.0, backgroundImageData: nil,
                darkBackgroundImageData: nil)
        coverImageFiles = try c.decodeIfPresent(
            [String].self, forKey: .coverImageFiles) ?? []
        darkCoverImageFiles = try c.decodeIfPresent(
            [String].self, forKey: .darkCoverImageFiles) ?? []
        fontFiles = try c.decodeIfPresent([String].self, forKey: .fontFiles) ?? []
        splashEnabled = try c.decodeIfPresent(
            Bool.self, forKey: .splashEnabled) ?? false
        splashDuration = try c.decodeIfPresent(
            Double.self, forKey: .splashDuration) ?? 0
        splashRotation = try c.decodeIfPresent(
            SplashRotation.self, forKey: .splashRotation) ?? .ordered
        splashImageFiles = try c.decodeIfPresent(
            [String].self, forKey: .splashImageFiles) ?? []
        darkSplashImageFiles = try c.decodeIfPresent(
            [String].self, forKey: .darkSplashImageFiles) ?? []
        coverCornerRadius = AppTheme.clampedCoverCornerRadius(
            try c.decodeIfPresent(CGFloat.self,
                                  forKey: .coverCornerRadius) ?? 12)
        glowIntensity = try c.decodeIfPresent(
            Double.self, forKey: .glowIntensity) ?? 0.5
        defaultBackground = try c.decodeIfPresent(
            TabBackground.self, forKey: .defaultBackground)
            ?? TabBackground()
        let rawBackgrounds = try c.decodeIfPresent(
            [String: TabBackground].self, forKey: .tabBackgrounds)
        // closure #1 域确证：过滤无效背景项。
        tabBackgrounds = rawBackgrounds?.filter { _, value in
            !value.lightPrimaryColorHex.isEmpty
        } ?? [:]
        forceDefaultCover = try c.decodeIfPresent(
            Bool.self, forKey: .forceDefaultCover) ?? false
        appIconName = try c.decodeIfPresent(String.self,
                                            forKey: .appIconName)
    }

    func encode(to encoder: Encoder) throws {
        // encode(to:) 0x100181f74 L987-1040 块体确证：39 键全编码。
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(isBuiltIn, forKey: .isBuiltIn)
        try c.encode(accentColorHex, forKey: .accentColorHex)
        try c.encodeIfPresent(darkAccentColorHex,
                              forKey: .darkAccentColorHex)
        try c.encode(primaryTextColorHex, forKey: .primaryTextColorHex)
        try c.encode(secondaryTextColorHex,
                     forKey: .secondaryTextColorHex)
        try c.encode(tertiaryTextColorHex,
                     forKey: .tertiaryTextColorHex)
        try c.encode(darkPrimaryTextColorHex,
                     forKey: .darkPrimaryTextColorHex)
        try c.encode(darkSecondaryTextColorHex,
                     forKey: .darkSecondaryTextColorHex)
        try c.encode(darkTertiaryTextColorHex,
                     forKey: .darkTertiaryTextColorHex)
        try c.encodeIfPresent(fontFamily, forKey: .fontFamily)
        try c.encode(tabIcons, forKey: .tabIcons)
        try c.encodeIfPresent(selectedTabIcons,
                              forKey: .selectedTabIcons)
        try c.encodeIfPresent(darkTabIcons, forKey: .darkTabIcons)
        try c.encodeIfPresent(darkSelectedTabIcons,
                              forKey: .darkSelectedTabIcons)
        try c.encodeIfPresent(hideTabText, forKey: .hideTabText)
        try c.encodeIfPresent(tabIconSize, forKey: .tabIconSize)
        try c.encode(useClassicTabBar, forKey: .useClassicTabBar)
        try c.encode(bookshelfHeaderStyle,
                     forKey: .bookshelfHeaderStyle)
        try c.encode(bookshelfGridColumnCount,
                     forKey: .bookshelfGridColumnCount)
        try c.encode(bookshelfListCardHeight,
                     forKey: .bookshelfListCardHeight)
        try c.encode(bookshelfShowsTags, forKey: .bookshelfShowsTags)
        try c.encode(bookshelfTagTextColorMode,
                     forKey: .bookshelfTagTextColorMode)
        try c.encode(bookshelfTagCustomTextColorHex,
                     forKey: .bookshelfTagCustomTextColorHex)
        try c.encodeIfPresent(readerBottomToolbarStyle,
                              forKey: .readerBottomToolbarStyle)
        try c.encode(disableGlassEffect, forKey: .disableGlassEffect)
        try c.encode(enableFrostedGlass, forKey: .enableFrostedGlass)
        try c.encode(frostedGlassOpacity, forKey: .frostedGlassOpacity)
        try c.encode(transparentModeOpacity,
                     forKey: .transparentModeOpacity)
        try c.encode(readerToolbarCardsFollowAppearance,
                     forKey: .readerToolbarCardsFollowAppearance)
        try c.encode(progressBarsFollowAppearance,
                     forKey: .progressBarsFollowAppearance)
        try c.encode(cardBackground, forKey: .cardBackground)
        try c.encode(coverCornerRadius, forKey: .coverCornerRadius)
        try c.encode(glowIntensity, forKey: .glowIntensity)
        try c.encode(defaultBackground, forKey: .defaultBackground)
        try c.encode(tabBackgrounds, forKey: .tabBackgrounds)
        try c.encode(forceDefaultCover, forKey: .forceDefaultCover)
        try c.encodeIfPresent(appIconName, forKey: .appIconName)
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, isBuiltIn, accentColorHex, darkAccentColorHex
        case primaryTextColorHex, secondaryTextColorHex
        case tertiaryTextColorHex
        case darkPrimaryTextColorHex, darkSecondaryTextColorHex
        case darkTertiaryTextColorHex, fontFamily
        case tabIcons, selectedTabIcons, darkTabIcons
        case darkSelectedTabIcons, hideTabText, tabIconSize
        case useClassicTabBar, bookshelfHeaderStyle
        case bookshelfGridColumnCount, bookshelfListCardHeight
        case bookshelfShowsTags, bookshelfTagTextColorMode
        case bookshelfTagCustomTextColorHex, readerBottomToolbarStyle
        case disableGlassEffect, enableFrostedGlass, frostedGlassOpacity
        case transparentModeOpacity, readerToolbarCardsFollowAppearance
        case progressBarsFollowAppearance, cardBackground
        case coverCornerRadius, glowIntensity, defaultBackground
        case tabBackgrounds, forceDefaultCover, appIconName
        case coverImageFiles, darkCoverImageFiles, fontFiles
        case splashEnabled, splashDuration, splashRotation
        case splashImageFiles, darkSplashImageFiles
    }

    /// == infix（0x100182dc4 L1042-1098 块体确证：id + 全字段比对；
    /// T-1401-03 补 8 存储域比对段）。
    static func == (lhs: AppTheme, rhs: AppTheme) -> Bool {
        if lhs.coverImageFiles != rhs.coverImageFiles
            || lhs.darkCoverImageFiles != rhs.darkCoverImageFiles
            || lhs.fontFiles != rhs.fontFiles
            || lhs.splashEnabled != rhs.splashEnabled
            || lhs.splashDuration != rhs.splashDuration
            || lhs.splashRotation != rhs.splashRotation
            || lhs.splashImageFiles != rhs.splashImageFiles
            || lhs.darkSplashImageFiles != rhs.darkSplashImageFiles {
            return false
        }
        lhs.id == rhs.id
            && lhs.accentColorHex == rhs.accentColorHex
            && lhs.darkAccentColorHex == rhs.darkAccentColorHex
            && lhs.primaryTextColorHex == rhs.primaryTextColorHex
            && lhs.secondaryTextColorHex == rhs.secondaryTextColorHex
            && lhs.tertiaryTextColorHex == rhs.tertiaryTextColorHex
            && lhs.darkPrimaryTextColorHex == rhs.darkPrimaryTextColorHex
            && lhs.darkSecondaryTextColorHex
                == rhs.darkSecondaryTextColorHex
            && lhs.darkTertiaryTextColorHex
                == rhs.darkTertiaryTextColorHex
            && lhs.fontFamily == rhs.fontFamily
            && lhs.tabIcons == rhs.tabIcons
            && lhs.selectedTabIcons == rhs.selectedTabIcons
            && lhs.darkTabIcons == rhs.darkTabIcons
            && lhs.darkSelectedTabIcons == rhs.darkSelectedTabIcons
            && lhs.hideTabText == rhs.hideTabText
            && lhs.tabIconSize == rhs.tabIconSize
            && lhs.useClassicTabBar == rhs.useClassicTabBar
            && lhs.bookshelfHeaderStyle == rhs.bookshelfHeaderStyle
            && lhs.bookshelfGridColumnCount == rhs.bookshelfGridColumnCount
            && lhs.bookshelfListCardHeight == rhs.bookshelfListCardHeight
            && lhs.bookshelfShowsTags == rhs.bookshelfShowsTags
            && lhs.bookshelfTagTextColorMode
                == rhs.bookshelfTagTextColorMode
            && lhs.bookshelfTagCustomTextColorHex
                == rhs.bookshelfTagCustomTextColorHex
            && lhs.readerBottomToolbarStyle
                == rhs.readerBottomToolbarStyle
            && lhs.disableGlassEffect == rhs.disableGlassEffect
            && lhs.enableFrostedGlass == rhs.enableFrostedGlass
            && lhs.frostedGlassOpacity == rhs.frostedGlassOpacity
            && lhs.transparentModeOpacity == rhs.transparentModeOpacity
            && lhs.readerToolbarCardsFollowAppearance
                == rhs.readerToolbarCardsFollowAppearance
            && lhs.progressBarsFollowAppearance
                == rhs.progressBarsFollowAppearance
            && lhs.cardBackground == rhs.cardBackground
            && lhs.coverCornerRadius == rhs.coverCornerRadius
            && lhs.glowIntensity == rhs.glowIntensity
            && lhs.defaultBackground == rhs.defaultBackground
            && lhs.tabBackgrounds == rhs.tabBackgrounds
            && lhs.forceDefaultCover == rhs.forceDefaultCover
            && lhs.appIconName == rhs.appIconName
    }

    /// clampedCoverCornerRadius(_:)（0x100184ba4 L1104-1107 签名域）。
    static func clampedCoverCornerRadius(_ radius: CGFloat) -> CGFloat {
        min(max(radius, 0), 32)
    }

    var clampedCoverCornerRadius: CGFloat {
        Self.clampedCoverCornerRadius(coverCornerRadius)
    }

    // MARK: 随机图域（0x100183d10 L1110-1114 / 0x100183e94 L1123-1127）

    /// randomDefaultCoverImage(colorScheme:)（0x100183d10 域确证：
    /// coverImageDatas 随机取一解码）。
    func randomDefaultCoverImage(colorScheme: ColorScheme) -> UIImage? {
        let datas = coverImageDatas(for: colorScheme)
        guard !datas.isEmpty else { return nil }
        return datas.randomElement().flatMap(UIImage.init(data:))
    }

    /// randomSplashImage(colorScheme:)（0x100183e94 域确证）。
    func randomSplashImage(colorScheme: ColorScheme) -> UIImage? {
        splashImageDatas(for: colorScheme)
            .randomElement()
            .flatMap(UIImage.init(data:))
    }

    /// splashImage(forIndex:colorScheme:)（0x100183fb8 L1130-1135 域）。
    func splashImage(forIndex index: Int, colorScheme: ColorScheme)
        -> UIImage? {
        let datas = splashImageDatas(for: colorScheme)
        guard datas.indices.contains(index) else { return nil }
        return UIImage(data: datas[index])
    }

    /// splashImageDatas(for:)（0x100183f14 L1138-1143 域确证：暗色
    /// 回退亮色域）。
    func splashImageDatas(for colorScheme: ColorScheme) -> [Data] {
        colorScheme == .dark
            ? (darkSplashImageDatas.isEmpty
                ? lightSplashImageDatas : darkSplashImageDatas)
            : (lightSplashImageDatas.isEmpty
                ? darkSplashImageDatas : lightSplashImageDatas)
    }

    private var lightSplashImageDatas: [Data] {
        splashImageFiles.compactMap { fileDataMap[$0] }
    }

    private var darkSplashImageDatas: [Data] {
        darkSplashImageFiles.compactMap { fileDataMap[$0] }
    }

    /// coverImageDatas(for:)（AppThemeManager.defaultCoverImageDatas
    /// 同链交叉确证）。
    func coverImageDatas(for colorScheme: ColorScheme) -> [Data] {
        colorScheme == .dark
            ? (darkCoverImageDatas.isEmpty
                ? lightCoverImageDatas : darkCoverImageDatas)
            : (lightCoverImageDatas.isEmpty
                ? darkCoverImageDatas : lightCoverImageDatas)
    }

    private var lightCoverImageDatas: [Data] {
        coverImageFiles.compactMap { fileDataMap[$0] }
    }

    private var darkCoverImageDatas: [Data] {
        darkCoverImageFiles.compactMap { fileDataMap[$0] }
    }

    /// 主题文件读取桥（closure #2/#3 域确证：主题目录文件名 → 数据）。
    private var fileDataMap: [String: Data] {
        AppThemeManager.shared.themeFileData(for: id)
    }

    /// decodedDefaultCoverImage()（签名族确证）。
    func decodedDefaultCoverImage() -> UIImage? {
        lightCoverImageDatas.first.flatMap(UIImage.init(data:))
    }

    // MARK: 背景域（0x100184398 L1146-1148）

    /// background(for:)（0x100184398 块体确证：tabBackgrounds 命中取
    /// 自定义，否则 defaultBackground）。
    func background(for page: TabPage) -> TabBackground {
        tabBackgrounds[page.rawValue] ?? defaultBackground
    }

    /// hasCustomBackground(for:)（签名族确证）。
    func hasCustomBackground(for page: TabPage) -> Bool {
        tabBackgrounds[page.rawValue] != nil
    }

    /// setBackground(_:for:)（签名族确证：nil 移除自定义背景）。
    mutating func setBackground(
        _ background: TabBackground?, for page: TabPage
    ) {
        if let background {
            tabBackgrounds[page.rawValue] = background
        } else {
            tabBackgrounds.removeValue(forKey: page.rawValue)
        }
    }

    // MARK: 颜色域（0x100184498 L1169-1184 / accentColor 域）

    /// accentColor getter（0x100184398 域链 Color.init(hex:) 确证）。
    var accentColor: Color {
        leaflowColor(accentColorHex)
    }

    /// darkAccentColor getter（closure #1 域确证：无暗色回退亮色）。
    var darkAccentColor: Color {
        leaflowColor(darkAccentColorHex ?? accentColorHex)
    }

    /// textColor(_:colorScheme:)（0x100184498 块体确证：三档级别 ×
    /// 明暗分派 → Color(hex:)）。
    /// wave-16：新增 SwiftUI 风格档先归一到三档（normalizedLevel）再分派。
    func textColor(
        _ level: AppThemeTextLevel, colorScheme: ColorScheme
    ) -> Color {
        let hex: String
        switch (colorScheme, level.normalizedLevel) {
        case (.light, .primary):
            hex = primaryTextColorHex
        case (.light, .secondary):
            hex = secondaryTextColorHex
        case (.light, .tertiary):
            hex = tertiaryTextColorHex
        case (_, .primary):
            hex = darkPrimaryTextColorHex
        case (_, .secondary):
            hex = darkSecondaryTextColorHex
        case (_, .tertiary):
            hex = darkTertiaryTextColorHex
        }
        return leaflowColor(hex)
    }

    // MARK: 归一化助手（0x1001845dc L1191-1208 + closure 0x10018b91c）

    /// normalizedRGBHex(_:)（0x1001845dc 块体确证：nil/异形 → nil；
    /// 6 位 uppercased；3 位逐字符加倍 'AABBCC' 链）。
    static func normalizedRGBHex(_ hex: String?) -> String? {
        guard let hex else { return nil }
        let trimmed = hex.trimmingCharacters(
            in: .whitespacesAndNewlines)
        if trimmed.count == 6 {
            return trimmed.uppercased()
        }
        if trimmed.count == 3 {
            return trimmed.map { character in
                // closure #1 域确证：单字符加倍。
                String(repeating: String(character), count: 2)
            }.joined().uppercased()
        }
        return nil
    }

    /// normalizedTextColorHex(_:fallback:)（签名族确证）。
    static func normalizedTextColorHex(
        _ hex: String?, fallback: String
    ) -> String {
        normalizedRGBHex(hex) ?? fallback
    }
}

// 注：UIColor.toHexComponents() 由 BookshelfAppearanceSettingsView 的
// internal 扩展提供（CardBackgroundSettingsView 同消费域）——本文件不重复
// 声明（wave-16 重声明消解）。

/// 非可失败 hex 桥（0x100184398 Color.init(hex:) 域确证；ReaderTheme
/// 扩展的 failable init 收敛）。
func leaflowColor(_ hex: String) -> Color {
    // T-1401-01：Color(hex:) 已落地为非可失败初始化器（0x100211b5c，
    // 非法 hex 回退近黑），本桥保持调用面兼容。
    Color(hex: hex)
}
