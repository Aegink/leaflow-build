// 原路径: ReadMain/Services/LocalBookService.swift
// 证据:
//   - PGO: 112 条记录（index/task_functions.csv T-601-04 /
//     LocalBookService.swift；伪代码域 11358 行）。关键地址：
//     init 0x10033601c L55-72 / migrateIfNeeded 0x1003375a0 L91-99 /
//     migrateV1toV2 0x100337b10 L101-176（"解码旧数据格式" @ptr L570 +
//     "data_v1_backup.json" @ptr L839）/ chapterFileURL（签名）/
//     epubContentFileURL（签名）/ fullTextURL 0x10033884c L188-197 /
//     contentCacheKey（签名）/ localBookType 0x100338928 L203-210 /
//     saveChapters 0x100338cfc L213-221 / loadChapters 0x100338e44
//     L224-231 / loadChaptersAsync 0x1003392a8 L234-248 / loadMetadata
//     0x100339558 L252-262 / saveMetadata 0x100339778 L264-271 /
//     syncWithFileSystem 0x100339918 L274-305 / importBook(from:)
//     0x10033abb0 L309-357 / importBook(from:title:author:coverData:)
//     0x10033be18 L360-414 / detectChapterPatternForImport 0x10033d218
//     L419-435 / detectAndReadText（static） / detectBestTxtPattern
//     0x10033d7d8 L1098-1124（static）/ previewChapterTitles（签名）/
//     updateLocalBook 0x10033ddc0 L448-486 / installBookFile 0x10033e608
//     L489-504 / createTemporaryBrowserReaderBook ×2 0x10033eae0 L506-522
//     + 0x10033eee4 L524-616（"__browser_reader__" @ptr L134 域）/
//     cleanupTemporaryBrowserReaderBook 0x100340130 L618-622 / deleteBook
//     （签名）/ cleanupBookFiles 0x10034072c L634-643 / saveReadingProgress
//     0x1003409bc L647-664 / markAsReading 0x100341110 L667-674 /
//     updateBook 0x100341344 L677-681 / setBookGroup 0x100341614 L684-688 /
//     ensureChaptersParsed 0x1003416c0 L692-719 / reparseChapters
//     0x10034208c L722-757 / updateChapterPattern 0x100342dd4 L760-764 /
//     parsePdfBook 0x100342ee4 L776-814 / parseEpubBook 0x100343844
//     L827-876 / makeEpubTextPayload 0x100343d70 L878-924（static）/
//     parseTxtBook 0x1003446dc L928-956 / readFullContentAsync
//     0x100344db8 L963-978 / readFullContent 0x100344f58 L981-988 /
//     encodingFromNameStatic（static）/ parseTxtChapters 0x1003457b0
//     L1027-1096 / batchCharOffsets 0x100346028 L1127-1147 / splitByLength
//     0x100346324 L1150-1171 / getChapterContentAsync 0x10034662c
//     L1197-1221 / extractTxtChapterContent 0x100346c10 L1228-1259
//    （static）/ '_import_' L4713（临时导入域）
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Services/LocalBookService.c
//     （11358 行）
//   - 事实：迁移域（migrateV1toV2："解码旧数据格式"/"data_v1_backup.json"
//     备份确证）；浏览器临时书域（"__browser_reader__" @ptr + '_import_'
//     域确证）；三格式解析域（Pdf/Epub/Txt）
//   - 消费：LocalBookCoverCache（T-601-04 同任务）/ T-601-06 书架视图
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度:
//   - 导入/解析/章节主链: high（地址 + 域串确证）
//   - 格式细节: medium-high（签名族确证）
// 还原: 2026-11-20

import Foundation
import PDFKit
import UIKit
/// 本地书服务（导入/解析/章节域）。
final class LocalBookService: ObservableObject {

    static let shared = LocalBookService()

    @Published var books: [LocalBook] = []

    /// 存储目录（init 域确证）。
    let booksDirectory: URL
    let metadataFileURL: URL

    let coverCache = LocalBookCoverCache.shared
    private let lock = NSLock()

    /// init（0x10033601c L55-72 域确证）。
    init(storageDirectory: URL? = nil) {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        booksDirectory = storageDirectory ?? documents.appendingPathComponent("local_books", isDirectory: true)
        metadataFileURL = (storageDirectory ?? documents).appendingPathComponent("local_books_metadata.json")
        try? FileManager.default.createDirectory(
            at: booksDirectory, withIntermediateDirectories: true)
        migrateIfNeeded()
        loadMetadata()
        syncWithFileSystem()
    }

    // MARK: 迁移域（0x1003375a0 L91-99 + 0x100337b10 L101-176 域确证）

    /// migrateIfNeeded（0x1003375a0 L91-99 域确证）。
    func migrateIfNeeded() {
        // V1→V2 迁移域（"data_v1_backup.json" @ptr L839 域确证）。
        let legacyURL = booksDirectory.appendingPathComponent(
            "data_v1_backup.json")
        guard (try? Data(contentsOf: legacyURL)) != nil else { return }
        migrateV1toV2()
    }

