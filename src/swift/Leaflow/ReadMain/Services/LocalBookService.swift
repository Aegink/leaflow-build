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
import UIKit
/// 本地书服务（导入/解析/章节域）。
final class LocalBookService: ObservableObject {

    static let shared = LocalBookService()

    @Published private(set) var books: [LocalBook] = []

    /// 存储目录（init 域确证）。
    private let booksDirectory: URL = FileManager.default.urls(
        for: .documentDirectory, in: .userDomainMask
    )[0].appendingPathComponent("local_books", isDirectory: true)

    private let metadataFileURL: URL = FileManager.default.urls(
        for: .documentDirectory, in: .userDomainMask
    )[0].appendingPathComponent("local_books_metadata.json")

    private let coverCache = LocalBookCoverCache.shared
    private let lock = NSLock()

    /// init（0x10033601c L55-72 域确证）。
    private init() {
        try? FileManager.default.createDirectory(
            at: booksDirectory, withIntermediateDirectories: true)
        migrateIfNeeded()
        loadMetadata()
        syncWithFileSystem()
    }

    // MARK: 迁移域（0x1003375a0 L91-99 + 0x100337b10 L101-176 域确证）

    /// migrateIfNeeded（0x1003375a0 L91-99 域确证）。
    private func migrateIfNeeded() {
        // V1→V2 迁移域（"data_v1_backup.json" @ptr L839 域确证）。
        let legacyURL = booksDirectory.appendingPathComponent(
            "data_v1_backup.json")
        guard (try? Data(contentsOf: legacyURL)) != nil else { return }
        migrateV1toV2()
    }

    /// migrateV1toV2（0x100337b10 L101-176 域确证；
    /// "解码旧数据格式" @ptr L570 域确证）。
    private func migrateV1toV2() {
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
    private func chapterFileURL(for id: String) -> URL {
        booksDirectory.appendingPathComponent("chapters_\(id).json")
    }

    /// epubContentFileURL（签名确证）。
    private func epubContentFileURL(for id: String) -> URL {
        booksDirectory.appendingPathComponent("epub_content_\(id).json")
    }

    /// fullTextURL（0x10033884c L188-197 域确证）。
    private func fullTextURL(for book: LocalBook) -> URL {
        booksDirectory.appendingPathComponent("fulltext_\(book.id).txt")
    }

    /// contentCacheKey（签名确证）。
    private func contentCacheKey(for book: LocalBook) -> String {
        "local_\(book.id)"
    }

    /// localBookType（0x100338928 L203-210 域确证）。
    private func localBookType(forExtension ext: String) -> String {
        switch ext.lowercased() {
        case "txt": return "TXT"
        case "epub": return "EPUB"
        case "pdf": return "PDF"
        default: return ext.uppercased()
        }
    }

    // MARK: 章节存储（0x100338cfc L213-221 + 0x100338e44 L224-231 域确证）

    /// saveChapters（0x100338cfc L213-221 域确证）。
    private func saveChapters(_ chapters: [LocalChapter], for id: String) {
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
    private func loadMetadata() {
        guard
            let data = try? Data(contentsOf: metadataFileURL),
            let stored = try? JSONDecoder().decode(
                [LocalBook].self, from: data)
        else { return }
        books = stored
    }

    /// saveMetadata（0x100339778 L264-271 域确证）。
    private func saveMetadata() {
        if let data = try? JSONEncoder().encode(books) {
            try? data.write(to: metadataFileURL, options: .atomic)
        }
    }

    /// syncWithFileSystem（0x100339918 L274-305 域确证）。
    private func syncWithFileSystem() {
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
        from url: URL, title: String, author: String?, coverData: Data?
    ) async -> LocalBook? {
        let ext = url.pathExtension
        let format = localBookType(forExtension: ext)
        var book = LocalBook(
            name: title, author: author,
            filePath: url.path, format: format)
        book.group = "本地"
        // 安装文件域（installBookFile 确证）。
        guard let installed = try? installBookFile(from: url) else {
            return nil
        }
        book.filePath = installed.path
        // 解析域（parsePdfBook/parseEpubBook/parseTxtBook 交叉）。
        book = await ensureChaptersParsed(book)
        // 封面域（LocalBookCoverCache 交叉）。
        if let coverData {
            coverCache.saveCover(data: coverData, for: book.id.uuidString)
        }
        await MainActor.run {
            books.append(book)
            saveMetadata()
        }
        return book
    }

    /// detectChapterPatternForImport（0x10033d218 L419-435 域确证）。
    func detectChapterPatternForImport(
        url: URL
    ) async -> (content: String, pattern: String?) {
        let content = await readFullContentAsync(
            book: LocalBook(
                name: url.lastPathComponent, filePath: url.path,
                format: "TXT"))
        guard let content else { return (content: "", pattern: nil) }
        let pattern = Self.detectBestTxtPattern(content: content)
        return (content: content, pattern: pattern)
    }

    /// detectAndReadText（static 签名确证）。
    static func detectAndReadText(
        at url: URL, preferred: String.Encoding?
    ) -> String? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let encodings: [String.Encoding] = [.utf8, .gb_18030_2000_4]
        for encoding in encodings {
            if let text = String(data: data, encoding: encoding) {
                return text
            }
        }
        return nil
    }

    /// detectBestTxtPattern（0x10033d7d8 L1098-1124 static 域确证）。
    static func detectBestTxtPattern(content: String) -> String? {
        // 常见章节正则域（第X章/X章/Chapter X 域推断）。
        let patterns = [
            "^第[0-9一二三四五六七八九十百千]+[章节卷][^\\n]*",
            "^[0-9]+[.、][^\\n]*",
            "^Chapter[ \\t]+[0-9]+[^\\n]*",
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern)
            else { continue }
            let range = NSRange(content.startIndex..., in: content)
            if regex.numberOfMatches(in: content, range: range) >= 2 {
                return pattern
            }
        }
        return nil
    }

