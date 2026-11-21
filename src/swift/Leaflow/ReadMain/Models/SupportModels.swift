// 原路径: ReadMain/Models/SupportModels.swift
// 证据:
//   - PGO: 3 条记录（index/task_functions.csv T-601-02 /
//     SupportModels.swift；全 pgo_only —— 无独立伪代码）。签名族：
//     DynamicCodingKeys.init(stringValue:) / DynamicCodingKeys.init(intValue:)
//     / BackGround.id getter
//   - CovMap: 行号映射（index/restoration_status.csv）
//   - IDA: 无独立伪代码（pgo_only 全家）
//   - 事实：动态编码键域（CodingKey 协议实现——stringValue/intValue 双 init
//     签名确证，AnalyzeRule JSON 动态域消费交叉）；背景模型域（id getter
//     pgo_only 确证）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: medium（pgo_only 签名推断；字段随阅读器域交叉）
// 还原: 2026-11-20

import Foundation

// MARK: - DynamicCodingKeys（签名族确证）

/// 动态编码键（stringValue/intValue 双 init 确证；
/// AnalyzeRule JSON 动态域消费）。
enum DynamicCodingKeys: CodingKey, Hashable {
    case string(String)
    case int(Int)

    /// stringValue（签名确证）。
    var stringValue: String {
        switch self {
        case .string(let value): return value
        case .int(let value): return "\(value)"
        }
    }

    /// intValue（签名确证）。
    var intValue: Int? {
        switch self {
        case .string: return nil
        case .int(let value): return value
        }
    }

    /// init(stringValue:)（签名确证）。
    init?(stringValue: String) {
        self = .string(stringValue)
    }

    /// init(intValue:)（签名确证）。
    init?(intValue: Int) {
        self = .int(intValue)
    }
}

// MARK: - BackGround（id getter pgo_only 确证）

/// 背景模型（id getter pgo_only 确证；阅读器背景域交叉）。
struct BackGround: Codable, Identifiable, Equatable {
    var name: String
    var kind: String
    var assetKey: String?

    /// id getter（pgo_only 确证）。
    var id: String { name }
}
