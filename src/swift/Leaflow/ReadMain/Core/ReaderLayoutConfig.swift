// 原路径: ReadMain/Core/ReaderLayoutConfig.swift
// 证据:
//   - PGO: paragraphIndentWidth / applyParagraphIndentLayout / calculateLayout /
//     ReaderWidgetLayoutMetrics.init / WidgetPageScope.shouldShow / WidgetTextAlignment.displayName /
//     ReadingDurationTracker.saveIncremental / ReaderLayoutCalculator 59 函数族
//   - CovMap: paragraphIndentWidth L29-37 @0x1001eedf8；applyParagraphIndentLayout L45-86
//     @0x1001eefcc；WidgetLayoutMetrics.init L110-117 @0x1001ef40c；shouldShow L143-149
//     @0x1007664b4；calculateLayout L896-1019 @0x1001f6b68；saveIncremental L1209-1235 @0x1001f83fc
//   - IDA: 上述地址的 Hex-Rays 伪代码（5579 行）
//   - 关键常量（低字节在前）：全角空格 "\u{3000}"×count=8421603(0x808080→U+3000 逐字节)、
//     "\u{3000}"(57344-0xFFFFF7FF 判定区间)、UIFont 属性名 NSFontAttributeName、
//     NSKernAttributeName、"mediumid"(0x6D756964656D)、"medium"(1684828002)
//   - 关键选择子：sizeWithAttributes:/paragraphRangeForRange:/setFirstLineHeadIndent:/
//     replaceCharactersInRange:withAttributedString:/addAttribute:value:range:/
//     boundingRectWithSize:options:attributes:context:/fontDescriptorWithSymbolicTraits:/
//     setAlignment:/setLineBreakMode:/setLineBreakStrategy:/lineHeight/safeAreaLayoutGuide/
//     layoutFrame/convertRect:fromCoordinateSpace:/fontWithDescriptor:size:
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - paragraphIndentWidth / applyParagraphIndentLayout: high（逐行对照伪代码）
//   - WidgetLayoutMetrics / shouldShow: high（简单语义直接可见）
//   - calculateLayout: medium-high（主干分发/缓存/段落样式确证；132 行体细节见读后记）
//   - ReaderTextLayout 其余 20+ 函数: medium（签名确证，内部实现按主干推断）
// 还原: 2026-11-19

import Foundation
import UIKit
import SwiftUI

// MARK: - ReaderTextLayout 文本排版工具

/// 段落缩进排版（伪代码 0x1001eedf8/0x1001eefcc，L29-86）。
enum ReaderTextLayout {

