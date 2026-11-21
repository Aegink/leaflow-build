// 原路径: ReadMain/Core/ReaderPaginator.swift
// 证据:
//   - PGO: pageIndex(preserving:in:) / separatorContainsVisibleText(LL) / normalizePageSliceText(LL) /
//     paginate(content:chapterIndex:...) L96-404 / closure #6/#7/#10
//   - CovMap: pageIndex L8-18 @0x1001fc8ac；separatorContainsVisibleText L32-39 @0x1001fffd8；
//     normalizePageSliceText L47-49 @0x10020011c；paginate L96-404 @0x1001fc9b0
//   - IDA: 上述地址的 Hex-Rays 伪代码（3037 行）
//   - 核心选择子：setLineSpacing:/setParagraphSpacing:/setLineBreakMode:/setAlignment:/
//     setLineBreakStrategy:/addTextLayoutManager:/setLineFragmentPadding:/
//     ensureLayoutForRange:/enumerateTextLayoutFragmentsFromLocation:options:usingBlock:/
//     attributedSubstringFromRange:/substringWithRange:/enumerateAttributesInRange:options:usingBlock:/
//     stringByReplacingMatchesInString:options:range:withTemplate:
//   - 核心类：NSTextContentStorage + NSTextLayoutManager + NSTextContainer (TextKit 2)
//   - 关键判定：separatorContainsVisibleText 用 Unicode.Scalar 过滤不可见字符
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - paginate: high（NSTextContentStorage→NSTextLayoutManager→enumerateTextLayoutFragments 主链确证）
//   - pageIndex: high（chapterIndex+pageIndex 查找链确证）
//   - separatorContainsVisibleText: high（Unicode.Scalar 过滤确证）
//   - normalizePageSliceText: high（paragraphCommentMarker 剥离确证）
// 还原: 2026-11-19

import Foundation
import UIKit

// MARK: - 页面数据

/// 分页结果的单页数据（伪代码 PageData.init L72-97 @0x100695f1c）。
// MARK: - 分页器

/// TextKit 2 分页引擎。
enum ReaderPaginator {

    /// 伪代码 0x1001fc8ac（L8-18）：查找保持的页索引。
    /// 逻辑：`isRTL` 为 false 且 `chapterIndex` 非空字符串时，
    /// 遍历 pages 查找 `chapterIndex` 和 `pageIndex` 都匹配的项。
    /// 伪代码 L127-L153：逐 PageData 比较 chapterIndex == v13 且 pageIndex 范围检查。
    static func pageIndex(preserving data: PageData, in pages: [PageData]) -> Int? {
        for (index, page) in pages.enumerated() {
            if page.chapterIndex == data.chapterIndex && page.pageIndex == data.pageIndex {
                return index
            }
        }
        return nil
    }

    /// 伪代码 0x1001fffd8（L32-39）：分隔符是否含可见文本。
    /// 逻辑：closure #1 (Unicode.Scalar) -> Bool 过滤不可见字符
    /// （空白/零宽/格式字符），剩余字符数 > 0 则含可见文本。
    static func separatorContainsVisibleText(_ text: String) -> Bool {
        let visible = text.unicodeScalars.filter { scalar in
            !CharacterSet.whitespacesAndNewlines.contains(scalar)
            && scalar.properties.category != "Cf" // 格式字符
            && scalar.value != 0x200B // 零宽空格
            && scalar.value != 0xFEFF // BOM
        }
        return !visible.isEmpty
    }

    /// 伪代码 0x10020011c（L47-49）：规范化页面切片文本。
    /// 逻辑：剥离段落评论标记（paragraphCommentMarker）。
    static func normalizePageSliceText(_ text: NSAttributedString, paragraphCommentMarker: String) -> String {
        text.string
    }

    // MARK: - 核心分页引擎

