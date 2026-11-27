// T-1602：TXT章节语义、双位置兼容及真实文件导入/重开/失败回滚。
import Foundation

enum LocalBookSampleSelfTest {
    @MainActor
    static func run(emit: (String, [String], [String]) -> Void) async {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("local-book-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let service = LocalBookService(storageDirectory: root.appendingPathComponent("store"))
            let content = "第一章 开始\n甲😀正文\n第二章 继续\n乙e\u{301}正文\n第三章 结束\n丙正文\n"
            let pattern = "^第.+章[^\\r\\n]*"
            let chapters = service.parseTxtChapters(content, customPattern: pattern)
            emit("local_txt_multiline_titles", ["第一章 开始", "第二章 继续", "第三章 结束"], chapters.map(\.title))
            emit("local_txt_title_stripped_body", ["甲😀正文\n", "乙e\u{301}正文\n", "丙正文\n"],
                chapters.indices.map { LocalBookService.extractTxtChapterContent(fullText: content, chapters: chapters, chapterIndex: $0) ?? "缺失" })
            let second = content.range(of: "第二章")!.lowerBound
            emit("local_txt_dual_offsets", [String(content.distance(from: content.startIndex, to: second)),
                String(second.utf16Offset(in: content)), String(content.count), String(content.utf16.count)],
                [String(chapters[1].startPosition), String(chapters[1].startUTF16 ?? -1),
                 String(chapters[2].endPosition), String(chapters[2].endUTF16 ?? -1)])
            emit("local_txt_pattern_case_insensitive", ["chapter 1", "CHAPTER 2", "Chapter 3"],
                service.previewChapterTitles(content: "chapter 1\na\nCHAPTER 2\nb\nChapter 3", pattern: "^chapter [0-9]"))
            emit("local_txt_two_matches_fallback", ["第1部分"],
                service.parseTxtChapters("第一章\n甲\n第二章\n乙", customPattern: pattern).map(\.title))
            emit("local_txt_invalid_pattern_fallback", ["第1部分"], service.parseTxtChapters("正文", customPattern: "[").map(\.title))
            emit("local_txt_empty_input", ["0", "0"], [String(service.parseTxtChapters("", customPattern: nil).count),
                String(service.splitByLength("正文", chapterLength: 0).count)])
            let longPreface = String(repeating: "序", count: 501) + content
            let prefaced = service.parseTxtChapters(longPreface, customPattern: "第.+章[^\\r\\n]*")
            emit("local_txt_preface_threshold", ["前言", "501", "4", "3"],
                [prefaced.first?.title ?? "", String(prefaced.first?.endUTF16 ?? -1), String(prefaced.count),
                 String(service.parseTxtChapters(String(repeating: "序", count: 500) + content,
                    customPattern: "第.+章[^\\r\\n]*").count)])
            let split = service.splitByLength("甲😀\n乙e\u{301}丙丁", chapterLength: 5)
            emit("local_txt_length_graphemes", ["3", "7", "甲😀\n乙e\u{301}丙丁"],
                [String(split.first?.endPosition ?? -1), String(split.last?.endPosition ?? -1),
                 split.compactMap { LocalBookService.extractTxtChapterContent(fullText: "甲😀\n乙e\u{301}丙丁", chapter: $0) }.joined()])
            let narrow = "^第[一二三]章", broad = "^第.+"
            emit("local_txt_pattern_score", [narrow], [LocalBookService.detectBestTxtPattern(
                content: (1...3).map { "第\(["一", "二", "三"][$0 - 1])章" + String(repeating: "长", count: 45) }.joined(separator: "\n"),
                patterns: [broad, narrow]) ?? ""])
            emit("local_txt_pattern_minimum", ["true"], [String(LocalBookService.detectBestTxtPattern(content: "第一章\n第二章", patterns: [pattern]) == nil)])
            let many = (1...25).map { "Chapter \($0)" }.joined(separator: "\n")
            emit("local_txt_preview_full_count", ["20", "25"], [String(service.previewChapterTitles(content: many, pattern: "^Chapter.*").count),
                String(service.previewChapterCount(content: many, pattern: "^Chapter.*"))])
            let legacy = try JSONDecoder().decode(LocalChapter.self,
                from: Data(#"{"id":0,"title":"","startPosition":1,"endPosition":2}"#.utf8))
            emit("local_txt_legacy_character_offsets", ["😀"], [LocalBookService.extractTxtChapterContent(fullText: "甲😀乙", chapter: legacy) ?? ""])
            let invalid = LocalChapter(id: 0, title: "", startPosition: 4, endPosition: 1, startUTF16: 4, endUTF16: 1)
            emit("local_txt_invalid_ranges", ["true", "true", "true"],
                [String(LocalBookService.extractTxtChapterContent(fullText: content, chapters: chapters, chapterIndex: -1) == nil),
                 String(LocalBookService.extractTxtChapterContent(fullText: content, chapter: invalid) == nil),
                 String(LocalBookService.extractTxtChapterContent(fullText: content, chapters: chapters, chapterIndex: 3) == nil)])
            let file = root.appendingPathComponent("固定本地正文.txt")
            try content.write(to: file, atomically: true, encoding: .utf8)
            let imported = await service.importBook(from: file, title: "固定本地正文", author: "样本作者", coverData: nil, chapterPattern: pattern)
            emit("local_txt_file_import", ["3", "甲😀正文\n", "true"], [String(imported?.totalChapters ?? -1),
                imported.flatMap { service.getChapterContent(book: $0, chapterIndex: 0) } ?? "",
                String(imported.map { $0.fileURL != file && FileManager.default.fileExists(atPath: $0.filePath) } ?? false)])
            let reloaded = LocalBookService(storageDirectory: root.appendingPathComponent("store"))
            emit("local_txt_cold_reload", ["1", "乙e\u{301}正文\n", pattern], [String(reloaded.books.count),
                reloaded.books.first.flatMap { reloaded.getChapterContent(book: $0, chapterIndex: 1) } ?? "",
                reloaded.books.first?.chapterPattern ?? ""])
            if let imported { reloaded.deleteBook(imported) }
            emit("local_txt_delete_owned_files", ["0", "true", "false"], [String(reloaded.books.count),
                String(FileManager.default.fileExists(atPath: file.path)),
                String(imported.map { FileManager.default.fileExists(atPath: $0.filePath) } ?? true)])
            let utf16 = root.appendingPathComponent("utf16.txt")
            try content.write(to: utf16, atomically: true, encoding: .utf16)
            emit("local_txt_utf16_detection", [content], [LocalBookService.detectAndReadText(at: utf16, preferred: nil) ?? ""])
            let gb = root.appendingPathComponent("gb.txt")
            try Data([0xD6, 0xD0, 0xCE, 0xC4]).write(to: gb)
            emit("local_txt_gb18030_detection", ["中文"], [LocalBookService.detectAndReadText(at: gb, preferred: nil) ?? ""])
            try FileManager.default.removeItem(at: reloaded.metadataFileURL)
            try FileManager.default.createDirectory(at: reloaded.metadataFileURL, withIntermediateDirectories: true)
            let failed = await reloaded.importBook(from: file)
            emit("local_txt_write_failure_rollback", ["true", "0", "0"], [String(failed == nil), String(reloaded.books.count),
                String(try FileManager.default.contentsOfDirectory(at: reloaded.booksDirectory, includingPropertiesForKeys: nil)
                    .filter { $0.pathExtension == "txt" }.count)])
        } catch {
            emit("local_txt_file_import", ["通过"], [error.localizedDescription])
        }
    }
}
