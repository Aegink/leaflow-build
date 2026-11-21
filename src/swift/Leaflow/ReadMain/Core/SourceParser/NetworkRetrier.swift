// 原路径: ReadMain/Core/SourceParser/NetworkRetrier.swift
// 证据:
//   - PGO: （2 函数，无独立伪代码 —— 内联）
//   - CovMap: 骨架地址
//   - IDA: （内联）
//   - 网络重试（次数/退避见读后记仍不清楚 2）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: medium（无伪代码）
// 还原: 2026-11-19


import Foundation

/// 网络重试器。
enum NetworkRetrier {

    /// 指数退避重试。
    static func withRetry<T>(
        maxAttempts: Int = 3,
        initialDelay: Double = 1.0,
        _ body: () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        for attempt in 0..<max(1, maxAttempts) {
            if attempt > 0 {
                try? await Task.sleep(nanoseconds: UInt64(initialDelay * pow(2, Double(attempt - 1)) * 1_000_000_000))
            }
            do {
                return try await body()
            } catch {
                lastError = error
            }
        }
        throw lastError ?? NSError(domain: "NetworkRetrier", code: -1)
    }
}
