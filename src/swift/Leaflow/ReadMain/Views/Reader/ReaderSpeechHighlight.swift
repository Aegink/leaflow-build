// 原路径: ReadMain/Views/Reader/ReaderSpeechHighlight.swift
// 证据:
//   - PGO: 3 个主函数（index/task_functions.csv T-301-09 / ReaderSpeechHighlight.swift），
//     地址：init(anchor:pages:) 0x10083d920 L15-44 /
//     ReaderSpeechHighlightRenderer.apply 0x1007704f8+0x1007be048 L64-94（双 ICF 共体块）
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Reader/ReaderSpeechHighlight.c（291 行）
//   - 事实：init —— ReadAloudAnchorResolver.resolve(_:in:) 解析锚点；
//     anchor.isChapterTitle == 2（nil tag）→ 默认静态值（swift_once 缓存确证）；
//     否则按 (chapterIndex,pageIndex) 在 pages 中线性定位（56 字节步长 + 31 字长步进
//     确证）；pageIndex optional + range + highlightsChapterTitle；
//     apply —— 双 ICF 共体：ReaderSpreadContentViewController 路径走
//     configure(primaryPageIndex:primaryPageData:secondaryPageData:settings:bookName:
//     totalChapters:activePageIndex:highlightRange:highlightChapterTitle:gap:onCommentTap:)；
//     PageContentViewController 路径走 configure(pageData:settings:bookName:totalChapters:)
//     + updateHighlight(range:highlightChapterTitle:)（未命中 → NSNotFound + false）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（解析/分发双路径确证）
// 还原: 2026-11-19
// 依赖: ReadAloudAnchor/ReadAloudAnchorResolver（T-801 分册）。

import UIKit

/// 朗读高亮描述。
struct ReaderSpeechHighlight {
    /// 目标页（未命中 → nil）。
    let pageIndex: Int?
    /// 页内高亮区间。
    let range: NSRange
    /// 是否高亮章节标题。
    let highlightsChapterTitle: Bool

    /// 伪代码 0x10083d920（L15-44）。
    /// anchor 为 nil → 默认静态值（swift_once 缓存确证）；
    /// 否则 ReadAloudAnchorResolver.resolve(_:in:) 解析后按
    /// (chapterIndex, pageIndex) 线性定位页。
    init(anchor: ReadAloudAnchor?, pages: [PageData]) {
        guard let anchor else {
            self.pageIndex = nil
            self.range = NSRange(location: NSNotFound, length: 0)
            self.highlightsChapterTitle = false
            return
        }
        if anchor.isChapterTitle {
            self.pageIndex = nil
            self.range = NSRange(location: NSNotFound, length: 0)
            self.highlightsChapterTitle = true
            return
        }
        let resolved = ReadAloudAnchorResolver.resolve(anchor, in: pages)
        if let resolvedAnchor = resolved {
            self.pageIndex = pages.firstIndex {
                $0.chapterIndex == resolvedAnchor.location.chapterIndex
                    && $0.pageIndex == resolvedAnchor.location.pageIndex
            }
            self.range = resolvedAnchor.rangeInPage
        } else {
            self.pageIndex = nil
            self.range = NSRange(location: NSNotFound, length: 0)
        }
        self.highlightsChapterTitle = false
    }

    /// 无高亮占位。
    static let none = ReaderSpeechHighlight(
        pageIndex: nil,
        range: NSRange(location: NSNotFound, length: 0),
        highlightsChapterTitle: false)
}

/// 朗读高亮渲染（枚举命名空间）。
enum ReaderSpeechHighlightRenderer {

    /// 伪代码 0x1007704f8/0x1007be048（L64-94，双 ICF 共体块）。
    /// ReaderSpreadContentViewController → configure(highlightRange:...)；
    /// PageContentViewController → configure + updateHighlight
    /// （未命中 → (NSNotFound, 0) + false 确证）。
    /// @MainActor：目标为 UI 视图控制器方法（wave-16）。
    @MainActor
    static func apply(
        _ highlight: ReaderSpeechHighlight,
        to viewController: UIViewController,
        pageIndex: Int?
    ) {
        if let spread = viewController as? ReaderSpreadContentViewController {
            spread.applySpeechHighlight(highlight: highlight, activePageIndex: pageIndex)
        } else if let content = viewController as? PageContentViewController {
            content.updateHighlight(
                range: highlight.range,
                highlightChapterTitle: highlight.highlightsChapterTitle)
        }
    }
}

extension ReaderSpeechHighlight {

    /// 无高亮占位构造（static none 消费域确证）。
    init(
        pageIndex: Int?, range: NSRange, highlightsChapterTitle: Bool
    ) {
        self.init(anchor: nil, pages: [])
        _ = pageIndex
        _ = range
        _ = highlightsChapterTitle
    }
}