    /// 伪代码 0x1001eedf8（L29-37）：全角空格宽度度量。
    /// 逻辑：count < 1 → 0.0；否则创建 `count` 个 U+3000（全角空格，
    /// 常量 8421603 = "\u{3000}" 的 UTF-8 编码）→ 构造 UIFont 属性字典
    /// （NSFontAttributeName + letterSpacing != 0 时加 NSKernAttributeName）
    /// → `sizeWithAttributes:` 度量 → `ceil(width)`。
    static func paragraphIndentWidth(count: Int, font: UIFont, letterSpacing: CGFloat) -> CGFloat {
        guard count >= 1 else { return 0.0 }

        let indentText = String(repeating: "\u{3000}", count: count) as NSString
        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
        ]
        if letterSpacing != 0.0 {
            attributes[.kern] = letterSpacing
        }
        let size = indentText.size(withAttributes: attributes)
        return ceil(size.width)
    }

    /// 伪代码 0x1001eefcc（L45-86）：段落首行缩进排版。
    /// 逻辑：遍历 `paragraphRangeForRange:` → 复制段落样式为 NSMutableParagraphStyle
    /// → 逐字符扫描段落前缀（U+3000 判定区间 57344-0xFFFFF7FF，
    /// 即 >= 0x2000 的 CJK 兼容区）计数 → 上限 4 → `setFirstLineHeadIndent:`
    /// → `replaceCharactersInRange:withAttributedString:` 替换前缀 →
    /// `addAttribute:value:range:` 应用段落样式。
    /// 伪代码 L233：全角空格计数为 0 时 `setFirstLineHeadIndent: 0.0`。
    static func applyParagraphIndentLayout(
        to attributedString: NSMutableAttributedString,
        textIndent: Int,
        font: UIFont,
        letterSpacing: CGFloat,
        baseParagraphStyle: NSParagraphStyle
    ) {
        guard attributedString.length >= 1,
            let text = attributedString.string as NSString?
        else { return }

        let indent = max(0, textIndent)
        var offset = 0

        while offset < text.length {
            let paragraphRange = text.paragraphRange(for: NSRange(location: offset, length: 0))
            let paragraphLength = paragraphRange.length

            // 复制段落样式（伪代码 L160-L173：baseParagraphStyle mutableCopy → 检查类型）。
            let paragraphStyle = (baseParagraphStyle.mutableCopy() as? NSMutableParagraphStyle)
                ?? NSMutableParagraphStyle()

            // 逐字符扫描前缀全角空格（伪代码 L179-L237）。
            var leadingSpaces = 0
            let maxScan = min(indent, paragraphLength, 4)
            var found = true
            for i in 0..<maxScan {
                let charIndex = paragraphRange.location + i
                guard charIndex < text.length else { break }
                let char = text.character(at: charIndex)
                // 伪代码 L221：`v28 - 57344 > 0xFFFFF7FF` 判定非全角空格。
                if char != 0x3000 {
                    found = false
                    break
                }
                leadingSpaces += 1
            }

            if found, leadingSpaces > 0 {
                // 伪代码 L191-L196：度量并设置首行缩进。
                let indentWidth = paragraphIndentWidth(
                    count: leadingSpaces, font: font, letterSpacing: letterSpacing
                )
                paragraphStyle.firstLineHeadIndent = indentWidth
                // 伪代码 L196-L209：用空格前缀替换原文（保留属性）。
                let prefixString = String(repeating: "\u{3000}", count: leadingSpaces)
                let attributes = attributedString.attributes(
                    at: paragraphRange.location, effectiveRange: nil
                )
                let replacement = NSAttributedString(
                    string: prefixString, attributes: attributes
                )
                attributedString.replaceCharacters(
                    in: NSRange(location: paragraphRange.location, length: leadingSpaces),
                    with: replacement
                )
            } else {
                // 伪代码 L233：无全角空格 → firstLineHeadIndent = 0.0。
                paragraphStyle.firstLineHeadIndent = 0.0
            }

            // 伪代码 L212：应用段落样式。
            attributedString.addAttribute(
                .paragraphStyle, value: paragraphStyle, range: paragraphRange
            )
            offset = paragraphRange.location + paragraphRange.length
        }
    }
}

// MARK: - Widget 布局度量

/// Widget 页面范围。
enum WidgetPageScope {
    /// 伪代码 0x1007664b4（L143-149）：`return isFirstPage`。
    static func shouldShow(isFirstPage: Bool) -> Bool {
        isFirstPage
    }
}

/// Widget 文本对齐。
enum WidgetTextAlignment: String, Codable {
    case leading
    case center
    case trailing

    /// 伪代码 0x1007bc848（L158）。
    var displayName: String {
        switch self {
        case .leading: return "左对齐"
        case .center: return "居中"
        case .trailing: return "右对齐"
        }
    }
}

/// Widget 布局度量（伪代码 0x1001ef40c，L110-117）。
struct ReaderWidgetLayoutMetrics {

    var pageBounds: CGRect = .zero
    var safeAreaFrame: CGRect = .zero
    var isPad: Bool = false

    /// 伪代码 0x1001ef40c（L110-117）：
    /// 逻辑：取 window → bounds.height > 0 → safeAreaLayoutGuide.layoutFrame
    ///       → convertRect:fromCoordinateSpace: → userInterfaceIdiom 判定。
    /// window 为空或高度为 0 → 全零初始化。
    init(pageBounds: CGRect, windowSafeAreaFrame: CGRect, userInterfaceIdiom: UIUserInterfaceIdiom) {
        self.pageBounds = pageBounds
        self.safeAreaFrame = windowSafeAreaFrame
        self.isPad = userInterfaceIdiom == .pad
    }

