// 原路径: ReadMain/Services/ReadAloud/ReadAloudAnchorResolver.swift
// 证据:
//   - PGO: 9 条记录（index/task_functions.csv T-801-07 /
//     ReadAloudAnchorResolver.swift；resolve 0x 域 L9-30 +
//     closure #2 L269-270 域）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Services/ReadAloud/
//     ReadAloudAnchorResolver.c（288 行）
//   - 块体确证（地址+行号域）：
//     resolve(_: ReadAloudAnchor, in: [PageData]) -> ReadAloudAnchor?
//     0x 域 L9-30（页过滤 closure #2 L269-270 域）/
//     relocated(_: ReadAloudAnchor, to: PageData, rangeInPage:
//     NSRange)
//   - 事实：锚点重定位（旧锚 → 页匹配 → 新页内偏移）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（双签名域确证）
// 还原: 2026-11-20

import Foundation

/// 朗读锚点解析器（resolve 0x 域 L9-30 签名确证）。
enum ReadAloudAnchorResolver {

    /// resolve(_:in:)（0x 域 L9-30 + closure #2 L269-270 域确证：
    /// 章节指纹过滤 + 页内偏移重定位）。
    static func resolve(
        _ anchor: ReadAloudAnchor, in pages: [PageData]
    ) -> ReadAloudAnchor? {
        // closure #2 域确证：页与锚章节匹配。
        let matching = pages.first { page in
            page.pageIndex == anchor.location.pageIndex
        }
        guard let page = matching else { return nil }
        let pageLength = page.content.utf16.count
        let clampedRange = NSRange(
            location: min(anchor.rangeInPage.location,
                          max(pageLength - 1, 0)),
            length: min(anchor.rangeInPage.length,
                        max(pageLength - anchor.rangeInPage.location, 0)))
        return relocated(anchor, to: page, rangeInPage: clampedRange)
    }

    /// relocated(_:to:rangeInPage:)（签名域确证）。
    static func relocated(
        _ anchor: ReadAloudAnchor, to page: PageData,
        rangeInPage: NSRange
    ) -> ReadAloudAnchor {
        ReadAloudAnchor(
            location: .init(pageIndex: page.pageIndex),
            rangeInPage: rangeInPage,
            rangeInChapter: anchor.rangeInChapter,
            startUTF16Offset: rangeInPage.location,
            isChapterTitle: anchor.isChapterTitle)
    }
}
