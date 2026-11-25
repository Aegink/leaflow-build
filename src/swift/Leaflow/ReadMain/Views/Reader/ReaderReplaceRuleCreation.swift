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

    /// 指令体0x1007c6730是构造器；PGO标签与0x1007c6934交错。
    /// 名称前缀0x101273ef0、前20字符及isRegex=false/enabled=true字段确证。
    static func makeRule(pattern: String, replacement: String) -> ReplaceRule {
        ReplaceRule(
            name: "阅读页添加: " + String(pattern.prefix(20)),
            pattern: pattern,
            replacement: replacement,
            isRegex: false,
            enabled: true)
    }

    /// 指令体0x1007c6934：nil或0改为1，其余值保持，返回是否改变。
    static func enableReplaceRuleIfNeeded(_ order: inout Int?) -> Bool {
        if order == nil || order == 0 {
            order = 1
            return true
        }
        return false
    }
}
