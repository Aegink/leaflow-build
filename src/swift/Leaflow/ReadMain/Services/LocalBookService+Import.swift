// 原路径: ReadMain/Services/LocalBookService.swift
// 分册归属不变，继续累计原始文件的规模、函数与桩。
import Foundation
import PDFKit
import UIKit

extension LocalBookService {
    // MARK: 导入域（0x10033abb0 L309-357 + 0x10033be18 L360-414 域确证）

    /// importBook(from:)（0x10033abb0 L309-357 域确证）。
    func importBook(from url: URL) async -> LocalBook? {
        await importBook(
            from: url, title: url.deletingPathExtension().lastPathComponent,
            author: nil, coverData: nil)
    }

    /// importBook(from:title:author:coverData:)
    ///（0x10033be18 L360-414 域确证）。
    func importBook(
        from url: URL, title: String, author: String?, coverData: Data?, chapterPattern: String? = nil
    ) async -> LocalBook? {
        let ext = url.pathExtension
        let format = localBookType(forExtension: ext)
        guard ["TXT", "EPUB", "PDF"].contains(format) else { return nil }
        var book = LocalBook(
            name: title, author: author,
            filePath: url.path, format: format)
        book.group = "本地"
        book.chapterPattern = chapterPattern
        // 安装文件域（installBookFile 确证）。
        guard let installed = try? installBookFile(from: url) else {
            return nil
        }
        book.filePath = installed.path
        // 解析域（parsePdfBook/parseEpubBook/parseTxtBook 交叉）。
        book = await ensureChaptersParsed(book)
        guard book.totalChapters > 0,
              loadChapters(for: book.id.uuidString)?.count == book.totalChapters else {
            cleanupBookFiles(book)
            return nil
        }
        // 封面域（LocalBookCoverCache 交叉）。
        if let coverData {
            coverCache.saveCover(data: coverData, for: book.id.uuidString)
        }
        let saved = await MainActor.run { persistImportedBook(book) }
        guard saved else { cleanupBookFiles(book); return nil }
        return book
    }

    // MARK: 解析域（0x1003416c0 L692-719 域确证）

    /// ensureChaptersParsed（0x1003416c0 L692-719 域确证）。
    func ensureChaptersParsed(_ book: LocalBook) async -> LocalBook {
        if let chapters = loadChapters(for: book.id.uuidString), !chapters.isEmpty {
            var restored = book
            restored.totalChapters = chapters.count
            return restored
        }
        return await reparseChapters(book)
    }

    /// reparseChapters（0x10034208c L722-757 域确证）。
    func reparseChapters(_ book: LocalBook) async -> LocalBook {
        var updated = book
        switch book.format.uppercased() {
        case "PDF":
            updated = await parsePdfBook(book, preferExisting: true)
        case "EPUB":
            updated = await parseEpubBook(book, preferExisting: true)
        default:
            updated = await parseTxtBook(book)
        }
        updateBook(updated)
        return updated
    }

    /// updateChapterPattern（0x100342dd4 L760-764 域确证）。
    func updateChapterPattern(book: LocalBook, pattern: String?) {
        guard
            let index = books.firstIndex(where: { $0.id == book.id })
        else { return }
        books[index].chapterPattern = pattern
        try? FileManager.default.removeItem(at: chapterFileURL(for: book.id.uuidString))
        saveMetadata()
    }

    // MARK: 格式解析域（0x100342ee4 L776-814 域确证）

    /// parsePdfBook（0x100342ee4 L776-814 域确证）。
    func parsePdfBook(
        _ book: LocalBook, preferExisting: Bool
    ) async -> LocalBook {
        var updated = book
        // PDF 分页域（PDFKit 交叉）。
        guard let pdfDocument = PDFKit.PDFDocument(url: fullTextURL(for: book))
        else { return updated }
        var chapters: [LocalChapter] = []
        for pageIndex in 0..<pdfDocument.pageCount {
            guard
                let page = pdfDocument.page(at: pageIndex),
                let text = page.string
            else { continue }
            let title = String(text.prefix(30))
            chapters.append(
                LocalChapter(
                    id: pageIndex, title: title,
                    startPosition: pageIndex, endPosition: pageIndex + 1))
        }
        updated.totalChapters = chapters.count
        saveChapters(chapters, for: updated.id.uuidString)
        return updated
    }

    /// parseEpubBook（0x100343844 L827-876 域确证）。
    func parseEpubBook(
        _ book: LocalBook, preferExisting: Bool
    ) async -> LocalBook {
        var updated = book
        // SimpleEpubParser 交叉确证（T-901-03 域）。
        let parsed = try? SimpleEpubParser.parse(
            epubURL: book.fileURL)
        let payload = parsed.map { Self.makeEpubTextPayload(from: $0) }
        if let payload {
            let fullURL = fullTextURL(for: updated)
            try? payload.content.write(
                to: fullURL, atomically: true, encoding: .utf8)
            saveChapters(payload.chapters, for: updated.id.uuidString)
            updated.totalChapters = payload.chapters.count
        }
        return updated
    }

    /// makeEpubTextPayload（0x100343d70 L878-924 static 域确证）。
    static func makeEpubTextPayload(
        from parsed: SimpleEpubParser.ParseResult
    ) -> (content: String, chapters: [LocalChapter]) {
        var chapters: [LocalChapter] = []
        var content = ""
        for (index, entry) in parsed.chapters.enumerated() {
            chapters.append(
                LocalChapter(
                    id: index, title: entry.title,
                    startPosition: content.count,
                    endPosition: content.count + entry.content.count,
                    startUTF16: content.utf16.count,
                    endUTF16: content.utf16.count + entry.content.utf16.count))
            content += entry.content + "\n\n"
        }
        return (content: content, chapters: chapters)
    }

    /// parseTxtBook（0x1003446dc L928-956 域确证）。
    func parseTxtBook(_ book: LocalBook) async -> LocalBook {
        var updated = book
        guard
            let content = await readFullContentAsync(book: book)
        else { return updated }
        let chapters = parseTxtChapters(
            content, customPattern: book.chapterPattern ?? Self.detectBestTxtPattern(content: content), chapterLength: 30_000)
        updated.totalChapters = chapters.count
        saveChapters(chapters, for: updated.id.uuidString)
        return updated
    }

    /// readFullContentAsync（0x100344db8 L963-978 域确证）。
    func readFullContentAsync(book: LocalBook) async -> String? {
        readFullContent(book: book)
    }

    /// readFullContent（0x100344f58 L981-988 域确证）。
    func readFullContent(book: LocalBook) -> String? {
        Self.detectAndReadText(
            at: fullTextURL(for: book), preferred: book.detectedEncoding.flatMap(Self.encodingFromNameStatic))
    }

    /// encodingFromNameStatic（static 签名确证）。
    static func encodingFromNameStatic(_ name: String) -> String.Encoding? {
        switch name.lowercased() {
        case "utf-8", "utf8": return .utf8
        case "gbk", "gb18030", "gb2312": return .gb18030
        case "utf-16", "utf16": return .utf16
        default: return nil
        }
    }

}
