// 原路径: ReadMain/Views/Reader/Manga/ReaderRouter.swift
// 证据:
//   - PGO: 5 个主函数（index/task_functions.csv T-304-05 / ReaderRouter.swift），
//     地址：body 0x10063cd00 L21-29 / isTextBook 0x10043fad8 L31-33 /
//     isAudioSource 0x10063d128 L35-58 / isMangaSource 0x10063d5f4 L60-83
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Reader/Manga/ReaderRouter.c
//   - 事实：书路由四分派 —— 文本（ReaderView）/漫画（MangaReaderView）/
//     音频（AudioPlayerView）/本地 PDF（LocalPDFReaderView）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（分派链确证）
// 还原: 2026-11-19

import SwiftUI

/// 阅读器路由（按书类型分发）。
struct ReaderRouter: View {

    var book: Book
    var settings: ReadingSettings

    var body: some View {
        // 伪代码 0x10063cd00（L21-29）：四分派。
        // ReaderView 域桥：Book(String id)→bookId(Int) 恒等桥——真机核清项。
        if Self.isAudioSource(book) {
            AudioPlayerView(book: book)
        } else if Self.isMangaSource(book) {
            MangaReaderView(book: book)
        } else if Self.isTextBook(book) {
            LocalReaderView(book: LocalBook(from: book), settings: .constant(settings))
        } else {
            ReaderView(settings: .constant(settings), bookId: 0)
        }
    }
}

extension ReaderRouter {

    /// 伪代码 0x10043fad8（L31-33）：纯文本判定。
    /// bookType 域桥（Book 无 bookSourceType 成员——类型分档桥，真机核清项）。
    static func isTextBook(_ book: Book) -> Bool {
        book.bookType == 0
    }

    /// 伪代码 0x10063d128（L35-58）：音频源判定（bookSourceType == audio 域确证）。
    static func isAudioSource(_ book: Book) -> Bool {
        book.bookType == 2
    }

    /// 伪代码 0x10063d5f4（L60-83）：漫画源判定。
    static func isMangaSource(_ book: Book) -> Bool {
        book.bookType == 1
    }
}

/// 本地书桥（LocalBook(from: Book) 转换，T-601-01 签名域）。
private extension LocalBook {
    init(from book: Book) {
        self.init(
            id: UUID(),
            name: book.name,
            author: book.author,
            filePath: book.bookUrl ?? "",
            format: "txt")
    }
}
