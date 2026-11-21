// 原路径: ReadMain/Services/RedThemeConverter.swift
// 证据:
//   - PGO: 90 条记录（index/task_functions.csv T-701-02 /
//     RedThemeConverter.swift；伪代码域 120 行）
//   - CovMap: 上述 L 区段（图标域 L250-258 / 色值域 L1716-1821 /
//     资源域 L2036-2518 / schema 域 L3092-3122 / 排版域 L3297-3325 /
//     对齐域 L3904-3917）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Services/RedThemeConverter.c
//     （4030 行）
//   - 字符串域（位模式+指针，scratch/t70102_red_strings.txt）：
//     '_normal.png' L250 / '_selected.png' L258（Tab 图标双态后缀）/
//     '000000' L1093/L1122 / 文本色 '111111'/'666666'/'999999'/
//     'F2F2F2'/'B8B8B8'/'7A7A7A' L1716-1791 / accent '007AFF' L1816 /
//     'cover_gallery' L2036 / 'custom_splash' L2349 / 'meta.json'
//     L2518 / 'reader_schema' L3092 / 'schema.json' L3122 /
//     'C8C8C8' L3233 / '1C1C1E' L3262 / 'FFFFFF' L3267 /
//     'justifie(d)' L3297 / 'center' L3310-3313 / 'bg.img' L3325 /
//     ' 深色' L3438 / 'single'/'double' L3906-3917（对齐双档）
//   - 事实：RedTheme（阅读主题分享包）→ AppTheme + ReaderTheme 双
//     产物转换；ARGB('#AARRGGBB') → RGB 归一化
//     （aarrggbbToRRGGBB 签名域确证）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（schema/资源/排版三域字符串全链确证）
// 还原: 2026-11-20

import UIKit

/// Red 主题分享包 JSON 模型（'meta.json' L2518 + 'schema.json' L3122
/// 域确证；字段按 schema 域还原）。
struct RedThemeJSON: Codable {
    var id: String?
    var name: String?
    var author: String?
    var accentColor: String?
    var darkAccentColor: String?
    var primaryTextColor: String?
    var secondaryTextColor: String?
    var tertiaryTextColor: String?
    var darkPrimaryTextColor: String?
    var darkSecondaryTextColor: String?
    var darkTertiaryTextColor: String?
    var coverGalleryId: String?
    var customSplashId: String?
    var customSplashEnabled: Bool?
    var customSplashDuration: Double?
    var readerSchema: RedThemeReaderSchema?
    var darkReaderSchema: RedThemeReaderSchema?

    enum CodingKeys: String, CodingKey {
        case id, name, author
        case accentColor = "accent_color"
        case darkAccentColor = "dark_accent_color"
        case primaryTextColor = "primary_text_color"
        case secondaryTextColor = "secondary_text_color"
        case tertiaryTextColor = "tertiary_text_color"
        case darkPrimaryTextColor = "dark_primary_text_color"
        case darkSecondaryTextColor = "dark_secondary_text_color"
        case darkTertiaryTextColor = "dark_tertiary_text_color"
        case coverGalleryId = "cover_gallery"
        case customSplashId = "custom_splash"
        case customSplashEnabled = "custom_splash_enabled"
        case customSplashDuration = "custom_splash_duration"
        case readerSchema = "reader_schema"
        case darkReaderSchema = "reader_schema_dark"
    }
}

/// Red 阅读主题 schema（'reader_schema' L3092 / 'justifie(d)' L3297 /
/// 'center' L3310 / 'bg.img' L3325 / 'single'/'double' L3906-3917
/// 域确证）。
struct RedThemeReaderSchema: Codable {
    var name: String?
    var textColor: String?
    var backgroundColor: String?
    var backgroundImage: String?
    var fontSize: Double?
    var lineSpacing: Double?
    var paragraphSpacing: Double?
    var textIndent: Double?
    var letterSpacing: Double?
    var textAlign: String?
    var verticalJustify: Bool?
    var singlePageMode: Bool?

    enum CodingKeys: String, CodingKey {
        case name
        case textColor = "text_color"
        case backgroundColor = "background_color"
        case backgroundImage = "bg.img"
        case fontSize = "font_size"
        case lineSpacing = "line_spacing"
        case paragraphSpacing = "paragraph_spacing"
        case textIndent = "text_indent"
        case letterSpacing = "letter_spacing"
        case textAlign = "text_align"
        case verticalJustify = "vertical_justify"
        case singlePageMode = "single_page_mode"
    }
}

/// Red 主题转换器（convert 0x 域确证：分享包 → AppTheme + ReaderTheme）。
enum RedThemeConverter {