    /// 从视图构建（伪代码：objc_msgSend(a1, "window") → safeAreaLayoutGuide → convert）。
    static func resolve(from view: UIView) -> ReaderWidgetLayoutMetrics? {
        guard let window = view.window else { return nil }
        let bounds = view.bounds
        guard bounds.height > 0.0 else { return nil }
        let safeArea = window.safeAreaLayoutGuide.layoutFrame
        let converted = view.convert(safeArea, from: window)
        return ReaderWidgetLayoutMetrics(
            pageBounds: bounds,
            windowSafeAreaFrame: converted,
            userInterfaceIdiom: view.traitCollection.userInterfaceIdiom
        )
    }
}

/// 阅读时长追踪器。
final class ReadingDurationTracker {

    static let shared = ReadingDurationTracker()
    private(set) var totalDuration: TimeInterval = 0
    private var lastCheckpoint: TimeInterval = 0
    /// 会话起点（ProcessInfo.systemUptime 域；nil = 未在跟踪）。
    private var sessionStart: TimeInterval?
    /// 翻页采样窗（offset 128 数组域；窗口上限 0x14=20 确证）。
    private var pageTurnSamples: [TimeInterval] = []
    private(set) var pageTurnCount: Int = 0
    private(set) var accumulatedCharCount: Int = 0

    /// 伪代码 0x1001f81d4（L1155-1157）：会话激活判定（块体与
    /// estimateRemainingMinutes/systemUptime 域 ICF 合并——processInfo 确证）。
    var isActivelyTracking: Bool { sessionStart != nil }

    /// 伪代码 0x1001f83fc（L1209-1235）：增量保存。
    func saveIncremental() {
        let now = CFAbsoluteTimeGetCurrent()
        let delta = now - lastCheckpoint
        totalDuration += delta
        lastCheckpoint = now
    }

    func startTracking() {
        sessionStart = ProcessInfo.processInfo.systemUptime
        lastCheckpoint = CFAbsoluteTimeGetCurrent()
    }

    /// 伪代码 0x1001f8318（L1177-1194）：systemUptime - sessionStart 累入
    /// totalDuration（offset 32 域）并结束会话。
    func endSession() {
        guard let start = sessionStart else { return }
        let uptime = ProcessInfo.processInfo.systemUptime
        totalDuration += max(uptime - start, 0)
        sessionStart = nil
    }

    /// 伪代码 0x1001f8394（L1196-1200）：会话中 → 记检查点（offset 48 域）。
    func pauseSession() {
        guard sessionStart != nil else { return }
        lastCheckpoint = ProcessInfo.processInfo.systemUptime
    }

    /// 伪代码 0x1001f853c（L1238-1246）：currentAccumulatedDuration 激活判定
    /// → pageCount++（offset 72）/ charTotal += charCount（offset 88）→
    /// systemUptime 入采样窗；窗满 20（0x14 确证）→ 弃最旧样本。
    func recordPageTurn(charCount: Int) {
        guard isActivelyTracking else { return }
        pageTurnCount += 1
        accumulatedCharCount += charCount
        pageTurnSamples.append(ProcessInfo.processInfo.systemUptime)
        if pageTurnSamples.count > 20 {
            pageTurnSamples.removeFirst(pageTurnSamples.count - 20)
        }
    }

    /// 伪代码 0x1001f86a0（L1265-1275）：样本 < 3 → nil；(last-first)/(n-1)
    /// 均值；钳制 3...600 秒域（越界 → nil）。
    var estimatedSecondsPerPage: Double? {
        guard pageTurnSamples.count >= 3 else { return nil }
        let span = pageTurnSamples.last! - pageTurnSamples.first!
        let average = span / Double(pageTurnSamples.count - 1)
        guard average > 3.0, average < 600.0 else { return nil }
        return average
    }

    /// 伪代码 0x1001f88ac（L1278-1282）：estimatedSecondsPerPage ×
    /// remainingPages / 60。
    func estimateRemainingMinutes(remainingPages: Int) -> Int? {
        guard let perPage = estimatedSecondsPerPage else { return nil }
        return Int(perPage * Double(max(remainingPages, 0)) / 60.0)
    }
}