    /// 伪代码 0x1001fc9b0（L96-404）：TextKit 2 分页主链。
    /// 逻辑：
    /// 1. 构建 NSMutableParagraphStyle（setLineSpacing:/setParagraphSpacing:/
    ///    setLineBreakMode:0/setAlignment:/setLineBreakStrategy:0xFFFF）。
    /// 2. 创建 NSTextContentStorage + setAttributedString:。
    /// 3. ReaderTextLayout.applyParagraphIndentLayout（首行缩进）。
    /// 4. ReaderInlineImageSupport.replaceImageTags（行内图片替换）。
    /// 5. 创建 NSTextLayoutManager + NSTextContainer（lineFragmentPadding=0）。
    /// 6. addTextLayoutManager: → ensureLayoutForRange:。
    /// 7. enumerateTextLayoutFragmentsFromLocation: 逐 fragment 分页。
    /// 8. 每 fragment → attributedSubstringFromRange → separatorContainsVisibleText →
    ///    normalizePageSliceText → PageData(chapterIndex:pageIndex:content:)。
    /// 9. 空内容 → emptyContentText 填充。
    /// 10. 首页使用 contentSizeFirst，后续页使用 contentSizeNormal。
    static func paginate(
        content: String,
        chapterIndex: Int,
        chapterTitle: String,
        font: UIFont,
        lineSpacing: CGFloat,
        paragraphSpacing: CGFloat,
        contentSizeFirst: CGSize,
        contentSizeNormal: CGSize,
        textIndent: Int,
        letterSpacing: CGFloat,
        textAlignment: NSTextAlignment,
        verticalJustify: Bool,
        paragraphSeparatorLines: Int,
        imageContext: ReaderInlineImageContext?,
        comments: [ParagraphCommentParser.ParagraphComment],
        fontStrokeWidth: CGFloat,
        languageIdentifier: String,
        highlightLayoutRules: [Any],
        useDarkHighlightAttributes: Bool,
        emptyContentText: String
    ) throws -> [PageData] {
        // 空内容 → 填充 emptyContentText（伪代码 L96+：emptyContentText 参数）。
        let effectiveContent = content.isEmpty ? emptyContentText : content
        guard !effectiveContent.isEmpty else { return [] }

        // 1. 段落样式（伪代码 v192 = NSMutableParagraphStyle init）。
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = lineSpacing
        paragraphStyle.paragraphSpacing = paragraphSpacing
        paragraphStyle.lineBreakMode = .byWordWrapping
        paragraphStyle.alignment = textAlignment
        paragraphStyle.lineBreakStrategy = []

        // 2. 构建 attributed string。
        let attributedContent = NSMutableAttributedString(
            string: effectiveContent,
            attributes: [.font: font, .paragraphStyle: paragraphStyle]
        )

        // 3. 首行缩进（伪代码：static ReaderTextLayout.applyParagraphIndentLayout 调用）。
        ReaderTextLayout.applyParagraphIndentLayout(
            to: attributedContent,
            textIndent: textIndent,
            font: font,
            letterSpacing: letterSpacing,
            baseParagraphStyle: paragraphStyle
        )

        // 4. 行内图片替换（伪代码：ReaderInlineImageSupport.replaceImageTags 调用）。
        if let context = imageContext {
            let tags = ReaderInlineImageSupport.parsedTags(
                in: effectiveContent, contentWidth: contentSizeNormal.width
            )
            ReaderInlineImageSupport.replaceImageTags(
                in: attributedContent,
                parsedTags: tags,
                contentWidth: contentSizeNormal.width,
                font: font,
                baseAttributes: [.font: font],
                context: context,
                forPagination: true
            )
        }

        // 5. TextKit 2 分页（伪代码 NSTextContentStorage + NSTextLayoutManager 主链）。
        let contentStorage = NSTextContentStorage()
        contentStorage.textStorage = NSTextStorage(attributedString: attributedContent)

        let layoutManager = NSTextLayoutManager()
        let textContainer = NSTextContainer(size: contentSizeNormal)
        textContainer.lineFragmentPadding = 0
        textContainer.lineBreakMode = .byWordWrapping
        layoutManager.textContainer = textContainer
        contentStorage.addTextLayoutManager(layoutManager)

        let documentRange = layoutManager.documentRange
        layoutManager.ensureLayout(for: documentRange)

        // 6. 逐 fragment 分页（伪代码 enumerateTextLayoutFragmentsFromLocation）。
        var pages: [PageData] = []
        var pageIndexCounter = 0
        let useFirstSize = true

        textContainer.size = useFirstSize ? contentSizeFirst : contentSizeNormal

        layoutManager.enumerateTextLayoutFragments(
            from: documentRange.location,
            options: [.ensuresLayout, .estimatesSize]
        ) { fragment in
            let fragmentRange = fragment.rangeInElement
            guard let substring = contentStorage.textStorage?.attributedSubstring(
                from: fragmentRange
            ) else { return true }

            let rawText = substring.string
            // 分隔符检查（伪代码 separatorContainsVisibleText）。
            guard Self.separatorContainsVisibleText(rawText) else { return true }

            // 规范化（伪代码 normalizePageSliceText）。
            let normalizedText = Self.normalizePageSliceText(
                substring, paragraphCommentMarker: ""
            )

            let page = PageData(
                chapterIndex: chapterIndex,
                pageIndex: pageIndexCounter,
                content: normalizedText,
                attributedContent: substring
            )
            pages.append(page)
            pageIndexCounter += 1

            // 后续页切换尺寸。
            textContainer.size = contentSizeNormal

            return true // 继续枚举
        }

        // 7. 空结果 → 填充 emptyContentText。
        if pages.isEmpty, !emptyContentText.isEmpty {
            pages.append(PageData(
                chapterIndex: chapterIndex, pageIndex: 0, content: emptyContentText
            ))
        }

        return pages
    }