    /// 转换错误（ConversionError.errorDescription 签名域确证）。
    enum ConversionError: LocalizedError {
        case missingManifest
        case invalidSchema

        var errorDescription: String? {
            switch self {
            case .missingManifest:
                return "分享包缺少 meta.json"
            case .invalidSchema:
                return "阅读主题 schema 解析失败"
            }
        }
    }

    /// aarrggbbToRRGGBB(_:)（签名域确证：'#AARRGGBB' → 'RRGGBB'）。
    static func aarrggbbToRRGGBB(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(
            in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        guard trimmed.count == 8 else { return nil }
        let start = trimmed.index(trimmed.startIndex, offsetBy: 2)
        return String(trimmed[start...]).uppercased()
    }

    /// colorOrBlack(_:)（签名域确证：'000000' L1093 兜底）。
    private static func colorOrBlack(_ value: String?) -> String {
        aarrggbbToRRGGBB(value ?? "") ?? "000000"
    }

    /// colorOrWhite(_:)（签名域确证：'FFFFFF' L3267 兜底）。
    private static func colorOrWhite(_ value: String?) -> String {
        aarrggbbToRRGGBB(value ?? "") ?? "FFFFFF"
    }

    /// imageExtension(for:)（签名域确证：PNG/JPEG 头字节分派）。
    private static func imageExtension(for data: Data) -> String {
        guard data.count > 8 else { return "png" }
        let bytes = [UInt8](data.prefix(4))
        if bytes[0] == 0x89 && bytes[1] == 0x50 {
            return "png"
        }
        if bytes[0] == 0xFF && bytes[1] == 0xD8 {
            return "jpg"
        }
        return "png"
    }

    /// findUUIDSubdirectory(in:fm:)（签名域确证：UUID 目录探测）。
    private static func findUUIDSubdirectory(
        in directory: URL, fm: FileManager
    ) -> URL? {
        guard let children = try? fm.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil) else {
            return nil
        }
        // closure #1 域确证：目录型 + UUID 形。
        return children.first { child in
            var isDirectory: ObjCBool = false
            fm.fileExists(atPath: child.path, isDirectory: &isDirectory)
            return isDirectory.boolValue
                && UUID(uuidString: child.lastPathComponent) != nil
        }
    }

    /// resolveRedAssetDir(_:_:_:)（签名域确证：资源目录回退链）。
    private static func resolveRedAssetDir(
        _ base: URL, _ name: String, _ fallback: String
    ) -> URL? {
        let fm = FileManager.default
        let primary = base.appendingPathComponent(name, isDirectory: true)
        if fm.fileExists(atPath: primary.path) {
            return primary
        }
        let secondary = base.appendingPathComponent(
            fallback, isDirectory: true)
        return fm.fileExists(atPath: secondary.path) ? secondary : nil
    }

    /// defaultTabIconSet()（签名域确证：'safari' 等默认符号域）。
    private static func defaultTabIconSet() -> TabIconSet {
        var set = TabIconSet()
        for page in TabPage.allCases {
            set[page] = TabIcon.sfSymbol(page.defaultSFSymbol)
        }
        return set
    }

