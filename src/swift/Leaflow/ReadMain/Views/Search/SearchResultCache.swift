// 原路径: ReadMain/Views/Search/SearchResultCache.swift
// 证据:
//   - PGO: 16 条记录（index/task_functions.csv T-501-06 /
//     SearchResultCache.swift；伪代码域 445 行）。关键地址：
//     init 0x1008e6d00 L14 / update(keyword:results:isComplete:)
//     0x1008e6e20 L24-31 / sourcesForBook(bookname:author:)
//     0x1008e6c9c L42-49 / clear 0x1008e6a0c L52-59 / notifyChange
//     0x1008e6fd4 L61-70 / markComplete 0x1008e700c L34-38；
//     "isComplete" 位模式 L95 确证
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Search/SearchResultCache.c
//     （445 行）
//   - 事实：搜索结果缓存（按 (bookname, author) 身份键域确证）；变更
//     通知域 notifyChange（0x1008e6fd4 域确证）；完成标记 markComplete
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（地址 + 身份键域确证）
// 还原: 2026-11-20

import Foundation

/// 搜索结果缓存。
final class SearchResultCache {

    private let lock = NSLock()
    private var results: [SearchResultBook] = []
    private var complete = false
    private var changeHandler: (() -> Void)?

    /// init（0x1008e6d00 L14 域确证）。
    init() {}

    /// 变更回调挂接（notifyChange 消费域）。
    func setChangeHandler(_ handler: (() -> Void)?) {
        lock.lock()
        changeHandler = handler
        lock.unlock()
    }

    /// 身份键（sourcesForBook 域确证；SearchEngine.merge 消费确证）。
    static func identityKey(
        bookname: String, author: String?
    ) -> String {
        let normalizedAuthor = (author ?? "")
            .trimmingCharacters(in: .whitespaces)
            .lowercased()
        return "\(bookname.lowercased())|\(normalizedAuthor)"
    }

    /// update(keyword:results:isComplete:)（0x1008e6e20 L24-31 域确证）。
    func update(
        keyword: String, results: [SearchResultBook], isComplete: Bool
    ) {
        lock.lock()
        self.results = results
        self.complete = isComplete
        let handler = changeHandler
        lock.unlock()
        handler?()
    }

    /// markComplete（0x1008e700c L34-38 域确证；"isComplete" 位模式 L95）。
    func markComplete() {
        lock.lock()
        complete = true
        let handler = changeHandler
        lock.unlock()
        handler?()
    }

    /// 完成态读取（markComplete 域确证）。
    var isComplete: Bool {
        lock.lock()
        defer { lock.unlock() }
        return complete
    }

    /// 快照读取（update 消费域）。
    var snapshot: [SearchResultBook] {
        lock.lock()
        defer { lock.unlock() }
        return results
    }

    /// sourcesForBook(bookname:author:)（0x1008e6c9c L42-49 域确证）。
    func sourcesForBook(
        bookname: String, author: String?
    ) -> [Book] {
        let key = Self.identityKey(bookname: bookname, author: author)
        lock.lock()
        defer { lock.unlock() }
        return results.first { $0.id == key }?.sources ?? []
    }

    /// clear（0x1008e6a0c L52-59 域确证）。
    func clear() {
        lock.lock()
        results.removeAll()
        complete = false
        lock.unlock()
    }

    /// notifyChange（0x1008e6fd4 L61-70 域确证）。
    private func notifyChange() {
        lock.lock()
        let handler = changeHandler
        lock.unlock()
        handler?()
    }
}
