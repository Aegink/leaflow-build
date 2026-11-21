// 原路径: ReadMain/Core/SourceParser/SourceParserMemoryDebug.swift
// 证据:
//   - PGO: compose(component:event:) (0x10016c774 L6-37)
//   - CovMap: L6-37
//   - IDA: 0x10016c774
//   - 诊断 rulePoolMax=/urlCheckedOut=
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high
// 还原: 2026-11-19


import Foundation

/// 解析器内存调试串组装。
enum SourceParserMemoryDebug {

    /// 伪代码 0x10016c774（L6-37）。
    static func compose(component: String, event: String) -> String {
        let footprint = MemoryTrace.currentProcessFootprintBytes() ?? 0
        let pool = JSContextPool.shared.snapshot()
        return "[MemoryDebug] component=\(component) event=\(event) "
            + "rulePoolMax=\(pool.pooled) urlCheckedOut=\(pool.checkedOut) "
            + "footprint=\(footprint)"
    }
}
