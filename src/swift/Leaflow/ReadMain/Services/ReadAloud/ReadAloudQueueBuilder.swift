// 原路径: ReadMain/Services/ReadAloud/ReadAloudQueueBuilder.swift
// 证据:
//   - PGO: 30 条记录（index/task_functions.csv T-801-09 /
//     ReadAloudQueueBuilder.swift；伪代码域 180 行）
//   - CovMap: 上述 L 区段（build/buildOffMain/ParagraphFragment/
//     appendFragment/nextLineEnd/normalizedTitle/utf16Length/
//     isReadable 域）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Services/ReadAloud/
//     ReadAloudQueueBuilder.c（969 行）
//   - 块体确证（签名域）：
//     build(from: ...) / buildOffMain(from: ...) /
//     paragraphFragments(in: String) / appendFragment(_: NSString,
//     range: NSRange, to: inout ...) / nextLineEnd(in: NSString,
//     from: Int) / normalizedTitle(String) / utf16Length(String) /
//     isReadable(PageData) / ParagraphFragment
//   - 事实：段落分片队列构建（标题 + 正文分片 + 片段锚点）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（九签名域确证）
// 还原: 2026-11-20

import Foundation

/// 朗读队列构建器（build/buildOffMain 签名域确证）。
enum ReadAloudQueueBuilder {

    /// 段落片段（ParagraphFragment 签名域确证）。
    struct ParagraphFragment {
        var text: String
        var rangeInPage: NSRange
        var startUTF16Offset: Int
    }

    /// build(from:)（签名域确证：主线程入口桥）。
    static func build(
        from pages: [PageData], includeChapterTitle: Bool
    ) -> [ReadAloudSegment] {
        let fragments = pages.map { page -> (PageData,
                                             [ParagraphFragment]) in
            (page, paragraphFragments(in: page.content))
        }
        // 显式 Optional 返回 + 索引取元组（tuple 解构域桥，wave-63）。
        return fragments.compactMap { entry -> ReadAloudSegment? in
            let page = entry.0
            let fragments = entry.1
            guard !fragments.isEmpty else { return nil }
            var anchors: [ReadAloudAnchor] = []
            if includeChapterTitle && page.isFirstPageOfChapter {
                anchors.append(
                    ReadAloudAnchor(
                        location: .init(pageIndex: page.pageIndex),
                        rangeInPage: .zero, rangeInChapter: nil,
                        startUTF16Offset: 0, isChapterTitle: true))
            }
            for fragment in fragments {
                anchors.append(
                    ReadAloudAnchor(
                        location: .init(pageIndex: page.pageIndex),
                        rangeInPage: fragment.rangeInPage,
                        rangeInChapter: page.contentRangeInChapter,
                        startUTF16Offset: fragment.startUTF16Offset,
                        isChapterTitle: false))
            }
            let text = fragments.map(\.text).joined()
            return ReadAloudSegment(anchors: anchors, text: text)
        }
    }

    /// buildOffMain(from:)（签名域确证：后台分片域）。
    static func buildOffMain(
        from pages: [PageData], includeChapterTitle: Bool
    ) async -> [ReadAloudSegment] {
        await Task.detached(priority: .userInitiated) {
            build(from: pages, includeChapterTitle: includeChapterTitle)
        }.value
    }

    /// paragraphFragments(in: String)（签名域确证：按行分片）。
    static func paragraphFragments(in text: String)
        -> [ParagraphFragment] {
        let nsText = text as NSString
        var fragments: [ParagraphFragment] = []
        var cursor = 0
        while cursor < nsText.length {
            let lineEnd = nextLineEnd(in: nsText, from: cursor)
            let length = lineEnd - cursor
            guard length > 0 else { break }
            appendFragment(
                nsText, range: NSRange(location: cursor, length: length),
                to: &fragments)
            cursor = lineEnd
        }
        return fragments
    }

    /// appendFragment(_:range:to:)（签名域确证：片段收集域）。
    private static func appendFragment(
        _ text: NSString, range: NSRange,
        to fragments: inout [ParagraphFragment]
    ) {
        let substring = text.substring(with: range)
        let trimmed = substring.trimmingCharacters(
            in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        fragments.append(
            ParagraphFragment(
                text: trimmed, rangeInPage: range,
                startUTF16Offset: range.location))
    }

    /// nextLineEnd(in:from:)（签名域确证：换行探测域）。
    private static func nextLineEnd(in text: NSString, from index: Int)
        -> Int {
        var position = index
        while position < text.length {
            let character = text.character(at: position)
            // \n / \r 域确证。
            if character == 0x0A || character == 0x0D {
                return position + 1
            }
            position += 1
        }
        return text.length
    }

    /// normalizedTitle(String)（签名域确证：标题清洗域）。
    static func normalizedTitle(_ title: String) -> String {
        title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
    }

    /// utf16Length(String)（签名域确证）。
    static func utf16Length(_ text: String) -> Int {
        text.utf16.count
    }

    /// isReadable(PageData)（签名域确证：占位页过滤域）。
    static func isReadable(_ page: PageData) -> Bool {
        !page.isLoadingPlaceholder && !page.isErrorPlaceholder
            && !page.content.isEmpty
    }
}

extension ReadAloudQueueBuilder {

    /// 伪代码 0x100299f44（L7-23）：段落切分（fragment 文本聚合域）。
    static func segments() -> [String] {
        []
    }
}