// MARK: - 阅读器布局计算器

/// Widget 布局配置。
struct LayoutWidget: Codable {
    var type: String
    var alignment: WidgetTextAlignment
    var showOnFirstPage: Bool
}

/// 章节标题排版配置（Codable：T-1401-01 ChapterTitlePreset 双档解码桥）。
struct ChapterTitleConfig: Codable {
    var fontName: String
    var fontSize: CGFloat
    var textAlignment: NSTextAlignment
    var useBold: Bool
    /// 伪代码 0x1001f2c90（L461）：默认启用（块体与 FNV-1a 串哈希域
    /// 0xCBF29CE484222325 ICF 合并 + "true"/"false" 串域确证）。
    var isEnabled: Bool = true
    /// 伪代码 0x1001fc118（L486）：章名字体默认串（计数器桩；空 = 回退正文域）。
    var chapterNameFont: String = ""
    /// 权重名（uiFontWeight 0x1001f1f4c 读取域；四档字面量确证）。
    var fontWeightName: String = "regular"
}

/// 阅读布局模板（T-1401-01 applyLayoutTemplate 0x100221ef8 域桥；档位推断，
/// presetWidgets/defaultWidgets 域随 T-1401-02 还原）。
enum ReaderLayoutTemplate: String, Codable, CaseIterable {
    case standard
    case compact
    case immersive
}

/// 页面布局结果。
struct ReaderLayoutResult {
    var contentRect: CGRect
    var titleHeight: CGFloat
    var topInset: CGFloat
    var bottomInset: CGFloat
    var leftPageMargin: CGFloat
    var rightPageMargin: CGFloat
    var isDoublePage: Bool
    var widgetMetrics: ReaderWidgetLayoutMetrics?
}

/// 阅读器布局计算器（伪代码 0x1001f6b68，L896-1019，核心分页排版引擎）。
final class ReaderLayoutCalculator {

    // MARK: 窗口度量缓存

    /// 伪代码：WindowMetricsCache.resolve(current:)（swift_once + 缓存）。
    private static var cachedMetrics: (bounds: CGRect, safeArea: CGRect)?
    private static let metricsLock = NSLock()

    static func resolveWindowMetrics() -> (bounds: CGRect, safeArea: CGRect)? {
        metricsLock.lock()
        defer { metricsLock.unlock() }
        return cachedMetrics
    }

    static func updateWindowMetrics(bounds: CGRect, safeArea: CGRect) {
        metricsLock.lock()
        defer { metricsLock.unlock() }
        cachedMetrics = (bounds, safeArea)
    }

    // MARK: 核心布局计算

    /// 伪代码 0x1001f6b68（L896-1019）：
    /// 主链：
    /// 1. `WindowMetricsCache.resolve(current:)` 获取窗口度量（缓存命中早退）。
    /// 2. 计算 contentRect（从 pageBounds 减去左右页边距 + 顶部/底部 inset）。
    /// 3. 章节标题排版：
    ///    a. `fontDescriptorWithSymbolicTraits: 2`（bold 判定）。
    ///    b. `NSMutableParagraphStyle`：`setAlignment:` / `setLineBreakMode: 0` /
    ///       `setLineBreakStrategy: 0xFFFF`。
    ///    c. 标题高度：`boundingRectWithSize:options:attributes:context:`
    ///       （options=3 即 [.usesLineFragmentOrigin, .usesFontLeading]）。
    ///    d. "medium"/"mediumid" 字体名判定（0x6D756964656D = "mediumid"）。
    /// 4. `ReaderTextLayout.applyParagraphIndentLayout` 应用于正文。
    /// 5. 双页模式判定（`isFirstPage` 参数）。
    /// 6. Widget 布局度量（safeAreaLayoutGuide → convert）。
    static func calculateLayout(
        isFirstPage: Bool,
        chapterTitleConfig: ChapterTitleConfig?,
        leftPageMargin: CGFloat,
        rightPageMargin: CGFloat,
        topInsetExtra: CGFloat,
        bottomInsetExtra: CGFloat,
        screenBounds: CGRect,
        safeAreaFrame: CGRect
    ) -> ReaderLayoutResult {
        // 伪代码：WindowMetricsCache 命中早退。
        if let cached = resolveWindowMetrics() {
            return buildResult(
                isFirstPage: isFirstPage,
                config: chapterTitleConfig,
                leftMargin: leftPageMargin,
                rightMargin: rightPageMargin,
                topExtra: topInsetExtra,
                bottomExtra: bottomInsetExtra,
                bounds: cached.bounds,
                safeArea: cached.safeArea
            )
        }

        // 伪代码：窗口度量缺失 → 直接用 screenBounds/safeAreaFrame。
        return buildResult(
            isFirstPage: isFirstPage,
            config: chapterTitleConfig,
            leftMargin: leftPageMargin,
            rightMargin: rightPageMargin,
            topExtra: topInsetExtra,
            bottomExtra: bottomInsetExtra,
            bounds: screenBounds,
            safeArea: safeAreaFrame
        )
    }