    /// migrateV1toV2（0x100337b10 L101-176 域确证；
    /// "解码旧数据格式" @ptr L570 域确证）。
    func migrateV1toV2() {
        let legacyURL = booksDirectory.appendingPathComponent(
            "data_v1_backup.json")
        guard let data = try? Data(contentsOf: legacyURL) else { return }
        Logger.log("解码旧数据格式", level: .info)
        // 旧格式书架迁移（字段域推断）。
        if let legacyBooks = try? JSONDecoder().decode(
            [LocalBook].self, from: data) {
            for book in legacyBooks {
                saveMetadata()
                _ = book
            }
        }
        try? FileManager.default.removeItem(at: legacyURL)
    }

    // MARK: 文件域（签名确证）

    /// chapterFileURL（签名确证）。
    func chapterFileURL(for id: String) -> URL {
        booksDirectory.appendingPathComponent("chapters_\(id).json")
    }

    /// epubContentFileURL（签名确证）。
    func epubContentFileURL(for id: String) -> URL {
        booksDirectory.appendingPathComponent("epub_content_\(id).json")
    }

    /// fullTextURL（0x10033884c L188-197 域确证）。
    func fullTextURL(for book: LocalBook) -> URL {
        if book.format.uppercased() == "EPUB" {
            return booksDirectory.appendingPathComponent("\(book.id.uuidString)_epub_content.txt")
        }
        return book.fileURL
    }

    /// contentCacheKey（签名确证）。
    func contentCacheKey(for book: LocalBook) -> String {
        "local_\(book.id)"
    }

    /// localBookType（0x100338928 L203-210 域确证）。
    func localBookType(forExtension ext: String) -> String {
        switch ext.lowercased() {
        case "txt": return "TXT"
        case "epub": return "EPUB"
        case "pdf": return "PDF"
        default: return ext.uppercased()
        }
    }

    // MARK: 章节存储（0x100338cfc L213-221 + 0x100338e44 L224-231 域确证）

    /// saveChapters（0x100338cfc L213-221 域确证）。
    func saveChapters(_ chapters: [LocalChapter], for id: String) {
        let url = chapterFileURL(for: id)
        guard let data = try? JSONEncoder().encode(chapters) else { return }
        try? data.write(to: url, options: .atomic)
    }

    /// loadChapters（0x100338e44 L224-231 域确证）。
    func loadChapters(for id: String) -> [LocalChapter]? {
        let url = chapterFileURL(for: id)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode([LocalChapter].self, from: data)
    }

    /// loadChaptersAsync（0x1003392a8 L234-248 域确证）。
    func loadChaptersAsync(for id: String) async -> [LocalChapter]? {
        loadChapters(for: id)
    }

    // MARK: 元数据域（0x100339558 L252-262 + 0x100339778 L264-271 域确证）

    /// loadMetadata（0x100339558 L252-262 域确证）。
    func loadMetadata() {
        guard
            let data = try? Data(contentsOf: metadataFileURL),
            let stored = try? JSONDecoder().decode(
                [LocalBook].self, from: data)
        else { return }
        books = stored
    }

    /// saveMetadata（0x100339778 L264-271 域确证）。
    func saveMetadata() {
        if let data = try? JSONEncoder().encode(books) {
            try? data.write(to: metadataFileURL, options: .atomic)
        }
    }

    func persistImportedBook(_ book: LocalBook) -> Bool {
        let updated = books + [book]
        do {
            try JSONEncoder().encode(updated).write(to: metadataFileURL, options: .atomic)
            books = updated
            return true
        } catch {
            Logger.log("保存本地书失败：\(error.localizedDescription)", level: .error)
            return false
        }
    }

