// 原路径: ReadMain/Models/BookSupportModels.swift
// 证据:
//   - PGO: 1 条记录（index/task_functions.csv T-601-01 /
//     BookSupportModels.swift；无独立伪代码——BookGroup.id getter
//     pgo_only）。签名族：Leaflow.BookGroup.id.getter : Swift.String
//   - CovMap: 行号映射（index/restoration_status.csv）
//   - IDA: 无独立伪代码（pgo_only）
//   - 事实：书架分组模型（id getter pgo_only 确证；书架域 BookService
//     T-601-03 交叉）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: medium（pgo_only 签名推断；字段随书架域交叉）
// 还原: 2026-11-20

import Foundation

/// 书架分组模型（BookGroup.id pgo_only 确证）。
struct BookGroup: Codable, Identifiable, Equatable {
    var name: String
    var order: Int = 0

    /// id getter（pgo_only 确证）。
    var id: String { name }
}
