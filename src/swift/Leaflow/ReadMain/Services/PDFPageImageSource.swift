// 原路径: ReadMain/Services/PDFPageImageSource.swift
// 证据:
//   - PGO: 11 个主函数（index/task_functions.csv T-304-02 / PDFPageImageSource.swift），
//     地址：inspectDocument(at:) 0x10036381c L49-60 / parse(String) 0x100363ed8
//     L30-42 / renderPage(document:pageIndex:maxPixelSize:) 0x10036402c L108-137
//     （closure UIGraphicsImageRendererContext 0x1003651bc L125-136 确证）/
//     directoryChapters(at:pageCount:) 0x1003644bc L62-106（outlineRoot + visit #1
//     0x1003648f4 L71-87 确证）/ makeURL(bookId:fileName:pageIndex:) closure
//     0x100364788 L27 / pageDirectory closure（0x100365c54 L147-154）/ 排序闭包
//     0x1003633cc L93-96（(title, pageIndex, order) 元组比较确证）
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Services/PDFPageImageSource.c
//   - 事实：pdf:// URL 形态（makeURL(bookId:fileName:pageIndex:) 签名确证）；
//     目录链 —— PDFDocument.outlineRoot → visit 递归（depth 参与确证）→
//     (title, pageIndex, order) 元组排序（closure 0x1003633cc 确证）；
//     renderPage —— UIGraphicsImageRenderer（closure #1 确证）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - parse/renderPage/outline 递归: high（调用/闭包确证）
//   - makeURL 形态: medium-high（签名确证；分隔符待真机对照）
// 还原: 2026-11-19

import Foundation
import PDFKit
import UIKit

/// PDF 页图片源（枚举命名空间）。
enum PDFPageImageSource {

    // MARK: URL 形态

    /// pgo_only makeURL(bookId:fileName:pageIndex:)（签名确证）。
    /// 形态：pdf://<bookId>/<fileName>/<pageIndex>。
    static func makeURL(bookId: String, fileName: String = "", pageIndex: Int) -> URL? {
        URL(string: "pdf://\(bookId)/\(fileName)/\(pageIndex)")
    }

    /// 伪代码 0x100363ed8（L30-42）：pdf:// URL 解析。
    /// makeURL(bookId:fileName:pageIndex:) 的逆向（host=bookId，尾段=pageIndex）。
    static func parse(_ urlString: String) -> PDFPageImageRequest? {
        guard urlString.hasPrefix("pdf://") else { return nil }
        let body = String(urlString.dropFirst("pdf://".count))
        let parts = body.split(separator: "/")
        guard parts.count >= 2,
              let pageIndex = Int(parts.last ?? "") else { return nil }
        let bookId = String(parts[0])
        return PDFPageImageRequest(bookId: bookId, pageIndex: pageIndex)
    }

    // MARK: 文档检查

    /// 伪代码 0x10036381c（L49-60）：文档检查（页数 + 目录链）。
    static func inspectDocument(at url: URL) -> PDFDocumentMetadata? {
        guard let document = PDFDocument(url: url) else { return nil }
        let pageCount = document.pageCount
        let chapters = directoryChapters(at: url, pageCount: pageCount)
        return PDFDocumentMetadata(pageCount: pageCount, chapters: chapters)
    }

    /// 伪代码 0x1003644bc（L62-106）+ visit #1（0x1003648f4，L71-87）：
    /// outline 递归收集（depth 参与确证）+ (title, pageIndex, order) 排序
    ///（closure 0x1003633cc，L93-96 确证）。
    static func directoryChapters(
        at url: URL, pageCount: Int
    ) -> [LocalChapter] {
        guard let document = PDFDocument(url: url),
              let outlineRoot = document.outlineRoot else { return [] }
        var collected: [(title: String, pageIndex: Int, order: Int)] = []
        var order = 0
        visit(outlineRoot, depth: 0, document: document, order: &order, collected: &collected)
        collected.sort { lhs, rhs in
            lhs.pageIndex == rhs.pageIndex
                ? lhs.order < rhs.order
                : lhs.pageIndex < rhs.pageIndex
        }
        return collected.enumerated().map { index, item in
            LocalChapter(
                id: UUID(),
                title: item.title,
                pageIndex: item.pageIndex,
                order: index,
                pageCount: pageCount)
        }
    }

    /// 伪代码 visit #1（0x1003648f4，L71-87）：outline 递归。
    private static func visit(
        _ outline: PDFOutline,
        depth: Int,
        document: PDFDocument,
        order: inout Int,
        collected: inout [(title: String, pageIndex: Int, order: Int)]
    ) {
        guard depth < 8 else { return }
        if let title = outline.label,
           let page = outline.destination?.page,
           let index = document.index(for: page) {
            collected.append((title: title, pageIndex: index, order: order))
            order += 1
        }
        for child in outline.children {
            visit(child, depth: depth + 1, document: document,
                  order: &order, collected: &collected)
        }
    }

    // MARK: 页渲染

    /// 伪代码 0x10036402c（L108-137）+ closure #1（0x1003651bc，L125-136）：
    /// 页渲染（UIGraphicsImageRenderer 确证）。
    static func renderPage(
        document: PDFDocument,
        pageIndex: Int,
        maxPixelSize: CGFloat
    ) -> UIImage? {
        guard pageIndex >= 0, pageIndex < document.pageCount,
              let page = document.page(at: pageIndex) else { return nil }
        let pageBounds = page.bounds(for: .mediaBox)
        let scale = maxPixelSize / max(pageBounds.width, pageBounds.height)
        let renderSize = CGSize(
            width: pageBounds.width * scale,
            height: pageBounds.height * scale)
        let renderer = UIGraphicsImageRenderer(size: renderSize)
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: renderSize))
            context.cgContext.translateBy(x: 0, y: renderSize.height)
            context.cgContext.scaleBy(x: scale, y: -scale)
            context.cgContext.translateBy(x: -pageBounds.origin.x, y: -pageBounds.origin.y)
            page.draw(with: .mediaBox, to: context.cgContext)
        }
    }
}

/// 本地章节（PDF 目录项；LocalChapter 属 T-601-01 域，签名级引用）。
struct LocalChapter: Identifiable {
    var id: UUID
    var title: String
    var pageIndex: Int
    var order: Int
    var pageCount: Int
}