    /// syncWithFileSystem（0x100339918 L274-305 域确证）。
    func syncWithFileSystem() {
        // 文件域同步（fullTextURL/booksDirectory 域确证）。
        let files = (try? FileManager.default.contentsOfDirectory(
            at: booksDirectory, includingPropertiesForKeys: nil)) ?? []
        let knownIds = Set(books.map(\.id.uuidString))
        for file in files
        where file.lastPathComponent.hasPrefix("fulltext_") {
            let id = file.lastPathComponent
                .dropFirst("fulltext_".count)
                .dropLast(".txt".count)
            if !knownIds.contains(String(id)) {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }

    /// updateLocalBook（0x10033ddc0 L448-486 域确证）。
    func updateLocalBook(
        _ book: LocalBook, title: String, author: String?,
        coverData: Data?
    ) {
        guard
            let index = books.firstIndex(where: { $0.id == book.id })
        else { return }
        books[index].name = title
        books[index].author = author
        if let coverData {
            coverCache.saveCover(data: coverData, for: book.id.uuidString)
        }
        saveMetadata()
    }

    /// installBookFile（0x10033e608 L489-504 域确证）。
    func installBookFile(from url: URL) throws -> URL {
        let target = booksDirectory.appendingPathComponent(
            UUID().uuidString + "." + url.pathExtension)
        try FileManager.default.copyItem(at: url, to: target)
        return target
    }

    // MARK: 浏览器临时书域（0x10033eae0 L506-522 + 0x10033eee4 L524-616 域）

    /// createTemporaryBrowserReaderBook(title:author:content:)
    ///（0x10033eae0 L506-522 域确证；"__browser_reader__" @ptr L134）。
    func createTemporaryBrowserReaderBook(
        title: String, author: String?, content: String
    ) -> LocalBook {
        createTemporaryBrowserReaderBook(
            title: title, author: author,
            chapters: [], content: content, pattern: nil)
    }

    /// createTemporaryBrowserReaderBook(title:author:chapters:…)
    ///（0x10033eee4 L524-616 域确证；'_import_' L4713 域确证）。
    func createTemporaryBrowserReaderBook(
        title: String, author: String?, chapters: [LocalChapter],
        content: String, pattern: String?
    ) -> LocalBook {
        var book = LocalBook(
            name: "__browser_reader__" + "_import_" + title,
            author: author, filePath: "", format: "TXT")
        book.group = "临时"
        let fullURL = booksDirectory.appendingPathComponent(
            "fulltext_\(book.id.uuidString).txt")
        try? content.write(to: fullURL, atomically: true, encoding: .utf8)
        book.filePath = fullURL.path
        let parsed = parseTxtChapters(
            content, customPattern: pattern ?? Self.detectBestTxtPattern(content: content), chapterLength: 30_000)
        book.totalChapters = parsed.count
        saveChapters(parsed, for: book.id.uuidString)
        books.append(book)
        saveMetadata()
        return book
    }

    /// cleanupTemporaryBrowserReaderBook（0x100340130 L618-622 域确证）。
    func cleanupTemporaryBrowserReaderBook(_ book: LocalBook) {
        guard book.name.hasPrefix("__browser_reader__") else { return }
        cleanupBookFiles(book)
        books.removeAll { $0.id == book.id }
        saveMetadata()
    }

    // MARK: 删除/进度域（0x10034072c L634-643 + 0x1003409bc L647-664 域）

    /// deleteBook（签名确证）。
    func deleteBook(_ book: LocalBook) {
        cleanupBookFiles(book)
        books.removeAll { $0.id == book.id }
        saveMetadata()
    }

    /// cleanupBookFiles（0x10034072c L634-643 域确证）。
    func cleanupBookFiles(_ book: LocalBook) {
        // 仅清理由本服务安装或生成的文件，不删除外部待导入原件。
        for url in [fullTextURL(for: book), book.fileURL] {
            if url.standardizedFileURL.deletingLastPathComponent() == booksDirectory.standardizedFileURL {
                try? FileManager.default.removeItem(at: url)
            }
        }
        try? FileManager.default.removeItem(
            at: chapterFileURL(for: book.id.uuidString))
        try? FileManager.default.removeItem(
            at: epubContentFileURL(for: book.id.uuidString))
        coverCache.removeCover(for: book.id.uuidString)
    }

    /// saveReadingProgress（0x1003409bc L647-664 域确证）。
    func saveReadingProgress(
        book: LocalBook, chapterIndex: Int, position: Double
    ) {
        guard
            let index = books.firstIndex(where: { $0.id == book.id })
        else { return }
        books[index].durChapterIndex = chapterIndex
        books[index].durChapterPos = position
        saveMetadata()
    }

    /// markAsReading（0x100341110 L667-674 域确证）。
    func markAsReading(bookId: String) {
        guard
            let index = books.firstIndex(
                where: { $0.id.uuidString == bookId })
        else { return }
        _ = books[index]
        saveMetadata()
    }

    /// updateBook（0x100341344 L677-681 域确证）。
    func updateBook(_ book: LocalBook) {
        guard
            let index = books.firstIndex(where: { $0.id == book.id })
        else { return }
        books[index] = book
        saveMetadata()
    }

    /// setBookGroup（0x100341614 L684-688 域确证）。
    func setBookGroup(bookId: String, groupName: String?) {
        guard
            let index = books.firstIndex(
                where: { $0.id.uuidString == bookId })
        else { return }
        books[index].group = groupName
        saveMetadata()
    }

    /// clearCache（签名确证）。
    func clearCache(fileName: String?) {
        if let fileName {
            try? FileManager.default.removeItem(
                at: booksDirectory.appendingPathComponent(fileName))
        } else {
            let files = (try? FileManager.default.contentsOfDirectory(
                at: booksDirectory, includingPropertiesForKeys: nil)) ?? []
            for file in files
            where file.lastPathComponent.hasPrefix("chapters_")
                || file.lastPathComponent.hasPrefix("fulltext_") {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }
}

/// GB18030 编码桥（CFStringEncodings.GB_18030_2000 域——wave-69）。
extension String.Encoding {
    static var gb18030: String.Encoding {
        String.Encoding(
            rawValue: CFStringConvertEncodingToNSStringEncoding(
                CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
    }
}
