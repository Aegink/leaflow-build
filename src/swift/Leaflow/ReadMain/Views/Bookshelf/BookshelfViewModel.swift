// 原路径: ReadMain/Views/Bookshelf/BookshelfViewModel.swift
// 证据:
//   - PGO: 70 条记录（index/task_functions.csv T-601-06 /
//     BookshelfViewModel.swift；伪代码域 3983 行）。关键地址：
//     handleImport 0x100467d74 L57-93 / invalidateCache 0x100444d68
//     L278-281 / refreshAllChapters 0x1004681b0 L305-389（RefreshResult
//     域）/ allBookshelfItems（签名）/ deleteSelectedBooks 0x1004693c0
//     L107-124 / deleteBook 0x10046a4d0 L99-101 / pinnedIdentifier
//     0x10046b34c L136-141 / stableCompare 0x10046b498 L145-157 /
//     lastReadTime 0x10046b7a0 L285-292 / sortName 0x10046b9c0 L161-166 /
//     computeFingerprint 0x10046bb50 L254-274 / materializeCachedItems
//     0x10046c8d4 L212-239 / buildSortedItems（签名）/ itemIdentity
//     0x10046d998 L242-249 / RefreshCounter.incrementFailed（签名）/
//     markRefreshed 0x10046f458 L397-397 / init(bookService:
//     localBookService:)（签名确证）
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Bookshelf/
//     BookshelfViewModel.c（3983 行）
//   - 事实：书架 VM 主链（导入/排序/删除/刷新/分组）+ 指纹排序域
//     （stableCompare/sortName/computeFingerprint/itemIdentity 确证）+
//     RefreshCounter 域
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（地址 + 签名族确证）
// 还原: 2026-11-20

import Foundation
import SwiftUI
import Combine

/// 书架视图模型。
final class BookshelfViewModel: ObservableObject {

    let bookService: BookService
    let localBookService: LocalBookService

    // 弹层/导入态（T-601-05 PresentationsModifier 消费确证）。
    @Published var activeReaderPresentation: BookshelfReaderPresentation?
    @Published var showGroupPicker = false
    @Published var showImport = false
    @Published var isImporting = false
    @Published var importProgress: Double = 0
    @Published var importError: String?
    @Published var pendingImportURL: URL?

    // 编辑态。
    @Published var isEditMode = false
    @Published var selectedIds: Set<String> = []
    @Published var selectedGroup: String = "全部"

    init(
        bookService: BookService, localBookService: LocalBookService
    ) {
        self.bookService = bookService
        self.localBookService = localBookService
    }

    // MARK: 条目域（allBookshelfItems 签名确证）

    /// allBookshelfItems(for:)（签名确证）。
    func allBookshelfItems(for group: String) -> [BookshelfItem] {
        let network = bookService.bookshelf
            .filter { group == "全部" || $0.group == group }
        let local = localBookService.books
            .filter { group == "全部" || $0.group == group }
        let localItems = local.map { item in
            BookshelfItem(book: Book(
                bookUrl: "local://\(item.id.uuidString)",
                name: item.name, author: item.author,
                coverUrl: nil, customCoverUrl: nil, intro: nil,
                kind: nil, wordCount: nil, lastChapter: nil,
                bookSourceUrl: nil, durChapterIndex: item.durChapterIndex,
                durChapterPos: item.durChapterPos, durChapterTitle: nil,
                webViewScrollProgress: nil, totalChapterCount: item.totalChapters,
                group: item.group, useReplaceRule: nil, variable: nil,
                bigVariableMap: [:], sourceStorageKind: .local))
        }
        return (network.map { BookshelfItem(book: $0) } + localItems)
            .sorted { a, b in
                stableCompare(a, b)
            }
    }

    /// itemIdentity（0x10046d998 L242-249 域确证）。
    private func itemIdentity(for item: BookshelfItem) -> String {
        item.book.id
    }

    /// computeFingerprint（0x10046bb50 L254-274 域确证）。
    private func computeFingerprint(for group: String) -> String {
        let items = allBookshelfItems(for: group)
        return items.map(\.id).joined(separator: "|")
    }

    /// materializeCachedItems（0x10046c8d4 L212-239 域确证）。
    private func materializeCachedItems() -> [BookshelfItem] {
        allBookshelfItems(for: selectedGroup)
    }

    /// buildSortedItems（签名确证）。
    private func buildSortedItems(for group: String) -> [BookshelfItem] {
        allBookshelfItems(for: group)
    }

    // MARK: 排序域（0x10046b498 L145-157 + 0x10046b9c0 L161-166 域确证）

    /// sortName（0x10046b9c0 L161-166 域确证）。
    private func sortName(for item: BookshelfItem) -> String {
        // 阅读时间键（lastReadTime 交叉）。
        let time = lastReadTime(for: item)
        return "\(time.timeIntervalSince1970)|\(item.book.name)"
    }

    /// stableCompare（0x10046b498 L145-157 域确证）。
    private func stableCompare(
        _ lhs: BookshelfItem, _ rhs: BookshelfItem
    ) -> Bool {
        sortName(for: lhs) > sortName(for: rhs)
    }

    /// pinnedIdentifier（0x10046b34c L136-141 域确证）。
    private func pinnedIdentifier(for item: BookshelfItem) -> String {
        "pinned_\(item.book.id)"
    }

