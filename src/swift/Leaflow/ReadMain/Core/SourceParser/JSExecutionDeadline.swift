// 原路径: ReadMain/Core/SourceParser/ReadMain/Core/SourceParser/JSExecutionDeadline.swift
// 证据:
//   - PGO: init(timeout:) / hasExpired.getter
//   - CovMap: init @骨架地址（2 函数）
//   - IDA: 骨架地址
//   - JS 执行截止时间（T-201-04 推断 4 的载体）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（ProcessInfo.systemUptime 计时语义自洽）
// 还原: 2026-11-19


import Foundation

/// JS 执行截止时间（safeEvaluateScript 的超时判定载体，T-201-04 推断 4）。
struct JSExecutionDeadline {

    let deadline: TimeInterval

    init(timeout: Double) {
        deadline = ProcessInfo.processInfo.systemUptime + timeout
    }

    /// 是否超时。
    var hasExpired: Bool {
        ProcessInfo.processInfo.systemUptime >= deadline
    }
}
