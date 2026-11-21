// 原路径: ReadMain/Views/Source/SourceManageModels.swift
// 证据:
//   - PGO: 5 条记录（index/task_functions.csv T-401-06 /
//     SourceManageModels.swift；2 个伪代码块 + 3 pgo_only）。关键地址：
//     SourceGroup.enabledCount 闭包 0x100cbd54c L23（BookSource enabled
//     过滤闭包）/ disabledCount getter（pgo_only）/ SourceManageSheet.id
//     getter（pgo_only）
//   - CovMap: L23 域
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Source/SourceManageModels.c
//     （87 行，2 块）
//   - 事实：SourceGroup.enabledCount 经 (BookSource)->Bool 闭包统计启用源
//     （0x100cbd54c 块体：enabled 标志读取 + Task 域哨兵确证）；
//     disabledCount = 总数 − enabled；SourceManageSheet 以 sheet 键控
//     （id getter）。
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（enabledCount 闭包块体确证；其余签名确证）
// 还原: 2026-11-20

import SwiftUI

/// 书源分组模型（enabledCount/disabledCount 域确证）。
struct SourceGroup: Identifiable, Equatable {
    let name: String
    let sources: [BookSource]

    var id: String { name }

    /// 0x100cbd54c（L23）：enabled 过滤闭包统计。
    var enabledCount: Int {
        sources.filter { $0.enabled }.count
    }

    /// pgo_only disabledCount getter（两 ICF 副本）。
    var disabledCount: Int {
        sources.count - enabledCount
    }
}

/// 书源管理弹层键（id getter pgo_only；sheet 键控确证）。
enum SourceManageSheet: String, Identifiable {
    case importOptions
    case export
    case help
    case batchTest

    var id: String { rawValue }
}
