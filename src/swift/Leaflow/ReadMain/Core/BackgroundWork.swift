// 原路径: ReadMain/Core/BackgroundWork.swift
// 证据:
//   - PGO: 11 个主函数（index/task_functions.csv T-101-02 / BackgroundWork.swift），
//     地址：run(priority:_:) 0x1001ee570 L8-14（+closure 0x1002b6db0/0x1002b7c58）
//     / runThrowing 0x100d3ae50 等 L20-24（3 共体块）/ runAsync 0x1001e6f50
//     L30-34 / runThrowingAsync 0x100d43c20 L39-43 / fireAndForget 0x1001a4c54
//     L50-54 / fireAndForgetAsync 0x1001be244 L61-65（+closure 0x1001a4ad0 L62-64）
//   - CovMap: 上述 L 区段
//   - IDA: src/pseudocode/Leaflow/ReadMain/Core/BackgroundWork.c（274 行）
//   - 事实：六个变体 —— Task(priority:) 包装（同步/抛出 × 后台/异步）；
//     fireAndForget 返回 Task<Void, Never>；closure 内 TaskPriority 参与；
//     已知噪声：0x1002b6db0/0x1002b7c58 块体实为 iCloud ubiquityIdentityToken /
//     NSFileManager 逻辑（CloudSync 域误标，不冒充）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high（六变体签名确证；包装语义按签名还原）
// 还原: 2026-11-19

import Foundation

/// 后台任务包装（枚举命名空间；统一 Task(priority:) 入口）。
enum BackgroundWork {

    /// 伪代码 0x1001ee570（L8-14）：后台同步执行。
    /// @escaping：Task(priority:operation:) 形参要求逃逸闭包。
    static func run<A: Sendable>(
        priority: TaskPriority? = nil,
        _ operation: @escaping @Sendable () -> A
    ) async -> A {
        await Task(priority: priority, operation: operation).value
    }

    /// 伪代码 0x100d3ae50（L20-24，3 共体块）：后台抛出执行。
    static func runThrowing<A: Sendable>(
        priority: TaskPriority? = nil,
        _ operation: @escaping @Sendable () throws -> A
    ) async throws -> A {
        try await Task(priority: priority, operation: operation).value
    }

    /// 伪代码 0x1001e6f50（L30-34）：后台异步执行。
    static func runAsync<A: Sendable>(
        priority: TaskPriority? = nil,
        _ operation: @escaping @Sendable () async -> A
    ) async -> A {
        await Task(priority: priority, operation: operation).value
    }

    /// 伪代码 0x100d43c20（L39-43）：后台异步抛出执行。
    static func runThrowingAsync<A: Sendable>(
        priority: TaskPriority? = nil,
        _ operation: @escaping @Sendable () async throws -> A
    ) async throws -> A {
        try await Task(priority: priority, operation: operation).value
    }

    /// 伪代码 0x1001a4c54（L50-54）：即发即忘（返回 Task 供取消）。
    /// operation @escaping：Task 闭包捕获域（wave-16）。
    @discardableResult
    static func fireAndForget(
        priority: TaskPriority? = nil,
        _ operation: @escaping @Sendable () -> Void
    ) -> Task<Void, Never> {
        Task(priority: priority) {
            operation()
        }
    }

    /// 伪代码 0x1001be244（L61-65 + closure 0x1001a4ad0，L62-64）：异步即发即忘。
    @discardableResult
    static func fireAndForgetAsync(
        priority: TaskPriority? = nil,
        _ operation: @escaping @Sendable () async -> Void
    ) -> Task<Void, Never> {
        Task(priority: priority) {
            await operation()
        }
    }
}
