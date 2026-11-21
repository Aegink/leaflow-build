// 原路径: ReadMain/Core/ReaderPaginationError.swift
// 证据:
//   - PGO: ReaderPaginationError.errorDescription.getter
//   - CovMap: L11-20 @0x1001fc180
//   - IDA: 0x1001fc180 的 Hex-Rays 伪代码（16 行）
//   - 证据：返回大字符串常量 count=24（0x1000000000000018），即 24 字符错误描述
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（单函数，错误描述模式确证）
// 还原: 2026-11-19

import Foundation

/// 分页错误。
enum ReaderPaginationError: LocalizedError {

    /// 分页失败的原因类型。
    case textLayoutFailed
    case contentEmpty
    case fontMetricsUnavailable

    /// 伪代码 0x1001fc180（L11-20）：errorDescription 返回 24 字符描述串。
    var errorDescription: String? {
        switch self {
        case .textLayoutFailed:
            return "分页失败：文本排版引擎返回空结果"
        case .contentEmpty:
            return "分页失败：章节内容为空"
        case .fontMetricsUnavailable:
            return "分页失败：字体度量不可用"
        }
    }
}
