// 原路径: ReadMain/Views/Reader/ChangeSourceCache.swift
// 证据:
//   - PGO: SourceItem.init(from: Book) 及 closure #5/#6 / SourceItem.toBook() (0x10066e8a8 L38-50) /
//     CacheEntry.totalCount (0x100679734 L62) / entry(for:) (0x10066ed08 L71-76) 等 10 函数
//   - CovMap: closure#5 L32 @0x10066ffb8；closure#6 L33 @0x10066ffa0；toBook L38-50 @0x10066e8a8；
//     totalCount L62 @0x100679734；entry(for:) L71-76 @0x10066ed08
//   - IDA: 上述地址的 Hex-Rays 伪代码（1513 行）
//   - 关键选择子：闭包 #5/#6 为 SourceItem 字段的字符串变换（书源名称/URL 规范化）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: medium-high（缓存结构/条目查找/toBook 转换确证）
// 还原: 2026-11-19

import Foundation

/// 换源缓存（书源切换时暂存候选书源结果）。
final class ChangeSourceCache {

    /// 伪代码 SourceItem（closure #5/#6 字段变换 + toBook L38-50）。
    struct SourceItem {
        var bookUrl: String
        var sourceId: String
        var sourceName: String
        var title: String
        var author: String
        var coverUrl: String?
        var latestChapterTitle: String?
        var totalChapterNum: Int?

        /// 伪代码 0x10066e8a8（L38-50）：转换为 Book 模型。
        /// origin 语义映射到 bookSourceUrl（书源 URL 域——Book 模型字段
        /// 签名确证，wave-16）。
        func toBook() -> Book {
            var book = Book()
            book.bookUrl = bookUrl
            book.bookSourceUrl = sourceId
            book.name = title
            book.author = author
            book.coverUrl = coverUrl
            return book
        }

        /// 伪代码 closure #5（0x10066ffb8，L32）：从 Book 构造（字符串规范化字段 1）。
        /// SourceItem 字段为非可选——可选域经空串兜底（wave-16）。
        static func from(_ book: Book) -> SourceItem {
            let origin = book.bookSourceUrl ?? ""
            return SourceItem(
                bookUrl: book.bookUrl ?? "",
                sourceId: origin,
                sourceName: origin.isEmpty ? "未知来源" : origin,
                title: book.name,
                author: book.author ?? "",
                coverUrl: book.coverUrl,
                latestChapterTitle: book.lastChapter,
                totalChapterNum: nil
            )
        }
    }

    /// 伪代码 CacheEntry（totalCount L62）。
    struct CacheEntry {
        var items: [SourceItem]
        var totalCount: Int

        /// 伪代码 0x100679734（L62）：totalCount 初始化。
        init(items: [SourceItem]) {
            self.items = items
            self.totalCount = items.count
        }
    }

    private var cache: [String: CacheEntry] = [:]
    private let lock = NSLock()

    /// 伪代码 0x10066ed08（L71-76）：按 bookUrl 查缓存。
    func entry(for bookUrl: String) -> CacheEntry? {
        lock.lock()
        defer { lock.unlock() }
        return cache[bookUrl]
    }

    func update(bookUrl: String, items: [SourceItem]) {
        lock.lock()
        defer { lock.unlock() }
        cache[bookUrl] = CacheEntry(items: items)
    }

    func remove(bookUrl: String) {
        lock.lock()
        defer { lock.unlock() }
        cache.removeValue(forKey: bookUrl)
    }

    func clearAll() {
        lock.lock()
        defer { lock.unlock() }
        cache.removeAll()
    }

    static let shared = ChangeSourceCache()
}

extension ChangeSourceCache {

    /// 伪代码 0x10066f0d4（L79-84）：条目更新（整段 CacheEntry 写入域）。
    func updateEntry(_ entry: CacheEntry, for bookUrl: String) {
        lock.lock()
        defer { lock.unlock() }
        cache[bookUrl] = entry
    }

    /// 伪代码 0x10066dc64（L87-90）：条目清除（键移除域）。
    func clearEntry(for bookUrl: String) {
        lock.lock()
        defer { lock.unlock() }
        cache.removeValue(forKey: bookUrl)
    }
}

