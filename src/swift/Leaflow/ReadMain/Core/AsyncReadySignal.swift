// 原路径: ReadMain/Core/AsyncReadySignal.swift
// 证据:
//   - PGO: waiters 初始化 (0x1001a2f90 L5) / signal() (0x1001a2ac0 L18-24)
//   - CovMap: L5/L18-24
//   - IDA: 0x1001a2f90/0x1001a2ac0
//   - 等待/唤醒信号量
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: high
// 还原: 2026-11-19


import Foundation

/// 异步就绪信号。
final class AsyncReadySignal {

    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var signaled = false
    private let lock = NSLock()

    /// 伪代码 0x1001a2ac0（L18-24）。
    func signal() {
        lock.lock()
        signaled = true
        let pending = waiters
        waiters.removeAll()
        lock.unlock()
        pending.forEach { $0.resume() }
    }

    func wait() async {
        await withCheckedContinuation { continuation in
            lock.lock()
            if signaled {
                lock.unlock()
                continuation.resume()
            } else {
                waiters.append(continuation)
                lock.unlock()
            }
        }
    }
}