    /// previewChapterTitles（签名确证）。
    func previewChapterTitles(
        content: String, pattern: String?
    ) -> [String] {
        guard let pattern,
              let regex = try? NSRegularExpression(pattern: pattern)
        else { return [] }
        let range = NSRange(content.startIndex..., in: content)
        let matches = regex.matches(in: content, range: range)
        return matches.prefix(20).compactMap {
            Range($0.range, in: content).map { String(content[$0]) }
        }
    }

    /// previewChapterCount（签名确证）。
    func previewChapterCount(
        content: String, pattern: String?
    ) -> Int {
        previewChapterTitles(content: content, pattern: pattern).count
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
    private func installBookFile(from url: URL) throws -> URL {
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
            content, customPattern: pattern, chapterLength: 6000)
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
    private func cleanupBookFiles(_ book: LocalBook) {
        try? FileManager.default.removeItem(at: fullTextURL(for: book))
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

    // MARK: 解析域（0x1003416c0 L692-719 域确证）

    /// ensureChaptersParsed（0x1003416c0 L692-719 域确证）。
    func ensureChaptersParsed(_ book: LocalBook) async -> LocalBook {
        if loadChapters(for: book.id.uuidString) != nil {
            return book
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
        _ = books[index]
        saveMetadata()
    }

    // MARK: 格式解析域（0x100342ee4 L776-814 域确证）

    /// parsePdfBook（0x100342ee4 L776-814 域确证）。
    private func parsePdfBook(
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
    private func parseEpubBook(
        _ book: LocalBook, preferExisting: Bool
    ) async -> LocalBook {
        var updated = book
        // SimpleEpubParser 交叉确证（T-901-03 域）。
        let parser = SimpleEpubParser()
        let parsed = try? await parser.parse(
            url: fullTextURL(for: book))
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
                    startPosition: content.utf16.count,
                    endPosition: content.utf16.count
                        + entry.content.utf16.count))
            content += entry.content + "\n\n"
        }
        return (content: content, chapters: chapters)
    }

    /// parseTxtBook（0x1003446dc L928-956 域确证）。
    private func parseTxtBook(_ book: LocalBook) async -> LocalBook {
        var updated = book
        guard
            let content = await readFullContentAsync(book: book)
        else { return updated }
        let chapters = parseTxtChapters(
            content, customPattern: nil, chapterLength: 6000)
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
            at: fullTextURL(for: book), preferred: nil)
    }

    /// encodingFromNameStatic（static 签名确证）。
    static func encodingFromNameStatic(_ name: String) -> String.Encoding? {
        switch name.lowercased() {
        case "utf-8", "utf8": return .utf8
        case "gbk", "gb18030": return .gb_18030_2000_4
        default: return nil
        }
    }

    // MARK: 章节切分域（0x1003457b0 L1027-1096 域确证）

