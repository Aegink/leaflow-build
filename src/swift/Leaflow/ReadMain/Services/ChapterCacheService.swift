// 原路径: ReadMain/Services/ChapterCacheService.swift
// 证据:
//   - PGO: 51 条记录（index/task_functions.csv T-601-03 /
//     ChapterCacheService.swift；伪代码域 5458 行）。关键地址：
//     getChapterList 0x1002f3f90 L52-69 / saveChapterList 0x1002f4e50
//     L86-109 / getCachedSummary 0x1002f52e4 L112-120 / getChapterSummary
//     0x1002f5538 L123-163 / hasChapterListCache 0x1002f6208 L166-169 /
//     getChapterContent 0x1002f64a8 L174-202 / saveChapterContent
//     0x1002f6a84 L205-232 / saveChapterPayload 0x1002f738c L235-283 /
//     removeChapterContent 0x1002f8b0c L286-299 / getChapterComments
//     0x1002f9094 L302-314 / getChapterReaderAccessURL 0x1002f94a4
//     L316-329 / loadChapterPayload 0x1002f9944 L333-359 /
//     isChapterCached 0x1002f9cc8 L364-380 / clearCache 0x1002fa2d0
//     L388-396 / clearAllCache 0x1002fa668 L399-408 / scanCachedData
//     0x1002f2ad8 L495-534（static）
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Services/ChapterCacheService.c
//     （5458 行）
//   - 字符串域确证（位模式/指针）："chapter_list.json" @ptr L390/
//     "chapter_" L4486（内容文件前缀）/"存章节列表失败: " @ptr L366/
//     "取缓存失败: " @ptr L1109/"存缓存失败: " @ptr L1612/"空，跳过保存:
//     chapter_" @ptr L2626/"removing cache: ch=" @ptr L2753/"本书，" L171 +
//     " 条摘要" L178/"aved content book=" @ptr L966/" readerUrl=" L2127/
//     " comments=" L2507/" markers=" L3056/'acheService.swift' @ptr L164
//   - 事实：目录域（chapter_list.json 清单 + chapter_N 内容文件）；
//     payload 域（content/nextUrl/comments/readerAccessURL 四元确证）；
//     摘要域（getCachedSummary count+lastChapterName 确证）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（地址 + 文件名域确证）
// 还原: 2026-11-20

import Foundation

/// 章节缓存服务（清单 + 内容文件双域）。
final class ChapterCacheService {

    static let shared = ChapterCacheService()

    private let lock = NSLock()
    private var memoryListCache: [String: [Chapter]] = [:]

    /// 缓存目录（"chapter_list.json" @ptr L390 域确证）。
    private var cacheDirectory: URL {
        FileManager.default.urls(
            for: .cachesDirectory, in: .userDomainMask
        )[0].appendingPathComponent("chapter_cache", isDirectory: true)
    }

    private func listFileURL(for bookUrl: String) -> URL {
        let key = Book.chapterCacheKey(
            bookUrl: bookUrl, bookSourceUrl: nil, sourceStorageKind: nil)
        return cacheDirectory.appendingPathComponent(
            "chapter_\(abs(key.hashValue))_list.json")
    }

    private func contentFileURL(
        for bookUrl: String, chapterIndex: Int
    ) -> URL {
        let key = Book.chapterCacheKey(
            bookUrl: bookUrl, bookSourceUrl: nil, sourceStorageKind: nil)
        return cacheDirectory.appendingPathComponent(
            "chapter_\(abs(key.hashValue))_\(chapterIndex).json")
    }

    /// init（目录建立域）。
    private init() {
        try? FileManager.default.createDirectory(
            at: cacheDirectory, withIntermediateDirectories: true)
    }

    // MARK: 章节列表（0x1002f3f90 L52-69 域确证）

    /// getChapterList（0x1002f3f90 L52-69 域确证）。
    func getChapterList(bookUrl: String) async -> [Chapter]? {
        lock.lock()
        if let cached = memoryListCache[bookUrl] {
            lock.unlock()
            return cached
        }
        lock.unlock()
        let url = listFileURL(for: bookUrl)
        guard let data = try? Data(contentsOf: url),
              let chapters = try? JSONDecoder().decode(
                [Chapter].self, from: data)
        else {
            Logger.log("取缓存失败: \(bookUrl)", level: .warning)
            return nil
        }
        lock.lock()
        memoryListCache[bookUrl] = chapters
        lock.unlock()
        return chapters
    }

    /// saveChapterList（0x1002f4e50 L86-109 域确证）。
    func saveChapterList(bookUrl: String, chapters: [Chapter]) {
        lock.lock()
        memoryListCache[bookUrl] = chapters
        lock.unlock()
        let url = listFileURL(for: bookUrl)
        guard let data = try? JSONEncoder().encode(chapters) else {
            Logger.log("存章节列表失败: \(bookUrl)", level: .warning)
            return
        }
        try? data.write(to: url, options: .atomic)
    }