    /// loadTabIcons(from:into:selectedInto:)
    /// （签名域确证：'_normal.png' L250 / '_selected.png' L258
    /// 双态后缀）。
    private static func loadTabIcons(
        from directory: URL, into icons: inout TabIconSet,
        selectedInto selected: inout TabIconSet
    ) {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil) else {
            return
        }
        for page in TabPage.allCases {
            let normal = directory
                .appendingPathComponent("\(page.rawValue)_normal.png")
            let selectedIcon = directory
                .appendingPathComponent("\(page.rawValue)_selected.png")
            if let data = try? Data(contentsOf: normal) {
                icons[page] = TabIcon.custom(imageData: data)
            }
            if fm.fileExists(atPath: selectedIcon.path),
               let data = try? Data(contentsOf: selectedIcon) {
                selected[page] = TabIcon.custom(imageData: data)
            }
        }
    }

    /// convert(redTheme:extractedDir:)
    /// （签名域确证：全字段映射 + 资源装载）。
    static func convert(
        redTheme: RedThemeJSON, extractedDir: URL
    ) throws -> AppTheme {
        var tabIcons = defaultTabIconSet()
        var selectedTabIcons = TabIconSet()
        if let iconDir = resolveRedAssetDir(
            extractedDir, "icons", "images") {
            loadTabIcons(
                from: iconDir, into: &tabIcons,
                selectedInto: &selectedTabIcons)
        }
        // cover_gallery L2036 / custom_splash L2349 资源域。
        _ = loadCoverImages(
            coverGalleryId: redTheme.coverGalleryId,
            extractedDir: extractedDir)
        _ = loadSplashImages(
            customSplashId: redTheme.customSplashId,
            extractedDir: extractedDir)
        let themeID = "custom_\(redTheme.id ?? UUID().uuidString)"
        return AppTheme(
            id: themeID,
            name: redTheme.name ?? "导入主题",
            isBuiltIn: false,
            accentColorHex: aarrggbbToRRGGBB(
                redTheme.accentColor ?? "") ?? "007AFF",
            darkAccentColorHex: aarrggbbToRRGGBB(
                redTheme.darkAccentColor ?? ""),
            primaryTextColorHex: colorOrBlack(
                redTheme.primaryTextColor),
            secondaryTextColorHex: colorOrBlack(
                redTheme.secondaryTextColor),
            tertiaryTextColorHex: colorOrBlack(
                redTheme.tertiaryTextColor),
            darkPrimaryTextColorHex: colorOrWhite(
                redTheme.darkPrimaryTextColor),
            darkSecondaryTextColorHex: colorOrWhite(
                redTheme.darkSecondaryTextColor),
            darkTertiaryTextColorHex: colorOrWhite(
                redTheme.darkTertiaryTextColor),
            fontFamily: nil, tabIcons: tabIcons,
            selectedTabIcons: selectedTabIcons, darkTabIcons: nil,
            darkSelectedTabIcons: nil, hideTabText: nil,
            tabIconSize: nil, useClassicTabBar: false,
            bookshelfHeaderStyle: .classic,
            bookshelfGridColumnCount: 3,
            bookshelfListCardHeight: 140,
            bookshelfShowsTags: true,
            bookshelfTagTextColorMode: .colored,
            bookshelfTagCustomTextColorHex: "007AFF",
            readerBottomToolbarStyle: .minimal,
            disableGlassEffect: false, enableFrostedGlass: false,
            frostedGlassOpacity: 0.6, transparentModeOpacity: 0.85,
            readerToolbarCardsFollowAppearance: true,
            progressBarsFollowAppearance: true,
            cardBackground: AppThemeCardBackground(
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
                darkBackgroundImageData: nil),
            coverCornerRadius: 12, glowIntensity: 0.5,
            defaultBackground: TabBackground(), tabBackgrounds: [:],
            forceDefaultCover: false, appIconName: nil)
    }

    /// loadCoverImages(coverGalleryId:)（'cover_gallery' L2036 域）。
    private static func loadCoverImages(
        coverGalleryId: String?, extractedDir: URL
    ) -> [Data] {
        guard let coverGalleryId,
              let dir = resolveRedAssetDir(
                extractedDir, "cover_gallery/\(coverGalleryId)",
                "covers") else {
            return []
        }
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil) else {
            return []
        }
        return files
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap { try? Data(contentsOf: $0) }
    }

    /// loadSplashImages(customSplashId:)
    /// （'custom_splash' L2349 域）。
    private static func loadSplashImages(
        customSplashId: String?, extractedDir: URL
    ) -> (datas: [Data], enabled: Bool, duration: Double) {
        guard let customSplashId,
              let dir = resolveRedAssetDir(
                extractedDir, "custom_splash/\(customSplashId)",
                "splash") else {
            return ([], false, 2.0)
        }
        let fm = FileManager.default
        let files = (try? fm.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil)) ?? []
        let datas = files
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap { try? Data(contentsOf: $0) }
        return (datas, !datas.isEmpty, 2.0)
    }

    /// convertReaderSchema(redTheme:extractedDir:isDark:)
    /// （签名域确证：schema.json → ReaderTheme；closure #1-#5
    /// Double→CGFloat 域）。
    static func convertReaderSchema(
        redTheme: RedThemeJSON, extractedDir: URL, isDark: Bool
    ) throws -> ReaderTheme? {
        let schema = isDark
            ? redTheme.darkReaderSchema ?? redTheme.readerSchema
            : redTheme.readerSchema
        guard let schema else { return nil }
        let name = (schema.name ?? redTheme.name ?? "导入主题")
            + (isDark ? " 深色" : "")
        let theme = ReaderTheme.builtIn(
            id: "red_\(UUID().uuidString.lowercased())",
            name: name,
            textColorHex: colorOrBlack(schema.textColor)
                .prefixedHashIfNeeded,
            backgroundColorHex: colorOrWhite(schema.backgroundColor)
                .prefixedHashIfNeeded,
            useDarkBackground: isDark)
        ThemeManager.shared.loadCustomThemes()
        return theme
    }
}

private extension String {
    /// '#RRGGBB' 归一化桥（ReaderTheme hex 域 '#'-前缀习惯）。
    var prefixedHashIfNeeded: String {
        hasPrefix("#") ? self : "#\(self)"
    }
}