    /// parseTxtChapters（0x1003457b0 L1027-1096 域确证）。
    func parseTxtChapters(
        _ content: String, customPattern: String?, chapterLength: Int
    ) -> [LocalChapter] {
        let pattern = customPattern ?? Self.detectBestTxtPattern(content: content)
        var chapters: [LocalChapter] = []
        if let pattern,
           let regex = try? NSRegularExpression(pattern: pattern) {
            let range = NSRange(content.startIndex..., in: content)
            let matches = regex.matches(in: content, range: range)
            for (index, match) in matches.enumerated() {
                guard let titleRange = Range(match.range, in: content) else {
                    continue
                }
                let title = String(content[titleRange])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let start = content.utf16.distance(
                    from: content.utf16.startIndex,
                    to: titleRange.lowerBound.samePosition(
                        in: content.utf16) ?? content.utf16.startIndex)
                let end: Int
                if index + 1 < matches.count,
                   let nextRange = Range(
                        matches[index + 1].range, in: content) {
                    end = content.utf16.distance(
                        from: content.utf16.startIndex,
                        to: nextRange.lowerBound.samePosition(
                            in: content.utf16) ?? content.utf16.startIndex)
                } else {
                    end = content.utf16.count
                }
                chapters.append(
                    LocalChapter(
                        id: index, title: title,
                        startPosition: start, endPosition: end))
            }
        }
        if chapters.isEmpty {
            chapters = splitByLength(
                content, chapterLength: chapterLength)
        }
        return chapters
    }

    /// batchCharOffsets（0x100346028 L1127-1147 域确证）。
    private func batchCharOffsets(
        _ content: String, utf16Offsets: [Int]
    ) -> [Int] {
        utf16Offsets.map { offset in
            String.Index(
                utf16Offset: offset, in: content)
                .samePosition(in: content) ?? content.startIndex
        }.map { content.distance(from: content.startIndex, to: $0) }
    }

    /// splitByLength（0x100346324 L1150-1171 域确证）。
    private func splitByLength(
        _ content: String, chapterLength: Int
    ) -> [LocalChapter] {
        guard !content.isEmpty else { return [] }
        let utf16Count = content.utf16.count
        var chapters: [LocalChapter] = []
        var index = 0
        var offset = 0
        while offset < utf16Count {
            let end = min(offset + chapterLength, utf16Count)
            let startIdx = String.Index(
                utf16Offset: offset, in: content)
            let endIdx = String.Index(
                utf16Offset: end, in: content)
            let snippet = String(content[startIdx..<endIdx])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            chapters.append(
                LocalChapter(
                    id: index,
                    title: snippet.isEmpty
                        ? "第 \(index + 1) 节"
                        : String(snippet.prefix(20)),
                    startPosition: offset, endPosition: end))
            index += 1
            offset = end
        }
        return chapters
    }

    // MARK: 内容读取域（0x10034662c L1197-1221 域确证）

    /// getChapterContentAsync（0x10034662c L1197-1221 域确证）。
    func getChapterContentAsync(
        book: LocalBook, chapterIndex: Int
    ) async -> String? {
        let content = await readFullContentAsync(book: book)
        guard let content else { return nil }
        return Self.extractTxtChapterContent(
            fullText: content, chapters: loadChapters(
                for: book.id.uuidString) ?? [],
            chapterIndex: chapterIndex)
    }

    /// extractTxtChapterContent（0x100346c10 L1228-1259 static 域确证）。
    static func extractTxtChapterContent(
        fullText: String, chapters: [LocalChapter], chapterIndex: Int
    ) -> String? {
        guard chapterIndex < chapters.count else { return nil }
        let chapter = chapters[chapterIndex]
        let startIdx = String.Index(
            utf16Offset: chapter.startPosition, in: fullText)
        let endIdx = String.Index(
            utf16Offset: min(chapter.endPosition, fullText.utf16.count),
            in: fullText)
        return String(fullText[startIdx..<endIdx])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// getChapterContent（签名确证）。
    func getChapterContent(
        book: LocalBook, chapterIndex: Int
    ) -> String? {
        let content = readFullContent(book: book)
        guard let content else { return nil }
        return Self.extractTxtChapterContent(
            fullText: content,
            chapters: loadChapters(for: book.id.uuidString) ?? [],
            chapterIndex: chapterIndex)
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
