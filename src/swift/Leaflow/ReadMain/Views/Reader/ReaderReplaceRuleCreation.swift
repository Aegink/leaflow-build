// 原路径: ReadMain/Views/Reader/ReaderReplaceRuleCreation.swift
// 证据:
//   - PGO: 2 个主函数（index/task_functions.csv T-301-08 / ReaderReplaceRuleCreation.swift），
//     地址：makeRule(pattern:replacement:) 0x1007c6934 L9-17 /
//     enableReplaceRuleIfNeeded(inout Int?) 0x1007c6730 L20-24（+closure 0x1007c7a9c L21）
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Views/Reader/ReaderReplaceRuleCreation.c（422 行）
//   - 事实：makeRule —— 构造 ReplaceRule（pattern/replacement 直填）；
//     enableReplaceRuleIfNeeded —— 规则未启用（order/排序键 nil）时置默认序
//     （String._fromSubstring 参与确证）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（构造/启用语义确证）
// 还原: 2026-11-19

import Foundation

/// 阅读器内替换规则创建（枚举命名空间）。
enum ReaderReplaceRuleCreation {

    /// 伪代码 0x1007c6934（L9-17）：按 pattern/replacement 构造规则。
    /// 字段对齐 ReplaceRule 真实 init（enable: Bool? 域，wave-16）。
    static func makeRule(pattern: String, replacement: String) -> ReplaceRule {
        ReplaceRule(
            name: pattern,
            pattern: pattern,
            replacement: replacement,
            enabled: true,
            group: "")
    }

    /// 伪代码 0x1007c6730（L20-24）：未启用时置默认序（返回是否启用）。
    static func enableReplaceRuleIfNeeded(_ order: inout Int?) -> Bool {
        if order == nil {
            order = 0
            return true
        }
        return false
    }
}