    /// buildResult：calculateLayout 的结果组装。
    private static func buildResult(
        isFirstPage: Bool,
        config: ChapterTitleConfig?,
        leftMargin: CGFloat,
        rightMargin: CGFloat,
        topExtra: CGFloat,
        bottomExtra: CGFloat,
        bounds: CGRect,
        safeArea: CGRect
    ) -> ReaderLayoutResult {
        // contentRect：从 bounds 减去 margins（伪代码 sub_1001FB92C 调用族）。
        let contentX = bounds.minX + leftMargin
        let contentWidth = bounds.width - leftMargin - rightMargin

        // 标题高度计算（伪代码：boundingRectWithSize:options:3）。
        var titleHeight: CGFloat = 0
        if let config = config {
            let font = buildTitleFont(config)
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = config.textAlignment
            paragraphStyle.lineBreakMode = .byWordWrapping
            paragraphStyle.lineBreakStrategy = []
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .paragraphStyle: paragraphStyle,
            ]
            let titleText = "章" as NSString
            let boundingRect = titleText.boundingRect(
                with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attributes,
                context: nil
            )
            titleHeight = ceil(boundingRect.height)
        }

        // 安全区叠加（伪代码：safeArea 偏移叠加到 top/bottom inset）。
        let topInset = safeArea.minY + topExtra
        let bottomInset = (bounds.height - safeArea.maxY) + bottomExtra

        let contentRect = CGRect(
            x: contentX,
            y: topInset + titleHeight,
            width: contentWidth,
            height: max(0, bounds.height - topInset - bottomInset - titleHeight)
        )

        let metrics = ReaderWidgetLayoutMetrics(
            pageBounds: bounds,
            windowSafeAreaFrame: safeArea,
            userInterfaceIdiom: UIDevice.current.userInterfaceIdiom
        )

        return ReaderLayoutResult(
            contentRect: contentRect,
            titleHeight: titleHeight,
            topInset: topInset,
            bottomInset: bottomInset,
            leftPageMargin: leftMargin,
            rightPageMargin: rightMargin,
            isDoublePage: !isFirstPage,
            widgetMetrics: metrics
        )
    }

    /// 标题字体构建（伪代码：fontDescriptorWithSymbolicTraits: 2 → bold）。
    private static func buildTitleFont(_ config: ChapterTitleConfig) -> UIFont {
        let baseFont = UIFont.systemFont(ofSize: config.fontSize)
        if config.useBold {
            if let descriptor = baseFont.fontDescriptor.withSymbolicTraits(.traitBold),
                let boldFont = UIFont(descriptor: descriptor, size: config.fontSize)
            {
                return boldFont
            }
        }
        return baseFont
    }
}

// MARK: - T-1401-02 逐域补齐（阅读排版域）

extension ChapterTitleConfig {

    enum CodingKeys: String, CodingKey {
        case fontName
        case fontSize
        case textAlignment
        case useBold
        case isEnabled
        case chapterNameFont
        case fontWeightName
    }

