// 原路径: ReadMain/Services/LocalBookService.swift
// 0x10033d7d8规则评分，0x1003457b0双位置分章，0x100346324长度分章，0x100346c10正文提取。
import Foundation

extension LocalBookService {
    func detectChapterPatternForImport(url: URL) async -> (content: String, pattern: String?) {
        guard let content = Self.detectAndReadText(at: url, preferred: nil) else { return ("", nil) }
        return (content, Self.detectBestTxtPattern(content: content))
    }

    static func detectAndReadText(at url: URL, preferred: String.Encoding?) -> String? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        // BOM优先，避免UTF-16字节被GB18030误解码；指定编码失败后仍尝试原版候选。
        let bomEncoding: String.Encoding? = data.starts(with: [0xFF, 0xFE]) || data.starts(with: [0xFE, 0xFF])
            ? .utf16 : data.starts(with: [0xEF, 0xBB, 0xBF]) ? .utf8 : nil
        var tried = Set<UInt>()
        for encoding in [preferred, bomEncoding, .utf8, .gb18030, .utf16].compactMap({ $0 }) {
            guard tried.insert(encoding.rawValue).inserted else { continue }
            if let text = String(data: data, encoding: encoding) {
                return text.hasPrefix("\u{FEFF}") ? String(text.dropFirst()) : text
            }
        }
        return nil
    }

    static func detectBestTxtPattern(content: String) -> String? {
        // TODO(T-601-01)：ChapterRuleManager内置规则全集仍需逐项恢复。
        let patterns = [
            "^第[0-9零一二三四五六七八九十百千万两]+[章节卷][^\\r\\n]*",
            "^[0-9]+[.、][^\\r\\n]*",
            "^Chapter[ \\t]+[0-9]+[^\\r\\n]*"
        ]
        return detectBestTxtPattern(content: content, patterns: patterns)
    }

    static func detectBestTxtPattern(content: String, patterns: [String]) -> String? {
        let text = content as NSString
        var best: String?
        var bestScore = Int.min
        for pattern in patterns {
            guard let regex = Self.chapterRegex(pattern) else { continue }
            let matches = regex.matches(in: content, range: NSRange(location: 0, length: text.length))
            guard matches.count >= 3 else { continue }
            let quality = matches.prefix(80).reduce(0) { score, match in
                let length = text.substring(with: match.range).trimmingCharacters(in: .whitespacesAndNewlines).count
                return score + (length <= 40 ? 2 : -2) + (length >= 2 ? 1 : 0)
            }
            let score = matches.count * 100 + quality
            if score > bestScore { best = pattern; bestScore = score }
        }
        return best
    }

    static func chapterRegex(_ pattern: String) -> NSRegularExpression? {
        guard !pattern.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .anchorsMatchLines])
    }

    func previewChapterTitles(content: String, pattern: String?) -> [String] {
        guard let pattern, let regex = Self.chapterRegex(pattern) else { return [] }
        let text = content as NSString
        return regex.matches(in: content, range: NSRange(location: 0, length: text.length)).prefix(20)
            .map { text.substring(with: $0.range).trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    func previewChapterCount(content: String, pattern: String?) -> Int {
        guard let pattern, let regex = Self.chapterRegex(pattern) else { return 0 }
        return regex.numberOfMatches(in: content, range: NSRange(location: 0, length: content.utf16.count))
    }

    func parseTxtChapters(_ content: String, customPattern: String?, chapterLength: Int = 30_000) -> [LocalChapter] {
        guard let pattern = customPattern, let regex = Self.chapterRegex(pattern) else {
            return splitByLength(content, chapterLength: chapterLength)
        }
        let text = content as NSString
        let matches = regex.matches(in: content, range: NSRange(location: 0, length: text.length))
        guard matches.count >= 3 else { return splitByLength(content, chapterLength: chapterLength) }
        let positions = matches.map { $0.range.location } + [text.length]
        let offsets = batchCharOffsets(content, utf16Offsets: positions)
        var chapters: [LocalChapter] = []
        if let first = positions.first, first > 500 {
            guard let end = offsets[first] else { return splitByLength(content, chapterLength: chapterLength) }
            chapters.append(LocalChapter(id: 0, title: "前言", startPosition: 0, endPosition: end,
                startUTF16: 0, endUTF16: first))
        }
        for (index, match) in matches.enumerated() {
            let start = positions[index], end = positions[index + 1]
            guard let startChar = offsets[start], let endChar = offsets[end] else { continue }
            chapters.append(LocalChapter(id: chapters.count,
                title: text.substring(with: match.range).trimmingCharacters(in: .whitespacesAndNewlines),
                startPosition: startChar, endPosition: endChar, startUTF16: start, endUTF16: end))
        }
        return chapters
    }

    // 单次遍历建立字素簇边界，禁止把UTF-16偏移直接当字符个数。
    func batchCharOffsets(_ content: String, utf16Offsets: [Int]) -> [Int: Int] {
        let requested = Set(utf16Offsets)
        var result: [Int: Int] = [:]
        var utf16Offset = 0
        var characterOffset = 0
        for character in content {
            if requested.contains(utf16Offset) { result[utf16Offset] = characterOffset }
            utf16Offset += String(character).utf16.count
            characterOffset += 1
        }
        if requested.contains(utf16Offset) { result[utf16Offset] = characterOffset }
        return result
    }

    func splitByLength(_ content: String, chapterLength: Int) -> [LocalChapter] {
        guard !content.isEmpty, chapterLength > 0 else { return [] }
        var chapters: [LocalChapter] = []
        var start = content.startIndex
        var offset = 0
        while start < content.endIndex {
            var end = content.index(start, offsetBy: chapterLength, limitedBy: content.endIndex) ?? content.endIndex
            if end < content.endIndex {
                let searchStart = content.index(end, offsetBy: -min(200, content.distance(from: start, to: end)))
                if let newline = content.range(of: "\n", options: .backwards, range: searchStart..<end) {
                    end = newline.upperBound
                }
            }
            let nextOffset = offset + content.distance(from: start, to: end)
            chapters.append(LocalChapter(id: chapters.count, title: "第\(chapters.count + 1)部分",
                startPosition: offset, endPosition: nextOffset))
            offset = nextOffset
            start = end
        }
        return chapters
    }

    func getChapterContentAsync(book: LocalBook, chapterIndex: Int) async -> String? {
        getChapterContent(book: book, chapterIndex: chapterIndex)
    }

    static func extractTxtChapterContent(fullText: String, chapters: [LocalChapter], chapterIndex: Int) -> String? {
        guard chapters.indices.contains(chapterIndex) else { return nil }
        return extractTxtChapterContent(fullText: fullText, chapter: chapters[chapterIndex])
    }

    static func extractTxtChapterContent(fullText: String, chapter: LocalChapter) -> String? {
        let content: String
        if let start = chapter.startUTF16, let end = chapter.endUTF16 {
            let text = fullText as NSString
            let lower = min(max(0, start), text.length)
            let upper = min(max(0, end), text.length)
            guard lower < upper else { return nil }
            content = text.substring(with: NSRange(location: lower, length: upper - lower))
        } else {
            let lower = max(0, chapter.startPosition)
            let upper = min(fullText.count, chapter.endPosition)
            guard lower < upper else { return nil }
            let start = fullText.index(fullText.startIndex, offsetBy: lower)
            let end = fullText.index(start, offsetBy: upper - lower)
            content = String(fullText[start..<end])
        }
        let title = chapter.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return content }
        let trimmed = content.drop(while: { $0.isWhitespace || $0.isNewline })
        guard trimmed.hasPrefix(title) else { return content }
        return String(trimmed.dropFirst(title.count).drop(while: { $0 == "\r" || $0 == "\n" || $0 == "\r\n" }))
    }

    func getChapterContent(book: LocalBook, chapterIndex: Int) -> String? {
        guard let content = readFullContent(book: book) else { return nil }
        return Self.extractTxtChapterContent(fullText: content,
            chapters: loadChapters(for: book.id.uuidString) ?? [], chapterIndex: chapterIndex)
    }
}
