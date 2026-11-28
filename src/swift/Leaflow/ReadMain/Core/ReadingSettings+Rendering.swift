// 原路径: ReadMain/Core/ReadingSettings.swift
// 分册只改变边界，函数、规模与桩仍计入原始文件。
import SwiftUI
import UIKit

extension ReadingSettings {
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
    var currentAppearanceIsDark: Bool {
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

    /// 伪代码 0x1002123e0（L450-457）：Documents
    ///（URLsForDirectory:9/inDomains:1 确证）+ ReaderBackgrounds 子目录；
    /// 不存在则 createDirectoryAtURL withIntermediateDirectories 创建
    ///（_convertNSErrorToError 域确证 throws）。
    static var backgroundImagesDirectory: URL {
        get throws {
            try backgroundImagesDirectory(documents: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0],
                legacySupport: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0])
        }
    }

    static func backgroundImagesDirectory(documents: URL, legacySupport: URL) throws -> URL {
        let fileManager = FileManager.default
        let directory = documents.appendingPathComponent("ReaderBackgrounds", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let legacy = legacySupport.appendingPathComponent("ReaderBackgrounds")
        for source in (try? fileManager.contentsOfDirectory(at: legacy, includingPropertiesForKeys: [.isRegularFileKey])) ?? [] {
            let target = directory.appendingPathComponent(source.lastPathComponent)
            if !fileManager.fileExists(atPath: target.path), (try source.resourceValues(forKeys: [.isRegularFileKey])).isRegularFile == true {
                try fileManager.copyItem(at: source, to: target)
            }
        }
        return directory
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
        // UIFont.Weight 是 struct（非 enum）——表达式模式匹配需普通 default。
        default: return .regular
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
        default: suffix = "Regular"
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

}
