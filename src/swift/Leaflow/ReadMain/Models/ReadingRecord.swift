// 原路径: ReadMain/Models/ReadingRecord.swift
// 证据:
//   - PGO: 7 条记录（index/task_functions.csv T-601-02 /
//     ReadingRecord.swift；1 个伪代码块）。关键地址：
//     init(from: Decoder) 0x1002501cc L55-66（Date 元数据 + 容器域确证）/
//     ReadingRecord.id/DailyStat.id/BookStat.id（pgo_only 签名）/
//     init(bookFingerprint:bookName:date:duration…)（双签名确证）
//   - CovMap: L55-66
//   - IDA: src/pseudocode/Leaflow/ReadMain/Models/ReadingRecord.c（131 行）
//   - 事实：init(from:) 用 Date 元数据（v36 = type metadata accessor for
//     Date 域确证）+ 容器解码（Decoder.container(keyedBy:) 域确证）；
//     DailyStat/BookStat 本体归口 T-501-01 ReadingStatisticsService.swift
//     （id getter 交叉确证）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（init(from:) 块体确证）
// 还原: 2026-11-20

import Foundation

/// 阅读会话记录（init(from:) 0x1002501cc L55-66 域确证）。
struct ReadingRecord: Codable, Equatable {
    let bookFingerprint: String
    let bookName: String
    let dayKey: String
    var readingSeconds: Int
    var listeningSeconds: Int
    var updatedAt: Date

    /// id getter（pgo_only 确证）。
    var id: String {
        "\(bookFingerprint)|\(dayKey)"
    }

    /// init（签名确证双域：bookFingerprint:bookName:date:duration…）。
    init(
        bookFingerprint: String, bookName: String, date: String,
        durationSeconds: Int, listeningSeconds: Int = 0,
        updatedAt: Date = Date()
    ) {
        self.bookFingerprint = bookFingerprint
        self.bookName = bookName
        self.dayKey = date
        self.readingSeconds = durationSeconds
        self.listeningSeconds = listeningSeconds
        self.updatedAt = updatedAt
    }

    /// init(from:)（0x1002501cc L55-66 域确证：Date 元数据 + keyed 容器）。
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        bookFingerprint = try container.decodeIfPresent(
            String.self, forKey: .bookFingerprint) ?? ""
        bookName = try container.decodeIfPresent(
            String.self, forKey: .bookName) ?? ""
        dayKey = try container.decodeIfPresent(
            String.self, forKey: .dayKey) ?? ""
        readingSeconds = try container.decodeIfPresent(
            Int.self, forKey: .readingSeconds) ?? 0
        listeningSeconds = try container.decodeIfPresent(
            Int.self, forKey: .listeningSeconds) ?? 0
        updatedAt = try container.decodeIfPresent(
            Date.self, forKey: .updatedAt) ?? Date()
    }

    enum CodingKeys: String, CodingKey {
        case bookFingerprint
        case bookName
        case dayKey = "date"
        case readingSeconds
        case listeningSeconds
        case updatedAt
    }
}