    /// getCachedSummary（0x1002f52e4 L112-120 域确证）。
    func getCachedSummary(
        bookUrl: String
    ) -> (count: Int, lastChapterName: String)? {
        lock.lock()
        let cached = memoryListCache[bookUrl]
        lock.unlock()
        guard let chapters = cached, let last = chapters.last else {
            return nil
        }
        return (count: chapters.count, lastChapterName: last.name)
    }

    /// getChapterSummary（0x1002f5538 L123-163 域确证）。
    func getChapterSummary(
        bookUrl: String
    ) async -> (count: Int, lastChapterName: String) {
        if let summary = getCachedSummary(bookUrl: bookUrl) {
            return summary
        }
        let chapters = await getChapterList(bookUrl: bookUrl) ?? []
        return (
            count: chapters.count,
            lastChapterName: chapters.last?.name ?? ""
        )
    }

    /// hasChapterListCache（0x1002f6208 L166-169 域确证）。
    func hasChapterListCache(bookUrl: String) -> Bool {
        FileManager.default.fileExists(
            atPath: listFileURL(for: bookUrl).path)
    }

    // MARK: 章节内容（0x1002f64a8 L174-202 域确证）

    /// getChapterContent（0x1002f64a8 L174-202 域确证）。
    func getChapterContent(
        bookUrl: String, chapterIndex: Int
    ) async -> ChapterContent? {
        let payload = await loadChapterPayload(
            bookUrl: bookUrl, chapterIndex: chapterIndex)
        guard let payload else { return nil }
        return ChapterContent(
            content: payload.content, nextUrl: payload.nextUrl,
            isPay: nil, comments: payload.comments,
            readerAccessURL: payload.readerAccessURL,
            chapterTitle: nil)
    }

    /// saveChapterContent（0x1002f6a84 L205-232 域确证）。
    func saveChapterContent(
        bookUrl: String, chapterIndex: Int, content: String
    ) async {
        // "空，跳过保存: chapter_" @ptr L2626 域确证。
        guard !content.isEmpty else {
            Logger.log(
                "空，跳过保存: chapter_\(chapterIndex)", level: .warning)
            return
        }
        let url = contentFileURL(for: bookUrl, chapterIndex: chapterIndex)
        guard let data = try? JSONEncoder().encode(content) else {
            Logger.log("存缓存失败: chapter_\(chapterIndex)", level: .warning)
            return
        }
        try? data.write(to: url, options: .atomic)
    }

    /// saveChapterPayload（0x1002f738c L235-283 域确证）。
    func saveChapterPayload(
        bookUrl: String, chapterIndex: Int, content: String,
        nextUrl: String?, comments: [ParagraphComment]?,
        readerAccessURL: String?
    ) async {
        // " comments=" L2507/" readerUrl=" L2127/" markers=" L3056 域确证。
        guard !content.isEmpty else {
            Logger.log(
                "空，跳过保存: chapter_\(chapterIndex)", level: .warning)
            return
        }
        let url = contentFileURL(for: bookUrl, chapterIndex: chapterIndex)
        let payload = ChapterPayload(
            content: content, nextUrl: nextUrl, comments: comments,
            readerAccessURL: readerAccessURL)
        guard let data = try? JSONEncoder().encode(payload) else {
            Logger.log("存缓存失败: chapter_\(chapterIndex)", level: .warning)
            return
        }
        try? data.write(to: url, options: .atomic)
    }

    /// removeChapterContent（0x1002f8b0c L286-299 域确证）。
    func removeChapterContent(
        bookUrl: String, chapterIndex: Int
    ) async {
        // "removing cache: ch=" @ptr L2753 域确证。
        let url = contentFileURL(for: bookUrl, chapterIndex: chapterIndex)
        try? FileManager.default.removeItem(at: url)
    }

    /// getChapterComments（0x1002f9094 L302-314 域确证）。
    func getChapterComments(
        bookUrl: String, chapterIndex: Int
    ) async -> [ParagraphComment] {
        let payload = await loadChapterPayload(
            bookUrl: bookUrl, chapterIndex: chapterIndex)
        return payload?.comments ?? []
    }

    /// getChapterReaderAccessURL（0x1002f94a4 L316-329 域确证）。
    func getChapterReaderAccessURL(
        bookUrl: String, chapterIndex: Int
    ) async -> String? {
        let payload = await loadChapterPayload(
            bookUrl: bookUrl, chapterIndex: chapterIndex)
        return payload?.readerAccessURL
    }

