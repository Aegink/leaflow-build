// 原路径: ReadMain/Core/SourceParser/ConcurrentRateLimiter.swift
// 证据:
//   - PGO: ConcurrentRateLimiterRegistry.limiter(for:) (0x1000cde78 L6-8) / insertIfAbsent (0x1000cd964 L10-18) 等 14 函数
//   - CovMap: L6-8/L10-18
//   - IDA: 上述地址
//   - 按域限流注册表
// 状态: 语义级还原（不是原始源码；变量名/注释为还原者所加）
// 置信度: medium-high
// 还原: 2026-11-19


import Foundation

/// 并发限流器。
final class ConcurrentRateLimiter {

    private var activeCount = 0
    private let maxConcurrent: Int
    private let lock = NSLock()

    init(maxConcurrent: Int) {
        self.maxConcurrent = max(1, maxConcurrent)
    }

    func tryAcquire() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if activeCount < maxConcurrent {
            activeCount += 1
            return true
        }
        return false
    }

    func release() {
        lock.lock()
        defer { lock.unlock() }
        activeCount = max(0, activeCount - 1)
    }
}

/// 伪代码 Registry（0x1000cde78，L6-18）。
final class ConcurrentRateLimiterRegistry {

    private var limiters: [String: ConcurrentRateLimiter] = [:]
    private let lock = NSLock()

    /// 伪代码 0x1000cde78（L6-8）。
    func limiter(for key: String) -> ConcurrentRateLimiter {
        lock.lock()
        defer { lock.unlock() }
        if let existing = limiters[key] {
            return existing
        }
        let created = ConcurrentRateLimiter(maxConcurrent: 4)
        limiters[key] = created
        return created
    }

    /// 伪代码 0x1000cd964（L10-18）。
    @discardableResult
    func insertIfAbsent(_ key: String, _ limiter: ConcurrentRateLimiter) -> ConcurrentRateLimiter {
        lock.lock()
        defer { lock.unlock() }
        if let existing = limiters[key] {
            return existing
        }
        limiters[key] = limiter
        return limiter
    }

    static let shared = ConcurrentRateLimiterRegistry()
}

// MARK: - T-1401-12 逐域补齐（限流域）

extension ConcurrentRateLimiterRegistry {

    /// 伪代码 0x1000cd690（L62-88）：按源键取限流器（并发数钳制域）。
    func getLimiter(
        sourceKey: String, concurrency: Int
    ) -> ConcurrentRateLimiter {
        let clamped = max(1, min(concurrency, 16))
        if let existing = limiter(for: sourceKey) {
            return existing
        }
        return insertIfAbsent(
            sourceKey, ConcurrentRateLimiter(maxConcurrent: clamped))
    }

    /// 伪代码 0x1000cdf94（L100-102）：快照（键集域）。
    func snapshot() -> [String: Int] {
        lock.lock()
        defer { lock.unlock() }
        return limiters.mapValues { $0.activeCount }
    }
}