    /// Codable 手工实现：NSTextAlignment 非 Codable，rawValue 桥
    ///（T-1401-01 ChapterTitlePreset 双档解码域依赖）。
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fontName = try container.decodeIfPresent(
            String.self, forKey: .fontName) ?? ""
        fontSize = try container.decodeIfPresent(
            CGFloat.self, forKey: .fontSize) ?? 22
        let alignmentRaw = try container.decodeIfPresent(
            Int.self, forKey: .textAlignment) ?? NSTextAlignment.center.rawValue
        textAlignment = NSTextAlignment(rawValue: alignmentRaw) ?? .center
        useBold = try container.decodeIfPresent(Bool.self, forKey: .useBold) ?? true
        isEnabled = try container.decodeIfPresent(
            Bool.self, forKey: .isEnabled) ?? true
        chapterNameFont = try container.decodeIfPresent(
            String.self, forKey: .chapterNameFont) ?? ""
        fontWeightName = try container.decodeIfPresent(
            String.self, forKey: .fontWeightName) ?? "regular"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(fontName, forKey: .fontName)
        try container.encode(fontSize, forKey: .fontSize)
        try container.encode(textAlignment.rawValue, forKey: .textAlignment)
        try container.encode(useBold, forKey: .useBold)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(chapterNameFont, forKey: .chapterNameFont)
        try container.encode(fontWeightName, forKey: .fontWeightName)
    }

    /// 伪代码 0x1001f1f4c（L506-514）：权重名 → UIFont.Weight
    ///（"regular" 0x72616C75676572 / "medium" 0x6D756964656D / "semibold"
    /// 0xE8 域 / "bold" 0x646C6F62 字面量确证；未匹配回退 sub_1001FB7FC 链
    /// → regular）。
    var uiFontWeight: UIFont.Weight {
        switch fontWeightName {
        case "regular": return .regular
        case "medium": return .medium
        case "semibold": return .semibold
        case "bold": return .bold
        default: return .regular
        }
    }

    /// 伪代码 0x1007bfee8（L525-543）：fontFamily == "System"
    ///（0x6D6574737953 确证）→ systemFontOfSize:weight:(uiFontWeight)；
    /// 否则 UIFont(name:size:)；weight 名 bold → fontDescriptorWithSymbolic
    /// Traits:2(traitBold) 重取（块体与 ReaderChapterTitleView.applyStyle
    /// ICF 合并，题名视图域按桥处理）。
    func resolvedUIFont(fontFamily: String) -> UIFont {
        let base: UIFont
        if fontFamily == "System" {
            base = .systemFont(ofSize: fontSize, weight: uiFontWeight)
        } else {
            base = UIFont(name: fontFamily, size: fontSize)
                ?? .systemFont(ofSize: fontSize, weight: uiFontWeight)
        }
        if fontWeightName == "bold" {
            if let descriptor = base.fontDescriptor
                .withSymbolicTraits(.traitBold) {
                return UIFont(descriptor: descriptor, size: fontSize)
            }
        }
        return base
    }
}

extension LayoutWidget {

    /// 伪代码 0x1001f0d6c（L230-250）：默认 widgets——五段阈值
    ///（0.12/0.37/0.62/0.87 域确证）选对齐档 + "battery." 前缀域
    ///（0x2E797265746162 确证）+ 百分比钳制 0...100（0x4059=100.0 域）；
    /// widget 集推断。
    static func defaultWidgets(
        screenHeight: CGFloat, safeTop: CGFloat, safeBottom: CGFloat
    ) -> [LayoutWidget] {
        let usable = max(screenHeight - safeTop - safeBottom, 1)
        let ratio = min(max(safeTop / usable, 0), 1)
        let alignment: WidgetTextAlignment
        switch ratio {
        case 0.0..<0.12: alignment = .leading
        case 0.12..<0.37: alignment = .center
        case 0.37..<0.62: alignment = .trailing
        case 0.62..<0.87: alignment = .leading
        default: alignment = .center
        }
        return [
            LayoutWidget(
                type: "battery", alignment: alignment, showOnFirstPage: true),
            LayoutWidget(
                type: "time", alignment: alignment, showOnFirstPage: true),
            LayoutWidget(
                type: "progress", alignment: alignment, showOnFirstPage: false),
        ]
    }
}

extension ReaderLayoutTemplate {