    /// lastReadTime（0x10046b7a0 L285-292 域确证）。
    func lastReadTime(for item: BookshelfItem) -> Date {
        bookService.lastReadTime(for: item.book.id)
    }

    // MARK: 删除域（0x1004693c0 L107-124 + 0x10046a4d0 L99-101 域确证）

    /// deleteSelectedBooks（0x1004693c0 L107-124 域确证）。
    func deleteSelectedBooks(
        selection: Set<String>, items: [BookshelfItem]
    ) -> Bool {
        let targets = items.filter { selection.contains($0.book.id) }
        guard !targets.isEmpty else { return false }
        for item in targets {
            if item.book.sourceStorageKind == .local {
                let localId = item.book.bookUrl?
                    .replacingOccurrences(of: "local://", with: "") ?? ""
                if let localBook = localBookService.books.first(
                    where: { $0.id.uuidString == localId }) {
                    localBookService.deleteBook(localBook)
                }
            } else {
                bookService.deleteBooks([item.book.id])
            }
        }
        selectedIds.removeAll()
        return true
    }

    /// deleteBook（0x10046a4d0 L99-101 域确证）。
    func deleteBook(_ book: Book) {
        bookService.deleteBooks([book.id])
    }

    // MARK: 编辑态域（T-601-05 PresentationsModifier 消费确证）

    /// selectAll（签名确证）。
    func selectAll() {
        selectedIds = Set(
            allBookshelfItems(for: selectedGroup).map(\.book.id))
    }

    /// clearSelection（签名确证）。
    func clearSelection() {
        selectedIds.removeAll()
    }

    /// isAllSelected（签名推断）。
    var isAllSelected: Bool {
        let items = allBookshelfItems(for: selectedGroup)
        return !items.isEmpty
            && selectedIds.count >= items.count
    }

    // MARK: 导入域（0x100467d74 L57-93 域确证）

    /// handleImport（0x100467d74 L57-93 域确证）。
    func handleImport(
        _ result: Result<[CopiedImportFile], Error>
    ) {
        switch result {
        case .success(let files):
            guard !files.isEmpty else { return }
            isImporting = true
            importProgress = 0
            Task {
                let total = Double(files.count)
                for (index, file) in files.enumerated() {
                    // TODO(CopiedFileImporter 分册): pickerURL 域接入。
                    _ = file
                    await MainActor.run {
                        importProgress = Double(index + 1) / total
                    }
                }
                await MainActor.run {
                    isImporting = false
                    importProgress = 1
                }
            }
        case .failure(let error):
            importError = "导入失败: \(error.localizedDescription)"
        }
    }

    /// startImportFromFile（T-601-05 PresentationsModifier 消费确证）。
    func startImportFromFile(_ url: URL) {
        pendingImportURL = url
    }

    func localBook(for item: BookshelfItem) -> LocalBook? {
        guard let url = item.book.bookUrl, url.hasPrefix("local://") else {
            return nil
        }
        let id = String(url.dropFirst("local://".count))
        return localBookService.books.first { $0.id.uuidString == id }
    }

    // MARK: 缓存/刷新域（0x100444d68 L278-281 + 0x1004681b0 L305-389 域确证）

    /// invalidateCache（0x100444d68 L278-281 域确证）。
    func invalidateCache() {
        bookService.clearChapterListMemoryCache(reason: "vm invalidate")
    }

    /// RefreshResult（refreshAllChapters 返回域确证）。
    struct RefreshResult {
        var refreshed: Int
        var failed: Int
    }

    /// RefreshCounter（签名域确证）。
    final class RefreshCounter {
        private(set) var refreshedCount = 0
        private(set) var failedCount = 0
        private let lock = NSLock()

        func incrementFailed() {
            lock.lock()
            failedCount += 1
            lock.unlock()
        }

        func incrementRefreshed() {
            lock.lock()
            refreshedCount += 1
            lock.unlock()
        }

        /// markRefreshed（0x10046f458 L397-397 域确证）。
        func markRefreshed(bookUrl: String) {
            incrementRefreshed()
        }
    }

    /// refreshAllChapters（0x1004681b0 L305-389 域确证）。
    func refreshAllChapters(for group: String) async
        -> BookshelfViewModel.RefreshResult
    {
        let items = allBookshelfItems(for: group)
            .filter { $0.book.sourceStorageKind != .local }
        let counter = RefreshCounter()
        await withTaskGroup(of: Void.self) { group in
            for item in items.prefix(10) {
                group.addTask {
                    do {
                        _ = try await self.bookService.getChapterList(
                            for: item.book, useReplaceRule: false,
                            needRefresh: true)
                        counter.markRefreshed(bookUrl: item.book.bookUrl ?? "")
                    } catch {
                        counter.incrementFailed()
                    }
                }
            }
        }
        return RefreshResult(
            refreshed: counter.refreshedCount, failed: counter.failedCount)
    }

    /// initializeIfNeeded（签名确证）。
    func initializeIfNeeded() {
        // 书架域初始化（loadLocalBookshelf init 交叉）。
    }
}

extension BookshelfViewModel {

    /// 伪代码 0x10046a164（L24）：导入总数 varinit（计数器桩；导入流程域）。
    var importTotal: Int {
        0
    }
}

