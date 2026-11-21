// 原路径: ReadMain/Core/SourceParser/ReadMain/Core/SourceParser/JSRuntime/JSHostBinder.swift
// 证据:
//   - PGO: （2 函数，无独立伪代码 —— 内联）
//   - CovMap: 骨架地址
//   - IDA: （内联）
//   - 绑定门面（读后记推断 1）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: medium（键集待反汇编，读后记仍不清楚 2）
// 还原: 2026-11-19


import Foundation

/// 宿主绑定器：JSExecutionContext ↔ JSContext 的桥接门面（推断 1）。
enum JSHostBinder {

    /// 把执行上下文绑定为宿主（活跃规则 + 池跟踪）。
    static func bind(_ target: JSExecutionContext, analyzer: AnalyzeRule?) {
        target.context.setObject(
            analyzer ?? NSNull(), forKeyedSubscript: "__activeAnalyzer" as NSString
        )
        _ = target.context.poolReuseTracker
    }

    /// 解绑。
    static func unbind(_ target: JSExecutionContext) {
        target.context.setObject(NSNull(), forKeyedSubscript: "__activeAnalyzer" as NSString)
    }
}