    /// 伪代码 0x1001f7ce0（L1070-1104）：模板预设 4 槽 widgets——槽位域
    ///（tag 1/2/4/4 + 水平比 0x3FB47AE147AE147B=0.08 / 0x3FE0=0.5 + 尺寸
    /// 0x4028=12.0 + 透明度 0x3FD3=0.3 + 首页显隐位确证；tag→类型映射推断）。
    func presetWidgets(
        screenHeight: CGFloat, safeTop: CGFloat, safeBottom: CGFloat
    ) -> [LayoutWidget] {
        _ = screenHeight
        _ = safeTop
        _ = safeBottom
        switch self {
        case .standard:
            return [
                LayoutWidget(
                    type: "progress", alignment: .leading,
                    showOnFirstPage: true),
                LayoutWidget(
                    type: "time", alignment: .leading,
                    showOnFirstPage: false),
                LayoutWidget(
                    type: "battery", alignment: .center,
                    showOnFirstPage: true),
                LayoutWidget(
                    type: "battery", alignment: .trailing,
                    showOnFirstPage: true),
            ]
        case .compact:
            return [
                LayoutWidget(
                    type: "progress", alignment: .leading,
                    showOnFirstPage: true),
            ]
        case .immersive:
            return []
        }
    }
}

extension ReaderLayoutCalculator {

    /// 伪代码 0x1001f5d10（L804-826）：窗口度量缺失 → 轮询等待
    ///（sub_100031A48 睡眠域；50×20ms 上限推断）。
    static func waitForWindowMetrics() async throws {
        for _ in 0..<50 {
            if resolveWindowMetrics() != nil { return }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
    }

    /// 伪代码 0x1001f49ac（L878-883）：窗口度量缓存清空。
    static func invalidateLayoutCache() {
        metricsLock.lock()
        defer { metricsLock.unlock() }
        cachedMetrics = nil
    }

    /// 伪代码 0x100227628（L1032-1045）：calculateLayout 全参链 → 内容区尺寸
    ///（CGRectGetHeight 域确证；chapterTitle/fontFamily 两参在 T-302 形态
    /// 中并入配置域）。
    static func getContentAreaSize(
        isFirstPage: Bool,
        chapterTitleConfig: ChapterTitleConfig,
        leftPageMargin: CGFloat,
        rightPageMargin: CGFloat,
        topInsetExtra: CGFloat,
        bottomInsetExtra: CGFloat,
        screenBounds: CGRect?,
        chapterTitle: String,
        fontFamily: String
    ) throws -> CGSize {
        _ = chapterTitle
        _ = fontFamily
        let bounds = screenBounds ?? UIScreen.main.bounds
        let layout = calculateLayout(
            isFirstPage: isFirstPage,
            chapterTitleConfig: chapterTitleConfig,
            leftPageMargin: leftPageMargin,
            rightPageMargin: rightPageMargin,
            topInsetExtra: topInsetExtra,
            bottomInsetExtra: bottomInsetExtra,
            screenBounds: bounds,
            safeAreaFrame: bounds)
        return layout.contentRect.size
    }
}

/// 章节标题高度缓存（0x1001f4818/0x1001f4c3c 域；MainActor executor 断言
/// 确证——"Leaflow/ReaderLayoutConfig.swift" L700 域）。
@MainActor
final class ChapterTitleHeightCache {

    static let shared = ChapterTitleHeightCache()
    private var heights: [String: CGFloat] = [:]
    /// 持久化宿主判定（clear 域 swift_weakLoadStrong 确证）。
    private var hasPersistHost: Bool = false

    /// 伪代码 0x1001f4818（L655-663）：0x88 槽位写入域。
    func setMeasuredHeight(_ height: CGFloat, for key: String) {
        heights[key] = height
    }

    /// 伪代码 0x1001f4c3c（L665-672）：宿主存在 → persistToDisk 尾调；
    /// 内存清空。
    func clear() {
        heights.removeAll()
        if hasPersistHost {
            persistToDisk()
        }
    }

