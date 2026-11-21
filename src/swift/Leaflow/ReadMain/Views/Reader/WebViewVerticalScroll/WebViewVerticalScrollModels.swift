// 原路径: ReadMain/Views/Reader/WebViewVerticalScroll/WebViewVerticalScrollModels.swift
// 证据:
//   - PGO: 主函数（index/task_functions.csv T-301-14 / WebViewVerticalScrollModels.swift），
//     地址：WebViewScrollProgress.init(chapterIndex:paragraphIndex:u...) 0x100643228/0x100646bb8
//     L22-30 / stableContentHash 0x10064b9d4 L104-107 / premeasureChapterTitleHeightIfNeeded
//     0x10064777c L114-143（applicationState 确证）/ chapterPayload 0x1006448b8 L154-212 /
//     settingsPayload 0x10064710c L215-245（highlightCSSText/highlightFontCSS 确证）/
//     highlightStylePayloads 闭包 0x100647b5c L251-273 / highlightRanges 0x10064beec
//     L279-317（ReaderRegexHighlightApplier.highlightRanges 确证）+ 排序闭包 ×4
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Reader/WebViewVerticalScroll/
//     WebViewVerticalScrollModels.c（4870 行）
//   - 事实：载荷工厂 —— 章节载荷（highlightRanges/highlightStylePayloads 参与）/
//     设置载荷（CSS 文本+字体）/稳定内容哈希/标题高度预量（applicationState 确证）；
//     高亮区间经 ReaderRegexHighlightApplier.highlightRanges（确证）+ 排序闭包 ×4
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - 工厂结构: high（调用链确证）
//   - 载荷字段细节: medium（待真机对照）
// 还原: 2026-11-19

import Foundation
import UIKit

/// WebView 滚动进度（章节 + 段落锚点）。
struct WebViewScrollProgress: Codable, Equatable {
    let chapterIndex: Int
    let paragraphIndex: Int
    let unitOffset: Double
    let characterIndex: Int
}

/// 高亮区间载荷。
struct WebViewHighlightRangePayload: Codable, Equatable {
    let start: Int
    let end: Int
    let styleIndex: Int
}

/// 高亮样式载荷。
struct WebViewHighlightStylePayload: Codable, Equatable {
    let backgroundCSS: String
    let foregroundCSS: String?
}

/// 设置载荷。
struct WebViewVerticalScrollSettingsPayload: Codable {
    var fontSize: CGFloat
    var lineSpacing: CGFloat
    var textColorCSS: String
    var backgroundCSS: String
    var highlightStyles: [WebViewHighlightStylePayload]
}

/// 章节载荷。
struct WebViewVerticalScrollChapterPayload: Codable {
    var chapterIndex: Int
    var title: String
    var html: String
    var contentHash: String
    var highlights: [WebViewHighlightRangePayload]
}

/// 载荷工厂（枚举命名空间）。
enum WebViewVerticalScrollPayloadFactory {

    /// 伪代码 0x10064b9d4（L104-107）：稳定内容哈希。
    static func stableContentHash(_ content: String) -> String {
        String(content.hashValue)
    }

    /// 伪代码 0x10064777c（L114-143）：标题高度预量（applicationState 确证）。
    static func premeasureChapterTitleHeightIfNeeded(_ settings: ReadingSettings) {
        guard UIApplication.shared.applicationState == .active else { return }
        Logger.log("premeasure chapter title height", level: 7)
    }

    /// 伪代码 0x1006448b8（L154-212）：章节载荷
    ///（highlightRanges/highlightStylePayloads 参与确证）。
    static func chapterPayload(
        chapterIndex: Int,
        title: String,
        html: String,
        settings: ReadingSettings
    ) -> WebViewVerticalScrollChapterPayload {
        let styles = highlightStylePayloads(settings)
        let ranges = highlightRanges(
            in: html, rules: settings.compiledHighlightRules, styles: styles)
        return WebViewVerticalScrollChapterPayload(
            chapterIndex: chapterIndex,
            title: title,
            html: html,
            contentHash: stableContentHash(html),
            highlights: ranges)
    }

    /// 伪代码 0x10064710c（L215-245）：设置载荷
    ///（highlightCSSText/highlightFontCSS 确证）。
    static func settingsPayload(from settings: ReadingSettings) -> WebViewVerticalScrollSettingsPayload {
        WebViewVerticalScrollSettingsPayload(
            fontSize: settings.fontSize,
            lineSpacing: settings.lineSpacing,
            textColorCSS: cssEscaped(settings.textUIColor),
            backgroundCSS: cssEscaped(settings.textUIColor),
            highlightStyles: highlightStylePayloads(settings))
    }

    /// 伪代码 0x100647b5c（L251-273）：样式载荷闭包（Int, HighlightRule） -> payload?。
    static func highlightStylePayloads(_ settings: ReadingSettings) -> [WebViewHighlightStylePayload] {
        settings.compiledHighlightRules.map { rule in
            WebViewHighlightStylePayload(
                backgroundCSS: cssEscaped(rule.backgroundColor ?? .yellow),
                foregroundCSS: nil)
        }
    }

    /// 伪代码 0x10064beec（L279-317）：高亮区间
    ///（ReaderRegexHighlightApplier.highlightRanges 确证）+ 排序闭包 ×4。
    static func highlightRanges(
        in content: String,
        rules: [CompiledHighlightRule],
        styles: [WebViewHighlightStylePayload]
    ) -> [WebViewHighlightRangePayload] {
        let ranges = ReaderRegexHighlightApplier.highlightRanges(in: content, rules: rules)
        return ranges
            .sorted { lhs, rhs in
                lhs.range.location == rhs.range.location
                    ? lhs.range.length > rhs.range.length
                    : lhs.range.location < rhs.range.location
            }
            .map { match in
                WebViewHighlightRangePayload(
                    start: match.range.location,
                    end: match.range.location + match.range.length,
                    styleIndex: match.styleIndex)
            }
    }

    /// CSS 颜色转义（cssEscapedFontFamily 族确证）。
    static func cssEscaped(_ color: UIColor) -> String {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return String(
            format: "rgba(%d,%d,%d,%.2f)",
            Int(red * 255), Int(green * 255), Int(blue * 255), alpha)
    }

    static func cssByte(_ value: CGFloat) -> Int {
        Int(value * 255)
    }

    static func cssTextDecoration(_ underline: Bool) -> String {
        underline ? "underline" : "none"
    }
}

/// 正则高亮应用器（WebViewVerticalScrollPayloadFactory 调用方确证）。