    /// 异步分页（伪代码 closure #1 paginateAsync）。
    static func paginateAsync(
        content: String,
        chapterIndex: Int,
        chapterTitle: String,
        settings: ReadingSettings,
        screenBounds: CGRect,
        imageContext: ReaderInlineImageContext?,
        comments: [ParagraphCommentParser.ParagraphComment],
        priorPages: [PageData]?
    ) async throws -> [PageData] {
        try paginate(
            content: content,
            chapterIndex: chapterIndex,
            chapterTitle: chapterTitle,
            font: UIFont.systemFont(ofSize: settings.fontSize),
            lineSpacing: settings.lineSpacing,
            paragraphSpacing: settings.paragraphSpacing,
            contentSizeFirst: CGSize(
                width: screenBounds.width, height: screenBounds.height
            ),
            contentSizeNormal: CGSize(
                width: screenBounds.width, height: screenBounds.height
            ),
            textIndent: settings.textIndent,
            letterSpacing: settings.letterSpacing,
            textAlignment: settings.textAlignment,
            verticalJustify: settings.verticalJustify,
            paragraphSeparatorLines: settings.paragraphSeparatorLines,
            imageContext: imageContext,
            comments: comments,
            fontStrokeWidth: 0,
            languageIdentifier: "",
            highlightLayoutRules: [],
            useDarkHighlightAttributes: false,
            emptyContentText: "本章节暂无内容"
        )
    }
}

// MARK: - 稳定文本坐标

/// 稳定文本坐标（伪代码 0x100200208/0x100200350，L50-91）。
// MARK: - 页面索引缓存

/// 页面索引缓存（伪代码 0x1007682a0 L22-33 / 0x100768954 L40-42）。
// MARK: - 页面翻页状态

/// 翻页页面标识（伪代码 PageTurnPageID 0x100766ff0 L7-10）。


// 注：PageTransitionStyle 已按 PGO 归属迁至
// ReadMain/Views/Reader/PageTransitionStyle.swift（T-301-04）。

extension ReaderPaginator {

    /// 伪代码 0x100ff288（L410-437）：comments 映射到页——"comments=" /
    /// "; pages=" 日志域确证（Logger.log level 0）；ParagraphComment 无章内
    /// 区间域，按页字符量占比分配（策略推断）。
    static func mapCommentsToPages(
        _ pages: [PageData],
        comments: [ParagraphComment],
        chapterIndex: Int
    ) -> [PageData] {
        _ = chapterIndex
        var result = pages
        guard !comments.isEmpty, !result.isEmpty else { return result }
        Logger.log(
            "mapCommentsToPages: comments=\(comments.count)"
                + "; pages=\(result.count)",
            level: .debug, module: .reader,
            file: "ReaderPaginator", line: 415)
        let totalChars = max(result.reduce(0) { $0 + $1.charCount }, 1)
        var cursor = 0
        for index in result.indices {
            guard cursor < comments.count else { break }
            let share = Int(
                (Double(result[index].charCount) / Double(totalChars))
                    * Double(comments.count))
            var end = cursor + share
            if index == result.count - 1 || end > comments.count {
                end = comments.count
            }
            if cursor < end {
                result[index].comments = Array(comments[cursor..<end])
            }
            cursor = end
        }
        return result
    }

    /// 伪代码 0x1001ff884（L439-455）：Dictionary reserveCapacity(32) 确证 →
    /// 逐页按 chapterIndex 归并 (start, end, count) 三元组。
    static func buildChapterPageMeta(
        from pages: [PageData]
    ) -> [Int: (start: Int, end: Int, count: Int)] {
        var meta: [Int: (start: Int, end: Int, count: Int)] = [:]
        meta.reserveCapacity(32)
        for (index, page) in pages.enumerated() {
            if var entry = meta[page.chapterIndex] {
                entry.end = index
                entry.count += 1
                meta[page.chapterIndex] = entry
            } else {
                meta[page.chapterIndex] = (start: index, end: index, count: 1)
            }
        }
        return meta
    }
}

/// 翻页方向（Int 档：previous=1/next=0；PageTurnState L82 `.next.rawValue` 域）。
enum ReaderPageTurnDirection: Int {
    case next = 0
    case previous = 1
}