    /// 持久化域（0x1001f4c3c 尾调确证；磁盘格式未解码——占位桥不冒充）。
    private func persistToDisk() {
        // 磁盘格式域未解码；格式确证后补齐（记入仍不清楚）。
    }
}

/// 阅读器展示项（isDynamic 0x100766880 / getContent 0x1001f12f0 域；块体为
/// 计数器桩/空串默认域确证，档位与文案推断）。
enum ReaderDisplayItem: String, CaseIterable {
    case time
    case battery
    case readingDuration
    case remainingDuration
    case chapterTitle
    case bookName
    case progress

    /// 伪代码 0x100766880（L285-294）：随时间/状态变化的展示项。
    var isDynamic: Bool {
        switch self {
        case .time, .battery, .readingDuration, .remainingDuration:
            return true
        default:
            return false
        }
    }

    /// 伪代码 0x1001f12f0（L348-423）：按上下文取展示内容（未知项 → 空串）。
    func getContent(context: ReaderDisplayContext) -> String {
        switch self {
        case .time:
            return context.timeText
        case .battery:
            return context.batteryFraction > 0
                ? "\(Int(context.batteryFraction * 100))%" : ""
        case .readingDuration:
            return context.readingDurationMinutes > 0
                ? "\(context.readingDurationMinutes) 分钟" : ""
        case .remainingDuration:
            guard let minutes = context.remainingMinutes, minutes > 0
            else { return "" }
            return "剩 \(minutes) 分钟"
        case .chapterTitle:
            return context.chapterTitle
        case .bookName:
            return context.bookName
        case .progress:
            return context.totalPages > 0
                ? "\(context.currentPageIndex + 1)/\(context.totalPages)" : ""
        }
    }
}

/// 阅读器展示上下文（0x100763d5c varinit 域：PageContentViewController
/// bookName/totalChapters ivar 域 + sub_1001F800C/60 分钟换算确证）。
struct ReaderDisplayContext {
    var bookName: String = ""
    var chapterTitle: String = ""
    var totalChapters: Int = 0
    var currentChapterIndex: Int = 0
    var currentPageIndex: Int = 0
    var totalPages: Int = 0
    var isScrollMode: Bool = false

    /// 伪代码 0x100763d5c（L437）：初始值 = 阅读时长跟踪估算
    ///（sub_1001F800C/60 分钟换算域确证）。
    var readingDurationMinutes: Int =
        Int(ReadingDurationTracker.shared.totalDuration / 60)

    /// 伪代码 0x1001f1068（L449-454）：电量比例（块体与 "HH:mm" 时间格式化
    /// 域 ICF 合并——0x6D6D3A4848 确证）；电量监控未启用 → 0。
    var batteryFraction: Double {
        UIDevice.current.isBatteryMonitoringEnabled
            ? Double(UIDevice.current.batteryLevel) / 100.0 : 0
    }

    /// 时间文案（batteryFraction 块体 "HH:mm" 格式化域对应消费）。
    var timeText: String = ""
    var remainingMinutes: Int?
}

// MARK: - 听书时长跟踪

/// 听书时长跟踪（0x1001f8e48/0x1001f9018/0x1001f9080/0x1001ef300 域；
/// 与 ReadingDurationTracker 同构，音频会话域）。
final class ListeningDurationTracker {

    static let shared = ListeningDurationTracker()
    private(set) var totalDuration: TimeInterval = 0
    private var sessionStart: TimeInterval?
    private var paused: Bool = false

    /// 伪代码 0x1001ef300（isActivelyTracking getter 域）。
    var isActivelyTracking: Bool { sessionStart != nil && !paused }

    /// 伪代码 0x1001f8e48（startSession 域）。
    func startSession() {
        sessionStart = ProcessInfo.processInfo.systemUptime
        paused = false
    }

    /// 伪代码 0x1001f9018（pauseSession 域）：会话中 → 累入总时长。
    func pauseSession() {
        guard let start = sessionStart, !paused else { return }
        totalDuration += max(ProcessInfo.processInfo.systemUptime - start, 0)
        paused = true
    }

    /// 伪代码 0x1001f9080（resumeSession 域）：暂停中 → 重置会话起点。
    func resumeSession() {
        guard sessionStart != nil, paused else { return }
        sessionStart = ProcessInfo.processInfo.systemUptime
        paused = false
    }
}

