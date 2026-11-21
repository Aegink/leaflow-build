// 原路径: ReadMain/Models/MangaModels.swift
// 证据:
//   - PGO: 7 个主函数（index/task_functions.csv T-1001-01 / MangaModels.swift），
//     地址：MangaPage.init(chapterIndex:pageIndex:imageURL:imageRequestContext:chapterTitle:...)
//     0x100632978 L27-34（MangaImageParser.extractImageURLs 调用确证）/
//     == infix 0x10024f6bc L36-38（+closure 0x10024fef0 L37）/
//     MangaImageRequestContext.init(source:book:) 0x10024f828 L56-60
//     （CharacterSet.whitespacesAndNewlines + trimmingCharacters 确证）/
//     imageDecodeRule.getter 0x10024f5e4+0x100308298+0x100315e7c L62-65（3 共体块）
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Models/MangaModels.c（727 行，7 块）
//   - 事实：MangaPage.init —— 从正文调 MangaImageParser.extractImageURLs(from:)
//     拆出图片 URL 列表；== —— 字段相等；RequestContext.init —— 从 source/book
//     取请求上下文；imageDecodeRule —— book/source 的解析规则字符串 trim 后返回
//     （空串 → nil 确证：v10 == 0 → nil）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - MangaPage/==: high（extractImageURLs 调用确证）
//   - RequestContext/imageDecodeRule: high（trim/空→nil 确证）
// 还原: 2026-11-19

import Foundation

/// 漫画页。
struct MangaPage: Identifiable, Equatable {
    let chapterIndex: Int
    let pageIndex: Int
    let imageURL: String
    let imageRequestContext: MangaImageRequestContext?
    let chapterTitle: String

    /// Identifiable 合成域（chapterIndex+pageIndex 稳定键）。
    var id: String { "\(chapterIndex)-\(pageIndex)" }

    /// 伪代码 0x100632978（L27-34）：从正文提取图片 URL
    ///（MangaImageParser.extractImageURLs(from:) 调用确证）。
    init(
        chapterIndex: Int,
        pageIndex: Int,
        imageURL: String,
        imageRequestContext: MangaImageRequestContext?,
        chapterTitle: String,
        content: String
    ) {
        self.chapterIndex = chapterIndex
        self.pageIndex = pageIndex
        self.imageURL = imageURL
        self.imageRequestContext = imageRequestContext
        self.chapterTitle = chapterTitle
        _ = MangaImageParser.extractImageURLs(from: content)
    }

    /// 伪代码 0x10024f6bc（L36-38 + closure 0x10024fef0）：字段相等。
    static func == (lhs: MangaPage, rhs: MangaPage) -> Bool {
        lhs.chapterIndex == rhs.chapterIndex
            && lhs.pageIndex == rhs.pageIndex
            && lhs.imageURL == rhs.imageURL
    }
}

/// 漫画图片请求上下文。
struct MangaImageRequestContext: Equatable {
    var source: BookSource?
    var book: Book?

    /// 伪代码 0x10024f828（L56-60）。
    init(source: BookSource?, book: Book) {
        self.source = source
        self.book = book
    }

    /// 伪代码 0x10024f5e4 等 3 个 ICF 共体块（L62-65）：
    /// 取书的图片解码规则（whitespacesAndNewlines trim 确证；空串 → nil，
    /// L382-391 v10 == 0 → nil 确证）。
    var imageDecodeRule: String? {
        guard let rule = book?.getImageDecodeRule() else { return nil }
        let trimmed = rule.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed
    }
}
