// 原路径: ReadMain/Core/AsyncPermitGate.swift
// 证据:
//   - PGO: Permit.released/takeForRelease/release async (0x1001a0314/0x1001a04ac/0x1001a0268) 等 22 函数
//   - CovMap: L8/L12-18/L20-22
//   - IDA: 0x1001a0314/0x1001a04ac/0x1001a0268
//   - async 许可证闸门（WebView 并发限流）
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: medium-high（release 链确证；acquire 变体见读后记仍不清楚 1）
// 还原: 2026-11-19


import Foundation

/// 异步许可证闸门。
final class AsyncPermitGate {

    final class Permit {
        private var released = false
        private let onRelease: () -> Void

        init(onRelease: @escaping () -> Void) {
            self.onRelease = onRelease
        }

        /// 伪代码 0x1001a04ac（L12-18）。
        private func takeForRelease() -> Bool {
            if released { return false }
            released = true
            return true
        }

        /// 伪代码 0x1001a0268（L20-22）。
        func release() async {
            guard takeForRelease() else { return }
            onRelease()
        }

        deinit {
            _ = takeForRelease()
            onRelease()
        }
    }

    private var available: Int
    private var waiters: [CheckedContinuation<Permit, Never>] = []
    private let lock = NSLock()

    init(maxConcurrent: Int) {
        available = max(1, maxConcurrent)
    }

    func acquire() async -> Permit {
        await withCheckedContinuation { continuation in
            lock.lock()
            if available > 0 {
                available -= 1
                lock.unlock()
                continuation.resume(returning: Permit { [weak self] in
                    self?.returnPermit()
                })
            } else {
                waiters.append(continuation)
                lock.unlock()
            }
        }
    }

    private func returnPermit() {
        lock.lock()
        if let waiter = waiters.first {
            waiters.removeFirst()
            lock.unlock()
            waiter.resume(returning: Permit { [weak self] in
                self?.returnPermit()
            })
        } else {
            available += 1
            lock.unlock()
        }
    }
}

extension AsyncPermitGate {

    /// 许可闸门快照（SourceService.snapshot 消费域）。
    struct Snapshot {
        var available: Int
        var waiting: Int
    }

    /// 快照读取。
    func snapshot() -> Snapshot {
        lock.lock()
        defer { lock.unlock() }
        return Snapshot(available: available, waiting: waiters.count)
    }
}
