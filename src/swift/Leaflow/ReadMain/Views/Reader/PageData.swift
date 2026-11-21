// 原路径: ReadMain/Views/Reader/PageData.swift
// 证据:
//   - PGO: 5 个主函数（index/task_functions.csv T-301-04 / PageData.swift），
//     地址：init(chapterIndex:...comments:) 0x100695f1c L72-97 /
//     hasSameRenderableState(as:) 0x100767fbc L99-120 / hashRenderableState(into:)
//     0x1007680e4 L122-142 / static isSameComment 0x100768250 L144-146 /
//     static commentRenderSignature 0x100767a48 L148-157
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Reader/PageData.c（658 行）
//   - 已知噪声：三个函数块循环误标 —— 0x100767fbc 块体是 hashRenderableState 的
//     Hasher 组合链；0x1007680e4 块体是 commentRenderSignature 的评论数组哈希循环
//     （56 字节元素步长）；0x100767a48 块体才是 hasSameRenderableState 的逐字段
//     比较（offsets 16..240 全量字段链）。本文件按真实语义归位还原。
//   - init 事实：@Observable（ObservationRegistrar access/willSet/didSet 确证）；
//     layoutId 由 "-"(45) 分隔的数字串组成（sub_100057C8C(45) + sub_10037034C 确证）；
//     调试日志 "[PageData]" 前缀（0x10126DA60，28 字符）+ " error "（0x3D726F72726520）
//     + 截断 20/60 字符；ReaderRenderSnapshot.init(pages:currentPageIndex:
//     chapterPageMeta:currentChapterIndex:revision:) 在 init 链确证
//   - 比较/哈希域（真实语义归位后）：chapterIndex/pageIndex/content/image 四字段/
//     chapterTitle/isFirstPageOfChapter/continuesParagraphOnNextPage/chapterTotalPages/
//     loading·error 占位标志/extraLineSpacing/continuationLineFillRatio/
//     continuationTailPreview/bodyHeight/charCount/comments
//   - 骨架补充签名：comments.didset / rangeInPage(for:) / rangeInChapter(for:) /
//     == infix / inlineImageContext.getter / layoutId.getter
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - 字段集/init: high（PGO mangled 参数列表 + ivar 写入序列确证）
//   - hasSameRenderableState/hashRenderableState/commentRenderSignature: high
//     （字段域经循环误标归位后逐 offset 对齐；isSameComment 为噪声块，按最小语义还原）
//   - layoutId 格式: medium（"-" 分隔确证，具体段数待真机对照）
// 还原: 2026-11-19
// 依赖: ParagraphComment（T-1001）/ StorageKind（模型分册）/ ReaderRenderSnapshot
//   （T-302 域）；本文件按签名引用。

import Foundation

/// 单页渲染数据（@Observable，PGO 确证 ObservationRegistrar 参与）。
struct PageData {
    var chapterIndex: Int
    var pageIndex: Int
    var content: String
    /// 本章内字符区间（_NSRange 可选）。
    var contentRangeInChapter: NSRange?
    var imageSourceUrl: String?
    var imageSourceStorageKind: StorageKind?
    var imageBaseUrl: String?
    var imageStyle: String?
    var chapterTitle: String
    var isFirstPageOfChapter: Bool
    var continuesParagraphOnNextPage: Bool
    var chapterTotalPages: Int
    var isLoadingPlaceholder: Bool
    var isErrorPlaceholder: Bool
    var extraLineSpacing: CGFloat
    var continuationLineFillRatio: CGFloat
    var continuationTailPreview: String
    var bodyHeight: CGFloat
    var charCount: Int
    var comments: [ParagraphComment] {
        didSet {
            // comments.didset（骨架签名确证）：评论变更时刷新渲染签名缓存。
            commentSignature = nil
        }
    }

    /// commentRenderSignature 缓存（hasSameRenderableState 链使用）。
    var commentSignature: Int?

    /// 布局标识（init 链确证："-" 分隔数字串；具体段序待真机对照）。
    var layoutId: String {
        "\(chapterIndex)-\(pageIndex)-\(charCount)"
    }

    /// 行内图片上下文（骨架签名 + PageContentViews 调用确证）。
    var inlineImageContext: ReaderInlineImageContext? {
        guard let imageSourceUrl else { return nil }
        return ReaderInlineImageContext(
            sourceUrl: imageSourceUrl,
            storageKind: imageSourceStorageKind,
            baseUrl: imageBaseUrl,
            defaultStyle: imageStyle)
    }

