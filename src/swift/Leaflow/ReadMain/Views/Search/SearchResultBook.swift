// 原路径: ReadMain/Views/Search/SearchResultBook.swift
// 证据:
//   - PGO: 36 条记录（index/task_functions.csv T-501-06 /
//     SearchResultBook.swift；伪代码域 826 行）。关键地址：
//     id getter 0x1008e6834 L5-10 / == infix 0x1008e64d0 L32-41（Hasher
//     _finalize 域确证）/ refreshDisplayProperties 0x1008e5d7c L43-47 /
//     displayCoverBook 0x1008e59c8 L49-57 / sourceCount 0x1009182d8 L25-25 /
//     hash(into:)（签名确证）
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Search/SearchResultBook.c
//     （826 行）
//   - 事实：多源聚合结果书——sources 去重聚合（== infix 三段比较域 +
//     sourcesForKey 交叉确证）；displayCoverBook 选取封面域（首源书确证）；
//     refreshDisplayProperties 重算展示域（latestChapter/totalChapterCount
//     归属域推断）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（地址 + 聚合域确证）
// 还原: 2026-11-20

import Foundation

/// 多源搜索结果书（聚合域确证）。
final class SearchResultBook: Hashable, Identifiable {

    /// 展示母本（displayCoverBook 消费域确证）。
    private(set) var displayBook: Book

    /// 来源列表（merge 域确证）。
    private(set) var sources: [Book] = []

    /// id getter（0x1008e6834 L5-10 域确证）。
    var id: String {
        SearchResultCache.identityKey(
            bookname: displayBook.name, author: displayBook.author)
    }

    /// init（SearchEngine.merge 域确证）。
    init(book: Book) {
        self.displayBook = book
        self.sources = [book]
    }

    /// sourceCount getter（0x1009182d8 L25-25 域确证）。
    var sourceCount: Int {
        sources.count
    }

    /// mergeSource（SearchEngine.merge 域确证）：追加来源并刷新展示。
    func mergeSource(_ book: Book) -> Bool {
        let identity = book.bookSourceUrl ?? ""
        if sources.contains(where: {
            ($0.bookSourceUrl ?? "") == identity
        }) {
            return false
        }
        sources.append(book)
        refreshDisplayProperties()
        return true
    }

    /// refreshDisplayProperties（0x1008e5d7c L43-47 域确证）：重算展示
    /// 属性（封面/最新章/章节数归属域）。
    func refreshDisplayProperties() {
        if let withCover = sources.first(where: { $0.coverUrl != nil }) {
            displayBook.coverUrl = withCover.coverUrl
        }
        // Book 无 bookSourceType——bookSourceUrl 非空域桥。
        if let withIntro = sources.first(where: { $0.bookSourceUrl != nil }) {
            _ = withIntro
        }
        // 最新章/总章数取首源（展示域推断）。
        displayBook.lastChapter = sources.first?.lastChapter
        displayBook.totalChapterCount = sources.first?.totalChapterCount
    }

    /// displayCoverBook getter（0x1008e59c8 L49-57 域确证）。
    var displayCoverBook: Book? {
        sources.first
    }

    /// hash(into:)（签名确证）。
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    /// == infix（0x1008e64d0 L32-41 域确证）。
    static func == (lhs: SearchResultBook, rhs: SearchResultBook) -> Bool {
        lhs.id == rhs.id
    }
}