    /// loadChapterPayload（0x1002f9944 L333-359 域确证）。
    private func loadChapterPayload(
        bookUrl: String, chapterIndex: Int
    ) async -> ChapterPayload? {
        let url = contentFileURL(for: bookUrl, chapterIndex: chapterIndex)
        guard let data = try? Data(contentsOf: url) else { return nil }
        if let payload = try? JSONDecoder().decode(
            ChapterPayload.self, from: data) {
            return payload
        }
        // 兼容纯 content 文件（saveChapterContent 域交叉）。
        if let content = try? JSONDecoder().decode(
            String.self, from: data) {
            return ChapterPayload(
                content: content, nextUrl: nil, comments: nil,
                readerAccessURL: nil)
        }
        return nil
    }

    /// isChapterCached（0x1002f9cc8 L364-380 域确证）。
    func isChapterCached(bookUrl: String, chapterIndex: Int) -> Bool {
        FileManager.default.fileExists(
            atPath: contentFileURL(
                for: bookUrl, chapterIndex: chapterIndex).path)
    }

    /// getCachedChapterIndices（签名确证）。
    func getCachedChapterIndices(bookUrl: String) -> Set<Int> {
        let key = Book.chapterCacheKey(
            bookUrl: bookUrl, bookSourceUrl: nil, sourceStorageKind: nil)
        let prefix = "chapter_\(abs(key.hashValue))_"
        let files = (try? FileManager.default.contentsOfDirectory(
            at: cacheDirectory, includingPropertiesForKeys: nil)) ?? []
        var indices = Set<Int>()
        for file in files
        where file.lastPathComponent.hasPrefix(prefix)
            && file.lastPathComponent.hasSuffix(".json")
            && !file.lastPathComponent.hasSuffix("_list.json") {
            let name = file.lastPathComponent
                .dropFirst(prefix.count)
                .dropLast(".json".count)
            if let index = Int(name) {
                indices.insert(index)
            }
        }
        return indices
    }

    /// clearCache（0x1002fa2d0 L388-396 域确证）。
    func clearCache(bookUrl: String) {
        let key = Book.chapterCacheKey(
            bookUrl: bookUrl, bookSourceUrl: nil, sourceStorageKind: nil)
        let prefix = "chapter_\(abs(key.hashValue))"
        let files = (try? FileManager.default.contentsOfDirectory(
            at: cacheDirectory, includingPropertiesForKeys: nil)) ?? []
        for file in files
        where file.lastPathComponent.hasPrefix(prefix) {
            try? FileManager.default.removeItem(at: file)
        }
        lock.lock()
        memoryListCache.removeValue(forKey: bookUrl)
        lock.unlock()
    }

    /// clearAllCache（0x1002fa668 L399-408 域确证）。
    func clearAllCache() {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: cacheDirectory, includingPropertiesForKeys: nil)) ?? []
        for file in files {
            try? FileManager.default.removeItem(at: file)
        }
        lock.lock()
        memoryListCache.removeAll()
        lock.unlock()
    }

    /// scanCachedData（0x1002f2ad8 L495-534 static 域确证）。
    static func scanCachedData(
        cacheDirectory: URL
    ) -> (books: Int, totalEntries: Int) {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: cacheDirectory, includingPropertiesForKeys: nil)) ?? []
        let bookKeys = Set(files.map { file in
            let name = file.lastPathComponent
            // chapter_<hash>_ 前缀提取（"chapter_" L4486 域确证）。
            guard name.hasPrefix("chapter_") else { return "" }
            let parts = name.dropFirst("chapter_".count)
            return String(parts.prefix(while: { $0 != "_" }))
        }.filter { !$0.isEmpty })
        return (books: bookKeys.count, totalEntries: files.count)
    }
}

/// 章节缓存 payload（saveChapterPayload 四元域确证）。
struct ChapterPayload: Codable {
    var content: String
    var nextUrl: String?
    var comments: [ParagraphComment]?
    var readerAccessURL: String?
}

// MARK: - T-1401-13/15 逐域补齐（章缓存域）

extension ChapterCacheService {

    /// 伪代码 0x1002faa3c（L411-424）：缓存字节数（目录枚举求和域）。
    func getCacheSize() async -> Int64 {
        var total: Int64 = 0
        guard let enumerator = FileManager.default.enumerator(
            at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey])
        else { return 0 }
        for case let file as URL in enumerator {
            total += Int64((try? file.resourceValues(forKeys: [.fileSizeKey]))
                ?.fileSize ?? 0)
        }
        return total
    }

    /// 伪代码 0x1002fbaac（L537-564）：书籍映射更新（bookUrl → 缓存键域）。
    func updateBookMapping(bookUrl: String) {
        let key = Book.chapterCacheKey(
            bookUrl: bookUrl, bookSourceUrl: nil, sourceStorageKind: nil)
        UserDefaults.standard.set(key, forKey: "chapter_cache_map_\(bookUrl)")
        Logger.log(
            "[chapterCache] mapping updated key=\(key)", level: .verbose)
    }
}