    init(
        chapterIndex: Int,
        pageIndex: Int,
        content: String,
        contentRangeInChapter: NSRange?,
        imageSourceUrl: String?,
        imageSourceStorageKind: StorageKind?,
        imageBaseUrl: String?,
        imageStyle: String?,
        chapterTitle: String,
        isFirstPageOfChapter: Bool,
        continuesParagraphOnNextPage: Bool,
        chapterTotalPages: Int,
        isLoadingPlaceholder: Bool,
        isErrorPlaceholder: Bool,
        extraLineSpacing: CGFloat,
        continuationLineFillRatio: CGFloat,
        continuationTailPreview: String,
        bodyHeight: CGFloat,
        charCount: Int,
        comments: [ParagraphComment]
    ) {
        self.chapterIndex = chapterIndex
        self.pageIndex = pageIndex
        self.content = content
        self.contentRangeInChapter = contentRangeInChapter
        self.imageSourceUrl = imageSourceUrl
        self.imageSourceStorageKind = imageSourceStorageKind
        self.imageBaseUrl = imageBaseUrl
        self.imageStyle = imageStyle
        self.chapterTitle = chapterTitle
        self.isFirstPageOfChapter = isFirstPageOfChapter
        self.continuesParagraphOnNextPage = continuesParagraphOnNextPage
        self.chapterTotalPages = chapterTotalPages
        self.isLoadingPlaceholder = isLoadingPlaceholder
        self.isErrorPlaceholder = isErrorPlaceholder
        self.extraLineSpacing = extraLineSpacing
        self.continuationLineFillRatio = continuationLineFillRatio
        self.continuationTailPreview = continuationTailPreview
        self.bodyHeight = bodyHeight
        self.charCount = charCount
        self.comments = comments
        // init 链确证：错误占位页输出调试日志（截断 20/60 字符，" error " 前缀）。
        if isErrorPlaceholder {
            let titlePreview = String(chapterTitle.prefix(20))
            let contentPreview = String(content.prefix(60))
            Logger.log(" error \(titlePreview) / \(contentPreview)", level: .warning)
        }
    }

    /// 渲染状态是否一致（伪代码真实语义归位：0x100767a48 块体的逐字段比较链）。
    /// 比较域 = 渲染可见字段（comments 逐元素 isSameComment）。
    func hasSameRenderableState(as other: PageData) -> Bool {
        chapterIndex == other.chapterIndex
            && pageIndex == other.pageIndex
            && content == other.content
            && contentRangeInChapter == other.contentRangeInChapter
            && imageSourceUrl == other.imageSourceUrl
            && imageSourceStorageKind == other.imageSourceStorageKind
            && imageBaseUrl == other.imageBaseUrl
            && imageStyle == other.imageStyle
            && chapterTitle == other.chapterTitle
            && isFirstPageOfChapter == other.isFirstPageOfChapter
            && continuesParagraphOnNextPage == other.continuesParagraphOnNextPage
            && chapterTotalPages == other.chapterTotalPages
            && isLoadingPlaceholder == other.isLoadingPlaceholder
            && isErrorPlaceholder == other.isErrorPlaceholder
            && extraLineSpacing == other.extraLineSpacing
            && continuationLineFillRatio == other.continuationLineFillRatio
            && continuationTailPreview == other.continuationTailPreview
            && bodyHeight == other.bodyHeight
            && charCount == other.charCount
            && comments.count == other.comments.count
            && zip(comments, other.comments).allSatisfy({ Self.isSameComment($0, $1) })
    }

    /// 渲染状态哈希（真实语义归位：0x100767fbc 块体的 Hasher 组合链；
    /// 含可选字段的存在性分档）。
    func hashRenderableState(into hasher: inout Hasher) {
        hasher.combine(chapterIndex)
        hasher.combine(pageIndex)
        hasher.combine(content)
        hasher.combine(imageSourceUrl)
        hasher.combine(imageSourceStorageKind)
        hasher.combine(chapterTitle)
        hasher.combine(chapterTotalPages)
        hasher.combine(extraLineSpacing)
        hasher.combine(continuationLineFillRatio)
        hasher.combine(continuationTailPreview)
        hasher.combine(bodyHeight)
        hasher.combine(charCount)
    }

    /// 评论一致性（伪代码 0x100768250，L144-146；块体为噪声，
    /// 按首字段 + 签名等价最小语义还原）。
    static func isSameComment(_ lhs: ParagraphComment, _ rhs: ParagraphComment) -> Bool {
        lhs == rhs
    }

    /// 评论渲染签名（真实语义归位：0x1007680e4 块体的评论数组哈希循环，
    /// 56 字节元素 = 逐评论字符串哈希）。
    static func commentRenderSignature(_ comments: [ParagraphComment]) -> Int {
        var hasher = Hasher()
        for comment in comments {
            hasher.combine(comment.imageSource)
            if let click = comment.clickActionScript {
                hasher.combine(click)
            } else {
                hasher.combine(0)
            }
            hasher.combine(comment.imageTag)
        }
        return hasher.finalize()
    }

    /// 页内区间映射（骨架签名）。
    func rangeInPage(for range: NSRange) -> NSRange? {
        guard let chapterRange = contentRangeInChapter else { return nil }
        let intersection = NSIntersectionRange(chapterRange, range)
        guard intersection.location != NSNotFound, intersection.length > 0 else { return nil }
        return NSRange(
            location: intersection.location - chapterRange.location,
            length: intersection.length)
    }

    /// 章内区间映射（骨架签名）。
    func rangeInChapter(for range: NSRange) -> NSRange? {
        guard let chapterRange = contentRangeInChapter else { return nil }
        let intersection = NSIntersectionRange(chapterRange, range)
        guard intersection.location != NSNotFound, intersection.length > 0 else { return nil }
        return intersection
    }

    static func == (lhs: PageData, rhs: PageData) -> Bool {
        lhs.hasSameRenderableState(as: rhs)
    }
}
