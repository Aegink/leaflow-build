// 原路径: ReadMain/Services/LocalBookCoverCache.swift
// 证据:
//   - PGO: 10 条记录（index/task_functions.csv T-601-04 /
//     LocalBookCoverCache.swift；伪代码域 413 行）。关键地址：
//     init 0x10033449c L14-26 / coverFileURL 0x100334914 L28-30 /
//     loadCover 0x100334ac8 L33-48 / saveCover 0x100334f64 L51-64 /
//     removeCover 0x1003352a8 L67-73 / coverExists（签名确证）
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Services/LocalBookCoverCache.c
//     （413 行）
//   - 事实：封面缓存域（coverFileURL 单键 → PNG 文件；
//     loadCover/saveCover/removeCover/coverExists 四件签名确证）
//   - 消费：LocalBookService（T-601-04 同任务交叉）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（地址 + 四件签名确证）
// 还原: 2026-11-20

import UIKit

/// 本地书封面缓存。
final class LocalBookCoverCache {

    static let shared = LocalBookCoverCache()

    /// 封面目录（init 0x10033449c L14-26 域确证）。
    private let coversDirectory: URL

    /// init（0x10033449c L14-26 域确证）。
    init(storageDirectory: URL? = nil) {
        coversDirectory = storageDirectory ?? FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("local_book_covers", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: coversDirectory, withIntermediateDirectories: true)
    }

    /// coverFileURL（0x100334914 L28-30 域确证）。
    private func coverFileURL(for id: String) -> URL {
        coversDirectory.appendingPathComponent("cover_\(id).png")
    }

    /// loadCover（0x100334ac8 L33-48 域确证）。
    func loadCover(for id: String) async -> UIImage? {
        let url = coverFileURL(for: id)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    /// saveCover（0x100334f64 L51-64 域确证）。
    func saveCover(data: Data, for id: String) {
        let url = coverFileURL(for: id)
        try? data.write(to: url, options: .atomic)
    }

    /// removeCover（0x1003352a8 L67-73 域确证）。
    func removeCover(for id: String) {
        let url = coverFileURL(for: id)
        try? FileManager.default.removeItem(at: url)
    }

    /// coverExists（签名确证）。
    func coverExists(for id: String) -> Bool {
        FileManager.default.fileExists(atPath: coverFileURL(for: id).path)
    }
}
