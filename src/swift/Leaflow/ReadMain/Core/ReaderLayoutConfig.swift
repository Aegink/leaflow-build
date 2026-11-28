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
enum WidgetPageScope: String, Codable, CaseIterable {
    case allPages, firstPageOnly, normalPageOnly

    /// 类型表3152与0x1007664b4：首章页/普通页/所有页。
    func shouldShow(isFirstPage: Bool) -> Bool {
        switch self {
        case .allPages: return true
        case .firstPageOnly: return isFirstPage
        case .normalPageOnly: return !isFirstPage
        }
    }
}

/// Widget 文本对齐。
enum WidgetTextAlignment: String, Codable {
    case leading = "left"
    case center
    case trailing = "right"

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

// MARK: - 阅读器布局计算器

/// Widget 布局配置。
/// refreshCadence 为计算推导（ReaderWidgetRefreshDriver 扩展域确证：
/// 按类型映射节流档，wave-16 撤销误加的存储字段）。

/// 章节标题排版配置（Codable：T-1401-01 ChapterTitlePreset 双档解码桥）。
struct ChapterTitleConfig: Codable, Equatable {
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
    /// 设计器 HTML 模板（ChapterTitleSettingsView 设计器载荷写入域确证，
    /// wave-16 补成员）。
    var templateHTML: String? = nil
    /// 样式名（导出 styleName 消费域确证，wave-16 补成员）。
    var styleName: String? = nil
}

/// 阅读布局模板（T-1401-01 applyLayoutTemplate 0x100221ef8 域桥；档位推断，
/// presetWidgets/defaultWidgets 域随 T-1401-02 还原）。
/// single：PageContentViews.updateFrames 消费域确证（单页渲染域档），
/// preset 集复用 standard（还原推断）。
enum ReaderLayoutTemplate: String, Codable, CaseIterable {
    case standard
    case compact
    case immersive
    case single
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

    /// 伪代码 0x1001f49ac（L878-883）：窗口度量缓存清空。
    static func invalidateLayoutCache() {
        metricsLock.lock()
        defer { metricsLock.unlock() }
        cachedMetrics = nil
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
        safeAreaFrame: CGRect,
        chapterTitle: String = ""
    ) -> ReaderLayoutResult {
        // 0x1001f6b68：显式screenBounds优先；不能被另一窗口的缓存覆盖。
        return buildResult(
            isFirstPage: isFirstPage,
            config: chapterTitleConfig,
            leftMargin: leftPageMargin,
            rightMargin: rightPageMargin,
            topExtra: topInsetExtra,
            bottomExtra: bottomInsetExtra,
            bounds: screenBounds,
            safeArea: safeAreaFrame,
            chapterTitle: chapterTitle
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
        safeArea: CGRect,
        chapterTitle: String
    ) -> ReaderLayoutResult {
        // contentRect：从 bounds 减去 margins（伪代码 sub_1001FB92C 调用族）。
        let contentX = bounds.minX + leftMargin
        let contentWidth = max(1, bounds.width - leftMargin - rightMargin)

        // 标题高度计算（伪代码：boundingRectWithSize:options:3）。
        var titleHeight: CGFloat = 0
        if isFirstPage, let config, config.isEnabled, !chapterTitle.isEmpty {
            let font = config.resolvedUIFont(fontFamily: config.fontName)
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = config.textAlignment
            paragraphStyle.lineBreakMode = .byWordWrapping
            paragraphStyle.lineBreakStrategy = []
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .paragraphStyle: paragraphStyle,
            ]
            let titleText = chapterTitle as NSString
            let boundingRect = titleText.boundingRect(
                with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attributes,
                context: nil
            )
            titleHeight = ceil(boundingRect.height)
        }

        // 安全区叠加（伪代码：safeArea 偏移叠加到 top/bottom inset）。
        let topInset = max(0, safeArea.minY - bounds.minY) + topExtra
        let bottomInset = max(0, bounds.maxY - safeArea.maxY) + bottomExtra

        let contentRect = CGRect(
            x: contentX,
            y: bounds.minY + topInset + titleHeight,
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

}

