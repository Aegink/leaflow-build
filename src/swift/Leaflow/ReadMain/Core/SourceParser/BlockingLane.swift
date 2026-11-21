// 原路径: ReadMain/Core/SourceParser/BlockingLane.swift
// 证据:
//   - PGO: currentThreadExecutor (0x1000c85c4 L25-38) / run<A: Sendable> (0x100285600 L45-60) 等 194 函数（多数 ICF 特化）
//   - CovMap: L25-38/L45-60
//   - IDA: 0x1000c85c4/0x100285600
//   - qireader.blocking-lane.worker 线程名（T-205-03 事实 1）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: medium-high（车道主链确证；特化副本噪声见读后记仍不清楚 1）
// 还原: 2026-11-19


import Foundation

/// 阻塞车道：同步 JS 求值的专用线程队列。
final class BlockingLane {

    static let shared = BlockingLane()
    private let queue: DispatchQueue
    private let semaphore: DispatchSemaphore

    init() {
        queue = DispatchQueue(label: "qireader.blocking-lane.worker", qos: .userInitiated)
        semaphore = DispatchSemaphore(value: 1)
    }

    /// 伪代码 0x1000c85c4（L25-38）：当前线程执行器。
    static func currentThreadExecutor() -> @Sendable (@Sendable () -> Void) -> Void {
        { work in work() }
    }

    /// 伪代码 0x100285600（L45-60）：在车道上同步执行。
    func run<T: Sendable>(_ work: @Sendable () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    continuation.resume(returning: try work())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// 阻塞版（java 桥串行语义）。
    func runBlocking<T: Sendable>(_ work: @Sendable () throws -> T) rethrows -> T {
        semaphore.wait()
        defer { semaphore.signal() }
        return try work()
    }
}

extension BlockingLane {

    /// 伪代码 0x1000ae1ac（L71-75）：带超时等待（信号量域）。
    func wait(timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        return semaphore.wait(timeout: .now() + timeout) == .success
            || deadline < Date()
    }
}

