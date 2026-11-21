// 原路径: ReadMain/Core/StringCoding.swift
// 证据:
//   - PGO: 0 主函数 / 4 条 pgo_only 记录（index/task_functions.csv T-101-03 /
//     StringCoding.swift）：_StringRenderMetrics._r([UInt8], UInt8) -> String
//     （+closure (UInt8) -> UInt8 + implicit closure）/ _StringRenderMetrics._h(String)
//     -> UInt64 —— 全部无独立地址（内联）
//   - CovMap: 0 插桩行（派生/内联文件）
//   - IDA: 无独立伪代码（符号内联进调用点）
//   - 事实：字符串渲染度量辅助 —— _r 字节表反查渲染（closure 逐字节映射确证）；
//     _h 字符串哈希（UInt64 返回确证）；调用域为日志/调试串渲染
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: medium（签名确证；语义按名称/调用域推断）
// 还原: 2026-11-19

import Foundation

/// 字符串渲染度量辅助（pgo_only 内联符号；命名空间按 mangled 还原）。
enum _StringRenderMetrics {

    /// 伪代码签名：_r([UInt8], UInt8) -> String。
    /// 逐字节映射渲染（closure (UInt8) -> UInt8 确证）；掩码参与（第二个参数）。
    /// 语义推断：字节表按掩码取反/偏移后拼成调试串。
    static func _r(_ bytes: [UInt8], _ mask: UInt8) -> String {
        String(
            bytes: bytes.map { byte -> UInt8 in
                byte ^ mask
            },
            encoding: .utf8) ?? ""
    }

    /// 伪代码签名：_h(String) -> UInt64。
    /// 字符串哈希（FNV-1a 64 位；推断实现）。
    static func _h(_ string: String) -> UInt64 {
        var hash: UInt64 = 0xCBF29CE484222325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001B3
        }
        return hash
    }
}
