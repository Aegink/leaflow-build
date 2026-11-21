// 原路径: ReadMain/Views/Search/SearchEngine.swift
// 证据:
//   - PGO: 31 条记录（index/task_functions.csv T-501-06 /
//     SearchEngine.swift；伪代码域 686 行）。关键地址：
//     requestStop 0x1006861ec L88-90 / batchMergeAndSnapshot 0x1008e3a28
//     L33-40（String.lowercased 归一确证）/ finalSnapshot 0x1008e3b2c
//     L44-61 / snapshotCount 0x1008e3cd8 L69-71 / incrementCompleted
//     0x1008e3d14 L80-82 / merge 0x1008e3d80 L104-150 / buildSortedSnapshot
//     0x1008e445c L154-165 + matchTier 域（L440-560 String.lowercased
//     双值比较确证）；getCompletedCount/snapshot/isFinished(totalCount:)/
//     clearAll/sourcesForKey/init(keyword:)（签名确证）
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Search/SearchEngine.c
//     （686 行）
//   - 事实：多源聚合引擎——merge 按 (name, author) 身份去重聚合来源
//     （merge 块 + sourcesForKey 域确证）；matchTier 匹配分档
//     （lowercased 双值比较域确证：书名/作者名归一）；buildSortedSnapshot
//     按档位排序快照；批量域 batchMergeAndSnapshot；停止域 requestStop；
//     完成计数 incrementCompleted/getCompletedCount/isFinished(totalCount:)
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（地址 + 归一比较域确证）
// 还原: 2026-11-20

import Foundation

/// 多源搜索聚合引擎。
final class SearchEngine {

    let keyword: String
    private let lock = NSLock()
    private var stopped = false
    private var completedCount = 0
    private var buckets: [String: SearchResultBook] = [:]

    /// init(keyword:)（签名确证）。
    init(keyword: String) {
        self.keyword = keyword
    }

    // MARK: 停止与计数（0x1006861ec L88-90 / 0x1008e3d14 L80-82 域确证）

    /// requestStop（0x1006861ec L88-90 域确证）。
    func requestStop() {
        lock.lock()
        stopped = true
        lock.unlock()
    }

    var isStopped: Bool {
        lock.lock()
        defer { lock.unlock() }
        return stopped
    }

    /// incrementCompleted（0x1008e3d14 L80-82 域确证）。
    func incrementCompleted() {
        lock.lock()
        completedCount += 1
        lock.unlock()
    }

    /// getCompletedCount（签名确证）。
    func getCompletedCount() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return completedCount
    }

    /// isFinished(totalCount:)（签名确证）。
    func isFinished(totalCount: Int) -> Bool {
        isStopped || getCompletedCount() >= totalCount
    }

    /// snapshotCount（0x1008e3cd8 L69-71 域确证）。
    func snapshotCount() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return buckets.count
    }

    // MARK: 聚合（0x1008e3d80 L104-150 域确证）

    /// merge([Book]) -> Bool（0x1008e3d80 L104-150 域确证）：按
    /// (bookname, author) 身份聚合来源。
    private func merge(_ books: [Book]) -> Bool {
        var changed = false
        lock.lock()
        for book in books {
            let identity = SearchResultCache.identityKey(
                bookname: book.name, author: book.author)
            if var existing = buckets[identity] {
                if existing.mergeSource(book) {
                    buckets[identity] = existing
                    changed = true
                }
            } else {
                buckets[identity] = SearchResultBook(book: book)
                changed = true
            }
        }
        lock.unlock()
        return changed
    }

    /// sourcesForKey（签名确证）。
    func sourcesForKey(_ key: String) -> [Book] {
        lock.lock()
        defer { lock.unlock() }
        return buckets[key]?.sources ?? []
    }

    // MARK: 快照（0x1008e445c L154-165 + matchTier 域确证）

    /// matchTier（签名域确证；String.lowercased 双值比较确证）：
    /// 书名全等 = 0，书名前缀 = 1，书名包含 = 2，其余 = 3。
    private func matchTier(_ result: SearchResultBook) -> Int {
        let name = result.displayBook.name.lowercased()
        let query = keyword.lowercased()
        if name == query { return 0 }
        if name.hasPrefix(query) { return 1 }
        if name.contains(query) { return 2 }
        return 3
    }

    /// buildSortedSnapshot（0x1008e445c L154-165 域确证）。
    private func buildSortedSnapshot() -> [SearchResultBook] {
        lock.lock()
        let values = Array(buckets.values)
        lock.unlock()
        return values.sorted { lhs, rhs in
            let lhsTier = matchTier(lhs)
            let rhsTier = matchTier(rhs)
            if lhsTier != rhsTier { return lhsTier < rhsTier }
            return lhs.sourceCount > rhs.sourceCount
        }
    }

    /// snapshot（签名确证）。
    func snapshot() -> [SearchResultBook] {
        buildSortedSnapshot()
    }

    /// mergeAndSnapshot([Book])（签名确证）。
    func mergeAndSnapshot(
        _ books: [Book]
    ) -> (changed: Bool, snapshot: [SearchResultBook]) {
        let changed = merge(books)
        return (changed, buildSortedSnapshot())
    }

    /// batchMergeAndSnapshot([[Book]])（0x1008e3a28 L33-40 域确证；
    /// String.lowercased 归一确证）。
    func batchMergeAndSnapshot(
        _ batches: [[Book]]
    ) -> (changed: Bool, snapshot: [SearchResultBook]) {
        var changed = false
        for batch in batches {
            if merge(batch) { changed = true }
        }
        return (changed, buildSortedSnapshot())
    }

    /// finalSnapshot(clearState:)（0x1008e3b2c L44-61 域确证）。
    func finalSnapshot(clearState: Bool) -> [SearchResultBook] {
        let result = buildSortedSnapshot()
        if clearState {
            clearAll()
        }
        return result
    }

    /// clearAll（签名确证）。
    func clearAll() {
        lock.lock()
        buckets.removeAll()
        completedCount = 0
        stopped = false
        lock.unlock()
    }
}
