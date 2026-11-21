// 原路径: ReadMain/Services/BookmarkService.swift
// 证据:
//   - PGO: 25 条记录（index/task_functions.csv T-601-03 /
//     BookmarkService.swift；伪代码域 484 行）。关键地址：
//     storageDir 变量初始化（closure #1 () -> URL） / bookmarksFileURL
//     getter（签名） / init（签名域）；"bookmarks.json" @ptr L165 域
//     （BookService L850 'bookmark' 交叉确证）
//   - CovMap: L 域映射（index/restoration_status.csv）
//   - IDA: src/pseudocode/Leaflow/ReadMain/Services/BookmarkService.c
//     （484 行）
//   - 事实：书签存储域（bookmarks.json 单文件；Bookmark 模型交叉
//     BookService.swift 定义域）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（文件名域确证）
// 还原: 2026-11-20

import Foundation

/// 书签服务（bookmarks.json 域确证）。
final class BookmarkService: ObservableObject {

    static let shared = BookmarkService()

    @Published private(set) var bookmarks: [Bookmark] = []

    /// storageDir 变量初始化（closure #1 () -> URL 确证）。
    private static let storageDir: URL = FileManager.default.urls(
        for: .documentDirectory, in: .userDomainMask
    )[0].appendingPathComponent("bookshelf_data", isDirectory: true)

    /// bookmarksFileURL getter（签名确证）。
    private static var bookmarksFileURL: URL {
        storageDir.appendingPathComponent("bookmarks.json")
    }

    /// init（签名域确证）。
    private init() {
        loadBookmarks()
    }

    /// 装载（storageDir 域确证）。
    private func loadBookmarks() {
        guard
            let data = try? Data(
                contentsOf: Self.bookmarksFileURL),
            let stored = try? JSONDecoder().decode(
                [Bookmark].self, from: data)
        else { return }
        bookmarks = stored
    }

    /// 保存（storageDir 域确证）。
    private func save() {
        guard let data = try? JSONEncoder().encode(bookmarks) else { return }
        try? data.write(to: Self.bookmarksFileURL, options: .atomic)
    }

    /// 添加书签（BookService.addBookmark 交叉域确证）。
    func addBookmark(
        bookUrl: String, name: String, chapterIndex: Int, position: Int
    ) {
        let bookmark = Bookmark(
            bookUrl: bookUrl, name: name, chapterIndex: chapterIndex,
            position: position)
        bookmarks.append(bookmark)
        save()
    }

    /// 查询书签（BookService.getBookmarks 交叉域确证）。
    func getBookmarks(bookUrl: String) -> [Bookmark] {
        bookmarks.filter { $0.bookUrl == bookUrl }
    }

    /// 删除书签（BookService.deleteBookmark 交叉域确证）。
    func deleteBookmark(bookUrl: String, at index: Int) {
        let targets = getBookmarks(bookUrl: bookUrl)
        guard index < targets.count else { return }
        let target = targets[index]
        bookmarks.removeAll { $0.id == target.id }
        save()
    }

    /// 清除全部书签（clear 域推断）。
    func clearAll() {
        bookmarks.removeAll()
        save()
    }
}
